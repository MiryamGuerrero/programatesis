from __future__ import annotations

import ast
import json
import re
import unicodedata
from datetime import UTC, datetime
from operator import add, mul, sub, truediv
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.security import UserContext

from app.api.deps import require_roles
from app.core.db import db_cursor

router = APIRouter(
    prefix="/nutricionista/etiquetado",
    tags=["Nutricionista Etiquetado Auditoria"],
)


class AuditoriaIngredienteRow(BaseModel):
    ingrediente_id: int
    ingrediente_nombre: str
    etiqueta_id: int
    etiqueta_codigo: str
    etiqueta_nombre: str
    subetiqueta_id: int
    subetiqueta_codigo: str
    subetiqueta_nombre: str
    regla_version_id: int
    regla_version_numero: int
    regla_estado: str
    subetiqueta_regla_id: int | None = None
    prioridad_evaluacion: int | None = None
    tipo_evaluacion: str | None = None
    energia_kcal: float | None = None
    proteinas_g: float | None = None
    hidratos_carbono_g: float | None = None
    grasa_total_g: float | None = None
    fibra_vegetal_g: float | None = None
    sodio_mg: float | None = None
    calcio_mg: float | None = None
    hierro_mg: float | None = None
    fecha_calculo: str | None = None
    valor_disparador: float | None = None
    detalle_evaluacion: dict[str, Any] | list[Any] | None = None
    condiciones: list[dict[str, Any]] = Field(default_factory=list)


class AuditoriaIngredienteResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[AuditoriaIngredienteRow]


class AuditoriaSubetiquetaCandidata(BaseModel):
    subetiqueta_id: int
    subetiqueta_codigo: str
    subetiqueta_nombre: str
    subetiqueta_regla_id: int | None = None
    prioridad_evaluacion: int | None = None
    tipo_evaluacion: str | None = None
    es_ganadora: bool
    condiciones: list[dict[str, Any]] = Field(default_factory=list)


class AuditoriaIngredienteDetalleResponse(BaseModel):
    resultado_ganador: AuditoriaIngredienteRow
    subetiquetas_candidatas: list[AuditoriaSubetiquetaCandidata]


class CondicionValorTextoInput(BaseModel):
    texto_busqueda: str = Field(min_length=1, max_length=255)
    tipo_match: str = Field(default="CONTIENE")


class CondicionInput(BaseModel):
    id_campo_catalogo: int = Field(ge=1)
    operador: str = Field(min_length=1, max_length=30)
    valor_numerico: float | None = None
    valor_texto_directo: str | None = Field(default=None, max_length=255)
    orden_condicion: int = Field(default=1, ge=1)
    valores_texto: list[CondicionValorTextoInput] = Field(default_factory=list)


class GrupoCondicionInput(BaseModel):
    operador_grupo: str = Field(default="AND")
    orden_grupo: int = Field(default=1, ge=1)
    condiciones: list[CondicionInput] = Field(default_factory=list)


class SubetiquetaReglaInput(BaseModel):
    id_subetiqueta: int = Field(ge=1)
    prioridad_evaluacion: int = Field(ge=1)
    tipo_evaluacion: str = Field(default="FIRST_MATCH")
    grupos_condicion: list[GrupoCondicionInput] = Field(default_factory=list)


class ReglaVersionUpdateRequest(BaseModel):
    estado: str = Field(default="BORRADOR")
    observacion: str | None = None
    subetiquetas: list[SubetiquetaReglaInput] | None = None


class ReglaVersionUpdateResponse(BaseModel):
    id_etiqueta: int
    source_regla_version_id: int
    source_version_numero: int
    new_regla_version_id: int
    new_version_numero: int
    estado: str
    clonado_desde_version_origen: bool
    subetiquetas_count: int
    grupos_count: int
    condiciones_count: int
    valores_texto_count: int


class RecalculoEtiquetadoRequest(BaseModel):
    id_regla_version: int | None = Field(default=None, gt=0)
    id_etiqueta: int | None = Field(default=None, gt=0)
    id_ingrediente: int | None = Field(default=None, gt=0)
    solo_activos: bool = True
    max_ingredientes: int | None = Field(default=None, ge=1, le=5000)
    dry_run: bool = False
    stop_on_error: bool = False


class RecalculoVersionResult(BaseModel):
    id_etiqueta: int
    id_regla_version: int
    version_numero: int
    estado: str
    ingredientes_procesados: int
    insertados: int
    actualizados: int
    sin_cambios: int
    eliminados: int
    sin_resultado: int
    errores: int


class RecalculoEtiquetadoResponse(BaseModel):
    scope: str
    dry_run: bool
    reglas_procesadas: int
    ingredientes_en_alcance: int
    insertados: int
    actualizados: int
    sin_cambios: int
    eliminados: int
    sin_resultado: int
    errores: int
    resultado_por_regla: list[RecalculoVersionResult]
    mensajes_error: list[str] = Field(default_factory=list)


class RecalculoErrorItem(BaseModel):
    id_ingrediente: int | None = None
    id_regla_version: int | None = None
    mensaje: str


class RecalculoHistorialItem(BaseModel):
    id_log: int
    fecha_registro: str
    id_usuario: str | None = None
    scope: str
    dry_run: bool
    reglas_procesadas: int
    ingredientes_en_alcance: int
    insertados: int
    actualizados: int
    sin_cambios: int
    eliminados: int
    sin_resultado: int
    errores: int
    etiqueta_ids: list[int] = Field(default_factory=list)
    regla_version_ids: list[int] = Field(default_factory=list)
    ultimos_errores: list[RecalculoErrorItem] = Field(default_factory=list)


class RecalculoHistorialResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[RecalculoHistorialItem]


class RecalculoHistorialDetalleResponse(BaseModel):
    item: RecalculoHistorialItem
    request_payload: dict[str, Any] = Field(default_factory=dict)
    result_payload: dict[str, Any] = Field(default_factory=dict)
    meta_payload: dict[str, Any] = Field(default_factory=dict)
    detalle: str | None = None


class EtiquetaNuevaSubsubetiquetaInput(BaseModel):
    codigo: str = Field(min_length=1, max_length=80)
    nombre_visible: str = Field(min_length=1, max_length=160)
    prioridad_relativa: int = Field(default=1, ge=1, le=99)
    descripcion: str | None = None
    activa: bool = True
    tipo_evaluacion: str = Field(default="FIRST_MATCH")


class EtiquetaNuevaSubetiquetaInput(BaseModel):
    codigo: str = Field(min_length=1, max_length=80)
    nombre_visible: str = Field(min_length=1, max_length=160)
    prioridad: int = Field(default=1, ge=1, le=9999)
    descripcion: str | None = None
    activa: bool = True
    tipo_evaluacion: str = Field(default="FIRST_MATCH")
    subsubetiquetas: list[EtiquetaNuevaSubsubetiquetaInput] = Field(default_factory=list)


class EtiquetaNuevaRequest(BaseModel):
    codigo: str = Field(min_length=1, max_length=80)
    nombre_visible: str = Field(min_length=1, max_length=160)
    descripcion: str | None = None
    activa: bool = True
    crear_regla_inicial: bool = True
    estado_regla_inicial: str = Field(default="BORRADOR")
    subetiquetas: list[EtiquetaNuevaSubetiquetaInput] = Field(default_factory=list, min_length=1)


class EtiquetaNuevaSubetiquetaResult(BaseModel):
    id_subetiqueta: int
    id_subetiqueta_padre: int | None = None
    codigo: str
    nombre_visible: str
    prioridad: int
    nivel: int
    parent_codigo: str | None = None


class EtiquetaNuevaResponse(BaseModel):
    id_etiqueta: int
    codigo: str
    nombre_visible: str
    id_regla_version_inicial: int | None = None
    version_numero_inicial: int | None = None
    subetiquetas_creadas: list[EtiquetaNuevaSubetiquetaResult] = Field(default_factory=list)


def _build_filters(
    search: str | None,
    id_etiqueta: int | None,
    id_subetiqueta: int | None,
) -> tuple[str, list[Any]]:
    clauses: list[str] = []
    params: list[Any] = []

    if search:
        clauses.append("i.nombre ilike %s")
        params.append(f"%{search.strip()}%")

    if id_etiqueta is not None:
        clauses.append("ire.id_etiqueta = %s")
        params.append(id_etiqueta)

    if id_subetiqueta is not None:
        clauses.append("ire.id_subetiqueta = %s")
        params.append(id_subetiqueta)

    where_sql = ""
    if clauses:
        where_sql = "WHERE " + " AND ".join(clauses)

    return where_sql, params


def _normalize_upper(value: str) -> str:
    return value.strip().upper()


def _validate_tipo_match(value: str) -> str:
    normalized = _normalize_upper(value)
    allowed = {"CONTIENE", "IGUAL", "INICIA", "TERMINA", "REGEX"}
    if normalized not in allowed:
        raise HTTPException(status_code=400, detail=f"tipo_match invalido: {value}")
    return normalized


def _validate_operador_grupo(value: str) -> str:
    normalized = _normalize_upper(value)
    if normalized not in {"AND", "OR"}:
        raise HTTPException(status_code=400, detail=f"operador_grupo invalido: {value}")
    return normalized


def _validate_tipo_evaluacion(value: str) -> str:
    normalized = _normalize_upper(value)
    if normalized not in {"FIRST_MATCH", "ELSE"}:
        raise HTTPException(status_code=400, detail=f"tipo_evaluacion invalido: {value}")
    return normalized


def _validate_estado_regla(value: str) -> str:
    normalized = _normalize_upper(value)
    if normalized not in {"BORRADOR", "PUBLICADA", "INACTIVA"}:
        raise HTTPException(status_code=400, detail=f"estado invalido: {value}")
    return normalized


def _normalize_code(value: str) -> str:
    text = unicodedata.normalize("NFKD", value)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = re.sub(r"[^A-Za-z0-9_]+", "_", text)
    text = text.strip("_").upper()
    if not text:
        raise HTTPException(status_code=400, detail="codigo invalido")
    return text


