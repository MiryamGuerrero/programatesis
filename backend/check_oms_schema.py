from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def check_oms_columns():
    with db_cursor() as cur:
        print("--- COLUMNS OF referencia.oms_curva_punto ---")
        cur.execute("SELECT column_name FROM information_schema.columns WHERE table_schema = 'referencia' AND table_name = 'oms_curva_punto'")
        for r in cur.fetchall(): print(r[0])

if __name__ == "__main__":
    check_oms_columns()
