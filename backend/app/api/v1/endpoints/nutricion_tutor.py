"""Compatibility endpoint module.

Use app.api.v1.endpoints.roles.nutricionista_endpoints and
app.api.v1.endpoints.roles.tutor_endpoints for new development.
"""

from fastapi import APIRouter

from app.api.v1.endpoints.roles.nutricionista_endpoints import (
    router as nutricionista_router,
)
from app.api.v1.endpoints.roles.tutor_endpoints import router as tutor_router

router = APIRouter(tags=["Nutricionista Tutor"])
router.include_router(nutricionista_router)
router.include_router(tutor_router)

__all__ = ["router"]
