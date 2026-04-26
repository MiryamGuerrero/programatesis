from fastapi import APIRouter
from app.api.v1.route_registry import registro_rutas_defecto

api_router = registro_rutas_defecto.construir_router()
