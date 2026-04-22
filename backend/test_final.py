
from datetime import date
from app.repositories.medico_tutor_repository import registrar_paciente

def test_registration_clean():
    print("Iniciando prueba de registro post-limpieza...")
    
    nombre = "PACIENTE PRUEBA LIMPIEZA CACHE"
    fecha_nac = date(2018, 1, 10)
    sexo = 2 # Femenino
    provincia = 2
    
    control_inicial = {
        "peso_kg": 22.0,
        "talla_cm": 115.0,
        "id_condiciones_activas": [7], # Lupus
        "alergia_ingrediente_ids": [10, 15],
        "alergia_subgrupo_ids": [5],
        "nota_evolucion": "Prueba final tras limpieza de cache"
    }
    
    try:
        resultado = registrar_paciente(
            nombre_completo=nombre,
            fecha_nacimiento=fecha_nac,
            id_sexo=sexo,
            id_provincia=provincia,
            control_clinico_inicial=control_inicial
        )
        print(f"\n[OK] Paciente ID: {resultado['id_paciente']}")
        print(f"[OK] Diagnóstico: {resultado['control_inicial']['diagnostico_nutri_texto']}")
        print("\nPrueba de persistencia exitosa.")
                
    except Exception as e:
        print(f"\n[ERROR]: {e}")

if __name__ == "__main__":
    test_registration_clean()
