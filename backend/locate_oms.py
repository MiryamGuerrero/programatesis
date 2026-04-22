from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def locate_oms():
    with db_cursor() as cur:
        cur.execute("SELECT table_schema, table_name FROM information_schema.tables WHERE table_name ILIKE '%oms%' OR table_name ILIKE '%zscore%'")
        for r in cur.fetchall(): print(r)

if __name__ == "__main__":
    locate_oms()