def _resolve_usuario_uuid(cur, user: UserContext) -> str | None:
    sql = """
        select u.id::text
        from usuarios.usuario u
        where u.id::text = %s
           or u.auth_user_id::text = %s
           or lower(u.email) = lower(%s)
        order by case
            when u.id::text = %s then 1
            when u.auth_user_id::text = %s then 2
            else 3
        end
        limit 1
    """
    cur.execute(sql, (user.user_id, user.user_id, user.email or "", user.user_id, user.user_id))
    row = cur.fetchone()
    if not row or not row[0]:
        return None

    candidate = str(row[0])
    try:
        UUID(candidate)
    except ValueError:
        return None
    return candidate


def _clone_subetiquetas_from_source(cur, source_regla_version_id: int, new_regla_version_id: int) -> dict[str, int]:
    stats = {
        "subetiquetas_count": 0,
        "grupos_count": 0,
        "condiciones_count": 0,
        "valores_texto_count": 0,
    }

    cur.execute(
        """
        select id, id_subetiqueta, prioridad_evaluacion, tipo_evaluacion
        from etiquetado.subetiqueta_regla
        where id_regla_version = %s
        order by prioridad_evaluacion, id
        """,
        (source_regla_version_id,),
    )
    source_subrules = cur.fetchall()

    subrule_map: dict[int, int] = {}
    for source_subrule in source_subrules:
        source_subrule_id = int(source_subrule[0])
        cur.execute(
            """
            insert into etiquetado.subetiqueta_regla (
                id_regla_version,
                id_subetiqueta,
                prioridad_evaluacion,
                tipo_evaluacion
            ) values (%s, %s, %s, %s)
            returning id
            """,
            (
                new_regla_version_id,
                source_subrule[1],
                source_subrule[2],
                source_subrule[3],
            ),
        )
        subrule_map[source_subrule_id] = int(cur.fetchone()[0])
        stats["subetiquetas_count"] += 1

    group_map: dict[int, int] = {}
    for source_subrule_id, new_subrule_id in subrule_map.items():
        cur.execute(
            """
            select id, operador_grupo, orden_grupo
            from etiquetado.grupo_condicion
            where id_subetiqueta_regla = %s
            order by orden_grupo, id
            """,
            (source_subrule_id,),
        )
        groups = cur.fetchall()
        for group in groups:
            source_group_id = int(group[0])
            cur.execute(
                """
                insert into etiquetado.grupo_condicion (
                    id_subetiqueta_regla,
                    operador_grupo,
                    orden_grupo
                ) values (%s, %s, %s)
                returning id
                """,
                (new_subrule_id, group[1], group[2]),
            )
            group_map[source_group_id] = int(cur.fetchone()[0])
            stats["grupos_count"] += 1

    condition_map: dict[int, int] = {}
    for source_group_id, new_group_id in group_map.items():
        cur.execute(
            """
            select id, id_campo_catalogo, operador, valor_numerico, valor_texto_directo, orden_condicion
            from etiquetado.condicion
            where id_grupo_condicion = %s
            order by orden_condicion, id
            """,
            (source_group_id,),
        )
        conditions = cur.fetchall()
        for condition in conditions:
            source_condition_id = int(condition[0])
            cur.execute(
                """
                insert into etiquetado.condicion (
                    id_grupo_condicion,
                    id_campo_catalogo,
                    operador,
                    valor_numerico,
                    valor_texto_directo,
                    orden_condicion
                ) values (%s, %s, %s, %s, %s, %s)
                returning id
                """,
                (
                    new_group_id,
                    condition[1],
                    condition[2],
                    condition[3],
                    condition[4],
                    condition[5],
                ),
            )
            condition_map[source_condition_id] = int(cur.fetchone()[0])
            stats["condiciones_count"] += 1

    for source_condition_id, new_condition_id in condition_map.items():
        cur.execute(
            """
            select texto_busqueda, tipo_match
            from etiquetado.condicion_valor_texto
            where id_condicion = %s
            order by id
            """,
            (source_condition_id,),
        )
        text_values = cur.fetchall()
        for text_value in text_values:
            cur.execute(
                """
                insert into etiquetado.condicion_valor_texto (
                    id_condicion,
                    texto_busqueda,
                    tipo_match
                ) values (%s, %s, %s)
                """,
                (new_condition_id, text_value[0], text_value[1]),
            )
            stats["valores_texto_count"] += 1

    return stats


def _insert_subetiquetas_payload(
    cur,
    id_etiqueta: int,
    new_regla_version_id: int,
    subetiquetas: list[SubetiquetaReglaInput],
) -> dict[str, int]:
    stats = {
        "subetiquetas_count": 0,
        "grupos_count": 0,
        "condiciones_count": 0,
        "valores_texto_count": 0,
    }

    if not subetiquetas:
        raise HTTPException(status_code=400, detail="subetiquetas no puede ser vacio")

    cur.execute(
        """
        select id
        from etiquetado.subetiqueta
        where id_etiqueta = %s
        """,
        (id_etiqueta,),
    )
    valid_subetiqueta_ids = {int(row[0]) for row in cur.fetchall()}

    seen_subetiqueta_ids: set[int] = set()
    seen_prioridades: set[int] = set()

    for sub in subetiquetas:
        if sub.id_subetiqueta not in valid_subetiqueta_ids:
            raise HTTPException(
                status_code=400,
                detail=f"La subetiqueta {sub.id_subetiqueta} no pertenece a la etiqueta {id_etiqueta}",
            )

        if sub.id_subetiqueta in seen_subetiqueta_ids:
            raise HTTPException(
                status_code=400,
                detail=f"subetiqueta duplicada en payload: {sub.id_subetiqueta}",
            )
        seen_subetiqueta_ids.add(sub.id_subetiqueta)

        if sub.prioridad_evaluacion in seen_prioridades:
            raise HTTPException(
                status_code=400,
                detail=f"prioridad_evaluacion duplicada en payload: {sub.prioridad_evaluacion}",
            )
        seen_prioridades.add(sub.prioridad_evaluacion)

        tipo_evaluacion = _validate_tipo_evaluacion(sub.tipo_evaluacion)

        if tipo_evaluacion == "FIRST_MATCH" and not sub.grupos_condicion:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"La subetiqueta {sub.id_subetiqueta} requiere al menos un grupo_condicion "
                    "cuando tipo_evaluacion es FIRST_MATCH"
                ),
            )

        cur.execute(
            """
            insert into etiquetado.subetiqueta_regla (
                id_regla_version,
                id_subetiqueta,
                prioridad_evaluacion,
                tipo_evaluacion
            ) values (%s, %s, %s, %s)
            returning id
            """,
            (
                new_regla_version_id,
                sub.id_subetiqueta,
                sub.prioridad_evaluacion,
                tipo_evaluacion,
            ),
        )
        subrule_id = int(cur.fetchone()[0])
        stats["subetiquetas_count"] += 1

        for group in sorted(sub.grupos_condicion, key=lambda item: item.orden_grupo):
            operador_grupo = _validate_operador_grupo(group.operador_grupo)
            cur.execute(
                """
                insert into etiquetado.grupo_condicion (
                    id_subetiqueta_regla,
                    operador_grupo,
                    orden_grupo
                ) values (%s, %s, %s)
                returning id
                """,
                (subrule_id, operador_grupo, group.orden_grupo),
            )
            group_id = int(cur.fetchone()[0])
            stats["grupos_count"] += 1

            if not group.condiciones:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f"El grupo_condicion {group.orden_grupo} de subetiqueta {sub.id_subetiqueta} "
                        "no tiene condiciones"
                    ),
                )

            for condition in sorted(group.condiciones, key=lambda item: item.orden_condicion):
                cur.execute(
                    """
                    insert into etiquetado.condicion (
                        id_grupo_condicion,
                        id_campo_catalogo,
                        operador,
                        valor_numerico,
                        valor_texto_directo,
                        orden_condicion
                    ) values (%s, %s, %s, %s, %s, %s)
                    returning id
                    """,
                    (
                        group_id,
                        condition.id_campo_catalogo,
                        condition.operador.strip(),
                        condition.valor_numerico,
                        condition.valor_texto_directo,
                        condition.orden_condicion,
                    ),
                )
                condition_id = int(cur.fetchone()[0])
                stats["condiciones_count"] += 1

                for text_value in condition.valores_texto:
                    cur.execute(
                        """
                        insert into etiquetado.condicion_valor_texto (
                            id_condicion,
                            texto_busqueda,
                            tipo_match
                        ) values (%s, %s, %s)
                        """,
                        (
                            condition_id,
                            text_value.texto_busqueda.strip(),
                            _validate_tipo_match(text_value.tipo_match),
                        ),
                    )
                    stats["valores_texto_count"] += 1

    return stats


def _normalize_lookup_key(value: str | None) -> str:
    text = value or ""
    normalized = unicodedata.normalize("NFKD", text)
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^A-Z0-9]+", "", ascii_text.upper())


def _to_formula_token(value: str | None) -> str:
    text = value or ""
    normalized = unicodedata.normalize("NFKD", text)
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii")
    token = re.sub(r"[^A-Z0-9]+", "_", ascii_text.upper()).strip("_")
    return token


