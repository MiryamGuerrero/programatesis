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
            "lacteos",
            "lácteos",
            "leches animales",
            "quesos frescos",
            "quesos procesados",
            "mantequillas",
        ),
        etiquetas_bloqueadas=("CONTIENE_LACTOSA",),
        etiquetas_positivas=("SIN_LACTOSA",),
    ),
    "ALERGIA_GLUTEN": RestriccionAlimentaria(
        codigo="ALERGIA_GLUTEN",
        nombre="Alergia/intolerancia al gluten",
        patrones_subgrupo=("con gluten",),
        patrones_ingrediente=("trigo", "cebada", "centeno", "cuscus", "cuscús", "pasta", "galleta"),
        etiquetas_bloqueadas=("CONTIENE_GLUTEN",),
        etiquetas_positivas=("SIN_GLUTEN",),
    ),
    "CELIAQUIA": RestriccionAlimentaria(
        codigo="CELIAQUIA",
        nombre="Celiaquia",
        patrones_subgrupo=("con gluten",),
        patrones_ingrediente=("trigo", "cebada", "centeno", "cuscus", "cuscÃºs", "pasta", "galleta"),
        etiquetas_bloqueadas=("CONTIENE_GLUTEN",),
        etiquetas_positivas=("SIN_GLUTEN",),
    ),
    "INTOLERANCIA_FRUCTOSA": RestriccionAlimentaria(
        codigo="INTOLERANCIA_FRUCTOSA",
        nombre="Intolerancia a la fructosa",
        patrones_subgrupo=("frutas", "dulces", "azucares", "azÃºcares"),
        patrones_ingrediente=(
            "fructosa",
            "miel",
            "jarabe",
            "sirope",
            "manzana",
            "pera",
            "mango",
            "sandia",
            "sandÃ­a",
            "uva",
            "pasas",
            "higo",
            "datil",
            "dÃ¡til",
        ),
        etiquetas_bloqueadas=("ALTO_FRUCTOSA", "CONTIENE_FRUCTOSA"),
        etiquetas_positivas=("BAJO_FRUCTOSA", "SIN_FRUCTOSA"),
    ),
    "INTOLERANCIA_HISTAMINA": RestriccionAlimentaria(
        codigo="INTOLERANCIA_HISTAMINA",
        nombre="Intolerancia a la histamina",
        patrones_subgrupo=("quesos curados", "embutidos", "fermentad", "pescado"),
        patrones_ingrediente=(
            "queso curado",
            "parmesano",
            "embutido",
            "salami",
            "chorizo",
            "jamon",
            "jamÃ³n",
            "atun",
            "atÃºn",
            "sardina",
            "salmon",
            "salmÃ³n",
            "vinagre",
            "chucrut",
            "kefir",
            "kÃ©fir",
        ),
        etiquetas_bloqueadas=("ALTO_HISTAMINA", "FERMENTADO"),
        etiquetas_positivas=("BAJO_HISTAMINA",),
    ),
    "INTOLERANCIA_SORBITOL_SACAROSA": RestriccionAlimentaria(
        codigo="INTOLERANCIA_SORBITOL_SACAROSA",
        nombre="Intolerancia a sorbitol/sacarosa",
        patrones_subgrupo=("azucares", "azÃºcares", "dulces", "pasteleria", "pastelerÃ­a"),
        patrones_ingrediente=(
            "sorbitol",
            "sacarosa",
            "azucar",
            "azÃºcar",
            "caramelo",
            "mermelada",
            "dulce",
            "chicle",
            "manzana",
            "pera",
            "ciruela",
        ),
        etiquetas_bloqueadas=("CONTIENE_SORBITOL", "ALTO_SACAROSA", "ALTO_AZUCAR"),
        etiquetas_positivas=("SIN_SORBITOL", "BAJO_SACAROSA", "BAJO_AZUCAR"),
    ),
    "INTOLERANCIA_SULFITOS": RestriccionAlimentaria(
        codigo="INTOLERANCIA_SULFITOS",
        nombre="Intolerancia a sulfitos",
        patrones_subgrupo=("frutos secos", "procesad", "conserva"),
        patrones_ingrediente=(
            "sulfito",
            "vino",
            "pasas",
            "fruta deshidratada",
            "frutos secos",
            "conserva",
            "encurtido",
            "vinagre",
        ),
        etiquetas_bloqueadas=("CONTIENE_SULFITOS",),
        etiquetas_positivas=("SIN_SULFITOS",),
    ),
    "ALERGIA_HUEVO": RestriccionAlimentaria(
        codigo="ALERGIA_HUEVO",
        nombre="Alergia al huevo",
        patrones_subgrupo=("huevo",),
        patrones_ingrediente=("huevo", "clara", "yema", "mayonesa", "merengue"),
        etiquetas_bloqueadas=("CONTIENE_HUEVO",),
        etiquetas_positivas=("SIN_HUEVO",),
    ),
    "ALERGIA_SOJA": RestriccionAlimentaria(
        codigo="ALERGIA_SOJA",
        nombre="Alergia a la soja",
        patrones_subgrupo=("soja",),
        patrones_ingrediente=("soja", "tofu", "tempeh", "lecitina de soja"),
        etiquetas_bloqueadas=("CONTIENE_SOJA",),
        etiquetas_positivas=("SIN_SOJA",),
    ),
    "ALERGIA_FRUTOS_SECOS": RestriccionAlimentaria(
        codigo="ALERGIA_FRUTOS_SECOS",
        nombre="Alergia a frutos secos",
        patrones_subgrupo=("frutos secos",),
        patrones_ingrediente=("almendra", "nuez", "mani", "maní", "cacahuete", "avellana", "pistacho"),
        etiquetas_bloqueadas=("CONTIENE_FRUTOS_SECOS",),
        etiquetas_positivas=("SIN_FRUTOS_SECOS",),
    ),
    "ALERGIA_PESCADO_MARISCOS": RestriccionAlimentaria(
        codigo="ALERGIA_PESCADO_MARISCOS",
        nombre="Alergia a pescado o mariscos",
        patrones_subgrupo=("pescado", "marisco", "crustaceo", "crustáceo", "molusco"),
        etiquetas_bloqueadas=("CONTIENE_PESCADO", "CONTIENE_MARISCOS"),
        etiquetas_positivas=("SIN_PESCADO", "SIN_MARISCOS"),
    ),
    "DIABETES": RestriccionAlimentaria(
        codigo="DIABETES",
        nombre="Diabetes",
        patrones_subgrupo=(
            "azucares",
            "azúcares",
            "dulces",
            "pasteleria",
            "pastelería",
            "chocolates con leche",
            "dulces con lacteos",
            "dulces con lácteos",
        ),
        patrones_ingrediente=(
            "azucar",
            "azúcar",
            "panela",
            "miel",
            "jarabe",
            "sirope",
            "caramelo",
            "mermelada",
            "dulce de leche",
            "gaseosa",
            "refresco",
            "chocolate blanco",
            "chocolate con leche",
        ),
        etiquetas_bloqueadas=("ALTO_AZUCAR", "NO_APTO_DIABETICOS"),
        etiquetas_positivas=("APTO_DIABETICOS", "BAJO_AZUCAR", "SIN_AZUCAR_ANADIDA", "CARBOHIDRATO_CONTROLADO"),
    ),
}


def normalizar_codigos_restriccion(codigos: Iterable[str] | None) -> set[str]:
    if not codigos:
        return set()
    return {
        str(codigo).strip().upper()
        for codigo in codigos
        if str(codigo).strip().upper() in RESTRICCIONES_ALIMENTARIAS
    }


def catalogo_restricciones() -> list[dict[str, str]]:
    return [
        {"codigo": r.codigo, "nombre": r.nombre}
        for r in RESTRICCIONES_ALIMENTARIAS.values()
    ]
