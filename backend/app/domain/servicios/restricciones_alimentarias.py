from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable


@dataclass(frozen=True)
class RestriccionAlimentaria:
    codigo: str
    nombre: str
    subgrupos_ids: set[int] = field(default_factory=set)
    ingredientes_ids: set[int] = field(default_factory=set)
    patrones_subgrupo: tuple[str, ...] = ()
    patrones_ingrediente: tuple[str, ...] = ()
    etiquetas_bloqueadas: tuple[str, ...] = ()
    etiquetas_positivas: tuple[str, ...] = ()


SUBGRUPOS_CON_LACTOSA = {
    98, 100, 101, 104, 105, 108, 111, 114, 117, 119
}


RESTRICCIONES_ALIMENTARIAS: dict[str, RestriccionAlimentaria] = {
    "INTOLERANCIA_LACTOSA": RestriccionAlimentaria(
        codigo="INTOLERANCIA_LACTOSA",
        nombre="Intolerancia a la lactosa",
        subgrupos_ids=SUBGRUPOS_CON_LACTOSA,
        patrones_subgrupo=(
            "con lactosa",
            "leches animales",
            "quesos frescos",
            "quesos procesados",
            "mantequillas",
        ),
        etiquetas_bloqueadas=("CONTIENE_LACTOSA",),
        etiquetas_positivas=("SIN_LACTOSA",),
    ),
    "INTOLERANCIA_GLUTEN": RestriccionAlimentaria(
        codigo="INTOLERANCIA_GLUTEN",
        nombre="Intolerancia al gluten",
        patrones_subgrupo=("con gluten",),
        patrones_ingrediente=("trigo", "cebada", "centeno", "cuscus", "cusc?s", "pasta", "galleta"),
        etiquetas_bloqueadas=("CONTIENE_GLUTEN",),
        etiquetas_positivas=("SIN_GLUTEN",),
    ),
    "CELIAQUIA": RestriccionAlimentaria(
        codigo="CELIAQUIA",
        nombre="Celiaqu?a",
        patrones_subgrupo=("con gluten",),
        patrones_ingrediente=("trigo", "cebada", "centeno", "cuscus", "cusc?s", "pasta", "galleta"),
        etiquetas_bloqueadas=("CONTIENE_GLUTEN",),
        etiquetas_positivas=("SIN_GLUTEN",),
    ),
    "INTOLERANCIA_FRUCTOSA": RestriccionAlimentaria(
        codigo="INTOLERANCIA_FRUCTOSA",
        nombre="Intolerancia a la fructosa",
        patrones_subgrupo=("frutas", "dulces"),
        patrones_ingrediente=(
            "fructosa", "miel", "jarabe", "sirope", "manzana", "pera", "mango", "sandia", "sand?a",
            "uva", "pasas", "higo", "datil", "d?til",
        ),
        etiquetas_bloqueadas=("ALTO_FRUCTOSA", "CONTIENE_FRUCTOSA"),
        etiquetas_positivas=("BAJO_FRUCTOSA", "SIN_FRUCTOSA"),
    ),
    "INTOLERANCIA_HISTAMINA": RestriccionAlimentaria(
        codigo="INTOLERANCIA_HISTAMINA",
        nombre="Intolerancia a la histamina",
        patrones_subgrupo=("quesos curados", "embutidos", "fermentad", "pescado"),
        patrones_ingrediente=(
            "queso curado", "parmesano", "embutido", "salami", "chorizo", "jamon", "jam?n", "atun",
            "at?n", "sardina", "salmon", "salm?n", "vinagre", "chucrut", "kefir", "k?fir",
        ),
        etiquetas_bloqueadas=("ALTO_HISTAMINA", "FERMENTADO"),
        etiquetas_positivas=("BAJO_HISTAMINA",),
    ),
    "INTOLERANCIA_SORBITOL_SACAROSA": RestriccionAlimentaria(
        codigo="INTOLERANCIA_SORBITOL_SACAROSA",
        nombre="Intolerancia a sorbitol/sacarosa",
        patrones_subgrupo=("dulces", "pasteleria", "pasteler?a"),
        patrones_ingrediente=(
            "sorbitol", "sacarosa", "azucar", "az?car", "caramelo", "mermelada", "dulce", "chicle",
            "manzana", "pera", "ciruela",
        ),
        etiquetas_bloqueadas=("CONTIENE_SORBITOL", "ALTO_SACAROSA", "ALTO_AZUCAR"),
        etiquetas_positivas=("SIN_SORBITOL", "BAJO_SACAROSA", "BAJO_AZUCAR"),
    ),
    "INTOLERANCIA_SULFITOS": RestriccionAlimentaria(
        codigo="INTOLERANCIA_SULFITOS",
        nombre="Intolerancia a sulfitos",
        patrones_subgrupo=("frutos secos", "procesad", "conserva"),
        patrones_ingrediente=(
            "sulfito", "vino", "pasas", "fruta deshidratada", "frutos secos", "conserva", "encurtido", "vinagre",
        ),
        etiquetas_bloqueadas=("CONTIENE_SULFITOS",),
        etiquetas_positivas=("SIN_SULFITOS",),
    ),
    "DIABETES": RestriccionAlimentaria(
        codigo="DIABETES",
        nombre="Diabetes",
        patrones_subgrupo=(
            "dulces", "pasteleria", "pasteler?a", "chocolates con leche",
            "dulces con lacteos", "dulces con l?cteos",
        ),
        patrones_ingrediente=(
            "azucar", "az?car", "panela", "miel", "jarabe", "sirope", "caramelo", "mermelada",
            "dulce de leche", "gaseosa", "refresco", "chocolate blanco", "chocolate con leche",
        ),
        etiquetas_bloqueadas=("ALTO_AZUCAR", "NO_APTO_DIABETICOS"),
        etiquetas_positivas=("APTO_DIABETICOS", "BAJO_AZUCAR", "SIN_AZUCAR_ANADIDA", "CARBOHIDRATO_CONTROLADO"),
    ),
}

