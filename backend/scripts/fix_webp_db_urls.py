import psycopg
import os
from dotenv import dotenv_values

def fix_db_urls():
    env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
    env = dotenv_values(env_path)
    db_url = env.get("DATABASE_URL")
    
    if not db_url:
        print("Error: DATABASE_URL no encontrado.")
        return

    try:
        # Usar la cadena de conexión del .env
        with psycopg.connect(db_url) as conn:
            with conn.cursor() as cur:
                # 1. Actualizar nutricion.receta
                print("Actualizando nutricion.receta...")
                cur.execute("""
                    UPDATE nutricion.receta 
                    SET imagen_url = REPLACE(imagen_url, '.jpg', '.webp')
                    WHERE imagen_url LIKE '%.jpg';
                """)
                rows_receta_jpg = cur.rowcount
                
                cur.execute("""
                    UPDATE nutricion.receta 
                    SET imagen_url = REPLACE(imagen_url, '.png', '.webp')
                    WHERE imagen_url LIKE '%.png';
                """)
                rows_receta_png = cur.rowcount
                
                # 2. Actualizar receta_imagen (esquema public)
                print("Actualizando receta_imagen...")
                cur.execute("""
                    UPDATE public.receta_imagen 
                    SET imagen_url = REPLACE(imagen_url, '.jpg', '.webp')
                    WHERE imagen_url LIKE '%.jpg';
                """)
                rows_ri_jpg = cur.rowcount

                cur.execute("""
                    UPDATE public.receta_imagen 
                    SET imagen_url = REPLACE(imagen_url, '.png', '.webp')
                    WHERE imagen_url LIKE '%.png';
                """)
                rows_ri_png = cur.rowcount
                
                conn.commit()
                print(f"Éxito:")
                print(f" - nutricion.receta: {rows_receta_jpg} jpg, {rows_receta_png} png actualizados.")
                print(f" - receta_imagen: {rows_ri_jpg} jpg, {rows_ri_png} png actualizados.")

    except Exception as e:
        print(f"Error conectando a la base de datos: {e}")

if __name__ == "__main__":
    fix_db_urls()
