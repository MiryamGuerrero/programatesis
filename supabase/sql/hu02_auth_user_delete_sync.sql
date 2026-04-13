begin;

create or replace function public.trg_sync_delete_usuario_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public, auth, usuarios
as $$
begin
  delete from usuarios.usuario u
  where u.auth_user_id = old.id;

  return old;
end;
$$;

drop trigger if exists on_auth_user_deleted_sync_usuario on auth.users;
create trigger on_auth_user_deleted_sync_usuario
after delete on auth.users
for each row
execute function public.trg_sync_delete_usuario_from_auth();

commit;
