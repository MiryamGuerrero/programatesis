import os
import psycopg
from dotenv import load_dotenv
from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres

def test_flow():
    load_dotenv('programatesis/backend/.env')
    repo = RepositorioPacientePostgres()
    
    print("--- INICIANDO BATERÍA DE PRUEBAS CLÍNICAS ---\n")

    # CASO 1: Niño Eutrófico (Normal) + Nuevo Tutor
    print("Prueba 1: Registro Eutrófico...")
    p1 = {
        "tutor": {"cedula": "0601234561", "nombre": "Tutor Prueba 1", "email": "tutor1@test.com", "id_parentesco": 1},
        "paciente": {"nombre_completo": "Niño Normal", "cedula": "0609876541", "fecha_nacimiento": "2018-01-01", "id_sexo": 1},
        "salud": {
            "id_patologia_base": 6, # Artritis
            "condiciones_temporales": [],
            "peso_kg": 20, "talla_cm": 110, "edad_meses": 75,
            "dolor_eva": 2, "brote_activo": False,
            "alergias_ingredientes": [], "alergias_subgrupos": []
        }
    }
    id1 = repo.registrar_paciente_integral(p1)
    print(f"  > Éxito. ID: {id1}")

    # CASO 2: Niño con Sobrepeso + Tutor Existente (Deduplicación)
    print("\nPrueba 2: Registro Sobrepeso + Tutor Existente...")
    p2 = {
        "tutor": {"cedula": "0601234561", "nombre": "Ignorado", "email": "ignorado@test.com", "id_parentesco": 1},
        "paciente": {"nombre_completo": "Niño Sobrepeso", "cedula": "0609876542", "fecha_nacimiento": "2015-05-15", "id_sexo": 2},
        "salud": {
            "id_patologia_base": 7, # Lupus
            "condiciones_temporales": [15], # Gripe
            "peso_kg": 45, "talla_cm": 130, "edad_meses": 108,
            "dolor_eva": 4, "brote_activo": True,
            "alergias_ingredientes": [], "alergias_subgrupos": []
        }
    }
    id2 = repo.registrar_paciente_integral(p2)
    print(f"  > Éxito. ID: {id2}")

    # CASO 3: Niño con Desnutrición + Alergias Complejas
    print("\nPrueba 3: Registro Desnutrición + Alergias Complejas...")
    p3 = {
        "tutor": {"cedula": "0601234562", "nombre": "Tutor Prueba 2", "email": "tutor2@test.com", "id_parentesco": 2},
        "paciente": {"nombre_completo": "Niño Bajo Peso", "cedula": "0609876543", "fecha_nacimiento": "2020-10-10", "id_sexo": 1},
        "salud": {
            "id_patologia_base": 6, 
            "condiciones_temporales": [16, 20], # Diarrea + Fiebre
            "peso_kg": 10, "talla_cm": 95, "edad_meses": 42,
            "dolor_eva": 1, "brote_activo": False,
            "alergias_ingredientes": [1, 2], # IDs inventados para prueba
            "alergias_subgrupos": [1]
        }
    }
    try:
        id3 = repo.registrar_paciente_integral(p3)
        print(f"  > Éxito. ID: {id3}")
    except Exception as e:
        print(f"  > Fallo esperado o real: {e}")

    print("\n--- PRUEBAS FINALIZADAS ---")

if __name__ == "__main__":
    test_flow()
