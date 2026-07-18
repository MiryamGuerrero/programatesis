from functools import lru_cache
from typing import Any, Dict, Optional

from app.domain.servicios.servicio_oms import ServicioOMS as ServicioOMSBase
from app.infraestructura.database.db import db_cursor


class ServicioOMS(ServicioOMSBase):
    @staticmethod
    @lru_cache(maxsize=1)
    def _todas_referencias() -> tuple[tuple[Any, ...], ...]:
        """Carga las referencias OMS una sola vez por proceso.

        Las referencias OMS son datos estaticos. Mantenerlas en memoria evita una
        consulta remota por indicador para cada control historico del paciente.
        """
        with db_cursor() as cur:
            cur.execute(
                """
                select id, ref_code, sexo, edad_meses::float, edad_dias,
                       medida_cm::float, l::float, m::float, s::float, sd0::float
                from referencia.oms_referencia_zscore
                order by id
                """
            )
            return tuple(cur.fetchall())

    @staticmethod
    @lru_cache(maxsize=1)
    def _todas_reglas_clasificacion() -> tuple[tuple[Any, ...], ...]:
        with db_cursor() as cur:
            cur.execute(
                """
                select ref_code, diagnostico, condicion_id, grupo_diagnostico,
                       edad_meses_min, edad_meses_max,
                       z_min::float, z_max::float, incluye_min, incluye_max
                from referencia.oms_clasificacion_zscore
                order by ref_code, grupo_diagnostico, edad_meses_min,
                         edad_meses_max, z_min nulls first,
                         z_max nulls last
                """
            )
            return tuple(cur.fetchall())

    @staticmethod
    @lru_cache(maxsize=16)
    def _referencias(indicador: str, sexo: str) -> tuple[tuple[Any, ...], ...]:
        return tuple(
            row
            for row in ServicioOMS._todas_referencias()
            if row[1] == indicador and row[2] == sexo
        )

    @staticmethod
    @lru_cache(maxsize=24)
    def _reglas_clasificacion(
        indicador: str, grupo: str
    ) -> tuple[tuple[Any, ...], ...]:
        return tuple(
            row[1:]
            for row in ServicioOMS._todas_reglas_clasificacion()
            if row[0] == indicador and row[3] == grupo
        )

    @staticmethod
    def _clasificar_por_regla(indicador: str, z_score: float, edad_meses: int) -> Dict[str, Any]:
        grupo = "talla" if indicador in {"LHFA", "HFA"} else ("peso_alerta" if indicador == "WFA" else "peso")
        for row in ServicioOMS._reglas_clasificacion(indicador, grupo):
            diagnostico, condicion_id, grupo_regla, edad_min, edad_max, z_min, z_max, incluye_min, incluye_max = row
            if not (edad_min <= edad_meses <= edad_max):
                continue
            cumple_min = z_min is None or (z_score >= z_min if incluye_min else z_score > z_min)
            cumple_max = z_max is None or (z_score <= z_max if incluye_max else z_score < z_max)
            if cumple_min and cumple_max:
                return {
                    "diagnostico": diagnostico,
                    "id_condicion": condicion_id,
                    "grupo": grupo_regla,
                }

        return {"diagnostico": "Sin clasificacion disponible", "id_condicion": None, "grupo": grupo}

    @staticmethod
    def _rango_referencia(indicador: str, sexo: str, campo: str) -> tuple[Optional[float], Optional[float]]:
        # Validacion de seguridad para evitar inyeccion via identificadores de columna
        columnas_permitidas = {"medida_cm", "edad_dias", "edad_meses"}
        if campo not in columnas_permitidas:
            raise ValueError(f"Campo no permitido para referencia OMS: {campo}")

        indice = {"edad_meses": 3, "edad_dias": 4, "medida_cm": 5}[campo]
        valores = [
            float(row[indice])
            for row in ServicioOMS._referencias(indicador, sexo)
            if row[indice] is not None
        ]
        return (min(valores), max(valores)) if valores else (None, None)

    @classmethod
    def obtener_referencia(
        cls,
        indicador: str,
        sexo: str,
        *,
        edad_meses: int,
        edad_dias: int,
        medida_cm: Optional[float] = None,
    ) -> Optional[Dict[str, Any]]:
        if indicador in {"WFL", "WFH"}:
            if medida_cm is None:
                raise ValueError(f"{indicador} requiere longitud/talla en cm")
            indice = 5
            objetivo = float(medida_cm)
        elif indicador == "LHFA":
            indice = 4
            objetivo = float(edad_dias)
        else:
            indice = 3
            objetivo = float(edad_meses)

        candidatas = (
            row
            for row in cls._referencias(indicador, sexo)
            if row[indice] is not None
        )
        row = min(candidatas, key=lambda item: abs(float(item[indice]) - objetivo), default=None)

        if not row:
            return None
        return {
            "id": row[0],
            "ref_code": row[1],
            "sexo": row[2],
            "edad_meses": row[3],
            "edad_dias": row[4],
            "medida_cm": row[5],
            "l": row[6],
            "m": row[7],
            "s": row[8],
            "sd0": row[9],
            "distancia": abs(float(row[indice]) - objetivo),
        }
