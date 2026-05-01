from typing import List, Optional
from ...core.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioReceta

class RepositorioRecetaPostgres(IRepositorioReceta):
    def listar_recetas(self, consulta: str = "", limite: int = 100) -> List[dict]:
        """Lista recetas usando la vista nutricional calculada."""
        with db_cursor() as cur:
            sql = """
                SELECT * FROM nutricion.vista_receta_detalle 
                WHERE nombre ILIKE %s AND activa = true
                ORDER BY nombre ASC
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
                SELECT r.id, r.nombre, v.calorias_totales
                FROM nutricion.receta r
                JOIN nutricion.receta_momento rm ON rm.id_receta = r.id
                JOIN nutricion.vista_receta_detalle v ON v.id = r.id
                WHERE rm.id_momento = %s AND r.activa = true
            """
            cur.execute(sql, (id_momento,))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

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
                        tiempo_coccion_min = %s, categoria = %s, subcategoria = %s, 
                        activa = %s, imagen_url = %s, updated_at = now()
                    WHERE id = %s
                """
                cur.execute(sql, (
                    datos["nombre"], datos.get("descripcion"), datos.get("descripcion_larga"),
                    datos.get("dificultad"), datos.get("porciones", 1), datos.get("tiempo_preparacion", 0),
                    datos.get("tiempo_coccion", 0), datos.get("categoria"), datos.get("subcategoria"),
                    datos.get("activa", True), datos.get("imagen_url"), id_receta
                ))
            else:
                sql = """
                    INSERT INTO nutricion.receta (
                        nombre, descripcion, descripcion_larga, dificultad, porciones, 
                        tiempo_preparacion_min, tiempo_coccion_min, categoria, subcategoria, 
                        activa, imagen_url
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
                """
                cur.execute(sql, (
                    datos["nombre"], datos.get("descripcion"), datos.get("descripcion_larga"),
                    datos.get("dificultad"), datos.get("porciones", 1), datos.get("tiempo_preparacion", 0),
                    datos.get("tiempo_coccion", 0), datos.get("categoria"), datos.get("subcategoria"),
                    datos.get("activa", True), datos.get("imagen_url")
                ))
                id_receta = cur.fetchone()[0]

            # 2. Sincronizar Ingredientes (Limpiar y Reinsertar es más seguro para prototipos)
            cur.execute("DELETE FROM nutricion.receta_ingrediente WHERE id_receta = %s", (id_receta,))
            for ing in datos.get("ingredientes", []):
                cur.execute("""
                    INSERT INTO nutricion.receta_ingrediente (
                        id_receta, id_ingrediente, cantidad_visual, unidad_visual, 
                        peso_en_gramos, es_principal, observaciones
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (
                    id_receta, ing["id_ingrediente"], ing.get("cantidad"), ing.get("unidad"),
                    ing.get("gramos", 0), ing.get("es_principal", False), ing.get("observaciones")
                ))

            # 3. Sincronizar Pasos
            cur.execute("DELETE FROM nutricion.receta_paso WHERE id_receta = %s", (id_receta,))
            for index, paso in enumerate(datos.get("preparacion", []), 1):
                cur.execute("""
                    INSERT INTO nutricion.receta_paso (
                        id_receta, numero_paso, descripcion, tiempo_estimado, nota_adicional
                    ) VALUES (%s, %s, %s, %s, %s)
                """, (id_receta, index, paso["descripcion"], paso.get("tiempo"), paso.get("nota")))

            # 4. Sincronizar Etiquetas
            cur.execute("DELETE FROM nutricion.receta_etiqueta WHERE id_receta = %s", (id_receta,))
            for etq in datos.get("etiquetas_salud", []):
                id_etiqueta = etq.get("id")
                if id_etiqueta:
                    cur.execute("INSERT INTO nutricion.receta_etiqueta (id_receta, id_etiqueta) VALUES (%s, %s)", 
                               (id_receta, id_etiqueta))

            return id_receta

    def listar_momentos_comida(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("SELECT id, nombre FROM nutricion.momento_comida ORDER BY orden")
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]
