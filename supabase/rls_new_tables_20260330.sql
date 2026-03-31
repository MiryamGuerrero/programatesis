-- =====================================================
-- Reuma Nutri - RLS para tablas nuevas (2026-03-30)
-- Cubre tablas agregadas por ajuste_clinico_nutricional_20260330.sql
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

-- =====================================================
-- Enable RLS in new tables
-- =====================================================
alter table if exists clinico.objetivo_nutricional_paciente enable row level security;
alter table if exists clinico.objetivo_nutricional_nutriente enable row level security;
alter table if exists clinico.objetivo_nutricional_restriccion enable row level security;

alter table if exists nutricion.ingrediente_sinonimo enable row level security;
alter table if exists nutricion.receta_nutriente_resumen enable row level security;
alter table if exists nutricion.momento_compatible enable row level security;
alter table if exists nutricion.receta_reemplazo_equivalente enable row level security;

alter table if exists interaccion.catalogo_nivel_actividad enable row level security;
alter table if exists interaccion.perfil_apoyo_tutor_paciente enable row level security;
alter table if exists interaccion.registro_apoyo_diario enable row level security;
alter table if exists interaccion.nota_tutor_paciente enable row level security;
alter table if exists interaccion.receta_permitida_contexto enable row level security;
alter table if exists interaccion.receta_permitida_item enable row level security;
alter table if exists interaccion.plan_item_reemplazo enable row level security;
alter table if exists interaccion.lista_compra enable row level security;
alter table if exists interaccion.lista_compra_item enable row level security;

-- =====================================================
-- Nutricion: tablas de soporte
-- =====================================================
drop policy if exists ingrediente_sinonimo_select_policy on nutricion.ingrediente_sinonimo;
create policy ingrediente_sinonimo_select_policy on nutricion.ingrediente_sinonimo
for select to authenticated
using (true);

drop policy if exists ingrediente_sinonimo_write_policy on nutricion.ingrediente_sinonimo;
create policy ingrediente_sinonimo_write_policy on nutricion.ingrediente_sinonimo
for all to authenticated
using (public.current_app_role() in ('admin', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'nutricionista'));

drop policy if exists receta_nutriente_resumen_select_policy on nutricion.receta_nutriente_resumen;
create policy receta_nutriente_resumen_select_policy on nutricion.receta_nutriente_resumen
for select to authenticated
using (true);

drop policy if exists receta_nutriente_resumen_write_policy on nutricion.receta_nutriente_resumen;
create policy receta_nutriente_resumen_write_policy on nutricion.receta_nutriente_resumen
for all to authenticated
using (public.current_app_role() in ('admin', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'nutricionista'));

drop policy if exists momento_compatible_select_policy on nutricion.momento_compatible;
create policy momento_compatible_select_policy on nutricion.momento_compatible
for select to authenticated
using (true);

drop policy if exists momento_compatible_write_policy on nutricion.momento_compatible;
create policy momento_compatible_write_policy on nutricion.momento_compatible
for all to authenticated
using (public.current_app_role() in ('admin', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'nutricionista'));

drop policy if exists receta_reemplazo_equivalente_select_policy on nutricion.receta_reemplazo_equivalente;
create policy receta_reemplazo_equivalente_select_policy on nutricion.receta_reemplazo_equivalente
for select to authenticated
using (true);

drop policy if exists receta_reemplazo_equivalente_write_policy on nutricion.receta_reemplazo_equivalente;
create policy receta_reemplazo_equivalente_write_policy on nutricion.receta_reemplazo_equivalente
for all to authenticated
using (public.current_app_role() in ('admin', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'nutricionista'));

-- =====================================================
-- Clinico: objetivo nutricional
-- =====================================================
drop policy if exists objetivo_nutricional_paciente_select_policy on clinico.objetivo_nutricional_paciente;
create policy objetivo_nutricional_paciente_select_policy on clinico.objetivo_nutricional_paciente
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id_paciente)
);

