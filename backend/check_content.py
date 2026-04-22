from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def check_content():
    with db_cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM referencia.oms_curva")
        print(f"Curvas: {cur.fetchone()[0]}")
        cur.execute("SELECT COUNT(*) FROM referencia.oms_curva_punto")
        print(f"Puntos: {cur.fetchone()[0]}")
        
        if cur.fetchone():
            cur.execute("SELECT * FROM referencia.oms_curva LIMIT 5")
            for r in cur.fetchall(): print(r)

if __name__ == "__main__":
    check_content()
