from fastapi import APIRouter

from app.api.v1.endpoints.auth_context import router as auth_context_router
from app.api.v1.endpoints.crud_ops import router as crud_ops_router
from app.api.v1.endpoints.roles.medico_endpoints import router as medico_router
from app.api.v1.endpoints.roles.nutricionista_endpoints import (
	router as nutricionista_router,
)
from app.api.v1.endpoints.roles.tutor_endpoints import router as tutor_router

api_router = APIRouter()
api_router.include_router(auth_context_router)
api_router.include_router(crud_ops_router)
api_router.include_router(medico_router)
api_router.include_router(nutricionista_router)
api_router.include_router(tutor_router)
