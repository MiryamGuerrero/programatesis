from app.core.db import db_cursor

def final_schema_refactor_v2():
    with db_cursor() as cur:
        try:
            print("Limpieza profunda de esquema...")
            
            # 1. Eliminar la vista para evitar conflictos de tipos
            cur.execute("DROP VIEW IF EXISTS usuarios.vista_gestion_pacientes;")

            # 2. Borrar columnas redundantes en usuarios.paciente
            cur.execute("ALTER TABLE usuarios.paciente DROP COLUMN IF EXISTS fecha_ultimo_control;")
            cur.execute("ALTER TABLE usuarios.paciente DROP COLUMN IF EXISTS diagnostico_base;")

            # 3. Crear la nueva vista con la lógica correcta (unión de tablas)
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
            
            print("✅ Tabla usuarios.paciente limpia. Vista SQL renovada.")
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    final_schema_refactor_v2()
