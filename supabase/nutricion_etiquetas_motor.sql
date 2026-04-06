-- =====================================================
-- Reuma Nutri - Motor de Ingredientes, Variables y Etiquetas
-- Fecha: 2026-04-04
-- Objetivo: Soportar importacion desde datosal/Ingredientes.xlsx,
--           versionado de reglas, trazabilidad y recalculo automatico.
-- =====================================================

begin;

create schema if not exists dom_nutricion_reglas;

-- =====================================================
-- Helpers
-- =====================================================

create or replace function dom_nutricion_reglas.fn_set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

-- =====================================================
-- Catalogos de clasificacion alimentaria
-- =====================================================

create table if not exists dom_nutricion_catalogos.subgrupo_alimentario (
    id serial primary key,
    id_grupo_alimentario integer not null references dom_nutricion_catalogos.grupo_alimentario(id),
    nombre varchar(150) not null,
    descripcion text,
    activo boolean not null default true,
    created_at timestamp not null default now(),
    updated_at timestamp not null default now()
);

create unique index if not exists ux_subgrupo_alimentario_grupo_nombre
    on dom_nutricion_catalogos.subgrupo_alimentario (id_grupo_alimentario, lower(btrim(nombre)));

create index if not exists idx_subgrupo_alimentario_grupo
    on dom_nutricion_catalogos.subgrupo_alimentario (id_grupo_alimentario);

alter table dom_nutricion_ingredientes.ingrediente
    add column if not exists codigo_externo varchar(60),
    add column if not exists nombre_ingles varchar(180),
    add column if not exists id_subgrupo_alimentario integer,
    add column if not exists unidad_base varchar(30),
    add column if not exists porcion_referencia_g numeric(12,4),
    add column if not exists parte_comestible_factor numeric(8,5),
    add column if not exists estado_ingrediente varchar(30),
    add column if not exists nivel_procesamiento varchar(60),
    add column if not exists precio_referencia numeric(12,4),
    add column if not exists unidad_precio varchar(30),
    add column if not exists peso_unidad_referencia_g numeric(12,4),
    add column if not exists fuente_registro varchar(40) not null default 'manual',
    add column if not exists fecha_importacion timestamp,
    add column if not exists version_fuente varchar(40);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ingrediente_id_subgrupo_alimentario_fkey'
    ) then
        alter table dom_nutricion_ingredientes.ingrediente
            add constraint ingrediente_id_subgrupo_alimentario_fkey
            foreign key (id_subgrupo_alimentario)
            references dom_nutricion_catalogos.subgrupo_alimentario(id);
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ingrediente_parte_comestible_factor'
    ) then
        alter table dom_nutricion_ingredientes.ingrediente
            add constraint ck_ingrediente_parte_comestible_factor
            check (parte_comestible_factor is null or (parte_comestible_factor >= 0 and parte_comestible_factor <= 1));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ingrediente_peso_unidad_ref'
    ) then
        alter table dom_nutricion_ingredientes.ingrediente
            add constraint ck_ingrediente_peso_unidad_ref
            check (peso_unidad_referencia_g is null or peso_unidad_referencia_g >= 0);
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ingrediente_precio_referencia'
    ) then
        alter table dom_nutricion_ingredientes.ingrediente
            add constraint ck_ingrediente_precio_referencia
            check (precio_referencia is null or precio_referencia >= 0);
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ingrediente_fuente_registro'
    ) then
        alter table dom_nutricion_ingredientes.ingrediente
            add constraint ck_ingrediente_fuente_registro
            check (fuente_registro in ('manual', 'excel', 'csv', 'api', 'sistema'));
    end if;
end $$;

create unique index if not exists ux_ingrediente_codigo_externo
    on dom_nutricion_ingredientes.ingrediente (codigo_externo)
    where codigo_externo is not null;

create index if not exists idx_ingrediente_subgrupo
    on dom_nutricion_ingredientes.ingrediente (id_subgrupo_alimentario);

-- =====================================================
-- Catalogo configurable de variables nutricionales
-- =====================================================

create table if not exists dom_nutricion_catalogos.variable_nutricional (
    id bigserial primary key,
    codigo varchar(120) not null,
    nombre_visible varchar(180) not null,
    tipo_dato varchar(20) not null default 'numeric',
    clasificacion varchar(80),
    categoria_funcional varchar(80),
    unidad varchar(40),
    descripcion text,
    hoja_origen varchar(100),
    columna_origen varchar(120),
    origen_catalogo varchar(30) not null default 'excel',
    es_calculable boolean not null default false,
    participa_en_calculos boolean not null default false,
    participa_en_reglas boolean not null default false,
    permite_nulos boolean not null default true,
    ausencia_bloquea_etiqueta boolean not null default false,
    activo boolean not null default true,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamp not null default now(),
    updated_at timestamp not null default now()
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_variable_nutricional_tipo_dato'
    ) then
        alter table dom_nutricion_catalogos.variable_nutricional
            add constraint ck_variable_nutricional_tipo_dato
            check (tipo_dato in ('numeric', 'text', 'boolean', 'date', 'json'));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_variable_nutricional_origen'
    ) then
        alter table dom_nutricion_catalogos.variable_nutricional
            add constraint ck_variable_nutricional_origen
            check (origen_catalogo in ('excel', 'manual', 'csv', 'api', 'sistema'));
    end if;
end $$;

create unique index if not exists ux_variable_nutricional_codigo
    on dom_nutricion_catalogos.variable_nutricional (lower(codigo));