def _to_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _load_target_rule_versions(cur, payload: RecalculoEtiquetadoRequest) -> list[dict[str, Any]]:
    if payload.id_regla_version is not None:
        cur.execute(
            """
            select rv.id, rv.id_etiqueta, rv.version_numero, rv.estado, e.codigo, e.nombre_visible
            from etiquetado.regla_version rv
            inner join etiquetado.etiqueta e on e.id = rv.id_etiqueta
            where rv.id = %s
            """,
            (payload.id_regla_version,),
        )
        row = cur.fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="id_regla_version no encontrado")

        result = {
            "id": int(row[0]),
            "id_etiqueta": int(row[1]),
            "version_numero": int(row[2]),
            "estado": str(row[3]),
            "etiqueta_codigo": str(row[4]),
            "etiqueta_nombre": str(row[5]),
        }
        if payload.id_etiqueta is not None and payload.id_etiqueta != result["id_etiqueta"]:
            raise HTTPException(
                status_code=400,
                detail="id_regla_version no pertenece al id_etiqueta enviado",
            )
        return [result]

    if payload.id_etiqueta is not None:
        cur.execute(
            """
            select rv.id, rv.id_etiqueta, rv.version_numero, rv.estado, e.codigo, e.nombre_visible
            from etiquetado.regla_version rv
            inner join etiquetado.etiqueta e on e.id = rv.id_etiqueta
            where rv.id_etiqueta = %s
              and rv.estado = 'PUBLICADA'
            order by rv.version_numero desc, rv.id desc
            limit 1
            """,
            (payload.id_etiqueta,),
        )
        row = cur.fetchone()
        if row is None:
            raise HTTPException(
                status_code=404,
                detail="No existe version PUBLICADA para la etiqueta solicitada",
            )
        return [
            {
                "id": int(row[0]),
                "id_etiqueta": int(row[1]),
                "version_numero": int(row[2]),
                "estado": str(row[3]),
                "etiqueta_codigo": str(row[4]),
                "etiqueta_nombre": str(row[5]),
            }
        ]

    cur.execute(
        """
        with latest as (
            select
                rv.id,
                rv.id_etiqueta,
                rv.version_numero,
                rv.estado,
                row_number() over (
                    partition by rv.id_etiqueta
                    order by rv.version_numero desc, rv.id desc
                ) as rn
            from etiquetado.regla_version rv
            where rv.estado = 'PUBLICADA'
        )
        select l.id, l.id_etiqueta, l.version_numero, l.estado, e.codigo, e.nombre_visible
        from latest l
        inner join etiquetado.etiqueta e on e.id = l.id_etiqueta
        where l.rn = 1
        order by l.id_etiqueta
        """
    )
    rows = cur.fetchall()
    if not rows:
        raise HTTPException(status_code=404, detail="No existen versiones PUBLICADAS para recalculo")

    return [
        {
            "id": int(row[0]),
            "id_etiqueta": int(row[1]),
            "version_numero": int(row[2]),
            "estado": str(row[3]),
            "etiqueta_codigo": str(row[4]),
            "etiqueta_nombre": str(row[5]),
        }
        for row in rows
    ]


def _build_ingredient_scope(cur, payload: RecalculoEtiquetadoRequest) -> dict[int, dict[str, Any]]:
    where: list[str] = []
    params: list[Any] = []

    if payload.id_ingrediente is not None:
        where.append("i.id = %s")
        params.append(payload.id_ingrediente)
    if payload.solo_activos:
        where.append("i.activo = true")

    where_sql = f"where {' and '.join(where)}" if where else ""
    limit_sql = ""
    if payload.max_ingredientes is not None:
        limit_sql = "limit %s"
        params.append(payload.max_ingredientes)

    cur.execute(
        f"""
        select
            i.id as ingrediente_id,
            i.nombre as ingrediente_nombre,
            i.activo as ingrediente_activo,
            ic.*
        from nutricion.ingrediente i
        left join nutricion.ingrediente_composicion ic on ic.id_ingrediente = i.id
        {where_sql}
        order by i.id
        {limit_sql}
        """,
        params,
    )
    rows = cur.fetchall()
    cols = [desc[0] for desc in cur.description]

    ingredients: dict[int, dict[str, Any]] = {}
    for row in rows:
        raw = dict(zip(cols, row, strict=False))
        ingrediente_id = int(raw["ingrediente_id"])

        lookup: dict[str, Any] = {}
        formula_values: dict[str, float] = {}
        for key, value in raw.items():
            norm = _normalize_lookup_key(key)
            if norm and norm not in lookup:
                lookup[norm] = value

            token = _to_formula_token(key)
            f_value = _to_float(value)
            if token and f_value is not None and token not in formula_values:
                formula_values[token] = f_value

        ingredients[ingrediente_id] = {
            "row": raw,
            "lookup": lookup,
            "metric_lookup": {},
            "formula_values": formula_values,
        }

    if not ingredients:
        return {}

    ingredient_ids = sorted(ingredients.keys())
    cur.execute(
        """
        select im.id_ingrediente, md.codigo, md.nombre, im.valor_numerico
        from nutricion.ingrediente_metrica im
        inner join nutricion.metrica_def md on md.id = im.id_metrica
        where im.id_ingrediente = any(%s)
        """,
        (ingredient_ids,),
    )
    for ingredient_id, metric_code, metric_name, metric_value in cur.fetchall():
        rid = int(ingredient_id)
        value = _to_float(metric_value)
        if rid not in ingredients or value is None:
            continue

        code = str(metric_code)
        name = str(metric_name)
        m_lookup: dict[str, Any] = ingredients[rid]["metric_lookup"]
        m_lookup[_normalize_lookup_key(code)] = value
        m_lookup[_normalize_lookup_key(name)] = value

        token_code = _to_formula_token(code)
        token_name = _to_formula_token(name)
        if token_code:
            ingredients[rid]["formula_values"][token_code] = value
        if token_name:
            ingredients[rid]["formula_values"][token_name] = value

    return ingredients


def _load_rule_structure(cur, id_regla_version: int) -> list[dict[str, Any]]:
    cur.execute(
        """
        select
            sr.id,
            sr.id_subetiqueta,
            sr.prioridad_evaluacion,
            sr.tipo_evaluacion,
            s.codigo,
            s.nombre_visible
        from etiquetado.subetiqueta_regla sr
        inner join etiquetado.subetiqueta s on s.id = sr.id_subetiqueta
        where sr.id_regla_version = %s
        order by sr.prioridad_evaluacion, sr.id
        """,
        (id_regla_version,),
    )
    rows = cur.fetchall()
    if not rows:
        return []

    subrules: list[dict[str, Any]] = []
    subrule_by_id: dict[int, dict[str, Any]] = {}
    for row in rows:
        subrule = {
            "id": int(row[0]),
            "id_subetiqueta": int(row[1]),
            "prioridad_evaluacion": int(row[2]),
            "tipo_evaluacion": str(row[3]),
            "subetiqueta_codigo": str(row[4]),
            "subetiqueta_nombre": str(row[5]),
            "groups": [],
        }
        subrules.append(subrule)
        subrule_by_id[subrule["id"]] = subrule

    subrule_ids = [item["id"] for item in subrules]
    cur.execute(
        """
        select id, id_subetiqueta_regla, operador_grupo, orden_grupo
        from etiquetado.grupo_condicion
        where id_subetiqueta_regla = any(%s)
        order by id_subetiqueta_regla, orden_grupo, id
        """,
        (subrule_ids,),
    )
    groups = cur.fetchall()

    group_map: dict[int, dict[str, Any]] = {}
    for row in groups:
        group = {
            "id": int(row[0]),
            "id_subetiqueta_regla": int(row[1]),
            "operador_grupo": str(row[2]),
            "orden_grupo": int(row[3]),
            "conditions": [],
        }
        group_map[group["id"]] = group
        subrule_by_id[group["id_subetiqueta_regla"]]["groups"].append(group)

    if not group_map:
        return subrules

    cur.execute(
        """
        select
            c.id,
            c.id_grupo_condicion,
            c.id_campo_catalogo,
            c.operador,
            c.valor_numerico,
            c.valor_texto_directo,
            c.orden_condicion,
            cc.codigo,
            cc.origen_tipo,
            cc.referencia_columna,
            cc.tipo_dato
        from etiquetado.condicion c
        inner join etiquetado.campo_catalogo cc on cc.id = c.id_campo_catalogo
        where c.id_grupo_condicion = any(%s)
        order by c.id_grupo_condicion, c.orden_condicion, c.id
        """,
        (list(group_map.keys()),),
    )
    condition_rows = cur.fetchall()

    condition_map: dict[int, dict[str, Any]] = {}
    for row in condition_rows:
        condition = {
            "id": int(row[0]),
            "id_grupo_condicion": int(row[1]),
            "id_campo_catalogo": int(row[2]),
            "operador": str(row[3]),
            "valor_numerico": row[4],
            "valor_texto_directo": row[5],
            "orden_condicion": int(row[6]),
            "campo_codigo": str(row[7]),
            "campo_origen_tipo": str(row[8]),
            "campo_referencia_columna": str(row[9]),
            "campo_tipo_dato": str(row[10]),
            "valores_texto": [],
        }
        condition_map[condition["id"]] = condition
        group_map[condition["id_grupo_condicion"]]["conditions"].append(condition)

    if not condition_map:
        return subrules

    cur.execute(
        """
        select id_condicion, texto_busqueda, tipo_match
        from etiquetado.condicion_valor_texto
        where id_condicion = any(%s)
        order by id_condicion, id
        """,
        (list(condition_map.keys()),),
    )
    for condition_id, text_value, match_type in cur.fetchall():
        cid = int(condition_id)
        if cid not in condition_map:
            continue
        condition_map[cid]["valores_texto"].append(
            {
                "texto_busqueda": str(text_value),
                "tipo_match": str(match_type),
            }
        )

    return subrules


