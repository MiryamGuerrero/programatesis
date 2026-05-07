import psycopg2
import os
from dotenv import load_dotenv

load_dotenv('backend/.env')

def check_links():
    db_url = os.getenv('DATABASE_URL')
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()

    print("--- VERIFICACIÓN DE VÍNCULOS ---")
    
    # Reglas nutricionales y sus condiciones
    sql = """
        SELECT r.id, r.mensaje_error, c.nombre, c.id_tipo_condicion
        FROM heuristico.regla r
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        JOIN heuristico.condicion c ON c.id = cr.id_condicion
        WHERE r.origen_regla = 'NUTRICIONAL'
        LIMIT 10
    """
    cur.execute(sql)
    links = cur.fetchall()
    for l in links:
        print(f"Regla {l[0]}: {l[1]} | Condición: {l[2]} (Tipo {l[3]})")

    cur.close()
    conn.close()

if __name__ == "__main__":
    check_links()
