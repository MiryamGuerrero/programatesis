#!/usr/bin/env python3
"""
Aplicar correcciones de roles en Supabase.
Sincroniza los roles desde usuarios.usuario a auth.users.
"""

import os
import sys
import psycopg
from dotenv import load_dotenv


def apply_role_sync_sql():
    """Ejecuta el SQL para sincronizar roles."""
    load_dotenv()
    
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("❌ DATABASE_URL no configurada")
        return False
    
    # SQL para sincronizar roles
    sql_script = """
-- =====================================================================
-- SINCRONIZACIÓN DE ROLES EN JWT DE SUPABASE
-- =====================================================================

-- 1. Crear función que sincroniza el rol desde usuarios.usuario a auth.users
create or replace function public.sync_user_role_to_auth()
returns trigger
language plpgsql
security definer set search_path = public, usuarios
as $$
declare
  v_role_code text;
  v_app_meta jsonb;
begin
  -- Obtener el código del rol desde usuarios.rol
  select lower(r.codigo)
  into v_role_code
  from usuarios.rol r
  where r.id = new.id_rol
  limit 1;
  
  -- Si no encontramos el rol, usar "tutor" como defecto
  if v_role_code is null then
    v_role_code := 'tutor';
  end if;
  
  -- Actualizar raw_app_meta_data en auth.users
  update auth.users
  set raw_app_meta_data = 
    jsonb_set(
      coalesce(raw_app_meta_data, '{}'::jsonb),
      '{role}',
      to_jsonb(v_role_code)
    )
  where id = new.auth_user_id;
  
  return new;
end;
$$;

-- 2. Crear trigger en usuarios.usuario para INSERT
drop trigger if exists trg_sync_role_on_insert on usuarios.usuario;
create trigger trg_sync_role_on_insert
after insert on usuarios.usuario
for each row
when (new.auth_user_id is not null)
execute function public.sync_user_role_to_auth();

-- 3. Crear trigger en usuarios.usuario para UPDATE (cuando cambia el rol)
drop trigger if exists trg_sync_role_on_update on usuarios.usuario;
create trigger trg_sync_role_on_update
after update on usuarios.usuario
for each row
when (old.id_rol is distinct from new.id_rol and new.auth_user_id is not null)
execute function public.sync_user_role_to_auth();

-- 4. Sincronizar roles existentes (usuarios que ya están en el sistema)
update auth.users
set raw_app_meta_data = 
  jsonb_set(
    coalesce(raw_app_meta_data, '{}'::jsonb),
    '{role}',
    (
      select to_jsonb(lower(r.codigo))
      from usuarios.usuario u
      inner join usuarios.rol r on r.id = u.id_rol
      where u.auth_user_id = auth.users.id
      limit 1
    )
  )
where id in (
  select auth_user_id 
  from usuarios.usuario 
  where auth_user_id is not null
);
"""
    
    try:
        print("🔗 Conectando a Supabase (PostgreSQL)...")
        with psycopg.connect(db_url, sslmode="require") as conn:
            with conn.cursor() as cur:
                print("✅ Conexión exitosa")
                
                print("\n📝 Ejecutando SQL para sincronizar roles...")
                cur.execute(sql_script)
                conn.commit()
                print("✅ SQL ejecutado exitosamente")
                
                # Verificar que se aplicó
                print("\n📊 Verificando sincronización...")
                cur.execute("""
                    select 
                      u.email,
                      u.id_rol,
                      r.codigo as role_code,
                      au.raw_app_meta_data->>'role' as jwt_role
                    from usuarios.usuario u
                    left join usuarios.rol r on r.id = u.id_rol
                    left join auth.users au on au.id = u.auth_user_id
                    where u.auth_user_id is not null
                    order by u.email;
                """)
                
                rows = cur.fetchall()
                print("\n👥 Usuarios sincronizados:")
                print("-" * 80)
                for email, id_rol, role_code, jwt_role in rows:
                    status = "✅" if jwt_role == role_code.lower() else "⚠️"
                    print(f"{status} {email:30} | BD: {role_code:15} | JWT: {jwt_role or 'N/A':15}")
                print("-" * 80)
                
                return True
                
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    print("=" * 80)
    print("APLICAR CORRECCIONES - Sincronización de Roles en Supabase")
    print("=" * 80)
    print()
    
    success = apply_role_sync_sql()
    
    print("\n" + "=" * 80)
    if success:
        print("✅ CORRECCIONES APLICADAS EXITOSAMENTE")
        print("\nProximos pasos:")
        print("1. Hacer login en la app con diferentes usuarios")
        print("2. Verificar que ven los módulos correctos según su rol")
        print("3. Probar navegación entre módulos")
        print("\nLas credenciales de prueba son:")
        print("  - admin@reumanutri.app (acceso a Admin)")
        print("  - medico@reumanutri.app (acceso a Médico)")
        print("  - nutricionista@reumanutri.app (acceso a Nutricionista)")
        print("  - tutor@reumanutri.app (acceso a Tutor)")
        return 0
    else:
        print("❌ OCURRIÓ UN ERROR")
        return 1


if __name__ == "__main__":
    sys.exit(main())
