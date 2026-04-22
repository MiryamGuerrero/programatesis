from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def find_table():
    with db_cursor() as cur:
        cur.execute("SELECT table_schema, table_name FROM information_schema.tables WHERE table_name = 'repositorio_receta_segura_version'")
        print(cur.fetchone())

if __name__ == "__main__":
    find_table()
