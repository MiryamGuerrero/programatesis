from fastapi import Depends

# Repositorios
from ...infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
from ...infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
from ...infraestructura.repositorios.repositorio_ingrediente import RepositorioIngredientePostgres
from ...infraestructura.repositorios.repositorio_nutricion import RepositorioNutricionPostgres
from ...infraestructura.repositorios.repositorio_clinico import RepositorioClinicoPostgres
from ...infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
from ...infraestructura.repositorios.repositorio_seguimiento import RepositorioSeguimientoPostgres
from ...infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres

# Casos de Uso
from ...aplicacion.nutricion.evaluar_reglas_paciente import CasoUsoEvaluarReglasPaciente
from ...aplicacion.nutricion.gestionar_ingredientes import CasoUsoGestionarIngredientes
from ...aplicacion.nutricion.gestionar_variables import CasoUsoGestionarVariables
from ...aplicacion.clinica.gestionar_control_clinico import CasoUsoGestionarControlClinico
from ...aplicacion.clinica.gestionar_pacientes import CasoUsoGestionarPacientes
from ...aplicacion.clinica.gestionar_perfil_usuario import CasoUsoObtenerPerfilUsuario
from ...aplicacion.nutricion.generar_plan_semanal import CasoUsoGenerarPlanSemanal
from ...aplicacion.nutricion.gestionar_seguimiento import CasoUsoGestionarSeguimiento
from ...aplicacion.clinica.supervisar_adherencia import CasoUsoSupervisarAdherenciaPacientes
from ...aplicacion.clinica.gestionar_usuarios import CasoUsoGestionarUsuarios

from ...aplicacion.clinica.gestionar_catalogos import CasoUsoGestionarCatalogos

def obtener_caso_uso_gestionar_catalogos() -> CasoUsoGestionarCatalogos:
    return CasoUsoGestionarCatalogos(
        repo_perfil=RepositorioPerfilPostgres()
    )

def obtener_caso_uso_obtener_perfil() -> CasoUsoObtenerPerfilUsuario:
    return CasoUsoObtenerPerfilUsuario(
        repo_perfil=RepositorioPerfilPostgres()
    )

def obtener_caso_uso_evaluar_reglas() -> CasoUsoEvaluarReglasPaciente:
    return CasoUsoEvaluarReglasPaciente(
        repo_paciente=RepositorioPacientePostgres(),
        repo_regla=RepositorioReglaPostgres(),
        repo_ingrediente=RepositorioIngredientePostgres()
    )

def obtener_caso_uso_gestionar_ingredientes() -> CasoUsoGestionarIngredientes:
    return CasoUsoGestionarIngredientes(
        repo_ingrediente=RepositorioIngredientePostgres()
    )

def obtener_caso_uso_gestionar_variables() -> CasoUsoGestionarVariables:
    return CasoUsoGestionarVariables(
        repo_nutricion=RepositorioNutricionPostgres()
    )

def obtener_caso_uso_gestionar_clinico() -> CasoUsoGestionarControlClinico:
    return CasoUsoGestionarControlClinico(
        repo_clinico=RepositorioClinicoPostgres()
    )

def obtener_caso_uso_gestionar_pacientes() -> CasoUsoGestionarPacientes:
    return CasoUsoGestionarPacientes(
        repo_paciente=RepositorioPacientePostgres()
    )

def obtener_caso_uso_generar_plan() -> CasoUsoGenerarPlanSemanal:
    return CasoUsoGenerarPlanSemanal(
        caso_evaluacion=obtener_caso_uso_evaluar_reglas(),
        repo_receta=RepositorioRecetaPostgres()
    )

def obtener_caso_uso_gestionar_seguimiento() -> CasoUsoGestionarSeguimiento:
    return CasoUsoGestionarSeguimiento(
        repo_seguimiento=RepositorioSeguimientoPostgres()
    )

def obtener_caso_uso_supervisar_adherencia() -> CasoUsoSupervisarAdherenciaPacientes:
    return CasoUsoSupervisarAdherenciaPacientes(
        repo_seguimiento=RepositorioSeguimientoPostgres()
    )

def obtener_caso_uso_gestionar_usuarios() -> CasoUsoGestionarUsuarios:
    return CasoUsoGestionarUsuarios(
        repo_perfil=RepositorioPerfilPostgres()
    )
