-- HU05: Permite guardar referencia de imagen del ingrediente como texto (URL/path/base64 texto)
-- No almacena binarios en la base, solo referencia textual.

alter table nutricion.ingrediente
    add column if not exists imagen_referencia text;
