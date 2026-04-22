from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def find_references():
    with db_cursor() as cur:
        print("--- REVISANDO DEPENDENCIAS DE control_paciente ---")
        cur.execute("""
            SELECT
                tc.table_schema, 
                tc.table_name, 
                kcu.column_name
            FROM 
                information_schema.table_constraints AS tc 
                JOIN information_schema.key_column_usage AS kcu
                  ON tc.constraint_name = kcu.constraint_name
                  AND tc.table_schema = kcu.table_schema
                JOIN information_schema.constraint_column_usage AS ccu
                  ON ccu.constraint_name = tc.constraint_name
                  AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY' 
              AND ccu.table_name = 'control_paciente'
        """)
        for row in cur.fetchall(): print(f"Referenciado por: {row[0]}.{row[1]} (col: {row[2]})")

        print("\n--- REVISANDO DEPENDENCIAS DE paciente ---")
        cur.execute("""
            SELECT
                tc.table_schema, 
                tc.table_name, 
                kcu.column_name
            FROM 
                information_schema.table_constraints AS tc 
                JOIN information_schema.key_column_usage AS kcu
                  ON tc.constraint_name = kcu.constraint_name
                  AND tc.table_schema = kcu.table_schema
                JOIN information_schema.constraint_column_usage AS ccu
                  ON ccu.constraint_name = tc.constraint_name
                  AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY' 
              AND ccu.table_name = 'paciente'
        """)
        for row in cur.fetchall(): print(f"Referenciado por: {row[0]}.{row[1]} (col: {row[2]})")

if __name__ == "__main__":
    find_references()
