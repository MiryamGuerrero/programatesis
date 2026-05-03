from typing import List
from ...core.db import db_cursor
from ...domain.modelos.reglas import Regla, FuenteRegla, TipoAccion, TipoObjetivo
from ...domain.repositorios.interfaces import IRepositorioRegla

class RepositorioReglaPostgres(IRepositorioRegla):
    def obtener_reglas_por_condiciones(self, ids_condiciones: List[int]) -> List[Regla]:
        if not ids_condiciones: return []
        with db_cursor() as cur:
            sql = """
                select r.id, cr.id_condicion, r.origen_regla, a.codigo as accion_codigo, t.codigo as objetivo_codigo, 
                       r.id_ingrediente, r.id_grupo_alimentario, r.id_subgrupo_alimentario, r.id_etiqueta, r.id_receta,
                       r.mensaje_error
                from heuristico.regla r
                join heuristico.condicion_regla cr on cr.id_regla = r.id
                join heuristico.catalogo_accion a on a.id = r.id_accion
                join heuristico.catalogo_objetivo_regla t on t.id = r.id_tipo_objetivo
                where cr.id_condicion = any(%s)
            """
            cur.execute(sql, (ids_condiciones,))
            return [self._mapear_fila_a_regla(r) for r in cur.fetchall()]

    def obtener_alergias_por_paciente(self, id_paciente: str) -> List[Regla]:
        with db_cursor() as cur:
            reglas = []
            # 1. Alergias por ingrediente
            cur.execute("select id_ingrediente from clinico.alergia_paciente_ingrediente where id_paciente = %s and activa = true", (id_paciente,))
            for r in cur.fetchall():
                reglas.append(Regla(fuente=FuenteRegla.ALERGIA, accion=TipoAccion.ELIMINAR, tipo_objetivo=TipoObjetivo.INGREDIENTE, id_objetivo=r[0], prioridad=1000))
            
            # 2. Alergias por subgrupo
            cur.execute("select id_subgrupo_alimentario from clinico.alergia_paciente_subgrupo where id_paciente = %s and activa = true", (id_paciente,))
            for r in cur.fetchall():
                reglas.append(Regla(fuente=FuenteRegla.ALERGIA, accion=TipoAccion.ELIMINAR, tipo_objetivo=TipoObjetivo.SUBGRUPO, id_objetivo=r[0], prioridad=1000))
            
            return reglas

    def listar_reglas_detalladas(self) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                select 
                    r.id, r.id_accion, r.id_tipo_objetivo,
                    r.id_ingrediente, r.id_grupo_alimentario, r.id_subgrupo_alimentario, r.id_etiqueta,
                    r.mensaje_error, r.es_estricta,
                    a.codigo as accion_codigo, t.codigo as objetivo_codigo,
                    i.nombre as ingrediente_nombre, g.nombre as grupo_nombre, 
                    s.nombre as subgrupo_nombre, e.nombre_visible as etiqueta_nombre,
                    array_agg(cr.id_condicion) as id_condiciones
                from heuristico.regla r
                join heuristico.catalogo_accion a on a.id = r.id_accion
                join heuristico.catalogo_objetivo_regla t on t.id = r.id_tipo_objetivo
                left join heuristico.condicion_regla cr on cr.id_regla = r.id
                left join nutricion.ingrediente i on i.id = r.id_ingrediente
                left join nutricion.grupo_alimentario g on g.id = r.id_grupo_alimentario
                left join nutricion.subgrupo_alimentario s on s.id = r.id_subgrupo_alimentario
                left join nutricion.etiqueta_nutricional e on e.id = r.id_etiqueta
                group by r.id, a.codigo, t.codigo, i.nombre, g.nombre, s.nombre, e.nombre_visible
            """
            try:
                cur.execute(sql)
                columnas = [desc[0] for desc in cur.description]
                rows = cur.fetchall()
                return [dict(zip(columnas, row)) for row in rows]
            except Exception as e:
                print(f"!!! ERROR SQL REGLAS: {str(e)}")
                return []

    def guardar_regla(self, data: dict) -> int:
        with db_cursor() as cur:
            # 1. Insertar la regla base
            sql_regla = """
                insert into heuristico.regla (
                    id_accion, id_tipo_objetivo, mensaje_error, es_estricta,
                    id_ingrediente, id_grupo_alimentario, id_subgrupo_alimentario, id_etiqueta,
                    origen_regla
                ) values (%s, %s, %s, %s, %s, %s, %s, %s, 'CLINICA')
                returning id
            """
            cur.execute(sql_regla, (
                data["id_accion"], data["id_tipo_objetivo"], data.get("mensaje_error"), data.get("es_estricta", False),
                data.get("id_ingrediente"), data.get("id_grupo_alimentario"), data.get("id_subgrupo_alimentario"), data.get("id_etiqueta")
            ))
            id_regla = cur.fetchone()[0]

            # 2. Vincular con todas las condiciones enviadas
            if data.get("id_condiciones"):
                for id_cond in data["id_condiciones"]:
                    cur.execute("insert into heuristico.condicion_regla (id_regla, id_condicion) values (%s, %s)", (id_regla, id_cond))
            
            return id_regla

    def eliminar_regla(self, id_regla: int) -> bool:
        with db_cursor() as cur:
            # Limpiar tabla puente primero
            cur.execute("delete from heuristico.condicion_regla where id_regla = %s", (id_regla,))
            cur.execute("delete from heuristico.regla where id = %s", (id_regla,))
            return cur.rowcount > 0

    def _mapear_fila_a_regla(self, fila: tuple) -> Regla:
        # Fila: id, id_condicion, origen, accion_codigo, objetivo_codigo, id_ing, id_grp, id_sub, id_etq, id_rec, msg
        id_objetivo = fila[5] or fila[6] or fila[7] or fila[8] or fila[9]
        return Regla(
            id_regla=fila[0],
            fuente=fila[2],
            accion=fila[3],
            tipo_objetivo=fila[4],
            id_objetivo=id_objetivo,
            mensaje=fila[10]
        )
