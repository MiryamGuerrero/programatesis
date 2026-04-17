from decimal import Decimal

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
    ("nutricion", "subgrupo_alimentario"),
}

_NUMERIC_SQL_TYPES = {
    "smallint",
    "integer",
    "bigint",
    "numeric",
    "real",
    "double precision",
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
    created_id = admin_crud_repository.create_user(
        email=email,
        nombre_completo=nombre_completo,
        id_rol=id_rol,
        cedula=cedula,
        username=username,
    )
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


def fetch_ingredientes_page(
    search: str | None,
    id_grupo_alimentario: int | None,
    id_subgrupo_alimentario: int | None,
    include_inactive: bool,
    limit: int,
    offset: int,
) -> tuple[list[dict], int]:
    normalized_search = search.strip() if search is not None else None
    if normalized_search == "":
        normalized_search = None

    if id_grupo_alimentario is not None and id_grupo_alimentario <= 0:
        raise ValueError("El grupo alimentario no es valido")
    if id_subgrupo_alimentario is not None and id_subgrupo_alimentario <= 0:
        raise ValueError("El subgrupo alimentario no es valido")

    return admin_crud_repository.fetch_ingredientes_page(
        search=normalized_search,
        id_grupo_alimentario=id_grupo_alimentario,
        id_subgrupo_alimentario=id_subgrupo_alimentario,
        include_inactive=include_inactive,
        limit=limit,
        offset=offset,
    )


def create_ingrediente(
    nombre: str,
    id_grupo_alimentario: int | None,
    id_subgrupo_alimentario: int | None,
    precio_libra: float,
    factor_parte_comestible: float,
    imagen_referencia: str | None = None,
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
        imagen_referencia=(imagen_referencia or "").strip() or None,
    )


def update_ingrediente(
    id_ingrediente: int,
    nombre: str | None = None,
    id_grupo_alimentario: int | None = None,
    id_subgrupo_alimentario: int | None = None,
    precio_libra: float | None = None,
    factor_parte_comestible: float | None = None,
    imagen_referencia: str | None = None,
    actualizar_imagen_referencia: bool = False,
    activo: bool | None = None,
) -> bool:
    if not admin_crud_repository.ingrediente_exists(id_ingrediente):
        raise ValueError("Ingrediente no encontrado")

    if all(
        value is None
        for value in (
            nombre,
            id_grupo_alimentario,
            id_subgrupo_alimentario,
            precio_libra,
            factor_parte_comestible,
            imagen_referencia if actualizar_imagen_referencia else None,
            activo,
        )
    ):
        raise ValueError("No hay campos para actualizar")

    normalized_nombre = nombre.strip() if nombre is not None else None
    if nombre is not None and not normalized_nombre:
        raise ValueError("El nombre del ingrediente es obligatorio")

    resolved_grupo = id_grupo_alimentario
    resolved_subgrupo = id_subgrupo_alimentario
    if id_grupo_alimentario is not None or id_subgrupo_alimentario is not None:
        defaults = admin_crud_repository.resolve_default_group_subgroup(
            id_grupo_alimentario,
            id_subgrupo_alimentario,
        )
        if not defaults or defaults[0] is None or defaults[1] is None:
            raise ValueError("No hay grupo/subgrupo alimentario valido")
        resolved_grupo, resolved_subgrupo = defaults

    normalized_imagen_referencia = None
    if actualizar_imagen_referencia:
        normalized_imagen_referencia = (imagen_referencia or "").strip() or None

    return admin_crud_repository.update_ingrediente(
        id_ingrediente=id_ingrediente,
        nombre=normalized_nombre,
        id_grupo_alimentario=resolved_grupo,
        id_subgrupo_alimentario=resolved_subgrupo,
        precio_libra=precio_libra,
        factor_parte_comestible=factor_parte_comestible,
        imagen_referencia=normalized_imagen_referencia,
        actualizar_imagen_referencia=actualizar_imagen_referencia,
        activo=activo,
    )


def delete_ingrediente(id_ingrediente: int) -> bool:
    if not admin_crud_repository.ingrediente_exists(id_ingrediente):
        raise ValueError("Ingrediente no encontrado")
    return admin_crud_repository.delete_ingrediente(id_ingrediente)


def fetch_ingrediente_composicion(id_ingrediente: int) -> dict:
    if not admin_crud_repository.ingrediente_exists(id_ingrediente):
        raise ValueError("Ingrediente no encontrado")

    metadata = admin_crud_repository.fetch_ingrediente_composicion_metadata()
    columnas = [column_name for column_name, _ in metadata]
    data_type_by_column = {column_name: data_type for column_name, data_type in metadata}

    values = admin_crud_repository.fetch_ingrediente_composicion(
        id_ingrediente=id_ingrediente,
        columnas=columnas,
    )

    normalized_values: dict[str, float | str] = {}
    for column_name in columnas:
        raw_value = None if values is None else values.get(column_name)
        if isinstance(raw_value, Decimal):
            raw_value = float(raw_value)

        data_type = data_type_by_column[column_name]
        if raw_value is None:
            normalized_values[column_name] = "" if data_type not in _NUMERIC_SQL_TYPES else 0.0
        elif data_type in _NUMERIC_SQL_TYPES:
            normalized_values[column_name] = float(raw_value)
        else:
            normalized_values[column_name] = str(raw_value)

    return {
        "id_ingrediente": id_ingrediente,
        "columnas": [
            {
                "codigo": column_name,
                "tipo": data_type_by_column[column_name],
            }
            for column_name in columnas
        ],
        "valores": normalized_values,
    }


def upsert_ingrediente_composicion(
    id_ingrediente: int,
    valores: dict[str, object],
) -> bool:
    if not admin_crud_repository.ingrediente_exists(id_ingrediente):
        raise ValueError("Ingrediente no encontrado")

    metadata = admin_crud_repository.fetch_ingrediente_composicion_metadata()
    if not metadata:
        raise ValueError("No se encontro metadata de composicion nutricional")

    data_type_by_column = {column_name: data_type for column_name, data_type in metadata}
    known_columns = set(data_type_by_column.keys())

    unknown_keys = [key for key in valores.keys() if key not in known_columns]
    if unknown_keys:
        joined = ", ".join(sorted(unknown_keys))
        raise ValueError(f"Variables de composicion no permitidas: {joined}")

    normalized_values: dict[str, object] = {}
    for column_name, raw_value in valores.items():
        data_type = data_type_by_column[column_name]
        if data_type in _NUMERIC_SQL_TYPES:
            if raw_value in (None, ""):
                normalized_values[column_name] = 0.0
                continue

            if isinstance(raw_value, bool):
                raise ValueError(f"Valor no valido para {column_name}")

            try:
                normalized_values[column_name] = float(raw_value)  # type: ignore[arg-type]
            except (TypeError, ValueError) as exc:
                raise ValueError(f"Valor numerico invalido para {column_name}") from exc
            continue

        if raw_value is None:
            normalized_values[column_name] = ""
        else:
            normalized_values[column_name] = str(raw_value).strip()

    return admin_crud_repository.upsert_ingrediente_composicion(
        id_ingrediente=id_ingrediente,
        valores=normalized_values,
        metadata=metadata,
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


def fetch_etiquetas_nutricionales() -> list[dict]:
    return admin_crud_repository.fetch_etiquetas_nutricionales()


def create_etiqueta_nutricional(
    nombre_visible: str,
    codigo: str | None = None,
) -> dict:
    name = nombre_visible.strip()
    if not name:
        raise ValueError("El nombre de la etiqueta es obligatorio")
    return admin_crud_repository.create_etiqueta_nutricional(name, codigo)


def update_etiqueta_nutricional(
    id_etiqueta: int,
    nombre_visible: str | None = None,
    codigo: str | None = None,
) -> bool:
    if not admin_crud_repository.etiqueta_exists(id_etiqueta):
        raise ValueError("Etiqueta no encontrada")

    if nombre_visible is None and codigo is None:
        raise ValueError("No hay campos para actualizar")

    normalized_nombre = nombre_visible.strip() if nombre_visible is not None else None
    if nombre_visible is not None and not normalized_nombre:
        raise ValueError("El nombre de la etiqueta es obligatorio")

    normalized_codigo = codigo.strip().upper() if codigo is not None else None
    if codigo is not None and not normalized_codigo:
        raise ValueError("El codigo de la etiqueta no puede estar vacio")

    return admin_crud_repository.update_etiqueta_nutricional(
        id_etiqueta=id_etiqueta,
        nombre_visible=normalized_nombre,
        codigo=normalized_codigo,
    )


def delete_etiqueta_nutricional(id_etiqueta: int) -> bool:
    if not admin_crud_repository.etiqueta_exists(id_etiqueta):
        raise ValueError("Etiqueta no encontrada")
    return admin_crud_repository.delete_etiqueta_nutricional(id_etiqueta)


def fetch_ingrediente_etiquetas(id_ingrediente: int) -> list[dict]:
    if not admin_crud_repository.ingrediente_exists(id_ingrediente):
        raise ValueError("Ingrediente no encontrado")
    return admin_crud_repository.fetch_ingrediente_etiquetas(id_ingrediente)


def assign_etiqueta_to_ingrediente(
    id_ingrediente: int,
    id_etiqueta: int | None = None,
    nombre_etiqueta: str | None = None,
) -> dict:
    if not admin_crud_repository.ingrediente_exists(id_ingrediente):
        raise ValueError("Ingrediente no encontrado")

    resolved_id = id_etiqueta

    if resolved_id is None:
        if not nombre_etiqueta or not nombre_etiqueta.strip():
            raise ValueError("Debe enviar id_etiqueta o nombre_etiqueta")
        created = create_etiqueta_nutricional(nombre_visible=nombre_etiqueta)
        resolved_id = int(created["id"])
    elif not admin_crud_repository.etiqueta_exists(resolved_id):
        raise ValueError("Etiqueta no encontrada")

    admin_crud_repository.assign_etiqueta_to_ingrediente(
        id_ingrediente=id_ingrediente,
        id_etiqueta=resolved_id,
    )
    etiquetas = admin_crud_repository.fetch_ingrediente_etiquetas(id_ingrediente)
    assigned = next((item for item in etiquetas if int(item["id_etiqueta"]) == resolved_id), None)
    return assigned or {"id_etiqueta": resolved_id}


def remove_etiqueta_from_ingrediente(id_ingrediente: int, id_etiqueta: int) -> bool:
    if not admin_crud_repository.ingrediente_exists(id_ingrediente):
        raise ValueError("Ingrediente no encontrado")
    return admin_crud_repository.remove_etiqueta_from_ingrediente(
        id_ingrediente=id_ingrediente,
        id_etiqueta=id_etiqueta,
    )
