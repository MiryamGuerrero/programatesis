from typing import List, Optional
from ...core.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioNutricion

class RepositorioNutricionPostgres(IRepositorioNutricion):
    def listar_variables(self, q: str = None, limit: int = 200) -> List[dict]:
        with db_cursor() as cur:
            term = f"%{q}%" if q else "%"
            sql = """
                select * from nutricion.variable_nutricional
                where (codigo ilike %s or nombre_visible ilike %s)
                order by categoria_funcional nulls last, nombre_visible
                limit %s
            """
            cur.execute(sql, (term, term, limit))
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]

    def obtener_variable_por_codigo(self, codigo: str) -> Optional[dict]:
        with db_cursor() as cur:
            cur.execute(
                "select id, tipo_dato from nutricion.variable_nutricional where lower(codigo) = lower(%s) limit 1",
                (codigo.strip(),)
            )
            row = cur.fetchone()
            return {"id": row[0], "tipo_dato": row[1]} if row else None

    def upsert_definicion_variable(self, data: dict) -> int:
        with db_cursor() as cur:
            cur.execute(
                "select id from nutricion.variable_nutricional where lower(codigo) = lower(%s)",
                (data["codigo"].strip(),)
            )
            row = cur.fetchone()
            
            if row:
                var_id = row[0]
                keys = [k for k in data.keys() if k != "codigo"]
                set_clause = ", ".join([f"{k} = %s" for k in keys])
                sql = f"update nutricion.variable_nutricional set {set_clause}, updated_at = now() where id = %s"
                cur.execute(sql, [data[k] for k in keys] + [var_id])
                return var_id
            else:
                columns = ", ".join(data.keys())
                placeholders = ", ".join(["%s"] * len(data))
                sql = f"insert into nutricion.variable_nutricional ({columns}, activo) values ({placeholders}, true) returning id"
                cur.execute(sql, list(data.values()))
                return cur.fetchone()[0]

    def upsert_valor_variable(self, data: dict, actualizado_por: str) -> None:
        with db_cursor() as cur:
            if "id_variable_nutricional" not in data:
                found = self.obtener_variable_por_codigo(data["variable_codigo"])
                if not found: raise ValueError(f"Variable {data['variable_codigo']} no existe")
                data["id_variable_nutricional"] = found["id"]

            sql = """
                insert into nutricion.ingrediente_variable_valor (
                    id_ingrediente, id_variable_nutricional, 
                    valor_numerico, valor_texto, valor_booleano,
                    estado_dato, origen_asignacion, justificacion,
                    actualizado_por, updated_at
                ) values (%s, %s, %s, %s, %s, %s, %s, %s, %s, now())
                on conflict (id_ingrediente, id_variable_nutricional)
                do update set
                    valor_numerico = excluded.valor_numerico,
                    valor_texto = excluded.valor_texto,
                    valor_booleano = excluded.valor_booleano,
                    estado_dato = excluded.estado_dato,
                    origen_asignacion = excluded.origen_asignacion,
                    justificacion = excluded.justificacion,
                    actualizado_por = excluded.actualizado_por,
                    updated_at = now()
            """
            cur.execute(sql, (
                data["id_ingrediente"], data["id_variable_nutricional"],
                data.get("valor_numerico"), data.get("valor_texto"), data.get("valor_booleano"),
                data.get("estado_dato", "valor_real"), data.get("origen_asignacion", "manual"),
                data.get("justificacion"), actualizado_por
            ))
