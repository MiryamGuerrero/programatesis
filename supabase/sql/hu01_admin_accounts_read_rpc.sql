begin;

create or replace function public.admin_listar_cuentas_hu01(
  p_search text default null,
  p_include_inactive boolean default true
)
returns table (
  id uuid,
  auth_user_id uuid,
  id_rol integer,
  rol_codigo text,
  rol_nombre text,
  cedula text,
  username text,
  email text,
  nombre_completo text,
  telefono text,
  direccion text,
  activo boolean,
  created_at timestamp without time zone,
  updated_at timestamp without time zone,
  deactivated_at timestamp without time zone,
  deactivated_reason text
)
language plpgsql
security definer
set search_path = public, usuarios, seguridad
as $$
declare
  v_actor uuid;
  v_search text;
begin
  v_actor := auth.uid();
  if not seguridad.is_admin(v_actor) then
    raise exception 'Solo administrador puede consultar cuentas'
      using errcode = '42501';
  end if;

  v_search := nullif(trim(coalesce(p_search, '')), '');

  insert into seguridad.log_auditoria(
    id_usuario,
    accion,
    esquema_afectado,
    tabla_afectada,
    id_registro_afectado,
    detalle,
    payload_anterior,
    payload_nuevo,
    fecha_registro
  ) values (
    v_actor,
    'READ_LIST',
    'usuarios',
    'usuario',
    null,
    'Consulta de listado de cuentas HU-01',
    null,
    jsonb_build_object(
      'search', v_search,
      'include_inactive', p_include_inactive
    ),
    now()
  );

  return query
    select
      u.id,
      u.auth_user_id,
      u.id_rol,
      r.codigo::text as rol_codigo,
      r.nombre::text as rol_nombre,
      u.cedula::text,
      u.username::text,
      u.email::text,
      u.nombre_completo::text,
      u.telefono::text,
      u.direccion::text,
      u.activo,
      u.created_at,
      u.updated_at,
      u.deactivated_at,
      u.deactivated_reason::text
    from usuarios.usuario u
    join usuarios.rol r on r.id = u.id_rol
    where lower(r.codigo) in ('admin', 'medico', 'nutricionista', 'tutor')
      and (p_include_inactive or u.activo = true)
      and (
        v_search is null
        or u.nombre_completo ilike ('%' || v_search || '%')
        or u.email ilike ('%' || v_search || '%')
        or u.username ilike ('%' || v_search || '%')
        or u.cedula ilike ('%' || v_search || '%')
      )
    order by u.created_at desc nulls last, u.nombre_completo asc;
end;
$$;

revoke all on function public.admin_listar_cuentas_hu01(text, boolean) from public;
grant execute on function public.admin_listar_cuentas_hu01(text, boolean) to authenticated;

commit;
