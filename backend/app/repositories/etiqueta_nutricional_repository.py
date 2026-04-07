"""
Repositorio para Etiquetas Nutricionales del Excel
"""

from app.core.db import get_connection
from app.schemas.domain import (
    EtiquetaNutricionalResponse,
    IngredienteEtiquetaResponse,
    IngredienteConEtiquetasResponse,
    IngredienteEtiquetaDetallada,
)


class EtiquetaNutricionalRepository:
    """Gestión de etiquetas nutricionales importadas del Excel"""
    
    @staticmethod
    def obtener_todas_etiquetas() -> list[EtiquetaNutricionalResponse]:
        """Obtener catálogo completo de etiquetas"""
        try:
            with get_connection() as conn:
                cur = conn.cursor()
                cur.execute("""
                    SELECT id, codigo_interno, nombre_categoria, descripcion
                    FROM dom_nutricion.etiqueta_nutricional
                    ORDER BY id
                """)
                
                etiquetas = []
                for row in cur.fetchall():
                    etiquetas.append(EtiquetaNutricionalResponse(
                        id=row[0],
                        codigo_interno=row[1],
                        nombre_categoria=row[2],
                        descripcion=row[3]
                    ))
                
                return etiquetas
        except Exception as e:
            print(f"Error al obtener etiquetas: {e}")
            return []
    
    @staticmethod
    def obtener_etiqueta_por_id(etiqueta_id: int) -> EtiquetaNutricionalResponse | None:
        """Obtener una etiqueta por ID"""
        try:
            with get_connection() as conn:
                cur = conn.cursor()
                cur.execute("""
                    SELECT id, codigo_interno, nombre_categoria, descripcion
                    FROM dom_nutricion.etiqueta_nutricional
                    WHERE id = %s
                """, (etiqueta_id,))
                
                row = cur.fetchone()
                if row:
                    return EtiquetaNutricionalResponse(
                        id=row[0],
                        codigo_interno=row[1],
                        nombre_categoria=row[2],
                        descripcion=row[3]
                    )
                return None
        except Exception as e:
            print(f"Error al obtener etiqueta {etiqueta_id}: {e}")
            return None
    
    @staticmethod
    def obtener_etiquetas_ingrediente(ingrediente_id: int) -> list[IngredienteEtiquetaDetallada]:
        """Obtener todas las etiquetas de un ingrediente específico"""
        try:
            with get_connection() as conn:
                cur = conn.cursor()
                cur.execute("""
                    SELECT 
                        ie.id,
                        e.nombre_categoria,
                        ie.valor_etiqueta,
                        e.codigo_interno
                    FROM dom_nutricion.ingrediente_etiqueta ie
                    JOIN dom_nutricion.etiqueta_nutricional e ON ie.etiqueta_id = e.id
                    WHERE ie.ingrediente_id = %s
                    ORDER BY e.id
                """, (ingrediente_id,))
                
                etiquetas = []
                for row in cur.fetchall():
                    etiquetas.append(IngredienteEtiquetaDetallada(
                        id=row[0],
                        nombre_categoria=row[1],
                        valor_etiqueta=row[2],
                        codigo_interno=row[3]
                    ))
                
                return etiquetas
        except Exception as e:
            print(f"Error al obtener etiquetas del ingrediente {ingrediente_id}: {e}")
            return []
    
    @staticmethod
    def obtener_ingrediente_completo_con_etiquetas(ingrediente_id: int) -> IngredienteConEtiquetasResponse | None:
        """Obtener ingrediente con TODAS sus etiquetas nutricionales"""
        try:
            with get_connection() as conn:
                cur = conn.cursor()
                
                # Obtener ingrediente
                cur.execute("""
                    SELECT 
                        i.id, i.codigo, i.nombre, i.energia_kcal, i.proteinas_g,
                        i.carbohidratos_g, i.calcio_mg, i.hierro_mg,
                        gal.nombre
                    FROM dom_nutricion.ingrediente i
                    LEFT JOIN dom_nutricion.grupo_alimentario gal 
                        ON gal.id = (
                            SELECT id FROM dom_nutricion.grupo_alimentario 
                            WHERE nombre = i.grupo_alimentario
                        )
                    WHERE i.id = %s
                """, (ingrediente_id,))
                
                ing_row = cur.fetchone()
                if not ing_row:
                    return None
                
                # Obtener etiquetas
                cur.execute("""
                    SELECT 
                        ie.id,
                        e.nombre_categoria,
                        ie.valor_etiqueta,
                        e.codigo_interno
                    FROM dom_nutricion.ingrediente_etiqueta ie
                    JOIN dom_nutricion.etiqueta_nutricional e ON ie.etiqueta_id = e.id
                    WHERE ie.ingrediente_id = %s
                    ORDER BY e.id
                """, (ingrediente_id,))
                
                etiquetas = []
                for row in cur.fetchall():
                    etiquetas.append(IngredienteEtiquetaDetallada(
                        id=row[0],
                        nombre_categoria=row[1],
                        valor_etiqueta=row[2],
                        codigo_interno=row[3]
                    ))
                
                return IngredienteConEtiquetasResponse(
                    id=ing_row[0],
                    codigo=ing_row[1],
                    nombre=ing_row[2],
                    energia_kcal=ing_row[3],
                    proteinas_g=ing_row[4],
                    carbohidratos_g=ing_row[5],
                    calcio_mg=ing_row[6],
                    hierro_mg=ing_row[7],
                    grupo_alimentario=ing_row[8],
                    etiquetas=etiquetas
                )
        except Exception as e:
            print(f"Error al obtener ingrediente completo {ingrediente_id}: {e}")
            return None
    
    @staticmethod
    def obtener_ingredientes_por_etiqueta(etiqueta_id: int, valor_etiqueta: str | None = None) -> list[int]:
        """
        Obtener liste de ingredientes que tienen una etiqueta específica
        Opcionalmente filtrar por valor exacto de la etiqueta
        """
        try:
            with get_connection() as conn:
                cur = conn.cursor()
                
                if valor_etiqueta:
                    cur.execute("""
                        SELECT DISTINCT ingrediente_id
                        FROM dom_nutricion.ingrediente_etiqueta
                        WHERE etiqueta_id = %s AND valor_etiqueta = %s
                        ORDER BY ingrediente_id
                    """, (etiqueta_id, valor_etiqueta))
                else:
                    cur.execute("""
                        SELECT DISTINCT ingrediente_id
                        FROM dom_nutricion.ingrediente_etiqueta
                        WHERE etiqueta_id = %s
                        ORDER BY ingrediente_id
                    """, (etiqueta_id,))
                
                return [row[0] for row in cur.fetchall()]
        except Exception as e:
            print(f"Error al obtener ingredientes por etiqueta {etiqueta_id}: {e}")
            return []