drop policy if exists objetivo_nutricional_paciente_insert_policy on clinico.objetivo_nutricional_paciente;
create policy objetivo_nutricional_paciente_insert_policy on clinico.objetivo_nutricional_paciente
for insert to authenticated
with check (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

drop policy if exists objetivo_nutricional_paciente_update_policy on clinico.objetivo_nutricional_paciente;
create policy objetivo_nutricional_paciente_update_policy on clinico.objetivo_nutricional_paciente
for update to authenticated
using (public.current_app_role() in ('admin', 'medico', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

drop policy if exists objetivo_nutricional_paciente_delete_policy on clinico.objetivo_nutricional_paciente;
create policy objetivo_nutricional_paciente_delete_policy on clinico.objetivo_nutricional_paciente
for delete to authenticated
using (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

drop policy if exists objetivo_nutricional_nutriente_select_policy on clinico.objetivo_nutricional_nutriente;
create policy objetivo_nutricional_nutriente_select_policy on clinico.objetivo_nutricional_nutriente
for select to authenticated
using (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_nutriente.id_objetivo
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(onp.id_paciente)
      )
  )
);

drop policy if exists objetivo_nutricional_nutriente_insert_policy on clinico.objetivo_nutricional_nutriente;
create policy objetivo_nutricional_nutriente_insert_policy on clinico.objetivo_nutricional_nutriente
for insert to authenticated
with check (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_nutriente.id_objetivo
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
);

drop policy if exists objetivo_nutricional_nutriente_update_policy on clinico.objetivo_nutricional_nutriente;
create policy objetivo_nutricional_nutriente_update_policy on clinico.objetivo_nutricional_nutriente
for update to authenticated
using (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_nutriente.id_objetivo
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
)
with check (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_nutriente.id_objetivo
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
);

drop policy if exists objetivo_nutricional_nutriente_delete_policy on clinico.objetivo_nutricional_nutriente;
create policy objetivo_nutricional_nutriente_delete_policy on clinico.objetivo_nutricional_nutriente
for delete to authenticated
using (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_nutriente.id_objetivo
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
);

drop policy if exists objetivo_nutricional_restriccion_select_policy on clinico.objetivo_nutricional_restriccion;
create policy objetivo_nutricional_restriccion_select_policy on clinico.objetivo_nutricional_restriccion
for select to authenticated
using (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_restriccion.id_objetivo
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(onp.id_paciente)
      )
  )
);

drop policy if exists objetivo_nutricional_restriccion_insert_policy on clinico.objetivo_nutricional_restriccion;
create policy objetivo_nutricional_restriccion_insert_policy on clinico.objetivo_nutricional_restriccion
for insert to authenticated
with check (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_restriccion.id_objetivo
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
);

drop policy if exists objetivo_nutricional_restriccion_update_policy on clinico.objetivo_nutricional_restriccion;
create policy objetivo_nutricional_restriccion_update_policy on clinico.objetivo_nutricional_restriccion
for update to authenticated
using (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_restriccion.id_objetivo
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
)
with check (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_restriccion.id_objetivo
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
);

