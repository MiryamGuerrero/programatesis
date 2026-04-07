from __future__ import annotations

import json
import re
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.api.deps import require_roles
from app.core.db import db_cursor
from app.core.security import UserContext
from app.services.shared.cerebro.motor_etiquetas_nutricionales import (
    build_human_rule,
    preview_ad_hoc_rule,
    process_one_pending_recalculation_job,
)
from app.services.shared.cerebro.motor_etiquetas_nutricionales.excel_formula_analysis_service import (
    analyze_excel_formulas,
    formula_to_branch_rules,
    slugify,
)

router = APIRouter(
    prefix="/nutricionista/etiquetas-config",
    tags=["Nutricionista Etiquetas Config"],
)


# -----------------------------------------------------------------------------
# Request models
# -----------------------------------------------------------------------------


class ExcelAnalyzeRequest(BaseModel):
    xlsx_path: str | None = None
    sheet_name: str = "Composicion"
    formula_row: int = Field(default=2, ge=1)
    only_label_columns: bool = True


class ExcelImportRequest(ExcelAnalyzeRequest):
    estado_regla: Literal["borrador", "activa", "inactiva", "archivada"] = "activa"
    tipo_regla: Literal["automatica", "manual", "mixta"] = "automatica"
    prioridad_base: int = 100
    procesar_recalculo_inmediato: bool = True


class GuidedConditionRequest(BaseModel):
    campo: str = Field(min_length=1)
    condicion: Literal[
        "contiene",
        "mayor_que",
        "menor_que",
        "igual_a",
        "diferente",
        "mayor_igual",
        "menor_igual",
        "entre",
        "nulo",
        "no_nulo",
    ]
    valor: str | float | int | None = None
    valor_min: float | None = None
    valor_max: float | None = None
    conector: Literal["AND", "OR"] = "AND"
    negado: bool = False


class GuidedRuleCreateRequest(BaseModel):
    id_etiqueta: int = Field(gt=0)
    nombre_regla: str = Field(min_length=3, max_length=180)
    codigo_regla: str | None = None
    formula_excel_original: str | None = None
    condiciones: list[GuidedConditionRequest] = Field(default_factory=list)
    prioridad: int = 100
    procesar_recalculo_inmediato: bool = True


class EditableRuleConditionRequest(BaseModel):
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


class RuleUpdateRequest(BaseModel):
    nombre_regla: str | None = Field(default=None, max_length=180)
    estado: Literal["borrador", "activa", "inactiva", "archivada"] | None = None
    tipo_regla: Literal["automatica", "manual", "mixta"] | None = None
    prioridad: int | None = None
    formula_excel_original: str | None = None
    expresion_humana: str | None = None
    umbral_resumen: dict[str, Any] | None = None
    condiciones: list[EditableRuleConditionRequest] | None = None
    procesar_recalculo_inmediato: bool = True


class OutcomeValidationRequest(BaseModel):
    id_regla_version: int | None = Field(default=None, gt=0)
    subcategoria: str | None = None
    limite_por_resultado: int = Field(default=1, ge=1, le=5)


class FixedFieldCreateRequest(BaseModel):
    codigo: str
    nombre_visible: str
    tipo_dato: Literal["numeric", "text", "boolean", "date", "json"] = "numeric"
    categoria_funcional: str | None = None
    clasificacion: str | None = None
    unidad: str | None = None
    descripcion: str | None = None
    origen_catalogo: Literal["manual", "csv"] = "manual"
    participa_en_reglas: bool = True
    participa_en_calculos: bool = False
    permite_nulos: bool = True


class CalculatedFieldCreateRequest(BaseModel):
    codigo: str
    nombre_visible: str
    descripcion: str | None = None
    columnas_origen: list[str] = Field(default_factory=list)
    formula_conceptual: str
    formula_excel_original: str | None = None
    unidad: str | None = None
    politica_dato_faltante: Literal[
        "insuficiente_dato",
        "no_aplica",
        "pendiente",
        "calcular_con_cero",
    ] = "insuficiente_dato"
    persistir_resultado: bool = True
    etiquetas_alimentadas: list[str] = Field(default_factory=list)
    orden: int | None = None
    activo: bool = True


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------


def _bounded_code(text: str, max_len: int = 120) -> str:
    code = slugify(text)
    return code[:max_len] if len(code) > max_len else code


def _json(data: Any) -> str:
    return json.dumps(data, ensure_ascii=False)


def _to_rows(cur, rows: list[tuple[Any, ...]]) -> list[dict[str, Any]]:
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, row, strict=False)) for row in rows]


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


def _enqueue_massive_recalc(cur, user_id: str | None, reason: str) -> int:
    cur.execute(
        """
        select dom_nutricion_reglas.rpc_solicitar_recalculo_masivo(
            %s,
            %s::jsonb
        )
        """,
        (user_id, _json({"trigger": "api", "reason": reason})),
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=500, detail="No se pudo crear job de recálculo")
    return int(row[0])


