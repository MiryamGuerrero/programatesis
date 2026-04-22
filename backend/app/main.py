from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import ORJSONResponse

from app.api.v1.router import api_router
from app.core.config import get_settings

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    default_response_class=ORJSONResponse,
)

# CORS configuration - Flexible for development
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://localhost:\d+", # Permite cualquier puerto en localhost
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    print("\n" + "="*50)
    print("SISTEMA REUMANUTRI INICIADO CON ÉXITO")
    print("MODIFICACIONES DE REGISTRO Y ALERGIAS CARGADAS")
    print("="*50 + "\n")


@app.get("/health", tags=["Health"])
def healthcheck() -> dict:
    return {"status": "ok"}


app.include_router(api_router, prefix="/api/v1")