drop policy if exists objetivo_nutricional_restriccion_delete_policy on clinico.objetivo_nutricional_restriccion;
create policy objetivo_nutricional_restriccion_delete_policy on clinico.objetivo_nutricional_restriccion
for delete to authenticated
using (
  exists (
    select 1
    from clinico.objetivo_nutricional_paciente onp
    where onp.id = objetivo_nutricional_restriccion.id_objetivo
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
);

-- =====================================================
-- Interaccion: catalogos y soporte tutor
-- =====================================================
drop policy if exists catalogo_nivel_actividad_select_policy on interaccion.catalogo_nivel_actividad;
create policy catalogo_nivel_actividad_select_policy on interaccion.catalogo_nivel_actividad
for select to authenticated
using (true);

drop policy if exists catalogo_nivel_actividad_write_policy on interaccion.catalogo_nivel_actividad;
create policy catalogo_nivel_actividad_write_policy on interaccion.catalogo_nivel_actividad
for all to authenticated
using (public.current_app_role() in ('admin', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'nutricionista'));

drop policy if exists perfil_apoyo_tutor_select_policy on interaccion.perfil_apoyo_tutor_paciente;
create policy perfil_apoyo_tutor_select_policy on interaccion.perfil_apoyo_tutor_paciente
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists perfil_apoyo_tutor_insert_policy on interaccion.perfil_apoyo_tutor_paciente;
create policy perfil_apoyo_tutor_insert_policy on interaccion.perfil_apoyo_tutor_paciente
for insert to authenticated
with check (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists perfil_apoyo_tutor_update_policy on interaccion.perfil_apoyo_tutor_paciente;
create policy perfil_apoyo_tutor_update_policy on interaccion.perfil_apoyo_tutor_paciente
for update to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
)
with check (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists perfil_apoyo_tutor_delete_policy on interaccion.perfil_apoyo_tutor_paciente;
create policy perfil_apoyo_tutor_delete_policy on interaccion.perfil_apoyo_tutor_paciente
for delete to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists registro_apoyo_diario_select_policy on interaccion.registro_apoyo_diario;
create policy registro_apoyo_diario_select_policy on interaccion.registro_apoyo_diario
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists registro_apoyo_diario_insert_policy on interaccion.registro_apoyo_diario;
create policy registro_apoyo_diario_insert_policy on interaccion.registro_apoyo_diario
for insert to authenticated
with check (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists registro_apoyo_diario_update_policy on interaccion.registro_apoyo_diario;
create policy registro_apoyo_diario_update_policy on interaccion.registro_apoyo_diario
for update to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
)
with check (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists registro_apoyo_diario_delete_policy on interaccion.registro_apoyo_diario;
create policy registro_apoyo_diario_delete_policy on interaccion.registro_apoyo_diario
for delete to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists nota_tutor_paciente_select_policy on interaccion.nota_tutor_paciente;
create policy nota_tutor_paciente_select_policy on interaccion.nota_tutor_paciente
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists nota_tutor_paciente_insert_policy on interaccion.nota_tutor_paciente;
create policy nota_tutor_paciente_insert_policy on interaccion.nota_tutor_paciente
for insert to authenticated
with check (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists nota_tutor_paciente_update_policy on interaccion.nota_tutor_paciente;
create policy nota_tutor_paciente_update_policy on interaccion.nota_tutor_paciente
for update to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
)
with check (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

drop policy if exists nota_tutor_paciente_delete_policy on interaccion.nota_tutor_paciente;
create policy nota_tutor_paciente_delete_policy on interaccion.nota_tutor_paciente
for delete to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or (
    id_usuario_tutor = auth.uid()
    and public.is_tutor_of_patient(id_paciente)
  )
);

-- =====================================================
-- Interaccion: recetas permitidas + reemplazo + compra
-- =====================================================
drop policy if exists receta_permitida_contexto_select_policy on interaccion.receta_permitida_contexto;
create policy receta_permitida_contexto_select_policy on interaccion.receta_permitida_contexto
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id_paciente)
);

drop policy if exists receta_permitida_contexto_write_policy on interaccion.receta_permitida_contexto;
create policy receta_permitida_contexto_write_policy on interaccion.receta_permitida_contexto
for all to authenticated
using (public.current_app_role() in ('admin', 'medico', 'nutricionista'))
with check (public.current_app_role() in ('admin', 'medico', 'nutricionista'));

drop policy if exists receta_permitida_item_select_policy on interaccion.receta_permitida_item;
create policy receta_permitida_item_select_policy on interaccion.receta_permitida_item
for select to authenticated
using (
  exists (
    select 1
    from interaccion.receta_permitida_contexto rpc
    where rpc.id = receta_permitida_item.id_contexto
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(rpc.id_paciente)
      )
  )
);

drop policy if exists receta_permitida_item_write_policy on interaccion.receta_permitida_item;
create policy receta_permitida_item_write_policy on interaccion.receta_permitida_item
for all to authenticated
using (
  exists (
    select 1
    from interaccion.receta_permitida_contexto rpc
    where rpc.id = receta_permitida_item.id_contexto
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
)
with check (
  exists (
    select 1
    from interaccion.receta_permitida_contexto rpc
    where rpc.id = receta_permitida_item.id_contexto
      and public.current_app_role() in ('admin', 'medico', 'nutricionista')
  )
);

drop policy if exists plan_item_reemplazo_select_policy on interaccion.plan_item_reemplazo;
create policy plan_item_reemplazo_select_policy on interaccion.plan_item_reemplazo
for select to authenticated
using (
  exists (
    select 1
    from interaccion.plan_item pi
    inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
    where pi.id = plan_item_reemplazo.id_plan_item
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(pn.id_paciente)
      )
  )
);

