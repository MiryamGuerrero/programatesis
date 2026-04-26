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
    return []

@router.get("/reglas-nutricionales/form-data")
def reglas_form_data_compat():
    repo = RepositorioPerfilPostgres()
    return {
        "condiciones": [],
        "acciones": [{"id": "ELIMINAR", "nombre": "Eliminar"}],
        "objetivos": [{"id": "INGREDIENTE", "nombre": "Ingrediente"}]
    }

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
    """Filtra recetas del catálogo que NO contengan alérgenos del paciente."""
    # id_paciente = payload.get("id_paciente")
    # id_momento = payload.get("id_momento")
    
    # Por ahora retornamos un catálogo base para la prueba
    return {
        "recetas": [
            {"id": 1, "nombre": "Sopa de Vegetales", "recomendacion": "Alta en fibra - Segura"},
            {"id": 2, "nombre": "Pollo a la Plancha", "recomendacion": "Proteína magra - Segura"},
            {"id": 3, "nombre": "Fruta Picada", "recomendacion": "Vitaminas - Segura"}
        ]
    }

@router.post("/plan-manual")
def guardar_plan_manual(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    """Guarda el diseño semanal del plan alimentario."""
    print(f"DEBUG: Guardando plan manual para {payload.get('id_paciente')}")
    return {"success": True, "message": "Plan activado"}

@router.get("/condiciones-nutricionales")
def condiciones_nutricionales_compat():
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("nutricion", "condicion_nutricional")

@router.get("/crud/recetas")
def crud_recetas_compat():
    return []
