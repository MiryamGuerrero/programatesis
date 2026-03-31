# Arquitectura por capas - Reuma Nutri

## 1. Descripcion general

La arquitectura del sistema sigue un modelo en capas con separacion de responsabilidades:

- Capa de presentacion: Flutter (web y mobile).
- Capa de servicios y logica: FastAPI (Python).
- Capa de persistencia y autenticacion: Supabase + PostgreSQL.

Esta estructura permite mantener el sistema mas ordenado, escalable y facil de evolucionar.

## 2. Capas del sistema

### 2.1 Capa de presentacion (Flutter)

Ubicacion principal:

- frontend/flutter_app/lib/main_web.dart
- frontend/flutter_app/lib/main_tutor_mobile.dart
- frontend/flutter_app/lib/features

Responsabilidad:

- Web: interfaz para admin, medico y nutricionista.
- Mobile: interfaz para tutor/cuidador.
- Captura de datos, validaciones basicas de formulario y navegacion.

### 2.2 Capa de servicios y logica (FastAPI)

Ubicacion principal (estado actual):

- backend/app/main.py
- backend/app/api/v1/router.py
- backend/app/api/v1/endpoints/roles
- backend/app/services/roles
- backend/app/services/shared

Responsabilidad:

- Centralizar procesos con reglas, calculos y decisiones automaticas.
- Ejemplos funcionales:
  - calculo de IMC
  - diagnostico OMS
  - reglas alimentarias
  - recetas permitidas
  - plan automatico
  - adherencia
  - preferencias aprendidas

Estado de implementacion consolidado:

- Los endpoints de rol importan directo desde servicios por modulo en app/services/roles/<rol>/modules.
- No se usan wrappers de compatibilidad para servicios de rol.
- Se retiraron los paquetes legacy de servicios que duplicaban responsabilidades.

### 2.3 Capa de datos, autenticacion y archivos (Supabase)

Ubicacion principal:

- base_de_datos.sql
- supabase/rls_policies.sql
- supabase/seed_catalogs.sql
- supabase/seed_oms_demo.sql

Responsabilidad:

- Persistencia transaccional en PostgreSQL.
- Autenticacion y control de acceso por rol.
- Politicas de seguridad por fila (RLS).
- Almacenamiento de archivos (por ejemplo, imagenes de recetas).

## 3. Carpetas por rol para modulos

Para mejorar comprension y mantenimiento, cada rol tiene modulos explicitos en backend y frontend.

### 3.1 Backend (implementacion real de servicios por rol)

Ruta base:

- backend/app/services/roles

Estructura activa:

- admin:
  - modules
- medico:
  - modules/diagnostico_oms
  - modules/adherencia
- nutricionista:
  - modules/ingredientes
  - modules/recetas
  - modules/plan_nutricional
  - modules/preferencias
- tutor:
  - modules/reemplazos

Servicios transversales:

- backend/app/services/shared

Limpieza aplicada en la migracion:

- Eliminados wrappers de compatibilidad en backend/app/services/roles/*.
- Eliminados paquetes legacy backend/app/services/admin_medico.
- Eliminados paquetes legacy backend/app/services/nutricion_tutor.
- Eliminados paquetes legacy backend/app/services/compartido.

### 3.2 Backend (workspaces de organizacion por rol)

Ruta base:

- backend/app/workspaces/roles

Estructura:

- admin:
  - modules/usuarios
  - modules/catalogos
- medico:
  - modules/registro_clinico
  - modules/diagnostico_oms
  - modules/reglas_medicas
  - modules/adherencia
- nutricionista:
  - modules/ingredientes
  - modules/recetas
  - modules/plan_nutricional
  - modules/reglas_nutricionales
  - modules/preferencias
- tutor:
  - modules/plan
  - modules/consumo
  - modules/reemplazos
  - modules/calificacion

Nota:

- Estas carpetas ordenan ownership funcional por rol para trabajo de equipo y planificacion.
- La ejecucion principal de negocio vive en app/services/roles y app/api/v1/endpoints/roles.

### 3.3 Frontend (modulos por rol)

Ruta base:

- frontend/flutter_app/lib/features

Estructura:

- admin/modules:
  - usuarios
  - catalogos
- medico/modules:
  - registro_clinico
  - diagnostico_oms
  - reglas_medicas
  - adherencia
- nutricionista/modules:
  - ingredientes
  - recetas
  - plan_nutricional
  - reglas_nutricionales
  - preferencias
- tutor/modules:
  - plan
  - consumo
  - reemplazos
  - calificacion

Estado de implementacion:

- Las pantallas principales de rol se movieron a modules/<modulo>/.
- role_shell usa imports directos a rutas de modules.

## 4. Regla de integracion entre capas

Regla de uso recomendada:

- Operaciones simples (CRUD directo sin reglas complejas):
  - Flutter puede consultar/escribir directo en Supabase.
- Operaciones complejas (calculo, reglas, decisiones automaticas):
  - Flutter debe llamar FastAPI.
  - FastAPI procesa la logica y consulta/actualiza Supabase.

## 5. Flujo operativo

### Flujo simple

Flutter -> Supabase

Uso tipico:

- catalogos simples
- lecturas de datos sin motor de reglas

### Flujo inteligente

Flutter -> FastAPI -> Supabase

Uso tipico:

- diagnosticos antropometricos
- filtrado de ingredientes y recetas permitidas
- construccion de planes
- calculos de adherencia

Mapa rapido de endpoints de rol (backend):

- /api/v1/imc-calculo -> medico/modules/diagnostico_oms
- /api/v1/diagnostico-oms -> medico/modules/diagnostico_oms
- /api/v1/reglas-evaluacion -> shared/rule_engine_service
- /api/v1/adherencia-calculo -> medico/modules/adherencia
- /api/v1/ingredientes-permitidos -> nutricionista/modules/ingredientes
- /api/v1/recetas-permitidas -> nutricionista/modules/recetas
- /api/v1/plan-automatico -> nutricionista/modules/plan_nutricional
- /api/v1/preferencias-aprendidas -> nutricionista/modules/preferencias
- /api/v1/reemplazo-equivalente -> tutor/modules/reemplazos

## 6. Beneficios de esta arquitectura

- Separacion clara entre UI, logica y datos.
- Menor acoplamiento entre cliente y reglas de negocio.
- Escalabilidad funcional por capas y por rol.
- Mejor mantenibilidad y pruebas por componente.
- Estructura de servicios sin duplicidad ni rutas legacy intermedias.

## 7. Sustento conceptual

Esta organizacion es coherente con principios de arquitectura por capas y separacion de responsabilidades, alineados con:

- Software Architecture in Practice (Bass, Clements, Kazman)
- Clean Architecture (Robert C. Martin)
- Patterns of Enterprise Application Architecture (Martin Fowler)
