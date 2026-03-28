-- Basic catalog seed for app bootstrap

insert into usuarios.rol (nombre)
values ('Admin'), ('Medico'), ('Nutricionista'), ('Tutor')
on conflict (nombre) do nothing;

insert into usuarios.catalogo_sexo (codigo, descripcion)
values ('M', 'Masculino'), ('F', 'Femenino')
on conflict (codigo) do nothing;

insert into heuristico.catalogo_accion (codigo, peso_puntaje)
values ('ELIMINAR', -100), ('REDUCIR', -50), ('PRIORIZAR', 50)
on conflict (codigo) do nothing;

insert into heuristico.catalogo_objetivo_regla (codigo)
values ('INGREDIENTE'), ('GRUPO_ALIMENTARIO'), ('ETIQUETA')
on conflict (codigo) do nothing;

insert into interaccion.catalogo_estado_plan (codigo)
values ('ACTIVO'), ('PAUSADO'), ('CERRADO')
on conflict (codigo) do nothing;

insert into interaccion.catalogo_tipo_plan (codigo)
values ('MANUAL'), ('AUTOMATICO')
on conflict (codigo) do nothing;

insert into interaccion.catalogo_origen_plan (codigo)
values ('MEDICO'), ('NUTRICIONISTA'), ('SISTEMA')
on conflict (codigo) do nothing;

insert into interaccion.catalogo_estado_consumo (codigo)
values ('NO_CONSUMIDO'), ('CONSUMIDO_PARCIAL'), ('CONSUMIDO_COMPLETO')
on conflict (codigo) do nothing;
