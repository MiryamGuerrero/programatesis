from __future__ import annotations

import json
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.api.deps import require_roles
from app.core.db import db_cursor
from app.core.security import UserContext
from app.services.roles.admin.modules.crud import admin_crud_service
from app.services.shared.cerebro.motor_etiquetas_nutricionales import (
    build_human_rule,
    preview_ad_hoc_rule,
    process_one_pending_recalculation_job,
    recalculate_ingredient_labels,
)

router = APIRouter(prefix="/nutricionista", tags=["Nutricionista Admin"])


class IngredientCreateRequest(BaseModel):
    nombre: str
    codigo_externo: str | None = None
    id_grupo_alimentario: int | None = Field(default=None, gt=0)
    grupo_nombre: str | None = None
    id_subgrupo_alimentario: int | None = Field(default=None, gt=0)
    subgrupo_nombre: str | None = None
    unidad_base: str | None = None
    parte_comestible_factor: float | None = Field(default=None, ge=0, le=1)
    precio_referencia: float | None = Field(default=None, ge=0)
    costo_estimado_por_100g: float | None = Field(default=None, ge=0)
    sinonimos: list[str] = Field(default_factory=list)


class IngredientUpdateRequest(BaseModel):
    nombre: str | None = None
    codigo_externo: str | None = None
    id_grupo_alimentario: int | None = Field(default=None, gt=0)
    grupo_nombre: str | None = None
    id_subgrupo_alimentario: int | None = Field(default=None, gt=0)
    subgrupo_nombre: str | None = None
    unidad_base: str | None = None
    parte_comestible_factor: float | None = Field(default=None, ge=0, le=1)
    precio_referencia: float | None = Field(default=None, ge=0)
    costo_estimado_por_100g: float | None = Field(default=None, ge=0)
    activo: bool | None = None
    sinonimos: list[str] | None = None


class VariableCreateRequest(BaseModel):
    codigo: str
    nombre_visible: str
    tipo_dato: Literal["numeric", "text", "boolean", "date", "json"] = "numeric"
    clasificacion: str | None = None
    categoria_funcional: str | None = None
    unidad: str | None = None
    descripcion: str | None = None
    es_calculable: bool = False
    participa_en_calculos: bool = False
    participa_en_reglas: bool = False
    permite_nulos: bool = True
    ausencia_bloquea_etiqueta: bool = False


class VariableValueUpsertItem(BaseModel):
    id_ingrediente: int = Field(gt=0)
    variable_codigo: str
    valor_numerico: float | None = None
    valor_texto: str | None = None
    valor_booleano: bool | None = None
    estado_dato: Literal[
        "valor_real",
        "no_reportado",
        "no_aplica",
        "pendiente",
        "invalido",
        "insuficiente_dato",
    ] = "valor_real"
    origen_asignacion: Literal[
        "importada_desde_excel",
        "automatica",
        "manual",
        "csv",
        "api",
        "sistema",
    ] = "manual"
    justificacion: str | None = None


class VariableBulkUpsertRequest(BaseModel):
    items: list[VariableValueUpsertItem] = Field(default_factory=list)


class LabelCreateRequest(BaseModel):
    codigo: str
    nombre_visible: str
    categoria: str | None = None
    subcategoria: str | None = None
    descripcion: str | None = None
    tipo_etiqueta: Literal["automatica", "manual", "mixta"] = "mixta"
    prioridad: int = 100
    color_hex: str | None = None
    activa: bool = True
    objetivo_clinico: str | None = None
    interpretacion_base: str | None = None
    admite_correccion_manual: bool = True


class RuleConditionRequest(BaseModel):
    orden: int = Field(ge=1)
    grupo_logico: int = Field(default=1, ge=1)
    conector_grupo: Literal["AND", "OR"] = "AND"
    tipo_condicion: str = "variable_compare"
    variable_codigo: str | None = None
    operador: str | None = None
    valor_numero: float | None = None
    valor_numero_min: float | None = None
    valor_numero_max: float | None = None
    valor_texto: str | None = None
    valor_lista: list[str] | None = None
    campo_objetivo: str | None = None
    negado: bool = False
    descripcion_humana: str | None = None


