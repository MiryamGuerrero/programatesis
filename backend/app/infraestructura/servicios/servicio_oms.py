from typing import Any, Dict, Optional

from app.domain.servicios.servicio_oms import ServicioOMS as ServicioOMSBase
from app.infraestructura.database.db import db_cursor


class ServicioOMS(ServicioOMSBase):
    @staticmethod
    def _clasificar_por_regla(indicador: str, z_score: float, edad_meses: int) -> Dict[str, Any]:
        grupo = "talla" if indicador in {"LHFA", "HFA"} else ("peso_alerta" if indicador == "WFA" else "peso")
        with db_cursor() as cur:
            cur.execute(
                """
                select diagnostico, condicion_id, grupo_diagnostico
                from referencia.oms_clasificacion_zscore
                where ref_code = %s
                  and edad_meses_min <= %s
                  and edad_meses_max >= %s
                  and grupo_diagnostico = %s
                  and (z_min is null or case when incluye_min then %s >= z_min else %s > z_min end)
                  and (z_max is null or case when incluye_max then %s <= z_max else %s < z_max end)
                limit 1
                """,
                (indicador, edad_meses, edad_meses, grupo, z_score, z_score, z_score, z_score),
            )
            row = cur.fetchone()

        if not row:
            return {"diagnostico": "Sin clasificacion disponible", "id_condicion": None, "grupo": grupo}
        return {"diagnostico": row[0], "id_condicion": row[1], "grupo": row[2]}

    @staticmethod
    def _rango_referencia(indicador: str, sexo: str, campo: str) -> tuple[Optional[float], Optional[float]]:
        with db_cursor() as cur:
            cur.execute(
                f"""
                select min({campo})::float, max({campo})::float
                from referencia.oms_referencia_zscore
                where ref_code = %s and sexo = %s and {campo} is not null
                """,
                (indicador, sexo),
            )
            row = cur.fetchone()
        return (row[0], row[1]) if row else (None, None)

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
        params: tuple[Any, ...]
        if indicador in {"WFL", "WFH"}:
            if medida_cm is None:
                raise ValueError(f"{indicador} requiere longitud/talla en cm")
            order_expr = "abs(medida_cm - %s)"
            where_expr = "medida_cm is not null"
            params = (medida_cm, indicador, sexo)
        elif indicador == "LHFA":
            order_expr = "abs(edad_dias - %s)"
            where_expr = "edad_dias is not null"
            params = (edad_dias, indicador, sexo)
        else:
            order_expr = "abs(edad_meses - %s)"
            where_expr = "edad_meses is not null"
            params = (edad_meses, indicador, sexo)

        with db_cursor() as cur:
            cur.execute(
                f"""
                select id, ref_code, sexo, edad_meses::float, edad_dias, medida_cm::float,
                       l::float, m::float, s::float, sd0::float, {order_expr}::float as distancia
                from referencia.oms_referencia_zscore
                where ref_code = %s and sexo = %s and {where_expr}
                order by distancia asc
                limit 1
                """,
                params,
            )
            row = cur.fetchone()

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
            "distancia": row[10],
        }
