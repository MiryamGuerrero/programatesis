from app.core.db import db_cursor

def check_labeling_tables():
    with db_cursor() as cur:
        print("--- TABLAS RELACIONADAS CON ETIQUETAS ---")
        cur.execute("""
            select table_name 
            from information_schema.tables 
            where table_schema = 'nutricion' and table_name ilike '%etiqueta%'
        """)
        for row in cur.fetchall(): print(row)

        print("\n--- CATÁLOGO DE ETIQUETAS DISPONIBLES ---")
        cur.execute("select id, codigo, nombre_visible from nutricion.etiqueta_nutricional")
        for row in cur.fetchall(): print(row)

if __name__ == "__main__":
    check_labeling_tables()
