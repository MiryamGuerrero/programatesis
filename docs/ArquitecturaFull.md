# ARQUITECTURA COMPLETA - REUMA NUTRI

---

## 1. VISIÓN GENERAL DE LA ARQUITECTURA

**Reuma Nutri** es un sistema experto de soporte nutricional para pacientes pediátricos con enfermedades reumáticas. Su arquitectura sigue un modelo **por capas** que combina:

- **Backend:** Arquitectura por Capas (Presentación → Aplicación → Dominio → Infraestructura) con FastAPI (Python)
- **Frontend:** Arquitectura basada en módulos por rol con Flutter (Dart)
- **Base de datos:** PostgreSQL en Supabase con extensiones
- **Autenticación:** Supabase Auth con JWT + validación asimétrica/simétrica
- **Edge Functions:** Deno/TypeScript para lógica desatendida

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FRONTEND (Flutter)                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │  Admin   │  │  Médico  │  │Nutricion.│  │  Tutor   │           │
│  │  Módulos │  │  Módulos │  │ Módulos  │  │  Módulos │           │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘           │
│       └──────────────┴─────────────┴──────────────┘                │
│                        │                                            │
│              ┌─────────┴──────────┐                                │
│              │   Role Shell +     │                                │
│              │  Module Registry   │                                │
│              └─────────┬──────────┘                                │
│                        │                                            │
│              ┌─────────┴──────────┐                                │
│              │    Riverpod        │                                │
│              │(State Management)  │                                │
│              └─────────┬──────────┘                                │
│                        │                                            │
│              ┌─────────┴──────────┐                                │
│              │  Dio API Client    │                                │
│              │  Supabase Client   │                                │
│              └─────────┬──────────┘                                │
└────────────────────────┼────────────────────────────────────────────┘
                         │ HTTP (JSON)
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     BACKEND (FastAPI)                               │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              CAPA DE PRESENTACIÓN (API)                     │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │   │
│  │  │  Auth    │  │  Admin   │  │  Médico  │  │Nutricion.│   │   │
│  │  │ Endpoints│  │ Endpoints│  │ Endpoints│  │ Endpoints│   │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │   │
│  │  │  Tutor   │  │  Perfil  │  │Compatibil.│                │   │
│  │  │ Endpoints│  │ Endpoints│  │ Endpoints│                 │   │
│  │  └──────────┘  └──────────┘  └──────────┘                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                          │                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              CAPA DE APLICACIÓN (Use Cases)                 │   │
│  │  gestionar_pacientes.py      gestionar_ingredientes.py     │   │
│  │  gestionar_control_clinico.py gestionar_variables.py       │   │
│  │  gestionar_catalogos.py      generar_plan_automatico.py    │   │
│  │  gestionar_perfil_usuario.py evaluar_reglas_paciente.py    │   │
│  │  gestionar_usuarios.py       gestionar_seguimiento.py      │   │
│  │  supervisar_adherencia.py                                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                          │                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              CAPA DE DOMINIO                                │   │
│  │  ┌─────────────────┐  ┌──────────────────────┐             │   │
│  │  │   MODELOS        │  │   SERVICIOS           │             │   │
│  │  │  paciente.py    │  │  servicio_oms.py     │             │   │
│  │  │  usuario.py     │  │  servicio_planificador│             │   │
│  │  │  clinico.py     │  │  servicio_heuristico │             │   │
│  │  │  reglas.py      │  │  restricciones_      │             │   │
│  │  │  seguimiento.py │  │  alimentarias.py     │             │   │
│  │  │  plan_nutricional│  │  resolutor_         │             │   │
│  │  │                 │  │  conflictos.py       │             │   │
│  │  └─────────────────┘  └──────────────────────┘             │   │
│  │  ┌─────────────────┐  ┌──────────────────────┐             │   │
│  │  │   INTERFACES     │  │   EXCEPCIONES         │             │   │
│  │  │  IRepositorio   │  │  ErrorValidacion     │             │   │
│  │  │  Paciente       │  │  ErrorReglaNegocio   │             │   │
│  │  │  IRepositorio   │  │  ErrorRecursoNo      │             │   │
│  │  │  Perfil, Regla, │  │  Encontrado          │             │   │
│  │  │  Ingrediente... │  │  ErrorDominio        │             │   │
│  │  └─────────────────┘  └──────────────────────┘             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                          │                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │           CAPA DE INFRAESTRUCTURA                            │   │
│  │  ┌──────────────────┐  ┌──────────────────┐                 │   │
│  │  │   REPOSITORIOS    │  │   CLIENTES        │                 │   │
│  │  │  repositorio_    │  │  supabase/       │                 │   │
│  │  │  paciente.py     │  │  client.py       │                 │   │
│  │  │  repositorio_    │  │  database/db.py  │                 │   │
│  │  │  perfil.py       │  │  (ConnectionPool) │                 │   │
│  │  │  repositorio_    │  └──────────────────┘                 │   │
│  │  │  regla.py        │                                        │   │
│  │  │  repositorio_    │                                        │   │
│  │  │  receta.py       │                                        │   │
│  │  │  repositorio_    │                                        │   │
│  │  │  ingrediente.py  │                                        │   │
│  │  │  repositorio_    │                                        │   │
│  │  │  clinico.py      │                                        │   │
│  │  │  repositorio_    │                                        │   │
│  │  │  seguimiento.py  │                                        │   │
│  │  │  repositorio_    │                                        │   │
│  │  │  composicion.py  │                                        │   │
│  │  └──────────────────┘                                        │   │
│  └─────────────────────────────────────────────────────────────┘   │
└───────────┬─────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     SUPABASE (PostgreSQL + Edge Functions)           │
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────────┐  │
│  │ PostgreSQL│ │   Auth   │ │ Storage  │ │ Edge Functions       │  │
│  │(8 esquemas)│ │(23 tablas)│ │(8 tablas)│ │ plan-inteligente    │  │
│  │ 61 tablas │ │          │ │          │ │ reemplazo-equivalente│  │
│  │ 7 vistas  │ │          │ │          │ │ recomendacion-puntual│  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 1.1 Paradigmas de Programación

