from app.core.db import db_cursor
import os
os.environ["DATABASE_URL"] = "postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres"

def check_oms_data():
    with db_cursor() as cur:
        # Check sex catalog
        print("--- CATALOGO SEXO ---")
        cur.execute("SELECT id, descripcion, codigo FROM usuarios.catalogo_sexo")
        for r in cur.fetchall(): print(r)

        # Check Indicator
        print("\n--- INDICADOR IMC ---")
        cur.execute("SELECT id, codigo, nombre FROM referencia.indicador_antropometrico WHERE codigo = 'IMC_EDAD'")
        print(cur.fetchone())

        # Check Curva (Sex mapping in OMS tables)
        print("\n--- CURVAS DISPONIBLES ---")
        cur.execute("""
            SELECT c.id, c.id_sexo, i.codigo 
            FROM referencia.oms_curva c
            JOIN referencia.indicador_antropometrico i ON i.id = c.id_indicador
            WHERE i.codigo = 'IMC_EDAD'
        """)
        for r in cur.fetchall(): print(r)

        # Check Point sample
        print("\n--- PUNTOS MUESTRA (Edad 84 meses = 7 años) ---")
        cur.execute("""
            SELECT p.edad_valor, p.l, p.m, p.s 
            FROM referencia.oms_curva_punto p
            JOIN referencia.oms_curva c ON c.id = p.id_curva
            WHERE c.id_indicador = (SELECT id FROM referencia.indicador_antropometrico WHERE codigo = 'IMC_EDAD')
              AND p.edad_valor BETWEEN 80 AND 90
            LIMIT 5
        """)
        for r in cur.fetchall(): print(r)

if __name__ == "__main__":
    check_oms_data()
