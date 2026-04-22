from datetime import date, timedelta
from app.core.db import db_cursor

def save_manual_plan(id_paciente: str, plan_data: dict, replicar_mes: bool = True):
    """
    Guarda un plan nutricional manual. 
    Si replicar_mes es True, repite el patrón semanal por 4 semanas.
    """
    with db_cursor() as cur:
        # 1. Desactivar planes anteriores
        cur.execute(
            "update interaccion.plan_nutricional set vigente = false where id_paciente = %s",
            (id_paciente,)
        )
        
        # 2. Obtener IDs de catálogos
        cur.execute("select id from interaccion.catalogo_tipo_plan where codigo = 'NORMAL' limit 1")
        id_tipo_plan = (cur.fetchone() or [1])[0]
        
        cur.execute("select id from interaccion.catalogo_origen_plan where codigo = 'MANUAL_NUTRI' limit 1")
        id_origen_plan = (cur.fetchone() or [1])[0]

        cur.execute("select id from interaccion.catalogo_estado_plan where codigo = 'ACTIVO' limit 1")
        id_estado_plan = (cur.fetchone() or [1])[0]

        hoy = date.today()
        # El plan dura 28 días (4 semanas exactas)
        duracion_dias = 28 if replicar_mes else 7
        fecha_fin = hoy + timedelta(days=duracion_dias)
        
        # 3. Crear encabezado del plan
        cur.execute(
            """
            insert into interaccion.plan_nutricional (
                id_paciente, id_tipo_plan, id_origen_plan, id_estado_plan, 
                es_plantilla, comidas_por_dia, fecha_inicio, fecha_fin, vigente
            )
            values (%s, %s, %s, %s, false, 5, %s, %s, true)
            returning id
            """,
            (id_paciente, id_tipo_plan, id_origen_plan, id_estado_plan, hoy, fecha_fin)
        )
        plan_id = cur.fetchone()[0]
        
        dias_map = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
        inicio_semana = hoy - timedelta(days=hoy.weekday())

        # 4. Insertar ítems (con lógica de replicación)
        semanas_a_generar = 4 if replicar_mes else 1
        
        for semana in range(semanas_a_generar):
            offset_semana = semana * 7
            
            for day_name, moments in plan_data.items():
                if day_name not in dias_map: continue
                
                offset_dia = dias_map.index(day_name)
                # Fecha calculada: Lunes base + offset del día + offset de la semana
                fecha_programada = inicio_semana + timedelta(days=offset_dia + offset_semana)

                for moment_name, recipe in moments.items():
                    if not recipe or 'id' not in recipe: continue
                    
                    # Mapeo de ID de momento
                    cur.execute("select id from nutricion.momento_comida where nombre ilike %s limit 1", (moment_name,))
                    m_row = cur.fetchone()
                    if not m_row:
                        if "mañana" in moment_name.lower(): m_id = 2
                        elif "almuerzo" in moment_name.lower(): m_id = 3
                        elif "tarde" in moment_name.lower(): m_id = 4
                        elif "merienda" in moment_name.lower() or "cena" in moment_name.lower(): m_id = 5
                        else: m_id = 1
                    else:
                        m_id = m_row[0]
                    
                    cur.execute(
                        """
                        insert into interaccion.plan_item (
                            id_plan, fecha_programada, id_momento, id_receta
                        )
                        values (%s, %s, %s, %s)
                        """,
                        (plan_id, fecha_programada, m_id, recipe['id'])
                    )
        
        print(f"   ✓ Plan manual guardado: {duracion_dias} días generados.")
        return {"id_plan": plan_id, "status": "success", "dias_generados": duracion_dias}
