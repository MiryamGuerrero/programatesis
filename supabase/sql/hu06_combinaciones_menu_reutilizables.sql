-- Permite reutilizar el mismo tipo de plato en varias combinaciones del mismo horario.
-- Antes la unicidad era por (regla, tipo_plato, rol), por eso un acompanamiento
-- se movia de una combinacion a otra. Ahora el orden identifica la combinacion.

do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'nutricion'
      and t.relname = 'regla_momento_tipo_receta'
      and c.contype = 'u'
      and pg_get_constraintdef(c.oid) ilike '%id_regla_momento%'
      and pg_get_constraintdef(c.oid) ilike '%id_tipo_plato%'
      and pg_get_constraintdef(c.oid) ilike '%rol_permitido%'
      and pg_get_constraintdef(c.oid) not ilike '%orden%'
  loop
    execute format(
      'alter table nutricion.regla_momento_tipo_receta drop constraint %I',
      constraint_name
    );
  end loop;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'nutricion'
      and t.relname = 'regla_momento_tipo_receta'
      and c.conname = 'regla_momento_tipo_receta_combo_unique'
  ) then
    alter table nutricion.regla_momento_tipo_receta
      add constraint regla_momento_tipo_receta_combo_unique
      unique (id_regla_momento, id_tipo_plato, rol_permitido, orden);
  end if;
end $$;
