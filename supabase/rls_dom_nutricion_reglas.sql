-- =====================================================
-- Reuma Nutri - RLS para modelo dom_nutricion_reglas (2026-04-04)
-- =====================================================

create or replace function public.current_app_role()
returns text
language sql
stable
as $$
    select coalesce(
        auth.jwt() -> 'app_metadata' ->> 'role',
        auth.jwt() ->> 'role',
        'tutor'
    )
$$;

grant execute on function public.current_app_role() to authenticated;

create or replace function public.is_nutrition_editor()
returns boolean
language sql
stable
as $$
    select public.current_app_role() in ('admin', 'nutricionista')
$$;

grant execute on function public.is_nutrition_editor() to authenticated;

-- =====================================================
-- Enable RLS
-- =====================================================

alter table if exists dom_nutricion_catalogos.subgrupo_alimentario enable row level security;
alter table if exists dom_nutricion_catalogos.variable_nutricional enable row level security;
alter table if exists dom_nutricion_ingrediente_rel.importacion_variable_lote enable row level security;
alter table if exists dom_nutricion_ingrediente_rel.ingrediente_variable_valor enable row level security;
alter table if exists dom_nutricion_ingrediente_rel.ingrediente_campo_derivado enable row level security;
alter table if exists dom_nutricion_ingrediente_rel.ingrediente_etiqueta_historial enable row level security;
alter table if exists dom_nutricion_reglas.campo_derivado_definicion enable row level security;
alter table if exists dom_nutricion_reglas.etiqueta_regla_version enable row level security;
alter table if exists dom_nutricion_reglas.etiqueta_regla_condicion enable row level security;
alter table if exists dom_nutricion_reglas.etiqueta_regla_excepcion enable row level security;
alter table if exists dom_nutricion_reglas.etiqueta_excepcion_manual enable row level security;
alter table if exists dom_nutricion_reglas.recalculo_job enable row level security;
alter table if exists dom_nutricion_reglas.recalculo_historial enable row level security;
alter table if exists dom_nutricion_reglas.auditoria_cambio enable row level security;

-- =====================================================
-- subgrupo_alimentario
-- =====================================================

drop policy if exists subgrupo_alimentario_select_policy on dom_nutricion_catalogos.subgrupo_alimentario;
create policy subgrupo_alimentario_select_policy on dom_nutricion_catalogos.subgrupo_alimentario
for select to authenticated
using (true);

drop policy if exists subgrupo_alimentario_write_policy on dom_nutricion_catalogos.subgrupo_alimentario;
create policy subgrupo_alimentario_write_policy on dom_nutricion_catalogos.subgrupo_alimentario
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

-- =====================================================
-- variable_nutricional
-- =====================================================

drop policy if exists variable_nutricional_select_policy on dom_nutricion_catalogos.variable_nutricional;
create policy variable_nutricional_select_policy on dom_nutricion_catalogos.variable_nutricional
for select to authenticated
using (true);

drop policy if exists variable_nutricional_write_policy on dom_nutricion_catalogos.variable_nutricional;
create policy variable_nutricional_write_policy on dom_nutricion_catalogos.variable_nutricional
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

-- =====================================================
-- ingredientes: valores y derivados
-- =====================================================

drop policy if exists ingrediente_variable_valor_select_policy on dom_nutricion_ingrediente_rel.ingrediente_variable_valor;
create policy ingrediente_variable_valor_select_policy on dom_nutricion_ingrediente_rel.ingrediente_variable_valor
for select to authenticated
using (true);

drop policy if exists ingrediente_variable_valor_write_policy on dom_nutricion_ingrediente_rel.ingrediente_variable_valor;
create policy ingrediente_variable_valor_write_policy on dom_nutricion_ingrediente_rel.ingrediente_variable_valor
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

drop policy if exists ingrediente_campo_derivado_select_policy on dom_nutricion_ingrediente_rel.ingrediente_campo_derivado;
create policy ingrediente_campo_derivado_select_policy on dom_nutricion_ingrediente_rel.ingrediente_campo_derivado
for select to authenticated
using (true);

drop policy if exists ingrediente_campo_derivado_write_policy on dom_nutricion_ingrediente_rel.ingrediente_campo_derivado;
create policy ingrediente_campo_derivado_write_policy on dom_nutricion_ingrediente_rel.ingrediente_campo_derivado
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

drop policy if exists importacion_variable_lote_select_policy on dom_nutricion_ingrediente_rel.importacion_variable_lote;
create policy importacion_variable_lote_select_policy on dom_nutricion_ingrediente_rel.importacion_variable_lote
for select to authenticated
using (public.is_nutrition_editor());