El proyecto combina múltiples paradigmas de programación, aprovechando las fortalezas de cada lenguaje:

| Paradigma | Backend (Python) | Frontend (Dart/Flutter) |
|-----------|-----------------|------------------------|
| **Orientado a Objetos (POO)** | Clases con herencia (`ErrorValidacion(ErrorDominio)`), encapsulamiento en repositorios y servicios | Clases con herencia (`ConsumerStatefulWidget`, `ConsumerWidget`), widgets como objetos |
| **Programación Funcional** | Uso de `map()`, `filter()`, `List comprehensions`, funciones `staticmethod`, inmutabilidad en DTOs | `maybeWhen()`, `when()` en AsyncValue, funciones arrow, inmutabilidad con `final` |
| **Programación Asíncrona** | `async/await` en use cases, `@asynccontextmanager` para lifespan | `FutureBuilder`, `StreamProvider`, `async/await` en providers |
| **Programación Declarativa** | Decoradores de FastAPI (`@app.get`, `@app.exception_handler`), Pydantic `BaseSettings` | Widget tree declarativo, Riverpod providers declarativos |
| **Programación Basada en Enumeraciones** | `Enum` vía clases de error | `enum AppRole` con extension methods (`AppRoleX`) |
| **Programación Orientada a Interfaces** | ABC (Abstract Base Classes) en `interfaces.py` | Implicit interfaces (Duck typing) en Dart |
| **Programación por Contratos** | Type hints estrictos, Pydantic validators | Type hints en Dart, null safety |
| **Programación Reactiva** | No aplica | Riverpod (`StreamProvider`, `StateProvider`), `ConsumerWidget`, `ref.watch()` |

## 1.2 Estándares de Codificación

### Backend (Python)

| Estándar | Aplicación |
|----------|-----------|
| **PEP 8** | Estilo de código: snake_case, 4 espacios, líneas < 79 chars |
| **PEP 484** | Type hints en todas las funciones y métodos |
| **PEP 257** | Docstrings en clases y métodos públicos |
| **PEP 20 (Zen of Python)** | Principios generales: "Explicit is better than implicit" |
| **Convención de nombres** | `snake_case` para variables/funciones, `PascalCase` para clases, `UPPER_CASE` para constantes |
| **Principio DRY** | Código reutilizado vía herencia (`ErrorDominio`) y composición |
| **Principio KISS** | Funciones cortas con responsabilidad única |
| **Convención de imports** | Estándar → Terceros → Locales (separados por línea en blanco) |
| **Manejo de excepciones** | Excepciones de dominio con herencia, captura mínima, relanzamiento controlado |

**Ejemplo de estilo backend (según código fuente):**
```python
class ErrorValidacion(ErrorDominio):
    """Excepción lanzada cuando un modelo de dominio no cumple sus reglas."""
    pass

class PerfilPaciente(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id_paciente: str
    nombre: str
    fecha_nacimiento: date
    alergias: List[Alergia] = []
    
    def validar(self):
        if self.fecha_nacimiento > date.today():
            raise ErrorValidacion("La fecha de nacimiento no puede ser en el futuro")
```

### Frontend (Dart/Flutter)

| Estándar | Aplicación |
|----------|-----------|
| **Effective Dart** | Guía oficial de estilo Dart |
| **Convención de nombres** | `lowerCamelCase` para variables/funciones, `PascalCase` para clases, `snake_case` para archivos |
| **Null safety** | Uso de `?` y `late` para variables nullable, `??` para valores por defecto |
| **Inmutabilidad** | `final` sobre `var`/`const` para datos que no cambian |
| **Widget tree** | Widgets pequeños y reutilizables, extracción a métodos privados `_buildX()` |
| **Provider pattern** | Providers definidos como top-level functions, `ref.watch()` para reactividad |
| **Patrón Repository** | Abstracción de datos en repositorios con inyección via providers |

**Ejemplo de estilo frontend (según código fuente):**
```dart
final appRoleProvider = FutureProvider<AppRole>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return AppRole.tutor;
  final roleFromApi = await _resolveRoleFromBackend(accessToken: session.accessToken);
  return roleFromApi ?? AppRole.tutor;
});
```

## 1.3 Patrones de Diseño Implementados

