alter table if exists referencia.oms_referencia
drop column if exists sd5neg;

notify pgrst, 'reload schema';
notify pgrst, 'reload config';
