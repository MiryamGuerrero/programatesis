from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from psycopg import sql
from pydantic import BaseModel, Field

from app.api.deps import require_roles
from app.core.db import db_cursor

router = APIRouter(tags=["CRUD Roles"])

_ALLOWED_CATALOGS: set[tuple[str, str]] = {
    ("dom_identidad_catalogos", "rol"),
    ("dom_identidad_catalogos", "catalogo_sexo"),
    ("dom_reglas_catalogos", "catalogo_accion"),
    ("dom_reglas_catalogos", "catalogo_objetivo_regla"),
    ("dom_planes_catalogos_estado", "catalogo_estado_plan"),
    ("dom_planes_catalogos_tipo", "catalogo_tipo_plan"),
    ("dom_planes_catalogos_tipo", "catalogo_origen_plan"),
    ("dom_planes_catalogos_estado", "catalogo_estado_consumo"),
}


def _rows_to_dicts(cur: Any, rows: list[tuple[Any, ...]]) -> list[dict[str, Any]]:
    columns = [description[0] for description in cur.description]
    return [dict(zip(columns, row, strict=False)) for row in rows]


class CreateUserRequest(BaseModel):
    email: str
    nombre_completo: str
    id_rol: int = Field(gt=0)


class CreateIngredienteRequest(BaseModel):
    nombre: str
    id_grupo_alimentario: int | None = None


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
    query = """
        select id, id_rol, email, nombre_completo, telefono, direccion, activo, created_at
        from dom_identidad_usuarios.usuario
        order by created_at desc
    """
    with db_cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()
        return _rows_to_dicts(cur, rows)


@router.post("/crud/users")
def crud_create_user(payload: CreateUserRequest, _=Depends(require_roles("admin"))) -> dict[str, Any]:
    query = """
        insert into dom_identidad_usuarios.usuario (email, nombre_completo, id_rol)
        values (%s, %s, %s)
        returning id
    """
    try:
        with db_cursor() as cur:
            cur.execute(query, (payload.email.strip(), payload.nombre_completo.strip(), payload.id_rol))
            created = cur.fetchone()
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    return {"id": str(created[0]) if created else None}


@router.get("/crud/catalog")
def crud_fetch_catalog(
    schema: str = Query(...),
    table: str = Query(...),
    _=Depends(require_roles("admin")),
) -> list[dict[str, Any]]:
    normalized = (schema.strip().lower(), table.strip().lower())
    if normalized not in _ALLOWED_CATALOGS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Catalogo no permitido")

    statement = sql.SQL("select * from {}.{} order by 1").format(
        sql.Identifier(normalized[0]),
        sql.Identifier(normalized[1]),
    )

    with db_cursor() as cur:
        cur.execute(statement)
        rows = cur.fetchall()
        return _rows_to_dicts(cur, rows)


@router.get("/crud/ingredientes")
def crud_fetch_ingredientes(
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> list[dict[str, Any]]:
    query = """
        select id, nombre, id_grupo_alimentario, activo
        from dom_nutricion_ingredientes.ingrediente
        order by id desc
    """
    with db_cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()
        return _rows_to_dicts(cur, rows)


@router.post("/crud/ingredientes")
def crud_create_ingrediente(
    payload: CreateIngredienteRequest,
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    query = """
        insert into dom_nutricion_ingredientes.ingrediente (nombre, id_grupo_alimentario, activo)
        values (%s, %s, true)
        returning id
    """
    try:
        with db_cursor() as cur:
            cur.execute(query, (payload.nombre.strip(), payload.id_grupo_alimentario))
            created = cur.fetchone()
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    return {"id": created[0] if created else None}


@router.get("/crud/recetas")
def crud_fetch_recetas(
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> list[dict[str, Any]]:
    query = """
        select id, nombre, calorias_totales
        from dom_recetas_base.receta
        order by id desc
    """
    with db_cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()
        return _rows_to_dicts(cur, rows)


@router.post("/crud/controles")
def crud_create_control(
    payload: CreateControlClinicoRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
) -> dict[str, Any]:
    query = """
        insert into dom_clinica_controles.control_paciente (
            id_paciente,
            peso_kg,
            talla_cm,
            edad_meses,
            nivel_dolor_eva,
            nivel_inflamacion,
            imc_calculado
        )
        values (%s, %s, %s, %s, %s, %s, %s)
        returning id
    """
    try:
        with db_cursor() as cur:
            cur.execute(
                query,
                (
                    payload.id_paciente,
                    payload.peso_kg,
                    payload.talla_cm,
                    payload.edad_meses,
                    payload.nivel_dolor_eva,
                    payload.nivel_inflamacion,
                    payload.imc_calculado,
                ),
            )
            created = cur.fetchone()
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    return {"id": created[0] if created else None}


@router.get("/crud/plan-items")
def crud_fetch_plan_items(
    id_paciente: str = Query(...),
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> list[dict[str, Any]]:
    query = """
        select pi.id, pi.id_plan, pi.id_receta, pi.id_momento, pi.fecha_programada
        from dom_planes_base.plan_item pi
        inner join dom_planes_base.plan_nutricional pn on pn.id = pi.id_plan
        where pn.id_paciente = %s
        order by pi.fecha_programada asc, pi.id asc
    """
    with db_cursor() as cur:
        cur.execute(query, (id_paciente,))
        rows = cur.fetchall()
        return _rows_to_dicts(cur, rows)


@router.post("/crud/consumos")
def crud_register_consumo(
    payload: RegisterConsumoRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> dict[str, Any]:
    estado_query = """
        select id
        from dom_planes_catalogos_estado.catalogo_estado_consumo
        where codigo = %s
        limit 1
    """
    insert_query = """
        insert into dom_planes_base.seguimiento_plan_item (
            id_plan_item,
            id_estado_consumo,
            id_receta_reemplazo,
            observacion,
            fecha_consumo
        )
        values (%s, %s, %s, %s, now())
        returning id
    """

    with db_cursor() as cur:
        cur.execute(estado_query, (payload.estado_codigo.strip(),))
        estado = cur.fetchone()
        if not estado:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"No existe estado de consumo: {payload.estado_codigo}",
            )

        try:
            cur.execute(
                insert_query,
                (
                    payload.id_plan_item,
                    estado[0],
                    payload.id_receta_reemplazo,
                    payload.observacion,
                ),
            )
            created = cur.fetchone()
        except Exception as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    return {"id": created[0] if created else None}


@router.post("/crud/evaluaciones")
def crud_rate_receta(
    payload: RateRecetaRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
) -> dict[str, Any]:
    query = """
        insert into dom_experiencia_usuario.evaluacion_receta (
            id_paciente,
            id_receta,
            estrellas,
            comentario,
            origen_evaluacion
        )
        values (%s, %s, %s, %s, 'APP_TUTOR')
        returning id
    """

    try:
        with db_cursor() as cur:
            cur.execute(
                query,
                (
                    payload.id_paciente,
                    payload.id_receta,
                    payload.estrellas,
                    payload.comentario,
                ),
            )
            created = cur.fetchone()
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    return {"id": created[0] if created else None}