def _safe_eval_formula(expression: str, names: dict[str, float]) -> bool:
    allowed_binary_ops = {
        ast.Add: add,
        ast.Sub: sub,
        ast.Mult: mul,
        ast.Div: truediv,
    }

    def _eval(node: ast.AST) -> float | bool:
        if isinstance(node, ast.Expression):
            return _eval(node.body)
        if isinstance(node, ast.Constant):
            if isinstance(node.value, (int, float)):
                return float(node.value)
            raise ValueError("Constante no numerica en formula")
        if isinstance(node, ast.Name):
            if node.id not in names:
                raise ValueError(f"Variable no encontrada en formula: {node.id}")
            return float(names[node.id])
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
            value = float(_eval(node.operand))
            return value if isinstance(node.op, ast.UAdd) else -value
        if isinstance(node, ast.BinOp):
            op_type = type(node.op)
            if op_type not in allowed_binary_ops:
                raise ValueError("Operador binario no permitido")
            left = float(_eval(node.left))
            right = float(_eval(node.right))
            if op_type is ast.Div and right == 0.0:
                raise ValueError("Division por cero en formula")
            return allowed_binary_ops[op_type](left, right)
        if isinstance(node, ast.Compare):
            left = float(_eval(node.left))
            result = True
            for op, comparator in zip(node.ops, node.comparators, strict=False):
                right = float(_eval(comparator))
                if isinstance(op, ast.Gt):
                    current = left > right
                elif isinstance(op, ast.GtE):
                    current = left >= right
                elif isinstance(op, ast.Lt):
                    current = left < right
                elif isinstance(op, ast.LtE):
                    current = left <= right
                elif isinstance(op, ast.Eq):
                    current = left == right
                elif isinstance(op, ast.NotEq):
                    current = left != right
                else:
                    raise ValueError("Comparador no permitido en formula")
                result = result and current
                left = right
            return result
        if isinstance(node, ast.BoolOp):
            if isinstance(node.op, ast.And):
                return all(bool(_eval(value)) for value in node.values)
            if isinstance(node.op, ast.Or):
                return any(bool(_eval(value)) for value in node.values)
            raise ValueError("Operador booleano no permitido")
        raise ValueError("Expresion no permitida en formula")

    parsed = ast.parse(expression, mode="eval")
    return bool(_eval(parsed))


def _text_match(value: str, text: str, match_type: str) -> bool:
    normalized_match = _normalize_upper(match_type)
    haystack = value.lower()
    needle = text.lower()

    if normalized_match == "CONTIENE":
        return needle in haystack
    if normalized_match == "IGUAL":
        return haystack == needle
    if normalized_match == "INICIA":
        return haystack.startswith(needle)
    if normalized_match == "TERMINA":
        return haystack.endswith(needle)
    if normalized_match == "REGEX":
        try:
            return re.search(text, value, flags=re.IGNORECASE) is not None
        except re.error:
            return False
    return False


def _resolve_condition_value(condition: dict[str, Any], ingredient_ctx: dict[str, Any]) -> Any:
    reference_column = str(condition["campo_referencia_columna"])
    field_code = str(condition["campo_codigo"])

    if _normalize_upper(str(condition["campo_origen_tipo"])) == "METRICA":
        metric_lookup: dict[str, Any] = ingredient_ctx["metric_lookup"]
        for key in (reference_column, field_code):
            normalized = _normalize_lookup_key(key)
            if normalized in metric_lookup:
                return metric_lookup[normalized]
        return None

    lookup: dict[str, Any] = ingredient_ctx["lookup"]
    for key in (reference_column, field_code):
        normalized = _normalize_lookup_key(key)
        if normalized in lookup:
            return lookup[normalized]
    return None


def _evaluate_condition(condition: dict[str, Any], ingredient_ctx: dict[str, Any]) -> tuple[bool, float | None, dict[str, Any]]:
    operator = _normalize_upper(str(condition["operador"]))
    resolved_value = _resolve_condition_value(condition, ingredient_ctx)

    detail: dict[str, Any] = {
        "condicion_id": condition["id"],
        "campo_codigo": condition["campo_codigo"],
        "referencia_columna": condition["campo_referencia_columna"],
        "operador": operator,
        "valor_referencia": condition.get("valor_numerico"),
        "valor_texto_referencia": condition.get("valor_texto_directo"),
        "valor_observado": resolved_value,
    }

    if operator == "FORMULA_GT":
        expression = (condition.get("valor_texto_directo") or "").strip()
        if not expression:
            detail["error"] = "formula vacia"
            return False, None, detail
        try:
            result = _safe_eval_formula(expression, ingredient_ctx["formula_values"])
        except Exception as exc:
            detail["error"] = str(exc)
            return False, None, detail
        detail["resultado"] = result
        return result, None, detail

    if operator in {"CONTIENE", "IGUAL", "INICIA", "TERMINA", "REGEX"}:
        observed_text = "" if resolved_value is None else str(resolved_value)
        text_references: list[dict[str, str]] = []
        if condition["valores_texto"]:
            text_references = [
                {
                    "texto_busqueda": str(item["texto_busqueda"]),
                    "tipo_match": _normalize_upper(str(item["tipo_match"])),
                }
                for item in condition["valores_texto"]
            ]
        elif condition.get("valor_texto_directo"):
            text_references = [
                {
                    "texto_busqueda": str(condition["valor_texto_directo"]),
                    "tipo_match": operator,
                }
            ]

        result = any(
            _text_match(observed_text, item["texto_busqueda"], item["tipo_match"])
            for item in text_references
        )
        detail["textos_evaluados"] = text_references
        detail["resultado"] = result
        return result, None, detail

    left = _to_float(resolved_value)
    right = _to_float(condition.get("valor_numerico"))
    if left is None or right is None:
        if operator in {"=", "==", "!=", "<>"}:
            observed_text = "" if resolved_value is None else str(resolved_value).strip().lower()
            reference_text = str(condition.get("valor_texto_directo") or "").strip().lower()
            if reference_text:
                result = observed_text == reference_text
                if operator in {"!=", "<>"}:
                    result = not result
                detail["resultado"] = result
                return result, None, detail
        detail["resultado"] = False
        detail["error"] = "valor numerico faltante"
        return False, None, detail

    if operator == ">":
        result = left > right
    elif operator == ">=":
        result = left >= right
    elif operator == "<":
        result = left < right
    elif operator == "<=":
        result = left <= right
    elif operator in {"=", "=="}:
        result = left == right
    elif operator in {"!=", "<>"}:
        result = left != right
    else:
        detail["resultado"] = False
        detail["error"] = f"operador no soportado: {operator}"
        return False, None, detail

    detail["resultado"] = result
    return result, left, detail


def _evaluate_subrule(subrule: dict[str, Any], ingredient_ctx: dict[str, Any]) -> tuple[bool, float | None, dict[str, Any]]:
    groups = sorted(subrule["groups"], key=lambda item: item["orden_grupo"])
    if not groups:
        return False, None, {
            "subetiqueta_regla_id": subrule["id"],
            "subetiqueta_id": subrule["id_subetiqueta"],
            "detalle_grupos": [],
            "resultado": False,
        }

    aggregate_result: bool | None = None
    trigger_value: float | None = None
    group_details: list[dict[str, Any]] = []

    for group in groups:
        condition_details: list[dict[str, Any]] = []
        condition_results: list[bool] = []

        for condition in sorted(group["conditions"], key=lambda item: item["orden_condicion"]):
            condition_result, observed_value, condition_detail = _evaluate_condition(condition, ingredient_ctx)
            condition_results.append(condition_result)
            condition_details.append(condition_detail)
            if trigger_value is None and condition_result and observed_value is not None:
                trigger_value = observed_value

        group_result = all(condition_results)
        group_details.append(
            {
                "grupo_condicion_id": group["id"],
                "operador_grupo": group["operador_grupo"],
                "orden_grupo": group["orden_grupo"],
                "resultado": group_result,
                "condiciones": condition_details,
            }
        )

        if aggregate_result is None:
            aggregate_result = group_result
        else:
            logical_operator = _normalize_upper(str(group["operador_grupo"]))
            if logical_operator == "OR":
                aggregate_result = bool(aggregate_result or group_result)
            else:
                aggregate_result = bool(aggregate_result and group_result)

    return bool(aggregate_result), trigger_value, {
        "subetiqueta_regla_id": subrule["id"],
        "subetiqueta_id": subrule["id_subetiqueta"],
        "detalle_grupos": group_details,
        "resultado": bool(aggregate_result),
    }


def _pick_winner_subrule(
    subrules: list[dict[str, Any]],
    ingredient_ctx: dict[str, Any],
) -> tuple[dict[str, Any] | None, float | None, dict[str, Any] | None]:
    else_candidate: dict[str, Any] | None = None
    else_detail: dict[str, Any] | None = None

    for subrule in subrules:
        eval_type = _normalize_upper(str(subrule["tipo_evaluacion"]))
        if eval_type == "ELSE":
            if else_candidate is None:
                else_candidate = subrule
                else_detail = {
                    "subetiqueta_regla_id": subrule["id"],
                    "subetiqueta_id": subrule["id_subetiqueta"],
                    "detalle_grupos": [],
                    "resultado": True,
                    "motivo": "ELSE",
                }
            continue

        matched, trigger_value, detail = _evaluate_subrule(subrule, ingredient_ctx)
        if matched:
            detail["motivo"] = "FIRST_MATCH"
            return subrule, trigger_value, detail

    if else_candidate is not None:
        return else_candidate, None, else_detail
    return None, None, None


def _build_structured_errors(error_messages: list[str]) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    pattern = re.compile(
        r"Error en version\s+(?P<version>\d+),\s+ingrediente\s+(?P<ingrediente>\d+):\s*(?P<mensaje>.*)",
        flags=re.IGNORECASE,
    )

    for message in error_messages[:300]:
        parsed = pattern.match(message)
        if parsed:
            output.append(
                {
                    "id_regla_version": int(parsed.group("version")),
                    "id_ingrediente": int(parsed.group("ingrediente")),
                    "mensaje": parsed.group("mensaje").strip() or message,
                }
            )
        else:
            output.append(
                {
                    "id_regla_version": None,
                    "id_ingrediente": None,
                    "mensaje": message,
                }
            )
    return output


