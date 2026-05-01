"""
Script para limpiar y crear reglas coherentes en ReumaNutri
Ejecutar: cd backend && python scripts/cleanup_and_create_rules.py
"""
import sys
sys.path.insert(0, '.')

from core.db import db_cursor
from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
from app.domain.modelos.reglas import Regla, FuenteRegla, TipoAccion, TipoObjetivo

def limpiar_reglas_vacias():
    """Eliminar reglas sin objetivo definido"""
    with db_cursor() as cur:
        cur.execute("""
            DELETE FROM heuristico.regla 
            WHERE id_ingrediente IS NULL 
              AND id_grupo_alimentario IS NULL 
              AND id_subgrupo_alimentario IS NULL 
              AND id_etiqueta IS NULL 
              AND id_receta IS NULL
        """)
        print(f"Eliminadas {cur.rowcount} reglas sin objetivo")

def verificar_reglas_coherentes():
    """Verificar que las reglas tengan sentido según su tipo"""
    repo = RepositorioReglaPostgres()
    reglas = repo.listar_reglas_detalladas()
    
    print(f"\nTotal reglas: {len(reglas)}")
    print("\n=== VERIFICACIÓN DE COHERENCIA ===")
    
    for r in reglas:
        id_regla = r['id']
        tipo = r['objetivo_codigo']
        accion = r['accion_codigo']
        id_obj = r['id_objetivo']
        
        problemas = []
        
        # Verificar que el objetivo coincide con el ID
        if tipo == 'INGREDIENTE' and not r.get('ingrediente_nombre'):
            problemas.append(f"Es INGREDIENTE pero no tiene ingrediente asignado (id_objetivo={id_obj})")
        elif tipo == 'SUBGRUPO' and not r.get('subgrupo_nombre'):
            problemas.append(f"Es SUBGRUPO pero no tiene subgrupo asignado (id_objetivo={id_obj})")
        elif tipo == 'GRUPO' and not r.get('grupo_nombre'):
            problemas.append(f"Es GRUPO pero no tiene grupo asignado (id_objetivo={id_obj})")
        elif tipo == 'ETIQUETA' and not r.get('etiqueta_nombre'):
            problemas.append(f"Es ETIQUETA pero no tiene etiqueta asignada (id_objetivo={id_obj})")
        elif tipo == 'RECETA' and not r.get('receta_nombre'):
            problemas.append(f"Es RECETA pero no tiene receta asignada (id_objetivo={id_obj})")
        
        if problemas:
            print(f"\nREGLA INCOHERENTE ID {id_regla}:")
            for p in problemas:
                print(f"  - {p}")
            print(f"  Acción: {accion} | Mensaje: {r.get('mensaje_error', 'N/A')}")

def crear_reglas_para_condiciones():
    """Crear reglas automáticas para condiciones comunes"""
    repo = RepositorioReglaPostgres()
    
    # Reglas para AIJ (Artritis Idiopática Juvenil)
    reglas_aij = [
        {
            "id_accion": 3,  # PRIORIZAR
            "id_tipo_objetivo": 2,  # SUBGRUPO
            "id_subgrupo_alimentario": None,  # Se asignará después
            "mensaje_error": "Paciente con AIJ: Priorizar alimentos antiinflamatorios",
            "id_condiciones": []  # Se asignarán después
        }
    ]
    
    print("\n=== REGLAS SUGERIDAS PARA AIJ ===")
    print("1. ELIMINAR alimentos procesados/inflamatorios (subgrupo fritos, embutidos)")
    print("2. PRIORIZAR omega-3 y alimentos antiinflamatorios")
    print("3. Reducir carbohidratos refinados si hay sobrepeso")

if __name__ == "__main__":
    print("=== INICIANDO LIMPIEZA Y CREACIÓN DE REGLAS ===\n")
    
    try:
        limpiar_reglas_vacias()
        verificar_reglas_coherentes()
        crear_reglas_para_condiciones()
        print("\n=== PROCESO COMPLETADO ===")
    except Exception as e:
        print(f"\nERROR: {str(e)}")
