# Workspace Medico

Rol: evaluacion clinica, antropometria y adherencia.

Capas a tocar:
- Presentacion API: app/api/v1/endpoints/roles/medico_endpoints.py
- Aplicacion: app/services/roles/medico
- Datos: app/repositories/clinical_repository.py, app/repositories/interaccion_repository.py

Carpetas de modulos (workspace):
- modules/registro_clinico
- modules/diagnostico_oms
- modules/reglas_medicas
- modules/adherencia

Convencion:
- Mantener respuestas orientadas a contexto clinico y trazabilidad de diagnostico.
- Cada modulo nuevo de medico debe ubicarse dentro de modules/.
