create table if not exists nutricion.regla_menu_combinacion (
  id bigserial primary key,
  id_momento integer not null references nutricion.momento_comida(id) on delete cascade,
  rol text not null,
  platillos jsonb not null default '[]'::jsonb,
  platillos_key text not null,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id_momento, rol, platillos_key)
);

create table if not exists nutricion.regla_menu_combinacion_condicion (
  id_regla_menu_combinacion bigint not null
    references nutricion.regla_menu_combinacion(id) on delete cascade,
  id_condicion_nutricional integer not null
    references heuristico.condicion(id) on delete restrict,
  primary key (id_regla_menu_combinacion, id_condicion_nutricional)
);
