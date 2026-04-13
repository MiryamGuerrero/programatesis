from app.core.auth_onboarding import delete_auth_user, provision_auth_user_with_password_setup
from app.repositories import admin_crud_repository

ALLOWED_CATALOGS: set[tuple[str, str]] = {
    ("usuarios", "rol"),
    ("usuarios", "catalogo_sexo"),
    ("usuarios", "parentesco"),
    ("usuarios", "provincia"),
    ("heuristico", "catalogo_accion"),
    ("heuristico", "catalogo_objetivo_regla"),
    ("heuristico", "catalogo_tipo_condicion"),
    ("heuristico", "condicion"),
    ("interaccion", "catalogo_estado_plan"),
    ("interaccion", "catalogo_tipo_plan"),
    ("interaccion", "catalogo_origen_plan"),
    ("interaccion", "catalogo_estado_consumo"),
    ("nutricion", "grupo_alimentario"),
}


def fetch_users() -> list[dict]:
    return admin_crud_repository.fetch_users()


def create_user(
    email: str,
    nombre_completo: str,
    id_rol: int,
    cedula: str | None = None,
    username: str | None = None,
) -> str | None:
    role_code = admin_crud_repository.fetch_role_code(id_rol)
    if not role_code:
        raise ValueError(f"No existe rol configurado para id_rol={id_rol}")

    auth_user_id = provision_auth_user_with_password_setup(
        email=email,
        nombre_completo=nombre_completo,
        role_code=role_code,
    )

    created_id = None
    try:
        created_id = admin_crud_repository.create_user(
            email=email,
            nombre_completo=nombre_completo,
            id_rol=id_rol,
            auth_user_id=auth_user_id,
            cedula=cedula,
            username=username,
        )
    except Exception as exc:
        try:
            delete_auth_user(auth_user_id)
        except Exception:
            pass
        raise exc

    return str(created_id) if created_id is not None else None


def update_user(
    id_usuario: str,
    cedula: str | None = None,
    username: str | None = None,
    email: str | None = None,
    nombre_completo: str | None = None,
    id_rol: int | None = None,
    activo: bool | None = None,
) -> bool:
    return admin_crud_repository.update_user(
        id_usuario=id_usuario,
        cedula=cedula,
        username=username,
        email=email,
        nombre_completo=nombre_completo,
        id_rol=id_rol,
        activo=activo,
    )


def delete_user(id_usuario: str) -> bool:
    return admin_crud_repository.delete_user(id_usuario)


def fetch_catalog(schema_name: str, table_name: str) -> list[dict]:
    normalized = (schema_name.strip().lower(), table_name.strip().lower())
    if normalized not in ALLOWED_CATALOGS:
        raise ValueError("Catalogo no permitido")
    return admin_crud_repository.fetch_catalog(normalized[0], normalized[1])


def fetch_ingredientes() -> list[dict]:
    return admin_crud_repository.fetch_ingredientes()


def create_ingrediente(
    nombre: str,
    id_grupo_alimentario: int | None,
    id_subgrupo_alimentario: int | None,
    precio_libra: float,
    factor_parte_comestible: float,
) -> int | None:
    defaults = admin_crud_repository.resolve_default_group_subgroup(
        id_grupo_alimentario,
        id_subgrupo_alimentario,
    )
    if not defaults or defaults[0] is None or defaults[1] is None:
        raise ValueError(
            "No hay grupo/subgrupo alimentario disponible para crear ingrediente. "
            "Cree catalogos en nutricion.grupo_alimentario y nutricion.subgrupo_alimentario."
        )

    return admin_crud_repository.create_ingrediente(
        nombre=nombre,
        id_grupo_alimentario=defaults[0],
        id_subgrupo_alimentario=defaults[1],
        precio_libra=precio_libra,
        factor_parte_comestible=factor_parte_comestible,
    )


def fetch_recetas() -> list[dict]:
    return admin_crud_repository.fetch_recetas()


def create_control(
    id_paciente: str,
    peso_kg: float,
    talla_cm: float,
    edad_meses: int,
    nivel_dolor_eva: int | None,
    nivel_inflamacion: int | None,
    imc_calculado: float | None,
) -> int | None:
    return admin_crud_repository.create_control(
        id_paciente=id_paciente,
        peso_kg=peso_kg,
        talla_cm=talla_cm,
        edad_meses=edad_meses,
        nivel_dolor_eva=nivel_dolor_eva,
        nivel_inflamacion=nivel_inflamacion,
        imc_calculado=imc_calculado,
    )


def fetch_plan_items(id_paciente: str) -> list[dict]:
    return admin_crud_repository.fetch_plan_items(id_paciente)


def register_consumo(
    id_plan_item: int,
    estado_codigo: str,
    id_receta_reemplazo: int | None,
    observacion: str | None,
) -> int | None:
    estado_id = admin_crud_repository.find_estado_consumo_id(estado_codigo)
    if estado_id is None:
        raise ValueError(f"No existe estado de consumo: {estado_codigo}")

    return admin_crud_repository.register_consumo(
        id_plan_item=id_plan_item,
        id_estado_consumo=estado_id,
        id_receta_reemplazo=id_receta_reemplazo,
        observacion=observacion,
    )


def rate_receta(
    id_paciente: str,
    id_receta: int,
    estrellas: int,
    comentario: str | None,
) -> int | None:
    return admin_crud_repository.rate_receta(
        id_paciente=id_paciente,
        id_receta=id_receta,
        estrellas=estrellas,
        comentario=comentario,
    )
