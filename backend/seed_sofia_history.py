from app.core.db import db_cursor
from datetime import datetime, timedelta

def seed_sofia_long_history(id_paciente):
    hoy = datetime.now()
    # Historial de 6 meses atrás (el mes 7 es hoy y queda vacío para el médico)
    controles = [
        {"m": 6, "p": 20.0, "t": 118, "d": 9, "inf": 3, "f": 2, "pcr": 65.0, "vsg": 50, "st": "Actividad Alta", "b": True, "n": "Desnutrición", "oms": 101, "obs": "Brote inicial severo. Se inicia terapia biológica."},
        {"m": 5, "p": 20.5, "t": 118.5, "d": 7, "inf": 2, "f": 4, "pcr": 40.0, "vsg": 35, "st": "Actividad Moderada", "b": False, "n": "Riesgo Desnutrición", "oms": 102, "obs": "Mejora progresiva. Tolera bien medicación."},
        {"m": 4, "p": 21.2, "t": 119, "d": 4, "inf": 1, "f": 6, "pcr": 15.0, "vsg": 20, "st": "Actividad Leve", "b": False, "n": "Eutrófico", "oms": 103, "obs": "Excelente respuesta clínica."},
        {"m": 3, "p": 20.8, "t": 119.2, "d": 6, "inf": 2, "f": 5, "pcr": 25.0, "vsg": 28, "st": "Actividad Moderada", "b": True, "n": "Eutrófico", "oms": 103, "obs": "Recaída leve asociada a proceso viral estacional.", "sintoma": 15}, # Gripe
        {"m": 2, "p": 21.8, "t": 119.5, "d": 2, "inf": 0, "f": 9, "pcr": 5.0, "vsg": 12, "st": "Estable", "b": False, "n": "Eutrófico", "oms": 103, "obs": "Recupera estado basal tras infección."},
        {"m": 1, "p": 22.5, "t": 119.8, "d": 1, "inf": 0, "f": 10, "pcr": 1.5, "vsg": 8, "st": "Estable", "b": False, "n": "Eutrófico", "oms": 103, "obs": "Remisión clínica sostenida."}
    ]

    with db_cursor() as cur:
        try:
            cur.execute("BEGIN")
            # Limpiar historial previo para evitar duplicados en la prueba
            cur.execute("DELETE FROM clinico.control_condicion_activa WHERE id_control IN (SELECT id FROM clinico.control_paciente WHERE id_paciente = %s)", (id_paciente,))
            cur.execute("DELETE FROM clinico.control_paciente WHERE id_paciente = %s", (id_paciente,))
            
            for c in controles:
                fecha = hoy - timedelta(days=c['m'] * 30)
                # Calcular edad exacta en meses para ese momento (Sofía nació en Oct 2018)
                nacimiento = datetime(2018, 10, 10)
                edad_meses = (fecha.year - nacimiento.year) * 12 + fecha.month - nacimiento.month
                
                imc = round(c['p'] / ((c['t']/100)**2), 2)
                
                cur.execute("""
                    INSERT INTO clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado,
                        id_condicion_nutricional_resultado, estado_nutricional, puntos_dolor, 
                        escala_inflamacion, nivel_fatiga, valor_pcr, valor_vsg, en_brote, 
                        estado_enfermedad, nota_evolucion, created_at
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
                """, (id_paciente, fecha, c['p'], c['t'], edad_meses, imc, c['oms'], c['n'], c['d'], c['inf'], c['f'], c['pcr'], c['vsg'], c['b'], c['st'], c['obs'], fecha))
                
                cid = cur.fetchone()[0]
                
                # Registrar Condición OMS
                cur.execute("INSERT INTO clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) VALUES (%s, %s, %s)", (cid, c['oms'], fecha))
                
                # Registrar Síntoma si existe
                if "sintoma" in c:
                    cur.execute("INSERT INTO clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin) VALUES (%s, %s, %s, %s)", (cid, c['sintoma'], fecha, fecha + timedelta(days=7)))

            cur.execute("COMMIT")
            print(f"✅ Historial de 7 meses cargado para Sofía Valentina.")
        except Exception as e:
            cur.execute("ROLLBACK")
            print(f"❌ Error inyectando historial: {e}")

if __name__ == "__main__":
    # ID de Sofía Valentina (obtenido del rastro anterior)
    seed_sofia_long_history("c19d7da5-bcf0-4116-8a0c-4150693e3404")
