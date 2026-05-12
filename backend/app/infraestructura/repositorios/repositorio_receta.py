from typing import List, Optional
from ...core.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioReceta

class RepositorioRecetaPostgres(IRepositorioReceta):
    def listar_recetas(self, consulta: str = "", limite: int = 100) -> List[dict]:
        """Lista recetas usando la vista nutricional calculada, incluyendo momentos."""
        with db_cursor() as cur:
            sql = """
                SELECT v.*, 
                (SELECT m.nombre FROM nutricion.receta_momento rm 
                 JOIN nutricion.momento_comida m ON m.id = rm.id_momento 
                 WHERE rm.id_receta = v.id LIMIT 1) as categoria,
                r.imagen_url
                FROM nutricion.vista_receta_detalle v
                JOIN nutricion.receta r ON r.id = v.id
                WHERE v.nombre ILIKE %s
                ORDER BY v.nombre ASC
                LIMIT %s
            """
            cur.execute(sql, (f"%{consulta}%", limite))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def obtener_detalle_completo(self, id_receta: int) -> Optional[dict]:
        """Obtiene una receta con todos sus ingredientes, pasos y etiquetas."""
        with db_cursor() as cur:
            # 1. Datos básicos y nutricionales (de la Vista)
            cur.execute("SELECT * FROM nutricion.vista_receta_detalle WHERE id = %s", (id_receta,))
            row = cur.fetchone()
            if not row:
                return None
            
            columnas = [desc[0] for desc in cur.description]
            receta = dict(zip(columnas, row))

            # 1.1 Momentos de Comida
            cur.execute("SELECT id_momento FROM nutricion.receta_momento WHERE id_receta = %s", (id_receta,))
            receta['momentos'] = [r[0] for r in cur.fetchall()]

            # 1.2 Tipos de Plato
            cur.execute("SELECT id_tipo_plato FROM nutricion.receta_tipo_plato WHERE id_receta = %s", (id_receta,))
            receta['tipos_plato'] = [r[0] for r in cur.fetchall()]

            # 2. Ingredientes con su composición técnica
            cur.execute("""
                SELECT 
                    ri.id_ingrediente, 
                    i.nombre, 
                    ri.cantidad_visual as cantidad, 
                    ri.unidad_visual as unidad, 
                    ri.peso_en_gramos as gramos, 
                    ri.observaciones,
                    ri.es_principal
                FROM nutricion.receta_ingrediente ri
                JOIN nutricion.ingrediente i ON i.id = ri.id_ingrediente
                WHERE ri.id_receta = %s
                ORDER BY ri.id ASC
            """, (id_receta,))
            columnas_ing = [desc[0] for desc in cur.description]
            receta['ingredientes'] = [dict(zip(columnas_ing, r)) for r in cur.fetchall()]

            # 3. Pasos de preparación
            cur.execute("""
                SELECT numero_paso as paso, descripcion, tiempo_estimado as tiempo, nota_adicional as nota
                FROM nutricion.receta_paso
                WHERE id_receta = %s
                ORDER BY numero_paso ASC
            """, (id_receta,))
            columnas_paso = [desc[0] for desc in cur.description]
            receta['preparacion'] = [dict(zip(columnas_paso, r)) for r in cur.fetchall()]

            # 4. Etiquetas de salud
            cur.execute("""
                SELECT e.id, e.nombre_visible as titulo, e.descripcion as explicacion 
                FROM nutricion.receta_etiqueta re
                JOIN nutricion.etiqueta_nutricional e ON e.id = re.id_etiqueta
                WHERE re.id_receta = %s
            """, (id_receta,))
            columnas_etq = [desc[0] for desc in cur.description]
            receta['etiquetas_salud'] = [dict(zip(columnas_etq, r)) for r in cur.fetchall()]

            # 5. Nutrición Detallada (Vitaminas y Minerales)
            # Consultamos la tabla de composición para los micronutrientes
            # Nota: Aquí se podrían sumar de forma similar a la vista si se requiere precisión total
            cur.execute("""
                SELECT 
                    SUM(ic.vitamina_a_eq_retinol_ug) as vit_a,
                    SUM(ic.vit_c_mg) as vit_c,
                    SUM(ic.vit_e_eq_alpha_tocoferol_mg) as vit_e,
                    SUM(ic.hierro_mg) as hierro,
                    SUM(ic.magnesio_mg) as magnesio,
                    SUM(ic.potasio_mg) as potasio
                FROM nutricion.receta_ingrediente ri
                JOIN nutricion.ingrediente_composicion ic ON ri.id_ingrediente = ic.id_ingrediente
                WHERE ri.id_receta = %s
            """, (id_receta,))
            micro = cur.fetchone()
            if micro:
                receta['nutricion_detallada'] = {
                    "vitaminas": [
                        {"nombre": "Vitamina A", "valor": round(float(micro[0] or 0), 2), "unidad": "µg"},
                        {"nombre": "Vitamina C", "valor": round(float(micro[1] or 0), 2), "unidad": "mg"},
                        {"nombre": "Vitamina E", "valor": round(float(micro[2] or 0), 2), "unidad": "mg"}
                    ],
                    "minerales": [
                        {"nombre": "Hierro", "valor": round(float(micro[3] or 0), 2), "unidad": "mg"},
                        {"nombre": "Magnesio", "valor": round(float(micro[4] or 0), 2), "unidad": "mg"},
                        {"nombre": "Potasio", "valor": round(float(micro[5] or 0), 2), "unidad": "mg"}
                    ]
                }

            return receta

    def obtener_recetas_por_momento(self, id_momento: int) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                SELECT r.id, r.nombre, r.imagen_url, v.calorias_totales
                FROM nutricion.receta r
                JOIN nutricion.receta_momento rm ON rm.id_receta = r.id
                JOIN nutricion.vista_receta_detalle v ON v.id = r.id
                WHERE rm.id_momento = %s AND r.activa = true
            """
            cur.execute(sql, (id_momento,))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def cambiar_estado_receta(self, id_receta: int, activa: bool) -> bool:
        with db_cursor() as cur:
            cur.execute("UPDATE nutricion.receta SET activa = %s, updated_at = now() WHERE id = %s", (activa, id_receta))
            return cur.rowcount > 0

    def guardar_receta(self, datos: dict) -> int:
        """Crea o actualiza una receta completa (Información, ingredientes y pasos)."""
        with db_cursor() as cur:
            id_receta = datos.get("id")
            
            # 1. Upsert de la información básica
            if id_receta:
                sql = """
                    UPDATE nutricion.receta SET 
                        nombre = %s, descripcion = %s, descripcion_larga = %s, 
                        dificultad = %s, porciones = %s, tiempo_preparacion_min = %s, 
                        tiempo_coccion_min = %s, activa = %s, imagen_url = %s, updated_at = now()
                    WHERE id = %s
                """
                cur.execute(sql, (
                    datos["nombre"], datos.get("descripcion"), datos.get("descripcion_larga"),
                    datos.get("dificultad"), datos.get("porciones", 1), datos.get("tiempo_preparacion", 0),
                    datos.get("tiempo_coccion", 0), datos.get("activa", True), datos.get("imagen_url"), id_receta
                ))
            else:
                sql = """
                    INSERT INTO nutricion.receta (
                        nombre, descripcion, descripcion_larga, dificultad, porciones, 
                        tiempo_preparacion_min, tiempo_coccion_min, activa, imagen_url
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
                """
                cur.execute(sql, (
                    datos["nombre"], datos.get("descripcion"), datos.get("descripcion_larga"),
                    datos.get("dificultad"), datos.get("porciones", 1), datos.get("tiempo_preparacion", 0),
                    datos.get("tiempo_coccion", 0), datos.get("activa", True), datos.get("imagen_url")
                ))
                id_receta = cur.fetchone()[0]

            # 2. Sincronizar Momentos de Comida (receta_momento)
            cur.execute("DELETE FROM nutricion.receta_momento WHERE id_receta = %s", (id_receta,))
            momentos = datos.get("momentos", [])
            if momentos:
                mom_values = [(id_receta, mid) for mid in momentos]
                cur.executemany("INSERT INTO nutricion.receta_momento (id_receta, id_momento) VALUES (%s, %s)", mom_values)

            # 3. Sincronizar Tipos de Plato (receta_tipo_plato)
            cur.execute("DELETE FROM nutricion.receta_tipo_plato WHERE id_receta = %s", (id_receta,))
            tipos_plato = datos.get("tipos_plato", [])
            if tipos_plato:
                tp_values = [(id_receta, tid) for tid in tipos_plato]
                cur.executemany("INSERT INTO nutricion.receta_tipo_plato (id_receta, id_tipo_plato) VALUES (%s, %s)", tp_values)

            # 4. Sincronizar Ingredientes
            cur.execute("DELETE FROM nutricion.receta_ingrediente WHERE id_receta = %s", (id_receta,))
            ingredientes = datos.get("ingredientes", [])
            if ingredientes:
                ing_values = [
                    (id_receta, ing["id_ingrediente"], ing.get("cantidad"), ing.get("unidad"), 
                     ing.get("gramos", 0), ing.get("es_principal", False), ing.get("observaciones"))
                    for ing in ingredientes
                ]
                cur.executemany("""
                    INSERT INTO nutricion.receta_ingrediente (
                        id_receta, id_ingrediente, cantidad_visual, unidad_visual, 
                        peso_en_gramos, es_principal, observaciones
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, ing_values)

            # 5. Sincronizar Pasos
            cur.execute("DELETE FROM nutricion.receta_paso WHERE id_receta = %s", (id_receta,))
            pasos = datos.get("preparacion", [])
            if pasos:
                paso_values = [
                    (id_receta, i, p["descripcion"], p.get("tiempo"), p.get("nota"))
                    for i, p in enumerate(pasos, 1)
                ]
                cur.executemany("""
                    INSERT INTO nutricion.receta_paso (
                        id_receta, numero_paso, descripcion, tiempo_estimado, nota_adicional
                    ) VALUES (%s, %s, %s, %s, %s)
                """, paso_values)

            # 6. Sincronizar Etiquetas (Manuales y Validadas desde el Frontend)
            cur.execute("DELETE FROM nutricion.receta_etiqueta WHERE id_receta = %s", (id_receta,))
            etiquetas = [etq.get("id") for etq in datos.get("etiquetas_salud", []) if etq.get("id")]
            if etiquetas:
                etq_values = [(id_receta, eid) for eid in etiquetas]
                cur.executemany("INSERT INTO nutricion.receta_etiqueta (id_receta, id_etiqueta) VALUES (%s, %s)", etq_values)

            # 7. Sincronizar nutricion.receta_imagen (Regresado al esquema nutricion)
            img_url = datos.get("imagen_url")
            if img_url:
                # Limpiar previas en nutricion.receta_imagen
                cur.execute("DELETE FROM nutricion.receta_imagen WHERE id_receta = %s", (id_receta,))
                cur.execute(
                    "INSERT INTO nutricion.receta_imagen (id_receta, imagen_url) VALUES (%s, %s)",
                    (id_receta, img_url)
                )

            return id_receta

    def listar_momentos_comida(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("SELECT id, nombre FROM nutricion.momento_comida WHERE activo = true ORDER BY orden")
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def listar_tipos_plato(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("SELECT id, nombre FROM nutricion.tipo_plato ORDER BY nombre")
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def eliminar_receta(self, id_receta: int) -> bool:
        """Elimina una receta y todas sus dependencias."""
        with db_cursor() as cur:
            cur.execute("DELETE FROM nutricion.receta_etiqueta WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta_ingrediente WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta_paso WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta_momento WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta_tipo_plato WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta WHERE id = %s", (id_receta,))
            return cur.rowcount > 0
