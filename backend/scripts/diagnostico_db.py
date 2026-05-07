import psycopg2
import os
from dotenv import load_dotenv

load_dotenv('backend/.env')

def diagnostic():
    db_url = os.getenv('DATABASE_URL')
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()

    print("--- DIAGNÓSTICO DE BASE DE DATOS ---")
    
    # 1. Verificar tipos de condiciones
    cur.execute("SELECT id, nombre FROM heuristico.catalogo_tipo_condicion")
    tipos = cur.fetchall()
    print(f"Tipos de condición en catálogo: {tipos}")

    # 2. Verificar condiciones de tipo 3
    cur.execute("SELECT count(*) FROM heuristico.condicion WHERE id_tipo_condicion = 3")
    count_tipo_3 = cur.fetchone()[0]
    print(f"Total condiciones tipo 3: {count_tipo_3}")

    cur.execute("SELECT count(*) FROM heuristico.condicion WHERE id_tipo_condicion = 3 AND activa = true")
    count_tipo_3_active = cur.fetchone()[0]
    print(f"Condiciones tipo 3 activas: {count_tipo_3_active}")

    # 3. Verificar reglas por origen
    cur.execute("SELECT origen_regla, count(*) FROM heuristico.regla GROUP BY origen_regla")
    reglas_por_origen = cur.fetchall()
    print(f"Reglas en heuristico.regla por origen: {reglas_por_origen}")

    # 4. Verificar tablas de nutrición
    cur.execute("SELECT count(*) FROM nutricion.ingrediente")
    print(f"Ingredientes: {cur.fetchone()[0]}")
    cur.execute("SELECT count(*) FROM nutricion.grupo_alimentario")
    print(f"Grupos: {cur.fetchone()[0]}")

    cur.close()
    conn.close()

if __name__ == "__main__":
    diagnostic()
