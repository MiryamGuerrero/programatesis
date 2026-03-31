create table if not exists referencia.oms_percentil_referencia (
    id bigserial primary key,
    id_indicador integer not null references referencia.indicador_antropometrico(id),
    id_sexo integer not null references usuarios.catalogo_sexo(id),
    meses integer not null,
    l decimal(12,6),
    m decimal(12,6),
    s decimal(12,6),
    stdev decimal(12,6),
    p01 decimal(12,6),
    p1 decimal(12,6),
    p3 decimal(12,6),
    p5 decimal(12,6),
    p10 decimal(12,6),
    p15 decimal(12,6),
    p25 decimal(12,6),
    p50 decimal(12,6),
    p75 decimal(12,6),
    p85 decimal(12,6),
    p90 decimal(12,6),
    p95 decimal(12,6),
    p97 decimal(12,6),
    p99 decimal(12,6),
    unique (id_indicador, id_sexo, meses)
);

grant select, insert, update, delete on table referencia.oms_percentil_referencia to authenticated;
grant usage, select on sequence referencia.oms_percentil_referencia_id_seq to authenticated;
