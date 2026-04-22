from app.core.db import db_cursor

def list_ingredients_paged(query: str = "", category_id: int = None, active: bool = None, limit: int = 10, offset: int = 0):
    """Lista ingredientes con filtros y paginación."""
    params = []
    where_clauses = ["1=1"]
    if query:
        where_clauses.append("i.nombre ilike %s")
        params.append(f"%{query}%")
    if category_id:
        where_clauses.append("i.id_grupo_alimentario = %s")
        params.append(category_id)
    if active is not None:
        where_clauses.append("i.activo = %s")
        params.append(active)

    where_str = " AND ".join(where_clauses)
    sql = f"""
        select 
            i.id, i.nombre, g.nombre as categoria, 
            coalesce(ic.energia_kcal, 0) as energia,
            coalesce(ic.proteinas_g, 0) as proteina,
            coalesce(ic.grasa_total_g, 0) as grasa,
            coalesce(ic.hidratos_carbono_g, 0) as carbohidratos,
            i.activo,
            array(
                select et.nombre_visible 
                from nutricion.ingrediente_etiqueta ie
                join nutricion.etiqueta_nutricional et on et.id = ie.id_etiqueta
                where ie.id_ingrediente = i.id
            ) as etiquetas
        from nutricion.ingrediente i
        left join nutricion.grupo_alimentario g on g.id = i.id_grupo_alimentario
        left join nutricion.ingrediente_composicion ic on ic.id_ingrediente = i.id
        where {where_str}
        order by i.nombre asc
        limit %s offset %s
    """
    params.extend([limit, offset])
    sql_count = f"select count(*) from nutricion.ingrediente i where {where_str}"
    
    with db_cursor() as cur:
        cur.execute(sql_count, params[:-2])
        total = cur.fetchone()[0]
        cur.execute(sql, params)
        rows = cur.fetchall()
        results = []
        for r in rows:
            results.append({
                "id": r[0], "nombre": r[1], "categoria": r[2],
                "energia_kcal": float(r[3] or 0), "proteinas_g": float(r[4] or 0),
                "grasas_g": float(r[5] or 0), "carbohidratos_g": float(r[6] or 0),
                "activo": r[7], "etiquetas": r[8]
            })
    return {"total": total, "items": results}

def get_ingredient_detail(id_ingrediente: int):
    sql = """
        select 
            i.id, i.nombre, i.id_grupo_alimentario, g.nombre as categoria_nombre,
            ic.energia_kcal, ic.proteinas_g, ic.grasa_total_g, ic.hidratos_carbono_g,
            ic.fibra_vegetal_g, ic.sodio_mg, ic.calcio_mg, ic.hierro_mg,
            i.activo,
            array(
                select et.nombre_visible 
                from nutricion.ingrediente_etiqueta ie
                join nutricion.etiqueta_nutricional et on et.id = ie.id_etiqueta
                where ie.id_ingrediente = i.id
            ) as etiquetas
        from nutricion.ingrediente i
        left join nutricion.grupo_alimentario g on g.id = i.id_grupo_alimentario
        left join nutricion.ingrediente_composicion ic on ic.id_ingrediente = i.id
        where i.id = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_ingrediente,))
        row = cur.fetchone()
        if not row: return None
        return {
            "id": row[0], "nombre": row[1], "id_grupo_alimentario": row[2], "categoria": row[3],
            "energia_kcal": float(row[4] or 0), "proteinas_g": float(row[5] or 0),
            "grasas_g": float(row[6] or 0), "carbohidratos_g": float(row[7] or 0),
            "fibra_g": float(row[8] or 0), "sodio_mg": float(row[9] or 0),
            "calcio_mg": float(row[10] or 0), "hierro_mg": float(row[11] or 0),
            "activo": row[12], "etiquetas": row[13]
        }