class LabelRuleCreateRequest(BaseModel):
    id_etiqueta: int = Field(gt=0)
    nombre_regla: str
    codigo_regla: str | None = None
    estado: Literal["borrador", "activa", "inactiva", "archivada"] = "activa"
    tipo_regla: Literal["automatica", "manual", "mixta"] = "automatica"
    prioridad: int = 100
    formula_excel_original: str | None = None
    campos_intervienen: list[str] = Field(default_factory=list)
    umbral_resumen: dict[str, Any] = Field(default_factory=dict)
    condiciones: list[RuleConditionRequest] = Field(default_factory=list)
    expresion_humana: str | None = None


class RulePreviewRequest(BaseModel):
    nombre_regla: str = "Vista previa"
    condiciones: list[RuleConditionRequest] = Field(default_factory=list)
    detail_limit: int = Field(default=25, ge=1, le=100)


class RecalculateIngredientRequest(BaseModel):
    procesar_inmediato: bool = True


class RecalculateGenericRequest(BaseModel):
    procesar_inmediato: bool = False


class RecalculateMassiveRequest(BaseModel):
    parametros: dict[str, Any] = Field(default_factory=dict)
    procesar_inmediato: bool = False


class UpsertIngredienteComposicionRequest(BaseModel):
    valores: dict[str, object] = Field(default_factory=dict)



def _rows_to_dicts(cur, rows: list[tuple[Any, ...]]) -> list[dict[str, Any]]:
    columns = [description[0] for description in cur.description]
    return [dict(zip(columns, row, strict=False)) for row in rows]



def _normalize_text(value: str) -> str:
    return value.strip()



def _resolve_group_id(cur, id_grupo: int | None, grupo_nombre: str | None) -> int | None:
    if id_grupo is not None:
        return id_grupo

    if not grupo_nombre:
        return None

    cur.execute(
        """
        insert into dom_nutricion_catalogos.grupo_alimentario (nombre)
        values (%s)
        on conflict (nombre) do update set nombre = excluded.nombre
        returning id
        """,
        (_normalize_text(grupo_nombre),),
    )
    row = cur.fetchone()
    return int(row[0]) if row else None



def _resolve_subgroup_id(
    cur,
    id_grupo: int | None,
    id_subgrupo: int | None,
    subgrupo_nombre: str | None,
) -> int | None:
    if id_subgrupo is not None:
        return id_subgrupo

    if id_grupo is None or not subgrupo_nombre:
        return None

    cur.execute(
        """
        select id
        from dom_nutricion_catalogos.subgrupo_alimentario
        where id_grupo_alimentario = %s
          and lower(btrim(nombre)) = lower(btrim(%s))
        limit 1
        """,
        (id_grupo, _normalize_text(subgrupo_nombre)),
    )
    row = cur.fetchone()
    if row:
        return int(row[0])

    cur.execute(
        """
        insert into dom_nutricion_catalogos.subgrupo_alimentario (
            id_grupo_alimentario,
            nombre,
            activo
        ) values (%s, %s, true)
        returning id
        """,
        (id_grupo, _normalize_text(subgrupo_nombre)),
    )
    created = cur.fetchone()
    return int(created[0]) if created else None



def _find_variable(cur, variable_code: str) -> tuple[int, str] | None:
    cur.execute(
        """
        select id, tipo_dato
        from dom_nutricion_catalogos.variable_nutricional
        where lower(codigo) = lower(%s)
        limit 1
        """,
        (variable_code.strip(),),
    )
    row = cur.fetchone()
    if not row:
        return None
    return int(row[0]), str(row[1])



def _validate_single_typed_value(item: VariableValueUpsertItem) -> None:
    provided = [
        item.valor_numerico is not None,
        item.valor_texto is not None,
        item.valor_booleano is not None,
    ]
    if sum(provided) > 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Solo se permite un tipo de valor por fila (numerico/texto/booleano).",
        )



