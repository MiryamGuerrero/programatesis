from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def check():
    with db_cursor() as cur:
        cur.execute("SELECT column_name FROM information_schema.columns WHERE table_schema = 'clinico' AND table_name = 'control_paciente'")
        for r in cur.fetchall(): print(r[0])

if __name__ == "__main__":
    check()
