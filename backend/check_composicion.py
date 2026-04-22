from app.core.db import db_cursor

def check_composicion_schema():
    with db_cursor() as cur:
        print("--- COLUMNAS DE NUTRICION.INGREDIENTE_COMPOSICION ---")
        try:
            cur.execute("""
                select column_name, data_type 
                from information_schema.columns 
                where table_schema = 'nutricion' and table_name = 'ingrediente_composicion'
                order by ordinal_position
            """)
            for row in cur.fetchall():
                print(row)
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    check_composicion_schema()