def _upsert_variable_value(cur, user: UserContext, item: VariableValueUpsertItem) -> None:
    _validate_single_typed_value(item)

    found = _find_variable(cur, item.variable_codigo)
    if not found:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Variable no encontrada: {item.variable_codigo}",
        )

    id_variable, _ = found

    cur.execute(
        """
        insert into dom_nutricion_ingrediente_rel.ingrediente_variable_valor (
            id_ingrediente,
            id_variable_nutricional,
            valor_numerico,
            valor_texto,
            valor_booleano,
            estado_dato,
            origen_asignacion,
            justificacion,
            actualizado_por,
            updated_at
        ) values (
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, now()
        )
        on conflict (id_ingrediente, id_variable_nutricional)
        do update set
            valor_numerico = excluded.valor_numerico,
            valor_texto = excluded.valor_texto,
            valor_booleano = excluded.valor_booleano,
            estado_dato = excluded.estado_dato,
            origen_asignacion = excluded.origen_asignacion,
            justificacion = excluded.justificacion,
            actualizado_por = excluded.actualizado_por,
            updated_at = now()
        """,
        (
            item.id_ingrediente,
            id_variable,
            item.valor_numerico,
            item.valor_texto,
            item.valor_booleano,
            item.estado_dato,
            item.origen_asignacion,
            item.justificacion,
            user.user_id,
        ),
    )


@router.get("/ingredientes")
def list_ingredients_admin(
    q: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    include_inactive: bool = Query(default=False),
    _=Depends(require_roles("admin", "nutricionista")),
) -> list[dict[str, Any]]:
    base_sql = """
        select
            i.id,
            i.nombre,
            i.codigo_externo,
            i.id_grupo_alimentario,
            g.nombre as grupo_nombre,
            i.id_subgrupo_alimentario,
            sg.nombre as subgrupo_nombre,
            i.parte_comestible_factor,
            i.precio_referencia,
            i.costo_estimado_por_100g,
            i.activo,
            i.fecha_importacion,
            i.version_fuente
        from dom_nutricion_ingredientes.ingrediente i
        left join dom_nutricion_catalogos.grupo_alimentario g
            on g.id = i.id_grupo_alimentario
        left join dom_nutricion_catalogos.subgrupo_alimentario sg
            on sg.id = i.id_subgrupo_alimentario
        where (%s or i.activo = true)
          and (%s is null or i.nombre ilike ('%' || %s || '%') or coalesce(i.codigo_externo, '') ilike ('%' || %s || '%'))
        order by i.nombre
        limit %s
        offset %s
    """

    with db_cursor() as cur:
        cur.execute(base_sql, (include_inactive, q, q, q, limit, offset))
        rows = cur.fetchall()
        return _rows_to_dicts(cur, rows)


