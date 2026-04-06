from dataclasses import dataclass
from importlib import import_module
from typing import Sequence

from fastapi import APIRouter

from app.api.v1.endpoints.auth_context import router as auth_context_router
from app.api.v1.endpoints.crud_ops import router as crud_ops_router
from app.api.v1.endpoints.roles.medico_endpoints import router as medico_router
from app.api.v1.endpoints.roles.nutricionista_endpoints import (
    router as nutricionista_router,
)
from app.api.v1.endpoints.roles.tutor_endpoints import router as tutor_router


def _load_optional_router(module_path: str) -> APIRouter | None:
    """Load a router only when the optional module is present."""

    try:
        module = import_module(module_path)
    except ModuleNotFoundError:
        return None

    router = getattr(module, "router", None)
    return router if isinstance(router, APIRouter) else None


nutricionista_admin_router = _load_optional_router(
    "app.api.v1.endpoints.roles.nutricionista_admin_endpoints"
)
nutricionista_etiquetas_config_router = _load_optional_router(
    "app.api.v1.endpoints.roles.nutricionista_etiquetas_config_endpoints"
)
ingredientes_router = _load_optional_router("app.api.v1.ingredientes_crud")
etiquetas_router = _load_optional_router("app.api.v1.etiquetas_crud")
etiquetas_nutricionales_router = _load_optional_router(
    "app.api.v1.etiquetas_nutricionales"
)
etiquetas_reglas_router = _load_optional_router("app.api.v1.etiquetas_reglas")


@dataclass(frozen=True)
class RouteModule:
    """Describe one mounted API module in a layer/role oriented structure."""

    name: str
    layer: str
    router: APIRouter
    role: str | None = None


class ApiRouteRegistry:
    """Builds the final APIRouter from declarative route modules."""

    def __init__(self, modules: Sequence[RouteModule]) -> None:
        self._modules = tuple(modules)

    def build_router(self) -> APIRouter:
        api_router = APIRouter()
        for module in self._modules:
            api_router.include_router(module.router)
        return api_router


def default_route_registry() -> ApiRouteRegistry:
    """Single source of truth for mounted endpoints by layer and role."""

    modules: list[RouteModule] = [
        RouteModule(name="auth_context", layer="presentation", router=auth_context_router),
        RouteModule(name="crud_ops", layer="presentation", router=crud_ops_router),
        RouteModule(name="medico", layer="presentation", role="medico", router=medico_router),
        RouteModule(
            name="nutricionista",
            layer="presentation",
            role="nutricionista",
            router=nutricionista_router,
        ),
        RouteModule(name="tutor", layer="presentation", role="tutor", router=tutor_router),
    ]

    if nutricionista_admin_router is not None:
        modules.append(
            RouteModule(
                name="nutricionista_admin",
                layer="presentation",
                role="nutricionista",
                router=nutricionista_admin_router,
            )
        )

    if nutricionista_etiquetas_config_router is not None:
        modules.append(
            RouteModule(
                name="nutricionista_etiquetas_config",
                layer="presentation",
                role="nutricionista",
                router=nutricionista_etiquetas_config_router,
            )
        )

    if ingredientes_router is not None:
        modules.append(
            RouteModule(name="ingredientes_crud", layer="presentation", router=ingredientes_router)
        )

    if etiquetas_router is not None:
        modules.append(
            RouteModule(name="etiquetas_crud", layer="presentation", router=etiquetas_router)
        )

    if etiquetas_nutricionales_router is not None:
        modules.append(
            RouteModule(
                name="etiquetas_nutricionales",
                layer="presentation",
                router=etiquetas_nutricionales_router,
            )
        )

    if etiquetas_reglas_router is not None:
        modules.append(
            RouteModule(name="etiquetas_reglas", layer="presentation", router=etiquetas_reglas_router)
        )

    return ApiRouteRegistry(tuple(modules))
