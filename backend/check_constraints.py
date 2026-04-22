from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def check_constraints():
    with db_cursor() as cur:
        print("--- CONSTRAINTS ON clinico.control_paciente ---")
        cur.execute("""
            SELECT conname, pg_get_constraintdef(c.oid)
            FROM pg_constraint c
            JOIN pg_namespace n ON n.oid = c.connamespace
            WHERE n.nspname = 'clinico' AND conrelid = 'clinico.control_paciente'::regclass
        """)
        for row in cur.fetchall(): print(row)

if __name__ == "__main__":
    check_constraints()
