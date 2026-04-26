from ...domain.repositorios.interfaces import IRepositorioPerfil
from ...domain.modelos.usuario import PerfilUsuario
from ...domain.excepciones import ErrorRecursoNoEncontrado

class CasoUsoObtenerPerfilUsuario:
    def __init__(self, repo_perfil: IRepositorioPerfil):
        self.repo_perfil = repo_perfil

    def ejecutar(self, auth_id: str) -> PerfilUsuario:
        perfil = self.repo_perfil.obtener_por_auth_id(auth_id)
        if not perfil:
            raise ErrorRecursoNoEncontrado(f"No se encontró el perfil para el usuario autenticado: {auth_id}")
        
        # Validar integridad del dominio
        perfil.validar()
        
        return perfil

    def actualizar(self, auth_id: str, datos: dict) -> bool:
        """Actualiza los datos del perfil del usuario."""
        # Podríamos añadir validaciones específicas aquí si fuera necesario
        return self.repo_perfil.actualizar_datos_perfil(auth_id, datos)