def _insert_rule_conditions(
    cur,
    id_regla_version: int,
    conditions: list[dict[str, Any]],
) -> int:
    inserted = 0
    for cond in conditions:
        variable_code = cond.get("variable_codigo")
        id_variable = None
        if variable_code:
            found = _find_variable(cur, str(variable_code))
            if not found:
                raise HTTPException(
                    status_code=404,
                    detail=f"Variable no encontrada en condicion: {variable_code}",
                )
            id_variable = found[0]

        cond_json = {
            "source": "api",
            "variable_codigo": variable_code,
            "tipo_condicion": cond.get("tipo_condicion"),
            "operador": cond.get("operador"),
        }

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
                id_regla_version,
                int(cond.get("orden") or 1),
                int(cond.get("grupo_logico") or 1),
                str(cond.get("conector_grupo") or "AND").upper(),
                cond.get("tipo_condicion"),
                id_variable,
                cond.get("operador"),
                cond.get("valor_numero"),
                cond.get("valor_numero_min"),
                cond.get("valor_numero_max"),
                cond.get("valor_texto"),
                cond.get("valor_lista"),
                cond.get("campo_objetivo"),
                bool(cond.get("negado", False)),
                cond.get("descripcion_humana"),
                _json(cond_json),
            ),
        )
        inserted += 1
    return inserted