@router.post("/ingredientes")
def create_ingredient_admin(
    payload: IngredientCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        with db_cursor() as cur:
            id_grupo = _resolve_group_id(cur, payload.id_grupo_alimentario, payload.grupo_nombre)
            id_subgrupo = _resolve_subgroup_id(
                cur,
                id_grupo=id_grupo,
                id_subgrupo=payload.id_subgrupo_alimentario,
                subgrupo_nombre=payload.subgrupo_nombre,
            )

            cur.execute(
                """
                insert into dom_nutricion_ingredientes.ingrediente (
                    nombre,
                    codigo_externo,
                    id_grupo_alimentario,
                    id_subgrupo_alimentario,
                    unidad_base,
                    parte_comestible_factor,
                    precio_referencia,
                    costo_estimado_por_100g,
                    fuente_registro,
                    fecha_importacion,
                    version_fuente,
                    activo
                ) values (
                    %s, %s, %s, %s, %s, %s, %s, %s,
                    'manual', now(), 'api', true
                )
                returning id
                """,
                (
                    payload.nombre.strip(),
                    payload.codigo_externo.strip() if payload.codigo_externo else None,
                    id_grupo,
                    id_subgrupo,
                    payload.unidad_base.strip() if payload.unidad_base else None,
                    payload.parte_comestible_factor,
                    payload.precio_referencia,
                    payload.costo_estimado_por_100g,
                ),
            )
            created = cur.fetchone()
            if not created:
                raise HTTPException(status_code=500, detail="No se pudo crear el ingrediente")

            id_ingrediente = int(created[0])

            for raw_syn in payload.sinonimos:
                syn = raw_syn.strip()
                if not syn:
                    continue
                cur.execute(
                    """
                    insert into dom_nutricion_ingredientes.ingrediente_sinonimo (
                        id_ingrediente,
                        nombre_sinonimo,
                        activo
                    ) values (%s, %s, true)
                    on conflict (id_ingrediente, nombre_sinonimo)
                    do update set activo = true
                    """,
                    (id_ingrediente, syn),
                )

            cur.execute(
                """
                insert into dom_nutricion_reglas.auditoria_cambio (
                    entidad, id_entidad, accion, detalle, changed_by
                ) values (%s, %s, %s, %s::jsonb, %s)
                """,
                (
                    "ingrediente",
                    str(id_ingrediente),
                    "create",
                    json.dumps(payload.model_dump()),
                    user.user_id,
                ),
            )

            return {"id": id_ingrediente}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.put("/ingredientes/{id_ingrediente}")
def update_ingredient_admin(
    id_ingrediente: int,
    payload: IngredientUpdateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        with db_cursor() as cur:
            id_grupo = _resolve_group_id(cur, payload.id_grupo_alimentario, payload.grupo_nombre)
            id_subgrupo = _resolve_subgroup_id(
                cur,
                id_grupo=id_grupo,
                id_subgrupo=payload.id_subgrupo_alimentario,
                subgrupo_nombre=payload.subgrupo_nombre,
            )

            cur.execute(
                """
                update dom_nutricion_ingredientes.ingrediente
                set nombre = coalesce(%s, nombre),
                    codigo_externo = coalesce(%s, codigo_externo),
                    id_grupo_alimentario = coalesce(%s, id_grupo_alimentario),
                    id_subgrupo_alimentario = coalesce(%s, id_subgrupo_alimentario),
                    unidad_base = coalesce(%s, unidad_base),
                    parte_comestible_factor = coalesce(%s, parte_comestible_factor),
                    precio_referencia = coalesce(%s, precio_referencia),
                    costo_estimado_por_100g = coalesce(%s, costo_estimado_por_100g),
                    activo = coalesce(%s, activo),
                    fuente_registro = 'manual',
                    fecha_importacion = now(),
                    version_fuente = 'api'
                where id = %s
                returning id
                """,
                (
                    payload.nombre.strip() if payload.nombre else None,
                    payload.codigo_externo.strip() if payload.codigo_externo else None,
                    id_grupo,
                    id_subgrupo,
                    payload.unidad_base.strip() if payload.unidad_base else None,
                    payload.parte_comestible_factor,
                    payload.precio_referencia,
                    payload.costo_estimado_por_100g,
                    payload.activo,
                    id_ingrediente,
                ),
            )
            updated = cur.fetchone()
            if not updated:
                raise HTTPException(status_code=404, detail="Ingrediente no encontrado")

            if payload.sinonimos is not None:
                cur.execute(
                    """
                    update dom_nutricion_ingredientes.ingrediente_sinonimo
                    set activo = false
                    where id_ingrediente = %s
                    """,
                    (id_ingrediente,),
                )
                for raw_syn in payload.sinonimos:
                    syn = raw_syn.strip()
                    if not syn:
                        continue
                    cur.execute(
                        """
                        insert into dom_nutricion_ingredientes.ingrediente_sinonimo (
                            id_ingrediente,
                            nombre_sinonimo,
                            activo
                        ) values (%s, %s, true)
                        on conflict (id_ingrediente, nombre_sinonimo)
                        do update set activo = true
                        """,
                        (id_ingrediente, syn),
                    )

            cur.execute(
                """
                insert into dom_nutricion_reglas.auditoria_cambio (
                    entidad, id_entidad, accion, detalle, changed_by
                ) values (%s, %s, %s, %s::jsonb, %s)
                """,
                (
                    "ingrediente",
                    str(id_ingrediente),
                    "update",
                    json.dumps(payload.model_dump()),
                    user.user_id,
                ),
            )

            return {"id": id_ingrediente, "updated": True}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.delete("/ingredientes/{id_ingrediente}")
def deactivate_ingredient_admin(
    id_ingrediente: int,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            update dom_nutricion_ingredientes.ingrediente
            set activo = false,
                fuente_registro = 'manual',
                fecha_importacion = now(),
                version_fuente = 'api-delete'
            where id = %s
            returning id
            """,
            (id_ingrediente,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Ingrediente no encontrado")

        cur.execute(
            """
            insert into dom_nutricion_reglas.auditoria_cambio (
                entidad, id_entidad, accion, detalle, changed_by
            ) values (%s, %s, %s, %s::jsonb, %s)
            """,
            (
                "ingrediente",
                str(id_ingrediente),
                "delete",
                json.dumps({"activo": False}),
                user.user_id,
            ),
        )

    return {"id": id_ingrediente, "active": False}


@router.get("/ingredientes/{id_ingrediente}/composicion")
def fetch_ingredient_composition_admin(
    id_ingrediente: int,
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        return admin_crud_service.fetch_ingrediente_composicion(id_ingrediente=id_ingrediente)
    except ValueError as exc:
        detail = str(exc)
        status_code = (
            status.HTTP_404_NOT_FOUND
            if "no encontrado" in detail.lower()
            else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(status_code=status_code, detail=detail) from exc


@router.put("/ingredientes/{id_ingrediente}/composicion")
def upsert_ingredient_composition_admin(
    id_ingrediente: int,
    payload: UpsertIngredienteComposicionRequest,
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        updated = admin_crud_service.upsert_ingrediente_composicion(
            id_ingrediente=id_ingrediente,
            valores=payload.valores,
        )
    except ValueError as exc:
        detail = str(exc)
        status_code = (
            status.HTTP_404_NOT_FOUND
            if "no encontrado" in detail.lower()
            else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(status_code=status_code, detail=detail) from exc

    return {"id_ingrediente": id_ingrediente, "updated": updated}


@router.get("/variables")
def list_variables_catalog(
    q: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=500),
    _=Depends(require_roles("admin", "nutricionista")),
) -> list[dict[str, Any]]:
    with db_cursor() as cur:
        cur.execute(
            """
            select
                id,
                codigo,
                nombre_visible,
                tipo_dato,
                clasificacion,
                categoria_funcional,
                unidad,
                descripcion,
                es_calculable,
                participa_en_calculos,
                participa_en_reglas,
                permite_nulos,
                ausencia_bloquea_etiqueta,
                activo
            from dom_nutricion_catalogos.variable_nutricional
            where (%s is null or codigo ilike ('%' || %s || '%') or nombre_visible ilike ('%' || %s || '%'))
            order by categoria_funcional nulls last, nombre_visible
            limit %s
            """,
            (q, q, q, limit),
        )
        return _rows_to_dicts(cur, cur.fetchall())


@router.post("/variables")
def create_or_update_variable_catalog(
    payload: VariableCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            select id
            from dom_nutricion_catalogos.variable_nutricional
            where lower(codigo) = lower(%s)
            limit 1
            """,
            (payload.codigo.strip(),),
        )
        row = cur.fetchone()

        if row:
            var_id = int(row[0])
            cur.execute(
                """
                update dom_nutricion_catalogos.variable_nutricional
                set nombre_visible = %s,
                    tipo_dato = %s,
                    clasificacion = %s,
                    categoria_funcional = %s,
                    unidad = %s,
                    descripcion = %s,
                    es_calculable = %s,
                    participa_en_calculos = %s,
                    participa_en_reglas = %s,
                    permite_nulos = %s,
                    ausencia_bloquea_etiqueta = %s,
                    activo = true,
                    updated_at = now()
                where id = %s
                """,
                (
                    payload.nombre_visible,
                    payload.tipo_dato,
                    payload.clasificacion,
                    payload.categoria_funcional,
                    payload.unidad,
                    payload.descripcion,
                    payload.es_calculable,
                    payload.participa_en_calculos,
                    payload.participa_en_reglas,
                    payload.permite_nulos,
                    payload.ausencia_bloquea_etiqueta,
                    var_id,
                ),
            )
            action = "update"
        else:
            cur.execute(
                """
                insert into dom_nutricion_catalogos.variable_nutricional (
                    codigo,
                    nombre_visible,
                    tipo_dato,
                    clasificacion,
                    categoria_funcional,
                    unidad,
                    descripcion,
                    origen_catalogo,
                    es_calculable,
                    participa_en_calculos,
                    participa_en_reglas,
                    permite_nulos,
                    ausencia_bloquea_etiqueta,
                    activo
                ) values (
                    %s, %s, %s, %s, %s, %s, %s,
                    'manual', %s, %s, %s, %s, %s, true
                )
                returning id
                """,
                (
                    payload.codigo.strip(),
                    payload.nombre_visible,
                    payload.tipo_dato,
                    payload.clasificacion,
                    payload.categoria_funcional,
                    payload.unidad,
                    payload.descripcion,
                    payload.es_calculable,
                    payload.participa_en_calculos,
                    payload.participa_en_reglas,
                    payload.permite_nulos,
                    payload.ausencia_bloquea_etiqueta,
                ),
            )
            created = cur.fetchone()
            if not created:
                raise HTTPException(status_code=500, detail="No se pudo crear variable")
            var_id = int(created[0])
            action = "create"

        cur.execute(
            """
            insert into dom_nutricion_reglas.auditoria_cambio (
                entidad, id_entidad, accion, detalle, changed_by
            ) values (%s, %s, %s, %s::jsonb, %s)
            """,
            (
                "variable_nutricional",
                str(var_id),
                action,
                json.dumps(payload.model_dump()),
                user.user_id,
            ),
        )

    return {"id": var_id, "action": action}


@router.post("/variables/valor-unitario")
def upsert_variable_value_unit(
    payload: VariableValueUpsertItem,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        with db_cursor() as cur:
            _upsert_variable_value(cur, user, payload)
        return {"ok": True, "id_ingrediente": payload.id_ingrediente, "variable_codigo": payload.variable_codigo}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/variables/valor-masivo")
def upsert_variable_values_bulk(
    payload: VariableBulkUpsertRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    ok = 0
    errors: list[dict[str, Any]] = []

    with db_cursor() as cur:
        for idx, item in enumerate(payload.items, start=1):
            try:
                _upsert_variable_value(cur, user, item)
                ok += 1
            except Exception as exc:  # noqa: BLE001
                errors.append(
                    {
                        "index": idx,
                        "id_ingrediente": item.id_ingrediente,
                        "variable_codigo": item.variable_codigo,
                        "error": str(exc),
                    }
                )

    return {
        "total": len(payload.items),
        "ok": ok,
        "errores": len(errors),
        "detalle_errores": errors[:50],
    }


@router.get("/etiquetas")
def list_labels_catalog(
    q: str | None = Query(default=None),
    limit: int = Query(default=300, ge=1, le=1000),
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> list[dict[str, Any]]:
    with db_cursor() as cur:
        cur.execute(
            """
            select
                id,
                codigo,
                nombre_visible,
                categoria,
                subcategoria,
                descripcion,
                tipo_etiqueta,
                prioridad,
                color_hex,
                activa,
                objetivo_clinico,
                interpretacion_base,
                admite_correccion_manual,
                persistir_resultado
            from dom_nutricion_catalogos.etiqueta_nutricional
            where (%s is null or codigo ilike ('%' || %s || '%') or nombre_visible ilike ('%' || %s || '%'))
            order by categoria nulls last, subcategoria nulls last, prioridad, nombre_visible
            limit %s
            """,
            (q, q, q, limit),
        )
        return _rows_to_dicts(cur, cur.fetchall())


@router.post("/etiquetas")
def create_or_update_label_catalog(
    payload: LabelCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            insert into dom_nutricion_catalogos.etiqueta_nutricional (
                codigo,
                nombre_visible,
                categoria,
                subcategoria,
                descripcion,
                tipo_etiqueta,
                prioridad,
                color_hex,
                activa,
                objetivo_clinico,
                interpretacion_base,
                admite_correccion_manual,
                persistir_resultado,
                updated_at
            ) values (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, true, now()
            )
            on conflict (codigo)
            do update set
                nombre_visible = excluded.nombre_visible,
                categoria = excluded.categoria,
                subcategoria = excluded.subcategoria,
                descripcion = excluded.descripcion,
                tipo_etiqueta = excluded.tipo_etiqueta,
                prioridad = excluded.prioridad,
                color_hex = excluded.color_hex,
                activa = excluded.activa,
                objetivo_clinico = excluded.objetivo_clinico,
                interpretacion_base = excluded.interpretacion_base,
                admite_correccion_manual = excluded.admite_correccion_manual,
                updated_at = now()
            returning id
            """,
            (
                payload.codigo.strip(),
                payload.nombre_visible,
                payload.categoria,
                payload.subcategoria,
                payload.descripcion,
                payload.tipo_etiqueta,
                payload.prioridad,
                payload.color_hex,
                payload.activa,
                payload.objetivo_clinico,
                payload.interpretacion_base,
                payload.admite_correccion_manual,
            ),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=500, detail="No se pudo crear/actualizar etiqueta")
        id_etiqueta = int(row[0])

        cur.execute(
            """
            insert into dom_nutricion_reglas.auditoria_cambio (
                entidad, id_entidad, accion, detalle, changed_by
            ) values (%s, %s, %s, %s::jsonb, %s)
            """,
            (
                "etiqueta_nutricional",
                str(id_etiqueta),
                "upsert",
                json.dumps(payload.model_dump()),
                user.user_id,
            ),
        )

    return {"id": id_etiqueta}


@router.post("/etiquetas/reglas")
def create_label_rule(
    payload: LabelRuleCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            select nombre_visible
            from dom_nutricion_catalogos.etiqueta_nutricional
            where id = %s
            limit 1
            """,
            (payload.id_etiqueta,),
        )
        tag_row = cur.fetchone()
        if not tag_row:
            raise HTTPException(status_code=404, detail="Etiqueta no encontrada")

        label_name = str(tag_row[0])

        cur.execute(
            """
            select coalesce(max(version), 0) + 1
            from dom_nutricion_reglas.etiqueta_regla_version
            where id_etiqueta = %s
            """,
            (payload.id_etiqueta,),
        )
        version = int(cur.fetchone()[0])

        codigo_regla = payload.codigo_regla.strip() if payload.codigo_regla else f"rule_{payload.id_etiqueta}_{version}"
        conditions_payload = [cond.model_dump() for cond in payload.condiciones]

        human_text = payload.expresion_humana or build_human_rule(
            rule_name=payload.nombre_regla,
            conditions=conditions_payload,
            result_label_name=label_name,
        )

        if payload.campos_intervienen:
            campos = payload.campos_intervienen
        else:
            campos = sorted(
                {
                    cond.variable_codigo
                    for cond in payload.condiciones
                    if cond.variable_codigo is not None and cond.variable_codigo.strip() != ""
                }
            )

        cur.execute(
            """
            insert into dom_nutricion_reglas.etiqueta_regla_version (
                id_etiqueta,
                version,
                codigo_regla,
                nombre_regla,
                estado,
                tipo_regla,
                prioridad,
                expresion_json,
                expresion_humana,
                formula_excel_original,
                campos_intervienen,
                umbral_resumen,
                es_importada_excel,
                activo,
                created_by
            ) values (
                %s, %s, %s, %s,
                %s, %s, %s,
                %s::jsonb, %s, %s,
                %s, %s::jsonb,
                false, true, %s
            )
            returning id
            """,
            (
                payload.id_etiqueta,
                version,
                codigo_regla,
                payload.nombre_regla,
                payload.estado,
                payload.tipo_regla,
                payload.prioridad,
                json.dumps({"builder": "fastapi", "condiciones": conditions_payload}),
                human_text,
                payload.formula_excel_original,
                campos,
                json.dumps(payload.umbral_resumen),
                user.user_id,
            ),
        )
        rule_row = cur.fetchone()
        if not rule_row:
            raise HTTPException(status_code=500, detail="No se pudo crear regla")
        id_regla = int(rule_row[0])

        for cond in payload.condiciones:
            id_variable = None
            variable_nombre = None
            if cond.variable_codigo:
                found = _find_variable(cur, cond.variable_codigo)
                if not found:
                    raise HTTPException(
                        status_code=404,
                        detail=f"Variable no encontrada en condicion: {cond.variable_codigo}",
                    )
                id_variable = found[0]
                variable_nombre = cond.variable_codigo

            cur.execute(
                """
                insert into dom_nutricion_reglas.etiqueta_regla_condicion (
                    id_regla_version,
                    orden,
                    grupo_logico,
                    conector_grupo,
                    tipo_condicion,
                    id_variable_nutricional,
                    operador,
                    valor_numero,
                    valor_numero_min,
                    valor_numero_max,
                    valor_texto,
                    valor_lista,
                    campo_objetivo,
                    negado,
                    descripcion_humana,
                    condicion_json,
                    activa
                ) values (
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s,
                    %s::jsonb, true
                )
                """,
                (
                    id_regla,
                    cond.orden,
                    cond.grupo_logico,
                    cond.conector_grupo,
                    cond.tipo_condicion,
                    id_variable,
                    cond.operador,
                    cond.valor_numero,
                    cond.valor_numero_min,
                    cond.valor_numero_max,
                    cond.valor_texto,
                    cond.valor_lista,
                    cond.campo_objetivo,
                    cond.negado,
                    cond.descripcion_humana,
                    json.dumps(
                        {
                            "variable_codigo": variable_nombre,
                            "tipo_condicion": cond.tipo_condicion,
                            "operador": cond.operador,
                        }
                    ),
                ),
            )

        cur.execute(
            """
            insert into dom_nutricion_reglas.auditoria_cambio (
                entidad, id_entidad, accion, detalle, changed_by
            ) values (%s, %s, %s, %s::jsonb, %s)
            """,
            (
                "etiqueta_regla_version",
                str(id_regla),
                "create",
                json.dumps(payload.model_dump()),
                user.user_id,
            ),
        )

    return {
        "id_regla": id_regla,
        "version": version,
        "expresion_humana": human_text,
    }


@router.post("/etiquetas/reglas/preview")
def preview_label_rule(
    payload: RulePreviewRequest,
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    conditions = [cond.model_dump() for cond in payload.condiciones]
    human = build_human_rule(payload.nombre_regla, conditions)
    preview = preview_ad_hoc_rule(conditions=conditions, detail_limit=payload.detail_limit)
    return {
        "expresion_humana": human,
        "preview": preview,
    }


@router.post("/recalculo/ingrediente/{id_ingrediente}")
def request_recalculate_ingredient(
    id_ingrediente: int,
    payload: RecalculateIngredientRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            select dom_nutricion_reglas.rpc_solicitar_recalculo_ingrediente(%s, %s, false, %s::jsonb)
            """,
            (id_ingrediente, user.user_id, json.dumps({"trigger": "api"})),
        )
        job_row = cur.fetchone()

    if not job_row:
        raise HTTPException(status_code=500, detail="No se pudo crear job de recálculo")

    job_id = int(job_row[0])
    if not payload.procesar_inmediato:
        return {"job_id": job_id, "estado": "pendiente"}

    result = recalculate_ingredient_labels(
        id_ingrediente=id_ingrediente,
        user_id=user.user_id,
        recalc_job_id=job_id,
    )
    return {"job_id": job_id, "estado": "procesado", "resultado": result}


@router.post("/recalculo/etiqueta/{id_etiqueta}")
def request_recalculate_label(
    id_etiqueta: int,
    payload: RecalculateGenericRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            select dom_nutricion_reglas.rpc_solicitar_recalculo_etiqueta(%s, %s, false, %s::jsonb)
            """,
            (id_etiqueta, user.user_id, json.dumps({"trigger": "api"})),
        )
        row = cur.fetchone()

    if not row:
        raise HTTPException(status_code=500, detail="No se pudo crear job de recálculo por etiqueta")

    job_id = int(row[0])

    if payload.procesar_inmediato:
        outcome = process_one_pending_recalculation_job()
        return {"job_id": job_id, "estado": "procesado", "resultado": outcome}

    return {"job_id": job_id, "estado": "pendiente"}


@router.post("/recalculo/masivo")
def request_recalculate_massive(
    payload: RecalculateMassiveRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            select dom_nutricion_reglas.rpc_solicitar_recalculo_masivo(%s, %s::jsonb)
            """,
            (user.user_id, json.dumps(payload.parametros)),
        )
        row = cur.fetchone()

    if not row:
        raise HTTPException(status_code=500, detail="No se pudo crear job de recálculo masivo")

    job_id = int(row[0])

    if payload.procesar_inmediato:
        outcome = process_one_pending_recalculation_job()
        return {"job_id": job_id, "estado": "procesado", "resultado": outcome}

    return {"job_id": job_id, "estado": "pendiente"}


@router.post("/recalculo/procesar-pendiente")
def process_pending_recalculation(
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    return process_one_pending_recalculation_job()