def _log_recalculo_historial(
    cur,
    user_uuid: str | None,
    scope: str,
    payload: RecalculoEtiquetadoRequest,
    response: RecalculoEtiquetadoResponse,
) -> None:
    etiqueta_ids = sorted({str(item.id_etiqueta) for item in response.resultado_por_regla})
    regla_version_ids = sorted({str(item.id_regla_version) for item in response.resultado_por_regla})
    structured_errors = _build_structured_errors(response.mensajes_error)

    payload_nuevo = {
        "request": payload.model_dump(),
        "result": response.model_dump(),
        "meta": {
            "scope": scope,
            "etiqueta_ids": etiqueta_ids,
            "regla_version_ids": regla_version_ids,
            "structured_errors": structured_errors[:100],
            "recorded_at": datetime.now(UTC).isoformat(),
        },
    }

    detalle = (
        f"scope={scope}; dry_run={response.dry_run}; reglas={response.reglas_procesadas}; "
        f"ingredientes={response.ingredientes_en_alcance}; ins={response.insertados}; "
        f"upd={response.actualizados}; del={response.eliminados}; err={response.errores}"
    )

    cur.execute(
        """
        insert into seguridad.log_auditoria (
            id_usuario,
            accion,
            esquema_afectado,
            tabla_afectada,
            id_registro_afectado,
            detalle,
            payload_nuevo
        ) values (%s, %s, %s, %s, %s, %s, %s::jsonb)
        """,
        (
            user_uuid,
            "ETIQUETADO_RECALCULO",
            "etiquetado",
            "ingrediente_resultado_etiqueta",
            ",".join(regla_version_ids) if regla_version_ids else None,
            detalle,
            json.dumps(payload_nuevo, ensure_ascii=False),
        ),
    )


def _parse_int_list(values: Any) -> list[int]:
    if not isinstance(values, list):
        return []
    output: list[int] = []
    for value in values:
        if str(value).isdigit():
            output.append(int(value))
    return output


def _build_historial_item(
    *,
    id_log: int,
    id_usuario: str | None,
    fecha_registro: Any,
    payload_nuevo: dict[str, Any],
) -> RecalculoHistorialItem:
    request_data = payload_nuevo.get("request") or {}
    result_data = payload_nuevo.get("result") or {}
    meta_data = payload_nuevo.get("meta") or {}

    raw_errors = meta_data.get("structured_errors") or []
    parsed_errors: list[RecalculoErrorItem] = []
    if isinstance(raw_errors, list):
        for item in raw_errors[:20]:
            if not isinstance(item, dict):
                continue
            parsed_errors.append(
                RecalculoErrorItem(
                    id_ingrediente=item.get("id_ingrediente"),
                    id_regla_version=item.get("id_regla_version"),
                    mensaje=str(item.get("mensaje") or ""),
                )
            )

    fecha_iso = fecha_registro.isoformat() if fecha_registro is not None else ""

    return RecalculoHistorialItem(
        id_log=int(id_log),
        fecha_registro=fecha_iso,
        id_usuario=id_usuario,
        scope=str(meta_data.get("scope") or "desconocido"),
        dry_run=bool(result_data.get("dry_run", request_data.get("dry_run", False))),
        reglas_procesadas=int(result_data.get("reglas_procesadas", 0) or 0),
        ingredientes_en_alcance=int(result_data.get("ingredientes_en_alcance", 0) or 0),
        insertados=int(result_data.get("insertados", 0) or 0),
        actualizados=int(result_data.get("actualizados", 0) or 0),
        sin_cambios=int(result_data.get("sin_cambios", 0) or 0),
        eliminados=int(result_data.get("eliminados", 0) or 0),
        sin_resultado=int(result_data.get("sin_resultado", 0) or 0),
        errores=int(result_data.get("errores", 0) or 0),
        etiqueta_ids=_parse_int_list(meta_data.get("etiqueta_ids")),
        regla_version_ids=_parse_int_list(meta_data.get("regla_version_ids")),
        ultimos_errores=parsed_errors,
    )


@router.post("/config/etiquetas", response_model=EtiquetaNuevaResponse)
def post_crear_etiqueta_con_subetiquetas(
    payload: EtiquetaNuevaRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
):
    estado_regla_inicial = _validate_estado_regla(payload.estado_regla_inicial)

    etiqueta_codigo = _normalize_code(payload.codigo)
    etiqueta_nombre = payload.nombre_visible.strip()
    if not etiqueta_nombre:
        raise HTTPException(status_code=400, detail="nombre_visible es obligatorio")

    top_entries: list[dict[str, Any]] = []
    child_entries: list[dict[str, Any]] = []
    used_codes: set[str] = set()

    for sub in payload.subetiquetas:
        sub_codigo = _normalize_code(sub.codigo)
        sub_nombre = sub.nombre_visible.strip()
        if not sub_nombre:
            raise HTTPException(
                status_code=400,
                detail=f"nombre_visible invalido en subetiqueta {sub_codigo}",
            )

        if sub_codigo in used_codes:
            raise HTTPException(
                status_code=400,
                detail=f"Codigo duplicado en subetiquetas: {sub_codigo}",
            )
        used_codes.add(sub_codigo)

        sub_tipo = _validate_tipo_evaluacion(sub.tipo_evaluacion)
        top_entries.append(
            {
                "codigo": sub_codigo,
                "nombre_visible": sub_nombre,
                "prioridad": int(sub.prioridad),
                "descripcion": sub.descripcion,
                "activa": bool(sub.activa),
                "tipo_evaluacion": sub_tipo,
                "nivel": 1,
                "parent_codigo": None,
            }
        )

        for child in sub.subsubetiquetas:
            child_nombre = child.nombre_visible.strip()
            if not child_nombre:
                raise HTTPException(
                    status_code=400,
                    detail=f"nombre_visible invalido en subsubetiqueta de {sub_codigo}",
                )

            child_suffix = _normalize_code(child.codigo)
            child_codigo = _normalize_code(f"{sub_codigo}_{child_suffix}")
            if child_codigo in used_codes:
                raise HTTPException(
                    status_code=400,
                    detail=f"Codigo duplicado en subsubetiquetas: {child_codigo}",
                )
            used_codes.add(child_codigo)

            child_tipo = _validate_tipo_evaluacion(child.tipo_evaluacion)
            child_entries.append(
                {
                    "codigo": child_codigo,
                    "nombre_visible": child_nombre,
                    "prioridad": int(sub.prioridad) * 100 + int(child.prioridad_relativa),
                    "descripcion": child.descripcion,
                    "activa": bool(child.activa),
                    "tipo_evaluacion": child_tipo,
                    "nivel": 2,
                    "parent_codigo": sub_codigo,
                }
            )

    with db_cursor() as cur:
        cur.execute(
            """
            select 1
            from etiquetado.etiqueta
            where codigo = %s
            limit 1
            """,
            (etiqueta_codigo,),
        )
        if cur.fetchone() is not None:
            raise HTTPException(
                status_code=409,
                detail=f"Ya existe una etiqueta con codigo {etiqueta_codigo}",
            )

        creada_por = _resolve_usuario_uuid(cur, user)

        cur.execute(
            """
            insert into etiquetado.etiqueta (
                codigo,
                nombre_visible,
                descripcion,
                activa,
                creada_por,
                created_at
            ) values (%s, %s, %s, %s, %s, now())
            returning id
            """,
            (
                etiqueta_codigo,
                etiqueta_nombre,
                payload.descripcion,
                payload.activa,
                creada_por,
            ),
        )
        id_etiqueta = int(cur.fetchone()[0])

        cur.execute(
            """
            select count(*)
            from information_schema.columns
            where table_schema = 'etiquetado'
              and table_name = 'subetiqueta'
              and column_name in ('id_subetiqueta_padre', 'nivel')
            """
        )
        has_hierarchy_columns = int(cur.fetchone()[0] or 0) == 2

        created_subs: list[EtiquetaNuevaSubetiquetaResult] = []
        subrule_map: dict[int, str] = {}
        sub_id_by_code: dict[str, int] = {}

        for entry in sorted(top_entries, key=lambda item: (int(item["prioridad"]), str(item["codigo"]))):
            if has_hierarchy_columns:
                cur.execute(
                    """
                    insert into etiquetado.subetiqueta (
                        id_etiqueta,
                        codigo,
                        nombre_visible,
                        prioridad,
                        descripcion,
                        activa,
                        id_subetiqueta_padre,
                        nivel
                    ) values (%s, %s, %s, %s, %s, %s, %s, %s)
                    returning id
                    """,
                    (
                        id_etiqueta,
                        entry["codigo"],
                        entry["nombre_visible"],
                        entry["prioridad"],
                        entry["descripcion"],
                        entry["activa"],
                        None,
                        1,
                    ),
                )
            else:
                cur.execute(
                    """
                    insert into etiquetado.subetiqueta (
                        id_etiqueta,
                        codigo,
                        nombre_visible,
                        prioridad,
                        descripcion,
                        activa
                    ) values (%s, %s, %s, %s, %s, %s)
                    returning id
                    """,
                    (
                        id_etiqueta,
                        entry["codigo"],
                        entry["nombre_visible"],
                        entry["prioridad"],
                        entry["descripcion"],
                        entry["activa"],
                    ),
                )

            id_subetiqueta = int(cur.fetchone()[0])
            sub_id_by_code[str(entry["codigo"])] = id_subetiqueta

            created_subs.append(
                EtiquetaNuevaSubetiquetaResult(
                    id_subetiqueta=id_subetiqueta,
                    id_subetiqueta_padre=None,
                    codigo=str(entry["codigo"]),
                    nombre_visible=str(entry["nombre_visible"]),
                    prioridad=int(entry["prioridad"]),
                    nivel=int(entry["nivel"]),
                    parent_codigo=entry["parent_codigo"],
                )
            )
            subrule_map[id_subetiqueta] = str(entry["tipo_evaluacion"])

        for entry in sorted(child_entries, key=lambda item: (int(item["prioridad"]), str(item["codigo"]))):
            parent_codigo = str(entry["parent_codigo"])
            id_subetiqueta_padre = sub_id_by_code.get(parent_codigo)
            if id_subetiqueta_padre is None:
                raise HTTPException(
                    status_code=500,
                    detail=f"No se encontro subetiqueta padre para {entry['codigo']}",
                )

            if has_hierarchy_columns:
                cur.execute(
                    """
                    insert into etiquetado.subetiqueta (
                        id_etiqueta,
                        codigo,
                        nombre_visible,
                        prioridad,
                        descripcion,
                        activa,
                        id_subetiqueta_padre,
                        nivel
                    ) values (%s, %s, %s, %s, %s, %s, %s, %s)
                    returning id
                    """,
                    (
                        id_etiqueta,
                        entry["codigo"],
                        entry["nombre_visible"],
                        entry["prioridad"],
                        entry["descripcion"],
                        entry["activa"],
                        id_subetiqueta_padre,
                        2,
                    ),
                )
            else:
                cur.execute(
                    """
                    insert into etiquetado.subetiqueta (
                        id_etiqueta,
                        codigo,
                        nombre_visible,
                        prioridad,
                        descripcion,
                        activa
                    ) values (%s, %s, %s, %s, %s, %s)
                    returning id
                    """,
                    (
                        id_etiqueta,
                        entry["codigo"],
                        entry["nombre_visible"],
                        entry["prioridad"],
                        entry["descripcion"],
                        entry["activa"],
                    ),
                )

            id_subetiqueta = int(cur.fetchone()[0])
            sub_id_by_code[str(entry["codigo"])] = id_subetiqueta

            created_subs.append(
                EtiquetaNuevaSubetiquetaResult(
                    id_subetiqueta=id_subetiqueta,
                    id_subetiqueta_padre=id_subetiqueta_padre,
                    codigo=str(entry["codigo"]),
                    nombre_visible=str(entry["nombre_visible"]),
                    prioridad=int(entry["prioridad"]),
                    nivel=int(entry["nivel"]),
                    parent_codigo=entry["parent_codigo"],
                )
            )
            subrule_map[id_subetiqueta] = str(entry["tipo_evaluacion"])

        id_regla_version: int | None = None
        version_numero: int | None = None
        if payload.crear_regla_inicial:
            cur.execute(
                """
                select coalesce(max(version_numero), 0) + 1
                from etiquetado.regla_version
                where id_etiqueta = %s
                """,
                (id_etiqueta,),
            )
            version_numero = int(cur.fetchone()[0])

            publicada_por = creada_por if estado_regla_inicial == "PUBLICADA" else None
            fecha_publicacion_sql = "now()" if estado_regla_inicial == "PUBLICADA" else "NULL"

            cur.execute(
                f"""
                insert into etiquetado.regla_version (
                    id_etiqueta,
                    version_numero,
                    estado,
                    observacion,
                    publicada_por,
                    fecha_publicacion
                ) values (%s, %s, %s, %s, %s, {fecha_publicacion_sql})
                returning id
                """,
                (
                    id_etiqueta,
                    version_numero,
                    estado_regla_inicial,
                    "Version inicial creada desde UI de etiquetas automaticas",
                    publicada_por,
                ),
            )
            id_regla_version = int(cur.fetchone()[0])

            for priority_idx, sub in enumerate(sorted(created_subs, key=lambda item: (item.prioridad, item.id_subetiqueta)), start=1):
                cur.execute(
                    """
                    insert into etiquetado.subetiqueta_regla (
                        id_regla_version,
                        id_subetiqueta,
                        prioridad_evaluacion,
                        tipo_evaluacion
                    ) values (%s, %s, %s, %s)
                    """,
                    (
                        id_regla_version,
                        sub.id_subetiqueta,
                        priority_idx,
                        subrule_map[sub.id_subetiqueta],
                    ),
                )

    return EtiquetaNuevaResponse(
        id_etiqueta=id_etiqueta,
        codigo=etiqueta_codigo,
        nombre_visible=etiqueta_nombre,
        id_regla_version_inicial=id_regla_version,
        version_numero_inicial=version_numero,
        subetiquetas_creadas=created_subs,
    )