def _ensure_label(cur, column_name: str, result_value: str) -> int:
    code = _bounded_code(f"excel_{column_name}_{result_value}", 80)
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
            activa,
            objetivo_clinico,
            interpretacion_base,
            admite_correccion_manual,
            persistir_resultado,
            created_at,
            updated_at
        ) values (
            %s, %s, %s, %s, %s,
            'automatica', 100, true, %s, %s,
            true, true, now(), now()
        )
        on conflict (codigo)
        do update set
            nombre_visible = excluded.nombre_visible,
            categoria = excluded.categoria,
            subcategoria = excluded.subcategoria,
            descripcion = excluded.descripcion,
            tipo_etiqueta = excluded.tipo_etiqueta,
            activa = true,
            updated_at = now()
        returning id
        """,
        (
            code,
            result_value,
            "Etiquetas nutricionales",
            column_name,
            f"Resultado importado desde Excel para columna '{column_name}'.",
            f"Clasificacion automatica importada desde Excel ({column_name}).",
            f"Resultado esperado: {result_value}",
        ),
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=500, detail="No se pudo crear/actualizar etiqueta")
    return int(row[0])


def _next_rule_version(cur, id_etiqueta: int) -> int:
    cur.execute(
        """
        select coalesce(max(version), 0) + 1
        from dom_nutricion_reglas.etiqueta_regla_version
        where id_etiqueta = %s
        """,
        (id_etiqueta,),
    )
    return int(cur.fetchone()[0])


def _load_rule_with_conditions(cur, id_regla_version: int) -> dict[str, Any] | None:
    cur.execute(
        """
        select
            rv.id,
            rv.id_etiqueta,
            rv.version,
            rv.codigo_regla,
            rv.nombre_regla,
            rv.estado,
            rv.tipo_regla,
            rv.prioridad,
            rv.expresion_humana,
            rv.formula_excel_original,
            rv.campos_intervienen,
            rv.umbral_resumen,
            rv.es_importada_excel,
            rv.activo,
            rv.created_at,
            rv.updated_at,
            e.nombre_visible as etiqueta_nombre,
            e.subcategoria as etiqueta_subcategoria
        from dom_nutricion_reglas.etiqueta_regla_version rv
        inner join dom_nutricion_catalogos.etiqueta_nutricional e
            on e.id = rv.id_etiqueta
        where rv.id = %s
        limit 1
        """,
        (id_regla_version,),
    )
    row = cur.fetchone()
    if not row:
        return None

    cur.execute(
        """
        select
            c.id,
            c.orden,
            c.grupo_logico,
            c.conector_grupo,
            c.tipo_condicion,
            vn.codigo as variable_codigo,
            c.operador,
            c.valor_numero,
            c.valor_numero_min,
            c.valor_numero_max,
            c.valor_texto,
            c.valor_lista,
            c.campo_objetivo,
            c.negado,
            c.descripcion_humana,
            c.activa
        from dom_nutricion_reglas.etiqueta_regla_condicion c
        left join dom_nutricion_catalogos.variable_nutricional vn
            on vn.id = c.id_variable_nutricional
        where c.id_regla_version = %s
        order by c.orden
        """,
        (id_regla_version,),
    )
    conds = _to_rows(cur, cur.fetchall())

    return {
        "id": int(row[0]),
        "id_etiqueta": int(row[1]),
        "version": int(row[2]),
        "codigo_regla": row[3],
        "nombre_regla": row[4],
        "estado": row[5],
        "tipo_regla": row[6],
        "prioridad": row[7],
        "expresion_humana": row[8],
        "formula_excel_original": row[9],
        "campos_intervienen": row[10] or [],
        "umbral_resumen": row[11] or {},
        "es_importada_excel": bool(row[12]),
        "activo": bool(row[13]),
        "created_at": str(row[14]) if row[14] else None,
        "updated_at": str(row[15]) if row[15] else None,
        "etiqueta_nombre": row[16],
        "etiqueta_subcategoria": row[17],
        "condiciones": conds,
    }


def _build_guided_condition_payload(items: list[GuidedConditionRequest]) -> list[dict[str, Any]]:
    payload: list[dict[str, Any]] = []
    order = 1

    for item in items:
        field_code = slugify(item.campo)
        cond_type = "variable_compare"
        operator = None
        value_number = None
        value_text = None
        value_min = None
        value_max = None
        field_name_like = bool(re.search(r"nombre|ingrediente|sinonimo", normalize_text(item.campo)))

        if item.condicion == "contiene":
            if field_name_like:
                cond_type = "text_contains_name"
                value_text = str(item.valor or "")
            else:
                operator = "contains"
                value_text = str(item.valor or "")
        elif item.condicion == "mayor_que":
            operator = ">"
            value_number = float(item.valor) if item.valor is not None else None
        elif item.condicion == "menor_que":
            operator = "<"
            value_number = float(item.valor) if item.valor is not None else None
        elif item.condicion == "igual_a":
            operator = "=="
            if isinstance(item.valor, (int, float)):
                value_number = float(item.valor)
            else:
                value_text = str(item.valor or "")
        elif item.condicion == "diferente":
            operator = "!="
            if isinstance(item.valor, (int, float)):
                value_number = float(item.valor)
            else:
                value_text = str(item.valor or "")
        elif item.condicion == "mayor_igual":
            operator = ">="
            value_number = float(item.valor) if item.valor is not None else None
        elif item.condicion == "menor_igual":
            operator = "<="
            value_number = float(item.valor) if item.valor is not None else None
        elif item.condicion == "entre":
            cond_type = "between"
            value_min = item.valor_min
            value_max = item.valor_max
        elif item.condicion == "nulo":
            cond_type = "is_null"
        elif item.condicion == "no_nulo":
            cond_type = "is_not_null"

        payload.append(
            {
                "orden": order,
                "grupo_logico": 1,
                "conector_grupo": item.conector,
                "tipo_condicion": cond_type,
                "variable_codigo": None if cond_type == "text_contains_name" else field_code,
                "operador": operator,
                "valor_numero": value_number,
                "valor_numero_min": value_min,
                "valor_numero_max": value_max,
                "valor_texto": value_text,
                "valor_lista": None,
                "campo_objetivo": item.campo,
                "negado": item.negado,
                "descripcion_humana": None,
            }
        )
        order += 1

    return payload


def normalize_text(value: str) -> str:
    text = value.strip().lower()
    text = re.sub(r"\s+", " ", text)
    return text


def _load_rule_conditions_for_preview(cur, id_regla_version: int) -> list[dict[str, Any]]:
    cur.execute(
        """
        select
            c.orden,
            c.grupo_logico,
            c.conector_grupo,
            c.tipo_condicion,
            vn.codigo,
            c.operador,
            c.valor_numero,
            c.valor_numero_min,
            c.valor_numero_max,
            c.valor_texto,
            c.valor_lista,
            c.campo_objetivo,
            c.negado,
            c.descripcion_humana
        from dom_nutricion_reglas.etiqueta_regla_condicion c
        left join dom_nutricion_catalogos.variable_nutricional vn
            on vn.id = c.id_variable_nutricional
        where c.id_regla_version = %s
          and c.activa = true
        order by c.orden
        """,
        (id_regla_version,),
    )

    out: list[dict[str, Any]] = []
    for row in cur.fetchall():
        out.append(
            {
                "orden": int(row[0]),
                "grupo_logico": int(row[1] or 1),
                "conector_grupo": row[2] or "AND",
                "tipo_condicion": row[3],
                "variable_codigo": row[4],
                "operador": row[5],
                "valor_numero": row[6],
                "valor_numero_min": row[7],
                "valor_numero_max": row[8],
                "valor_texto": row[9],
                "valor_lista": row[10],
                "campo_objetivo": row[11],
                "negado": bool(row[12]),
                "descripcion_humana": row[13],
            }
        )
    return out


def _load_used_values(cur, id_ingrediente: int, variable_codes: list[str]) -> dict[str, Any]:
    if not variable_codes:
        return {}

    cur.execute(
        """
        select
            vn.codigo,
            coalesce(iv.valor_numerico::text, iv.valor_texto, iv.valor_booleano::text, '[sin_dato]') as valor
        from dom_nutricion_ingrediente_rel.ingrediente_variable_valor iv
        inner join dom_nutricion_catalogos.variable_nutricional vn
            on vn.id = iv.id_variable_nutricional
        where iv.id_ingrediente = %s
          and lower(vn.codigo) = any(%s)
        """,
        (id_ingrediente, [c.lower() for c in variable_codes]),
    )
    return {str(row[0]): row[1] for row in cur.fetchall()}


# -----------------------------------------------------------------------------
# Endpoints
# -----------------------------------------------------------------------------


@router.post("/excel/analizar")
def analyze_excel_rules(
    payload: ExcelAnalyzeRequest,
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        return analyze_excel_formulas(
            xlsx_path=payload.xlsx_path,
            sheet_name=payload.sheet_name,
            formula_row=payload.formula_row,
            only_label_columns=payload.only_label_columns,
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/excel/importar")
def import_excel_rules(
    payload: ExcelImportRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    analysis = analyze_excel_formulas(
        xlsx_path=payload.xlsx_path,
        sheet_name=payload.sheet_name,
        formula_row=payload.formula_row,
        only_label_columns=payload.only_label_columns,
    )

    created_rules: list[dict[str, Any]] = []
    warnings: list[str] = []

    with db_cursor() as cur:
        for formula_item in analysis["formulas_detectadas"]:
            column_name = formula_item["columna"]
            formula_excel = formula_item["formula_excel"]
            branches = formula_item["reglas_detectadas"]

            if not branches:
                warnings.append(f"Columna sin ramas detectables: {column_name}")
                continue

            for branch in branches:
                result_value = str(branch["resultado"]).strip()
                if not result_value:
                    continue

                conditions = branch["condiciones"]
                label_id = _ensure_label(cur, column_name, result_value)
                version = _next_rule_version(cur, label_id)
                rule_code = _bounded_code(f"excel_{column_name}_{result_value}_v{version}", 120)
                campos_intervienen = sorted(
                    {
                        str(c.get("variable_codigo"))
                        for c in conditions
                        if c.get("variable_codigo")
                    }
                )

                human = branch.get("expresion_humana") or build_human_rule(
                    rule_name=f"{column_name} -> {result_value}",
                    conditions=conditions,
                    result_label_name=result_value,
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
                        true, true, %s
                    )
                    returning id
                    """,
                    (
                        label_id,
                        version,
                        rule_code,
                        f"Regla importada Excel: {column_name} = {result_value}",
                        payload.estado_regla,
                        payload.tipo_regla,
                        payload.prioridad_base,
                        _json(
                            {
                                "source": "excel",
                                "columna": column_name,
                                "resultado": result_value,
                                "condiciones": conditions,
                            }
                        ),
                        human,
                        formula_excel,
                        campos_intervienen,
                        _json(
                            {
                                "columna_etiqueta": column_name,
                                "resultado_objetivo": result_value,
                                "funciones_detectadas": formula_item.get("funciones_detectadas", []),
                            }
                        ),
                        user.user_id,
                    ),
                )
                row = cur.fetchone()
                if not row:
                    raise HTTPException(status_code=500, detail="No se pudo crear regla importada")
                id_regla_version = int(row[0])

                inserted = _insert_rule_conditions(cur, id_regla_version, conditions)

                cur.execute(
                    """
                    insert into dom_nutricion_reglas.auditoria_cambio (
                        entidad, id_entidad, accion, detalle, changed_by
                    ) values (
                        'etiqueta_regla_version',
                        %s,
                        'import_excel',
                        %s::jsonb,
                        %s
                    )
                    """,
                    (
                        str(id_regla_version),
                        _json(
                            {
                                "label_id": label_id,
                                "column_name": column_name,
                                "result_value": result_value,
                                "formula_excel": formula_excel,
                                "conditions_inserted": inserted,
                            }
                        ),
                        user.user_id,
                    ),
                )

                created_rules.append(
                    {
                        "id_regla_version": id_regla_version,
                        "id_etiqueta": label_id,
                        "columna": column_name,
                        "resultado": result_value,
                        "version": version,
                        "condiciones": inserted,
                    }
                )

        job_id = _enqueue_massive_recalc(cur, user.user_id, "import_excel_rules")

    processed = None
    if payload.procesar_recalculo_inmediato:
        processed = process_one_pending_recalculation_job()

    return {
        "archivo": analysis["archivo"],
        "formulas_detectadas": analysis["total_formulas_detectadas"],
        "reglas_detectadas": analysis["total_reglas_detectadas"],
        "reglas_creadas": len(created_rules),
        "detalle_reglas": created_rules,
        "warnings": warnings,
        "recalculo_job_id": job_id,
        "recalculo_procesado": processed,
    }


