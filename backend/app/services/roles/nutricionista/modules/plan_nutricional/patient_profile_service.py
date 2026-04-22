from app.core.db import db_cursor
from app.repositories.clinical_repository import get_patient_active_condition_ids
from app.repositories.rules_repository import list_rules_for_conditions_by_type
from app.services.roles.nutricionista.modules.recetas.allowed_recipe_service import get_recetas_permitidas

def get_patient_full_profile(id_paciente: str):
    """
    Obtiene el perfil dividido en Clínico, Temporal y Nutricional.
    """
    # 1. Auditoría en Consola (Reforzada)
    get_recetas_permitidas(id_paciente)

    res = {
        "nombre": "No disponible",
        "sexo": "N/A",
        "clinico": "Ninguna",
        "temporal": "Ninguna",
        "nutricional": "Ninguna",
        "alergias": "Ninguna reportada",
        "reglas_clinicas": [],
        "reglas_nutricionales": []
    }
    
    try:
        with db_cursor() as cur:
            # 2. Datos Base
            cur.execute("select nombre_completo, (select codigo from usuarios.catalogo_sexo where id = id_sexo) from usuarios.paciente where id = %s::uuid", (id_paciente,))
            row = cur.fetchone()
            if row:
                res["nombre"], res["sexo"] = row

            # 3. Clasificación de Condiciones Activas
            cur.execute("""
                select c.nombre, t.codigo
                from clinico.control_condicion_activa cca
                join heuristico.condicion c on c.id = cca.id_condicion
                join heuristico.catalogo_tipo_condicion t on t.id = c.id_tipo_condicion
                where cca.id_control = (
                    select id from clinico.control_paciente 
                    where id_paciente = %s::uuid 
                    order by fecha_control desc limit 1
                ) and c.activa = true
            """, (id_paciente,))
            condiciones = cur.fetchall()
            
            clinicas = [c[0] for c in condiciones if c[1] == 'CLINICA']
            temporales = [c[0] for c in condiciones if c[1] == 'TEMPORAL']
            nutris = [c[0] for c in condiciones if c[1] == 'NUTRICIONAL']
            
            if clinicas: res["clinico"] = ", ".join(clinicas)
            if temporales: res["temporal"] = ", ".join(temporales)
            if nutris: res["nutricional"] = ", ".join(nutris)

            # 4. Alergias
            cur.execute("select string_agg(nombre, ', ') from nutricion.ingrediente where id in (select id_ingrediente from clinico.alergia_paciente_ingrediente where id_paciente = %s::uuid and activa = true)", (id_paciente,))
            alergias_i = cur.fetchone()[0]
            cur.execute("select string_agg(nombre, ', ') from nutricion.subgrupo_alimentario where id in (select id_subgrupo_alimentario from clinico.alergia_paciente_subgrupo where id_paciente = %s::uuid and activa = true)", (id_paciente,))
            alergias_g = cur.fetchone()[0]
            
            total_alergias = []
            if alergias_i: total_alergias.append(f"Ingr: {alergias_i}")
            if alergias_g: total_alergias.append(f"Subgrp: {alergias_g}")
            if total_alergias: res["alergias"] = " | ".join(total_alergias)

        # 5. Reglas
        c_ids = get_patient_active_condition_ids(id_paciente)
        if c_ids:
            r_clin = list_rules_for_conditions_by_type(c_ids, "CLINICA")
            r_nutri = list_rules_for_conditions_by_type(c_ids, "NUTRICIONAL")
            res["reglas_clinicas"] = [r["mensaje_error"] for r in r_clin if r.get("mensaje_error")]
            res["reglas_nutricionales"] = [r["mensaje_error"] for r in r_nutri if r.get("mensaje_error")]

    except Exception as e:
        print(f"Error en Perfil: {e}")
        
    return res
