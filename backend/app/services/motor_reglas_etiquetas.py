"""
Motor de evaluación de reglas de etiquetas nutricionales
Aplica reglas a ingredientes y asigna etiquetas automáticamente
"""

from app.repositories import etiqueta_reglas_repository as reglas_repo
from app.core.db import db_cursor


def aplicar_todas_reglas(
    ingrediente_ids: list[int] | None = None,
    etiqueta_ids: list[int] | None = None,
    remplazar_existentes: bool = True
) -> dict:
    """
    Aplicar todas las reglas a ingredientes
    
    Args:
        ingrediente_ids: IDs específicos (None = todos)
        etiqueta_ids: Etiquetas específicas (None = todas)
        remplazar_existentes: Si eliminar etiquetas asignadas manualmente
    
    Returns:
        dict con resumen de aplicación
    """
    
    resultado = {
        'ingredientes_procesados': 0,
        'etiquetas_asignadas': 0,
        'etiquetas_removidas': 0,
        'errores': []
    }
    
    try:
        # Obtener ingredientes a procesar
        if ingrediente_ids is None:
            ingredientes = _obtener_todos_ingredientes()
        else:
            ingredientes = ingrediente_ids
        
        # Obtener reglas a aplicar
        todas_reglas = reglas_repo.listar_todas_reglas(solo_activas=True)
        
        if etiqueta_ids:
            todas_reglas = [r for r in todas_reglas if r['etiqueta_id'] in etiqueta_ids]
        
        # Agrupar reglas por etiqueta
        reglas_por_etiqueta = {}
        for regla in todas_reglas:
            eid = regla['etiqueta_id']
            if eid not in reglas_por_etiqueta:
                reglas_por_etiqueta[eid] = []
            reglas_por_etiqueta[eid].append(regla)
        
        # Procesar cada ingrediente
        for ingr_id in ingredientes:
            try:
                # Si remplazan existentes, eliminar etiquetas previas
                if remplazar_existentes:
                    _eliminar_etiquetas_ingrediente(ingr_id)
                    resultado['etiquetas_removidas'] += _contar_etiquetas_removidas(ingr_id)
                
                # Evaluar y aplicar reglas
                for etiqueta_id, reglas in reglas_por_etiqueta.items():
                    if _evaluar_etiqueta_para_ingrediente(ingr_id, reglas):
                        _asignar_etiqueta_ingrediente(ingr_id, etiqueta_id)
                        resultado['etiquetas_asignadas'] += 1
                
                resultado['ingredientes_procesados'] += 1
            
            except Exception as e:
                resultado['errores'].append(f"Error en ingrediente {ingr_id}: {str(e)}")
        
        resultado['mensaje'] = f"Se procesaron {resultado['ingredientes_procesados']} ingredientes, " \
                              f"se asignaron {resultado['etiquetas_asignadas']} etiquetas"
    
    except Exception as e:
        resultado['errores'].append(f"Error crítico: {str(e)}")
        resultado['mensaje'] = "Error al aplicar reglas"
    
    return resultado


def aplicar_reglas_etiqueta(
    etiqueta_id: int,
    ingrediente_ids: list[int] | None = None
) -> dict:
    """Aplicar reglas de una etiqueta específica"""
    
    resultado = {
        'ingredientes_procesados': 0,
        'etiquetas_asignadas': 0,
        'errores': []
    }
    
    try:
        # Obtener reglas de la etiqueta
        reglas = reglas_repo.listar_reglas_etiqueta(etiqueta_id, solo_activas=True)
        
        if not reglas:
            resultado['mensaje'] = f"No hay reglas activas para etiqueta {etiqueta_id}"
            return resultado
        
        # Obtener ingredientes
        if ingrediente_ids is None:
            ingredientes = _obtener_todos_ingredientes()
        else:
            ingredientes = ingrediente_ids
        
        # Procesar cada ingrediente
        for ingr_id in ingredientes:
            try:
                if _evaluar_etiqueta_para_ingrediente(ingr_id, reglas):
                    _asignar_etiqueta_ingrediente(ingr_id, etiqueta_id)
                    resultado['etiquetas_asignadas'] += 1
                
                resultado['ingredientes_procesados'] += 1
            
            except Exception as e:
                resultado['errores'].append(f"Error en ingrediente {ingr_id}: {str(e)}")
        
        resultado['mensaje'] = f"Se asignaron {resultado['etiquetas_asignadas']} etiquetas"
    
    except Exception as e:
        resultado['errores'].append(str(e))
        resultado['mensaje'] = "Error al aplicar reglas"
    
    return resultado


