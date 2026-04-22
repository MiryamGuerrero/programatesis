
from app.core.db import db_cursor

def verify_latest_registrations():
    print("\n" + "="*60)
    print("VERIFICACIÓN DE ÚLTIMOS REGISTROS (ALERGIAS Y NUTRICIÓN)")
    print("="*60)
    
    with db_cursor() as cur:
        # 1. Ver últimos 3 pacientes
        cur.execute("""
            SELECT p.id, p.nombre_completo, p.created_at, s.descripcion
            FROM usuarios.paciente p
            JOIN usuarios.catalogo_sexo s ON s.id = p.id_sexo
            ORDER BY p.created_at DESC LIMIT 3
        """)
        pacientes = cur.fetchall()
        
        if not pacientes:
            print("No se encontraron pacientes registrados.")
            return

        for p_id, nombre, fecha, sexo in pacientes:
            print(f"\n> PACIENTE: {nombre}")
            print(f"  ID: {p_id}")
            print(f"  Registrado: {fecha}")
            
            # Ver Alergias
            cur.execute("SELECT count(*) FROM clinico.alergia_paciente_ingrediente WHERE id_paciente = %s", (p_id,))
            cant_ing = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM clinico.alergia_paciente_subgrupo WHERE id_paciente = %s", (p_id,))
            cant_sub = cur.fetchone()[0]
            print(f"  [ALERGIAS] Ingredientes: {cant_ing} | Subgrupos: {cant_sub}")
            
            # Ver Diagnósticos Nutricionales (Condición activa)
            cur.execute("""
                SELECT c.nombre 
                FROM clinico.diagnostico_paciente dp
                JOIN heuristico.condicion c ON c.id = dp.id_condicion
                WHERE dp.id_paciente = %s AND c.id_tipo_condicion = 3
            """, (p_id,))
            diags = [r[0] for r in cur.fetchall()]
            print(f"  [DIAGNÓSTICO NUTRI] {', '.join(diags) if diags else 'Ninguno'}")
            
            # Ver en Control Clínico
            cur.execute("""
                SELECT diagnostico_oms_texto, imc_calculado 
                FROM clinico.control_paciente 
                WHERE id_paciente = %s ORDER BY created_at DESC LIMIT 1
            """, (p_id,))
            ctrl = cur.fetchone()
            if ctrl:
                print(f"  [CONTROL CLÍNICO] IMC: {ctrl[1]} | OMS: {ctrl[0]}")
    
    print("\n" + "="*60 + "\n")

if __name__ == "__main__":
    verify_latest_registrations()
