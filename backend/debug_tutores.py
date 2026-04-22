from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def debug_tutores():
    with db_cursor() as cur:
        print("--- LISTADO DE USUARIOS CON ROL TUTOR (O PARECIDOS) ---")
        cur.execute("""
            SELECT id, cedula, nombre_completo, id_rol, email 
            FROM usuarios.usuario 
            WHERE id_rol = 3 OR cedula IS NOT NULL 
            LIMIT 10
        """)
        for r in cur.fetchall():
            print(f"ID: {r[0]} | Cédula: '{r[1]}' | Nombre: {r[2]} | Rol: {r[3]} | Email: {r[4]}")

if __name__ == "__main__":
    debug_tutores()
