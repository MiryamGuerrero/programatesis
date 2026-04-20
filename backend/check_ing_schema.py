from app.core.db import db_cursor

def check_ingrediente_schema():
    with db_cursor() as cur:
        print("--- COLUMNAS DE NUTRICION.INGREDIENTE ---")
        cur.execute("""
            select column_name, data_type 
            from information_schema.columns 
            where table_schema = 'nutricion' and table_name = 'ingrediente'
            order by column_name
        """)
        for row in cur.fetchall():
            print(row)

if __name__ == "__main__":
    check_ingrediente_schema()
