# Reuma Nutri

Aplicacion de soporte nutricional clinico pediatrico.

## Estado actual del proyecto

El proyecto esta compuesto por:

- Backend FastAPI en `backend/app`.
- Frontend Flutter (web y mobile) en `frontend/flutter_app`.
- Base de datos, SQL operativo y funciones serverless en `supabase`.

La API principal expone `GET /health` y rutas de negocio bajo prefijo `/api/v1`.

## Estructura real en la raiz

Actualmente en la raiz existen:

- `backend/`
- `frontend/`
- `supabase/`
- `docs/`
- `Fuente_datos/`
- `deploy_edge_functions.ps1`
- `start_web.ps1`
- `start_tutor_mobile.ps1`
- `README.md`

Ademas, en `backend/scripts/` se mantienen scripts de soporte/importacion/auditoria de datos. No forman parte del runtime principal de la app, pero siguen disponibles como utilitarios de mantenimiento.

## Modulos funcionales por rol

- Admin
  - Gestion de usuarios
  - CRUD administrativo
- Medico
  - Registro clinico
  - Diagnostico OMS
  - Reglas medicas
- Nutricionista
  - Ingredientes
  - Recetas
  - Plan nutricional
  - Preferencias aprendidas
- Tutor
  - Visualizacion de plan
  - Reemplazo por equivalentes

## Endpoints de negocio principales

Todos bajo `/api/v1`:

- `POST /imc-calculo`
- `POST /diagnostico-oms`
- `POST /reglas-evaluacion`
- `POST /ingredientes-permitidos`
- `POST /recetas-permitidas`
- `POST /plan-automatico`
- `POST /reemplazo-equivalente`
- `POST /adherencia-calculo`
- `POST /preferencias-aprendidas`

## Arranque rapido

Requisitos generales:

- Python 3.11+
- Flutter SDK
- Proyecto Supabase activo
- `backend/.env` configurado

Opciones recomendadas desde la raiz del repo:

- Web (admin, medico, nutricionista):
  - `./start_web.ps1`
- Mobile tutor:
  - `./start_tutor_mobile.ps1 -DeviceId <DEVICE_ID>`
  - Si omites `-DeviceId`, el script intenta detectar un dispositivo movil disponible.

Los scripts validan variables criticas en `backend/.env`, levantan backend en puerto `8000` y ejecutan Flutter con los `--dart-define` necesarios.

## Backend y frontend (detalle)

- Backend:
  - Entry point: `backend/app/main.py`
  - Health check: `http://127.0.0.1:8000/health`
- Frontend:
  - Web entry: `lib/main_web.dart`
  - Tutor mobile entry: `lib/main_tutor_mobile.dart`

## Supabase y Edge Functions

- SQL y artefactos de base de datos en `supabase/sql`, `supabase/analysis` y `supabase/backups`.
- Edge Functions desplegables en:
  - `supabase/functions/plan-inteligente`
  - `supabase/functions/recomendacion-puntual`
  - `supabase/functions/reemplazo-equivalente`
- Script de despliegue: `deploy_edge_functions.ps1`.

## Seguridad

- Roles soportados: `admin`, `medico`, `nutricionista`, `tutor`.
- El acceso a datos se controla con politicas RLS y reglas de autorizacion en Supabase + validaciones en backend.

## Documentacion

- Arquitectura por capas: `docs/arquitectura_por_capas.md`
- Guia de arranque: `docs/arranque_app.md`
- Componentes: `docs/component_diagram.md`
- Modulos por rol: `docs/modulos_por_rol_y_capas.md`

## Nota sobre datos fuente

`Fuente_datos/` contiene insumos y archivos historicos para procesos de carga/normalizacion (por ejemplo, ingredientes y tablas OMS). Estos archivos no son necesarios para ejecutar el flujo runtime diario, pero si para tareas de mantenimiento de datos.