@router.get("/reglas")
def list_editable_rules(
    id_etiqueta: int | None = Query(default=None),
    estado: str | None = Query(default=None),
    q: str | None = Query(default=None),
    solo_activas: bool = Query(default=True),
    limit: int = Query(default=200, ge=1, le=1000),
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    where: list[str] = ["1=1"]
    params: list[Any] = []

    if id_etiqueta is not None:
        where.append("rv.id_etiqueta = %s")
        params.append(id_etiqueta)

    if estado:
        where.append("lower(rv.estado) = lower(%s)")
        params.append(estado)

    if q:
        where.append(
            "(rv.codigo_regla ilike ('%' || %s || '%') or rv.nombre_regla ilike ('%' || %s || '%') or e.nombre_visible ilike ('%' || %s || '%'))"
        )
        params.extend([q, q, q])

    if solo_activas:
        where.append("rv.activo = true")

    where_sql = " and ".join(where)

    with db_cursor() as cur:
        cur.execute(
            f"""
            select
                rv.id,
                rv.id_etiqueta,
                e.codigo as etiqueta_codigo,
                e.nombre_visible as etiqueta_nombre,
                e.subcategoria as etiqueta_subcategoria,
                rv.version,
                rv.codigo_regla,
                rv.nombre_regla,
                rv.estado,
                rv.tipo_regla,
                rv.prioridad,
                rv.expresion_humana,
                rv.formula_excel_original,
                rv.es_importada_excel,
                rv.activo,
                rv.updated_at
            from dom_nutricion_reglas.etiqueta_regla_version rv
            inner join dom_nutricion_catalogos.etiqueta_nutricional e
                on e.id = rv.id_etiqueta
            where {where_sql}
            order by rv.updated_at desc, rv.id desc
            limit %s
            """,
            (*params, limit),
        )
        rules_rows = cur.fetchall()
        rules = _to_rows(cur, rules_rows)

        if not rules:
            return {"total": 0, "items": []}

        rule_ids = [int(r["id"]) for r in rules]
        cur.execute(
            """
            select
                c.id_regla_version,
                c.id,
                c.orden,
                c.grupo_logico,
                c.conector_grupo,
                c.tipo_condicion,
                vn.codigo as variable_codigo,
                c.operador,
                c.valor_numero,
                c.valor_numero_min,
                c.valor_numero_max,
                c.valor_texto,
                c.valor_lista,
                c.campo_objetivo,
                c.negado,
                c.descripcion_humana,
                c.activa
            from dom_nutricion_reglas.etiqueta_regla_condicion c
            left join dom_nutricion_catalogos.variable_nutricional vn
                on vn.id = c.id_variable_nutricional
            where c.id_regla_version = any(%s)
            order by c.id_regla_version, c.orden
            """,
            (rule_ids,),
        )
        cond_rows = _to_rows(cur, cur.fetchall())

    cond_by_rule: dict[int, list[dict[str, Any]]] = {}
    for row in cond_rows:
        rid = int(row["id_regla_version"])
        cond_by_rule.setdefault(rid, []).append(row)

    for row in rules:
        rid = int(row["id"])
        row["condiciones"] = cond_by_rule.get(rid, [])

    return {"total": len(rules), "items": rules}


@router.get("/etiquetas")
def list_available_labels(
    q: str | None = Query(default=None),
    solo_activas: bool = Query(default=True),
    limit: int = Query(default=300, ge=1, le=2000),
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    where: list[str] = ["1=1"]
    params: list[Any] = []

    if q:
        where.append(
            "(e.codigo ilike ('%' || %s || '%') or e.nombre_visible ilike ('%' || %s || '%') or coalesce(e.subcategoria, '') ilike ('%' || %s || '%'))"
        )
        params.extend([q, q, q])

    if solo_activas:
        where.append("e.activa = true")

    where_sql = " and ".join(where)

    with db_cursor() as cur:
        cur.execute(
            f"""
            select
                e.id,
                e.codigo,
                e.nombre_visible,
                e.categoria,
                e.subcategoria,
                e.prioridad,
                e.activa,
                e.updated_at
            from dom_nutricion_catalogos.etiqueta_nutricional e
            where {where_sql}
            order by e.prioridad asc, e.nombre_visible asc
            limit %s
            """,
            (*params, limit),
        )
        rows = _to_rows(cur, cur.fetchall())

    return {
        "total": len(rows),
        "items": rows,
    }


@router.post("/reglas/guiada")
def create_guided_rule(
    payload: GuidedRuleCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    if not payload.condiciones:
        raise HTTPException(status_code=400, detail="Debe enviar al menos una condicion")

    canonical_conditions = _build_guided_condition_payload(payload.condiciones)

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

        version = _next_rule_version(cur, payload.id_etiqueta)
        code = payload.codigo_regla or _bounded_code(
            f"guiada_{payload.id_etiqueta}_{payload.nombre_regla}_{version}",
            120,
        )

        human = build_human_rule(
            rule_name=payload.nombre_regla,
            conditions=canonical_conditions,
            result_label_name=str(tag_row[0]),
        )

        campos = sorted(
            {
                str(c.get("variable_codigo"))
                for c in canonical_conditions
                if c.get("variable_codigo")
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
                'activa', 'automatica', %s,
                %s::jsonb, %s, %s,
                %s, %s::jsonb,
                false, true, %s
            )
            returning id
            """,
            (
                payload.id_etiqueta,
                version,
                code,
                payload.nombre_regla,
                payload.prioridad,
                _json({"builder": "guiado", "condiciones": canonical_conditions}),
                human,
                payload.formula_excel_original,
                campos,
                _json({"origen": "guiado"}),
                user.user_id,
            ),
        )
        rule_row = cur.fetchone()
        if not rule_row:
            raise HTTPException(status_code=500, detail="No se pudo crear regla")

        id_regla_version = int(rule_row[0])
        inserted = _insert_rule_conditions(cur, id_regla_version, canonical_conditions)

        cur.execute(
            """
            insert into dom_nutricion_reglas.auditoria_cambio (
                entidad, id_entidad, accion, detalle, changed_by
            ) values (
                'etiqueta_regla_version',
                %s,
                'create_guided',
                %s::jsonb,
                %s
            )
            """,
            (
                str(id_regla_version),
                _json(payload.model_dump()),
                user.user_id,
            ),
        )

        job_id = _enqueue_massive_recalc(cur, user.user_id, "create_guided_rule")

    processed = None
    if payload.procesar_recalculo_inmediato:
        processed = process_one_pending_recalculation_job()

    return {
        "id_regla_version": id_regla_version,
        "version": version,
        "condiciones_insertadas": inserted,
        "expresion_humana": human,
        "recalculo_job_id": job_id,
        "recalculo_procesado": processed,
    }


@router.put("/reglas/{id_regla_version}")
def update_editable_rule(
    id_regla_version: int,
    payload: RuleUpdateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        existing = _load_rule_with_conditions(cur, id_regla_version)
        if not existing:
            raise HTTPException(status_code=404, detail="Regla no encontrada")

        sets: list[str] = []
        values: list[Any] = []

        if payload.nombre_regla is not None:
            sets.append("nombre_regla = %s")
            values.append(payload.nombre_regla)
        if payload.estado is not None:
            sets.append("estado = %s")
            values.append(payload.estado)
        if payload.tipo_regla is not None:
            sets.append("tipo_regla = %s")
            values.append(payload.tipo_regla)
        if payload.prioridad is not None:
            sets.append("prioridad = %s")
            values.append(payload.prioridad)
        if payload.formula_excel_original is not None:
            sets.append("formula_excel_original = %s")
            values.append(payload.formula_excel_original)
        if payload.umbral_resumen is not None:
            sets.append("umbral_resumen = %s::jsonb")
            values.append(_json(payload.umbral_resumen))

        working_conditions = (
            [c.model_dump() for c in payload.condiciones]
            if payload.condiciones is not None
            else [
                {
                    "orden": int(c["orden"]),
                    "grupo_logico": int(c.get("grupo_logico") or 1),
                    "conector_grupo": str(c.get("conector_grupo") or "AND"),
                    "tipo_condicion": c.get("tipo_condicion"),
                    "variable_codigo": c.get("variable_codigo"),
                    "operador": c.get("operador"),
                    "valor_numero": c.get("valor_numero"),
                    "valor_numero_min": c.get("valor_numero_min"),
                    "valor_numero_max": c.get("valor_numero_max"),
                    "valor_texto": c.get("valor_texto"),
                    "valor_lista": c.get("valor_lista"),
                    "campo_objetivo": c.get("campo_objetivo"),
                    "negado": bool(c.get("negado", False)),
                    "descripcion_humana": c.get("descripcion_humana"),
                }
                for c in existing["condiciones"]
            ]
        )

        if payload.expresion_humana is not None:
            expression_human = payload.expresion_humana
        else:
            expression_human = build_human_rule(
                rule_name=payload.nombre_regla or str(existing["nombre_regla"]),
                conditions=working_conditions,
                result_label_name=str(existing["etiqueta_nombre"]),
            )

        sets.append("expresion_humana = %s")
        values.append(expression_human)

        campos = sorted(
            {
                str(c.get("variable_codigo"))
                for c in working_conditions
                if c.get("variable_codigo")
            }
        )
        sets.append("campos_intervienen = %s")
        values.append(campos)

        sets.append("updated_at = now()")

        cur.execute(
            f"""
            update dom_nutricion_reglas.etiqueta_regla_version
            set {', '.join(sets)}
            where id = %s
            """,
            (*values, id_regla_version),
        )

        inserted_conditions = 0
        if payload.condiciones is not None:
            cur.execute(
                """
                delete from dom_nutricion_reglas.etiqueta_regla_condicion
                where id_regla_version = %s
                """,
                (id_regla_version,),
            )
            inserted_conditions = _insert_rule_conditions(cur, id_regla_version, working_conditions)

        cur.execute(
            """
            insert into dom_nutricion_reglas.auditoria_cambio (
                entidad, id_entidad, accion, detalle, changed_by
            ) values (
                'etiqueta_regla_version',
                %s,
                'update',
                %s::jsonb,
                %s
            )
            """,
            (
                str(id_regla_version),
                _json(payload.model_dump()),
                user.user_id,
            ),
        )

        job_id = _enqueue_massive_recalc(cur, user.user_id, "update_rule")

    processed = None
    if payload.procesar_recalculo_inmediato:
        processed = process_one_pending_recalculation_job()

    return {
        "id_regla_version": id_regla_version,
        "updated": True,
        "condiciones_reemplazadas": payload.condiciones is not None,
        "condiciones_insertadas": inserted_conditions,
        "recalculo_job_id": job_id,
        "recalculo_procesado": processed,
    }


@router.delete("/reglas/{id_regla_version}")
def delete_rule(
    id_regla_version: int,
    hard_delete: bool = Query(default=False),
    procesar_recalculo_inmediato: bool = Query(default=True),
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        existing = _load_rule_with_conditions(cur, id_regla_version)
        if not existing:
            raise HTTPException(status_code=404, detail="Regla no encontrada")

        if hard_delete:
            cur.execute(
                """
                delete from dom_nutricion_reglas.etiqueta_regla_version
                where id = %s
                """,
                (id_regla_version,),
            )
            action = "delete_hard"
        else:
            cur.execute(
                """
                update dom_nutricion_reglas.etiqueta_regla_version
                set activo = false,
                    estado = 'archivada',
                    updated_at = now()
                where id = %s
                """,
                (id_regla_version,),
            )
            action = "delete_soft"

        # Mandatory behavior: remove label assignment from all ingredients for this rule.
        cur.execute(
            """
            update dom_nutricion_ingrediente_rel.ingrediente_etiqueta
            set activa = false,
                estado_calculo = 'excluido',
                manual_override = true,
                motivo_manual = 'Regla eliminada o archivada',
                updated_at = now()
            where id_regla_version = %s
            """,
            (id_regla_version,),
        )
        affected = cur.rowcount

        cur.execute(
            """
            insert into dom_nutricion_reglas.auditoria_cambio (
                entidad, id_entidad, accion, detalle, changed_by
            ) values (
                'etiqueta_regla_version',
                %s,
                %s,
                %s::jsonb,
                %s
            )
            """,
            (
                str(id_regla_version),
                action,
                _json({"hard_delete": hard_delete, "affected_assignments": affected}),
                user.user_id,
            ),
        )

        job_id = _enqueue_massive_recalc(cur, user.user_id, "delete_rule")

    processed = None
    if procesar_recalculo_inmediato:
        processed = process_one_pending_recalculation_job()

    return {
        "id_regla_version": id_regla_version,
        "deleted": True,
        "hard_delete": hard_delete,
        "asignaciones_inactivadas": affected,
        "recalculo_job_id": job_id,
        "recalculo_procesado": processed,
    }


@router.post("/validacion/resultados")
def validate_outcomes_with_examples(
    payload: OutcomeValidationRequest,
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        subcategoria = payload.subcategoria

        if payload.id_regla_version is not None:
            cur.execute(
                """
                select e.subcategoria
                from dom_nutricion_reglas.etiqueta_regla_version rv
                inner join dom_nutricion_catalogos.etiqueta_nutricional e
                    on e.id = rv.id_etiqueta
                where rv.id = %s
                limit 1
                """,
                (payload.id_regla_version,),
            )
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Regla no encontrada")
            subcategoria = row[0]

        if not subcategoria:
            raise HTTPException(status_code=400, detail="Debe enviar id_regla_version o subcategoria")

        cur.execute(
            """
            select
                e.id,
                e.nombre_visible,
                e.subcategoria,
                rv.id as id_regla_version
            from dom_nutricion_catalogos.etiqueta_nutricional e
            left join lateral (
                select id
                from dom_nutricion_reglas.etiqueta_regla_version r
                where r.id_etiqueta = e.id
                  and r.activo = true
                  and r.estado = 'activa'
                order by r.version desc
                limit 1
            ) rv on true
            where lower(e.subcategoria) = lower(%s)
              and e.activa = true
            order by e.prioridad, e.nombre_visible
            """,
            (subcategoria,),
        )
        outcomes = _to_rows(cur, cur.fetchall())

        result_items: list[dict[str, Any]] = []

        for item in outcomes:
            label_id = int(item["id"])
            rule_id = item.get("id_regla_version")

            cur.execute(
                """
                select
                    i.id,
                    i.nombre
                from dom_nutricion_ingrediente_rel.ingrediente_etiqueta ie
                inner join dom_nutricion_ingredientes.ingrediente i
                    on i.id = ie.id_ingrediente
                where ie.id_etiqueta = %s
                  and ie.activa = true
                order by ie.updated_at desc nulls last, ie.id desc
                limit %s
                """,
                (label_id, payload.limite_por_resultado),
            )
            samples = cur.fetchall()

            fallback_ids: list[int] = []
            condition_payload: list[dict[str, Any]] = []
            if not samples and rule_id is not None:
                condition_payload = _load_rule_conditions_for_preview(cur, int(rule_id))
                if condition_payload:
                    preview = preview_ad_hoc_rule(condition_payload, detail_limit=payload.limite_por_resultado)
                    fallback_ids = [int(x["id"]) for x in preview.get("muestra_cumplen", [])]

            if not samples and fallback_ids:
                cur.execute(
                    """
                    select id, nombre
                    from dom_nutricion_ingredientes.ingrediente
                    where id = any(%s)
                    order by id
                    """,
                    (fallback_ids,),
                )
                samples = cur.fetchall()

            variable_codes = sorted(
                {
                    str(c.get("variable_codigo"))
                    for c in (condition_payload or _load_rule_conditions_for_preview(cur, int(rule_id)) if rule_id else [])
                    if c.get("variable_codigo")
                }
            )

            example_rows: list[dict[str, Any]] = []
            for sample in samples:
                ing_id = int(sample[0])
                used_values = _load_used_values(cur, ing_id, variable_codes)
                example_rows.append(
                    {
                        "id_ingrediente": ing_id,
                        "ingrediente": sample[1],
                        "valores_usados": used_values,
                        "resultado_calculado": item["nombre_visible"],
                    }
                )

            result_items.append(
                {
                    "id_etiqueta": label_id,
                    "resultado": item["nombre_visible"],
                    "subcategoria": item["subcategoria"],
                    "id_regla_version": rule_id,
                    "ejemplos": example_rows,
                    "tiene_ejemplos": len(example_rows) > 0,
                }
            )

    covered = sum(1 for item in result_items if item["tiene_ejemplos"])
    return {
        "subcategoria": subcategoria,
        "total_resultados": len(result_items),
        "resultados_con_ejemplo": covered,
        "resultados_sin_ejemplo": len(result_items) - covered,
        "items": result_items,
    }


@router.get("/campos")
def list_fields(
    q: str | None = Query(default=None),
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            select
                id,
                codigo,
                nombre_visible,
                tipo_dato,
                categoria_funcional,
                clasificacion,
                unidad,
                origen_catalogo,
                participa_en_reglas,
                participa_en_calculos,
                es_calculable,
                activo
            from dom_nutricion_catalogos.variable_nutricional
            where (%s is null or codigo ilike ('%' || %s || '%') or nombre_visible ilike ('%' || %s || '%'))
            order by categoria_funcional nulls last, nombre_visible
            """,
            (q, q, q),
        )
        variables = _to_rows(cur, cur.fetchall())

        cur.execute(
            """
            select
                id,
                codigo,
                nombre_visible,
                columnas_origen,
                formula_conceptual,
                formula_excel_original,
                unidad,
                politica_dato_faltante,
                persistir_resultado,
                etiquetas_alimentadas,
                version,
                activo
            from dom_nutricion_reglas.campo_derivado_definicion
            where (%s is null or codigo ilike ('%' || %s || '%') or nombre_visible ilike ('%' || %s || '%'))
            order by nombre_visible
            """,
            (q, q, q),
        )
        calculated = _to_rows(cur, cur.fetchall())

    return {
        "variables_fijas": variables,
        "campos_calculados": calculated,
        "total_variables_fijas": len(variables),
        "total_campos_calculados": len(calculated),
    }


@router.post("/campos/fijos")
def create_fixed_field(
    payload: FixedFieldCreateRequest,
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
        existing = cur.fetchone()

        if existing:
            field_id = int(existing[0])
            cur.execute(
                """
                update dom_nutricion_catalogos.variable_nutricional
                set nombre_visible = %s,
                    tipo_dato = %s,
                    clasificacion = %s,
                    categoria_funcional = %s,
                    unidad = %s,
                    descripcion = %s,
                    origen_catalogo = %s,
                    participa_en_calculos = %s,
                    participa_en_reglas = %s,
                    permite_nulos = %s,
                    es_calculable = false,
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
                    payload.origen_catalogo,
                    payload.participa_en_calculos,
                    payload.participa_en_reglas,
                    payload.permite_nulos,
                    field_id,
                ),
            )
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
                    activo,
                    created_at,
                    updated_at
                ) values (
                    %s, %s, %s, %s, %s, %s, %s,
                    %s, false, %s, %s, %s, true, now(), now()
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
                    payload.origen_catalogo,
                    payload.participa_en_calculos,
                    payload.participa_en_reglas,
                    payload.permite_nulos,
                ),
            )
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=500, detail="No se pudo crear campo fijo")
            field_id = int(row[0])

        cur.execute(
            """
            insert into dom_nutricion_reglas.auditoria_cambio (
                entidad, id_entidad, accion, detalle, changed_by
            ) values (
                'variable_nutricional',
                %s,
                'upsert',
                %s::jsonb,
                %s
            )
            """,
            (str(field_id), _json(payload.model_dump()), user.user_id),
        )

    return {"id_variable": field_id, "ok": True}


@router.post("/campos/calculados")
def create_calculated_field(
    payload: CalculatedFieldCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            insert into dom_nutricion_reglas.campo_derivado_definicion (
                codigo,
                nombre_visible,
                descripcion,
                columnas_origen,
                formula_conceptual,
                formula_excel_original,
                unidad,
                politica_dato_faltante,
                persistir_resultado,
                etiquetas_alimentadas,
                orden,
                activo,
                updated_at
            ) values (
                %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, now()
            )
            on conflict (lower(codigo))
            do update set
                nombre_visible = excluded.nombre_visible,
                descripcion = excluded.descripcion,
                columnas_origen = excluded.columnas_origen,
                formula_conceptual = excluded.formula_conceptual,
                formula_excel_original = excluded.formula_excel_original,
                unidad = excluded.unidad,
                politica_dato_faltante = excluded.politica_dato_faltante,
                persistir_resultado = excluded.persistir_resultado,
                etiquetas_alimentadas = excluded.etiquetas_alimentadas,
                orden = excluded.orden,
                activo = excluded.activo,
                version = dom_nutricion_reglas.campo_derivado_definicion.version + 1,
                updated_at = now()
            returning id, version
            """,
            (
                payload.codigo.strip(),
                payload.nombre_visible,
                payload.descripcion,
                payload.columnas_origen,
                payload.formula_conceptual,
                payload.formula_excel_original,
                payload.unidad,
                payload.politica_dato_faltante,
                payload.persistir_resultado,
                payload.etiquetas_alimentadas,
                payload.orden,
                payload.activo,
            ),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=500, detail="No se pudo crear campo calculado")

        field_id = int(row[0])
        version = int(row[1])

        cur.execute(
            """
            insert into dom_nutricion_reglas.auditoria_cambio (
                entidad, id_entidad, accion, detalle, changed_by
            ) values (
                'campo_derivado_definicion',
                %s,
                'upsert',
                %s::jsonb,
                %s
            )
            """,
            (str(field_id), _json(payload.model_dump()), user.user_id),
        )

    return {"id_campo_calculado": field_id, "version": version, "ok": True}


@router.post("/excel/formula/interpretar")
def interpret_single_formula(
    formula: str,
    columna_etiqueta: str,
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    # Utility endpoint for debugging/manual migration of formulas.
    if not formula.startswith("="):
        raise HTTPException(status_code=400, detail="La formula debe comenzar con '='")

    rules = formula_to_branch_rules(
        formula=formula,
        label_column_name=columna_etiqueta,
        cell_to_header={},
    )
    return {
        "columna_etiqueta": columna_etiqueta,
        "formula": formula,
        "reglas_detectadas": rules,
        "total_reglas_detectadas": len(rules),
    }
