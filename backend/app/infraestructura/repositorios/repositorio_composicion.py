from typing import List, Optional
from ...core.db import db_cursor


class RepositorioComposicionPostgres:

    # ---- MOMENTOS DE COMIDA ----

    def listar_momentos(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("""
                SELECT id, nombre, orden, hora_inicio, hora_fin,
                       obligatorio, activo, color
                FROM nutricion.momento_comida
                ORDER BY orden
            """)
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]

    def obtener_momento(self, id_momento: int) -> Optional[dict]:
        with db_cursor() as cur:
            cur.execute("""
                SELECT id, nombre, orden, hora_inicio, hora_fin,
                       obligatorio, activo, color
                FROM nutricion.momento_comida WHERE id = %s
            """, (id_momento,))
            r = cur.fetchone()
            if not r: return None
            cols = [d[0] for d in cur.description]
            return dict(zip(cols, r))

    def crear_momento(self, datos: dict) -> int:
        with db_cursor() as cur:
            cur.execute("""
                INSERT INTO nutricion.momento_comida
                    (nombre, orden, hora_inicio, hora_fin, obligatorio, activo, color)
                VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING id
            """, (
                datos["nombre"], datos.get("orden", 0),
                datos.get("hora_inicio"), datos.get("hora_fin"),
                datos.get("obligatorio", False),
                datos.get("activo", True),
                datos.get("color", "#4CAF50")
            ))
            return cur.fetchone()[0]

    def actualizar_momento(self, id_momento: int, datos: dict) -> bool:
        campos, vals = [], []
        for k in ("nombre","orden","hora_inicio","hora_fin","obligatorio","activo","color"):
            if k in datos:
                campos.append(f"{k} = %s"); vals.append(datos[k])
        if not campos: return False
        vals.append(id_momento)
        with db_cursor() as cur:
            cur.execute(f"UPDATE nutricion.momento_comida SET {', '.join(campos)}, updated_at = now() WHERE id = %s", tuple(vals))
            return cur.rowcount > 0

    def eliminar_momento(self, id_momento: int) -> bool:
        with db_cursor() as cur:
            cur.execute("DELETE FROM nutricion.momento_comida WHERE id = %s", (id_momento,))
            return cur.rowcount > 0

    # ---- TIPOS DE PLATO ----

    def listar_tipos_plato(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("SELECT id, nombre FROM nutricion.tipo_plato ORDER BY id")
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]

    def obtener_tipo_plato(self, id_tipo: int) -> Optional[dict]:
        with db_cursor() as cur:
            cur.execute("SELECT id, nombre FROM nutricion.tipo_plato WHERE id = %s", (id_tipo,))
            r = cur.fetchone()
            if not r: return None
            cols = [d[0] for d in cur.description]
            return dict(zip(cols, r))

    def crear_tipo_plato(self, nombre: str) -> int:
        with db_cursor() as cur:
            cur.execute("INSERT INTO nutricion.tipo_plato (nombre) VALUES (%s) RETURNING id", (nombre.upper().strip(),))
            return cur.fetchone()[0]

    def actualizar_tipo_plato(self, id_tipo: int, nombre: str) -> bool:
        with db_cursor() as cur:
            cur.execute("UPDATE nutricion.tipo_plato SET nombre = %s WHERE id = %s", (nombre.upper().strip(), id_tipo))
            return cur.rowcount > 0

    def eliminar_tipo_plato(self, id_tipo: int) -> bool:
        with db_cursor() as cur:
            cur.execute("DELETE FROM nutricion.tipo_plato WHERE id = %s", (id_tipo,))
            return cur.rowcount > 0

    # ---- REGLAS GENERALES DE COMPOSICIÓN (regla_momento_comida) ----

    def listar_reglas_generales(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("""
                SELECT r.id, r.id_momento, m.nombre as momento_nombre,
                       r.min_principales, r.max_principales,
                       r.permite_complementos, r.max_complementos_total, r.activo
                FROM nutricion.regla_momento_comida r
                JOIN nutricion.momento_comida m ON m.id = r.id_momento
                ORDER BY m.orden
            """)
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]

    def obtener_regla_general(self, id_regla: int) -> Optional[dict]:
        with db_cursor() as cur:
            cur.execute("""
                SELECT r.id, r.id_momento, m.nombre as momento_nombre,
                       r.min_principales, r.max_principales,
                       r.permite_complementos, r.max_complementos_total, r.activo
                FROM nutricion.regla_momento_comida r
                JOIN nutricion.momento_comida m ON m.id = r.id_momento
                WHERE r.id = %s
            """, (id_regla,))
            r = cur.fetchone()
            if not r: return None
            cols = [d[0] for d in cur.description]
            return dict(zip(cols, r))

    def obtener_regla_general_por_momento(self, id_momento: int) -> Optional[dict]:
        with db_cursor() as cur:
            cur.execute("""
                SELECT r.id, r.id_momento, m.nombre as momento_nombre,
                       r.min_principales, r.max_principales,
                       r.permite_complementos, r.max_complementos_total, r.activo
                FROM nutricion.regla_momento_comida r
                JOIN nutricion.momento_comida m ON m.id = r.id_momento
                WHERE r.id_momento = %s
            """, (id_momento,))
            r = cur.fetchone()
            if not r: return None
            cols = [d[0] for d in cur.description]
            return dict(zip(cols, r))

    def crear_regla_general(self, datos: dict) -> int:
        with db_cursor() as cur:
            cur.execute("""
                INSERT INTO nutricion.regla_momento_comida
                    (id_momento, min_principales, max_principales, permite_complementos, max_complementos_total, activo)
                VALUES (%s,%s,%s,%s,%s,%s)
                ON CONFLICT (id_momento) DO UPDATE SET
                    min_principales = EXCLUDED.min_principales,
                    max_principales = EXCLUDED.max_principales,
                    permite_complementos = EXCLUDED.permite_complementos,
                    max_complementos_total = EXCLUDED.max_complementos_total,
                    activo = EXCLUDED.activo,
                    updated_at = now()
                RETURNING id
            """, (
                datos["id_momento"],
                datos.get("min_principales", 1),
                datos.get("max_principales", 1),
                datos.get("permite_complementos", True),
                datos.get("max_complementos_total"),
                datos.get("activo", True)
            ))
            return cur.fetchone()[0]

    def actualizar_regla_general(self, id_regla: int, datos: dict) -> bool:
        campos, vals = [], []
        for k in ("id_momento","min_principales","max_principales","permite_complementos","max_complementos_total","activo"):
            if k in datos:
                campos.append(f"{k} = %s"); vals.append(datos[k])
        if not campos: return False
        vals.append(id_regla)
        with db_cursor() as cur:
            cur.execute(f"UPDATE nutricion.regla_momento_comida SET {', '.join(campos)}, updated_at = now() WHERE id = %s", tuple(vals))
            return cur.rowcount > 0

    def eliminar_regla_general(self, id_regla: int) -> bool:
        with db_cursor() as cur:
            cur.execute("DELETE FROM nutricion.regla_momento_comida WHERE id = %s", (id_regla,))
            return cur.rowcount > 0

    # ---- TIPOS PERMITIDOS POR MOMENTO (regla_momento_tipo_receta) ----

    def listar_tipos_permitidos(self, id_regla_momento: Optional[int] = None) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                SELECT rt.id, rt.id_regla_momento, rm.id_momento,
                       m.nombre as momento_nombre,
                       rt.id_tipo_plato, tp.nombre as tipo_plato_nombre,
                       rt.rol_permitido, rt.minimo, rt.maximo,
                       rt.obligatorio, rt.orden, rt.activo
                FROM nutricion.regla_momento_tipo_receta rt
                JOIN nutricion.regla_momento_comida rm ON rm.id = rt.id_regla_momento
                JOIN nutricion.momento_comida m ON m.id = rm.id_momento
                JOIN nutricion.tipo_plato tp ON tp.id = rt.id_tipo_plato
            """
            params = []
            if id_regla_momento is not None:
                sql += " WHERE rt.id_regla_momento = %s"
                params.append(id_regla_momento)
            sql += " ORDER BY m.orden, rt.rol_permitido DESC, rt.orden, tp.nombre"
            cur.execute(sql, tuple(params))
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]

    def obtener_tipo_permitido(self, id: int) -> Optional[dict]:
        with db_cursor() as cur:
            cur.execute("""
                SELECT rt.id, rt.id_regla_momento, rm.id_momento,
                       m.nombre as momento_nombre,
                       rt.id_tipo_plato, tp.nombre as tipo_plato_nombre,
                       rt.rol_permitido, rt.minimo, rt.maximo,
                       rt.obligatorio, rt.orden, rt.activo
                FROM nutricion.regla_momento_tipo_receta rt
                JOIN nutricion.regla_momento_comida rm ON rm.id = rt.id_regla_momento
                JOIN nutricion.momento_comida m ON m.id = rm.id_momento
                JOIN nutricion.tipo_plato tp ON tp.id = rt.id_tipo_plato
                WHERE rt.id = %s
            """, (id,))
            r = cur.fetchone()
            if not r: return None
            cols = [d[0] for d in cur.description]
            return dict(zip(cols, r))

    def crear_tipo_permitido(self, datos: dict) -> int:
        with db_cursor() as cur:
            cur.execute("""
                INSERT INTO nutricion.regla_momento_tipo_receta
                    (id_regla_momento, id_tipo_plato, rol_permitido, minimo, maximo, obligatorio, orden, activo)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (id_regla_momento, id_tipo_plato, rol_permitido)
                DO UPDATE SET
                    minimo = EXCLUDED.minimo, maximo = EXCLUDED.maximo,
                    obligatorio = EXCLUDED.obligatorio, orden = EXCLUDED.orden,
                    activo = EXCLUDED.activo, updated_at = now()
                RETURNING id
            """, (
                datos["id_regla_momento"], datos["id_tipo_plato"],
                datos["rol_permitido"], datos.get("minimo", 0),
                datos.get("maximo", 1), datos.get("obligatorio", False),
                datos.get("orden", 0), datos.get("activo", True)
            ))
            return cur.fetchone()[0]

    def actualizar_tipo_permitido(self, id: int, datos: dict) -> bool:
        campos, vals = [], []
        for k in ("id_regla_momento","id_tipo_plato","rol_permitido","minimo","maximo","obligatorio","orden","activo"):
            if k in datos:
                campos.append(f"{k} = %s"); vals.append(datos[k])
        if not campos: return False
        vals.append(id)
        with db_cursor() as cur:
            cur.execute(f"UPDATE nutricion.regla_momento_tipo_receta SET {', '.join(campos)}, updated_at = now() WHERE id = %s", tuple(vals))
            return cur.rowcount > 0

    def eliminar_tipo_permitido(self, id: int) -> bool:
        with db_cursor() as cur:
            cur.execute("DELETE FROM nutricion.regla_momento_tipo_receta WHERE id = %s", (id,))
            return cur.rowcount > 0

    # ---- MÉTODO COMPUESTO: devuelve la regla general + tipos permitidos ----

    def obtener_regla_completa_por_momento(self, id_momento: int) -> Optional[dict]:
        general = self.obtener_regla_general_por_momento(id_momento)
        if not general:
            return None
        tipos = self.listar_tipos_permitidos(id_regla_momento=general["id"])
        general["tipos_permitidos"] = tipos
        return general
