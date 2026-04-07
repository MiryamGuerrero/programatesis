"""
Repositorio para gestionar reglas de etiquetas nutricionales
"""

from app.core.db import db_cursor
from app.schemas.domain import (
    EtiquetaNutricionalReglaCreate,
    EtiquetaNutricionalReglaUpdate,
    EtiquetaNutricionalReglaResponse,
)


def crear_regla(regla: EtiquetaNutricionalReglaCreate) -> dict:
    """Crear una nueva regla de etiqueta"""
    sql = """
        INSERT INTO dom_nutricion.etiqueta_nutricional_regla
        (etiqueta_id, nutriente_columna, operador, valor_umbral, orden, resultado_texto, activa)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING id, etiqueta_id, nutriente_columna, operador, valor_umbral, 
                  orden, resultado_texto, activa, creada_en, actualizada_en
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (
            regla.etiqueta_id,
            regla.nutriente_columna,
            regla.operador,
            float(regla.valor_umbral),
            regla.orden,
            regla.resultado_texto,
            regla.activa
        ))
        row = cur.fetchone()
    
    return _mapear_regla(row) if row else {}


def obtener_regla(regla_id: int) -> dict | None:
    """Obtener una regla por ID"""
    sql = """
        SELECT id, etiqueta_id, nutriente_columna, operador, valor_umbral,
               orden, resultado_texto, activa, creada_en, actualizada_en
        FROM dom_nutricion.etiqueta_nutricional_regla
        WHERE id = %s
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (regla_id,))
        row = cur.fetchone()
    
    return _mapear_regla(row) if row else None


def listar_reglas_etiqueta(etiqueta_id: int, solo_activas: bool = True) -> list[dict]:
    """Listar reglas de una etiqueta"""
    sql = """
        SELECT id, etiqueta_id, nutriente_columna, operador, valor_umbral,
               orden, resultado_texto, activa, creada_en, actualizada_en
        FROM dom_nutricion.etiqueta_nutricional_regla
        WHERE etiqueta_id = %s
    """
    
    if solo_activas:
        sql += " AND activa = true"
    
    sql += " ORDER BY orden"
    
    with db_cursor() as cur:
        cur.execute(sql, (etiqueta_id,) if not solo_activas else (etiqueta_id,))
        rows = cur.fetchall()
    
    return [_mapear_regla(row) for row in rows]


def listar_todas_reglas(solo_activas: bool = True) -> list[dict]:
    """Listar todas las reglas"""
    sql = """
        SELECT id, etiqueta_id, nutriente_columna, operador, valor_umbral,
               orden, resultado_texto, activa, creada_en, actualizada_en
        FROM dom_nutricion.etiqueta_nutricional_regla
    """
    
    if solo_activas:
        sql += " WHERE activa = true"
    
    sql += " ORDER BY etiqueta_id, orden"
    
    with db_cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()
    
    return [_mapear_regla(row) for row in rows]


def actualizar_regla(regla_id: int, datos: EtiquetaNutricionalReglaUpdate) -> dict | None:
    """Actualizar una regla existente"""
    
    # Construir query dinámicamente
    campos_update = []
    valores = []
    
    if datos.operador is not None:
        campos_update.append("operador = %s")
        valores.append(datos.operador)
    
    if datos.valor_umbral is not None:
        campos_update.append("valor_umbral = %s")
        valores.append(float(datos.valor_umbral))
    
    if datos.orden is not None:
        campos_update.append("orden = %s")
        valores.append(datos.orden)
    
    if datos.resultado_texto is not None:
        campos_update.append("resultado_texto = %s")
        valores.append(datos.resultado_texto)
    
    if datos.activa is not None:
        campos_update.append("activa = %s")
        valores.append(datos.activa)
    
    if not campos_update:
        return obtener_regla(regla_id)
    
    campos_update.append("actualizada_en = CURRENT_TIMESTAMP")
    
    sql = f"""
        UPDATE dom_nutricion.etiqueta_nutricional_regla
        SET {', '.join(campos_update)}
        WHERE id = %s
        RETURNING id, etiqueta_id, nutriente_columna, operador, valor_umbral,
                  orden, resultado_texto, activa, creada_en, actualizada_en
    """
    
    valores.append(regla_id)
    
    with db_cursor() as cur:
        cur.execute(sql, valores)
        row = cur.fetchone()
    
    return _mapear_regla(row) if row else None