| Patrón | Backend | Frontend |
|--------|---------|----------|
| **Arquitectura por Capas** | api → aplicacion → domain → infraestructura | core → shared → features |
| **Repository Pattern** | Interfaces en domain, impl en infraestructura | SupabaseCrudRepository encapsula acceso a datos |
| **Inyección de Dependencias** | FastAPI dependencias (`dependencias.py`) | Riverpod providers (`dioProvider`, `supabaseCrudRepositoryProvider`) |
| **DTO Pattern** | `dtos/` separan API del modelo interno | Modelos en `models/` por feature |
| **Strategy Pattern** | Servicios de dominio intercambiables | -- |
| **Template Method** | Flujo base en use cases con pasos definidos | Widget build pattern con `ConsumerStatefulWidget` |
| **Observer / Reactive** | -- | Riverpod `ref.watch()` + StreamProvider |
| **Factory Method** | `get_settings()`, `get_pool()`, `buildApiClient()` | `buildApiClient()`, providers factories |
| **Singleton** | `get_pool()`, `get_settings()` (LRU cache) | Providers singleton (top-level) |
| **Adapter Pattern** | Repositorios implementan interfaces | Dio Interceptors adaptan HTTP |
| **Exception Hierarchy** | `ErrorDominio → ErrorValidacion/ReglaNegocio/RecursoNoEncontrado` | -- |
| **Module Registry** | `route_registry.py` registra endpoints por rol | `role_module_registry.dart` registra páginas por rol |
| **Context Manager** | `db_cursor()` maneja pool de conexiones | -- |

---

## 2. BACKEND - ARQUITECTURA POR CAPAS

### 2.1 Principios de Diseño

El backend implementa una **Arquitectura por Capas** (Layered Architecture) con los siguientes principios:

| Principio | Descripción |
|-----------|-------------|
| **Independencia del Framework** | FastAPI es un detalle de implementación intercambiable |
| **Independencia de la UI** | La API puede ser consumida por cualquier cliente |
| **Independencia de la BD** | Los repositorios pueden cambiar de implementación |
| **Independencia de agentes externos** | Supabase/PSequel son detalles de infraestructura |
| **Pruebas aisladas** | El dominio puede probarse sin infraestructura |

### 2.2 Estructura de Capas

```
backend/
├── app/
│   ├── main.py                    # Punto de entrada FastAPI + middlewares + exception handlers
│   ├── core/                      # Configuración transversal
│   │   ├── config.py              # Settings (Pydantic BaseSettings)
│   │   └── security.py            # JWT decode, roles, UserContext
│   ├── api/                       # CAPA DE PRESENTACIÓN (Controllers)
│   │   ├── deps.py                # Dependencias FastAPI (get_current_user, require_roles)
│   │   └── v1/
│   │       ├── router.py          # Router raíz "/api/v1"
│   │       ├── route_registry.py  # Registro de módulos por rol
│   │       ├── dependencias.py    # Wiring DI (use cases -> repos)
│   │       ├── dtos/              # Request/Response schemas
│   │       └── endpoints/         # Endpoints agrupados por rol
│   │           ├── contexto_autenticacion.py
│   │           └── roles/
│   │               ├── puntos_entrada_admin.py
│   │               ├── puntos_entrada_medico.py
│   │               ├── puntos_entrada_nutricionista.py
│   │               ├── puntos_entrada_nutricionista_admin.py
│   │               ├── puntos_entrada_tutor.py
│   │               ├── puntos_entrada_perfil.py
│   │               └── puntos_entrada_compatibilidad.py
│   ├── aplicacion/                # CAPA DE APLICACIÓN (Use Cases)
│   │   ├── clinica/
│   │   │   ├── gestionar_pacientes.py
│   │   │   ├── gestionar_control_clinico.py
│   │   │   ├── gestionar_catalogos.py
│   │   │   ├── gestionar_perfil_usuario.py
│   │   │   ├── gestionar_usuarios.py
│   │   │   └── supervisar_adherencia.py
│   │   └── nutricion/
│   │       ├── gestionar_ingredientes.py
│   │       ├── gestionar_variables.py
│   │       ├── generar_plan_automatico.py
│   │       ├── evaluar_reglas_paciente.py
│   │       └── gestionar_seguimiento.py
│   ├── domain/                    # CAPA DE DOMINIO (Núcleo del negocio)
│   │   ├── modelos/               # Entidades del dominio
│   │   │   ├── paciente.py        # PerfilPaciente, Alergia
│   │   │   ├── usuario.py         # PerfilUsuario
│   │   │   ├── clinico.py         # ClinicalDiagnosis
│   │   │   ├── reglas.py          # Regla
│   │   │   ├── seguimiento.py     # RegistroConsumo
│   │   │   └── plan_nutricional.py # PlanSemanal, DiaPlan, ItemPlan
│   │   ├── servicios/             # Lógica de negocio pura
│   │   │   ├── servicio_oms.py              # Evaluación OMS (z-scores)
│   │   │   ├── servicio_planificador.py     # Generación de planes
│   │   │   ├── servicio_heuristico.py       # Motor de reglas
│   │   │   ├── restricciones_alimentarias.py # Definiciones de restricciones
│   │   │   └── resolutor_conflictos.py      # Resolución de conflictos entre reglas
│   │   ├── repositorios/
│   │   │   └── interfaces.py      # Puertos (IPRepositorioPaciente, IRepositorioRegla, etc.)
│   │   ├── dtos/                  # Data Transfer Objects del dominio
│   │   └── excepciones.py         # ErrorValidacion, ErrorReglaNegocio, ErrorRecursoNoEncontrado
│   └── infraestructura/           # CAPA DE INFRAESTRUCTURA (Adaptadores)
│       ├── database/
│       │   └── db.py              # ConnectionPool (psycopg_pool)
│       ├── supabase/
│       │   └── client.py          # Clientes Supabase (admin y público)
│       ├── repositorios/          # Implementaciones concretas de los puertos
│       │   ├── base.py            # Repositorio base
│       │   ├── repositorio_paciente.py
│       │   ├── repositorio_perfil.py
│       │   ├── repositorio_regla.py
│       │   ├── repositorio_receta.py
│       │   ├── repositorio_ingrediente.py
│       │   ├── repositorio_clinico.py
│       │   ├── repositorio_nutricion.py
│       │   ├── repositorio_composicion.py
│       │   └── repositorio_seguimiento.py
│       └── servicios/
│           └── servicio_oms.py    # Implementación concreta con acceso a BD
```