create index if not exists idx_variable_nutricional_categoria
    on dom_nutricion_catalogos.variable_nutricional (categoria_funcional, clasificacion);

-- =====================================================
-- Valores por ingrediente (EAV controlado)
-- =====================================================

create table if not exists dom_nutricion_ingrediente_rel.importacion_variable_lote (
    id bigserial primary key,
    tipo_carga varchar(20) not null,
    archivo_nombre text,
    hash_archivo varchar(128),
    estado varchar(20) not null default 'pendiente',
    total_registros integer not null default 0,
    registros_ok integer not null default 0,
    registros_error integer not null default 0,
    detalle_error jsonb,
    creado_por uuid references dom_identidad_usuarios.usuario(id),
    created_at timestamp not null default now(),
    updated_at timestamp not null default now()
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_importacion_variable_tipo_carga'
    ) then
        alter table dom_nutricion_ingrediente_rel.importacion_variable_lote
            add constraint ck_importacion_variable_tipo_carga
            check (tipo_carga in ('manual', 'csv', 'excel', 'api', 'sistema'));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_importacion_variable_estado'
    ) then
        alter table dom_nutricion_ingrediente_rel.importacion_variable_lote
            add constraint ck_importacion_variable_estado
            check (estado in ('pendiente', 'procesando', 'aplicado', 'error'));
    end if;
end $$;

create table if not exists dom_nutricion_ingrediente_rel.ingrediente_variable_valor (
    id bigserial primary key,
    id_ingrediente integer not null references dom_nutricion_ingredientes.ingrediente(id) on delete cascade,
    id_variable_nutricional bigint not null references dom_nutricion_catalogos.variable_nutricional(id),
    valor_numerico numeric(18,6),
    valor_texto text,
    valor_booleano boolean,
    valor_fecha date,
    valor_json jsonb,
    estado_dato varchar(30) not null default 'valor_real',
    origen_asignacion varchar(40) not null default 'manual',
    es_fuente_primaria boolean not null default true,
    id_importacion_lote bigint references dom_nutricion_ingrediente_rel.importacion_variable_lote(id),
    version_fuente varchar(40),
    justificacion text,
    observacion text,
    creado_por uuid references dom_identidad_usuarios.usuario(id),
    actualizado_por uuid references dom_identidad_usuarios.usuario(id),
    created_at timestamp not null default now(),
    updated_at timestamp not null default now(),
    unique (id_ingrediente, id_variable_nutricional)
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ing_var_valor_estado_dato'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_variable_valor
            add constraint ck_ing_var_valor_estado_dato
            check (estado_dato in (
                'valor_real',
                'no_reportado',
                'no_aplica',
                'pendiente',
                'invalido',
                'insuficiente_dato'
            ));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ing_var_valor_origen'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_variable_valor
            add constraint ck_ing_var_valor_origen
            check (origen_asignacion in (
                'importada_desde_excel',
                'automatica',
                'manual',
                'csv',
                'api',
                'sistema'
            ));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ing_var_valor_unico_tipo'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_variable_valor
            add constraint ck_ing_var_valor_unico_tipo
            check (
                ((valor_numerico is not null)::int
                + (valor_texto is not null)::int
                + (valor_booleano is not null)::int
                + (valor_fecha is not null)::int
                + (valor_json is not null)::int) <= 1
            );
    end if;
end $$;

create index if not exists idx_ing_var_valor_ingrediente
    on dom_nutricion_ingrediente_rel.ingrediente_variable_valor (id_ingrediente);

create index if not exists idx_ing_var_valor_variable
    on dom_nutricion_ingrediente_rel.ingrediente_variable_valor (id_variable_nutricional);

create index if not exists idx_ing_var_valor_estado
    on dom_nutricion_ingrediente_rel.ingrediente_variable_valor (estado_dato);

alter table dom_nutricion_ingrediente_rel.ingrediente_nutriente
    add column if not exists estado_dato varchar(30) not null default 'valor_real',
    add column if not exists origen_asignacion varchar(40) not null default 'manual',
    add column if not exists observacion text,
    add column if not exists updated_at timestamp not null default now();

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ingrediente_nutriente_estado_dato'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_nutriente
            add constraint ck_ingrediente_nutriente_estado_dato
            check (estado_dato in (
                'valor_real',
                'no_reportado',
                'no_aplica',
                'pendiente',
                'invalido',
                'insuficiente_dato'
            ));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ingrediente_nutriente_origen_asignacion'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_nutriente
            add constraint ck_ingrediente_nutriente_origen_asignacion
            check (origen_asignacion in (
                'importada_desde_excel',
                'automatica',
                'manual',
                'csv',
                'api',
                'sistema'
            ));
    end if;
end $$;

-- =====================================================
-- Definicion y resultados de campos derivados
-- =====================================================

create table if not exists dom_nutricion_reglas.campo_derivado_definicion (
    id bigserial primary key,
    codigo varchar(120) not null,
    nombre_visible varchar(180) not null,
    descripcion text,
    columnas_origen text[] not null default '{}'::text[],
    formula_conceptual text not null,
    formula_excel_original text,
    unidad varchar(40),
    validaciones jsonb not null default '{}'::jsonb,
    politica_dato_faltante varchar(30) not null default 'insuficiente_dato',
    persistir_resultado boolean not null default true,
    etiquetas_alimentadas text[] not null default '{}'::text[],
    excepciones jsonb not null default '[]'::jsonb,
    version integer not null default 1,
    orden integer,
    activo boolean not null default true,
    created_at timestamp not null default now(),
    updated_at timestamp not null default now()
);

create unique index if not exists ux_campo_derivado_codigo
    on dom_nutricion_reglas.campo_derivado_definicion (lower(codigo));

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_campo_derivado_politica_faltante'
    ) then
        alter table dom_nutricion_reglas.campo_derivado_definicion
            add constraint ck_campo_derivado_politica_faltante
            check (politica_dato_faltante in (
                'insuficiente_dato',
                'no_aplica',
                'pendiente',
                'calcular_con_cero'
            ));
    end if;
