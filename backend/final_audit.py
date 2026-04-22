from app.core.db import db_cursor
import os

os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def final_clinical_audit():
    with db_cursor() as cur:
        # Tablas a auditar
        tables = [
            ('usuarios', 'paciente'),
            ('usuarios', 'tutor_paciente'),
            ('clinico', 'control_paciente'),
            ('clinico', 'control_condicion_activa'),
            ('clinico', 'restriccion_temporal_paciente'),
            ('clinico', 'alergia_paciente_ingrediente'),
            ('clinico', 'alergia_paciente_subgrupo'),
            ('clinico', 'diagnostico_paciente')
        ]
        
        print("--- AUDITORÍA DE COLUMNAS Y TIPOS ---")
        for schema, table in tables:
            print(f"\n[{schema}.{table}]")
            cur.execute(f"SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema = '{schema}' AND table_name = '{table}'")
            for col in cur.fetchall():
                print(f"  - {col[0]} ({col[1]}) | Nullable: {col[2]}")

        print("\n--- RESTRICCIONES DE INTEGRIDAD (FKeys) ---")
        cur.execute("""
            SELECT tc.table_name, kcu.column_name, ccu.table_name AS foreign_table_name
            FROM information_schema.table_constraints AS tc 
            JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
            WHERE constraint_type = 'FOREIGN KEY' AND tc.table_schema IN ('clinico', 'usuarios')
        """)
        for row in cur.fetchall():
            print(f"  {row[0]}.{row[1]} -> {row[2]}")

if __name__ == "__main__":
    final_clinical_audit()