### 2.3 Flujo de una Solicitud

```
Cliente (Flutter) → HTTP POST /api/v1/pacientes
         │
         ▼
    [CORS Middleware]
         │
         ▼
    [Exception Handlers]
         │
         ▼
    [Dependencia: get_current_user()] → decode_supabase_token() → build_user_context()
         │                                │                           │
         │                           JWT decode              Resuelve rol desde
         │                           o Auth API              BD si no viene en JWT
         │                                │                           │
         ▼                                ▼                           ▼
    [Dependencia: require_roles()] → assert_allowed_role(user, {"medico"})
         │
         ▼
    [Endpoint] → Use Case → Domain Service → Repository Interface
         │          │            │                   │
         │          │            │           Implementación Postgres
         │          │            │                   │
         │          │      Lógica de negocio    SQL → Supabase Pooler
         │          │     (servicio_oms,        │
         │          │      servicio_planificador)│
         │          │                           │
         │          ▼                           ▼
         │    Excepciones de dominio       Resultados
         │    (ErrorValidacion, etc.)      (dicts, modelos)
         │          │
         ▼          ▼
    [Exception Handlers] → ORJSONResponse (400, 404, 500)
         │
         ▼
    Respuesta JSON → Cliente
```

### 2.4 Módulos del Backend por Rol

| Endpoint | Rol | Funcionalidades Principales |
|----------|-----|---------------------------|
| `/api/v1/me`, `/auth-context` | Público | Contexto de autenticación |
| `/api/v1/usuarios`, `/roles`, `/*` | Admin | CRUD de usuarios, gestión de tutores |
| `/api/v1/pacientes`, `/pre-diagnostico-nutricional`, `/reglas-medicas`, `/catalogos` | Médico | Gestión de pacientes, diagnósticos, controles, reglas clínicas |
| `/api/v1/ingredientes`, `/recetas`, `/plan-automatico`, `/plan-manual` | Nutricionista | CRUD de ingredientes, recetas, generación de planes |
| `/api/v1/nutricionista/ingredientes`, `/variables`, `/etiquetas`, `/momentos-comida`, `/tipos-plato`, `/reglas-menu-combinaciones` | Nutricionista (Admin) | Administración avanzada del catálogo nutricional |
| `/api/v1/tutor/mis-pacientes`, `/plan-diario`, `/generar-plan-automatico`, `/lista-compras` | Tutor | Panel del tutor, plan diario, preferencias, consumo |
| `/api/v1/perfil/mi-perfil` | Público | Perfil de usuario |
| `/api/v1/planes`, `/recetas-permitidas`, `/crud/*`, `/composicion` | Público | Compatibilidad y reglas |

### 2.5 Servicios de Dominio Clave

| Servicio | Responsabilidad |
|----------|----------------|
| **ServicioOMS** | Motor de clasificación antropométrica OMS: cálculo de z-scores, selección de indicador (peso/edad, talla/edad, IMC/edad), evaluación del estado nutricional del paciente |
| **ServicioPlanificador** | Generación automática de planes semanales: selección aleatoria ponderada de recetas, priorización de recetas potenciadas (80% probabilidad), distribución por momentos de comida |
| **ServicioHeuristico** | Evaluación de reglas heurísticas: cruza condiciones activas del paciente con reglas del sistema para determinar ingredientes prohibidos, permitidos o recomendados |
| **RestriccionesAlimentarias** | Definiciones de restricciones dietéticas (lactosa, gluten, etc.) con sus etiquetas bloqueantes asociadas |
| **ResolutorConflictos** | Resuelve conflictos cuando múltiples reglas aplican al mismo ingrediente con diferentes acciones |

### 2.6 Seguridad y Autenticación

```
Token JWT (Bearer)
    │
    ▼
decode_supabase_token(token)
    │
    ├── ¿Hay SUPABASE_JWT_SECRET configurado?
    │   ├── Sí → jwt.decode(token, secret, HS256)
    │   └── No → _verify_token_with_supabase_auth(token)
    │               ├── GET {supabase_url}/auth/v1/user
    │               └── Fallback → jwt.get_unverified_claims(token)
    │
    ▼
build_user_context(claims)
    │
    ├── _is_user_active(user_id, email) → consulta BD tabla usuario
    ├── _normalize_role() → Normaliza string de rol
    ├── _get_role_from_user_table() → Fallback a BD si no viene en claims
    └── Default → "tutor"
    │
    ▼
UserContext(user_id, role, email)
    │
    ▼
assert_allowed_role(user, allowed_roles)
```

### 2.7 Manejo de Excepciones

| Excepción | HTTP Status | Uso |
|-----------|-------------|-----|
| `ErrorValidacion` | 400 | Validaciones de dominio (fechas, datos inválidos) |
| `ErrorReglaNegocio` | 400 | Infracciones de reglas clínicas o nutricionales |
| `ErrorRecursoNoEncontrado` | 404 | Entidad no encontrada |
| `Exception` (genérica) | 500 | Errores inesperados del sistema |

