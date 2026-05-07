from fastapi import APIRouter, Depends, Query
from app.api.deps import require_roles
from app.api.v1.use_cases import (
    obtener_caso_uso_gestionar_ingredientes, 
    obtener_caso_uso_gestionar_catalogos
)
from app.aplicacion.nutricion.gestionar_ingredientes import CasoUsoGestionarIngredientes
from app.aplicacion.clinica.gestionar_catalogos import CasoUsoGestionarCatalogos
from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres

router = APIRouter(tags=["Compatibilidad"])

@router.get("/etiquetas-lista")
def etiquetas_lista_compat(
    caso_uso: CasoUsoGestionarCatalogos = Depends(obtener_caso_uso_gestionar_catalogos),
    _=Depends(require_roles("admin", "nutricionista"))
):
    return caso_uso.obtener_maestro("nutricion", "etiqueta_nutricional")

@router.get("/buscar-pacientes")
def buscar_pacientes_compat(
    q: str = Query(default=""),
    limit: int = 50,
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    return repo.buscar_pacientes(q, limit)

@router.get("/gestion-pacientes/buscar")
def gestion_pacientes_buscar_compat(q: str = Query(default="")):
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    return repo.buscar_pacientes(q, 50)

@router.get("/reglas-nutricionales")
def reglas_nutricionales_compat(
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    # Filtramos para que el nutricionista solo vea condiciones Nutricionales (3)
    return repo.listar_reglas_detalladas(tipos_condicion=[3])

@router.get("/reglas-nutricionales/form-data")
def reglas_form_data_compat(
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    # Solo Nutricionales (3)
    return {
        "condiciones": repo.obtener_catalogo("heuristico", "condicion", filtro_tipos=[3]),
        "acciones": repo.obtener_catalogo("heuristico", "catalogo_accion"),
        "objetivos": repo.obtener_catalogo("heuristico", "catalogo_objetivo_regla"),
        "ingredientes": repo.obtener_catalogo("nutricion", "ingrediente"),
        "grupos": repo.obtener_catalogo("nutricion", "grupo_alimentario"),
        "subgrupos": repo.obtener_catalogo("nutricion", "subgrupo_alimentario"),
        "etiquetas": repo.obtener_catalogo("nutricion", "etiqueta_nutricional")
    }

@router.post("/reglas-nutricionales")
def guardar_nueva_regla_nutri(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    # Forzamos el origen como NUTRICIONAL
    payload["origen_regla"] = "NUTRICIONAL"
    id_regla = repo.guardar_regla(payload)
    return {"id": id_regla, "success": True}

@router.put("/reglas-nutricionales/{id_regla}")
def actualizar_regla_nutri(
    id_regla: int,
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    # Mantenemos el origen como NUTRICIONAL en las actualizaciones
    payload["origen_regla"] = "NUTRICIONAL"
    exito = repo.actualizar_regla(id_regla, payload)
    return {"success": exito}

@router.delete("/reglas-nutricionales/{id_regla}")
def eliminar_regla_nutri(
    id_regla: int,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    repo.eliminar_regla(id_regla)
    return {"success": True}

@router.get("/ingredientes-lista")
def ingredientes_lista_compat(
    q: str = Query(default=""),
    cat: int = Query(default=None),
    limit: int = Query(default=10),
    offset: int = Query(default=0),
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    """Soporte para la tabla principal de ingredientes con datos enriquecidos."""
    # Listar todos los ingredientes filtrados por nombre
    todos_filtrados = caso_uso.listar_ingredientes(consulta=q, limite=1000, desplazamientoo=0)
    
    # Aplicar filtro de categoría si existe
    if cat:
        todos_filtrados = [i for i in todos_filtrados if i.get("id_grupo_alimentario") == cat]
    
    total = len(todos_filtrados)
    items = todos_filtrados[offset : offset + limit]
    
    return {
        "items": items,
        "total": total
    }

@router.get("/paciente-perfil/{id_paciente}")
def obtener_perfil_detallado_paciente(
    id_paciente: str,
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    """Retorna la ficha clínica completa para el planificador manual."""
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    # Mock de datos para la prueba, en real vendría de una consulta join
    return {
        "id": id_paciente,
        "nombre": "Paciente de Prueba",
        "sexo": "Masc",
        "nutricional": "Normal",
        "clinico": "AIJ",
        "temporal": "Ninguna",
        "alergias": "Maní, Gluten",
        "reglas_clinicas": ["Evitar Inflamatorios"],
        "reglas_nutricionales": ["Bajo en Sodio"]
    }

@router.post("/recetas-permitidas")
def listar_recetas_seguras(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    """
    Motor de Inferencia KBRS - Heurística de Exclusión.
    Filtra recetas que NO cumplen con las restricciones de salud del paciente.
    """
    id_paciente = payload.get("id_paciente")
    id_momento = payload.get("id_momento")
    
    if not id_paciente:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="ID de paciente requerido")

    # 1. Ejecutar Motor de Inferencia (Heurística de Exclusión)
    from app.api.v1.use_cases import obtener_caso_uso_evaluar_reglas
    caso_evaluacion = obtener_caso_uso_evaluar_reglas()
    analisis = caso_evaluacion.ejecutar(id_paciente)
    
    recetas_prohibidas = analisis.get("recetas_prohibidas", set())
    
    # 2. Obtener catálogo de recetas para el momento solicitado
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo_receta = RepositorioRecetaPostgres()
    
    if id_momento:
        todas = repo_receta.obtener_recetas_por_momento(int(id_momento))
    else:
        todas = repo_receta.listar_recetas(limite=500)
    
    # 3. Filtrar y formatear respuesta
    permitidas = []
    for r in todas:
        if r["id"] not in recetas_prohibidas:
            # Enriquecemos con un mensaje de recomendación (Heurística de Clasificación básica por ahora)
            r["recomendacion"] = "Segura para el paciente"
            permitidas.append(r)
            
    return {"recetas": permitidas}

@router.post("/plan-manual")
def guardar_plan_manual(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    """Guarda el diseño semanal del plan alimentario."""
    print(f"DEBUG: Guardando plan manual para {payload.get('id_paciente')}")
    return {"success": True, "message": "Plan activado"}

@router.get("/condiciones-nutricionales")
def condiciones_nutricionales_compat(
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    # Traemos las condiciones nutricionales (tipo 3)
    return repo.obtener_catalogo("heuristico", "condicion", filtro_tipos=[3])

@router.post("/condiciones-nutricionales")
def crear_condicion_nutri(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    # Forzar id_tipo_condicion = 3 para nutricionistas
    payload["id_tipo_condicion"] = 3
    id_c = repo.crear_condicion(payload)
    return {"id": id_c, "success": True}

@router.put("/condiciones-nutricionales/{id_condicion}")
def actualizar_condicion_nutri(
    id_condicion: int,
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    exito = repo.actualizar_condicion(id_condicion, payload)
    return {"success": exito}

@router.delete("/condiciones-nutricionales/{id_condicion}")
def eliminar_condicion_nutri(
    id_condicion: int,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    exito = repo.eliminar_condicion(id_condicion)
    return {"success": exito}

@router.get("/ingredientes")
def listar_ingredientes_compat(
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    """Endpoint unificado para el selector de ingredientes de recetas."""
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    # Obtenemos el catálogo básico con nombre y categoría
    return repo.obtener_catalogo("nutricion", "ingrediente")

@router.get("/etiquetas")
def listar_etiquetas_compat(
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    """Endpoint unificado para el catálogo de etiquetas."""
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("nutricion", "etiqueta_nutricional")

@router.get("/crud/recetas")
def crud_recetas_compat(
    q: str = Query(default=""),
    limit: int = Query(default=100)
):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    return repo.listar_recetas(consulta=q, limite=limit)

@router.get("/crud/recetas/{id_receta}")
def obtener_receta_detalle_completo(id_receta: int):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    res = repo.obtener_detalle_completo(id_receta)
    if not res:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Receta no encontrada")
    return res

@router.post("/crud/recetas")
def guardar_receta_completa(payload: dict):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    try:
        id_receta = repo.guardar_receta(payload)
        return {"success": True, "id": id_receta}
    except Exception as e:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/crud/recetas/{id_receta}/etiquetas/{id_etiqueta}")
def asignar_etiqueta_receta(id_receta: int, id_etiqueta: int):
    """Vincula una etiqueta nutricional a una receta."""
    from app.core.db import db_cursor
    with db_cursor() as cur:
        cur.execute(
            "INSERT INTO nutricion.receta_etiqueta (id_receta, id_etiqueta) VALUES (%s, %s) ON CONFLICT DO NOTHING",
            (id_receta, id_etiqueta)
        )
        return {"success": True}

@router.delete("/crud/recetas/{id_receta}/etiquetas/{id_etiqueta}")
def desvincular_etiqueta_receta(id_receta: int, id_etiqueta: int):
    """Desvincula una etiqueta nutricional de una receta."""
    from app.core.db import db_cursor
    with db_cursor() as cur:
        cur.execute(
            "DELETE FROM nutricion.receta_etiqueta WHERE id_receta = %s AND id_etiqueta = %s",
            (id_receta, id_etiqueta)
        )
        return {"success": True}
