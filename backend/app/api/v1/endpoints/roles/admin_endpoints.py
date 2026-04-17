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
	imagen_referencia: str | None = Field(default=None, max_length=1500)


class UpdateIngredienteRequest(BaseModel):
	nombre: str | None = None
	id_grupo_alimentario: int | None = None
	id_subgrupo_alimentario: int | None = None
	precio_libra: float | None = Field(default=None, ge=0)
	factor_parte_comestible: float | None = Field(default=None, gt=0)
	imagen_referencia: str | None = Field(default=None, max_length=1500)
	activo: bool | None = None


class CreateEtiquetaNutricionalRequest(BaseModel):
	nombre_visible: str = Field(min_length=1, max_length=160)
	codigo: str | None = Field(default=None, min_length=1, max_length=80)


class UpdateEtiquetaNutricionalRequest(BaseModel):
	nombre_visible: str | None = Field(default=None, min_length=1, max_length=160)
	codigo: str | None = Field(default=None, min_length=1, max_length=80)


class AssignEtiquetaIngredienteRequest(BaseModel):
	id_etiqueta: int | None = Field(default=None, gt=0)
	nombre_etiqueta: str | None = Field(default=None, min_length=1, max_length=160)


class UpsertIngredienteComposicionRequest(BaseModel):
	valores: dict[str, Any] = Field(default_factory=dict)


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
	_=Depends(require_roles("nutricionista")),
) -> list[dict[str, Any]]:
	return admin_crud_service.fetch_ingredientes()


