from typing import List
from ...core.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioReceta

class RepositorioRecetaPostgres(IRepositorioReceta):
    def obtener_recetas_por_momento(self, id_momento: int) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                select r.id, r.nombre
                from nutricion.receta r
                join nutricion.receta_momento rm on rm.id_receta = r.id
                where rm.id_momento = %s and r.activa = true
            """
            cur.execute(sql, (id_momento,))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def listar_momentos_comida(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("select id, nombre from nutricion.momento_comida order by orden")
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]