drop policy if exists plan_item_reemplazo_insert_policy on interaccion.plan_item_reemplazo;
create policy plan_item_reemplazo_insert_policy on interaccion.plan_item_reemplazo
for insert to authenticated
with check (
  exists (
    select 1
    from interaccion.plan_item pi
    inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
    where pi.id = plan_item_reemplazo.id_plan_item
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or (
          plan_item_reemplazo.id_usuario_tutor = auth.uid()
          and public.is_tutor_of_patient(pn.id_paciente)
        )
      )
  )
);

drop policy if exists plan_item_reemplazo_update_policy on interaccion.plan_item_reemplazo;
create policy plan_item_reemplazo_update_policy on interaccion.plan_item_reemplazo
for update to authenticated
using (
  exists (
    select 1
    from interaccion.plan_item pi
    inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
    where pi.id = plan_item_reemplazo.id_plan_item
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or (
          plan_item_reemplazo.id_usuario_tutor = auth.uid()
          and public.is_tutor_of_patient(pn.id_paciente)
        )
      )
  )
)
with check (
  exists (
    select 1
    from interaccion.plan_item pi
    inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
    where pi.id = plan_item_reemplazo.id_plan_item
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or (
          plan_item_reemplazo.id_usuario_tutor = auth.uid()
          and public.is_tutor_of_patient(pn.id_paciente)
        )
      )
  )
);

drop policy if exists plan_item_reemplazo_delete_policy on interaccion.plan_item_reemplazo;
create policy plan_item_reemplazo_delete_policy on interaccion.plan_item_reemplazo
for delete to authenticated
using (
  exists (
    select 1
    from interaccion.plan_item pi
    inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
    where pi.id = plan_item_reemplazo.id_plan_item
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or (
          plan_item_reemplazo.id_usuario_tutor = auth.uid()
          and public.is_tutor_of_patient(pn.id_paciente)
        )
      )
  )
);

drop policy if exists lista_compra_select_policy on interaccion.lista_compra;
create policy lista_compra_select_policy on interaccion.lista_compra
for select to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id_paciente)
);

drop policy if exists lista_compra_insert_policy on interaccion.lista_compra;
create policy lista_compra_insert_policy on interaccion.lista_compra
for insert to authenticated
with check (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id_paciente)
);

drop policy if exists lista_compra_update_policy on interaccion.lista_compra;
create policy lista_compra_update_policy on interaccion.lista_compra
for update to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id_paciente)
)
with check (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id_paciente)
);

drop policy if exists lista_compra_delete_policy on interaccion.lista_compra;
create policy lista_compra_delete_policy on interaccion.lista_compra
for delete to authenticated
using (
  public.current_app_role() in ('admin', 'medico', 'nutricionista')
  or public.is_tutor_of_patient(id_paciente)
);

drop policy if exists lista_compra_item_select_policy on interaccion.lista_compra_item;
create policy lista_compra_item_select_policy on interaccion.lista_compra_item
for select to authenticated
using (
  exists (
    select 1
    from interaccion.lista_compra lc
    where lc.id = lista_compra_item.id_lista_compra
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(lc.id_paciente)
      )
  )
);

drop policy if exists lista_compra_item_insert_policy on interaccion.lista_compra_item;
create policy lista_compra_item_insert_policy on interaccion.lista_compra_item
for insert to authenticated
with check (
  exists (
    select 1
    from interaccion.lista_compra lc
    where lc.id = lista_compra_item.id_lista_compra
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(lc.id_paciente)
      )
  )
);

drop policy if exists lista_compra_item_update_policy on interaccion.lista_compra_item;
create policy lista_compra_item_update_policy on interaccion.lista_compra_item
for update to authenticated
using (
  exists (
    select 1
    from interaccion.lista_compra lc
    where lc.id = lista_compra_item.id_lista_compra
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(lc.id_paciente)
      )
  )
)
with check (
  exists (
    select 1
    from interaccion.lista_compra lc
    where lc.id = lista_compra_item.id_lista_compra
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(lc.id_paciente)
      )
  )
);

drop policy if exists lista_compra_item_delete_policy on interaccion.lista_compra_item;
create policy lista_compra_item_delete_policy on interaccion.lista_compra_item
for delete to authenticated
using (
  exists (
    select 1
    from interaccion.lista_compra lc
    where lc.id = lista_compra_item.id_lista_compra
      and (
        public.current_app_role() in ('admin', 'medico', 'nutricionista')
        or public.is_tutor_of_patient(lc.id_paciente)
      )
  )
);
