from typing import List, Dict, Set
from ...core.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioIngrediente

# Subgrupos que contienen lactosa (para deteccion automatica de intolerancia)
SUBGRUPOS_CON_LACTOSA: Set[int] = {
    98,   # Leches animales (con lactosa)
    100,  # Natas y cremas de leche (con lactosa)
    101,  # Yogures animales (con lactosa)
    104,  # Leches fermentadas animales (con lactosa)
    105,  # Quesos frescos (con lactosa)
    108,  # Quesos procesados y en lonchas (con lactosa)
    111,  # Mantequillas (lacteo, con lactosa)
    114,  # Salsas con lacteos (con lactosa)
    117,  # Chocolates con leche (con lactosa)
    119,  # Dulces con lacteos (con lactosa)
}

class RepositorioIngredientePostgres(IRepositorioIngrediente):
    def listar_todos_activos(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("select id, nombre, id_subgrupo_alimentario from nutricion.ingrediente where activo = true")
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def listar_ingredientes_admin(self, consulta: str = None, limite: int = 100, desplazamiento: int = 0, incluir_inactivos: bool = False) -> List[dict]:
        term = f"%{consulta}%" if consulta else "%"
        sql = """
            with etiquetas_agg as (
                select ie.id_ingrediente, array_agg(en.nombre_visible) as etiquetas
                from nutricion.ingrediente_etiqueta ie
                join nutricion.etiqueta_nutricional en on en.id = ie.id_etiqueta
                group by ie.id_ingrediente
            )
            select 
                i.*, 
                g.nombre as categoria, 
                sg.nombre as subgrupo,
                coalesce(ea.etiquetas, '{}') as etiquetas,
                coalesce(c.energia_kcal, 0) as energia_kcal,
                coalesce(c.proteinas_g, 0) as proteinas_g,
                coalesce(c.grasa_total_g, 0) as grasa_total_g,
                coalesce(c.hidratos_carbono_g, 0) as hidratos_carbono_g
            from nutricion.ingrediente i
            left join nutricion.grupo_alimentario g on g.id = i.id_grupo_alimentario
            left join nutricion.subgrupo_alimentario sg on sg.id = i.id_subgrupo_alimentario
            left join etiquetas_agg ea on ea.id_ingrediente = i.id
            left join nutricion.ingrediente_composicion c on c.id_ingrediente = i.id
            where (%s or i.activo = true) and (i.nombre ilike %s)
            order by i.nombre limit %s offset %s
        """
        with db_cursor() as cur:
            cur.execute(sql, (incluir_inactivos, term, limite, desplazamiento))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def resolver_id_grupo(self, id_grupo: int | None, nombre: str | None) -> int | None:
        if id_grupo: return id_grupo
        if not nombre: return None
        with db_cursor() as cur:
            cur.execute("insert into nutricion.grupo_alimentario (nombre) values (%s) on conflict (nombre) do update set nombre = excluded.nombre returning id", (nombre.strip(),))
            return cur.fetchone()[0]

    def resolver_id_subgrupo(self, id_grupo: int | None, id_subgrupo: int | None, nombre: str | None) -> int | None:
        if id_subgrupo: return id_subgrupo
        if not id_grupo or not nombre: return None
        with db_cursor() as cur:
            cur.execute("insert into nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre) values (%s, %s) on conflict (id_grupo_alimentario, nombre) do update set nombre = excluded.nombre returning id", (id_grupo, nombre.strip()))
            return cur.fetchone()[0]

    def crear_ingrediente(self, datos: dict) -> int:
        columnas = ", ".join(datos.keys())
        marcadores = ", ".join(["%s"] * len(datos))
        sql = f"insert into nutricion.ingrediente ({columnas}) values ({marcadores}) returning id"
        with db_cursor() as cur:
            cur.execute(sql, list(datos.values()))
            return cur.fetchone()[0]

    def obtener_ingrediente(self, id_ingrediente: int) -> dict | None:
        sql = """
            select 
                i.*, 
                g.nombre as grupo_nombre, 
                sg.nombre as subgrupo_nombre,
                coalesce(c.energia_kcal, 0) as energia_kcal,
                coalesce(c.proteinas_g, 0) as proteinas_g,
                coalesce(c.grasa_total_g, 0) as grasa_total_g,
                coalesce(c.hidratos_carbono_g, 0) as hidratos_carbono_g
            from nutricion.ingrediente i
            left join nutricion.grupo_alimentario g on g.id = i.id_grupo_alimentario
            left join nutricion.subgrupo_alimentario sg on sg.id = i.id_subgrupo_alimentario
            left join nutricion.ingrediente_composicion c on c.id_ingrediente = i.id
            where i.id = %s
        """
        with db_cursor() as cur:
            cur.execute(sql, (id_ingrediente,))
            row = cur.fetchone()
            if not row: return None
            columnas = [desc[0] for desc in cur.description]
            return dict(zip(columnas, row))

    def obtener_mapa_etiquetas_ingrediente(self) -> Dict[int, Set[int]]:
        with db_cursor() as cur:
            cur.execute("select id_ingrediente, id_etiqueta from nutricion.ingrediente_etiqueta")
            mapa: Dict[int, Set[int]] = {}
            for row in cur.fetchall():
                id_ing, id_eti = row
                if id_ing not in mapa: mapa[id_ing] = set()
                mapa[id_ing].add(id_eti)
            return mapa

    def obtener_mapa_ingredientes_receta(self) -> Dict[int, Set[int]]:
        with db_cursor() as cur:
            cur.execute("select id_receta, id_ingrediente from nutricion.receta_ingrediente")
            mapa: Dict[int, Set[int]] = {}
            for row in cur.fetchall():
                id_rec, id_ing = row
                if id_rec not in mapa: mapa[id_rec] = set()
                mapa[id_rec].add(id_ing)
            return mapa

    def buscar_ingredientes_filtrados(self, id_paciente: str, consulta: str = None, limite: int = 50) -> List[dict]:
        """
        Busca ingredientes aplicando filtros de alergias del paciente.
        
        Logica de bloqueo:
        1. Ingredientes individuales prohibidos (alergia_paciente_ingrediente)
        2. Subgrupos prohibidos (alergia_paciente_subgrupo)
        3. Si el paciente tiene algun subgrupo con lactosa prohibido -> intolerante
           -> se bloquean TODOS los subgrupos con lactosa automaticamente
        """
        with db_cursor() as cur:
            # 1. Obtener IDs de ingredientes y subgrupos prohibidos
            cur.execute(
                "select id_ingrediente from clinico.alergia_paciente_ingrediente where id_paciente = %s and activa = true",
                (id_paciente,)
            )
            ing_prohibidos = {r[0] for r in cur.fetchall()}

            cur.execute(
                "select id_subgrupo_alimentario from clinico.alergia_paciente_subgrupo where id_paciente = %s and activa = true",
                (id_paciente,)
            )
            sub_prohibidos = {r[0] for r in cur.fetchall()}

            # 2. Detectar intolerancia a la lactosa:
            # Si el paciente tiene prohibido CUALQUIER subgrupo con lactosa,
            # consideramos que es intolerante y bloqueamos TODOS los subgrupos con lactosa
            es_intolerante_lactosa = bool(sub_prohibidos & SUBGRUPOS_CON_LACTOSA)

            if es_intolerante_lactosa:
                # Ampliar prohibicion a todos los subgrupos con lactosa
                sub_prohibidos |= SUBGRUPOS_CON_LACTOSA

            # 3. Consulta principal con exclusion por subgrupo e ingrediente y busqueda por sinonimos
            term = f"%{consulta}%" if consulta else "%"
            safe_ing = list(ing_prohibidos) if ing_prohibidos else [0]
            safe_sub = list(sub_prohibidos) if sub_prohibidos else [0]

            sql = """
                select i.id, i.nombre, sg.nombre as subgrupo, i.id_subgrupo_alimentario
                from nutricion.ingrediente i
                left join nutricion.subgrupo_alimentario sg on sg.id = i.id_subgrupo_alimentario
                where i.activo = true
                  and (
                    i.nombre ilike %s 
                    or exists (
                        select 1 from unnest(i.sinonimos) s where s ilike %s
                    )
                  )
                  and i.id != all(%s)
                  and (i.id_subgrupo_alimentario is null or i.id_subgrupo_alimentario != all(%s))
                order by i.nombre
                limit %s
            """

            cur.execute(sql, (term, term, safe_ing, safe_sub, limite))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]