end $$;

create table if not exists dom_nutricion_ingrediente_rel.ingrediente_campo_derivado (
    id bigserial primary key,
    id_ingrediente integer not null references dom_nutricion_ingredientes.ingrediente(id) on delete cascade,
    id_campo_derivado bigint not null references dom_nutricion_reglas.campo_derivado_definicion(id),
    valor_numerico numeric(18,6),
    valor_texto text,
    estado_calculo varchar(30) not null default 'pendiente',
    detalle_estado text,
    campos_faltantes text[] not null default '{}'::text[],
    version_calculo integer,
    trace_calculo jsonb not null default '{}'::jsonb,
    fecha_calculo timestamp,
    created_at timestamp not null default now(),
    updated_at timestamp not null default now(),
    unique (id_ingrediente, id_campo_derivado)
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ing_campo_derivado_estado'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_campo_derivado
            add constraint ck_ing_campo_derivado_estado
            check (estado_calculo in (
                'calculado',
                'pendiente',
                'insuficiente_dato',
                'excluido',
                'excepcion_manual',
                'no_aplica',
                'error'
            ));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ing_campo_derivado_unico_tipo'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_campo_derivado
            add constraint ck_ing_campo_derivado_unico_tipo
            check (((valor_numerico is not null)::int + (valor_texto is not null)::int) <= 1);
    end if;
end $$;

create index if not exists idx_ing_campo_derivado_ingrediente
    on dom_nutricion_ingrediente_rel.ingrediente_campo_derivado (id_ingrediente);

create index if not exists idx_ing_campo_derivado_estado
    on dom_nutricion_ingrediente_rel.ingrediente_campo_derivado (estado_calculo);

-- =====================================================
-- Definicion de etiquetas y reglas versionadas
-- =====================================================

alter table dom_nutricion_catalogos.etiqueta_nutricional
    add column if not exists categoria varchar(80),
    add column if not exists subcategoria varchar(80),
    add column if not exists descripcion text,
    add column if not exists tipo_etiqueta varchar(20) not null default 'automatica',
    add column if not exists prioridad integer not null default 100,
    add column if not exists color_hex varchar(9),
    add column if not exists activa boolean not null default true,
    add column if not exists objetivo_clinico text,
    add column if not exists interpretacion_base text,
    add column if not exists admite_correccion_manual boolean not null default true,
    add column if not exists persistir_resultado boolean not null default true,
    add column if not exists created_at timestamp not null default now(),
    add column if not exists updated_at timestamp not null default now();

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_tipo_etiqueta'
    ) then
        alter table dom_nutricion_catalogos.etiqueta_nutricional
            add constraint ck_etiqueta_tipo_etiqueta
            check (tipo_etiqueta in ('automatica', 'manual', 'mixta'));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_color_hex'
    ) then
        alter table dom_nutricion_catalogos.etiqueta_nutricional
            add constraint ck_etiqueta_color_hex
            check (color_hex is null or color_hex ~* '^#([0-9a-f]{6}|[0-9a-f]{8})$');
    end if;
end $$;

create table if not exists dom_nutricion_reglas.etiqueta_regla_version (
    id bigserial primary key,
    id_etiqueta integer not null references dom_nutricion_catalogos.etiqueta_nutricional(id) on delete cascade,
    version integer not null,
    codigo_regla varchar(120) not null,
    nombre_regla varchar(180) not null,
    estado varchar(20) not null default 'borrador',
    tipo_regla varchar(20) not null default 'automatica',
    prioridad integer not null default 100,
    expresion_json jsonb,
    expresion_humana text,
    formula_excel_original text,
    campos_intervienen text[] not null default '{}'::text[],
    umbral_resumen jsonb not null default '{}'::jsonb,
    fecha_inicio_vigencia date,
    fecha_fin_vigencia date,
    es_importada_excel boolean not null default false,
    activo boolean not null default true,
    created_by uuid references dom_identidad_usuarios.usuario(id),
    created_at timestamp not null default now(),
    updated_at timestamp not null default now(),
    unique (id_etiqueta, version)
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_regla_estado'
    ) then
        alter table dom_nutricion_reglas.etiqueta_regla_version
            add constraint ck_etiqueta_regla_estado
            check (estado in ('borrador', 'activa', 'inactiva', 'archivada'));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_regla_tipo'
    ) then
        alter table dom_nutricion_reglas.etiqueta_regla_version
            add constraint ck_etiqueta_regla_tipo
            check (tipo_regla in ('automatica', 'manual', 'mixta'));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_regla_rango_fechas'
    ) then
        alter table dom_nutricion_reglas.etiqueta_regla_version
            add constraint ck_etiqueta_regla_rango_fechas
            check (
                fecha_fin_vigencia is null
                or fecha_inicio_vigencia is null
                or fecha_fin_vigencia >= fecha_inicio_vigencia
            );
    end if;
end $$;

create unique index if not exists ux_etiqueta_regla_codigo_version
    on dom_nutricion_reglas.etiqueta_regla_version (lower(codigo_regla), version);

create index if not exists idx_etiqueta_regla_estado
    on dom_nutricion_reglas.etiqueta_regla_version (estado, activo);

