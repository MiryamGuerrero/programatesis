import json
from typing import List, Optional
from app.infraestructura.database.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioComposicion


class RepositorioComposicionPostgres(IRepositorioComposicion):
    ROLES_COMBINACION = {
        "COMBINACION_LIGERA",
        "COMBINACION_EQUILIBRADA",
        "COMBINACION_ENERGETICA",
        "COMBINACION_RECUPERACION_NUTRICIONAL",
        "COMBINACION_SUAVE",
        "COMBINACION_COMPLEMENTARIA",
    }
    COMBINACIONES_LIGERAS_PROHIBIDAS = {
        tuple(sorted(["PLATO FUERTE", "COLADA"])),
        tuple(sorted(["ARROZ PREPARADO", "BATIDO"])),
        tuple(sorted(["PASTA SALUDABLE", "JUGO NATURAL"])),
        tuple(sorted(["PANCAKES SALUDABLES", "COLADA"])),
    }

    def _asegurar_tablas_reglas_menu(self, cur) -> None:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS nutricion.regla_menu_combinacion (
                id bigserial PRIMARY KEY,
                id_momento integer NOT NULL REFERENCES nutricion.momento_comida(id) ON DELETE CASCADE,
                rol text NOT NULL,
                platillos jsonb NOT NULL DEFAULT '[]'::jsonb,
                platillos_key text NOT NULL,
                activo boolean NOT NULL DEFAULT true,
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now(),
                UNIQUE (id_momento, rol, platillos_key)
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS nutricion.regla_menu_combinacion_condicion (
                id_regla_menu_combinacion bigint NOT NULL
                    REFERENCES nutricion.regla_menu_combinacion(id) ON DELETE CASCADE,
                id_condicion_nutricional integer NOT NULL
                    REFERENCES heuristico.condicion(id) ON DELETE RESTRICT,
                PRIMARY KEY (id_regla_menu_combinacion, id_condicion_nutricional)
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS nutricion.momento_tipo_plato_factible (
                id bigserial PRIMARY KEY,
                id_momento integer NOT NULL REFERENCES nutricion.momento_comida(id) ON DELETE CASCADE,
                id_tipo_plato integer NOT NULL REFERENCES nutricion.tipo_plato(id) ON DELETE CASCADE,
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now(),
                UNIQUE (id_momento, id_tipo_plato)
            )
        """)

    def obtener_configuracion_maestra(self, id_momento_inicial: Optional[int] = None) -> dict:
        """Obtiene todo el estado inicial del modulo en una sola consulta masiva."""
        with db_cursor() as cur:
            self._asegurar_tablas_reglas_menu(cur)
            
            # 1. Momentos
            cur.execute("SELECT id, nombre, orden, hora_inicio, hora_fin, obligatorio, activo, color FROM nutricion.momento_comida ORDER BY orden")
            momentos = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            # 2. Tipos de plato
            cur.execute("SELECT id, nombre FROM nutricion.tipo_plato ORDER BY nombre")
            tipos = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            # 3. Condiciones
            cur.execute("SELECT id, nombre FROM heuristico.condicion WHERE id_tipo_condicion = 3 ORDER BY nombre")
            condiciones = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            # 4. Todas las reglas inteligentes (Combinaciones clinicas)
            cur.execute("""
                SELECT r.id, r.id_momento, m.nombre AS momento_nombre, r.rol,
                       r.platillos, r.activo,
                       coalesce(
                         jsonb_agg(
                           jsonb_build_object('id', c.id, 'nombre', c.nombre)
                           ORDER BY c.nombre
                         ) FILTER (WHERE c.id IS NOT NULL),
                         '[]'::jsonb
                       ) AS condiciones_nutricionales
                FROM nutricion.regla_menu_combinacion r
                JOIN nutricion.momento_comida m ON m.id = r.id_momento
                LEFT JOIN nutricion.regla_menu_combinacion_condicion rc
                    ON rc.id_regla_menu_combinacion = r.id
                LEFT JOIN heuristico.condicion c
                    ON c.id = rc.id_condicion_nutricional
                GROUP BY r.id, m.nombre
                ORDER BY r.id_momento, r.rol, r.id
            """)
            todas_reglas = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            # 5. Regla especifica del momento inicial (Si aplica)
            regla_detalle = None
            if id_momento_inicial or momentos:
                mid = id_momento_inicial or momentos[0]["id"]
                regla_detalle = self.obtener_regla_completa_por_momento(mid)

            return {
                "momentos": momentos,
                "tipos_plato": tipos,
                "condiciones": condiciones,
                "todas_reglas": todas_reglas,
                "regla_detalle_inicial": regla_detalle
            }

    def _normalizar_texto(self, valor: str) -> str:
        return " ".join(str(valor).strip().upper().split())

    def _tabla_existe(self, cur, esquema: str, tabla: str) -> bool:
        cur.execute("SELECT to_regclass(%s)", (f"{esquema}.{tabla}",))
        return cur.fetchone()[0] is not None

    def _columna_existe(self, cur, esquema: str, tabla: str, columna: str) -> bool:
        cur.execute(
            """
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = %s
              AND table_name = %s
              AND column_name = %s
            LIMIT 1
            """,
            (esquema, tabla, columna),
        )
        return cur.fetchone() is not None

    def _obtener_momento_por_id_cur(self, cur, id_momento: int) -> Optional[dict]:
        cur.execute("SELECT id, nombre FROM nutricion.momento_comida WHERE id = %s", (id_momento,))
        row = cur.fetchone()
        return {"id": row[0], "nombre": row[1]} if row else None

    def _resolver_tipos_plato_existentes(self, cur, nombres: list) -> list[dict]:
        tipos = []
        for nombre in nombres:
            normalizado = self._normalizar_texto(nombre)
            if not normalizado:
                continue
            cur.execute(
                "SELECT id, nombre FROM nutricion.tipo_plato WHERE upper(nombre) = %s LIMIT 1",
                (normalizado,),
            )
            row = cur.fetchone()
            if not row:
                raise ValueError(f"Tipo de platillo no existe: {nombre}")
            tipos.append({"id": row[0], "nombre": row[1]})
        unicos = {tipo["id"]: tipo for tipo in tipos}
        return sorted(unicos.values(), key=lambda item: self._normalizar_texto(item["nombre"]))

    def _resolver_condiciones_existentes(self, cur, valores: list) -> list[dict]:
        condiciones = []
        for valor in valores:
            if isinstance(valor, int):
                cur.execute(
                    "SELECT id, nombre FROM heuristico.condicion WHERE id = %s AND id_tipo_condicion = 3 LIMIT 1",
                    (valor,),
                )
            else:
                cur.execute(
                    "SELECT id, nombre FROM heuristico.condicion WHERE upper(nombre) = %s AND id_tipo_condicion = 3 LIMIT 1",
                    (self._normalizar_texto(valor),),
                )
            row = cur.fetchone()
            if not row:
                raise ValueError(f"Condicion nutricional no existe: {valor}")
            condiciones.append({"id": row[0], "nombre": row[1]})
        unicas = {condicion["id"]: condicion for condicion in condiciones}
        return sorted(unicas.values(), key=lambda item: item["nombre"])

    def _validar_regla_menu(self, momento: dict, rol: str, tipos: list[dict], condiciones: list[dict]) -> None:
        if rol not in self.ROLES_COMBINACION:
            raise ValueError(f"Rol no permitido: {rol}")
        if len(condiciones) < 1:
            raise ValueError("Selecciona al menos una condicion nutricional")
        if len(tipos) < 2:
            raise ValueError("Cada combinacion debe tener minimo dos platillos")
        nombres = [self._normalizar_texto(tipo["nombre"]) for tipo in tipos]
        if self._normalizar_texto(momento["nombre"]) == "DESAYUNO" and "INFUSIÓN" in nombres:
            raise ValueError("Infusion no se permite en combinaciones de desayuno")
        if rol == "COMBINACION_LIGERA":
            clave = tuple(sorted(nombres))
            if clave in self.COMBINACIONES_LIGERAS_PROHIBIDAS:
                raise ValueError("La combinacion no es valida para COMBINACION_LIGERA")

    def obtener_todas_combinaciones_por_condiciones(self, ids_momentos: List[int], ids_condiciones: List[int]) -> List[dict]:
        """Trae todas las combinaciones aplicables para una lista de momentos y condiciones en una sola consulta."""
        if not ids_momentos or not ids_condiciones:
            return []
        with db_cursor() as cur:
            sql = """
                SELECT DISTINCT r.id, r.id_momento, r.platillos, r.rol
                FROM nutricion.regla_menu_combinacion r
                JOIN nutricion.regla_menu_combinacion_condicion rc ON rc.id_regla_menu_combinacion = r.id
                WHERE r.id_momento = ANY(%s) 
                  AND r.activo = true
                  AND rc.id_condicion_nutricional = ANY(%s)
            """
            cur.execute(sql, (ids_momentos, ids_condiciones))
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def obtener_combinaciones_por_condiciones(self, id_momento: int, ids_condiciones: List[int]) -> List[dict]:
        with db_cursor() as cur:
            self._asegurar_tablas_reglas_menu(cur)
            sql = """
                SELECT DISTINCT r.id, r.platillos, r.rol
                FROM nutricion.regla_menu_combinacion r
                JOIN nutricion.regla_menu_combinacion_condicion rc ON rc.id_regla_menu_combinacion = r.id
                WHERE r.id_momento = %s 
                  AND r.activo = true
                  AND rc.id_condicion_nutricional = ANY(%s)
            """
            cur.execute(sql, (id_momento, ids_condiciones))
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def _listar_reglas_menu(self, cur_where: str, params: tuple, limite: int = 12, offset: int = 0) -> dict:
        where_clause = f" {cur_where}" if cur_where.strip() else ""
        with db_cursor() as cur:
            self._asegurar_tablas_reglas_menu(cur)
            
            # 1. Total count
            cur.execute(f"SELECT count(*) FROM nutricion.regla_menu_combinacion r {where_clause}", params)
            total = cur.fetchone()[0]

            # 2. Paginated items
            sql = f"""
                SELECT r.id, r.id_momento, m.nombre AS momento_nombre, r.rol,
                       r.platillos, r.activo,
                       coalesce(
                         jsonb_agg(
                           jsonb_build_object('id', c.id, 'nombre', c.nombre)
                           ORDER BY c.nombre
                         ) FILTER (WHERE c.id IS NOT NULL),
                         '[]'::jsonb
                       ) AS condiciones_nutricionales
                FROM nutricion.regla_menu_combinacion r
                JOIN nutricion.momento_comida m ON m.id = r.id_momento
                LEFT JOIN nutricion.regla_menu_combinacion_condicion rc
                    ON rc.id_regla_menu_combinacion = r.id
                LEFT JOIN heuristico.condicion c
                    ON c.id = rc.id_condicion_nutricional
                {where_clause}
                GROUP BY r.id, m.nombre
                ORDER BY r.rol, r.id
                LIMIT %s OFFSET %s
            """
            cur.execute(sql, params + (limite, offset))
            cols = [d[0] for d in cur.description]
            items = [dict(zip(cols, row)) for row in cur.fetchall()]
            
            return {"items": items, "total": total}

    def listar_reglas_menu_combinacion(self, id_momento: int, limite: int = 12, offset: int = 0) -> dict:
        return self._listar_reglas_menu(
            cur_where="WHERE r.id_momento = %s", 
            params=(id_momento,),
            limite=limite,
            offset=offset
        )

    def listar_todas_reglas_menu_combinacion(self, limite: int = 12, offset: int = 0) -> dict:
        return self._listar_reglas_menu(
            cur_where="", 
            params=(),
            limite=limite,
            offset=offset
        )

    def _asignar_momento_a_recetas_por_tipos(self, cur, id_momento: int, tipos: list[dict]) -> int:
        """Auto-asigna un momento a recetas que tienen los tipos de plato de una regla."""
        if not tipos:
            return 0
        self._guardar_tipos_factibles_momento(cur, id_momento, tipos)
        self._inferir_tipos_en_recetas_sin_clasificar(cur, tipos)
        tipo_ids = [t["id"] for t in tipos]
        cur.execute("""
            INSERT INTO nutricion.receta_momento (id_receta, id_momento)
            SELECT DISTINCT rtp.id_receta, %s
            FROM nutricion.receta_tipo_plato rtp
            WHERE rtp.id_tipo_plato = ANY(%s)
            ON CONFLICT DO NOTHING
        """, (id_momento, tipo_ids))
        return cur.rowcount

    def _guardar_tipos_factibles_momento(self, cur, id_momento: int, tipos: list[dict]) -> None:
        tipo_ids = sorted({int(t["id"]) for t in tipos if t.get("id") is not None})
        if not tipo_ids:
            return
        cur.executemany(
            """
            INSERT INTO nutricion.momento_tipo_plato_factible (id_momento, id_tipo_plato, updated_at)
            VALUES (%s, %s, now())
            ON CONFLICT (id_momento, id_tipo_plato)
            DO UPDATE SET updated_at = now()
            """,
            [(id_momento, tid) for tid in tipo_ids],
        )

    def _recalcular_tipos_factibles_momento(self, cur, id_momento: int) -> None:
        cur.execute(
            "DELETE FROM nutricion.momento_tipo_plato_factible WHERE id_momento = %s",
            (id_momento,),
        )
        cur.execute(
            """
            INSERT INTO nutricion.momento_tipo_plato_factible (id_momento, id_tipo_plato, updated_at)
            SELECT DISTINCT r.id_momento, (p.value->>'id')::int as id_tipo_plato, now()
            FROM nutricion.regla_menu_combinacion r,
                 jsonb_array_elements(r.platillos) AS p(value)
            WHERE r.id_momento = %s
              AND r.activo = true
              AND (p.value->>'id') ~ '^[0-9]+$'
            ON CONFLICT (id_momento, id_tipo_plato)
            DO UPDATE SET updated_at = now()
            """,
            (id_momento,),
        )

    def _inferir_tipos_en_recetas_sin_clasificar(self, cur, tipos: list[dict]) -> None:
        """Vincula tipos de plato a recetas existentes cuando el nombre/descripcion coincide."""
        for tipo in tipos:
            nombre = self._normalizar_texto(tipo.get("nombre", ""))
            if not nombre:
                continue
            patron = f"%{nombre}%"
            cur.execute("""
                INSERT INTO nutricion.receta_tipo_plato (id_receta, id_tipo_plato)
                SELECT r.id, %s
                FROM nutricion.receta r
                WHERE (
                    upper(coalesce(r.nombre, '')) LIKE %s
                    OR upper(coalesce(r.descripcion, '')) LIKE %s
                    OR upper(coalesce(r.descripcion_larga, '')) LIKE %s
                )
                ON CONFLICT DO NOTHING
            """, (tipo["id"], patron, patron, patron))

    def importar_reglas_menu_combinacion(self, id_momento: int, combinaciones: list[dict]) -> dict:
        if not isinstance(combinaciones, list) or not combinaciones:
            raise ValueError("El JSON debe incluir combinaciones")
        with db_cursor() as cur:
            self._asegurar_tablas_reglas_menu(cur)
            momento = self._obtener_momento_por_id_cur(cur, id_momento)
            if not momento:
                raise ValueError("Momento de comida no encontrado")

            insertadas = 0
            omitidas = 0
            for item in combinaciones:
                rol = self._normalizar_texto(item.get("rol", ""))
                platillos = item.get("platillos", [])
                condiciones_raw = (
                    item.get("condiciones_nutricionales")
                    or item.get("orientacion_nutricional")
                    or item.get("condiciones")
                    or []
                )
                tipos = self._resolver_tipos_plato_existentes(cur, platillos)
                condiciones = self._resolver_condiciones_existentes(cur, condiciones_raw)
                self._validar_regla_menu(momento, rol, tipos, condiciones)

                platillos_payload = [{"id": tipo["id"], "nombre": tipo["nombre"]} for tipo in tipos]
                platillos_key = "|".join(str(tipo["id"]) for tipo in tipos)
                cur.execute("""
                    INSERT INTO nutricion.regla_menu_combinacion
                        (id_momento, rol, platillos, platillos_key, activo, updated_at)
                    VALUES (%s, %s, %s::jsonb, %s, true, now())
                    ON CONFLICT (id_momento, rol, platillos_key) DO NOTHING
                    RETURNING id
                """, (id_momento, rol, json.dumps(platillos_payload), platillos_key))
                row = cur.fetchone()
                if not row:
                    omitidas += 1
                    # Aun asi auto-asignar momento a recetas en caso de regla existente
                    self._asignar_momento_a_recetas_por_tipos(cur, id_momento, tipos)
                    continue
                regla_id = row[0]
                for condicion in condiciones:
                    cur.execute("""
                        INSERT INTO nutricion.regla_menu_combinacion_condicion
                            (id_regla_menu_combinacion, id_condicion_nutricional)
                        VALUES (%s, %s)
                        ON CONFLICT DO NOTHING
                    """, (regla_id, condicion["id"]))
                # Auto-asignar momento a recetas que usan estos tipos de plato
                self._asignar_momento_a_recetas_por_tipos(cur, id_momento, tipos)
                insertadas += 1
            return {"insertadas": insertadas, "omitidas": omitidas}

    def crear_regla_menu_combinacion(
        self,
        id_momento: int,
        rol: str,
        platillos_nombres: list[str],
        condiciones_ids: list[int],
    ) -> dict:
        """Crea o actualiza una combinacion unica.
        Si ya existe (mismo momento + mismo rol + mismos platillos),
        agrega las condiciones nuevas sin duplicar.
        """
        rol = rol.strip().upper()
        with db_cursor() as cur:
            self._asegurar_tablas_reglas_menu(cur)
            momento = self._obtener_momento_por_id_cur(cur, id_momento)
            if not momento:
                raise ValueError("Momento de comida no encontrado")
            tipos = self._resolver_tipos_plato_existentes(cur, platillos_nombres)
            condiciones = []
            for cid in condiciones_ids:
                cur.execute(
                    "SELECT id, nombre FROM heuristico.condicion WHERE id = %s AND id_tipo_condicion = 3 LIMIT 1",
                    (cid,),
                )
                row = cur.fetchone()
                if not row:
                    raise ValueError(f"Condicion nutricional no existe (id={cid})")
                condiciones.append({"id": row[0], "nombre": row[1]})
            self._validar_regla_menu(momento, rol, tipos, condiciones)
            platillos_payload = [{"id": t["id"], "nombre": t["nombre"]} for t in tipos]
            platillos_key = "|".join(str(t["id"]) for t in tipos)
            cur.execute(
                "SELECT id FROM nutricion.regla_menu_combinacion WHERE id_momento = %s AND rol = %s AND platillos_key = %s",
                (id_momento, rol, platillos_key),
            )
            existing = cur.fetchone()
            if existing:
                regla_id = existing[0]
                nuevas = 0
                for cond in condiciones:
                    cur.execute(
                        "SELECT 1 FROM nutricion.regla_menu_combinacion_condicion WHERE id_regla_menu_combinacion = %s AND id_condicion_nutricional = %s",
                        (regla_id, cond["id"]),
                    )
                    if not cur.fetchone():
                        cur.execute(
                            "INSERT INTO nutricion.regla_menu_combinacion_condicion (id_regla_menu_combinacion, id_condicion_nutricional) VALUES (%s, %s)",
                            (regla_id, cond["id"]),
                        )
                        nuevas += 1
                cur.execute(
                    "UPDATE nutricion.regla_menu_combinacion SET updated_at = now() WHERE id = %s",
                    (regla_id,),
                )
                # Auto-asignar momento a recetas que usan estos tipos de plato
                self._asignar_momento_a_recetas_por_tipos(cur, id_momento, tipos)
                return {"accion": "actualizada", "id": regla_id, "condiciones_agregadas": nuevas}
            cur.execute(
                "INSERT INTO nutricion.regla_menu_combinacion (id_momento, rol, platillos, platillos_key, activo, updated_at) VALUES (%s, %s, %s::jsonb, %s, true, now()) RETURNING id",
                (id_momento, rol, json.dumps(platillos_payload), platillos_key),
            )
            regla_id = cur.fetchone()[0]
            for cond in condiciones:
                cur.execute(
                    "INSERT INTO nutricion.regla_menu_combinacion_condicion (id_regla_menu_combinacion, id_condicion_nutricional) VALUES (%s, %s)",
                    (regla_id, cond["id"]),
                )
            # Auto-asignar momento a recetas que usan estos tipos de plato
            self._asignar_momento_a_recetas_por_tipos(cur, id_momento, tipos)
            return {"accion": "creada", "id": regla_id, "condiciones_agregadas": len(condiciones)}

    def eliminar_regla_menu_combinacion(self, id_regla: int) -> bool:
        with db_cursor() as cur:
            self._asegurar_tablas_reglas_menu(cur)
            cur.execute("SELECT id_momento FROM nutricion.regla_menu_combinacion WHERE id = %s", (id_regla,))
            row = cur.fetchone()
            cur.execute("DELETE FROM nutricion.regla_menu_combinacion WHERE id = %s", (id_regla,))
            exito = cur.rowcount > 0
            if exito and row:
                self._recalcular_tipos_factibles_momento(cur, int(row[0]))
            return exito

    def listar_tipos_factibles_por_momento(self, id_momento: int) -> List[dict]:
        with db_cursor() as cur:
            self._asegurar_tablas_reglas_menu(cur)
            cur.execute(
                """
                SELECT mtpf.id, mtpf.id_momento, mtpf.id_tipo_plato, tp.nombre as tipo_plato_nombre
                FROM nutricion.momento_tipo_plato_factible mtpf
                JOIN nutricion.tipo_plato tp ON tp.id = mtpf.id_tipo_plato
                WHERE mtpf.id_momento = %s
                ORDER BY tp.nombre
                """,
                (id_momento,),
            )
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]

    def _asegurar_unicidad_combinaciones(self, cur) -> None:
        cur.execute("""
            DO $$
            DECLARE
              constraint_name text;
            BEGIN
              FOR constraint_name IN
                SELECT c.conname
                FROM pg_constraint c
                JOIN pg_class t ON t.oid = c.conrelid
                JOIN pg_namespace n ON n.oid = t.relnamespace
                WHERE n.nspname = 'nutricion'
                  AND t.relname = 'regla_momento_tipo_receta'
                  AND c.contype = 'u'
                  AND pg_get_constraintdef(c.oid) ILIKE '%id_regla_momento%'
                  AND pg_get_constraintdef(c.oid) ILIKE '%id_tipo_plato%'
                  AND pg_get_constraintdef(c.oid) ILIKE '%rol_permitido%'
                  AND pg_get_constraintdef(c.oid) NOT ILIKE '%orden%'
              LOOP
                EXECUTE format(
                  'ALTER TABLE nutricion.regla_momento_tipo_receta DROP CONSTRAINT %I',
                  constraint_name
                );
              END LOOP;
            END $$;
        """)
        cur.execute("""
            DO $$
            BEGIN
              IF NOT EXISTS (
                SELECT 1
                FROM pg_constraint c
                JOIN pg_class t ON t.oid = c.conrelid
                JOIN pg_namespace n ON n.oid = t.relnamespace
                WHERE n.nspname = 'nutricion'
                  AND t.relname = 'regla_momento_tipo_receta'
                  AND c.conname = 'regla_momento_tipo_receta_combo_unique'
              ) THEN
                ALTER TABLE nutricion.regla_momento_tipo_receta
                  ADD CONSTRAINT regla_momento_tipo_receta_combo_unique
                  UNIQUE (id_regla_momento, id_tipo_plato, rol_permitido, orden);
              END IF;
            END $$;
        """)

    def _asignar_momentos_por_tipo_permitido(self, cur, id_regla_momento: int, id_tipo_plato: int) -> None:
        if not self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
            return
        cur.execute("SELECT id, nombre FROM nutricion.tipo_plato WHERE id = %s", (id_tipo_plato,))
        tipo = cur.fetchone()
        if tipo:
            self._inferir_tipos_en_recetas_sin_clasificar(
                cur,
                [{"id": tipo[0], "nombre": tipo[1]}],
            )
        cur.execute("""
            INSERT INTO nutricion.receta_momento (id_receta, id_momento)
            SELECT DISTINCT rtp.id_receta, rm.id_momento
            FROM nutricion.receta_tipo_plato rtp
            JOIN nutricion.regla_momento_comida rm ON rm.id = %s
            WHERE rtp.id_tipo_plato = %s
              AND rm.activo = true
            ON CONFLICT DO NOTHING
        """, (id_regla_momento, id_tipo_plato))

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
            if self._columna_existe(cur, "nutricion", "momento_comida", "updated_at"):
                sql = f"UPDATE nutricion.momento_comida SET {', '.join(campos)}, updated_at = now() WHERE id = %s"
            else:
                sql = f"UPDATE nutricion.momento_comida SET {', '.join(campos)} WHERE id = %s"
            cur.execute(sql, tuple(vals))
            return cur.rowcount > 0

    def eliminar_momento(self, id_momento: int) -> bool:
        with db_cursor() as cur:
            if self._tabla_existe(cur, "nutricion", "regla_momento_tipo_receta") and self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                cur.execute("""
                    DELETE FROM nutricion.regla_momento_tipo_receta rt
                    USING nutricion.regla_momento_comida rm
                    WHERE rt.id_regla_momento = rm.id
                      AND rm.id_momento = %s
                """, (id_momento,))
            if self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                cur.execute(
                    "DELETE FROM nutricion.regla_momento_comida WHERE id_momento = %s",
                    (id_momento,),
                )
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
        nombre = nombre.strip()
        if not nombre:
            raise ValueError("El nombre del tipo de plato es requerido")
        with db_cursor() as cur:
            cur.execute("INSERT INTO nutricion.tipo_plato (nombre) VALUES (%s) RETURNING id", (nombre.upper(),))
            return cur.fetchone()[0]

    def _obtener_o_crear_tipo_plato(self, cur, nombre: str) -> int:
        nombre = nombre.strip().upper()
        if not nombre:
            raise ValueError("Cada platillo debe tener nombre")
        cur.execute("SELECT id FROM nutricion.tipo_plato WHERE upper(nombre) = %s LIMIT 1", (nombre,))
        row = cur.fetchone()
        if row:
            return row[0]
        cur.execute("INSERT INTO nutricion.tipo_plato (nombre) VALUES (%s) RETURNING id", (nombre,))
        return cur.fetchone()[0]

    def actualizar_tipo_plato(self, id_tipo: int, nombre: str) -> bool:
        nombre = nombre.strip()
        if not nombre:
            raise ValueError("El nombre del tipo de plato es requerido")
        with db_cursor() as cur:
            cur.execute("UPDATE nutricion.tipo_plato SET nombre = %s WHERE id = %s", (nombre.upper(), id_tipo))
            return cur.rowcount > 0

    def eliminar_tipo_plato(self, id_tipo: int) -> bool:
        with db_cursor() as cur:
            if self._tabla_existe(cur, "nutricion", "regla_momento_tipo_receta"):
                cur.execute(
                    "DELETE FROM nutricion.regla_momento_tipo_receta WHERE id_tipo_plato = %s",
                    (id_tipo,),
                )
            cur.execute(
                "DELETE FROM nutricion.receta_tipo_plato WHERE id_tipo_plato = %s",
                (id_tipo,),
            )
            cur.execute("DELETE FROM nutricion.tipo_plato WHERE id = %s", (id_tipo,))
            return cur.rowcount > 0

    def limpiar_reglas_composicion(self) -> dict:
        with db_cursor() as cur:
            detalles = 0
            reglas = 0
            if self._tabla_existe(cur, "nutricion", "regla_momento_tipo_receta"):
                cur.execute("DELETE FROM nutricion.regla_momento_tipo_receta")
                detalles = cur.rowcount
            if self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                cur.execute("DELETE FROM nutricion.regla_momento_comida")
                reglas = cur.rowcount
            return {"detalles_eliminados": detalles, "reglas_eliminadas": reglas}

    # ---- REGLAS GENERALES DE COMPOSICIÓN (regla_momento_comida) ----

    def listar_reglas_generales(self) -> List[dict]:
        with db_cursor() as cur:
            if not self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                return []
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
            if not self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                return None
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
            if not self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                return None
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
            if not self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                return 0
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
            if not self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                return False
            cur.execute(f"UPDATE nutricion.regla_momento_comida SET {', '.join(campos)}, updated_at = now() WHERE id = %s", tuple(vals))
            return cur.rowcount > 0

    def eliminar_regla_general(self, id_regla: int) -> bool:
        with db_cursor() as cur:
            if not self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                return False
            cur.execute("DELETE FROM nutricion.regla_momento_comida WHERE id = %s", (id_regla,))
            return cur.rowcount > 0

    # ---- TIPOS PERMITIDOS POR MOMENTO (regla_momento_tipo_receta) ----

    def listar_tipos_permitidos(self, id_regla_momento: Optional[int] = None) -> List[dict]:
        with db_cursor() as cur:
            if not self._tabla_existe(cur, "nutricion", "regla_momento_tipo_receta"):
                if id_regla_momento is not None:
                    cur.execute(
                        """
                        SELECT mtpf.id, NULL::int as id_regla_momento, mtpf.id_momento,
                               m.nombre as momento_nombre,
                               mtpf.id_tipo_plato, tp.nombre as tipo_plato_nombre,
                               'PRINCIPAL'::text as rol_permitido, 0::int as minimo, 1::int as maximo,
                               false as obligatorio, 0::int as orden, true as activo
                        FROM nutricion.momento_tipo_plato_factible mtpf
                        JOIN nutricion.momento_comida m ON m.id = mtpf.id_momento
                        JOIN nutricion.tipo_plato tp ON tp.id = mtpf.id_tipo_plato
                        WHERE 1 = 0
                        ORDER BY tp.nombre
                        """
                    )
                    cols = [d[0] for d in cur.description]
                    return [dict(zip(cols, r)) for r in cur.fetchall()]
                cur.execute(
                    """
                    SELECT mtpf.id, NULL::int as id_regla_momento, mtpf.id_momento,
                           m.nombre as momento_nombre,
                           mtpf.id_tipo_plato, tp.nombre as tipo_plato_nombre,
                           'PRINCIPAL'::text as rol_permitido, 0::int as minimo, 1::int as maximo,
                           false as obligatorio, 0::int as orden, true as activo
                    FROM nutricion.momento_tipo_plato_factible mtpf
                    JOIN nutricion.momento_comida m ON m.id = mtpf.id_momento
                    JOIN nutricion.tipo_plato tp ON tp.id = mtpf.id_tipo_plato
                    ORDER BY m.orden, tp.nombre
                    """
                )
                cols = [d[0] for d in cur.description]
                return [dict(zip(cols, r)) for r in cur.fetchall()]
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
            if not self._tabla_existe(cur, "nutricion", "regla_momento_tipo_receta"):
                return None
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
            if not self._tabla_existe(cur, "nutricion", "regla_momento_tipo_receta"):
                return 0
            self._asegurar_unicidad_combinaciones(cur)
            cur.execute("""
                INSERT INTO nutricion.regla_momento_tipo_receta
                    (id_regla_momento, id_tipo_plato, rol_permitido, minimo, maximo, obligatorio, orden, activo)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (id_regla_momento, id_tipo_plato, rol_permitido, orden)
                DO UPDATE SET
                    minimo = EXCLUDED.minimo, maximo = EXCLUDED.maximo,
                    obligatorio = EXCLUDED.obligatorio,
                    activo = EXCLUDED.activo, updated_at = now()
                RETURNING id
            """, (
                datos["id_regla_momento"], datos["id_tipo_plato"],
                datos["rol_permitido"], datos.get("minimo", 0),
                datos.get("maximo", 1), datos.get("obligatorio", False),
                datos.get("orden", 0), datos.get("activo", True)
            ))
            id_tipo_permitido = cur.fetchone()[0]
            self._asignar_momentos_por_tipo_permitido(
                cur, datos["id_regla_momento"], datos["id_tipo_plato"]
            )
            return id_tipo_permitido

    def importar_combinaciones_momento(self, id_momento: int, combinaciones: list[dict]) -> dict:
        if not combinaciones:
            return {"insertadas": 0, "omitidas": 0, "tipos_creados": 0}

        with db_cursor() as cur:
            if not self._tabla_existe(cur, "nutricion", "regla_momento_comida"):
                return {"insertadas": 0, "omitidas": len(combinaciones), "tipos_creados": 0}
            self._asegurar_unicidad_combinaciones(cur)
            cur.execute("SELECT id FROM nutricion.momento_comida WHERE id = %s", (id_momento,))
            if not cur.fetchone():
                raise ValueError("Momento de comida no encontrado")

            cur.execute("""
                INSERT INTO nutricion.regla_momento_comida
                    (id_momento, min_principales, max_principales, permite_complementos, max_complementos_total, activo)
                VALUES (%s, 1, 1, true, 2, true)
                ON CONFLICT (id_momento) DO UPDATE SET updated_at = now()
                RETURNING id
            """, (id_momento,))
            id_regla = cur.fetchone()[0]

            cur.execute("""
                SELECT rt.rol_permitido, rt.orden, array_agg(rt.id_tipo_plato ORDER BY rt.id_tipo_plato)
                FROM nutricion.regla_momento_tipo_receta rt
                WHERE rt.id_regla_momento = %s
                GROUP BY rt.rol_permitido, rt.orden
            """, (id_regla,))
            existentes = {
                (row[0], tuple(row[2] or []))
                for row in cur.fetchall()
            }

            cur.execute("""
                SELECT coalesce(max(orden), 0)
                FROM nutricion.regla_momento_tipo_receta
                WHERE id_regla_momento = %s
            """, (id_regla,))
            siguiente_orden = (cur.fetchone()[0] or 0) + 1

            cur.execute("SELECT count(*) FROM nutricion.tipo_plato")
            tipos_antes = cur.fetchone()[0]

            insertadas = 0
            omitidas = 0
            for item in combinaciones:
                nombres = item.get("platillos") or item.get("tipos") or item.get("opciones")
                if not isinstance(nombres, list) or not nombres:
                    omitidas += 1
                    continue
                rol = str(item.get("rol") or item.get("tipo") or "PRINCIPAL").strip().upper()
                if rol not in {"PRINCIPAL", "COMPLEMENTO"}:
                    rol = "PRINCIPAL"

                ids = sorted({
                    self._obtener_o_crear_tipo_plato(cur, str(nombre))
                    for nombre in nombres
                    if str(nombre).strip()
                })
                if not ids:
                    omitidas += 1
                    continue

                clave = (rol, tuple(ids))
                if clave in existentes:
                    omitidas += 1
                    continue

                for id_tipo in ids:
                    cur.execute("""
                        INSERT INTO nutricion.regla_momento_tipo_receta
                            (id_regla_momento, id_tipo_plato, rol_permitido, minimo, maximo, obligatorio, orden, activo)
                        VALUES (%s,%s,%s,%s,1,false,%s,true)
                    """, (
                        id_regla,
                        id_tipo,
                        rol,
                        1 if rol == "PRINCIPAL" else 0,
                        siguiente_orden,
                    ))
                    self._asignar_momentos_por_tipo_permitido(cur, id_regla, id_tipo)

                existentes.add(clave)
                insertadas += 1
                siguiente_orden += 1

            cur.execute("SELECT count(*) FROM nutricion.tipo_plato")
            tipos_creados = cur.fetchone()[0] - tipos_antes
            return {
                "insertadas": insertadas,
                "omitidas": omitidas,
                "tipos_creados": tipos_creados,
            }

    def actualizar_tipo_permitido(self, id: int, datos: dict) -> bool:
        campos, vals = [], []
        for k in ("id_regla_momento","id_tipo_plato","rol_permitido","minimo","maximo","obligatorio","orden","activo"):
            if k in datos:
                campos.append(f"{k} = %s"); vals.append(datos[k])
        if not campos: return False
        vals.append(id)
        with db_cursor() as cur:
            if not self._tabla_existe(cur, "nutricion", "regla_momento_tipo_receta"):
                return False
            cur.execute(f"UPDATE nutricion.regla_momento_tipo_receta SET {', '.join(campos)}, updated_at = now() WHERE id = %s", tuple(vals))
            updated = cur.rowcount > 0
            if updated:
                cur.execute("""
                    SELECT id_regla_momento, id_tipo_plato
                    FROM nutricion.regla_momento_tipo_receta
                    WHERE id = %s AND activo = true
                """, (id,))
                row = cur.fetchone()
                if row:
                    self._asignar_momentos_por_tipo_permitido(cur, row[0], row[1])
            return updated

    def eliminar_tipo_permitido(self, id: int) -> bool:
        with db_cursor() as cur:
            if not self._tabla_existe(cur, "nutricion", "regla_momento_tipo_receta"):
                return False
            cur.execute("DELETE FROM nutricion.regla_momento_tipo_receta WHERE id = %s", (id,))
            return cur.rowcount > 0

    # ---- MÉTODO COMPUESTO: devuelve la regla general + tipos permitidos ----

    def obtener_regla_completa_por_momento(self, id_momento: int) -> Optional[dict]:
        general = self.obtener_regla_general_por_momento(id_momento)
        if not general:
            momento = self.obtener_momento(id_momento)
            if not momento:
                return None
            tipos_factibles = self.listar_tipos_factibles_por_momento(id_momento)
            tipos_permitidos = [
                {
                    "id": t.get("id"),
                    "id_regla_momento": None,
                    "id_momento": t.get("id_momento"),
                    "momento_nombre": momento["nombre"],
                    "id_tipo_plato": t.get("id_tipo_plato"),
                    "tipo_plato_nombre": t.get("tipo_plato_nombre"),
                    "rol_permitido": "PRINCIPAL",
                    "minimo": 0,
                    "maximo": 1,
                    "obligatorio": False,
                    "orden": 0,
                    "activo": True,
                }
                for t in tipos_factibles
            ]
            return {
                "id": None,
                "id_momento": id_momento,
                "momento_nombre": momento["nombre"],
                "min_principales": 1,
                "max_principales": 1,
                "permite_complementos": True,
                "max_complementos_total": 2,
                "activo": True,
                "tipos_permitidos": tipos_permitidos,
            }
        tipos = self.listar_tipos_permitidos(id_regla_momento=general["id"])
        general["tipos_permitidos"] = tipos
        return general