---

## 3. FRONTEND - ARQUITECTURA FLUTTER

### 3.1 Principios de Diseño

| Principio | Descripción |
|-----------|-------------|
| **Arquitectura modular por rol** | Cada rol del sistema tiene su propio conjunto de módulos/páginas |
| **State Management con Riverpod** | Proveedores globales y locales para estado reactivo |
| **Registro de módulos** | Sistema de plugins mediante `RoleModule` y `RoleModuleRegistry` |
| **Separación feature-first** | Cada feature agrupa presentación, datos y lógica |
| **Cliente API centralizado** | Dio como HTTP client con configuración centralizada |

### 3.2 Estructura de Capas

```
lib/
├── main.dart                          # Punto de entrada (web)
├── main_tutor_mobile.dart             # Punto de entrada (tutor mobile)
├── app.dart                           # Widget raíz ReumaNutriApp
├── bootstrap.dart                     # Inicialización (Supabase, i18n)
│
├── core/                              # CAPA BASE TRANSVERSAL
│   ├── config/
│   │   └── app_config.dart            # Configuración (URLs, keys)
│   ├── theme/
│   │   ├── app_theme.dart             # Tema Material 3 (azul/verde corporativo)
│   │   ├── app_sizes.dart             # Constantes de tamaño
│   │   ├── app_responsive.dart        # Helpers responsive
│   │   └── app_breakpoints.dart       # Breakpoints (mobile/tablet/desktop)
│   ├── state/
│   │   ├── app_providers.dart         # Providers globales (auth, perfil, rol)
│   │   └── notification_provider.dart # Estado de notificaciones
│   ├── services/
│   │   ├── realtime_service.dart      # Suscripciones Supabase Realtime
│   │   └── recipe_image_service.dart  # Compresión/subida de imágenes
│   ├── session/
│   │   ├── session_lock.dart          # Bloqueo de sesión web
│   │   ├── session_lock_web.dart
│   │   └── session_lock_stub.dart
│   └── network/
│       └── api_client.dart            # Cliente Dio (HTTP)
│
├── shared/                            # COMPARTIDO ENTRE FEATURES
│   ├── models/
│   │   └── app_role.dart              # Enum AppRole {admin, medico, nutricionista, tutor}
│   └── widgets/
│       ├── role_shell.dart            # Shell principal (sidebar + topbar + IndexedStack)
│       ├── nutri_avatar.dart
│       ├── patient_summary_panel.dart
│       ├── layout_components.dart
│       ├── module_ux.dart
│       └── escalas/
│
├── features/                          # FEATURES POR ROL
│   ├── auth/                          # Autenticación
│   │   ├── login_page.dart
│   │   └── set_password_page.dart
│   │
│   ├── roles/                         # Registro de módulos
│   │   ├── role_module.dart           # Modelo RoleModule (key, title, icon, builder)
│   │   └── role_module_registry.dart  # Mapeo AppRole → List<RoleModule>
│   │
│   ├── admin/                         # MÓDULOS DE ADMINISTRADOR
│   │   ├── data/
│   │   │   └── admin_accounts_supabase_repository.dart
│   │   └── modules/
│   │       ├── catalogos/admin_catalogs_page.dart
│   │       └── usuarios/
│   │           ├── admin_users_page.dart    # Gestión de personal médico
│   │           └── admin_tutors_page.dart   # Gestión de cuentas tutor
│   │
│   ├── medico/                        # MÓDULOS DE MÉDICO
│   │   ├── data/
│   │   │   ├── repositorio_medico.dart
│   │   │   └── supervision_provider.dart
│   │   ├── presentation/
│   │   │   ├── supervision_pacientes_page.dart  # Lista pacientes + filtros
│   │   │   ├── registro_paciente_page.dart      # Registro de paciente
│   │   │   ├── registro_mensual_page.dart       # Control mensual
│   │   │   └── patient_detail_modal.dart        # Detalle del paciente
│   │   └── modules/
│   │       ├── catalogo_condiciones/   # Catálogo de condiciones médicas
│   │       ├── reglas_medicas/         # Reglas médicas
│   │       ├── registro_clinico/       # Registro clínico
│   │       ├── consulta_evolucion/     # Consulta de evolución
│   │       ├── alergias_condiciones/   # Alergias y condiciones
│   │       └── diagnostico_oms/        # Diagnóstico OMS
│   │
│   ├── nutricionista/                 # MÓDULOS DE NUTRICIONISTA
│   │   └── modules/
│   │       ├── ingredientes/          # CRUD de ingredientes
│   │       │   ├── ingredientes_page.dart
│   │       │   ├── ingrediente_form_page.dart
│   │       │   ├── ingrediente_detalle_page.dart
│   │       │   └── models/ingrediente_model.dart
│   │       ├── recetas/               # CRUD de recetas
│   │       │   ├── recetas_page.dart
│   │       │   ├── receta_form_page.dart
│   │       │   ├── receta_detalle_page.dart
│   │       │   └── widgets/
│   │       ├── etiquetas/             # Etiquetas nutricionales
│   │       │   ├── etiquetas_page.dart
│   │       │   ├── etiquetas_gestion_page.dart
│   │       │   ├── etiqueta_form_page.dart
│   │       │   └── widgets/etiqueta_card.dart
│   │       ├── condiciones/           # Condiciones nutricionales
│   │       ├── reglas_nutricionales/  # Reglas nutricionales
│   │       ├── plan_nutricional/      # Plan manual
│   │       └── configuracion_menu/    # Menú y horarios
│   │
│   ├── tutor/                         # MÓDULOS DE TUTOR
│   │   ├── data/
│   │   │   ├── tutor_repository.dart
│   │   │   ├── repositorio_tutor.dart
│   │   │   └── seguimiento_provider.dart
│   │   ├── presentation/
│   │   │   ├── tutor_home_page.dart           # Dashboard del tutor
│   │   │   ├── mis_pacientes_page.dart        # Mis pacientes
│   │   │   ├── tutor_perfil_page.dart         # Perfil tutor
│   │   │   ├── tutor_calendario_page.dart     # Calendario de comidas
│   │   │   ├── tutor_recetas_page.dart        # Explorador de recetas
│   │   │   ├── tutor_receta_detalle_page.dart # Detalle de receta
│   │   │   ├── tutor_gustos_page.dart         # Preferencias
│   │   │   ├── tutor_compras_page.dart        # Lista de compras
│   │   │   ├── plan_diario_page.dart          # Plan del día
│   │   │   ├── registro_tutor_page.dart       # Registro tutor
│   │   │   ├── onboarding_gustos_page.dart    # Onboarding preferencias
│   │   │   └── widgets/
│   │   │       └── generar_plan_automatico_modal.dart
│   │   └── modules/
│   │       ├── reemplazos/reemplazo_page.dart     # Reemplazo de recetas
│   │       ├── consumo/consumo_page.dart           # Registro de consumo
│   │       ├── plan/plan_page.dart                 # Plan nutricional
│   │       └── calificacion/calificacion_page.dart # Calificación de recetas
│   │
│   ├── shared/                        # Páginas compartidas entre roles
│   │   └── widgets/
│   │       ├── gestion_pacientes_page.dart
│   │       ├── registrar_paciente_page.dart
│   │       └── expediente_paciente_page.dart
│   │
│   └── perfil/                        # Perfil de usuario (común)
│       └── perfil_page.dart
```