CODIGOS_RESTRICCION_ALIAS: dict[str, str] = {
    "ALERGIA_GLUTEN": "INTOLERANCIA_GLUTEN",
    "DIABETES_RESTRICCION_AZUCAR": "DIABETES",
    "ALERGIA_SULFITOS": "INTOLERANCIA_SULFITOS",
    "INTOLERANCIA_FRUCTOSA_SEVERA": "INTOLERANCIA_FRUCTOSA",
}


def resolver_codigo_restriccion(codigo: str | None) -> str:
    raw = str(codigo or "").strip().upper()
    if not raw:
        return ""
    return CODIGOS_RESTRICCION_ALIAS.get(raw, raw)


def normalizar_codigos_restriccion(codigos: Iterable[str] | None) -> set[str]:
    if not codigos:
        return set()
    return {
        resolver_codigo_restriccion(codigo)
        for codigo in codigos
        if resolver_codigo_restriccion(codigo) in RESTRICCIONES_ALIMENTARIAS
    }


def _resolver_subgrupos_ids_para_catalogo(
    restriccion: RestriccionAlimentaria,
    subgrupos_catalogo: list[dict] | None = None,
) -> list[int]:
    ids = set(restriccion.subgrupos_ids)
    if not subgrupos_catalogo:
        return sorted(ids)

    def _normalizar_texto(v: str) -> str:
        txt = (v or "").lower()
        return (
            txt.replace("á", "a")
            .replace("é", "e")
            .replace("í", "i")
            .replace("ó", "o")
            .replace("ú", "u")
            .replace("ñ", "n")
            .replace("?", "a")
        )

    def _excluir_falso_positivo(nombre_norm: str, patron_norm: str) -> bool:
        if patron_norm in ("con lactosa", "leches animales", "quesos frescos", "quesos procesados", "mantequillas"):
            # Evitar capturar opciones "sin lactosa".
            if "sin lactosa" in nombre_norm:
                return True
            # Evitar falsos positivos de frutos secos por palabra "mantequilla".
            if "frutos secos" in nombre_norm:
                return True
        if patron_norm in ("dulces", "pasteleria", "pasteleria"):
            # No penalizar versiones "sin" cuando son explícitamente aptas.
            if "sin azucar" in nombre_norm or "sin lacteos" in nombre_norm or "sin lacteos" in nombre_norm:
                return True
        return False

    for s in subgrupos_catalogo:
        nombre = str(s.get("nombre") or "").lower()
        nombre_norm = _normalizar_texto(nombre)
        sid = s.get("id")
        if sid is None:
            continue
        for patron in restriccion.patrones_subgrupo:
            patron_norm = _normalizar_texto(patron)
            if patron_norm in nombre_norm and not _excluir_falso_positivo(nombre_norm, patron_norm):
                ids.add(int(sid))
                break
    return sorted(ids)


def _resolver_ingredientes_ids_para_catalogo(
    restriccion: RestriccionAlimentaria,
    ingredientes_catalogo: list[dict] | None = None,
) -> list[int]:
    ids = set(restriccion.ingredientes_ids)
    if not ingredientes_catalogo:
        return sorted(ids)

    for i in ingredientes_catalogo:
        nombre = str(i.get("nombre") or "").lower()
        iid = i.get("id")
        if iid is None:
            continue
        for patron in restriccion.patrones_ingrediente:
            if patron.lower() in nombre:
                ids.add(int(iid))
                break
    return sorted(ids)


def catalogo_restricciones(
    subgrupos_catalogo: list[dict] | None = None,
    ingredientes_catalogo: list[dict] | None = None,
) -> list[dict]:
    return [
        {
            "codigo": r.codigo,
            "nombre": r.nombre,
            "ids_subgrupos": _resolver_subgrupos_ids_para_catalogo(r, subgrupos_catalogo),
            "ids_ingredientes": _resolver_ingredientes_ids_para_catalogo(r, ingredientes_catalogo),
            "etiquetas_bloqueadas": list(r.etiquetas_bloqueadas),
            "etiquetas_positivas": list(r.etiquetas_positivas),
        }
        for r in RESTRICCIONES_ALIMENTARIAS.values()
    ]