create table if not exists dom_nutricion_reglas.etiqueta_regla_condicion (
    id bigserial primary key,
    id_regla_version bigint not null references dom_nutricion_reglas.etiqueta_regla_version(id) on delete cascade,
    orden integer not null,
    grupo_logico integer not null default 1,
    conector_grupo varchar(3) not null default 'AND',
    tipo_condicion varchar(40) not null,
    id_variable_nutricional bigint references dom_nutricion_catalogos.variable_nutricional(id),
    operador varchar(20),
    valor_numero numeric(18,6),
    valor_numero_min numeric(18,6),
    valor_numero_max numeric(18,6),
    valor_texto text,
    valor_lista text[],
    campo_objetivo varchar(180),
    negado boolean not null default false,
    descripcion_humana text,
    condicion_json jsonb not null default '{}'::jsonb,
    activa boolean not null default true,
    created_at timestamp not null default now(),
    updated_at timestamp not null default now(),
    unique (id_regla_version, orden)
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_condicion_conector'
    ) then
        alter table dom_nutricion_reglas.etiqueta_regla_condicion
            add constraint ck_etiqueta_condicion_conector
            check (conector_grupo in ('AND', 'OR'));
    end if;
end $$;

create index if not exists idx_etiqueta_condicion_regla
    on dom_nutricion_reglas.etiqueta_regla_condicion (id_regla_version, activa);

create table if not exists dom_nutricion_reglas.etiqueta_regla_excepcion (
    id bigserial primary key,
    id_regla_version bigint not null references dom_nutricion_reglas.etiqueta_regla_version(id) on delete cascade,
    id_ingrediente integer references dom_nutricion_ingredientes.ingrediente(id),
    patron_nombre text,
    accion_excepcion varchar(30) not null,
    valor_etiqueta_override text,
    motivo text,
    activa boolean not null default true,
    created_by uuid references dom_identidad_usuarios.usuario(id),
    created_at timestamp not null default now(),
    updated_at timestamp not null default now()
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_regla_excepcion_accion'
    ) then
        alter table dom_nutricion_reglas.etiqueta_regla_excepcion
            add constraint ck_etiqueta_regla_excepcion_accion
            check (accion_excepcion in ('forzar_asignacion', 'excluir_asignacion', 'reemplazar_resultado'));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_regla_excepcion_target'
    ) then
        alter table dom_nutricion_reglas.etiqueta_regla_excepcion
            add constraint ck_etiqueta_regla_excepcion_target
            check (id_ingrediente is not null or patron_nombre is not null);
    end if;
end $$;

create index if not exists idx_etiqueta_regla_excepcion_regla
    on dom_nutricion_reglas.etiqueta_regla_excepcion (id_regla_version, activa);

create table if not exists dom_nutricion_reglas.etiqueta_excepcion_manual (
    id bigserial primary key,
    id_ingrediente integer not null references dom_nutricion_ingredientes.ingrediente(id) on delete cascade,
    id_etiqueta integer not null references dom_nutricion_catalogos.etiqueta_nutricional(id) on delete cascade,
    accion varchar(20) not null,
    justificacion text not null,
    motivo_clinico text,
    activa boolean not null default true,
    fecha_inicio timestamp not null default now(),
    fecha_fin timestamp,
    id_usuario uuid references dom_identidad_usuarios.usuario(id),
    created_at timestamp not null default now(),
    updated_at timestamp not null default now()
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_excepcion_manual_accion'
    ) then
        alter table dom_nutricion_reglas.etiqueta_excepcion_manual
            add constraint ck_etiqueta_excepcion_manual_accion
            check (accion in ('quitar', 'forzar', 'invalidar'));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_etiqueta_excepcion_manual_fechas'
    ) then
        alter table dom_nutricion_reglas.etiqueta_excepcion_manual
            add constraint ck_etiqueta_excepcion_manual_fechas
            check (fecha_fin is null or fecha_fin >= fecha_inicio);
    end if;
end $$;

create index if not exists idx_etiqueta_excepcion_manual_lookup
    on dom_nutricion_reglas.etiqueta_excepcion_manual (id_ingrediente, id_etiqueta, activa);

-- =====================================================
-- Asignacion de etiquetas a ingredientes (estado actual)
-- =====================================================

alter table dom_nutricion_ingrediente_rel.ingrediente_etiqueta
    add column if not exists activa boolean not null default true,
    add column if not exists origen_asignacion varchar(40) not null default 'automatica',
    add column if not exists id_regla_version bigint,
    add column if not exists version_regla integer,
    add column if not exists valor_justificacion jsonb not null default '{}'::jsonb,
    add column if not exists estado_calculo varchar(30) not null default 'calculado',
    add column if not exists es_precalculada_excel boolean not null default false,
    add column if not exists manual_override boolean not null default false,
    add column if not exists motivo_manual text,
    add column if not exists id_usuario_modificacion uuid,
    add column if not exists fecha_asignacion timestamp not null default now(),
    add column if not exists fecha_calculo timestamp,
    add column if not exists updated_at timestamp not null default now();

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'ingrediente_etiqueta_id_regla_version_fkey'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_etiqueta
            add constraint ingrediente_etiqueta_id_regla_version_fkey
            foreign key (id_regla_version)
            references dom_nutricion_reglas.etiqueta_regla_version(id);
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ingrediente_etiqueta_id_usuario_modificacion_fkey'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_etiqueta
            add constraint ingrediente_etiqueta_id_usuario_modificacion_fkey
            foreign key (id_usuario_modificacion)
            references dom_identidad_usuarios.usuario(id);
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ingrediente_etiqueta_origen_asignacion'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_etiqueta
            add constraint ck_ingrediente_etiqueta_origen_asignacion
            check (origen_asignacion in (
                'importada_desde_excel',
                'automatica',
                'manual',
                'csv',
                'api',
                'sistema'
            ));
    end if;

    if not exists (
        select 1 from pg_constraint
        where conname = 'ck_ingrediente_etiqueta_estado_calculo'
    ) then
        alter table dom_nutricion_ingrediente_rel.ingrediente_etiqueta
            add constraint ck_ingrediente_etiqueta_estado_calculo
            check (estado_calculo in (
                'calculado',
                'pendiente',
                'insuficiente_dato',
                'excluido',
                'excepcion_manual',
                'no_aplica',
                'error'
            ));
    end if;
