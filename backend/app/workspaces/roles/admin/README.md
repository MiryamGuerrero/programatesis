# Workspace Admin

Rol: administracion funcional y gobierno de catalogos/usuarios.

Capas a tocar:
- Presentacion API: app/api/v1/endpoints/crud_ops.py
- Reglas de acceso: app/api/deps.py
- Integracion datos: app/repositories

Carpetas de modulos (workspace):
- modules/usuarios
- modules/catalogos

Convencion:
- No mezclar logica clinica ni nutricional en este workspace.
- Cada modulo nuevo de admin debe ubicarse dentro de modules/.
