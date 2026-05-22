-- HU08: Optimización de rendimiento para expediente y planificación nutricional
-- Ejecutar en entorno Supabase/PostgreSQL.

-- 1) Validación nutricional mensual
create index if not exists idx_validacion_control_paciente_periodo
  on clinico.validacion_control_nutricional_mensual (id_paciente, anio desc, mes desc);

-- 2) Control mensual por paciente (último control)
create index if not exists idx_control_paciente_fecha
  on clinico.control_paciente (id_paciente, fecha_control desc, id desc);

-- 3) Recomendaciones de ingredientes activas por paciente
create index if not exists idx_recomendacion_paciente_activa
  on clinico.recomendacion_ingrediente (id_paciente, activa, id_ingrediente);

-- 4) Alergias por paciente (ingrediente y subgrupo)
create index if not exists idx_alergia_ing_paciente_activa
  on clinico.alergia_paciente_ingrediente (id_paciente, activa, id_ingrediente);

create index if not exists idx_alergia_sub_paciente_activa
  on clinico.alergia_paciente_subgrupo (id_paciente, activa, id_subgrupo_alimentario);

-- 5) Plan y plan items por paciente/fecha
create index if not exists idx_plan_paciente_created
  on interaccion.plan_nutricional (id_paciente, created_at desc, id desc);

create index if not exists idx_plan_item_plan_fecha_momento
  on interaccion.plan_item (id_plan, fecha_programada, id_momento);

-- 6) Recetas para filtrado rápido por momento y tipo
create index if not exists idx_receta_momento_receta
  on nutricion.receta_momento (id_momento, id_receta);

create index if not exists idx_receta_tipo_plato_tipo_receta
  on nutricion.receta_tipo_plato (id_tipo_plato, id_receta);

create index if not exists idx_receta_ingrediente_receta
  on nutricion.receta_ingrediente (id_receta, id_ingrediente);

-- 7) Ingredientes activos por subgrupo/nombre
create index if not exists idx_ingrediente_activo_subgrupo
  on nutricion.ingrediente (activo, id_subgrupo_alimentario, id);

create index if not exists idx_ingrediente_nombre_lower
  on nutricion.ingrediente (lower(nombre));

-- 8) Vista para lectura rápida de recomendaciones activas por paciente
create or replace view clinico.v_recomendaciones_activas_paciente as
select
  ri.id_paciente,
  ri.id_ingrediente,
  i.nombre as ingrediente_nombre,
  ri.id_rol_recomienda,
  ri.id_profesional,
  ri.motivo,
  ri.prioridad,
  ri.fecha_recomendacion
from clinico.recomendacion_ingrediente ri
join nutricion.ingrediente i on i.id = ri.id_ingrediente
where ri.activa = true;

