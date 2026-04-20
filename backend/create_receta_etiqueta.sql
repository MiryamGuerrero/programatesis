-- Crear tabla para etiquetas de recetas
create table if not exists nutricion.receta_etiqueta (
    id serial primary key,
    id_receta int not null references nutricion.receta(id) on delete cascade,
    id_etiqueta int not null references nutricion.etiqueta_nutricional(id) on delete cascade,
    created_at timestamp default current_timestamp,
    unique(id_receta, id_etiqueta)
);
