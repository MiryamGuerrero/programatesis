from app.core.db import db_cursor

def find_nutrients():
    with db_cursor() as cur:
        print("--- TABLAS DE NUTRIENTES ---")
        cur.execute("select table_name from information_schema.tables where table_schema = 'nutricion' and table_name ilike '%nutriente%'")
        for row in cur.fetchall(): print(row)

if __name__ == "__main__":
    find_nutrients()
