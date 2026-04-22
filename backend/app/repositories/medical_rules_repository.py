from app.core.db import db_cursor
from app.schemas.domain import MedicalRuleCreate, MedicalRuleUpdate, MedicalRuleResponse

# Tipos de condición Médica
ID_TIPO_CLINICA = 1
ID_TIPO_TEMPORAL = 2

def list_medical_rules() -> list[MedicalRuleResponse]:
    """Lista reglas vinculadas a condiciones clínicas y temporales."""
    sql = """
        SELECT 
            r.id, 
            r.id_accion, a.codigo as accion_codigo,
            r.id_tipo_objetivo, o.codigo as objetivo_codigo,
            r.id_ingrediente, i.nombre as ingrediente_nombre,
            r.id_grupo_alimentario, g.nombre as grupo_nombre,
            r.id_subgrupo_alimentario, s.nombre as subgrupo_nombre,
            r.id_etiqueta, e.nombre_visible as etiqueta_nombre,
            r.mensaje_error, r.es_estricta,
            COALESCE(array_agg(cr.id_condicion) FILTER (WHERE cr.id_condicion IS NOT NULL), '{}') as id_condiciones
        FROM heuristico.regla r
        JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
        JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo
        LEFT JOIN nutricion.ingrediente i ON i.id = r.id_ingrediente
        LEFT JOIN nutricion.grupo_alimentario g ON g.id = r.id_grupo_alimentario
        LEFT JOIN nutricion.subgrupo_alimentario s ON s.id = r.id_subgrupo_alimentario
        LEFT JOIN nutricion.etiqueta_nutricional e ON e.id = r.id_etiqueta
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        JOIN heuristico.condicion c ON c.id = cr.id_condicion
        WHERE c.id_tipo_condicion IN (%s, %s)
        GROUP BY r.id, a.codigo, o.codigo, i.nombre, g.nombre, s.nombre, e.nombre_visible
        ORDER BY r.id DESC
    """
    with db_cursor() as cur:
        cur.execute(sql, (ID_TIPO_CLINICA, ID_TIPO_TEMPORAL))
        rows = cur.fetchall()
        return [
            MedicalRuleResponse(
                id=r[0], id_accion=r[1], accion_codigo=r[2],
                id_tipo_objetivo=r[3], objetivo_codigo=r[4],
                id_ingrediente=r[5], ingrediente_nombre=r[6],
                id_grupo_alimentario=r[7], grupo_nombre=r[8],
                id_subgrupo_alimentario=r[9], subgrupo_nombre=r[10],
                id_etiqueta=r[11], etiqueta_nombre=r[12],
                mensaje_error=r[13], es_estricta=r[14],
                id_condiciones=list(r[15])
            )
            for r in rows
        ]

def get_medical_rule_form_data() -> dict:
    """Catálogos para el formulario de reglas médicas."""
    with db_cursor() as cur:
        cur.execute("SELECT id, codigo, nombre FROM heuristico.catalogo_accion ORDER BY id")
        acciones = [{"id": r[0], "codigo": r[1], "nombre": r[2]} for r in cur.fetchall()]
        
        cur.execute("SELECT id, codigo, nombre FROM heuristico.catalogo_objetivo_regla ORDER BY id")
        objetivos = [{"id": r[0], "codigo": r[1], "nombre": r[2]} for r in cur.fetchall()]
        
        cur.execute("SELECT id, nombre FROM heuristico.condicion WHERE activa = true AND id_tipo_condicion IN (1, 2) ORDER BY nombre")
        condiciones = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]

        cur.execute("SELECT id, nombre FROM nutricion.ingrediente ORDER BY nombre LIMIT 500")
        ingredientes = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]

        cur.execute("SELECT id, nombre FROM nutricion.grupo_alimentario ORDER BY nombre")
        grupos = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]

        cur.execute("SELECT id, nombre FROM nutricion.subgrupo_alimentario ORDER BY nombre")
        subgrupos = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]

        cur.execute("SELECT id, nombre_visible FROM nutricion.etiqueta_nutricional ORDER BY nombre_visible")
        etiquetas = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]
        
        return {
            "acciones": acciones, "objetivos": objetivos, "condiciones": condiciones,
            "ingredientes": ingredientes, "grupos": grupos, "subgrupos": subgrupos, "etiquetas": etiquetas
        }

def create_medical_rule(rule: MedicalRuleCreate, created_by: str = None) -> int:
    sql_regla = """
        INSERT INTO heuristico.regla (
            id_accion, id_tipo_objetivo, id_ingrediente, id_grupo_alimentario, 
            id_subgrupo_alimentario, id_etiqueta, mensaje_error, es_estricta, 
            created_by, origen_regla
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    """
    origen = rule.origen_regla or "MEDICA"
    with db_cursor() as cur:
        cur.execute(sql_regla, (
            rule.id_accion, rule.id_tipo_objetivo, rule.id_ingrediente,
            rule.id_grupo_alimentario, rule.id_subgrupo_alimentario,
            rule.id_etiqueta, rule.mensaje_error, rule.es_estricta, 
            created_by, origen
        ))
        id_regla = cur.fetchone()[0]
        
        for id_condicion in rule.id_condiciones:
            cur.execute("INSERT INTO heuristico.condicion_regla (id_regla, id_condicion) VALUES (%s, %s)", (id_regla, id_condicion))
        return id_regla

def update_medical_rule(id_regla: int, rule_update: MedicalRuleUpdate) -> bool:
    with db_cursor() as cur:
        fields = []
        params = []
        # Mapear campos opcionales...
        upd_map = {
            "id_accion": rule_update.id_accion,
            "id_tipo_objetivo": rule_update.id_tipo_objetivo,
            "id_ingrediente": rule_update.id_ingrediente,
            "id_grupo_alimentario": rule_update.id_grupo_alimentario,
            "id_subgrupo_alimentario": rule_update.id_subgrupo_alimentario,
            "id_etiqueta": rule_update.id_etiqueta,
            "mensaje_error": rule_update.mensaje_error,
            "es_estricta": rule_update.es_estricta,
            "origen_regla": rule_update.origen_regla
        }
        for k, v in upd_map.items():
            if v is not None:
                fields.append(f"{k} = %s")
                params.append(v)
        
        if fields:
            params.append(id_regla)
            cur.execute(f"UPDATE heuristico.regla SET {', '.join(fields)} WHERE id = %s", tuple(params))
            
        if rule_update.id_condiciones is not None:
            cur.execute("DELETE FROM heuristico.condicion_regla WHERE id_regla = %s", (id_regla,))
            for id_c in rule_update.id_condiciones:
                cur.execute("INSERT INTO heuristico.condicion_regla (id_regla, id_condicion) VALUES (%s, %s)", (id_regla, id_c))
        return True

def delete_medical_rule(id_regla: int) -> bool:
    with db_cursor() as cur:
        cur.execute("DELETE FROM heuristico.regla WHERE id = %s", (id_regla,))
        return cur.rowcount > 0
