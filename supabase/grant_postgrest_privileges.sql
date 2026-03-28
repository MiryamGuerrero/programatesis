grant usage on schema usuarios, clinico, nutricion, interaccion, heuristico, referencia to authenticated, anon;

grant select, insert, update, delete on all tables in schema usuarios to authenticated;
grant select, insert, update, delete on all tables in schema clinico to authenticated;
grant select, insert, update, delete on all tables in schema nutricion to authenticated;
grant select, insert, update, delete on all tables in schema interaccion to authenticated;
grant select, insert, update, delete on all tables in schema heuristico to authenticated;
grant select, insert, update, delete on all tables in schema referencia to authenticated;

grant usage, select on all sequences in schema usuarios to authenticated;
grant usage, select on all sequences in schema clinico to authenticated;
grant usage, select on all sequences in schema nutricion to authenticated;
grant usage, select on all sequences in schema interaccion to authenticated;
grant usage, select on all sequences in schema heuristico to authenticated;
grant usage, select on all sequences in schema referencia to authenticated;

alter default privileges in schema usuarios grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema clinico grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema nutricion grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema interaccion grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema heuristico grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema referencia grant select, insert, update, delete on tables to authenticated;

alter default privileges in schema usuarios grant usage, select on sequences to authenticated;
alter default privileges in schema clinico grant usage, select on sequences to authenticated;
alter default privileges in schema nutricion grant usage, select on sequences to authenticated;
alter default privileges in schema interaccion grant usage, select on sequences to authenticated;
alter default privileges in schema heuristico grant usage, select on sequences to authenticated;
alter default privileges in schema referencia grant usage, select on sequences to authenticated;
