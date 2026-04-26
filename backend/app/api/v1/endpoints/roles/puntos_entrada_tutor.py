from datetime import date
from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.deps import require_roles
from app.api.v1.use_cases import obtener_caso_uso_gestionar_seguimiento
from app.aplicacion.nutricion.gestionar_seguimiento import CasoUsoGestionarSeguimiento
from pydantic import BaseModel

router = APIRouter(tags=["Tutor"])

class RegistroConsumoRequest(BaseModel):
    id_plan_item: int
    id_estado_consumo: int
    observacion: str | None = None

@router.get("/plan-diario/{id_paciente}")
def obtener_plan_diario(
    id_paciente: str,
    fecha: date = date.today(),
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento),
    _=Depends(require_roles("tutor", "admin"))
):
    return caso_uso.obtener_menu_diario(id_paciente, fecha)

@router.post("/registrar-consumo")
def registrar_consumo(
    payload: RegistroConsumoRequest,
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento),
    _=Depends(require_roles("tutor", "admin"))
):
    try:
        exito = caso_uso.registrar_comida_consumida(payload.model_dump())
        return {"success": exito}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get("/adherencia/{id_paciente}")
def obtener_estadisticas_adherencia(
    id_paciente: str,
    dias: int = Query(default=7, ge=1, le=30),
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento),
    _=Depends(require_roles("tutor", "admin"))
):
    return caso_uso.obtener_estadisticas_adherencia(id_paciente, dias)
