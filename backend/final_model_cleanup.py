from app.core.db import db_cursor

def deep_cleanup():
    with db_cursor() as cur:
        try:
            print("Iniciando refactorización de campos redundantes...")
            
            # 1. Limpiar control_paciente: Eliminar redundancia OMS
            # Dejamos solo id_condicion_nutricional_resultado
            cur.execute("""
                ALTER TABLE clinico.control_paciente 
                DROP COLUMN IF EXISTS diagnostico_oms_id;
            """)

            # 2. Asegurar que la tabla de condiciones activas tenga la estructura para el historial
            # id_control vincula la condición al momento exacto del tiempo
            cur.execute("""
                DO $$ 
                BEGIN 
                    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='clinico' AND table_name='control_condicion_activa' AND column_name='fecha_registro') THEN
                        ALTER TABLE clinico.control_condicion_activa ADD COLUMN fecha_registro TIMESTAMP DEFAULT now();
                    END IF;
                END $$;
            """)

            print("✅ Limpieza de atributos redundantes completada.")
        except Exception as e:
            print(f"❌ Error en limpieza: {e}")

if __name__ == "__main__":
    deep_cleanup()
