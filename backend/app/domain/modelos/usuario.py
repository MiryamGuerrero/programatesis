from pydantic import BaseModel, ConfigDict, computed_field
from typing import Optional
from ..excepciones import ErrorValidacion

class PerfilUsuario(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: str
    nombre_completo: str
    username: Optional[str] = None
    email: str
    rol_nombre: str  # Ahora usamos el nombre descriptivo
    rol_codigo: str
    id_rol: Optional[int] = None
    activo: Optional[bool] = None
    cedula: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    parentesco: Optional[str] = None


    @computed_field
    @property
    def avatar(self) -> str:
        """Calcula las iniciales del nombre y apellido."""
        partes = self.nombre_completo.strip().split()
        if len(partes) >= 2:
            return f"{partes[0][0]}{partes[-1][0]}".upper()
        elif len(partes) == 1:
            return f"{partes[0][0]}".upper()
        return "?"

    def validar(self):
        if not self.nombre_completo:
            raise ErrorValidacion("El nombre completo es requerido")
        if "@" not in self.email:
            raise ErrorValidacion("El email proporcionado no es válido")