def reevaluar_ingrediente(ingrediente_id: int) -> dict:
    """Reevaluar todas las reglas para un ingrediente específico"""
    
    resultado = {
        'ingredientes_procesados': 0,
        'etiquetas_asignadas': 0,
        'etiquetas_removidas': 0,
        'errores': []
    }
    
    try:
        # Eliminar etiquetas previas
        _eliminar_etiquetas_ingrediente(ingrediente_id)
        resultado['etiquetas_removidas'] = _contar_etiquetas_removidas(ingrediente_id)
        
        # Obtener todas las reglas
        todas_reglas = reglas_repo.listar_todas_reglas(solo_activas=True)
        
        # Agrupar por etiqueta
        reglas_por_etiqueta = {}
        for regla in todas_reglas:
            eid = regla['etiqueta_id']
            if eid not in reglas_por_etiqueta:
                reglas_por_etiqueta[eid] = []
            reglas_por_etiqueta[eid].append(regla)
        
        # Evaluar y aplicar
        for etiqueta_id, reglas in reglas_por_etiqueta.items():
            if _evaluar_etiqueta_para_ingrediente(ingrediente_id, reglas):
                _asignar_etiqueta_ingrediente(ingrediente_id, etiqueta_id)
                resultado['etiquetas_asignadas'] += 1
        
        resultado['ingredientes_procesados'] = 1
        resultado['mensaje'] = f"Reevaluado exitosamente"
    
    except Exception as e:
        resultado['errores'].append(str(e))
        resultado['mensaje'] = "Error al reevaluar"
    
    return resultado


# ======================== FUNCIONES AUXILIARES ========================

def _obtener_todos_ingredientes() -> list[int]:
    """Obtener IDs de todos los ingredientes"""
    sql = "SELECT id FROM dom_nutricion.ingrediente WHERE codigo IS NOT NULL"
    
    with db_cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()
    
    return [row[0] for row in rows]


def _evaluar_etiqueta_para_ingrediente(ingrediente_id: int, reglas: list[dict]) -> bool:
    """
    Evaluar si un ingrediente cumple TODAS las reglas de una etiqueta
    Las reglas se evalúan en orden
    """
    
    for regla in sorted(reglas, key=lambda r: r['orden']):
        if not reglas_repo.evaluar_regla_para_ingrediente(ingrediente_id, regla['id']):
            return False
    
    return True if reglas else False


def _asignar_etiqueta_ingrediente(ingrediente_id: int, etiqueta_id: int) -> bool:
    """Asignar una etiqueta a un ingrediente (si no existe)"""
    
    sql = """
        INSERT INTO dom_nutricion.ingrediente_etiqueta
        (ingrediente_id, etiqueta_id, valor_etiqueta)
        VALUES (%s, %s, 'asignado_por_regla')
        ON CONFLICT DO NOTHING
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (ingrediente_id, etiqueta_id))
    
    return True


def _eliminar_etiquetas_ingrediente(ingrediente_id: int) -> int:
    """Eliminar todas las etiquetas de un ingrediente"""
    
    sql = """
        DELETE FROM dom_nutricion.ingrediente_etiqueta
        WHERE ingrediente_id = %s
        AND (valor_etiqueta = 'asignado_por_regla' OR valor_etiqueta LIKE 'regla_%')
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (ingrediente_id,))
    
    return True


def _contar_etiquetas_removidas(ingrediente_id: int) -> int:
    """Contar cuántas etiquetas se removieron"""
    
    sql = """
        SELECT COUNT(*) FROM dom_nutricion.ingrediente_etiqueta
        WHERE ingrediente_id = %s
        AND valor_etiqueta = 'asignado_por_regla'
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (ingrediente_id,))
        row = cur.fetchone()
    
    return row[0] if row else 0
