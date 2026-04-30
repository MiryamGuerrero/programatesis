from app.core.db import db_cursor

def validate_schema():
    print("--- VALIDACIÓN DE ATRIBUTOS CLÍNICOS EN CONTROL_PACIENTE ---")
    with db_cursor() as cur:
        cur.execute("SELECT column_name FROM information_schema.columns WHERE table_schema = 'clinico' AND table_name = 'control_paciente'")
        cols = [r[0] for r in cur.fetchall()]
        required = ['puntos_dolor', 'escala_inflamacion', 'minutos_rigidez', 'valor_pcr', 'valor_vsg', 'en_brote', 'articulaciones_inflamadas', 'articulaciones_dolorosas', 'edad_meses']
        for col in required:
            status = "✅ EXISTE" if col in cols else "❌ FALTANTE"
            print(f"Campo {col}: {status}")

    print("\n--- VALIDACIÓN DE UNIFICACIÓN EN CONTROL_CONDICION_ACTIVA ---")
    with db_cursor() as cur:
        cur.execute("SELECT column_name FROM information_schema.columns WHERE table_schema = 'clinico' AND table_name = 'control_condicion_activa'")
        cols = [r[0] for r in cur.fetchall()]
        print(f"Columnas actuales: {cols}")
        if 'id_control' in cols and 'id_condicion' in cols:
            print("✅ Estructura de unificación histórica correcta.")

if __name__ == "__main__":
    validate_schema()
