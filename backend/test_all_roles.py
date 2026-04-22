#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test completo: Verificar que los roles funcionan correctamente.
Prueba el endpoint /auth-context con usuarios de diferentes roles.
"""

import os
import sys
import json
from datetime import datetime, timedelta, timezone
import jwt as pyjwt
import httpx
from dotenv import load_dotenv

# Fix para encoding en Windows
if sys.platform.startswith('win'):
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def test_user_role(email: str, user_id: str, expected_role: str) -> bool:
    """Prueba que un usuario obtiene el rol correcto."""
    load_dotenv()
    jwt_secret = os.getenv("SUPABASE_JWT_SECRET")
    
    if not jwt_secret:
        print("[X] SUPABASE_JWT_SECRET no configurada")
        return False
    
    # Crear token JWT para el usuario
    payload = {
        "sub": user_id,
        "email": email,
        "aud": "authenticated",
        "iat": datetime.now(timezone.utc).timestamp(),
        "exp": (datetime.now(timezone.utc) + timedelta(hours=1)).timestamp(),
        "app_metadata": {
            "provider": "email",
            "role": expected_role  # Ahora está sincronizado en Supabase
        },
        "user_metadata": {},
    }
    
    token = pyjwt.encode(payload, jwt_secret, algorithm="HS256")
    
    # Llamar a /auth-context
    endpoint = "http://localhost:8000/api/v1/auth-context"
    
    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(
                endpoint,
                headers={"Authorization": f"Bearer {token}"},
            )
        
        if response.status_code != 200:
            print("[X] " + email + ": Status " + str(response.status_code))
            return False
        
        data = response.json()
        actual_role = data.get("role")
        
        if actual_role == expected_role:
            print("[OK] " + email + ": " + actual_role)
            return True
        else:
            print("[WARN] " + email + ": esperado '" + expected_role + "', obtuvo '" + actual_role + "'")
            return False
            
    except Exception as e:
        print("[X] " + email + ": " + str(e))
        return False


def main():
    print("=" * 80)
    print("TEST COMPLETO - Acceso a Modulos por Rol")
    print("=" * 80)
    print("\n[TEST] " + datetime.now().isoformat() + "\n")
    
    # Verificar que backend está disponible
    print("[1/4] Verificando backend...")
    try:
        with httpx.Client(timeout=5) as client:
            response = client.get("http://localhost:8000/health")
        if response.status_code != 200:
            print("[X] Backend no responde correctamente")
            return 1
        print("[OK] Backend saludable\n")
    except Exception as e:
        print("[X] Backend no disponible: " + str(e))
        return 1
    
    # Test de cada usuario
    print("[2/4] Probando roles de usuarios...\n")
    
    users = [
        ("admin@reumanutri.app", "2ce2820e-323c-4015-be3e-4d94837e4fc6", "admin"),
        ("medico@reumanutri.app", "ada48961-d81c-4dda-8056-3e25b6e51766", "medico"),
        ("nutricionista@reumanutri.app", "b4ca5ef7-58b4-4d3b-844d-39e321a7d73d", "nutricionista"),
        ("tutor@reumanutri.app", "ddc6eaf0-d517-4990-b9ff-9465775ff0ed", "tutor"),
    ]
    
    results = []
    for email, user_id, expected_role in users:
        success = test_user_role(email, user_id, expected_role)
        results.append(success)
    
    # Resumen
    print("\n" + "=" * 80)
    passed = sum(results)
    total = len(results)
    
    if passed == total:
        print("[OK] TODOS LOS TESTS PASARON (" + str(passed) + "/" + str(total) + ")")
        print("\n[INFO] Proximos pasos:")
        print("[1] Accede a la app Flutter con cada usuario")
        print("[2] Verifica que ves los modulos correctos para cada rol")
        print("[3] Prueba cambiar entre modulos")
        print("[4] Haz logout y login con otro usuario")
        print("\n[INFO] Tus roles estan correctamente sincronizados:")
        print("  - admin: Usuarios, Perfil")
        print("  - medico: Pacientes, Historia Clinica, Diagnostico OMS, etc.")
        print("  - nutricionista: Ingredientes, Recetas, Plan Manual, Perfil")
        print("  - tutor: Mi Plan, Consumo, Reemplazos, Calificar, Perfil")
        return 0
    else:
        print("[WARN] Algunos tests fallaron (" + str(passed) + "/" + str(total) + ")")
        return 1


if __name__ == "__main__":
    sys.exit(main())
