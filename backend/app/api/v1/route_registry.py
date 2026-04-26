from dataclasses import dataclass
from typing import Sequence
from fastapi import APIRouter

from app.api.v1.endpoints.contexto_autenticacion import router as router_contexto_auth
from app.api.v1.endpoints.roles.puntos_entrada_admin import router as router_admin
from app.api.v1.endpoints.roles.puntos_entrada_medico import router as router_medico
from app.api.v1.endpoints.roles.puntos_entrada_nutricionista_admin import (
    router as router_nutri_admin,
)
from app.api.v1.endpoints.roles.puntos_entrada_nutricionista import router as router_nutri
from app.api.v1.endpoints.roles.puntos_entrada_tutor import router as router_tutor
from app.api.v1.endpoints.roles.puntos_entrada_perfil import router as router_perfil
from app.api.v1.endpoints.roles.puntos_entrada_compatibilidad import router as router_compat

@dataclass(frozen=True)
class ModuloRuta:
    nombre: str
    capa: str
    rol: str
    router: APIRouter


@dataclass(frozen=True)
class RegistroRutasApi:
    modulos: Sequence[ModuloRuta]

    def construir_router(self) -> APIRouter:
        api_router = APIRouter()
        for modulo in self.modulos:
            api_router.include_router(modulo.router)
        return api_router


def construir_registro_defecto() -> RegistroRutasApi:
    # (nombre, rol, router)
    configs = (
        ("auth", "public", router_contexto_auth),
        ("admin", "admin", router_admin),
        ("medico", "medico", router_medico),
        ("nutri_admin", "nutricionista", router_nutri_admin),
        ("nutricionista", "nutricionista", router_nutri),
        ("tutor", "tutor", router_tutor),
        ("perfil", "public", router_perfil),
        ("compat", "public", router_compat),
    )

    modulos = []
    for nombre, rol, router in configs:
        modulos.append(
            ModuloRuta(
                nombre=nombre,
                capa="presentacion",
                rol=rol,
                router=router,
            )
        )

    return RegistroRutasApi(tuple(modulos))


registro_rutas_defecto = construir_registro_defecto()
