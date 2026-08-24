import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import ORJSONResponse
from starlette.status import HTTP_400_BAD_REQUEST, HTTP_404_NOT_FOUND, HTTP_500_INTERNAL_SERVER_ERROR

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.infraestructura.database.db import close_pool, get_pool
from app.domain.excepciones import ErrorDominio, ErrorValidacion, ErrorRecursoNoEncontrado, ErrorReglaNegocio

settings = get_settings()
dev_cors_origins = [
    *(f"http://localhost:{port}" for port in range(3000, 3011)),
    *(f"http://127.0.0.1:{port}" for port in range(3000, 3011)),
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]
cors_origins = list(dict.fromkeys([*settings.cors_origins, *dev_cors_origins]))

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Inicio del sistema: crear un unico pool antes de atender requests concurrentes.
    get_pool()
    yield
    # Cierre: Limpiar recursos del pool de base de datos
    try:
        close_pool()
    except Exception:
        pass # Evitar ruido en el shutdown

# NutriReuma API - Arquitectura Hexagonal Pragmática (Reload Marker v2)
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
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Compresión GZip para respuestas HTTP grandes (mejora latencia de cliente)
from starlette.middleware.gzip import GZipMiddleware
app.add_middleware(GZipMiddleware, minimum_size=500)

# Middleware simple para añadir cabeceras de cache en GETs de endpoints de catalogos y form-data
CACHE_PATH_PREFIXES = (
    "/api/v1/crud/catalog",
    "/api/v1/reglas-nutricionales/form-data",
    "/api/v1/reglas-menu-combinaciones",
    "/api/v1/ingredientes-lista",
    "/api/v1/usuarios",
)

@app.middleware("http")
async def add_cache_headers(request: Request, call_next):
    response = await call_next(request)
    try:
        if request.method == "GET":
            path = request.url.path
            for p in CACHE_PATH_PREFIXES:
                if path.startswith(p):
                    # short-lived cache to reduce repeated work from UI during navigation
                    response.headers.setdefault("Cache-Control", "public, max-age=30")
                    break
    except Exception:
        pass
    return response


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
