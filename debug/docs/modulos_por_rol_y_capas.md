# Modulos por rol y capas

Este documento deja visible la organizacion funcional de frontend y backend bajo arquitectura limpia por capas.

## 1. Frontend (Flutter)

Base de presentacion:
- `frontend/flutter_app/lib/shared/widgets/role_shell.dart`
- `frontend/flutter_app/lib/features/roles/role_module_registry.dart`
- `frontend/flutter_app/lib/features/roles/role_module.dart`

Navegacion por URL (web):
- `/?role=<rol>&module=<modulo>`
- El parametro `module` se sincroniza al cambiar de seccion dentro de cada rol.

### 1.1 Admin
- Vista usuarios: `frontend/flutter_app/lib/features/admin/modules/usuarios/admin_users_page.dart`
- Vista catalogos: `frontend/flutter_app/lib/features/admin/modules/catalogos/admin_catalogs_page.dart`

### 1.2 Medico
- Vista registro clinico: `frontend/flutter_app/lib/features/medico/modules/registro_clinico/registro_clinico_page.dart`
- Vista diagnostico OMS: `frontend/flutter_app/lib/features/medico/modules/diagnostico_oms/diagnostico_page.dart`
- Vista reglas medicas: `frontend/flutter_app/lib/features/medico/modules/reglas_medicas/reglas_medicas_page.dart`

### 1.3 Nutricionista
- Vista ingredientes: `frontend/flutter_app/lib/features/nutricionista/modules/ingredientes/ingredientes_page.dart`
- Vista recetas: `frontend/flutter_app/lib/features/nutricionista/modules/recetas/recetas_page.dart`
- Vista plan manual: `frontend/flutter_app/lib/features/nutricionista/modules/plan_nutricional/plan_manual_page.dart`
- Vista etiquetas nutricionales: `frontend/flutter_app/lib/features/nutricionista/modules/reglas_nutricionales/reglas_nutricionales_page.dart`

### 1.4 Tutor
- Vista plan: `frontend/flutter_app/lib/features/tutor/modules/plan/plan_page.dart`
- Vista consumo: `frontend/flutter_app/lib/features/tutor/modules/consumo/consumo_page.dart`
- Vista reemplazos: `frontend/flutter_app/lib/features/tutor/modules/reemplazos/reemplazo_page.dart`
- Vista calificacion: `frontend/flutter_app/lib/features/tutor/modules/calificacion/calificacion_page.dart`

## 2. Backend (FastAPI)

Entrada de router:
- `backend/app/api/v1/router.py`
- `backend/app/api/v1/route_registry.py`

### 2.1 Capa presentacion por rol
- Admin: `backend/app/api/v1/endpoints/roles/admin_endpoints.py`
- Medico: `backend/app/api/v1/endpoints/roles/medico_endpoints.py`
- Nutricionista: `backend/app/api/v1/endpoints/roles/nutricionista_endpoints.py`
- Tutor: `backend/app/api/v1/endpoints/roles/tutor_endpoints.py`
- Shared auth: `backend/app/api/v1/endpoints/auth_context.py`

### 2.2 Capa aplicacion (servicios)
- Servicios por rol: `backend/app/services/roles/`
- Servicios compartidos: `backend/app/services/shared/`
- Admin CRUD service: `backend/app/services/roles/admin/modules/crud/admin_crud_service.py`

### 2.3 Capa infraestructura
- Repositorios: `backend/app/repositories/`
- Config/DB/seguridad: `backend/app/core/`
- Admin CRUD repository: `backend/app/repositories/admin_crud_repository.py`

## 3. Limpieza aplicada

Se eliminaron modulos legacy no usados por el enrutado actual:

- `backend/app/api/v1/endpoints/crud_ops.py`
- `backend/app/api/v1/endpoints/admin_medico.py`
- `backend/app/api/v1/endpoints/nutricion_tutor.py`
- `backend/app/api/v1/etiquetas_api.py`
- `backend/app/api/v1/etiquetas_crud.py`
- `backend/app/api/v1/etiquetas_nutricionales.py`
- `backend/app/api/v1/etiquetas_reglas.py`
- `backend/app/api/v1/ingredientes_crud.py`

Se eliminaron tambien esqueletos frontend no usados por la app Flutter activa:

- `frontend/mobile-tutor/`
- `frontend/web-dashboard/`
- `frontend/packages/`
- `frontend/package.json`
- `frontend/pnpm-workspace.yaml`

## 4. Convencion operativa

1. Nuevos endpoints deben vivir en `backend/app/api/v1/endpoints/roles/<rol>_endpoints.py`.
2. Nuevas vistas deben registrarse solo en `frontend/flutter_app/lib/features/roles/role_module_registry.dart`.
3. Logica de negocio no debe quedar en widgets ni endpoints; debe ir en `services`.