drop policy if exists importacion_variable_lote_write_policy on dom_nutricion_ingrediente_rel.importacion_variable_lote;
create policy importacion_variable_lote_write_policy on dom_nutricion_ingrediente_rel.importacion_variable_lote
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

-- =====================================================
-- reglas y excepciones de etiquetas
-- =====================================================

drop policy if exists campo_derivado_definicion_select_policy on dom_nutricion_reglas.campo_derivado_definicion;
create policy campo_derivado_definicion_select_policy on dom_nutricion_reglas.campo_derivado_definicion
for select to authenticated
using (true);

drop policy if exists campo_derivado_definicion_write_policy on dom_nutricion_reglas.campo_derivado_definicion;
create policy campo_derivado_definicion_write_policy on dom_nutricion_reglas.campo_derivado_definicion
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

drop policy if exists etiqueta_regla_version_select_policy on dom_nutricion_reglas.etiqueta_regla_version;
create policy etiqueta_regla_version_select_policy on dom_nutricion_reglas.etiqueta_regla_version
for select to authenticated
using (true);

drop policy if exists etiqueta_regla_version_write_policy on dom_nutricion_reglas.etiqueta_regla_version;
create policy etiqueta_regla_version_write_policy on dom_nutricion_reglas.etiqueta_regla_version
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

drop policy if exists etiqueta_regla_condicion_select_policy on dom_nutricion_reglas.etiqueta_regla_condicion;
create policy etiqueta_regla_condicion_select_policy on dom_nutricion_reglas.etiqueta_regla_condicion
for select to authenticated
using (true);

drop policy if exists etiqueta_regla_condicion_write_policy on dom_nutricion_reglas.etiqueta_regla_condicion;
create policy etiqueta_regla_condicion_write_policy on dom_nutricion_reglas.etiqueta_regla_condicion
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

drop policy if exists etiqueta_regla_excepcion_select_policy on dom_nutricion_reglas.etiqueta_regla_excepcion;
create policy etiqueta_regla_excepcion_select_policy on dom_nutricion_reglas.etiqueta_regla_excepcion
for select to authenticated
using (true);

drop policy if exists etiqueta_regla_excepcion_write_policy on dom_nutricion_reglas.etiqueta_regla_excepcion;
create policy etiqueta_regla_excepcion_write_policy on dom_nutricion_reglas.etiqueta_regla_excepcion
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

drop policy if exists etiqueta_excepcion_manual_select_policy on dom_nutricion_reglas.etiqueta_excepcion_manual;
create policy etiqueta_excepcion_manual_select_policy on dom_nutricion_reglas.etiqueta_excepcion_manual
for select to authenticated
using (true);

drop policy if exists etiqueta_excepcion_manual_write_policy on dom_nutricion_reglas.etiqueta_excepcion_manual;
create policy etiqueta_excepcion_manual_write_policy on dom_nutricion_reglas.etiqueta_excepcion_manual
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

-- =====================================================
-- trazabilidad y jobs
-- =====================================================

drop policy if exists ingrediente_etiqueta_historial_select_policy on dom_nutricion_ingrediente_rel.ingrediente_etiqueta_historial;
create policy ingrediente_etiqueta_historial_select_policy on dom_nutricion_ingrediente_rel.ingrediente_etiqueta_historial
for select to authenticated
using (public.is_nutrition_editor());

drop policy if exists recalculo_job_select_policy on dom_nutricion_reglas.recalculo_job;
create policy recalculo_job_select_policy on dom_nutricion_reglas.recalculo_job
for select to authenticated
using (public.is_nutrition_editor());

drop policy if exists recalculo_job_write_policy on dom_nutricion_reglas.recalculo_job;
create policy recalculo_job_write_policy on dom_nutricion_reglas.recalculo_job
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

drop policy if exists recalculo_historial_select_policy on dom_nutricion_reglas.recalculo_historial;
create policy recalculo_historial_select_policy on dom_nutricion_reglas.recalculo_historial
for select to authenticated
using (public.is_nutrition_editor());

drop policy if exists recalculo_historial_write_policy on dom_nutricion_reglas.recalculo_historial;
create policy recalculo_historial_write_policy on dom_nutricion_reglas.recalculo_historial
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());

drop policy if exists auditoria_cambio_select_policy on dom_nutricion_reglas.auditoria_cambio;
create policy auditoria_cambio_select_policy on dom_nutricion_reglas.auditoria_cambio
for select to authenticated
using (public.is_nutrition_editor());

drop policy if exists auditoria_cambio_write_policy on dom_nutricion_reglas.auditoria_cambio;
create policy auditoria_cambio_write_policy on dom_nutricion_reglas.auditoria_cambio
for all to authenticated
using (public.is_nutrition_editor())
with check (public.is_nutrition_editor());
