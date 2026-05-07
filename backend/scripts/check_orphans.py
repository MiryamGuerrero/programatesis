import psycopg2
import os
from dotenv import load_dotenv

load_dotenv('backend/.env')

def check_orphans():
    db_url = os.getenv('DATABASE_URL')
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()

    print("--- CHEQUEO DE REGLAS SIN CONDICIÓN ---")
    
    # Reglas nutricionales sin vínculo
    sql = """
        SELECT count(*)
        FROM heuristico.regla r
        LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        WHERE r.origen_regla = 'NUTRICIONAL' AND cr.id_condicion IS NULL
    """
    cur.execute(sql)
    print(f"Reglas nutricionales huérfanas: {cur.fetchone()[0]}")

    cur.close()
    conn.close()

if __name__ == "__main__":
    check_orphans()
