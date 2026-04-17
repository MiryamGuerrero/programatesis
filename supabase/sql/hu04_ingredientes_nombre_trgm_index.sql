-- HU04: Optimiza busqueda por nombre en nutricion.ingrediente (ILIKE)
-- Requiere extension pg_trgm y un indice GIN trigram.

create extension if not exists pg_trgm with schema extensions;

create index if not exists idx_ingrediente_nombre_trgm
    on nutricion.ingrediente
    using gin (nombre gin_trgm_ops);
