begin;

alter table etiquetado.subetiqueta
  add column if not exists id_subetiqueta_padre bigint,
  add column if not exists nivel smallint not null default 1;

update etiquetado.subetiqueta
set nivel = case when id_subetiqueta_padre is null then 1 else 2 end
where nivel is null or nivel not in (1, 2);

alter table etiquetado.subetiqueta
  alter column nivel set default 1,
  alter column nivel set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'subetiqueta_nivel_check'
      and connamespace = 'etiquetado'::regnamespace
  ) then
    alter table etiquetado.subetiqueta
      add constraint subetiqueta_nivel_check
      check (nivel in (1, 2));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'subetiqueta_id_subetiqueta_padre_fkey'
      and connamespace = 'etiquetado'::regnamespace
  ) then
    alter table etiquetado.subetiqueta
      add constraint subetiqueta_id_subetiqueta_padre_fkey
      foreign key (id_subetiqueta_padre)
      references etiquetado.subetiqueta(id)
      on delete cascade;
  end if;
end
$$;

create index if not exists idx_subetiqueta_id_subetiqueta_padre
  on etiquetado.subetiqueta(id_subetiqueta_padre);

commit;
