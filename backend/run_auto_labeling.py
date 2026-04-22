from app.core.db import db_cursor

def auto_etiquetar_recetas():
    """
    Analiza todas las recetas y les asigna etiquetas automáticamente 
    basándose en nutrientes totales e ingredientes.
    """
    print("\n>>> INICIANDO PROCESO DE AUTO-ETIQUETADO DE RECETAS")
    
    with db_cursor() as cur:
        # 1. Obtener todas las recetas
        cur.execute("select id, nombre from nutricion.receta where activa = true")
        recetas = cur.fetchall()

        for id_receta, nombre in recetas:
            print(f"   Analizando: {nombre}...")
            etiquetas_a_poner = set()

            # --- A. LÓGICA POR NUTRIENTES TOTALES ---
            cur.execute("""
                select 
                    sum(ri.peso_en_gramos * i.sodio_mg / 100) as total_sodio,
                    sum(ri.peso_en_gramos * i.omega3_g / 100) as total_omega3,
                    sum(ri.peso_en_gramos * i.calcio_mg / 100) as total_calcio,
                    sum(ri.peso_en_gramos * i.fibra_vegetal_g / 100) as total_fibra
                from nutricion.receta_ingrediente ri
                join nutricion.ingrediente i on i.id = ri.id_ingrediente
                where ri.id_receta = %s
            """, (id_receta,))
            
            nutris = cur.fetchone()
            if nutris:
                sodio = float(nutris[0] or 0)
                omega3 = float(nutris[1] or 0)
                calcio = float(nutris[2] or 0)
                fibra = float(nutris[3] or 0)
                
                if sodio < 140: etiquetas_a_poner.add(91) # BAJO_EN_SODIO
                if sodio > 400: etiquetas_a_poner.add(144) # ALTO_SODIO
                if omega3 > 0.5: etiquetas_a_poner.add(143) # FUENTE_OMEGA3
                if calcio > 200: etiquetas_a_poner.add(134) # CALCIO_VITD
                if fibra > 5: etiquetas_a_poner.add(145) # ALTA_FIBRA

            # --- B. LÓGICA POR HERENCIA ---
            cur.execute("""
                select distinct id_etiqueta 
                from nutricion.ingrediente_etiqueta 
                where id_ingrediente in (select id_ingrediente from nutricion.receta_ingrediente where id_receta = %s)
            """, (id_receta,))
            tags_ingredientes = [row[0] for row in cur.fetchall()]
            
            if 118 in tags_ingredientes: etiquetas_a_poner.add(118) # PROINFLAMATORIO
            if 123 in tags_ingredientes: etiquetas_a_poner.add(123) # PATRON_ANTIINFLAMATORIO

            # --- 3. GUARDAR EN LA BASE DE DATOS ---
            cur.execute("delete from nutricion.receta_etiqueta where id_receta = %s", (id_receta,))
            for id_etiqueta in etiquetas_a_poner:
                cur.execute(
                    "insert into nutricion.receta_etiqueta (id_receta, id_etiqueta) values (%s, %s) on conflict do nothing",
                    (id_receta, id_etiqueta)
                )

    print(">>> AUTO-ETIQUETADO COMPLETADO EXITOSAMENTE")

if __name__ == "__main__":
    auto_etiquetar_recetas()
