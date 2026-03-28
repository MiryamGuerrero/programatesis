insert into referencia.indicador_antropometrico (codigo, nombre)
values ('IMC_EDAD', 'IMC para la edad')
on conflict (codigo) do nothing;

insert into referencia.oms_referencia (
    id_indicador,
    id_sexo,
    meses,
    l,
    m,
    s
)
select
    i.id,
    sx.id,
    g.meses,
    1.0 as l,
    case
        when sx.codigo = 'M' then 15.5 + (g.meses * 0.01)
        else 15.2 + (g.meses * 0.01)
    end as m,
    0.1 as s
from referencia.indicador_antropometrico i
join usuarios.catalogo_sexo sx on sx.codigo in ('M', 'F')
cross join generate_series(0, 228) as g(meses)
where i.codigo = 'IMC_EDAD'
on conflict (id_indicador, id_sexo, meses) do nothing;
