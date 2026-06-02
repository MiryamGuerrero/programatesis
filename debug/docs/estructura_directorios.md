# Estructura del Proyecto

`	ext
programatesis/
├── .github
│   ├── java-upgrade
│   │   ├── .gitignore
│   │   └── hooks
│   │       └── scripts
│   │           ├── recordToolUse.ps1
│   │           └── recordToolUse.sh
│   └── modernize
│       └── java-upgrade
│           ├── .gitignore
│           └── hooks
│               └── scripts
│                   ├── recordToolUse.ps1
│                   └── recordToolUse.sh
├── .gitignore
├── backend
│   ├── .backend_fingerprint_web.txt
│   ├── .env
│   ├── app
│   │   ├── __init__.py
│   │   ├── api
│   │   │   ├── __init__.py
│   │   │   ├── deps.py
│   │   │   └── v1
│   │   │       ├── __init__.py
│   │   │       ├── dtos
│   │   │       │   ├── __init__.py
│   │   │       │   ├── clinico.py
│   │   │       │   └── nutricion.py
│   │   │       ├── endpoints
│   │   │       │   ├── __init__.py
│   │   │       │   ├── contexto_autenticacion.py
│   │   │       │   └── roles
│   │   │       │       ├── __init__.py
│   │   │       │       ├── puntos_entrada_admin.py
│   │   │       │       ├── puntos_entrada_compatibilidad.py
│   │   │       │       ├── puntos_entrada_medico.py
│   │   │       │       ├── puntos_entrada_nutricionista.py
│   │   │       │       ├── puntos_entrada_nutricionista_admin.py
│   │   │       │       ├── puntos_entrada_perfil.py
│   │   │       │       └── puntos_entrada_tutor.py
│   │   │       ├── route_registry.py
│   │   │       ├── router.py
│   │   │       └── use_cases.py
│   │   ├── aplicacion
│   │   │   ├── __init__.py
│   │   │   ├── clinica
│   │   │   │   ├── __init__.py
│   │   │   │   ├── gestionar_catalogos.py
│   │   │   │   ├── gestionar_control_clinico.py
│   │   │   │   ├── gestionar_pacientes.py
│   │   │   │   ├── gestionar_perfil_usuario.py
│   │   │   │   ├── gestionar_usuarios.py
│   │   │   │   └── supervisar_adherencia.py
│   │   │   └── nutricion
│   │   │       ├── __init__.py
│   │   │       ├── evaluar_reglas_paciente.py
│   │   │       ├── generar_plan_automatico.py
│   │   │       ├── generar_plan_semanal.py
│   │   │       ├── gestionar_ingredientes.py
│   │   │       ├── gestionar_seguimiento.py
│   │   │       └── gestionar_variables.py
│   │   ├── core
│   │   │   ├── __init__.py
│   │   │   ├── auth_onboarding.py
│   │   │   ├── config.py
│   │   │   ├── db.py
│   │   │   ├── security.py
│   │   │   └── supabase_client.py
│   │   ├── domain
│   │   │   ├── __init__.py
│   │   │   ├── dtos
│   │   │   │   └── __init__.py
│   │   │   ├── excepciones.py
│   │   │   ├── modelos
│   │   │   │   ├── __init__.py
│   │   │   │   ├── clinico.py
│   │   │   │   ├── nutricion.py
│   │   │   │   ├── paciente.py
│   │   │   │   ├── plan_nutricional.py
│   │   │   │   ├── reglas.py
│   │   │   │   ├── seguimiento.py
│   │   │   │   └── usuario.py
│   │   │   ├── repositorios
│   │   │   │   ├── __init__.py
│   │   │   │   └── interfaces.py
│   │   │   └── servicios
│   │   │       ├── __init__.py
│   │   │       ├── resolutor_conflictos.py
│   │   │       ├── restricciones_alimentarias.py
│   │   │       ├── servicio_heuristico.py
│   │   │       ├── servicio_oms.py
│   │   │       └── servicio_planificador.py
│   │   ├── infraestructura
│   │   │   ├── __init__.py
│   │   │   └── repositorios
│   │   │       ├── __init__.py
│   │   │       ├── base.py
│   │   │       ├── repositorio_clinico.py
│   │   │       ├── repositorio_composicion.py
│   │   │       ├── repositorio_ingrediente.py
│   │   │       ├── repositorio_nutricion.py
│   │   │       ├── repositorio_paciente.py
│   │   │       ├── repositorio_perfil.py
│   │   │       ├── repositorio_receta.py
│   │   │       ├── repositorio_regla.py
│   │   │       └── repositorio_seguimiento.py
│   │   ├── main.py
│   │   ├── repositories
│   │   ├── schemas
│   │   └── services
│   │       ├── roles
│   │       │   ├── admin
│   │       │   │   └── modules
│   │       │   │       └── crud
│   │       │   ├── medico
│   │       │   │   └── modules
│   │       │   │       ├── adherencia
│   │       │   │       └── diagnostico_oms
│   │       │   ├── nutricionista
│   │       │   │   └── modules
│   │       │   │       ├── ingredientes
│   │       │   │       ├── plan_nutricional
│   │       │   │       ├── preferencias
│   │       │   │       └── recetas
│   │       │   └── tutor
│   │       │       └── modules
│   │       │           └── reemplazos
│   │       └── shared
│   │           └── cerebro
│   │               ├── calculos_etiquetas
│   │               ├── clasificacion_estado_nutricional_oms
│   │               └── motor_etiquetas_nutricionales
│   ├── requirements.txt
│   ├── scripts
│   │   ├── auto_tag_recipes.py
│   │   ├── cleanup_derived_restriction_allergies.py
│   │   ├── clear_menu_rules.py
│   │   ├── enforce_reumatic_overlap_rules.py
│   │   ├── fix_webp_db_urls.py
│   │   ├── migrate_oms.py
│   │   ├── migrate_referencia.py
│   │   ├── migrate_to_webp.py
│   │   ├── optimize_recipe_storage_images.ps1
│   │   └── reset_referencia_oms.py
│   └── tests
│       ├── test_servicio_oms.py
│       └── test_servicio_oms_exhaustivo.py
├── backup_bd
│   └── backup_schema.sql
├── docs
│   ├── arquitectura_por_capas.md
│   ├── arranque_app.md
│   ├── component_diagram.md
│   ├── estructura_directorios.md
│   ├── historias_de_usuario.md
│   ├── modulos_por_rol_y_capas.md
│   ├── peticion.md
│   ├── referencia_oms_limpia.md
│   ├── reglas_clinicas_actuales.txt
│   ├── reporte_limpieza_overlap_general_reumaticos.txt
│   ├── reporte_overlap_general_reumaticos_audit_20260523_181007.txt
│   ├── reporte_overlap_general_reumaticos_fix_20260523_181011.txt
│   ├── reporte_redundancia_reglas_temporales_nutricionales.txt
│   ├── reporte_redundancia_reglas_temporales_nutricionales_post_limpieza.txt
│   └── reporte_reglas_etiquetas_reumaticas.txt
├── frontend
│   ├── README.md
│   └── flutter_app
│       ├── .flutter-plugins-dependencies
│       ├── .gitignore
│       ├── .metadata
│       ├── README.md
│       ├── analysis_options.yaml
│       ├── assets
│       │   └── images
│       │       ├── .placeholder
│       │       ├── catalogo_condiciones.png
│       │       ├── gestion.png
│       │       ├── gestion_pacientes.png
│       │       ├── kp3.png
│       │       ├── kpi_1.png
│       │       ├── kpi_3.png
│       │       ├── kpi_joint.png
│       │       ├── kpi_total.png
│       │       ├── logo 1.png
│       │       ├── logo sin.png
│       │       ├── modal_icon_mi.png
│       │       ├── nutri_clinic_hero.png
│       │       ├── pacientes.png
│       │       ├── rule_joint_icon.png
│       │       └── rule_temporal_icon.png
│       ├── flutter_01.log
│       ├── flutter_02.log
│       ├── lib
│       │   ├── app.dart
│       │   ├── bootstrap.dart
│       │   ├── core
│       │   │   ├── config
│       │   │   │   └── app_config.dart
│       │   │   ├── network
│       │   │   │   └── api_client.dart
│       │   │   ├── services
│       │   │   │   ├── realtime_service.dart
│       │   │   │   └── recipe_image_service.dart
│       │   │   ├── session
│       │   │   │   ├── session_lock.dart
│       │   │   │   ├── session_lock_stub.dart
│       │   │   │   └── session_lock_web.dart
│       │   │   ├── state
│       │   │   │   ├── app_providers.dart
│       │   │   │   └── notification_provider.dart
│       │   │   └── theme
│       │   │       └── app_theme.dart
│       │   ├── escalas_demo_entry.dart
│       │   ├── features
│       │   │   ├── admin
│       │   │   │   ├── data
│       │   │   │   │   └── admin_accounts_supabase_repository.dart
│       │   │   │   └── modules
│       │   │   │       ├── catalogos
│       │   │   │       │   ├── .gitkeep
│       │   │   │       │   └── admin_catalogs_page.dart
│       │   │   │       ├── debug
│       │   │   │       │   └── debug_auth_page.dart
│       │   │   │       └── usuarios
│       │   │   │           ├── .gitkeep
│       │   │   │           ├── admin_tutors_page.dart
│       │   │   │           └── admin_users_page.dart
│       │   │   ├── auth
│       │   │   │   ├── login_page.dart
│       │   │   │   └── set_password_page.dart
│       │   │   ├── medico
│       │   │   │   ├── data
│       │   │   │   │   ├── repositorio_medico.dart
│       │   │   │   │   └── supervision_provider.dart
│       │   │   │   ├── modules
│       │   │   │   │   ├── _shared
│       │   │   │   │   │   └── medico_section_placeholder_page.dart
│       │   │   │   │   ├── adherencia
│       │   │   │   │   │   └── .gitkeep
│       │   │   │   │   ├── alergias_condiciones
│       │   │   │   │   │   └── alergias_condiciones_page.dart
│       │   │   │   │   ├── catalogo_condiciones
│       │   │   │   │   │   ├── catalogo_condiciones_page.dart
│       │   │   │   │   │   └── condiciones_medicas_page.dart
│       │   │   │   │   ├── consulta_evolucion
│       │   │   │   │   │   └── consulta_evolucion_page.dart
│       │   │   │   │   ├── diagnostico_oms
│       │   │   │   │   │   ├── .gitkeep
│       │   │   │   │   │   └── diagnostico_page.dart
│       │   │   │   │   ├── registro_clinico
│       │   │   │   │   │   ├── .gitkeep
│       │   │   │   │   │   └── registro_clinico_page.dart
│       │   │   │   │   └── reglas_medicas
│       │   │   │   │       ├── .gitkeep
│       │   │   │   │       └── reglas_medicas_page.dart
│       │   │   │   └── presentation
│       │   │   │       ├── control_mensual_page.dart.backup
│       │   │   │       ├── patient_detail_modal.dart
│       │   │   │       ├── registro_mensual_page.dart
│       │   │   │       ├── registro_paciente_page.dart
│       │   │   │       └── supervision_pacientes_page.dart
│       │   │   ├── nutricionista
│       │   │   │   └── modules
│       │   │   │       ├── condiciones
│       │   │   │       │   └── condiciones_nutricionales_page.dart
│       │   │   │       ├── configuracion_menu
│       │   │   │       │   └── configuracion_menu_page.dart
│       │   │   │       ├── etiquetas
│       │   │   │       │   ├── etiqueta_form_page.dart
│       │   │   │       │   ├── etiquetas_gestion_page.dart
│       │   │   │       │   ├── etiquetas_page.dart
│       │   │   │       │   └── widgets
│       │   │   │       │       └── etiqueta_card.dart
│       │   │   │       ├── ingredientes
│       │   │   │       │   ├── .gitkeep
│       │   │   │       │   ├── ingrediente_detalle_page.dart
│       │   │   │       │   ├── ingrediente_form_page.dart
│       │   │   │       │   ├── ingredientes_page.dart
│       │   │   │       │   └── models
│       │   │   │       │       └── ingrediente_model.dart
│       │   │   │       ├── plan_nutricional
│       │   │   │       │   ├── .gitkeep
│       │   │   │       │   └── plan_manual_page.dart
│       │   │   │       ├── preferencias
│       │   │   │       │   └── .gitkeep
│       │   │   │       ├── recetas
│       │   │   │       │   ├── .gitkeep
│       │   │   │       │   ├── receta_detalle_page.dart
│       │   │   │       │   ├── receta_form_page.dart
│       │   │   │       │   ├── recetas_page.dart
│       │   │   │       │   └── widgets
│       │   │   │       │       ├── receta_card.dart
│       │   │   │       │       └── selector_ingrediente_dialog.dart
│       │   │   │       └── reglas_nutricionales
│       │   │   │           ├── .gitkeep
│       │   │   │           └── reglas_nutricionales_page.dart
│       │   │   ├── perfil
│       │   │   │   └── perfil_page.dart
│       │   │   ├── roles
│       │   │   │   ├── role_module.dart
│       │   │   │   └── role_module_registry.dart
│       │   │   ├── shared
│       │   │   │   └── widgets
│       │   │   │       ├── expediente_paciente_page.dart
│       │   │   │       ├── gestion_pacientes_page.dart
│       │   │   │       └── registrar_paciente_page.dart
│       │   │   └── tutor
│       │   │       ├── data
│       │   │       │   ├── repositorio_tutor.dart
│       │   │       │   ├── seguimiento_provider.dart
│       │   │       │   └── tutor_repository.dart
│       │   │       ├── modules
│       │   │       │   ├── calificacion
│       │   │       │   │   ├── .gitkeep
│       │   │       │   │   └── calificacion_page.dart
│       │   │       │   ├── consumo
│       │   │       │   │   ├── .gitkeep
│       │   │       │   │   └── consumo_page.dart
│       │   │       │   ├── plan
│       │   │       │   │   ├── .gitkeep
│       │   │       │   │   └── plan_page.dart
│       │   │       │   └── reemplazos
│       │   │       │       ├── .gitkeep
│       │   │       │       └── reemplazo_page.dart
│       │   │       └── presentation
│       │   │           ├── gestion_tutores_pacientes_page.dart
│       │   │           ├── mis_pacientes_page.dart
│       │   │           ├── onboarding_gustos_page.dart
│       │   │           ├── plan_diario_page.dart
│       │   │           ├── registro_tutor_page.dart
│       │   │           ├── tutor_calendario_page.dart
│       │   │           ├── tutor_compras_page.dart
│       │   │           ├── tutor_gustos_page.dart
│       │   │           ├── tutor_home_page.dart
│       │   │           ├── tutor_mockup_pacientes_page.dart
│       │   │           ├── tutor_perfil_page.dart
│       │   │           ├── tutor_receta_detalle_page.dart
│       │   │           ├── tutor_recetas_page.dart
│       │   │           └── widgets
│       │   │               └── generar_plan_automatico_modal.dart
│       │   ├── main.dart
│       │   ├── main_tutor_mobile.dart
│       │   ├── main_web.dart
│       │   ├── shared
│       │   │   ├── models
│       │   │   │   └── app_role.dart
│       │   │   ├── repositories
│       │   │   │   ├── inteligencia_api_repository.dart
│       │   │   │   └── supabase_crud_repository.dart
│       │   │   └── widgets
│       │   │       ├── escalas
│       │   │       │   ├── escala_selector.dart
│       │   │       │   └── escalas_demo.dart
│       │   │       ├── layout_components.dart
│       │   │       ├── layout_components.txt
│       │   │       ├── module_ux.dart
│       │   │       ├── nutri_avatar.dart
│       │   │       ├── patient_summary_panel.dart
│       │   │       ├── role_shell.dart
│       │   │       └── tutor_mobile_shell.dart
│       │   └── tutor_mobile_app.dart
│       ├── pubspec.lock
│       └── pubspec.yaml
├── generate_tree.py
├── moocks
│   ├── Gestion de pacientes.png
│   ├── MODAL ENFERMEDADES REUMATICAS.png
│   ├── SINTOMAS TEMPORALES.png
│   ├── alergias.png
│   ├── art.png
│   ├── catalogo condiciones .png
│   ├── control mensual.png
│   ├── escala dolor.png
│   ├── expediente.jpeg
│   ├── gestion condiciones.png
│   ├── gestion.png
│   ├── identidad del paciente.png
│   ├── kp3.png
│   ├── kpi 1.png
│   ├── kpis.png
│   ├── kpis2.png
│   ├── mi.png
│   ├── modal condiciones temporales.png
│   ├── modal regla.png
│   ├── modulo gestion de condiciones.png
│   ├── moock1 modal crear menu.png
│   ├── pacientes.png
│   ├── plan manual.png
│   ├── reglas medicas.png
│   ├── represtante mensaje encontro.png
│   ├── seccion actividad enfermedad.png
│   ├── seccion variables clinicas.png
│   ├── seccion_Alergias.png
│   ├── temporal.png
│   └── tutor no encontrado.png
├── oms
│   ├── README.md
│   ├── condicion.csv
│   ├── oms_clasificacion_zscore.csv
│   ├── oms_fuente_archivo.csv
│   ├── oms_indicador.csv
│   ├── oms_referencia_percentil.csv
│   ├── oms_referencia_zscore.csv
│   ├── prompt_algoritmo_estado_nutricional.txt
│   ├── resumen_generacion.json
│   └── schema_referencia.sql
├── oms_referencia_csvs_COMPLETO
│   ├── AVISO_REVISION_COMPLETA.txt
│   ├── crear_tablas_referencia.sql
│   ├── fuente_referencia.csv
│   ├── importacion_oms_log.csv
│   ├── indicador_antropometrico.csv
│   ├── oms_clasificacion_zscore.csv
│   ├── oms_curva.csv
│   ├── oms_curva_percentil.csv
│   ├── oms_curva_punto.csv
│   ├── oms_curva_zscore.csv
│   └── orden_carga_y_validacion.sql
├── start_tutor_mobile.ps1
├── start_web.ps1
├── supabase
│   ├── functions
│   │   ├── plan-inteligente
│   │   │   └── index.ts
│   │   ├── recomendacion-puntual
│   │   │   └── index.ts
│   │   └── reemplazo-equivalente
│   │       └── index.ts
│   └── sql
│       ├── etiquetas_lactosa.sql
│       ├── fix_jwt_role_metadata.sql
│       ├── hu01_admin_accounts_read_rpc.sql
│       ├── hu01_security_hardening.sql
│       ├── hu01_sensitive_data_encryption.sql
│       ├── hu02_auth_user_delete_sync.sql
│       ├── hu02_etiquetado_subetiqueta_hierarchy.sql
│       ├── hu03_remove_etiquetado_automatico.sql
│       ├── hu04_ingredientes_nombre_trgm_index.sql
│       ├── hu05_ingrediente_imagen_referencia_text.sql
│       ├── hu06_combinaciones_menu_reutilizables.sql
│       ├── hu07_reglas_menu_combinacion_condiciones.sql
│       ├── hu08_planificacion_rendimiento.sql
│       ├── hu09_recetas_seguras_paciente_rapidas.sql
│       ├── hu10_recetas_seguras_refuerzo_indices.sql
│       ├── hu11_subgrupos_emoji.sql
│       ├── hu_reumatic_rules_only_blocking.sql
│       ├── migracion_cantones_parroquias.sql
│       └── refactorizar_subgrupos_alergias.sql
└── web.ps1
`
