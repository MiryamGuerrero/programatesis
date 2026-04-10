begin;

create extension if not exists pgcrypto with schema extensions;

-- Crea llave de cifrado en Vault si no existe.
do $$
begin
  if not exists (
    select 1
    from vault.secrets s
    where s.name = 'hu01_sensitive_data_key'
  ) then
    perform vault.create_secret(
      encode(gen_random_bytes(32), 'hex'),
      'hu01_sensitive_data_key',
      'Clave de cifrado para HU-01 (datos sensibles de cuentas)',
      null::uuid
    );
  end if;
end;
$$;

alter table usuarios.usuario
  add column if not exists cedula_enc bytea;

alter table usuarios.usuario
  drop column if exists email_enc,
  drop column if exists telefono_enc,
  drop column if exists direccion_enc;

create or replace function seguridad.get_hu01_sensitive_key()
returns text
language plpgsql
security definer
stable
set search_path = public, seguridad, vault
as $$
declare
  v_key text;
begin
  select ds.decrypted_secret
  into v_key
  from vault.decrypted_secrets ds
  where ds.name = 'hu01_sensitive_data_key'
  order by ds.updated_at desc nulls last, ds.created_at desc
  limit 1;

  if v_key is null or length(trim(v_key)) = 0 then
    raise exception 'No existe llave de cifrado hu01_sensitive_data_key en vault';
  end if;

  return v_key;
end;
$$;

revoke all on function seguridad.get_hu01_sensitive_key() from public;

create or replace function seguridad.trg_encrypt_usuario_sensitive()
returns trigger
language plpgsql
security definer
set search_path = public, usuarios, seguridad, extensions
as $$
declare
  v_key text;
begin
  v_key := seguridad.get_hu01_sensitive_key();

  if tg_op = 'INSERT' then
    if new.cedula is not null then
      new.cedula_enc := pgp_sym_encrypt(new.cedula::text, v_key, 'cipher-algo=aes256, compress-algo=1');
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.cedula is distinct from old.cedula then
      new.cedula_enc := case when new.cedula is null then null else pgp_sym_encrypt(new.cedula::text, v_key, 'cipher-algo=aes256, compress-algo=1') end;
    end if;

    return new;
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_usuario_encrypt_sensitive on usuarios.usuario;
create trigger trg_usuario_encrypt_sensitive
before insert or update on usuarios.usuario
for each row
execute function seguridad.trg_encrypt_usuario_sensitive();

-- Backfill para datos existentes.
update usuarios.usuario u
set
  cedula_enc = case when u.cedula is null then null else pgp_sym_encrypt(u.cedula::text, seguridad.get_hu01_sensitive_key(), 'cipher-algo=aes256, compress-algo=1') end
where
  (u.cedula is not null and u.cedula_enc is null);

commit;