@router.get("/crud/ingredientes/paged")
def crud_fetch_ingredientes_paged(
	q: str | None = Query(default=None, max_length=160),
	id_grupo_alimentario: int | None = Query(default=None, gt=0),
	id_subgrupo_alimentario: int | None = Query(default=None, gt=0),
	include_inactive: bool = Query(default=False),
	limit: int = Query(default=20, ge=1, le=100),
	offset: int = Query(default=0, ge=0),
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	items, total = admin_crud_service.fetch_ingredientes_page(
		search=q,
		id_grupo_alimentario=id_grupo_alimentario,
		id_subgrupo_alimentario=id_subgrupo_alimentario,
		include_inactive=include_inactive,
		limit=limit,
		offset=offset,
	)
	return {
		"items": items,
		"total": total,
		"limit": limit,
		"offset": offset,
	}


@router.post("/crud/ingredientes")
def crud_create_ingrediente(
	payload: CreateIngredienteRequest,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	try:
		created_id = admin_crud_service.create_ingrediente(
			nombre=payload.nombre,
			id_grupo_alimentario=payload.id_grupo_alimentario,
			id_subgrupo_alimentario=payload.id_subgrupo_alimentario,
			precio_libra=payload.precio_libra,
			factor_parte_comestible=payload.factor_parte_comestible,
			imagen_referencia=payload.imagen_referencia,
		)
	except ValueError as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	return {"id": created_id}


@router.put("/crud/ingredientes/{id_ingrediente}")
def crud_update_ingrediente(
	id_ingrediente: int,
	payload: UpdateIngredienteRequest,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	try:
		updated = admin_crud_service.update_ingrediente(
			id_ingrediente=id_ingrediente,
			nombre=payload.nombre,
			id_grupo_alimentario=payload.id_grupo_alimentario,
			id_subgrupo_alimentario=payload.id_subgrupo_alimentario,
			precio_libra=payload.precio_libra,
			factor_parte_comestible=payload.factor_parte_comestible,
			imagen_referencia=payload.imagen_referencia,
			actualizar_imagen_referencia="imagen_referencia" in payload.model_fields_set,
			activo=payload.activo,
		)
	except ValueError as exc:
		detail = str(exc)
		status_code = (
			status.HTTP_404_NOT_FOUND
			if "no encontrado" in detail.lower()
			else status.HTTP_400_BAD_REQUEST
		)
		raise HTTPException(status_code=status_code, detail=detail) from exc
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

	return {"id": id_ingrediente, "updated": updated}


@router.delete("/crud/ingredientes/{id_ingrediente}")
def crud_delete_ingrediente(
	id_ingrediente: int,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	try:
		deleted = admin_crud_service.delete_ingrediente(id_ingrediente)
	except ValueError as exc:
		detail = str(exc)
		status_code = (
			status.HTTP_404_NOT_FOUND
			if "no encontrado" in detail.lower()
			else status.HTTP_400_BAD_REQUEST
		)
		raise HTTPException(status_code=status_code, detail=detail) from exc
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

	return {"id": id_ingrediente, "deleted": deleted}


@router.get("/crud/ingredientes/{id_ingrediente}/composicion")
def crud_fetch_ingrediente_composicion(
	id_ingrediente: int,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	try:
		return admin_crud_service.fetch_ingrediente_composicion(id_ingrediente=id_ingrediente)
	except ValueError as exc:
		detail = str(exc)
		status_code = (
			status.HTTP_404_NOT_FOUND
			if "no encontrado" in detail.lower()
			else status.HTTP_400_BAD_REQUEST
		)
		raise HTTPException(status_code=status_code, detail=detail) from exc


@router.put("/crud/ingredientes/{id_ingrediente}/composicion")
def crud_upsert_ingrediente_composicion(
	id_ingrediente: int,
	payload: UpsertIngredienteComposicionRequest,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	try:
		updated = admin_crud_service.upsert_ingrediente_composicion(
			id_ingrediente=id_ingrediente,
			valores=payload.valores,
		)
	except ValueError as exc:
		detail = str(exc)
		status_code = (
			status.HTTP_404_NOT_FOUND
			if "no encontrado" in detail.lower()
			else status.HTTP_400_BAD_REQUEST
		)
		raise HTTPException(status_code=status_code, detail=detail) from exc

	return {"id_ingrediente": id_ingrediente, "updated": updated}


@router.get("/crud/etiquetas")
def crud_fetch_etiquetas(
	_=Depends(require_roles("nutricionista")),
) -> list[dict[str, Any]]:
	return admin_crud_service.fetch_etiquetas_nutricionales()


@router.post("/crud/etiquetas")
def crud_create_etiqueta(
	payload: CreateEtiquetaNutricionalRequest,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	try:
		return admin_crud_service.create_etiqueta_nutricional(
			nombre_visible=payload.nombre_visible,
			codigo=payload.codigo,
		)
	except ValueError as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.put("/crud/etiquetas/{id_etiqueta}")
def crud_update_etiqueta(
	id_etiqueta: int,
	payload: UpdateEtiquetaNutricionalRequest,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	try:
		updated = admin_crud_service.update_etiqueta_nutricional(
			id_etiqueta=id_etiqueta,
			nombre_visible=payload.nombre_visible,
			codigo=payload.codigo,
		)
	except ValueError as exc:
		detail = str(exc)
		status_code = (
			status.HTTP_404_NOT_FOUND
			if "no encontrada" in detail.lower()
			else status.HTTP_400_BAD_REQUEST
		)
		raise HTTPException(status_code=status_code, detail=detail) from exc
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

	return {"id": id_etiqueta, "updated": updated}


@router.delete("/crud/etiquetas/{id_etiqueta}")
def crud_delete_etiqueta(
	id_etiqueta: int,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	try:
		deleted = admin_crud_service.delete_etiqueta_nutricional(id_etiqueta)
	except ValueError as exc:
		detail = str(exc)
		status_code = (
			status.HTTP_404_NOT_FOUND
			if "no encontrada" in detail.lower()
			else status.HTTP_400_BAD_REQUEST
		)
		raise HTTPException(status_code=status_code, detail=detail) from exc
	except Exception as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

	return {"id": id_etiqueta, "deleted": deleted}


@router.get("/crud/ingredientes/{id_ingrediente}/etiquetas")
def crud_fetch_ingrediente_etiquetas(
	id_ingrediente: int,
	_=Depends(require_roles("nutricionista")),
) -> list[dict[str, Any]]:
	try:
		return admin_crud_service.fetch_ingrediente_etiquetas(id_ingrediente)
	except ValueError as exc:
		raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/crud/ingredientes/{id_ingrediente}/etiquetas")
def crud_assign_ingrediente_etiqueta(
	id_ingrediente: int,
	payload: AssignEtiquetaIngredienteRequest,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	if payload.id_etiqueta is None and not payload.nombre_etiqueta:
		raise HTTPException(
			status_code=status.HTTP_400_BAD_REQUEST,
			detail="Debe enviar id_etiqueta o nombre_etiqueta",
		)

	try:
		return admin_crud_service.assign_etiqueta_to_ingrediente(
			id_ingrediente=id_ingrediente,
			id_etiqueta=payload.id_etiqueta,
			nombre_etiqueta=payload.nombre_etiqueta,
		)
	except ValueError as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.delete("/crud/ingredientes/{id_ingrediente}/etiquetas/{id_etiqueta}")
def crud_remove_ingrediente_etiqueta(
	id_ingrediente: int,
	id_etiqueta: int,
	_=Depends(require_roles("nutricionista")),
) -> dict[str, Any]:
	try:
		removed = admin_crud_service.remove_etiqueta_from_ingrediente(
			id_ingrediente=id_ingrediente,
			id_etiqueta=id_etiqueta,
		)
	except ValueError as exc:
		raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc

	return {"id_ingrediente": id_ingrediente, "id_etiqueta": id_etiqueta, "removed": removed}


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