from app.core.db import db_cursor
from datetime import datetime, timedelta
import uuid

def seed_complete_test_patient():
    # 1. IDs de referencia
    ID_LUPUS = 2 # Supongamos ID 2 es AIJ o Lupus
    ID_TUTOR = str(uuid.uuid4())
    ID_PACIENTE = str(uuid.uuid4())
    HOY = datetime.now()
    
    # IDs de Lácteos para el bloqueo automático
    LACTEOS = [20, 21, 22, 23, 66, 79, 39]

    with db_cursor() as cur:
        try:
            cur.execute("BEGIN")
            
            # 2. Crear Tutor
            cur.execute("""
                INSERT INTO usuarios.usuario (id, nombre_completo, email, cedula, id_rol, activo)
                VALUES (%s, 'Carlos Pérez (Tutor)', 'tutor_mateo@reuma.app', '0609998881', 4, true)
            """, (ID_TUTOR,))

            # 3. Crear Paciente
            cur.execute("""
                INSERT INTO usuarios.paciente (id, nombre_completo, fecha_nacimiento, id_sexo, cedula, activo, diagnostico_base)
                VALUES (%s, 'Mateo Sebastián Pérez', '2015-05-20', 1, '0605554441', true, 'Artritis Idiopática Juvenil')
            """, (ID_PACIENTE,))

            # 4. Vincular Tutor
            cur.execute("""
                INSERT INTO usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal)
                VALUES (%s, %s, 1, true)
            """, (ID_TUTOR, ID_PACIENTE))

            # 5. Diagnóstico Maestro
            cur.execute("""
                INSERT INTO clinico.diagnostico_paciente (id_paciente, id_condicion, fecha_diagnostico, es_cronico, esta_activo)
                VALUES (%s, 1, now(), true, true)
            """, (ID_PACIENTE,))

            # 6. Alergias e Intolerancia (Bloqueo de Lácteos)
            for sub_id in LACTEOS:
                cur.execute("INSERT INTO clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, activa) VALUES (%s, %s, true)", (ID_PACIENTE, sub_id))
            
            # Alergia a ingrediente específico: Canela (Supongamos ID 120)
            cur.execute("INSERT INTO clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, activa) VALUES (%s, 310, true)", (ID_PACIENTE,))

            # 7. Historial de 6 Controles (Evolución)
            # Mes 1 (Brote), Mes 2 (Mejora), Mes 3 (Normal), Mes 4 (Recaída-Diarrea), Mes 5 (Mejora), Mes 6 (Hoy)
            evoluccion = [
                {"m": 5, "p": 25.0, "t": 128, "d": 9, "inf": 3, "f": 2, "pcr": 55.0, "b": True, "st": "Actividad Alta", "n": "Desnutrición"},
                {"m": 4, "p": 26.2, "t": 128.5, "d": 6, "inf": 2, "f": 4, "pcr": 25.0, "b": False, "st": "Actividad Moderada", "n": "Riesgo Desnutrición"},
                {"m": 3, "p": 27.5, "t": 129, "d": 2, "inf": 0, "f": 8, "pcr": 4.0, "b": False, "st": "Estable", "n": "Eutrófico"},
                {"m": 2, "p": 27.0, "t": 129.2, "d": 5, "inf": 2, "f": 5, "pcr": 15.0, "b": True, "st": "Actividad Moderada", "n": "Eutrófico"},
                {"m": 1, "p": 28.2, "t": 129.5, "d": 1, "inf": 0, "f": 9, "pcr": 2.0, "b": False, "st": "Estable", "n": "Eutrófico"},
                {"m": 0, "p": 29.5, "t": 130, "d": 0, "inf": 0, "f": 10, "pcr": 0.8, "b": False, "st": "Estable", "n": "Eutrófico"}
            ]

            for ev in evoluccion:
                fecha = HOY - timedelta(days=ev['m'] * 30)
                cur.execute("""
                    INSERT INTO clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado,
                        id_condicion_nutricional_resultado, estado_nutricional, puntos_dolor, 
                        escala_inflamacion, nivel_fatiga, valor_pcr, en_brote, estado_enfermedad, created_at
                    ) VALUES (%s, %s, %s, %s, 108, %s, 103, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
                """, (ID_PACIENTE, fecha, ev['p'], ev['t'], round(ev['p']/((ev['t']/100)**2),2), ev['n'], ev['d'], ev['inf'], ev['f'], ev['pcr'], ev['b'], ev['st'], fecha))
                
                cid = cur.fetchone()[0]
                
                # Inyectar síntoma temporal en la recaída (Mes 4 - ev['m']==2)
                if ev['m'] == 2:
                    cur.execute("INSERT INTO clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin) VALUES (%s, 16, %s, %s)", (cid, fecha, fecha + timedelta(days=5)))

            cur.execute("COMMIT")
            print(f"✅ PACIENTE DE PRUEBA CREADO EXITOSAMENTE")
            print(f"ID: {ID_PACIENTE}")
            print(f"Nombre: Mateo Sebastián Pérez")
            print(f"Busca este nombre en tu lista de pacientes.")
            
        except Exception as e:
            cur.execute("ROLLBACK")
            print(f"❌ Error sembrando Mateo: {e}")

if __name__ == "__main__":
    seed_complete_test_patient()