### 3.3 Sistema de Navegación (Module Registry)

El frontend **no usa un router tradicional** (como go_router). En su lugar implementa un **patrón de registro de módulos**:

```
AppRole (enum)
    │
    ▼
modulesForRole(role)
    │
    ├── AppRole.admin → [Equipo Médico, Cuentas Tutores, Mi Perfil]
    ├── AppRole.medico → [Gestión Pacientes, Catálogo Condiciones, Reglas Clínicas, Mi Perfil]
    ├── AppRole.nutricionista → [Ingredientes, Etiquetas, Recetas, Plan Manual, Menú y Horarios, Condiciones, Reglas Nutricionales, Mi Perfil]
    └── AppRole.tutor → [Mi Paciente, Mi Perfil]
    │
    ▼
RoleShell (widget principal)
    │
    ├── NavigationBar/Sidebar según plataforma
    └── IndexedStack → módulo seleccionado por índice
```

Cada `RoleModule` contiene:
- `key`: Identificador único
- `title`: Título visible en la navegación
- `icon`: Icono Material Design
- `builder()`: Función que construye el widget de la página

### 3.4 State Management (Riverpod)

```
Providers globales (app_providers.dart):
├── authSessionProvider          → Sesión de Supabase Auth
├── userProfileProvider         → Perfil del usuario autenticado
├── currentRoleProvider         → Rol actual (derivado del perfil)
└── notificationProvider        → Estado de notificaciones

Providers por feature (ej. tutor):
├── misPacientesProvider        → Lista de pacientes del tutor
├── planDiarioProvider          → Plan del día
└── seguimientoProvider         → Estado de seguimiento
```

### 3.5 Comunicación con el Backend

```
Flutter App
    │
    ├── Dio (api_client.dart) ───→ FastAPI (HTTP JSON) ───→ DB
    │   BaseURL: http://localhost:8000/api/v1/
    │   Timeouts: 2min connect, 5min receive
    │   Headers: Content-Type: application/json
    │
    ├── supabase_flutter ────→ Supabase Auth ───→ Auth API
    │   │                    Login, registro, JWT
    │   └───→ Supabase Realtime ───→ Suscripciones en vivo
    │
    └── http ─────────────────→ Edge Functions (Deno) ───→ DB
        plan-inteligente, reemplazo-equivalente, recomendacion-puntual
```

---

## 4. BASE DE DATOS

### 4.1 Esquemas y Propósito

| Esquema | Tablas | Propósito |
|---------|--------|-----------|
| `usuarios` | 8 | Usuarios, pacientes, tutores, roles, ubicación geográfica |
| `clinico` | 9 + vistas | Diagnósticos, alergias, controles, restricciones, recomendaciones |
| `nutricion` | 25 | Ingredientes, composición nutricional, recetas, grupos alimentarios, etiquetas, momentos de comida |
| `interaccion` | 12 | Planes nutricionales, items, evaluaciones, preferencias, seguimiento |
| `heuristico` | 6 | Motor de reglas: condiciones, acciones, objetivos, reglas |
| `referencia` | 6 | Estándares OMS: z-scores, percentiles, clasificaciones |
| `seguridad` | 2 | Auditoría de operaciones, registro de errores |
| `public` | 5 | Vistas públicas y tablas compartidas |

### 4.2 Motor de Reglas (Heurístico)

El esquema `heuristico` implementa un motor de reglas flexible:

