from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.api.deps import require_roles
from app.services.roles.admin.modules.crud import admin_crud_service

router = APIRouter(tags=["CRUD Roles"])


class CreateUserRequest(BaseModel):
	cedula: str | None = None
	username: str | None = None
	email: str
	nombre_completo: str
	id_rol: int = Field(gt=0)


class UpdateUserRequest(BaseModel):
	cedula: str | None = None
	username: str | None = None
	email: str | None = None
	nombre_completo: str | None = None
	id_rol: int | None = Field(default=None, gt=0)
	activo: bool | None = None


class CreateIngredienteRequest(BaseModel):
	nombre: str
	id_grupo_alimentario: int | None = None
	id_subgrupo_alimentario: int | None = None
	precio_libra: float = Field(default=0, ge=0)
	factor_parte_comestible: float = Field(default=1, gt=0)


class CreateControlClinicoRequest(BaseModel):
	id_paciente: str
	peso_kg: float = Field(gt=0)
	talla_cm: float = Field(gt=0)
	edad_meses: int = Field(ge=0, le=228)
	nivel_dolor_eva: int | None = Field(default=None, ge=0, le=10)
	nivel_inflamacion: int | None = Field(default=None, ge=0, le=10)
	imc_calculado: float | None = Field(default=None, gt=0)


class RegisterConsumoRequest(BaseModel):
	id_plan_item: int = Field(gt=0)
	estado_codigo: str
	id_receta_reemplazo: int | None = Field(default=None, gt=0)
	observacion: str | None = None


class RateRecetaRequest(BaseModel):
	id_paciente: str
	id_receta: int = Field(gt=0)
	estrellas: int = Field(ge=1, le=5)
	comentario: str | None = None


@router.get("/crud/users")
def crud_fetch_users(_=Depends(require_roles("admin"))) -> list[dict[str, Any]]:
	return admin_crud_service.fetch_users()


@router.post("/crud/users")
def crud_create_user(payload: CreateUserRequest, _=Depends(require_roles("admin"))) -> dict[str, Any]:
	try:
		created_id = admin_crud_service.create_user(
			cedula=payload.cedula,
			username=payload.username,
			email=payload.email,
			nombre_completo=payload.nombre_completo,
			id_rol=payload.id_rol,
		)
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	return {"id": created_id}


@router.put("/crud/users/{id_usuario}")
def crud_update_user(
	id_usuario: str,
	payload: UpdateUserRequest,
	_=Depends(require_roles("admin")),
) -> dict[str, Any]:
	try:
		updated = admin_crud_service.update_user(
			id_usuario=id_usuario,
			cedula=payload.cedula,
			username=payload.username,
			email=payload.email,
			nombre_completo=payload.nombre_completo,
			id_rol=payload.id_rol,
			activo=payload.activo,
		)
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	return {"id": id_usuario, "updated": updated}


@router.delete("/crud/users/{id_usuario}")
def crud_delete_user(
	id_usuario: str,
	_=Depends(require_roles("admin")),
) -> dict[str, Any]:
	try:
		deleted = admin_crud_service.delete_user(id_usuario=id_usuario)
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	return {"id": id_usuario, "deleted": deleted}


@router.get("/crud/catalog")
def crud_fetch_catalog(
	schema: str = Query(...),
	table: str = Query(...),
	_=Depends(require_roles("admin", "medico", "nutricionista")),
) -> list[dict[str, Any]]:
	try:
		return admin_crud_service.fetch_catalog(schema_name=schema, table_name=table)
	except ValueError as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/crud/ingredientes")
def crud_fetch_ingredientes(
	_=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> list[dict[str, Any]]:
	return admin_crud_service.fetch_ingredientes()


@router.post("/crud/ingredientes")
def crud_create_ingrediente(
	payload: CreateIngredienteRequest,
	_=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
	try:
		created_id = admin_crud_service.create_ingrediente(
			nombre=payload.nombre,
			id_grupo_alimentario=payload.id_grupo_alimentario,
			id_subgrupo_alimentario=payload.id_subgrupo_alimentario,
			precio_libra=payload.precio_libra,
			factor_parte_comestible=payload.factor_parte_comestible,
		)
	except ValueError as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	return {"id": created_id}


@router.get("/crud/recetas")
def crud_fetch_recetas(
	_=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> list[dict[str, Any]]:
	return admin_crud_service.fetch_recetas()


@router.post("/crud/controles")
def crud_create_control(
	payload: CreateControlClinicoRequest,
	_=Depends(require_roles("admin", "medico", "nutricionista")),
) -> dict[str, Any]:
	try:
		created_id = admin_crud_service.create_control(
			id_paciente=payload.id_paciente,
			peso_kg=payload.peso_kg,
			talla_cm=payload.talla_cm,
			edad_meses=payload.edad_meses,
			nivel_dolor_eva=payload.nivel_dolor_eva,
			nivel_inflamacion=payload.nivel_inflamacion,
			imc_calculado=payload.imc_calculado,
		)
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	return {"id": created_id}


@router.get("/crud/plan-items")
def crud_fetch_plan_items(
	id_paciente: str = Query(...),
	_=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> list[dict[str, Any]]:
	return admin_crud_service.fetch_plan_items(id_paciente)


@router.post("/crud/consumos")
def crud_register_consumo(
	payload: RegisterConsumoRequest,
	_=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> dict[str, Any]:
	try:
		created_id = admin_crud_service.register_consumo(
			id_plan_item=payload.id_plan_item,
			estado_codigo=payload.estado_codigo,
			id_receta_reemplazo=payload.id_receta_reemplazo,
			observacion=payload.observacion,
		)
	except ValueError as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	return {"id": created_id}


@router.post("/crud/evaluaciones")
def crud_rate_receta(
	payload: RateRecetaRequest,
	_=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> dict[str, Any]:
	try:
		created_id = admin_crud_service.rate_receta(
			id_paciente=payload.id_paciente,
			id_receta=payload.id_receta,
			estrellas=payload.estrellas,
			comentario=payload.comentario,
		)
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	return {"id": created_id}