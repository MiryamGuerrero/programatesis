from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def search_populated_tables():
    with db_cursor() as cur:
        cur.execute("""
            SELECT table_schema, table_name 
            FROM information_schema.tables 
            WHERE table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pgbouncer', 'realtime')
        """)
        tables = cur.fetchall()
        for schema, table in tables:
            try:
                cur.execute(f"SELECT COUNT(*) FROM {schema}.{table}")
                count = cur.fetchone()[0]
                if count > 50:
                    print(f"Table: {schema}.{table} | Count: {count}")
            except: pass

if __name__ == "__main__":
    search_populated_tables()
