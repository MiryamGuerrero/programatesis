#!/usr/bin/env python3
"""Test endpoint /auth-context con credenciales de usuario."""

import os
import sys
import json
from datetime import datetime, timedelta, timezone
import jwt as pyjwt

import httpx
from dotenv import load_dotenv


def test_auth_context():
    """Prueba el endpoint /auth-context con un JWT de usuario válido."""
    load_dotenv()
    
    # Obtener variables de entorno
    supabase_url = os.getenv("SUPABASE_URL")
    jwt_secret = os.getenv("SUPABASE_JWT_SECRET")
    anon_key = os.getenv("SUPABASE_ANON_KEY")
    
    if not all([supabase_url, jwt_secret, anon_key]):
        print("❌ Variables de entorno incompletas")
        print(f"   SUPABASE_URL: {bool(supabase_url)}")
        print(f"   SUPABASE_JWT_SECRET: {bool(jwt_secret)}")
        print(f"   SUPABASE_ANON_KEY: {bool(anon_key)}")
        return False
    
    print("✅ Variables de entorno configuradas")
    
    # Crear un JWT de prueba para el usuario "medico@reumanutri.app"
    # (deberías hacer un login real en Supabase, pero esto es para testing)
    user_id = "ada48961-d81c-4dda-8056-3e25b6e51766"  # ID del usuario medico
    
    payload = {
        "sub": user_id,
        "email": "medico@reumanutri.app",
        "aud": "authenticated",
        "iat": datetime.now(timezone.utc).timestamp(),
        "exp": (datetime.now(timezone.utc) + timedelta(hours=1)).timestamp(),
        "app_metadata": {
            "provider": "email",
            "providers": ["email"],
            "role": "medico"  # Role en los metadatos de la app
        },
        "user_metadata": {},
    }
    
    token = pyjwt.encode(payload, jwt_secret, algorithm="HS256")
    print(f"🔑 Token JWT creado para usuario: {user_id}")
    print(f"   Email: medico@reumanutri.app")
    print(f"   Role (en JWT): medico")
    
    # Hacer request al endpoint /auth-context
    backend_url = "http://localhost:8000"
    endpoint = f"{backend_url}/api/v1/auth-context"
    
    print(f"\n📍 Llamando a: {endpoint}")
    
    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(
                endpoint,
                headers={"Authorization": f"Bearer {token}"},
            )
        
        print(f"📊 Status Code: {response.status_code}")
        print(f"📦 Response: {json.dumps(response.json(), indent=2)}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"\n✅ Éxito!")
            print(f"   User ID: {data.get('user_id')}")
            print(f"   Email: {data.get('email')}")
            print(f"   Role: {data.get('role')}")
            return True
        else:
            print(f"\n❌ Error {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Error en request: {e}")
        return False


def test_health():
    """Prueba el endpoint /health del backend."""
    backend_url = "http://localhost:8000"
    endpoint = f"{backend_url}/health"
    
    print(f"🏥 Verificando salud del backend: {endpoint}")
    
    try:
        with httpx.Client(timeout=5) as client:
            response = client.get(endpoint)
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Backend saludable: {json.dumps(data)}")
            return True
        else:
            print(f"❌ Backend no responde correctamente (status {response.status_code})")
            return False
            
    except Exception as e:
        print(f"❌ No se puede conectar al backend: {e}")
        return False


def main():
    print("=" * 60)
    print("TEST - Endpoint /auth-context")
    print("=" * 60)
    print(f"\n⏰ Timestamp: {datetime.now().isoformat()}\n")
    
    # Primero verificar salud del backend
    print("1️⃣  Verificando salud del backend...")
    print("-" * 60)
    health_ok = test_health()
    
    if not health_ok:
        print("\n❌ Backend no está disponible. Asegúrate de ejecutar:")
        print("   cd backend && python -m uvicorn app.main:app --reload")
        return 1
    
    print("\n2️⃣  Probando /auth-context...")
    print("-" * 60)
    auth_ok = test_auth_context()
    
    print("\n" + "=" * 60)
    print("RESUMEN")
    print("=" * 60)
    
    if health_ok and auth_ok:
        print("✅ Todos los tests pasaron")
        print("\n📋 El backend está funcionando correctamente.")
        print("   El problema en el frontend probablemente es:")
        print("   - Timeout insuficiente (ya AUMENTADO a 6 segundos)")
        print("   - Credenciales sin metadatos de rol en Supabase")
        print("   - JWT no incluye 'role' en app_metadata")
    else:
        print("❌ Algunos tests fallaron")
    
    return 0 if (health_ok and auth_ok) else 1


if __name__ == "__main__":
    sys.exit(main())
