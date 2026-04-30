from app.core.db import db_cursor

def final_schema_refactor_v3():
    with db_cursor() as cur:
        try:
            print("Limpieza profunda de esquema (Modo Cascade)...")
            
            # 1. Eliminar vistas dependientes
            cur.execute("DROP VIEW IF EXISTS usuarios.vista_gestion_pacientes CASCADE;")
            cur.execute("DROP VIEW IF EXISTS vw_paciente CASCADE;")

            # 2. Borrar columnas redundantes
            cur.execute("ALTER TABLE usuarios.paciente DROP COLUMN IF EXISTS fecha_ultimo_control CASCADE;")
            cur.execute("ALTER TABLE usuarios.paciente DROP COLUMN IF EXISTS diagnostico_base CASCADE;")

            # 3. Crear la vista definitiva para el médico
            cur.execute("""
                CREATE VIEW usuarios.vista_gestion_pacientes AS
                SELECT 
                    p.id,
                    p.nombre_completo,
                    p.cedula,
                    (SELECT c.nombre 
                     FROM clinico.diagnostico_paciente dp 
                     JOIN heuristico.condicion c ON c.id = dp.id_condicion 
                     WHERE dp.id_paciente = p.id AND dp.esta_activo = true 
                     LIMIT 1) AS enfermedad_principal,
                    p.fecha_nacimiento,
                    extract(year from age(now(), p.fecha_nacimiento))::int AS edad_anios,
                    ctrl.estado_enfermedad AS severidad,
                    ctrl.estado_nutricional AS condicion_nutricional,
                    ctrl.fecha_control AS ultimo_control
                FROM usuarios.paciente p
                LEFT JOIN LATERAL (
                    SELECT estado_enfermedad, estado_nutricional, fecha_control
                    FROM clinico.control_paciente
                    WHERE id_paciente = p.id
                    ORDER BY fecha_control DESC
                    LIMIT 1
                ) ctrl ON true
                WHERE p.activo = true;
            """)
            
            print("✅ Base de datos saneada con éxito.")
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    final_schema_refactor_v3()
