from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def exhaustive_search():
    with db_cursor() as cur:
        # Search in all schemas for anything that might contain the OMS data
        cur.execute("""
            SELECT table_schema, table_name 
            FROM information_schema.tables 
            WHERE table_name ILIKE '%curva%' OR table_name ILIKE '%indicador%' 
               OR table_name ILIKE '%oms%' OR table_name ILIKE '%zscore%'
        """)
        tables = cur.fetchall()
        for schema, table in tables:
            cur.execute(f"SELECT COUNT(*) FROM {schema}.{table}")
            count = cur.fetchone()[0]
            print(f"Table: {schema}.{table} | Count: {count}")

if __name__ == "__main__":
    exhaustive_search()
