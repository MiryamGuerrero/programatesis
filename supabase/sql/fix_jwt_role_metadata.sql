-- =====================================================================
-- SOLUCIÓN: Sincronización de Roles en JWT de Supabase
-- =====================================================================
-- Este script agrega un trigger que copia automáticamente el rol
-- de la tabla usuarios.usuario a los metadatos del JWT (auth.users)
-- Esto permite que el frontend obtenga el rol desde la sesión sin
-- necesidad de hacer un request al backend.
--
-- PROBLEMA ORIGINAL:
-- - Login en Supabase no incluía el rol en los metadatos
-- - Frontend requería hacer request a /auth-context (timeout de 2s)
-- - Si el timeout fallaba, el usuario veía rol "tutor" por defecto
--
-- SOLUCIÓN:
-- - Crear trigger que actualice raw_app_meta_data en auth.users
-- - Sincronizar rol cuando se crea usuario o se actualiza en usuarios.usuario
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
execute function public.sync_user_role_to_auth();

-- 3. Crear trigger en usuarios.usuario para UPDATE (cuando cambia el rol)
drop trigger if exists trg_sync_role_on_update on usuarios.usuario;
create trigger trg_sync_role_on_update
after update on usuarios.usuario
for each row
when (old.id_rol is distinct from new.id_rol)
execute function public.sync_user_role_to_auth();

-- 4. Sincronizar roles existentes (usuarios que ya están en el sistema)
-- IMPORTANTE: Ejecutar esto una sola vez para actualizar usuarios existentes
do $$
declare
  v_user record;
  v_role_code text;
begin
  -- Iterar sobre todos los usuarios con auth_user_id
  for v_user in
    select u.id, u.auth_user_id, u.id_rol
    from usuarios.usuario u
    where u.auth_user_id is not null
  loop
    -- Obtener el código del rol
    select lower(r.codigo)
    into v_role_code
    from usuarios.rol r
    where r.id = v_user.id_rol;
    
    if v_role_code is null then
      v_role_code := 'tutor';
    end if;
    
    -- Actualizar auth.users
    update auth.users
    set raw_app_meta_data = 
      jsonb_set(
        coalesce(raw_app_meta_data, '{}'::jsonb),
        '{role}',
        to_jsonb(v_role_code)
      )
    where id = v_user.auth_user_id;
  end loop;
  
  raise notice 'Sincronización de roles completada';
end $$;

-- 5. Verificación: mostrar usuarios actualizados
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