@router.get("/auditoria", response_model=AuditoriaIngredienteResponse)
def get_auditoria_ingredientes(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    search: str | None = Query(default=None),
    id_etiqueta: int | None = Query(default=None, ge=1),
    id_subetiqueta: int | None = Query(default=None, ge=1),
    _=Depends(require_roles("admin", "nutricionista")),
):
    where_sql, where_params = _build_filters(search, id_etiqueta, id_subetiqueta)
    offset = (page - 1) * page_size

    count_sql = f"""
        SELECT COUNT(*)
        FROM etiquetado.ingrediente_resultado_etiqueta ire
        INNER JOIN nutricion.ingrediente i ON i.id = ire.id_ingrediente
        {where_sql}
    """

    data_sql = f"""
        SELECT
            i.id AS ingrediente_id,
            i.nombre AS ingrediente_nombre,
            e.id AS etiqueta_id,
            e.codigo AS etiqueta_codigo,
            e.nombre_visible AS etiqueta_nombre,
            s.id AS subetiqueta_id,
            s.codigo AS subetiqueta_codigo,
            s.nombre_visible AS subetiqueta_nombre,
            rv.id AS regla_version_id,
            rv.version_numero AS regla_version_numero,
            rv.estado AS regla_estado,
            sr.id AS subetiqueta_regla_id,
            sr.prioridad_evaluacion,
            sr.tipo_evaluacion,
            ic.energia_kcal,
            ic.proteinas_g,
            ic.hidratos_carbono_g,
            ic.grasa_total_g,
            ic.fibra_vegetal_g,
            ic.sodio_mg,
            ic.calcio_mg,
            ic.hierro_mg,
            ire.fecha_calculo,
            ire.valor_disparador,
            ire.detalle_evaluacion,
            COALESCE(condiciones.items, '[]'::jsonb) AS condiciones
        FROM etiquetado.ingrediente_resultado_etiqueta ire
        INNER JOIN nutricion.ingrediente i ON i.id = ire.id_ingrediente
        LEFT JOIN nutricion.ingrediente_composicion ic ON ic.id_ingrediente = i.id
        INNER JOIN etiquetado.etiqueta e ON e.id = ire.id_etiqueta
        INNER JOIN etiquetado.subetiqueta s ON s.id = ire.id_subetiqueta
        INNER JOIN etiquetado.regla_version rv ON rv.id = ire.id_regla_version
        LEFT JOIN etiquetado.subetiqueta_regla sr
            ON sr.id_regla_version = ire.id_regla_version
           AND sr.id_subetiqueta = ire.id_subetiqueta
        LEFT JOIN LATERAL (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'grupo_condicion_id', gc.id,
                    'operador_grupo', gc.operador_grupo,
                    'orden_grupo', gc.orden_grupo,
                    'condicion_id', c.id,
                    'campo_catalogo_id', c.id_campo_catalogo,
                    'operador', c.operador,
                    'valor_numerico', c.valor_numerico,
                    'valor_texto_directo', c.valor_texto_directo,
                    'orden_condicion', c.orden_condicion,
                    'textos', COALESCE(cvt.textos, '[]'::jsonb)
                )
                ORDER BY gc.orden_grupo, c.orden_condicion
            ) AS items
            FROM etiquetado.grupo_condicion gc
            INNER JOIN etiquetado.condicion c ON c.id_grupo_condicion = gc.id
            LEFT JOIN LATERAL (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', cvt.id,
                        'texto_busqueda', cvt.texto_busqueda,
                        'tipo_match', cvt.tipo_match
                    )
                    ORDER BY cvt.id
                ) AS textos
                FROM etiquetado.condicion_valor_texto cvt
                WHERE cvt.id_condicion = c.id
            ) cvt ON TRUE
            WHERE gc.id_subetiqueta_regla = sr.id
        ) condiciones ON TRUE
        {where_sql}
        ORDER BY i.nombre, e.nombre_visible
        OFFSET %s LIMIT %s
    """

    with db_cursor() as cur:
        cur.execute(count_sql, where_params)
        total = int(cur.fetchone()[0])

        cur.execute(data_sql, [*where_params, offset, page_size])
        rows = cur.fetchall()
        cols = [desc[0] for desc in cur.description]

    items: list[AuditoriaIngredienteRow] = []
    for row in rows:
        payload = dict(zip(cols, row, strict=False))
        payload["fecha_calculo"] = (
            payload["fecha_calculo"].isoformat()
            if payload.get("fecha_calculo") is not None
            else None
        )
        items.append(AuditoriaIngredienteRow.model_validate(payload))

    return AuditoriaIngredienteResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=items,
    )


