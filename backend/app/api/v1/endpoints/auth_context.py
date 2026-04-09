from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.api.deps import get_current_user
from app.core.security import UserContext
from app.repositories import profile_repository

router = APIRouter(tags=["Auth"])


class UpdateMyProfileRequest(BaseModel):
    nombre_completo: str | None = None
    cedula: str | None = None
    telefono: str | None = None
    direccion: str | None = None
    email: str | None = None


@router.get("/auth-context")
def auth_context(user: UserContext = Depends(get_current_user)) -> dict[str, str | None]:
    return {
        "user_id": user.user_id,
        "email": user.email,
        "role": user.role,
    }


@router.get("/profile/me")
def profile_me(user: UserContext = Depends(get_current_user)) -> dict[str, str | bool | None]:
    profile = profile_repository.fetch_my_profile(user_id=user.user_id, email=user.email)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Perfil no encontrado")

    return {
        "id": profile.get("id"),
        "auth_user_id": profile.get("auth_user_id"),
        "email": profile.get("email"),
        "nombre_completo": profile.get("nombre_completo"),
        "cedula": profile.get("cedula"),
        "telefono": profile.get("telefono"),
        "direccion": profile.get("direccion"),
        "role": profile.get("role"),
        "activo": bool(profile.get("activo")) if profile.get("activo") is not None else None,
    }


@router.put("/profile/me")
def update_profile_me(
    payload: UpdateMyProfileRequest,
    user: UserContext = Depends(get_current_user),
) -> dict[str, bool]:
    try:
        updated = profile_repository.update_my_profile(
            user_id=user.user_id,
            email=user.email,
            nombre_completo=payload.nombre_completo,
            cedula=payload.cedula,
            telefono=payload.telefono,
            direccion=payload.direccion,
            nuevo_email=str(payload.email) if payload.email is not None else None,
        )
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    if not updated:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se aplicaron cambios en el perfil",
        )

    return {"updated": True}
