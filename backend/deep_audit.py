from app.core.db import db_cursor
import os

os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def deep_audit():
    with db_cursor() as cur:
        # 1. Ver qué hay en usuarios.usuario (Tutor)
        print("\n--- COLUMNAS DE usuarios.usuario (Tutor) ---")
        cur.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'usuarios' AND table_name = 'usuario'")
        for col in cur.fetchall(): print(f"  {col[0]}: {col[1]}")

        # 2. Ver catálogo de parentescos
        print("\n--- CATÁLOGO usuarios.parentesco ---")
        cur.execute("SELECT id, nombre FROM usuarios.parentesco")
        for row in cur.fetchall(): print(f"  {row}")

        # 3. Ver catálogo de provincias
        print("\n--- CATÁLOGO usuarios.provincia ---")
        cur.execute("SELECT id, nombre FROM usuarios.provincia")
        for row in cur.fetchall(): print(f"  {row}")

        # 4. Buscar tablas de contacto adicionales
        print("\n--- BUSCANDO TABLAS DE DIRECCIÓN O CONTACTO ---")
        cur.execute("SELECT table_schema, table_name FROM information_schema.tables WHERE table_name ILIKE '%contacto%' OR table_name ILIKE '%direccion%'")
        for row in cur.fetchall(): print(f"  Encontrada: {row[0]}.{row[1]}")

if __name__ == "__main__":
    deep_audit()
