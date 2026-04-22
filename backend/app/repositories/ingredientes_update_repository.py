from app.core.db import db_cursor

def update_ingredient_full(id_ingrediente: int, data: dict):
    """Actualiza tanto el ingrediente como su composición nutricional."""
    with db_cursor() as cur:
        # 1. Actualizar tabla base
        cur.execute("""
            update nutricion.ingrediente 
            set nombre = %s, id_grupo_alimentario = %s, activo = %s
            where id = %s
        """, (data['nombre'], data['id_grupo_alimentario'], data['activo'], id_ingrediente))
        
        # 2. Actualizar composición (Soporta Upsert)
        cur.execute("""
            insert into nutricion.ingrediente_composicion (
                id_ingrediente, energia_kcal, proteinas_g, grasa_total_g, 
                hidratos_carbono_g, fibra_vegetal_g, sodio_mg, calcio_mg, hierro_mg
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            on conflict (id_ingrediente) do update set
                energia_kcal = excluded.energia_kcal,
                proteinas_g = excluded.proteinas_g,
                grasa_total_g = excluded.grasa_total_g,
                hidratos_carbono_g = excluded.hidratos_carbono_g,
                fibra_vegetal_g = excluded.fibra_vegetal_g,
                sodio_mg = excluded.sodio_mg,
                calcio_mg = excluded.calcio_mg,
                hierro_mg = excluded.hierro_mg
        """, (
            id_ingrediente, data['energia_kcal'], data['proteinas_g'], 
            data['grasa_total_g'], data['carbohidratos_g'], data['fibra_g'],
            data['sodio_mg'], data['calcio_mg'], data['hierro_mg']
        ))
        
        # 3. Gestionar Etiquetas (Simple: borrar y poner las nuevas)
        cur.execute("delete from nutricion.ingrediente_etiqueta where id_ingrediente = %s", (id_ingrediente,))
        for tag_id in data.get('id_etiquetas', []):
            cur.execute("insert into nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta) values (%s, %s)", (id_ingrediente, tag_id))
            
    return True
