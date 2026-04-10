begin;

-- 1) Trazabilidad en cuentas de usuario
alter table usuarios.usuario
  add column if not exists created_by uuid,
  add column if not exists updated_by uuid,
  add column if not exists deactivated_at timestamp without time zone,
  add column if not exists deactivated_by uuid,
  add column if not exists deactivated_reason text;

-- 2) Funcion de autorizacion admin para RLS
create or replace function seguridad.is_admin(p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, usuarios, seguridad
as $$
  select exists (
    select 1
    from usuarios.usuario u
    join usuarios.rol r on r.id = u.id_rol
    where u.activo = true
      and lower(r.codigo) = 'admin'
      and (u.auth_user_id = p_uid or u.id = p_uid)
  );
$$;

revoke all on function seguridad.is_admin(uuid) from public;
grant execute on function seguridad.is_admin(uuid) to authenticated;

-- 3) Funcion utilitaria de log de errores
create or replace function seguridad.registrar_error(
  p_modulo text,
  p_mensaje text,
  p_stack_trace text default null,
  p_payload jsonb default null
)
returns bigint
language plpgsql
security definer
set search_path = public, seguridad
as $$
declare
  v_id bigint;
begin
  insert into seguridad.log_error(modulo, mensaje, stack_trace, payload, fecha_registro)
  values (
    left(coalesce(p_modulo, 'app'), 200),
    left(coalesce(p_mensaje, 'Error no especificado'), 4000),
    p_stack_trace,
    p_payload,
    now()
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function seguridad.registrar_error(text, text, text, jsonb) from public;
grant execute on function seguridad.registrar_error(text, text, text, jsonb) to authenticated;

-- 4) Trigger BEFORE para setear metadata de auditoria en usuarios.usuario
create or replace function seguridad.trg_set_usuario_audit_fields()
returns trigger
language plpgsql
security definer
set search_path = public, usuarios, seguridad
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();

  if tg_op = 'INSERT' then
    if new.created_at is null then
      new.created_at := now();
    end if;

    new.updated_at := now();

    if new.created_by is null then
      new.created_by := v_actor;
    end if;
    new.updated_by := v_actor;

    if coalesce(new.activo, true) = false then
      if new.deactivated_at is null then
        new.deactivated_at := now();
      end if;
      if new.deactivated_by is null then
        new.deactivated_by := v_actor;
      end if;
    end if;

    return new;
  end if;

  if tg_op = 'UPDATE' then
    new.updated_at := now();
    new.updated_by := v_actor;

    if coalesce(old.activo, false) = true and coalesce(new.activo, false) = false then
      new.deactivated_at := now();
      new.deactivated_by := v_actor;
    elsif coalesce(old.activo, false) = false and coalesce(new.activo, false) = true then
      new.deactivated_at := null;
      new.deactivated_by := null;
      new.deactivated_reason := null;
    end if;

    return new;
  end if;

  return coalesce(new, old);
end;
$$;

-- 5) Trigger AFTER para log automatico en seguridad.log_auditoria
create or replace function seguridad.trg_log_usuario_change()
returns trigger
language plpgsql
security definer
set search_path = public, usuarios, seguridad
as $$
declare
  v_actor uuid;
  v_accion text;
  v_detalle text;
  v_context text;
begin
  v_actor := auth.uid();

  if tg_op = 'INSERT' then
    v_accion := 'CREATE';
    v_detalle := 'Creacion de cuenta';
  elsif tg_op = 'UPDATE' then
    if coalesce(old.activo, false) = true and coalesce(new.activo, false) = false then
      v_accion := 'DEACTIVATE';
      v_detalle := 'Desactivacion de cuenta';
    elsif coalesce(old.activo, false) = false and coalesce(new.activo, false) = true then
      v_accion := 'ACTIVATE';
      v_detalle := 'Activacion de cuenta';
    else
      v_accion := 'UPDATE';
      v_detalle := 'Actualizacion de cuenta';
    end if;
  elsif tg_op = 'DELETE' then
    v_accion := 'DELETE';
    v_detalle := 'Eliminacion de cuenta';
  else
    v_accion := tg_op;
    v_detalle := 'Cambio de cuenta';
  end if;

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
  )
  values (
    v_actor,
    v_accion,
    'usuarios',
    'usuario',
    coalesce(new.id, old.id)::text,
    v_detalle,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end,
    now()
  );

  return coalesce(new, old);
exception when others then
  get stacked diagnostics v_context = pg_exception_context;

  begin
    perform seguridad.registrar_error(
      'seguridad.trg_log_usuario_change',
      sqlerrm,
      v_context,
      jsonb_build_object(
        'tg_op', tg_op,
        'tabla', tg_table_schema || '.' || tg_table_name,
        'registro', coalesce(new.id, old.id)
      )
    );
  exception when others then
    null;
  end;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_usuario_set_audit_fields on usuarios.usuario;
create trigger trg_usuario_set_audit_fields
before insert or update on usuarios.usuario
for each row
execute function seguridad.trg_set_usuario_audit_fields();

drop trigger if exists trg_usuario_log_auditoria on usuarios.usuario;
create trigger trg_usuario_log_auditoria
after insert or update or delete on usuarios.usuario
for each row
execute function seguridad.trg_log_usuario_change();

-- 6) Grants minimos para consumo via Supabase SDK (con control por RLS)
grant usage on schema usuarios to authenticated;
grant usage on schema seguridad to authenticated;

revoke all on table usuarios.usuario from anon;
revoke all on table usuarios.rol from anon;
revoke all on table seguridad.log_auditoria from anon;
revoke all on table seguridad.log_error from anon;

grant select, insert, update on table usuarios.usuario to authenticated;
grant select on table usuarios.rol to authenticated;
grant select on table seguridad.log_auditoria to authenticated;
grant select on table seguridad.log_error to authenticated;

-- 7) RLS y politicas
alter table usuarios.usuario enable row level security;
alter table usuarios.rol enable row level security;
alter table seguridad.log_auditoria enable row level security;
alter table seguridad.log_error enable row level security;

drop policy if exists usuario_select_admin on usuarios.usuario;
drop policy if exists usuario_insert_admin on usuarios.usuario;
drop policy if exists usuario_update_admin on usuarios.usuario;

create policy usuario_select_admin
on usuarios.usuario
for select
to authenticated
using (seguridad.is_admin(auth.uid()));

create policy usuario_insert_admin
on usuarios.usuario
for insert
to authenticated
with check (seguridad.is_admin(auth.uid()));

create policy usuario_update_admin
on usuarios.usuario
for update
to authenticated
using (seguridad.is_admin(auth.uid()))
with check (seguridad.is_admin(auth.uid()));

drop policy if exists rol_select_admin on usuarios.rol;
create policy rol_select_admin
on usuarios.rol
for select
to authenticated
using (seguridad.is_admin(auth.uid()));

drop policy if exists log_auditoria_select_admin on seguridad.log_auditoria;
create policy log_auditoria_select_admin
on seguridad.log_auditoria
for select
to authenticated
using (seguridad.is_admin(auth.uid()));

drop policy if exists log_error_select_admin on seguridad.log_error;
create policy log_error_select_admin
on seguridad.log_error
for select
to authenticated
using (seguridad.is_admin(auth.uid()));

commit;