def eliminar_regla(regla_id: int) -> bool:
    """Eliminar una regla"""
    sql = "DELETE FROM dom_nutricion.etiqueta_nutricional_regla WHERE id = %s"
    
    with db_cursor() as cur:
        cur.execute(sql, (regla_id,))
    
    return True


def evaluar_regla_para_ingrediente(
    ingrediente_id: int,
    regla_id: int
) -> bool:
    """Evaluar si un ingrediente cumple una regla"""
    
    # Obtener regla
    regla = obtener_regla(regla_id)
    if not regla:
        return False
    
    # Obtener valor del nutriente en el ingrediente
    sql = f"""
        SELECT {regla['nutriente_columna']}
        FROM dom_nutricion.ingrediente
        WHERE id = %s
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (ingrediente_id,))
        row = cur.fetchone()
    
    if not row or row[0] is None:
        return False
    
    valor = float(row[0])
    umbral = float(regla['valor_umbral'])
    operador = regla['operador']
    
    # Evaluar condición
    if operador == '>':
        return valor > umbral
    elif operador == '>=':
        return valor >= umbral
    elif operador == '<':
        return valor < umbral
    elif operador == '<=':
        return valor <= umbral
    elif operador == '==':
        return valor == umbral
    elif operador == '!=':
        return valor != umbral
    
    return False


def guardar_auditoria_aplicacion(
    ingrediente_id: int,
    etiqueta_id: int,
    regla_id: int | None,
    valor_nutriente: float | None,
    operador: str | None,
    valor_umbral: float | None,
    resultado_texto: str | None,
    aplicado_por: str = "sistema"
) -> int:
    """Guardar registro de auditoria de aplicacion de regla"""
    
    sql = """
        INSERT INTO dom_nutricion.ingrediente_etiqueta_auditoria
        (ingrediente_id, etiqueta_id, regla_id, valor_nutriente, operador, 
         valor_umbral, resultado_texto, aplicado_por)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (
            ingrediente_id,
            etiqueta_id,
            regla_id,
            valor_nutriente,
            operador,
            valor_umbral,
            resultado_texto,
            aplicado_por
        ))
        row = cur.fetchone()
    
    return row[0] if row else 0


def obtener_auditoria_ingrediente(ingrediente_id: int, limite: int = 100) -> list[dict]:
    """Obtener historial de aplicacion de reglas para un ingrediente"""
    
    sql = """
        SELECT id, ingrediente_id, etiqueta_id, regla_id, valor_nutriente,
               operador, valor_umbral, resultado_texto, aplicada_en, aplicado_por
        FROM dom_nutricion.ingrediente_etiqueta_auditoria
        WHERE ingrediente_id = %s
        ORDER BY aplicada_en DESC
        LIMIT %s
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (ingrediente_id, limite))
        rows = cur.fetchall()
    
    return [
        {
            'id': row[0],
            'ingrediente_id': row[1],
            'etiqueta_id': row[2],
            'regla_id': row[3],
            'valor_nutriente': float(row[4]) if row[4] else None,
            'operador': row[5],
            'valor_umbral': float(row[6]) if row[6] else None,
            'resultado_texto': row[7],
            'aplicada_en': str(row[8]) if row[8] else None,
            'aplicado_por': row[9]
        }
        for row in rows
    ]


# ======================== FUNCIONES AUXILIARES ========================

def _mapear_regla(row) -> dict:
    """Mapear fila de BD a diccionario"""
    if not row:
        return {}
    
    return {
        'id': row[0],
        'etiqueta_id': row[1],
        'nutriente_columna': row[2],
        'operador': row[3],
        'valor_umbral': float(row[4]) if row[4] else None,
        'orden': row[5],
        'resultado_texto': row[6],
        'activa': row[7],
        'creada_en': str(row[8]) if row[8] else None,
        'actualizada_en': str(row[9]) if row[9] else None,
    }
