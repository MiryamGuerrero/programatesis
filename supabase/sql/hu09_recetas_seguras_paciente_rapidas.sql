-- HU09: Indices para cargar recetas seguras del paciente sin llamadas N+1.

create index if not exists idx_receta_etiqueta_receta
  on nutricion.receta_etiqueta (id_receta, id_etiqueta);

create index if not exists idx_etiqueta_nutricional_codigo
  on nutricion.etiqueta_nutricional (codigo);

create index if not exists idx_diagnostico_paciente_activo
  on clinico.diagnostico_paciente (id_paciente, esta_activo, id_condicion);

create index if not exists idx_control_condicion_activa_control
  on clinico.control_condicion_activa (id_control, esta_activa, id_condicion);

create index if not exists idx_condicion_regla_condicion
  on heuristico.condicion_regla (id_condicion, id_regla);

create index if not exists idx_regla_accion_componentes
  on heuristico.regla (
    id_accion,
    id_receta,
    id_ingrediente,
    id_subgrupo_alimentario,
    id_grupo_alimentario,
    id_etiqueta
  );

create index if not exists idx_restriccion_paciente_activa
  on clinico.restriccion_paciente (id_paciente, activa, codigo_restriccion);
