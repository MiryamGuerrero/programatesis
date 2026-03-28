-- =====================================================
-- Reuma Nutri - RLS Policies by app role
-- IMPORTANT:
-- 1) Add schemas to Supabase API exposed schemas:
--    usuarios, clinico, nutricion, interaccion, heuristico, referencia
-- 2) Ensure JWT includes app_metadata.role with values:
--    admin, medico, nutricionista, tutor
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

create or replace function public.is_tutor_of_patient(paciente_id uuid)
returns boolean
language sql
stable
as $$
  select exists(
    select 1
    from usuarios.tutor_paciente tp
    where tp.id_usuario_tutor = auth.uid()
      and tp.id_paciente = paciente_id
  )
$$;

grant execute on function public.current_app_role() to authenticated;
grant execute on function public.is_tutor_of_patient(uuid) to authenticated;

grant usage on schema usuarios, clinico, nutricion, interaccion, heuristico, referencia to authenticated;

-- =====================================================
-- Enable RLS
-- =====================================================
alter table usuarios.usuario enable row level security;
alter table usuarios.paciente enable row level security;
alter table usuarios.tutor_paciente enable row level security;
alter table clinico.control_paciente enable row level security;
alter table nutricion.ingrediente enable row level security;
alter table nutricion.receta enable row level security;
alter table interaccion.plan_nutricional enable row level security;
alter table interaccion.plan_item enable row level security;
alter table interaccion.seguimiento_plan_item enable row level security;
alter table interaccion.evaluacion_receta enable row level security;
alter table interaccion.preferencia_receta enable row level security;
alter table interaccion.preferencia_ingrediente enable row level security;

-- =====================================================
-- usuarios.usuario
-- =====================================================
create policy usuarios_select_policy on usuarios.usuario
for select to authenticated
using (
  public.current_app_role() = 'admin'
  or id = auth.uid()
);

create policy usuarios_insert_admin_policy on usuarios.usuario
for insert to authenticated
with check (public.current_app_role() = 'admin');

create policy usuarios_update_admin_policy on usuarios.usuario
for update to authenticated
using (public.current_app_role() = 'admin')
with check (public.current_app_role() = 'admin');

-- =====================================================
-- usuarios.paciente
-- =====================================================
create policy paciente_select_policy on usuarios.paciente
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id)
);

create policy paciente_write_profesional_policy on usuarios.paciente
for all to authenticated
using (public.current_app_role() in ('admin', 'medico', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

-- =====================================================
-- usuarios.tutor_paciente
-- =====================================================
create policy tutor_paciente_select_policy on usuarios.tutor_paciente
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or id_usuario_tutor = auth.uid()
);

create policy tutor_paciente_write_policy on usuarios.tutor_paciente
for all to authenticated
using (public.current_app_role() in ('admin', 'medico', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

-- =====================================================
-- clinico.control_paciente
-- =====================================================
create policy control_paciente_select_policy on clinico.control_paciente
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id_paciente)
);

create policy control_paciente_insert_policy on clinico.control_paciente
for insert to authenticated
with check (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

create policy control_paciente_update_policy on clinico.control_paciente
for update to authenticated
using (public.current_app_role() in ('admin', 'medico', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

-- =====================================================
-- nutricion.ingrediente + receta
-- =====================================================
create policy ingrediente_select_policy on nutricion.ingrediente
for select to authenticated
using (true);

create policy ingrediente_write_policy on nutricion.ingrediente
for all to authenticated
using (public.current_app_role() in ('admin', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'nutricionista'));

create policy receta_select_policy on nutricion.receta
for select to authenticated
using (true);

create policy receta_write_policy on nutricion.receta
for all to authenticated
using (public.current_app_role() in ('admin', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'nutricionista'));

-- =====================================================
-- interaccion.plan_nutricional + plan_item
-- =====================================================
create policy plan_select_policy on interaccion.plan_nutricional
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id_paciente)
);

create policy plan_write_policy on interaccion.plan_nutricional
for all to authenticated
using (public.current_app_role() in ('admin', 'medico', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

create policy plan_item_select_policy on interaccion.plan_item
for select to authenticated
using (
  exists (
    select 1
    from interaccion.plan_nutricional pn
    where pn.id = plan_item.id_plan
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(pn.id_paciente)
      )
  )
);

create policy plan_item_write_policy on interaccion.plan_item
for all to authenticated
using (public.current_app_role() in ('admin', 'medico', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

-- =====================================================
-- seguimiento + evaluacion + preferencias
-- =====================================================
create policy seguimiento_select_policy on interaccion.seguimiento_plan_item
for select to authenticated
using (
  exists (
    select 1
    from interaccion.plan_item pi
    inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
    where pi.id = seguimiento_plan_item.id_plan_item
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(pn.id_paciente)
      )
  )
);

create policy seguimiento_insert_tutor_policy on interaccion.seguimiento_plan_item
for insert to authenticated
with check (
  exists (
    select 1
    from interaccion.plan_item pi
    inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
    where pi.id = seguimiento_plan_item.id_plan_item
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(pn.id_paciente)
      )
  )
);

create policy seguimiento_update_tutor_policy on interaccion.seguimiento_plan_item
for update to authenticated
using (
  exists (
    select 1
    from interaccion.plan_item pi
    inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
    where pi.id = seguimiento_plan_item.id_plan_item
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(pn.id_paciente)
      )
  )
)
with check (
  exists (
    select 1
    from interaccion.plan_item pi
    inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
    where pi.id = seguimiento_plan_item.id_plan_item
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(pn.id_paciente)
      )
  )
);

create policy evaluacion_select_policy on interaccion.evaluacion_receta
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or id_paciente in (
    select tp.id_paciente
    from usuarios.tutor_paciente tp
    where tp.id_usuario_tutor = auth.uid()
  )
);

create policy evaluacion_insert_policy on interaccion.evaluacion_receta
for insert to authenticated
with check (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or id_paciente in (
    select tp.id_paciente
    from usuarios.tutor_paciente tp
    where tp.id_usuario_tutor = auth.uid()
  )
);

create policy preferencia_receta_policy on interaccion.preferencia_receta
for all to authenticated
using (
  public.current_app_role() in ('admin', 'nutricionista')
  or id_paciente in (
    select tp.id_paciente
    from usuarios.tutor_paciente tp
    where tp.id_usuario_tutor = auth.uid()
  )
)
with check (
  public.current_app_role() in ('admin', 'nutricionista')
  or id_paciente in (
    select tp.id_paciente
    from usuarios.tutor_paciente tp
    where tp.id_usuario_tutor = auth.uid()
  )
);

create policy preferencia_ingrediente_policy on interaccion.preferencia_ingrediente
for all to authenticated
using (
  public.current_app_role() in ('admin', 'nutricionista')
  or id_paciente in (
    select tp.id_paciente
    from usuarios.tutor_paciente tp
    where tp.id_usuario_tutor = auth.uid()
  )
)
with check (
  public.current_app_role() in ('admin', 'nutricionista')
  or id_paciente in (
    select tp.id_paciente
    from usuarios.tutor_paciente tp
    where tp.id_usuario_tutor = auth.uid()
  )
);
