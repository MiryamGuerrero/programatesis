from fastapi import APIRouter, Depends

from app.api.deps import require_roles
from app.schemas.domain import (
    ReemplazoEquivalenteRequest,
    ReemplazoEquivalenteResponse,
)
from app.services.roles.tutor.modules.reemplazos.equivalent_replacement_service import (
    find_equivalent_replacements,
)

router = APIRouter(tags=["Tutor"])


@router.post("/reemplazo-equivalente", response_model=ReemplazoEquivalenteResponse)
def reemplazo_equivalente(
    payload: ReemplazoEquivalenteRequest,
    _=Depends(require_roles("admin", "nutricionista", "tutor")),
):
    return find_equivalent_replacements(
        id_ingrediente_original=payload.id_ingrediente_original,
        cantidad_gramos=payload.cantidad_gramos,
    )