end $$;

create index if not exists idx_ingrediente_etiqueta_activa
    on dom_nutricion_ingrediente_rel.ingrediente_etiqueta (id_ingrediente, activa);

create index if not exists idx_ingrediente_etiqueta_origen
    on dom_nutricion_ingrediente_rel.ingrediente_etiqueta (origen_asignacion, estado_calculo);

create table if not exists dom_nutricion_ingrediente_rel.ingrediente_etiqueta_historial (
    id bigserial primary key,
    id_ingrediente integer not null,
    id_etiqueta integer not null,
    activa boolean,
    origen_asignacion varchar(40),
    id_regla_version bigint,
    version_regla integer,
    estado_calculo varchar(30),
    es_precalculada_excel boolean,
    manual_override boolean,
    motivo_manual text,
    id_usuario_modificacion uuid,
    valor_justificacion jsonb,
    fecha_asignacion timestamp,
    fecha_calculo timestamp,
    evento varchar(20) not null,
    changed_at timestamp not null default now()
);

create index if not exists idx_ing_etq_historial_ingrediente
    on dom_nutricion_ingrediente_rel.ingrediente_etiqueta_historial (id_ingrediente, changed_at desc);

create index if not exists idx_ing_etq_historial_etiqueta
    on dom_nutricion_ingrediente_rel.ingrediente_etiqueta_historial (id_etiqueta, changed_at desc);

create or replace function dom_nutricion_reglas.fn_log_ingrediente_etiqueta_historial()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'DELETE' then
        insert into dom_nutricion_ingrediente_rel.ingrediente_etiqueta_historial (
            id_ingrediente,
            id_etiqueta,
            activa,
            origen_asignacion,
            id_regla_version,
            version_regla,
            estado_calculo,
            es_precalculada_excel,
            manual_override,
            motivo_manual,
            id_usuario_modificacion,
            valor_justificacion,
            fecha_asignacion,
            fecha_calculo,
            evento
        )
        values (
            old.id_ingrediente,
            old.id_etiqueta,
            old.activa,
            old.origen_asignacion,
            old.id_regla_version,
            old.version_regla,
            old.estado_calculo,
            old.es_precalculada_excel,
            old.manual_override,
            old.motivo_manual,
            old.id_usuario_modificacion,
            old.valor_justificacion,
            old.fecha_asignacion,
            old.fecha_calculo,
            'delete'
        );
        return old;
    end if;

    insert into dom_nutricion_ingrediente_rel.ingrediente_etiqueta_historial (
        id_ingrediente,
        id_etiqueta,
        activa,
        origen_asignacion,
        id_regla_version,
        version_regla,
        estado_calculo,
        es_precalculada_excel,
        manual_override,
        motivo_manual,
        id_usuario_modificacion,
        valor_justificacion,
        fecha_asignacion,
        fecha_calculo,
        evento
    )
    values (
        new.id_ingrediente,
        new.id_etiqueta,
        new.activa,
        new.origen_asignacion,
        new.id_regla_version,
        new.version_regla,
        new.estado_calculo,
        new.es_precalculada_excel,
        new.manual_override,
        new.motivo_manual,
        new.id_usuario_modificacion,
        new.valor_justificacion,
        new.fecha_asignacion,
        new.fecha_calculo,
        lower(tg_op)
    );

    return new;
end;
$$;

drop trigger if exists trg_log_ingrediente_etiqueta_historial
    on dom_nutricion_ingrediente_rel.ingrediente_etiqueta;

create trigger trg_log_ingrediente_etiqueta_historial
after insert or update or delete on dom_nutricion_ingrediente_rel.ingrediente_etiqueta
for each row execute function dom_nutricion_reglas.fn_log_ingrediente_etiqueta_historial();

-- =====================================================
-- Recalculo: jobs y auditoria
-- =====================================================

create table if not exists dom_nutricion_reglas.recalculo_job (
    id bigserial primary key,
    alcance varchar(20) not null,
    id_ingrediente integer references dom_nutricion_ingredientes.ingrediente(id),
    id_etiqueta integer references dom_nutricion_catalogos.etiqueta_nutricional(id),
    id_regla_version bigint references dom_nutricion_reglas.etiqueta_regla_version(id),
    estado varchar(20) not null default 'pendiente',
    solicitado_desde varchar(30) not null default 'sistema',
    solicitado_por uuid references dom_identidad_usuarios.usuario(id),
    worker_name varchar(80),
    parametros jsonb not null default '{}'::jsonb,
    resumen jsonb,
    solicitado_at timestamp not null default now(),
    iniciado_at timestamp,
    finalizado_at timestamp,
    created_at timestamp not null default now(),
    updated_at timestamp not null default now()
);

