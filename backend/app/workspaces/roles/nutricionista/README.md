# Workspace Nutricionista

Rol: permisos de ingredientes, recetas, plan y aprendizaje de preferencias.

Capas a tocar:
- Presentacion API: app/api/v1/endpoints/roles/nutricionista_endpoints.py
- Aplicacion: app/services/roles/nutricionista
- Datos: app/repositories/nutrition_repository.py, app/repositories/interaccion_repository.py

Carpetas de modulos (workspace):
- modules/ingredientes
- modules/recetas
- modules/plan_nutricional
- modules/reglas_nutricionales
- modules/preferencias

Convencion:
- Priorizar reglas nutricionales explicables y consistentes con catalogos dom_*.
- Cada modulo nuevo de nutricionista debe ubicarse dentro de modules/.
