from app.core.db import db_cursor

def final_schema_refactor():
    with db_cursor() as cur:
        try:
            print("Refactorizando Vista de Gestión y limpiando tabla paciente...")
            
            # 1. Recrear la vista para que busque datos de las tablas correctas
            cur.execute("""
                CREATE OR REPLACE VIEW usuarios.vista_gestion_pacientes AS
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

            # 2. Borrar columnas redundantes en usuarios.paciente
            cur.execute("ALTER TABLE usuarios.paciente DROP COLUMN IF EXISTS fecha_ultimo_control;")
            cur.execute("ALTER TABLE usuarios.paciente DROP COLUMN IF EXISTS diagnostico_base;")
            
            print("✅ Tabla usuarios.paciente limpia. Vista SQL actualizada.")
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    final_schema_refactor()