do $$
begin
    if not exists (
        select 1 from pg_constraint where conname = 'ck_recalculo_job_alcance'
    ) then
        alter table dom_nutricion_reglas.recalculo_job
            add constraint ck_recalculo_job_alcance
            check (alcance in ('ingrediente', 'etiqueta', 'regla', 'masivo'));
    end if;

    if not exists (
        select 1 from pg_constraint where conname = 'ck_recalculo_job_estado'
    ) then
        alter table dom_nutricion_reglas.recalculo_job
            add constraint ck_recalculo_job_estado
            check (estado in ('pendiente', 'procesando', 'completado', 'error', 'cancelado'));
    end if;

    if not exists (
        select 1 from pg_constraint where conname = 'ck_recalculo_job_origen'
    ) then
        alter table dom_nutricion_reglas.recalculo_job
            add constraint ck_recalculo_job_origen
            check (solicitado_desde in ('trigger', 'rpc', 'api', 'sistema', 'importacion'));
    end if;
end $$;

create index if not exists idx_recalculo_job_estado_fecha
    on dom_nutricion_reglas.recalculo_job (estado, solicitado_at);

create index if not exists idx_recalculo_job_ingrediente
    on dom_nutricion_reglas.recalculo_job (id_ingrediente, estado);

create unique index if not exists ux_recalculo_job_pendiente_ingrediente
    on dom_nutricion_reglas.recalculo_job (id_ingrediente)
    where alcance = 'ingrediente' and estado in ('pendiente', 'procesando') and id_ingrediente is not null;

create table if not exists dom_nutricion_reglas.recalculo_historial (
    id bigserial primary key,
    id_recalculo_job bigint not null references dom_nutricion_reglas.recalculo_job(id) on delete cascade,
    id_ingrediente integer references dom_nutricion_ingredientes.ingrediente(id),
    id_etiqueta integer references dom_nutricion_catalogos.etiqueta_nutricional(id),
    estado_resultado varchar(30) not null,
    detalle text,
    payload jsonb,
    created_at timestamp not null default now()
);

do $$
begin
    if not exists (
        select 1 from pg_constraint where conname = 'ck_recalculo_historial_estado'
    ) then
        alter table dom_nutricion_reglas.recalculo_historial
            add constraint ck_recalculo_historial_estado
            check (estado_resultado in (
                'calculado',
                'pendiente',
                'insuficiente_dato',
                'excluido',
                'excepcion_manual',
                'no_aplica',
                'error'
            ));
    end if;
end $$;

create index if not exists idx_recalculo_historial_job
    on dom_nutricion_reglas.recalculo_historial (id_recalculo_job, created_at desc);

create table if not exists dom_nutricion_reglas.auditoria_cambio (
    id bigserial primary key,
    entidad varchar(50) not null,
    id_entidad varchar(80) not null,
    accion varchar(20) not null,
    detalle jsonb,
    changed_by uuid references dom_identidad_usuarios.usuario(id),
    changed_at timestamp not null default now()
);

-- =====================================================
-- Triggers de recálculo automatico
-- =====================================================

create or replace function dom_nutricion_reglas.fn_enqueue_recalculo_ingrediente()
returns trigger
language plpgsql
as $$
declare
    v_id_ingrediente integer;
begin
    if tg_table_name = 'ingrediente' then
        v_id_ingrediente := coalesce(new.id, old.id);
    else
        v_id_ingrediente := coalesce(new.id_ingrediente, old.id_ingrediente);
    end if;

    if v_id_ingrediente is null then
        return coalesce(new, old);
    end if;

    insert into dom_nutricion_reglas.recalculo_job (
        alcance,
        id_ingrediente,
        estado,
        solicitado_desde,
        parametros
    )
    select
        'ingrediente',
        v_id_ingrediente,
        'pendiente',
        'trigger',
        jsonb_build_object(
            'tabla', tg_table_schema || '.' || tg_table_name,
            'operacion', tg_op
        )
    where not exists (
        select 1
        from dom_nutricion_reglas.recalculo_job j
        where j.alcance = 'ingrediente'
          and j.id_ingrediente = v_id_ingrediente
          and j.estado in ('pendiente', 'procesando')
    );

    return coalesce(new, old);
end;
$$;

drop trigger if exists trg_enqueue_recalculo_from_variable
    on dom_nutricion_ingrediente_rel.ingrediente_variable_valor;

create trigger trg_enqueue_recalculo_from_variable
after insert or update on dom_nutricion_ingrediente_rel.ingrediente_variable_valor
for each row execute function dom_nutricion_reglas.fn_enqueue_recalculo_ingrediente();

drop trigger if exists trg_enqueue_recalculo_from_nutriente
    on dom_nutricion_ingrediente_rel.ingrediente_nutriente;

create trigger trg_enqueue_recalculo_from_nutriente
after insert or update on dom_nutricion_ingrediente_rel.ingrediente_nutriente
for each row execute function dom_nutricion_reglas.fn_enqueue_recalculo_ingrediente();

drop trigger if exists trg_enqueue_recalculo_from_ingrediente
    on dom_nutricion_ingredientes.ingrediente;

create trigger trg_enqueue_recalculo_from_ingrediente
after insert or update on dom_nutricion_ingredientes.ingrediente
for each row execute function dom_nutricion_reglas.fn_enqueue_recalculo_ingrediente();

-- =====================================================
-- RPCs de gestion de recálculo
-- =====================================================

