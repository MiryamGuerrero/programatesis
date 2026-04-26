import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import ORJSONResponse
from starlette.status import HTTP_400_BAD_REQUEST, HTTP_404_NOT_FOUND, HTTP_500_INTERNAL_SERVER_ERROR

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.db import close_pool
from app.domain.excepciones import ErrorDominio, ErrorValidacion, ErrorRecursoNoEncontrado, ErrorReglaNegocio

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Inicio del sistema
    yield
    # Cierre: Limpiar recursos del pool de base de datos
    try:
        close_pool()
    except Exception:
        pass # Evitar ruido en el shutdown

# NutriReuma API - Arquitectura Hexagonal Pragmática
app = FastAPI(
    title="NutriReuma API",
    description="Sistema experto para el soporte de decisiones en nutrición pediátrica para pacientes con enfermedades reumáticas.",
    version="1.0.0",
    default_response_class=ORJSONResponse,
    lifespan=lifespan
)

# Configuración de Seguridad y CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8000",
        "http://localhost:19006", # Flutter Web local
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Manejadores de Excepciones de Dominio ---

@app.exception_handler(ErrorValidacion)
async def manejador_error_validacion(request: Request, exc: ErrorValidacion):
    return ORJSONResponse(
        status_code=HTTP_400_BAD_REQUEST,
        content={"error": "Validación de Dominio", "mensaje": str(exc), "detalle": exc.detalle}
    )

@app.exception_handler(ErrorRecursoNoEncontrado)
async def manejador_error_no_encontrado(request: Request, exc: ErrorRecursoNoEncontrado):
    return ORJSONResponse(
        status_code=HTTP_404_NOT_FOUND,
        content={"error": "Recurso No Encontrado", "mensaje": str(exc)}
    )

@app.exception_handler(ErrorReglaNegocio)
async def manejador_error_regla_negocio(request: Request, exc: ErrorReglaNegocio):
    return ORJSONResponse(
        status_code=HTTP_400_BAD_REQUEST,
        content={"error": "Infracción de Regla Clínica", "mensaje": str(exc)}
    )

@app.exception_handler(Exception)
async def manejador_error_inesperado(request: Request, exc: Exception):
    return ORJSONResponse(
        status_code=HTTP_500_INTERNAL_SERVER_ERROR,
        content={"error": "Error Interno", "mensaje": "Ha ocurrido un error inesperado en el sistema"}
    )

@app.get("/health")
def healthcheck():
    return {"status": "ok", "ambiente": "produccion_vf", "arquitectura": "hexagonal"}

app.include_router(api_router, prefix="/api/v1")
