from datetime import date
from app.core.db import db_cursor

def obtener_expediente_paciente(paciente_id: str) -> dict:
    """Trae toda la información actual del paciente para el expediente."""
    with db_cursor() as cur:
        # 1. Datos Maestros
        cur.execute("""
            SELECT p.id, p.nombre_completo, p.fecha_nacimiento, p.id_sexo, s.descripcion as sexo, 
                   p.id_provincia, p.enfermedad_principal, p.fecha_ultimo_control
            FROM usuarios.paciente p
            JOIN usuarios.catalogo_sexo s ON s.id = p.id_sexo
            WHERE p.id = %s
        """, (paciente_id,))
        p = cur.fetchone()
        if not p: return None
        
        # 2. Alergias a Ingredientes
        cur.execute("""
            SELECT i.id, i.nombre, a.observacion 
            FROM clinico.alergia_paciente_ingrediente a
            JOIN nutricion.ingrediente i ON i.id = a.id_ingrediente
            WHERE a.id_paciente = %s AND a.activa = true
        """, (paciente_id,))
        alergias_ing = [{"id": r[0], "nombre": r[1], "obs": r[2]} for r in cur.fetchall()]

        # 3. Alergias a Subgrupos (Usando id_subgrupo_alimentario)
        cur.execute("""
            SELECT g.id, g.nombre, a.observacion 
            FROM clinico.alergia_paciente_subgrupo a
            JOIN nutricion.subgrupo_alimentario g ON g.id = a.id_subgrupo_alimentario
            WHERE a.id_paciente = %s AND a.activa = true
        """, (paciente_id,))
        alergias_grp = [{"id": r[0], "nombre": r[1], "obs": r[2]} for r in cur.fetchall()]

        # 4. Condiciones Temporales Activas
        cur.execute("""
            SELECT c.id, c.nombre, r.fecha_inicio, r.fecha_fin,
                   (r.fecha_fin >= CURRENT_DATE) as es_vigente
            FROM clinico.restriccion_temporal_paciente r
            JOIN heuristico.condicion c ON c.id = r.id_condicion
            WHERE r.id_paciente = %s AND r.activa = true
            ORDER BY r.fecha_fin DESC
        """, (paciente_id,))
        temporales = [{"id": r[0], "nombre": r[1], "inicio": str(r[2]), "fin": str(r[3]), "vigente": r[4]} for r in cur.fetchall()]

        # 5. Condiciones Clínicas (Fijas de diagnósticos previos)
        cur.execute("""
            SELECT c.id, c.nombre
            FROM clinico.diagnostico_paciente d
            JOIN heuristico.condicion c ON c.id = d.id_condicion
            WHERE d.id_paciente = %s AND d.activa = true
        """, (paciente_id,))
        clinicas = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]

        # 6. Últimos controles para el historial
        cur.execute("""
            SELECT fecha_control, peso_kg, talla_cm, imc_calculado, diagnostico_oms_texto, 
                   nivel_dolor_eva, inflamacion_pcr, hay_brote_activo,
                   nivel_inflamacion, nivel_fatiga
            FROM clinico.control_paciente
            WHERE id_paciente = %s
            ORDER BY fecha_control DESC LIMIT 5
        """, (paciente_id,))
        historial = [
            {"fecha": str(r[0]), "peso": float(r[1]) if r[1] else 0, "talla": float(r[2]) if r[2] else 0, 
             "imc": float(r[3]) if r[3] else 0, "estado": r[4], "dolor": r[5], "pcr": float(r[6]) if r[6] else 0, "brote": r[7],
             "inflamacion": r[8], "fatiga": r[9]}
            for r in cur.fetchall()
        ]

        # Obtener estado OMS actual
        estado_oms = historial[0]['estado'] if historial else "Sin evaluación"

        return {
            "info": {
                "id": str(p[0]), "nombre": p[1], "fnac": str(p[2]), "id_sexo": p[3], "sexo": p[4],
                "provincia": p[5], "enfermedad": p[6], "ultimo_control": str(p[7]),
                "estado_oms": estado_oms
            },
            "alergias_ingredientes": alergias_ing,
            "alergias_grupos": alergias_grp,
            "condiciones_temporales": temporales,
            "condiciones_clinicas": clinicas,
            "historial": historial
        }

def guardar_alergias_y_temporales_full(paciente_id: str, ingredientes: list[int], grupos: list[int], temporales: list[dict]):
    """Actualiza alergias y condiciones temporales con fecha de fin."""
    with db_cursor() as cur:
        # 1. Sincronizar Alergias Ingredientes
        cur.execute("DELETE FROM clinico.alergia_paciente_ingrediente WHERE id_paciente = %s", (paciente_id,))
        for id_ing in ingredientes:
            cur.execute("""
                INSERT INTO clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, activa, fecha_registro) 
                VALUES (%s, %s, true, CURRENT_DATE)
            """, (paciente_id, id_ing))
        
        # 2. Sincronizar Alergias Subgrupos
        cur.execute("DELETE FROM clinico.alergia_paciente_subgrupo WHERE id_paciente = %s", (paciente_id,))
        for id_sub in grupos:
            cur.execute("""
                INSERT INTO clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, activa, fecha_registro) 
                VALUES (%s, %s, true, CURRENT_DATE)
            """, (paciente_id, id_sub))

        # 3. Sincronizar Restricciones Temporales
        cur.execute("UPDATE clinico.restriccion_temporal_paciente SET activa = false WHERE id_paciente = %s", (paciente_id,))
        for temp in temporales:
            cur.execute("""
                INSERT INTO clinico.restriccion_temporal_paciente 
                (id_paciente, id_condicion, fecha_inicio, fecha_fin, activa, accion_codigo, motivo)
                VALUES (%s, %s, LEAST(CURRENT_DATE, %s::date), %s, true, 'ELIMINAR', 'Restricción por condición temporal')
            """, (paciente_id, temp['id'], temp['fecha_fin'], temp['fecha_fin']))