@router.get("/auditoria/detalle", response_model=AuditoriaIngredienteDetalleResponse)
def get_auditoria_ingrediente_detalle(
    id_ingrediente: int = Query(ge=1),
    id_etiqueta: int = Query(ge=1),
    id_regla_version: int | None = Query(default=None, ge=1),
    _=Depends(require_roles("admin", "nutricionista")),
):
    where_parts = ["ire.id_ingrediente = %s", "ire.id_etiqueta = %s"]
    winner_params: list[Any] = [id_ingrediente, id_etiqueta]

    if id_regla_version is not None:
        where_parts.append("ire.id_regla_version = %s")
        winner_params.append(id_regla_version)

    winner_sql = f"""
        SELECT
            i.id AS ingrediente_id,
            i.nombre AS ingrediente_nombre,
            e.id AS etiqueta_id,
            e.codigo AS etiqueta_codigo,
            e.nombre_visible AS etiqueta_nombre,
            s.id AS subetiqueta_id,
            s.codigo AS subetiqueta_codigo,
            s.nombre_visible AS subetiqueta_nombre,
            rv.id AS regla_version_id,
            rv.version_numero AS regla_version_numero,
            rv.estado AS regla_estado,
            sr.id AS subetiqueta_regla_id,
            sr.prioridad_evaluacion,
            sr.tipo_evaluacion,
            ic.energia_kcal,
            ic.proteinas_g,
            ic.hidratos_carbono_g,
            ic.grasa_total_g,
            ic.fibra_vegetal_g,
            ic.sodio_mg,
            ic.calcio_mg,
            ic.hierro_mg,
            ire.fecha_calculo,
            ire.valor_disparador,
            ire.detalle_evaluacion,
            COALESCE(condiciones.items, '[]'::jsonb) AS condiciones
        FROM etiquetado.ingrediente_resultado_etiqueta ire
        INNER JOIN nutricion.ingrediente i ON i.id = ire.id_ingrediente
        LEFT JOIN nutricion.ingrediente_composicion ic ON ic.id_ingrediente = i.id
        INNER JOIN etiquetado.etiqueta e ON e.id = ire.id_etiqueta
        INNER JOIN etiquetado.subetiqueta s ON s.id = ire.id_subetiqueta
        INNER JOIN etiquetado.regla_version rv ON rv.id = ire.id_regla_version
        LEFT JOIN etiquetado.subetiqueta_regla sr
            ON sr.id_regla_version = ire.id_regla_version
           AND sr.id_subetiqueta = ire.id_subetiqueta
        LEFT JOIN LATERAL (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'grupo_condicion_id', gc.id,
                    'operador_grupo', gc.operador_grupo,
                    'orden_grupo', gc.orden_grupo,
                    'condicion_id', c.id,
                    'campo_catalogo_id', c.id_campo_catalogo,
                    'operador', c.operador,
                    'valor_numerico', c.valor_numerico,
                    'valor_texto_directo', c.valor_texto_directo,
                    'orden_condicion', c.orden_condicion,
                    'textos', COALESCE(cvt.textos, '[]'::jsonb)
                )
                ORDER BY gc.orden_grupo, c.orden_condicion
            ) AS items
            FROM etiquetado.grupo_condicion gc
            INNER JOIN etiquetado.condicion c ON c.id_grupo_condicion = gc.id
            LEFT JOIN LATERAL (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', cvt.id,
                        'texto_busqueda', cvt.texto_busqueda,
                        'tipo_match', cvt.tipo_match
                    )
                    ORDER BY cvt.id
                ) AS textos
                FROM etiquetado.condicion_valor_texto cvt
                WHERE cvt.id_condicion = c.id
            ) cvt ON TRUE
            WHERE gc.id_subetiqueta_regla = sr.id
        ) condiciones ON TRUE
        WHERE {" AND ".join(where_parts)}
        ORDER BY rv.version_numero DESC, ire.fecha_calculo DESC NULLS LAST
        LIMIT 1
    """

    with db_cursor() as cur:
        cur.execute(winner_sql, winner_params)
        winner_row = cur.fetchone()
        if winner_row is None:
            raise HTTPException(
                status_code=404,
                detail="No existe resultado etiquetado para ese ingrediente y etiqueta",
            )

        winner_cols = [desc[0] for desc in cur.description]
        winner_payload = dict(zip(winner_cols, winner_row, strict=False))
        winner_payload["fecha_calculo"] = (
            winner_payload["fecha_calculo"].isoformat()
            if winner_payload.get("fecha_calculo") is not None
            else None
        )
        winner_payload["condiciones"] = winner_payload.get("condiciones") or []

        candidates_sql = """
            SELECT
                s.id AS subetiqueta_id,
                s.codigo AS subetiqueta_codigo,
                s.nombre_visible AS subetiqueta_nombre,
                sr.id AS subetiqueta_regla_id,
                sr.prioridad_evaluacion,
                sr.tipo_evaluacion,
                COALESCE(condiciones.items, '[]'::jsonb) AS condiciones
            FROM etiquetado.subetiqueta s
            LEFT JOIN etiquetado.subetiqueta_regla sr
                ON sr.id_subetiqueta = s.id
               AND sr.id_regla_version = %s
            LEFT JOIN LATERAL (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'grupo_condicion_id', gc.id,
                        'operador_grupo', gc.operador_grupo,
                        'orden_grupo', gc.orden_grupo,
                        'condicion_id', c.id,
                        'campo_catalogo_id', c.id_campo_catalogo,
                        'operador', c.operador,
                        'valor_numerico', c.valor_numerico,
                        'valor_texto_directo', c.valor_texto_directo,
                        'orden_condicion', c.orden_condicion,
                        'textos', COALESCE(cvt.textos, '[]'::jsonb)
                    )
                    ORDER BY gc.orden_grupo, c.orden_condicion
                ) AS items
                FROM etiquetado.grupo_condicion gc
                INNER JOIN etiquetado.condicion c ON c.id_grupo_condicion = gc.id
                LEFT JOIN LATERAL (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'id', cvt.id,
                            'texto_busqueda', cvt.texto_busqueda,
                            'tipo_match', cvt.tipo_match
                        )
                        ORDER BY cvt.id
                    ) AS textos
                    FROM etiquetado.condicion_valor_texto cvt
                    WHERE cvt.id_condicion = c.id
                ) cvt ON TRUE
                WHERE gc.id_subetiqueta_regla = sr.id
            ) condiciones ON TRUE
            WHERE s.id_etiqueta = %s
            ORDER BY COALESCE(sr.prioridad_evaluacion, 999999), s.id
        """

        cur.execute(
            candidates_sql,
            (winner_payload["regla_version_id"], winner_payload["etiqueta_id"]),
        )
        candidate_rows = cur.fetchall()
        candidate_cols = [desc[0] for desc in cur.description]

    candidates: list[AuditoriaSubetiquetaCandidata] = []
    for row in candidate_rows:
        payload = dict(zip(candidate_cols, row, strict=False))
        payload["es_ganadora"] = payload["subetiqueta_id"] == winner_payload["subetiqueta_id"]
        payload["condiciones"] = payload.get("condiciones") or []
        candidates.append(AuditoriaSubetiquetaCandidata.model_validate(payload))

    return AuditoriaIngredienteDetalleResponse(
        resultado_ganador=AuditoriaIngredienteRow.model_validate(winner_payload),
        subetiquetas_candidatas=candidates,
    )


@router.put(
    "/reglas/versiones/{id_regla_version}",
    response_model=ReglaVersionUpdateResponse,
)
def put_regla_version(
    id_regla_version: int,
    payload: ReglaVersionUpdateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
):
    if id_regla_version <= 0:
        raise HTTPException(status_code=400, detail="id_regla_version invalido")

    estado = _validate_estado_regla(payload.estado)

    with db_cursor() as cur:
        cur.execute(
            """
            select id, id_etiqueta, version_numero
            from etiquetado.regla_version
            where id = %s
            """,
            (id_regla_version,),
        )
        source_version = cur.fetchone()
        if source_version is None:
            raise HTTPException(status_code=404, detail="regla_version no encontrada")

        source_regla_version_id = int(source_version[0])
        id_etiqueta = int(source_version[1])
        source_version_numero = int(source_version[2])

        cur.execute(
            """
            select coalesce(max(version_numero), 0) + 1
            from etiquetado.regla_version
            where id_etiqueta = %s
            """,
            (id_etiqueta,),
        )
        new_version_numero = int(cur.fetchone()[0])

        publicada_por: str | None = None
        fecha_publicacion_sql: str | None = None
        if estado == "PUBLICADA":
            publicada_por = _resolve_usuario_uuid(cur, user)
            fecha_publicacion_sql = "now()"

        cur.execute(
            f"""
            insert into etiquetado.regla_version (
                id_etiqueta,
                version_numero,
                estado,
                observacion,
                publicada_por,
                fecha_publicacion
            ) values (%s, %s, %s, %s, %s, {fecha_publicacion_sql or 'NULL'})
            returning id
            """,
            (
                id_etiqueta,
                new_version_numero,
                estado,
                payload.observacion,
                publicada_por,
            ),
        )
        new_regla_version_id = int(cur.fetchone()[0])

        if payload.subetiquetas is None:
            stats = _clone_subetiquetas_from_source(
                cur,
                source_regla_version_id=source_regla_version_id,
                new_regla_version_id=new_regla_version_id,
            )
            clonado = True
        else:
            stats = _insert_subetiquetas_payload(
                cur,
                id_etiqueta=id_etiqueta,
                new_regla_version_id=new_regla_version_id,
                subetiquetas=payload.subetiquetas,
            )
            clonado = False

    return ReglaVersionUpdateResponse(
        id_etiqueta=id_etiqueta,
        source_regla_version_id=source_regla_version_id,
        source_version_numero=source_version_numero,
        new_regla_version_id=new_regla_version_id,
        new_version_numero=new_version_numero,
        estado=estado,
        clonado_desde_version_origen=clonado,
        subetiquetas_count=stats["subetiquetas_count"],
        grupos_count=stats["grupos_count"],
        condiciones_count=stats["condiciones_count"],
        valores_texto_count=stats["valores_texto_count"],
    )


