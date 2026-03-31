do $$
declare
	schema_name text;
	domain_schemas text[] := array[
		'dom_auditoria_seguridad',
		'dom_clinica_alergias',
		'dom_clinica_controles',
		'dom_clinica_diagnosticos',
		'dom_clinica_objetivos',
		'dom_compras',
		'dom_experiencia_usuario',
		'dom_identidad_catalogos',
		'dom_identidad_usuarios',
		'dom_nutricion_catalogos',
		'dom_nutricion_ingrediente_rel',
		'dom_nutricion_ingredientes',
		'dom_planes_base',
		'dom_planes_catalogos_estado',
		'dom_planes_catalogos_tipo',
		'dom_planes_permitidos',
		'dom_planes_reemplazos',
		'dom_recetas_analitica',
		'dom_recetas_base',
		'dom_recetas_composicion',
		'dom_referencia_oms',
		'dom_reglas_catalogos',
		'dom_reglas_motor',
		'dom_territorio_catalogos',
		'dom_tutor_acompanamiento'
	];
begin
	foreach schema_name in array domain_schemas loop
		execute format('grant usage on schema %I to authenticated, anon', schema_name);
		execute format('grant select, insert, update, delete on all tables in schema %I to authenticated', schema_name);
		execute format('grant usage, select on all sequences in schema %I to authenticated', schema_name);
		execute format('alter default privileges in schema %I grant select, insert, update, delete on tables to authenticated', schema_name);
		execute format('alter default privileges in schema %I grant usage, select on sequences to authenticated', schema_name);
	end loop;
end
$$;
