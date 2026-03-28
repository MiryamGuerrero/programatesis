from fastapi import APIRouter

from app.api.v1.endpoints.admin_medico import router as admin_medico_router
from app.api.v1.endpoints.nutricion_tutor import router as nutricion_tutor_router

api_router = APIRouter()
api_router.include_router(admin_medico_router)
api_router.include_router(nutricion_tutor_router)