@router.post("/recalculo", response_model=RecalculoEtiquetadoResponse)
def post_recalculo_etiquetado(
    payload: RecalculoEtiquetadoRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
):
    if payload.id_regla_version is None and payload.id_etiqueta is None:
        scope = "masivo"
    elif payload.id_regla_version is not None:
        scope = "regla_version"
    else:
        scope = "etiqueta"

    global_errors: list[str] = []

    with db_cursor() as cur:
        user_uuid = _resolve_usuario_uuid(cur, user)
        target_versions = _load_target_rule_versions(cur, payload)
        ingredient_scope = _build_ingredient_scope(cur, payload)

        if not ingredient_scope:
            response = RecalculoEtiquetadoResponse(
                scope=scope,
                dry_run=payload.dry_run,
                reglas_procesadas=len(target_versions),
                ingredientes_en_alcance=0,
                insertados=0,
                actualizados=0,
                sin_cambios=0,
                eliminados=0,
                sin_resultado=0,
                errores=0,
                resultado_por_regla=[],
                mensajes_error=[],
            )
            _log_recalculo_historial(cur, user_uuid, scope, payload, response)
            return response

        ingredient_ids = sorted(ingredient_scope.keys())

        totals = {
            "insertados": 0,
            "actualizados": 0,
            "sin_cambios": 0,
            "eliminados": 0,
            "sin_resultado": 0,
            "errores": 0,
        }
        results_by_version: list[RecalculoVersionResult] = []

        for version in target_versions:
            id_regla_version = int(version["id"])
            id_etiqueta = int(version["id_etiqueta"])

            subrules = _load_rule_structure(cur, id_regla_version)
            if not subrules:
                msg = (
                    f"Regla version {id_regla_version} sin subetiquetas_regla; "
                    "se omite del recalculo"
                )
                global_errors.append(msg)
                results_by_version.append(
                    RecalculoVersionResult(
                        id_etiqueta=id_etiqueta,
                        id_regla_version=id_regla_version,
                        version_numero=int(version["version_numero"]),
                        estado=str(version["estado"]),
                        ingredientes_procesados=0,
                        insertados=0,
                        actualizados=0,
                        sin_cambios=0,
                        eliminados=0,
                        sin_resultado=0,
                        errores=1,
                    )
                )
                totals["errores"] += 1
                continue

            cur.execute(
                """
                select id_ingrediente, id_subetiqueta
                from etiquetado.ingrediente_resultado_etiqueta
                where id_regla_version = %s
                  and id_ingrediente = any(%s)
                """,
                (id_regla_version, ingredient_ids),
            )
            existing_map = {int(row[0]): int(row[1]) for row in cur.fetchall()}

            version_stats = {
                "ingredientes_procesados": 0,
                "insertados": 0,
                "actualizados": 0,
                "sin_cambios": 0,
                "eliminados": 0,
                "sin_resultado": 0,
                "errores": 0,
            }

            for ingredient_id in ingredient_ids:
                version_stats["ingredientes_procesados"] += 1
                try:
                    ctx = ingredient_scope[ingredient_id]
                    winner_subrule, trigger_value, detail = _pick_winner_subrule(subrules, ctx)
                    current_subetiqueta = existing_map.get(ingredient_id)

                    if winner_subrule is None:
                        if current_subetiqueta is not None:
                            if not payload.dry_run:
                                cur.execute(
                                    """
                                    delete from etiquetado.ingrediente_resultado_etiqueta
                                    where id_ingrediente = %s
                                      and id_etiqueta = %s
                                      and id_regla_version = %s
                                    """,
                                    (ingredient_id, id_etiqueta, id_regla_version),
                                )
                            version_stats["eliminados"] += 1
                        else:
                            version_stats["sin_resultado"] += 1
                        continue

                    winning_subetiqueta = int(winner_subrule["id_subetiqueta"])

                    if current_subetiqueta == winning_subetiqueta:
                        version_stats["sin_cambios"] += 1
                        continue

                    if payload.dry_run:
                        if current_subetiqueta is None:
                            version_stats["insertados"] += 1
                        else:
                            version_stats["actualizados"] += 1
                        continue

                    detalle_payload = {
                        "source": "api_recalculo_etiquetado_v1",
                        "evaluated_at": datetime.now(UTC).isoformat(),
                        "id_regla_version": id_regla_version,
                        "id_etiqueta": id_etiqueta,
                        "subetiqueta_regla_id": winner_subrule["id"],
                        "tipo_evaluacion": winner_subrule["tipo_evaluacion"],
                        "evaluacion": detail,
                    }

                    cur.execute(
                        """
                        insert into etiquetado.ingrediente_resultado_etiqueta (
                            id_ingrediente,
                            id_etiqueta,
                            id_subetiqueta,
                            id_regla_version,
                            valor_disparador,
                            detalle_evaluacion,
                            fecha_calculo
                        ) values (%s, %s, %s, %s, %s, %s::jsonb, now())
                        on conflict (id_ingrediente, id_etiqueta, id_regla_version)
                        do update set
                            id_subetiqueta = excluded.id_subetiqueta,
                            valor_disparador = excluded.valor_disparador,
                            detalle_evaluacion = excluded.detalle_evaluacion,
                            fecha_calculo = now()
                        returning (xmax = 0) as inserted
                        """,
                        (
                            ingredient_id,
                            id_etiqueta,
                            winning_subetiqueta,
                            id_regla_version,
                            trigger_value,
                            json.dumps(detalle_payload, ensure_ascii=False),
                        ),
                    )
                    inserted = bool(cur.fetchone()[0])
                    if inserted:
                        version_stats["insertados"] += 1
                    else:
                        version_stats["actualizados"] += 1

                except Exception as exc:
                    version_stats["errores"] += 1
                    error_msg = (
                        f"Error en version {id_regla_version}, ingrediente {ingredient_id}: {exc}"
                    )
                    global_errors.append(error_msg)
                    if payload.stop_on_error:
                        raise HTTPException(status_code=500, detail=error_msg) from exc

            totals["insertados"] += version_stats["insertados"]
            totals["actualizados"] += version_stats["actualizados"]
            totals["sin_cambios"] += version_stats["sin_cambios"]
            totals["eliminados"] += version_stats["eliminados"]
            totals["sin_resultado"] += version_stats["sin_resultado"]
            totals["errores"] += version_stats["errores"]

            results_by_version.append(
                RecalculoVersionResult(
                    id_etiqueta=id_etiqueta,
                    id_regla_version=id_regla_version,
                    version_numero=int(version["version_numero"]),
                    estado=str(version["estado"]),
                    ingredientes_procesados=version_stats["ingredientes_procesados"],
                    insertados=version_stats["insertados"],
                    actualizados=version_stats["actualizados"],
                    sin_cambios=version_stats["sin_cambios"],
                    eliminados=version_stats["eliminados"],
                    sin_resultado=version_stats["sin_resultado"],
                    errores=version_stats["errores"],
                )
            )

        response = RecalculoEtiquetadoResponse(
            scope=scope,
            dry_run=payload.dry_run,
            reglas_procesadas=len(target_versions),
            ingredientes_en_alcance=len(ingredient_scope),
            insertados=totals["insertados"],
            actualizados=totals["actualizados"],
            sin_cambios=totals["sin_cambios"],
            eliminados=totals["eliminados"],
            sin_resultado=totals["sin_resultado"],
            errores=totals["errores"],
            resultado_por_regla=results_by_version,
            mensajes_error=global_errors[:200],
        )
        _log_recalculo_historial(cur, user_uuid, scope, payload, response)

    return response


@router.get("/recalculo/historial", response_model=RecalculoHistorialResponse)
def get_recalculo_historial(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    id_etiqueta: int | None = Query(default=None, ge=1),
    id_regla_version: int | None = Query(default=None, ge=1),
    _=Depends(require_roles("admin", "nutricionista")),
):
    offset = (page - 1) * page_size
    etiqueta_key = str(id_etiqueta) if id_etiqueta is not None else None
    regla_key = str(id_regla_version) if id_regla_version is not None else None

    where_clauses = [
        "la.accion = 'ETIQUETADO_RECALCULO'",
        "la.esquema_afectado = 'etiquetado'",
    ]
    where_params: list[Any] = []

    if etiqueta_key is not None:
        where_clauses.append("(la.payload_nuevo->'meta'->'etiqueta_ids') ? %s")
        where_params.append(etiqueta_key)

    if regla_key is not None:
        where_clauses.append("(la.payload_nuevo->'meta'->'regla_version_ids') ? %s")
        where_params.append(regla_key)

    where_sql = " and ".join(where_clauses)

    with db_cursor() as cur:
        count_sql = f"""
            select count(*)
            from seguridad.log_auditoria la
            where {where_sql}
        """
        cur.execute(count_sql, where_params)
        total = int(cur.fetchone()[0])

        data_sql = f"""
            select
                la.id,
                la.id_usuario::text,
                la.fecha_registro,
                la.payload_nuevo
            from seguridad.log_auditoria la
            where {where_sql}
            order by la.fecha_registro desc, la.id desc
            offset %s
            limit %s
        """
        cur.execute(
            data_sql,
            [*where_params, offset, page_size],
        )
        rows = cur.fetchall()

    items: list[RecalculoHistorialItem] = []
    for row in rows:
        payload_nuevo = row[3] if isinstance(row[3], dict) else {}
        items.append(
            _build_historial_item(
                id_log=int(row[0]),
                id_usuario=row[1],
                fecha_registro=row[2],
                payload_nuevo=payload_nuevo,
            )
        )

    return RecalculoHistorialResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=items,
    )


@router.get(
    "/recalculo/historial/{id_log}",
    response_model=RecalculoHistorialDetalleResponse,
)
def get_recalculo_historial_detalle(
    id_log: int,
    _=Depends(require_roles("admin", "nutricionista")),
):
    if id_log <= 0:
        raise HTTPException(status_code=400, detail="id_log invalido")

    with db_cursor() as cur:
        cur.execute(
            """
            select
                la.id,
                la.id_usuario::text,
                la.fecha_registro,
                la.detalle,
                la.payload_nuevo
            from seguridad.log_auditoria la
            where la.id = %s
              and la.accion = 'ETIQUETADO_RECALCULO'
              and la.esquema_afectado = 'etiquetado'
            limit 1
            """,
            (id_log,),
        )
        row = cur.fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail="Historial no encontrado")

    payload_nuevo = row[4] if isinstance(row[4], dict) else {}
    item = _build_historial_item(
        id_log=int(row[0]),
        id_usuario=row[1],
        fecha_registro=row[2],
        payload_nuevo=payload_nuevo,
    )

    request_data = payload_nuevo.get("request") if isinstance(payload_nuevo, dict) else {}
    result_data = payload_nuevo.get("result") if isinstance(payload_nuevo, dict) else {}
    meta_data = payload_nuevo.get("meta") if isinstance(payload_nuevo, dict) else {}

    return RecalculoHistorialDetalleResponse(
        item=item,
        request_payload=request_data if isinstance(request_data, dict) else {},
        result_payload=result_data if isinstance(result_data, dict) else {},
        meta_payload=meta_data if isinstance(meta_data, dict) else {},
        detalle=row[3],
    )
