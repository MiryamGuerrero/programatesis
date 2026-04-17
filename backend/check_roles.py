#!/usr/bin/env python3
"""Verificar estructura de tabla usuarios.rol."""

import os
import psycopg
from dotenv import load_dotenv


def check_roles_table():
    """Verifica la tabla usuarios.rol."""
    load_dotenv()
    db_url = os.getenv("DATABASE_URL")
    
    if not db_url:
        print("❌ DATABASE_URL no configurada")
        return False
    
    try:
        with psycopg.connect(db_url, sslmode="require") as conn:
            with conn.cursor() as cur:
                # Verificar estructura de rol
                cur.execute("""
                    SELECT column_name, data_type 
                    FROM information_schema.columns 
                    WHERE table_schema = 'usuarios' 
                    AND table_name = 'rol'
                    ORDER BY ordinal_position;
                """)
                columns = cur.fetchall()
                
                if not columns:
                    print("❌ Tabla usuarios.rol NO EXISTE")
                    return False
                
                print("✅ Tabla usuarios.rol EXISTE")
                print("\n📋 Estructura:")
                for col_name, col_type in columns:
                    print(f"   - {col_name}: {col_type}")
                
                # Verificar registros
                cur.execute("SELECT id, codigo, descripcion FROM usuarios.rol;")
                roles = cur.fetchall()
                
                print(f"\n📊 Roles disponibles ({len(roles)}):")
                for role_id, codigo, descripcion in roles:
                    print(f"   - ID: {role_id}, Código: {codigo}, Descripción: {descripcion}")
                
                return True
                
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


if __name__ == "__main__":
    print("=" * 60)
    print("Verificación - Tabla usuarios.rol")
    print("=" * 60)
    print()
    check_roles_table()