```
condicion (ej: "Artritis Reumatoide")
    │
    ▼ (N:M)
condicion_regla
    │
    ▼
regla
    ├── Acción: [bloquear, permitir, recomendar, sugerir, alertar]
    ├── Objetivo: [ingrediente, grupo_alimentario, subgrupo, etiqueta, receta]
    ├── Es estricta: [true/false]
    └── Mensaje de error
```

**Check constraint:** Una regla debe apuntar exactamente a UN objetivo.

### 4.3 Referencias OMS

El esquema `referencia` contiene datos de la OMS para evaluación nutricional:

- **oms_indicador**: Catálogo de indicadores (WFH, HFA, WFA, BMI)
- **oms_referencia_zscore**: Tablas de z-scores con parámetros LMS (Lambda, Mediana, Sigma)
- **oms_referencia_percentil**: Tablas de percentiles (p01 a p999)
- **oms_clasificacion_zscore**: Rangos de z-score por edad para diagnóstico nutricional
- **oms_fuente_archivo**: Registro de archivos fuente importados

---

## 5. SUPABASE EDGE FUNCTIONS

Tres funciones serverless en Deno/TypeScript para lógica desatendida:

| Función | Propósito | Input | Output |
|---------|-----------|-------|--------|
| **plan-inteligente** | Generar plan semanal automático | `{patient_id, days, meals_per_day, start_date}` | Plan nutricional creado |
| **reemplazo-equivalente** | Buscar sustitutos equivalentes | `{ingrediente_id}` | Lista de sustitutos con ratio de conversión |
| **recomendacion-puntual** | Recomendar recetas al instante | `{patient_id, momento_codigo}` | Lista de recetas recomendadas (máx 10) |

---

## 6. FLUJO DE DATOS COMPLETO (Ejemplo: Generar Plan Automático)

```
Tutor (Flutter)
    │
    ├── 1. Abre plan_diario_page.dart
    │
    ├── 2. Presiona "Generar plan automático"
    │   → generar_plan_automatico_modal.dart
    │
    ├── 3. POST /api/v1/generar-plan-automatico
    │   Body: { id_paciente, fecha_inicio, dias }
    │   Header: Authorization: Bearer <JWT>
    │
    ▼
Backend (FastAPI)
    │
    ├── 4. get_current_user() → decode token → build_user_context()
    │
    ├── 5. Use Case: generar_plan_automatico.py
    │   │
    │   ├── 6. Obtener condiciones activas del paciente
    │   │   → repositorio_paciente.obtener_por_id()
    │   │
    │   ├── 7. Evaluar reglas heurísticas
    │   │   → servicio_heuristico.evaluar()
    │   │
    │   ├── 8. Obtener recetas seguras filtradas
    │   │   → repositorio_receta.obtener_recetas_seguras_para_paciente()
    │   │
    │   └── 9. Generar plan semanal
    │       → servicio_planificador.generar_plan_automatico()
    │
    ├── 10. Guardar plan en BD
    │   → repositorio_plan.guardar_plan_manual()
    │
    └── 11. ORJSONResponse { plan, items }
    │
    ▼
Tutor (Flutter)
    │
    └── 12. planDiarioProvider actualiza UI
        → Plan del día visible con recetas asignadas
```

---

## 7. MAPEO FRONTEND ↔ BACKEND

| Módulo Frontend | Endpoint Backend | Esquema BD |
|----------------|-----------------|------------|
| Admin → Equipo Médico | `/api/v1/usuarios` | `usuarios.usuario`, `usuarios.rol` |
| Admin → Cuentas Tutores | `/api/v1/tutores` | `usuarios.tutor_paciente`, `usuarios.usuario` |
| Médico → Gestión Pacientes | `/api/v1/pacientes`, `/api/v1/pre-diagnostico-nutricional` | `usuarios.paciente`, `clinico.*` |
| Médico → Catálogo Condiciones | `/api/v1/catalogos/condiciones` | `referencia.condicion`, `heuristico.condicion` |
| Médico → Reglas Clínicas | `/api/v1/reglas-medicas` | `heuristico.regla`, `heuristico.condicion_regla` |
| Médico → Diagnóstico OMS | `/api/v1/pre-diagnostico-nutricional` | `referencia.oms_*` |
| Nutricionista → Ingredientes | `/api/v1/ingredientes` | `nutricion.ingrediente`, `nutricion.ingrediente_composicion` |
| Nutricionista → Recetas | `/api/v1/recetas` | `nutricion.receta`, `nutricion.receta_ingrediente`, `nutricion.receta_paso` |
| Nutricionista → Etiquetas | `/api/v1/nutricionista/etiquetas` | `nutricion.etiqueta_nutricional` |
| Nutricionista → Plan Manual | `/api/v1/plan-manual` | `interaccion.plan_nutricional`, `interaccion.plan_item` |
| Nutricionista → Menú/Horarios | `/api/v1/composicion` | `nutricion.momento_comida`, `nutricion.tipo_plato`, `nutricion.regla_menu_combinacion` |
| Nutricionista → Condiciones | `/api/v1/catalogos/condiciones-nutricionales` | `heuristico.condicion` |
| Nutricionista → Reglas Nutricionales | `/api/v1/reglas-nutricionales` | `heuristico.regla` |
| Tutor → Mi Paciente | `/api/v1/tutor/mis-pacientes` | `usuarios.tutor_paciente`, `usuarios.paciente` |
| Tutor → Plan Diario | `/api/v1/tutor/plan-diario` | `interaccion.plan_item`, `interaccion.seguimiento_plan_item` |
| Tutor → Recetas | `/api/v1/recetas-permitidas` | `nutricion.receta` (filtrada por reglas) |
| Tutor → Preferencias | `/api/v1/tutor/preferencias` | `interaccion.preferencia_paciente` |
| Tutor → Lista Compras | `/api/v1/tutor/lista-compras` | `interaccion.plan_item` + `nutricion.receta_ingrediente` |
| Tutor → Calendario | `/api/v1/tutor/plan-diario` | `interaccion.plan_nutricional`, `interaccion.plan_item` |
| Tutor → Consumo | `/api/v1/tutor/consumo` | `interaccion.seguimiento_plan_item` |
| Tutor → Calificación | `/api/v1/tutor/evaluar-receta` | `interaccion.evaluacion_receta` |

