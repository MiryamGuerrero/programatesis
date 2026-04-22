from app.core.db import db_cursor
from app.schemas.domain import NutritionalRuleCreate, NutritionalRuleUpdate, NutritionalRuleResponse

# ID del tipo de condición NUTRICIONAL según catálogo
ID_TIPO_NUTRICIONAL = 3

def list_nutritional_rules() -> list[NutritionalRuleResponse]:
    """
    Lista reglas que pertenecen exclusivamente a condiciones de tipo NUTRICIONAL.
    """
    sql = """
        SELECT 
            r.id, 
            r.id_etiqueta, 
            e.nombre_visible as etiqueta_nombre,
            r.id_accion, 
            a.codigo as accion_codigo,
            r.id_tipo_objetivo, 
            o.codigo as objetivo_codigo,
            r.mensaje_error,
            r.es_estricta,
            COALESCE(array_agg(cr.id_condicion) FILTER (WHERE cr.id_condicion IS NOT NULL), '{}') as id_condiciones
        FROM heuristico.regla r
        LEFT JOIN nutricion.etiqueta_nutricional e ON e.id = r.id_etiqueta
        JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
        JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo
        -- Unimos con condicion_regla y luego con condicion para filtrar por tipo
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        JOIN heuristico.condicion c ON c.id = cr.id_condicion
        WHERE c.id_tipo_condicion = %s
        GROUP BY r.id, e.nombre_visible, a.codigo, o.codigo
        ORDER BY e.nombre_visible ASC, r.id DESC
    """
    with db_cursor() as cur:
        cur.execute(sql, (ID_TIPO_NUTRICIONAL,))
        rows = cur.fetchall()
        return [
            NutritionalRuleResponse(
                id=r[0],
                id_etiqueta=r[1],
                etiqueta_nombre=r[2],
                id_accion=r[3],
                accion_codigo=r[4],
                id_tipo_objetivo=r[5],
                objetivo_codigo=r[6],
                mensaje_error=r[7],
                es_estricta=r[8],
                id_condiciones=list(r[9])
            )
            for r in rows
        ]

def get_nutritional_rule_form_data() -> dict:
    """
    Obtiene catálogos filtrando solo condiciones NUTRICIONALES para el formulario.
    """
    with db_cursor() as cur:
        # Acciones
        cur.execute("SELECT id, codigo, nombre FROM heuristico.catalogo_accion ORDER BY id")
        acciones = [{"id": r[0], "codigo": r[1], "nombre": r[2]} for r in cur.fetchall()]
        
        # Objetivos
        cur.execute("SELECT id, codigo, nombre FROM heuristico.catalogo_objetivo_regla ORDER BY id")
        objetivos = [{"id": r[0], "codigo": r[1], "nombre": r[2]} for r in cur.fetchall()]
        
        # Condiciones (SOLO NUTRICIONALES)
        cur.execute("""
            SELECT id, nombre, id_tipo_condicion 
            FROM heuristico.condicion 
            WHERE activa = true AND id_tipo_condicion = %s 
            ORDER BY nombre
        """, (ID_TIPO_NUTRICIONAL,))
        condiciones = [{"id": r[0], "nombre": r[1], "id_tipo_condicion": r[2]} for r in cur.fetchall()]
        
        # Etiquetas
        cur.execute("SELECT id, nombre_visible FROM nutricion.etiqueta_nutricional ORDER BY nombre_visible")
        etiquetas = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]
        
        return {
            "acciones": acciones,
            "objetivos": objetivos,
            "condiciones": condiciones,
            "etiquetas": etiquetas
        }

def create_nutritional_rule(rule: NutritionalRuleCreate, created_by: str = None) -> int:
    sql_regla = """
        INSERT INTO heuristico.regla (
            id_etiqueta, id_accion, id_tipo_objetivo, mensaje_error, es_estricta, created_by
        ) VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING id
    """
    with db_cursor() as cur:
        cur.execute(sql_regla, (
            rule.id_etiqueta, rule.id_accion, rule.id_tipo_objetivo, 
            rule.mensaje_error, rule.es_estricta, created_by
        ))
        id_regla = cur.fetchone()[0]
        
        # Insertar asociaciones con condiciones
        if rule.id_condiciones:
            for id_condicion in rule.id_condiciones:
                cur.execute(
                    "INSERT INTO heuristico.condicion_regla (id_regla, id_condicion) VALUES (%s, %s)",
                    (id_regla, id_condicion)
                )
        return id_regla

def update_nutritional_rule(id_regla: int, rule_update: NutritionalRuleUpdate) -> bool:
    with db_cursor() as cur:
        # 1. Actualizar campos de la regla
        fields = []
        params = []
        if rule_update.id_etiqueta is not None:
            fields.append("id_etiqueta = %s")
            params.append(rule_update.id_etiqueta)
        if rule_update.id_accion is not None:
            fields.append("id_accion = %s")
            params.append(rule_update.id_accion)
        if rule_update.mensaje_error is not None:
            fields.append("mensaje_error = %s")
            params.append(rule_update.mensaje_error)
        if rule_update.es_estricta is not None:
            fields.append("es_estricta = %s")
            params.append(rule_update.es_estricta)
            
        if fields:
            params.append(id_regla)
            sql = f"UPDATE heuristico.regla SET {', '.join(fields)} WHERE id = %s"
            cur.execute(sql, tuple(params))
            
        # 2. Actualizar condiciones (si se envian)
        if rule_update.id_condiciones is not None:
            cur.execute("DELETE FROM heuristico.condicion_regla WHERE id_regla = %s", (id_regla,))
            for id_condicion in rule_update.id_condiciones:
                cur.execute(
                    "INSERT INTO heuristico.condicion_regla (id_regla, id_condicion) VALUES (%s, %s)",
                    (id_regla, id_condicion)
                )
        return True

def delete_nutritional_rule(id_regla: int) -> bool:
    with db_cursor() as cur:
        cur.execute("DELETE FROM heuristico.regla WHERE id = %s", (id_regla,))
        return cur.rowcount > 0