create or replace function dom_nutricion_reglas.rpc_solicitar_recalculo_ingrediente(
    p_id_ingrediente integer,
    p_solicitado_por uuid default null,
    p_forzar boolean default false,
    p_parametros jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
as $$
declare
    v_job_id bigint;
begin
    if p_id_ingrediente is null then
        raise exception 'p_id_ingrediente es requerido';
    end if;

    if not p_forzar then
        select id into v_job_id
        from dom_nutricion_reglas.recalculo_job
        where alcance = 'ingrediente'
          and id_ingrediente = p_id_ingrediente
          and estado in ('pendiente', 'procesando')
        order by id desc
        limit 1;

        if v_job_id is not null then
            return v_job_id;
        end if;
    end if;

    insert into dom_nutricion_reglas.recalculo_job (
        alcance,
        id_ingrediente,
        estado,
        solicitado_desde,
        solicitado_por,
        parametros
    ) values (
        'ingrediente',
        p_id_ingrediente,
        'pendiente',
        'rpc',
        p_solicitado_por,
        coalesce(p_parametros, '{}'::jsonb)
    )
    returning id into v_job_id;

    return v_job_id;
end;
$$;

create or replace function dom_nutricion_reglas.rpc_solicitar_recalculo_etiqueta(
    p_id_etiqueta integer,
    p_solicitado_por uuid default null,
    p_forzar boolean default false,
    p_parametros jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
as $$
declare
    v_job_id bigint;
begin
    if p_id_etiqueta is null then
        raise exception 'p_id_etiqueta es requerido';
    end if;

    if not p_forzar then
        select id into v_job_id
        from dom_nutricion_reglas.recalculo_job
        where alcance = 'etiqueta'
          and id_etiqueta = p_id_etiqueta
          and estado in ('pendiente', 'procesando')
        order by id desc
        limit 1;

        if v_job_id is not null then
            return v_job_id;
        end if;
    end if;

    insert into dom_nutricion_reglas.recalculo_job (
        alcance,
        id_etiqueta,
        estado,
        solicitado_desde,
        solicitado_por,
        parametros
    ) values (
        'etiqueta',
        p_id_etiqueta,
        'pendiente',
        'rpc',
        p_solicitado_por,
        coalesce(p_parametros, '{}'::jsonb)
    )
    returning id into v_job_id;

    return v_job_id;
end;
$$;

create or replace function dom_nutricion_reglas.rpc_solicitar_recalculo_masivo(
    p_solicitado_por uuid default null,
    p_parametros jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
as $$
declare
    v_job_id bigint;
begin
    insert into dom_nutricion_reglas.recalculo_job (
        alcance,
        estado,
        solicitado_desde,
        solicitado_por,
        parametros
    ) values (
        'masivo',
        'pendiente',
        'rpc',
        p_solicitado_por,
        coalesce(p_parametros, '{}'::jsonb)
    )
    returning id into v_job_id;

    return v_job_id;
end;
$$;

create or replace function dom_nutricion_reglas.rpc_tomar_recalculo_job(
    p_worker_name varchar default 'fastapi'
)
returns table (
    id bigint,
    alcance varchar,
    id_ingrediente integer,
    id_etiqueta integer,
    id_regla_version bigint,
    parametros jsonb
)
language plpgsql
as $$
begin
    return query
    with picked as (
        select j.id
        from dom_nutricion_reglas.recalculo_job j
        where j.estado = 'pendiente'
        order by j.solicitado_at asc
        limit 1
        for update skip locked
    )
    update dom_nutricion_reglas.recalculo_job j
    set estado = 'procesando',
        iniciado_at = now(),
        worker_name = p_worker_name,
        updated_at = now()
    where j.id in (select picked.id from picked)
    returning j.id, j.alcance, j.id_ingrediente, j.id_etiqueta, j.id_regla_version, j.parametros;
end;
$$;

create or replace function dom_nutricion_reglas.rpc_cerrar_recalculo_job(
    p_id_job bigint,
    p_estado_final varchar,
    p_resumen jsonb default '{}'::jsonb
)
returns void
language plpgsql
as $$
begin
    update dom_nutricion_reglas.recalculo_job
    set estado = p_estado_final,
        resumen = coalesce(p_resumen, '{}'::jsonb),
        finalizado_at = now(),
        updated_at = now()
    where id = p_id_job;
end;
$$;

create or replace function dom_nutricion_reglas.rpc_registrar_recalculo_historial(
    p_id_recalculo_job bigint,
    p_id_ingrediente integer,
    p_id_etiqueta integer,
    p_estado_resultado varchar,
    p_detalle text,
    p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
as $$
begin
    insert into dom_nutricion_reglas.recalculo_historial (
        id_recalculo_job,
        id_ingrediente,
        id_etiqueta,
        estado_resultado,
        detalle,
        payload
    ) values (
        p_id_recalculo_job,
        p_id_ingrediente,
        p_id_etiqueta,
        p_estado_resultado,
        p_detalle,
        coalesce(p_payload, '{}'::jsonb)
    );
end;
$$;

create or replace function dom_nutricion_reglas.rpc_upsert_ingrediente_etiqueta(
    p_id_ingrediente integer,
    p_id_etiqueta integer,
    p_origen_asignacion varchar default 'automatica',
    p_id_regla_version bigint default null,
    p_version_regla integer default null,
    p_valor_justificacion jsonb default '{}'::jsonb,
    p_estado_calculo varchar default 'calculado',
    p_es_precalculada_excel boolean default false,
    p_manual_override boolean default false,
    p_motivo_manual text default null,
    p_id_usuario_modificacion uuid default null,
    p_fecha_calculo timestamp default now()
)
returns void
language plpgsql
as $$
begin
    insert into dom_nutricion_ingrediente_rel.ingrediente_etiqueta (
        id_ingrediente,
        id_etiqueta,
        activa,
        origen_asignacion,
        id_regla_version,
        version_regla,
        valor_justificacion,
        estado_calculo,
        es_precalculada_excel,
        manual_override,
        motivo_manual,
        id_usuario_modificacion,
        fecha_asignacion,
        fecha_calculo,
        updated_at
    ) values (
        p_id_ingrediente,
        p_id_etiqueta,
        true,
        p_origen_asignacion,
        p_id_regla_version,
        p_version_regla,
        coalesce(p_valor_justificacion, '{}'::jsonb),
        p_estado_calculo,
        p_es_precalculada_excel,
        p_manual_override,
        p_motivo_manual,
        p_id_usuario_modificacion,
        now(),
        p_fecha_calculo,
        now()
    )
    on conflict (id_ingrediente, id_etiqueta)
    do update set
        activa = excluded.activa,
        origen_asignacion = excluded.origen_asignacion,
        id_regla_version = excluded.id_regla_version,
        version_regla = excluded.version_regla,
        valor_justificacion = excluded.valor_justificacion,
        estado_calculo = excluded.estado_calculo,
        es_precalculada_excel = excluded.es_precalculada_excel,
        manual_override = excluded.manual_override,
        motivo_manual = excluded.motivo_manual,
        id_usuario_modificacion = excluded.id_usuario_modificacion,
        fecha_calculo = excluded.fecha_calculo,
        updated_at = now();
end;
$$;

create or replace function dom_nutricion_reglas.rpc_inactivar_ingrediente_etiqueta(
    p_id_ingrediente integer,
    p_id_etiqueta integer,
    p_motivo text,
    p_id_usuario_modificacion uuid default null
)
returns void
language plpgsql
as $$
begin
    update dom_nutricion_ingrediente_rel.ingrediente_etiqueta
    set activa = false,
        estado_calculo = 'excluido',
        manual_override = true,
        motivo_manual = p_motivo,
        id_usuario_modificacion = p_id_usuario_modificacion,
        updated_at = now()
    where id_ingrediente = p_id_ingrediente
      and id_etiqueta = p_id_etiqueta;
end;
$$;

-- =====================================================
-- Triggers updated_at
-- =====================================================

drop trigger if exists trg_set_updated_at_subgrupo
    on dom_nutricion_catalogos.subgrupo_alimentario;
create trigger trg_set_updated_at_subgrupo
before update on dom_nutricion_catalogos.subgrupo_alimentario
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_variable_nutricional
    on dom_nutricion_catalogos.variable_nutricional;
create trigger trg_set_updated_at_variable_nutricional
before update on dom_nutricion_catalogos.variable_nutricional
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_importacion_variable_lote
    on dom_nutricion_ingrediente_rel.importacion_variable_lote;
create trigger trg_set_updated_at_importacion_variable_lote
before update on dom_nutricion_ingrediente_rel.importacion_variable_lote
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_ing_var_valor
    on dom_nutricion_ingrediente_rel.ingrediente_variable_valor;
create trigger trg_set_updated_at_ing_var_valor
before update on dom_nutricion_ingrediente_rel.ingrediente_variable_valor
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_campo_derivado_def
    on dom_nutricion_reglas.campo_derivado_definicion;
create trigger trg_set_updated_at_campo_derivado_def
before update on dom_nutricion_reglas.campo_derivado_definicion
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_ing_campo_derivado
    on dom_nutricion_ingrediente_rel.ingrediente_campo_derivado;
create trigger trg_set_updated_at_ing_campo_derivado
before update on dom_nutricion_ingrediente_rel.ingrediente_campo_derivado
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_etiqueta_nutricional
    on dom_nutricion_catalogos.etiqueta_nutricional;
create trigger trg_set_updated_at_etiqueta_nutricional
before update on dom_nutricion_catalogos.etiqueta_nutricional
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_etiqueta_regla_version
    on dom_nutricion_reglas.etiqueta_regla_version;
create trigger trg_set_updated_at_etiqueta_regla_version
before update on dom_nutricion_reglas.etiqueta_regla_version
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_etiqueta_regla_condicion
    on dom_nutricion_reglas.etiqueta_regla_condicion;
create trigger trg_set_updated_at_etiqueta_regla_condicion
before update on dom_nutricion_reglas.etiqueta_regla_condicion
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_etiqueta_regla_excepcion
    on dom_nutricion_reglas.etiqueta_regla_excepcion;
create trigger trg_set_updated_at_etiqueta_regla_excepcion
before update on dom_nutricion_reglas.etiqueta_regla_excepcion
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_etiqueta_excepcion_manual
    on dom_nutricion_reglas.etiqueta_excepcion_manual;
create trigger trg_set_updated_at_etiqueta_excepcion_manual
before update on dom_nutricion_reglas.etiqueta_excepcion_manual
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_ingrediente_etiqueta
    on dom_nutricion_ingrediente_rel.ingrediente_etiqueta;
create trigger trg_set_updated_at_ingrediente_etiqueta
before update on dom_nutricion_ingrediente_rel.ingrediente_etiqueta
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

drop trigger if exists trg_set_updated_at_recalculo_job
    on dom_nutricion_reglas.recalculo_job;
create trigger trg_set_updated_at_recalculo_job
before update on dom_nutricion_reglas.recalculo_job
for each row execute function dom_nutricion_reglas.fn_set_updated_at();

commit;
