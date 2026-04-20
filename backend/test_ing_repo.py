import os
import sys

# Añadir path del proyecto
sys.path.append(os.getcwd())

from app.repositories.ingredientes_repository import list_ingredients_paged

def test_ingredients():
    print(">>> Probando list_ingredients_paged...")
    try:
        result = list_ingredients_paged(query="", limit=10, offset=0)
        print(f">>> Éxito! Total ingredientes: {result['total']}")
        if result['items']:
            print(f">>> Ejemplo: {result['items'][0]['nombre']}")
    except Exception as e:
        print(f">>> ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_ingredients()
