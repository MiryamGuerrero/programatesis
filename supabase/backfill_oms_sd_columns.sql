create or replace function referencia.lms_valor_z(
    p_l numeric,
    p_m numeric,
    p_s numeric,
    p_z numeric
)
returns numeric
language sql
immutable
as $$
    select
        case
            when p_l is null or p_m is null or p_s is null then null
            when abs(p_l) < 1e-12 then round((p_m * exp(p_s * p_z))::numeric, 6)
            when (1 + p_l * p_s * p_z) <= 0 then null
            else round((p_m * power((1 + p_l * p_s * p_z), (1 / p_l)))::numeric, 6)
        end
$$;

update referencia.oms_referencia
set
    sd4neg = coalesce(sd4neg, referencia.lms_valor_z(l, m, s, -4)),
    sd3neg = coalesce(sd3neg, referencia.lms_valor_z(l, m, s, -3)),
    sd2neg = coalesce(sd2neg, referencia.lms_valor_z(l, m, s, -2)),
    sd1neg = coalesce(sd1neg, referencia.lms_valor_z(l, m, s, -1)),
    sd0 = coalesce(sd0, referencia.lms_valor_z(l, m, s, 0)),
    sd1 = coalesce(sd1, referencia.lms_valor_z(l, m, s, 1)),
    sd2 = coalesce(sd2, referencia.lms_valor_z(l, m, s, 2)),
    sd3 = coalesce(sd3, referencia.lms_valor_z(l, m, s, 3)),
    sd4 = coalesce(sd4, referencia.lms_valor_z(l, m, s, 4))
where
    sd4neg is null
    or sd3neg is null
    or sd2neg is null
    or sd1neg is null
    or sd0 is null
    or sd1 is null
    or sd2 is null
    or sd3 is null
    or sd4 is null;
