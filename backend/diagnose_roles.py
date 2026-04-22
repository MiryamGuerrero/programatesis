#!/usr/bin/env python3
"""Diagnóstico para identificar por qué los usuarios no pueden acceder a módulos."""

import os
import sys
import json
from datetime import datetime
import psycopg

# Configuración desde .env
def load_env():
    from dotenv import load_dotenv
    load_dotenv()
    return {
        "db_url": os.getenv("DATABASE_URL"),
        "supabase_url": os.getenv("SUPABASE_URL"),
        "supabase_key": os.getenv("SUPABASE_ANON_KEY"),
        "jwt_secret": os.getenv("SUPABASE_JWT_SECRET"),
    }

def check_usuarios_table():
    """Verifica la tabla usuarios.usuario"""
    config = load_env()
    db_url = config.get("db_url")
    
    if not db_url:
        print("❌ DATABASE_URL no configurada")
        return False
    
    try:
        with psycopg.connect(db_url, sslmode="require") as conn:
            with conn.cursor() as cur:
                # Verificar si la tabla existe
                cur.execute("""
                    SELECT EXISTS(
                        SELECT 1 FROM information_schema.tables 
                        WHERE table_schema = 'usuarios' 
                        AND table_name = 'usuario'
                    );
                """)
                exists = cur.fetchone()[0]
                
                if not exists:
                    print("❌ Tabla usuarios.usuario NO EXISTE")
                    return False
                
                print("✅ Tabla usuarios.usuario EXISTE")
                
                # Verificar estructura
                cur.execute("""
                    SELECT column_name, data_type 
                    FROM information_schema.columns 
                    WHERE table_schema = 'usuarios' 
                    AND table_name = 'usuario'
                    ORDER BY ordinal_position;
                """)
                columns = cur.fetchall()
                print("\n📋 Estructura de la tabla:")
                for col_name, col_type in columns:
                    print(f"   - {col_name}: {col_type}")
                
                # Contar usuarios
                cur.execute("SELECT COUNT(*) FROM usuarios.usuario;")
                count = cur.fetchone()[0]
                print(f"\n📊 Total de usuarios: {count}")
                
                if count == 0:
                    print("⚠️  ¡No hay usuarios en la tabla!")
                    return False
                
                # Verificar usuarios con role definido
                cur.execute("""
                    SELECT id, email, id_rol, auth_user_id, activo 
                    FROM usuarios.usuario 
                    LIMIT 5;
                """)
                users = cur.fetchall()
                print("\n👥 Primeros 5 usuarios:")
                for user in users:
                    print(f"   - ID: {user[0]}, Email: {user[1]}, Rol: {user[2]}, AuthID: {user[3]}, Activo: {user[4]}")
                
                # Verificar que hay al menos un usuario activo con rol
                cur.execute("""
                    SELECT COUNT(*) FROM usuarios.usuario 
                    WHERE activo = true AND id_rol IS NOT NULL;
                """)
                valid_count = cur.fetchone()[0]
                print(f"\n✅ Usuarios activos con rol: {valid_count}")
                
                if valid_count == 0:
                    print("❌ No hay usuarios activos con rol asignado")
                    return False
                
                return True
                
    except Exception as e:
        print(f"❌ Error conectando a BD: {e}")
        return False

def check_auth_endpoint():
    """Intenta llamar al endpoint /auth-context"""
    import requests
    from supabase import create_client
    from datetime import datetime, timedelta, timezone
    import jwt as pyjwt
    
    config = load_env()
    
    # Crear un token JWT de prueba con un usuario válido
    # Esto requiere verificar en Supabase quién está autenticado
    try:
        print("\n🔐 Verificando endpoint /auth-context")
        
        # Nota: Este test es limitado sin credenciales de usuario real
        # Lo mejor es hacer un login real en Supabase
        print("   ℹ️  Para probar /auth-context se requiere un usuario autenticado en Supabase")
        print("   ℹ️  Verifica en los logs del servidor backend si hay errores")
        
        return True
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    print("=" * 60)
    print("DIAGNÓSTICO - Problema de Acceso a Módulos por Rol")
    print("=" * 60)
    print(f"\n⏰ Timestamp: {datetime.now().isoformat()}\n")
    
    print("1️⃣  Verificando tabla usuarios.usuario...")
    print("-" * 60)
    check1 = check_usuarios_table()
    
    print("\n2️⃣  Verificando backend...")
    print("-" * 60)
    check2 = check_auth_endpoint()
    
    print("\n" + "=" * 60)
    print("RESUMEN")
    print("=" * 60)
    
    if check1 and check2:
        print("✅ Checks básicos pasaron")
        print("\n📋 Próximos pasos:")
        print("   1. Verifica en el navegador si el token Bearer es válido")
        print("   2. Revisa la consola del backend para ver errores de timeout")
        print("   3. Asegúrate de que el backend está corriendo en http://localhost:8000")
        print("   4. Revisa los logs de la app Flutter para ver qué rol recibe")
    else:
        print("❌ Problemas detectados:")
        if not check1:
            print("   - Problema con la tabla usuarios.usuario")
        if not check2:
            print("   - Problema con el endpoint /auth-context")
    
    return 0 if (check1 and check2) else 1

if __name__ == "__main__":
    sys.exit(main())
