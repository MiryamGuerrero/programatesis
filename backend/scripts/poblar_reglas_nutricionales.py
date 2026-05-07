import psycopg2
import os
from dotenv import load_dotenv

load_dotenv('backend/.env')

def run():
    db_url = os.getenv('DATABASE_URL')
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()

    try:
        # 1. Obtener condiciones nutricionales (tipo 3)
        cur.execute("SELECT id, nombre FROM heuristico.condicion WHERE id_tipo_condicion = 3 AND activa = true")
        condiciones = cur.fetchall()
        print(f"Encontradas {len(condiciones)} condiciones nutricionales.")

        # 2. Obtener 5 items de cada categoría
        cur.execute("SELECT id, nombre FROM nutricion.ingrediente WHERE activo = true LIMIT 5")
        ingredientes = cur.fetchall()
        
        cur.execute("SELECT id, nombre FROM nutricion.grupo_alimentario LIMIT 5")
        grupos = cur.fetchall()
        
        cur.execute("SELECT id, nombre_visible FROM nutricion.etiqueta_nutricional LIMIT 5")
        etiquetas = cur.fetchall()
        
        cur.execute("SELECT id, nombre FROM nutricion.subgrupo_alimentario LIMIT 5")
        subgrupos = cur.fetchall()

        print(f"Items obtenidos: Ingredientes({len(ingredientes)}), Grupos({len(grupos)}), Etiquetas({len(etiquetas)}), Subgrupos({len(subgrupos)})")

        reglas_creadas = 0
        
        # Acciones: 1=ELIMINAR, 2=DISMINUIR, 3=PRIORIZAR
        # Objetivos: 1=INGREDIENTE, 2=GRUPO, 3=ETIQUETA, 4=SUBGRUPO

        for cond_id, cond_nombre in condiciones:
            # Determinar lógica base según condición
            es_exceso = any(x in cond_nombre.lower() for x in ['sobrepeso', 'elevado', 'obesidad', 'alta'])
            es_deficit = any(x in cond_nombre.lower() for x in ['bajo', 'severa', 'delgadez', 'desnutrición', 'desnutricion'])
            
            # Reglas para Ingredientes (5 por cada condición)
            for i_id, i_nombre in ingredientes:
                accion = 2 if es_exceso else (3 if es_deficit else 4)
                msg = f"Ajustar consumo de {i_nombre} debido a {cond_nombre}."
                
                cur.execute("""
                    INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_ingrediente, mensaje_error, origen_regla, es_estricta)
                    VALUES (%s, %s, %s, %s, 'NUTRICIONAL', false) RETURNING id
                """, (accion, 1, i_id, msg))
                regla_id = cur.fetchone()[0]
                cur.execute("INSERT INTO heuristico.condicion_regla (id_condicion, id_regla) VALUES (%s, %s)", (cond_id, regla_id))
                reglas_creadas += 1

            # Reglas para Grupos (5 por cada condición)
            for g_id, g_nombre in grupos:
                accion = 2 if es_exceso else (3 if es_deficit else 4)
                msg = f"Controlar grupo {g_nombre} en pacientes con {cond_nombre}."
                cur.execute("""
                    INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, mensaje_error, origen_regla, es_estricta)
                    VALUES (%s, %s, %s, %s, 'NUTRICIONAL', false) RETURNING id
                """, (accion, 2, g_id, msg))
                regla_id = cur.fetchone()[0]
                cur.execute("INSERT INTO heuristico.condicion_regla (id_condicion, id_regla) VALUES (%s, %s)", (cond_id, regla_id))
                reglas_creadas += 1

            # Reglas para Etiquetas (5 por cada condición)
            for e_id, e_nombre in etiquetas:
                # Lógica específica para etiquetas
                if 'grasa' in e_nombre.lower() or 'calor' in e_nombre.lower():
                    accion = 1 if es_exceso else 3
                elif 'fibra' in e_nombre.lower() or 'proteína' in e_nombre.lower():
                    accion = 3
                else:
                    accion = 4
                
                msg = f"Observar etiqueta '{e_nombre}' en contexto de {cond_nombre}."
                cur.execute("""
                    INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, origen_regla, es_estricta)
                    VALUES (%s, %s, %s, %s, 'NUTRICIONAL', false) RETURNING id
                """, (accion, 3, e_id, msg))
                regla_id = cur.fetchone()[0]
                cur.execute("INSERT INTO heuristico.condicion_regla (id_condicion, id_regla) VALUES (%s, %s)", (cond_id, regla_id))
                reglas_creadas += 1

            # Reglas para Subgrupos (5 por cada condición)
            for s_id, s_nombre in subgrupos:
                accion = 2 if es_exceso else (3 if es_deficit else 4)
                msg = f"Recomendación para {s_nombre} bajo {cond_nombre}."
                cur.execute("""
                    INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, mensaje_error, origen_regla, es_estricta)
                    VALUES (%s, %s, %s, %s, 'NUTRICIONAL', false) RETURNING id
                """, (accion, 4, s_id, msg))
                regla_id = cur.fetchone()[0]
                cur.execute("INSERT INTO heuristico.condicion_regla (id_condicion, id_regla) VALUES (%s, %s)", (cond_id, regla_id))
                reglas_creadas += 1

        conn.commit()
        print(f"Proceso finalizado con éxito. Se crearon {reglas_creadas} reglas vinculadas.")

    except Exception as e:
        conn.rollback()
        print(f"Error durante la ejecución: {e}")
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    run()