---

## 8. TECNOLOGÍAS Y VERSIONES

### 8.1 Backend

| Tecnología | Versión | Propósito |
|-----------|---------|-----------|
| Python | 3.11+ | Lenguaje de programación |
| FastAPI | 0.115.12 | Framework web ASGI |
| Uvicorn | 0.34.0 | Servidor ASGI |
| Pydantic | 2.11.3 | Validación de datos y settings |
| psycopg | 3.2.6 | Driver PostgreSQL |
| psycopg-pool | 3.2.6 | Pool de conexiones |
| Supabase SDK | 2.15.0 | Cliente Supabase |
| python-jose | 3.3.0 | JWT handling |
| httpx | 0.28.1 | Cliente HTTP |
| orjson | 3.10.16 | Serialización JSON rápida |
| openpyxl | 3.1.5 | Importación Excel |

### 8.2 Frontend

| Tecnología | Versión | Propósito |
|-----------|---------|-----------|
| Dart SDK | >=3.3.0 | Lenguaje de programación |
| Flutter | 3.x | Framework UI multi-plataforma |
| flutter_riverpod | ^2.5.1 | State Management |
| supabase_flutter | ^2.8.0 | Cliente Supabase (Auth + Realtime) |
| dio | 5.8.0+1 | Cliente HTTP |
| google_fonts | ^6.2.1 | Tipografía (Lato, Montserrat) |
| fl_chart | ^1.2.0 | Gráficos |
| intl | ^0.20.0 | Internacionalización (es_EC) |
| image_picker | ^1.1.2 | Selección de imágenes |
| flutter_image_compress | ^2.4.0 | Compresión de imágenes |

### 8.3 Base de Datos

| Tecnología | Versión | Propósito |
|-----------|---------|-----------|
| PostgreSQL | 17.6 | Base de datos relacional |
| Supabase | - | Plataforma cloud (hosting, auth, storage) |

### 8.4 Edge Functions

| Tecnología | Propósito |
|-----------|-----------|
| Deno | Runtime TypeScript serverless |
| TypeScript | Lenguaje de las edge functions |

---

## 9. PATRONES DE DISEÑO IMPLEMENTADOS

| Patrón | Dónde se usa | Beneficio |
|--------|-------------|-----------|
| **Arquitectura por Capas** | Backend (api → aplicacion → domain → infraestructura) | Separación de preocupaciones, testabilidad |
| **Ports & Adapters** | Backend (interfaces.py → repositorios/*.py) | Independencia de tecnología de BD |
| **Inyección de Dependencias** | Backend (dependencias.py) | Desacoplamiento entre capas |
| **Repository Pattern** | Backend (repositorios/*.py) | Abstracción de acceso a datos |
| **Module Registry** | Frontend (role_module_registry.dart) | Navegación por rol sin router |
| **Provider Pattern (Riverpod)** | Frontend (providers) | Estado reactivo y desacoplado |
| **DTO Pattern** | Backend (dtos/) | Separación entre modelo interno y API |
| **Exception Hierarchy** | Backend (excepciones.py) | Manejo consistente de errores |
| **Strategy Pattern** | Backend (servicio_planificador.py, servicio_heuristico.py) | Algoritmos intercambiables |
| **Singleton** | Backend (config.py get_settings, supabase/client.py) | Instancia única de configuración y clientes |
| **Context Manager** | Backend (database/db.py db_cursor) | Gestión de recursos de BD |

---

## 10. CONSIDERACIONES DE CALIDAD

### 10.1 Seguridad
- **Autenticación:** JWT con Supabase Auth, doble validación (simétrica y asimétrica)
- **Autorización:** Roles validados en cada endpoint via `require_roles()`
- **Desactivación de cuentas:** Verificación en cada request
- **CORS:** Lista blanca de orígenes configurables
- **Encriptación:** Datos sensibles encriptados (bytea)

### 10.2 Rendimiento
- **Pool de conexiones:** psycopg_pool para reutilización
- **Cache:** LRU cache en settings y clientes Supabase
- **Serialización:** orjson para respuestas JSON rápidas
- **Índices:** Trigramas para búsqueda de ingredientes
- **Timeouts:** Configurados (2min connect, 5min receive)

### 10.3 Mantenibilidad
- **Arquitectura en capas:** Separación clara de responsabilidades
- **Código organizado por rol:** Tanto frontend como backend
- **Migraciones SQL:** Versionadas por historia de usuario (HU)
- **Logging:** Auditoría y registro de errores en esquema `seguridad`

---

*Documento de Arquitectura generado el: 08/06/2026*
*Proyecto: Reuma Nutri - Sistema de Gestión Nutricional para Enfermedades Reumáticas*
*Versión: 1.0.0*
