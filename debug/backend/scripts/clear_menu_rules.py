import psycopg
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def clear_menu_rules():
    if not DATABASE_URL:
        print("DATABASE_URL no encontrada en .env")
        return

    try:
        with psycopg.connect(DATABASE_URL) as conn:
            with conn.cursor() as cur:
                print("Eliminando todas las reglas de menú...")
                # La tabla nutricion.regla_menu_combinacion_condicion tiene ON DELETE CASCADE 
                # de nutricion.regla_menu_combinacion, así que basta con borrar la principal.
                cur.execute("DELETE FROM nutricion.regla_menu_combinacion;")
                print(f"Reglas eliminadas: {cur.rowcount}")
                conn.commit()
    except Exception as e:
        print(f"Error al eliminar reglas: {e}")

if __name__ == "__main__":
    clear_menu_rules()
