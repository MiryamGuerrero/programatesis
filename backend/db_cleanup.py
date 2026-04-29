from app.core.db import db_cursor

def cleanup_database():
    with db_cursor() as cur:
        try:
            print("Iniciando limpieza de tablas redundantes...")
            # 1. Asegurar que control_condicion_activa tenga los campos necesarios para síntomas temporales
            cur.execute("""
                ALTER TABLE clinico.control_condicion_activa 
                ADD COLUMN IF NOT EXISTS fecha_inicio DATE,
                ADD COLUMN IF NOT EXISTS fecha_fin DATE,
                ADD COLUMN IF NOT EXISTS esta_activa BOOLEAN DEFAULT true,
                ADD COLUMN IF NOT EXISTS observacion TEXT;
            """)
            
            # 2. Borrar tablas basura
            cur.execute("DROP TABLE IF EXISTS clinico.restriccion_temporal_paciente CASCADE;")
            cur.execute("DROP TABLE IF EXISTS clinico.paciente_condicion_vigente CASCADE;")
            
            print("✅ Tablas redundantes eliminadas y control_condicion_activa optimizada.")
        except Exception as e:
            print(f"❌ Error en limpieza: {e}")

if __name__ == "__main__":
    cleanup_database()
