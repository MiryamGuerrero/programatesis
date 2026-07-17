================================================================================
  ARQUITECTURA NUTRIREUMA — DIAGRAMA UML DE DESPLIEGUE + COMPONENTES
  DOCUMENTO DE ANÁLISIS Y DISEÑO ARQUITECTÓNICO
================================================================================

Basado en el código fuente real del proyecto (Flutter + FastAPI + Supabase).


================================================================================
1. COMPONENTES PRINCIPALES A ALTO NIVEL
================================================================================

Basándose en el código real, los componentes lógicos de NutriReuma son:

┌──────────────────────────────────────────────────────────────┐
│ COMPONENTE              │ RESPONSABILIDAD                    │
├──────────────────────────┼───────────────────────────────────┤
│ Frontend Web            │ Interfaz web (Flutter Web)         │
│ NutriReuma              │ Roles: admin, médico, nutricionista│
│                          │ Compilado a flutter_web_build      │
├──────────────────────────┼───────────────────────────────────┤
│ App Móvil               │ Interfaz móvil (Flutter Mobile)     │
│ NutriReuma              │ Rol: tutor principalmente          │
│                          │ Compilado a nutrireuma_app.apk     │
├──────────────────────────┼───────────────────────────────────┤
│ Backend / API FastAPI   │ Rutas REST, lógica de negocio,     │
│                          │ autorización por rol, validación   │
│                          │ JWT, integración con Supabase      │
├──────────────────────────┼───────────────────────────────────┤
│ Lógica de negocio y     │ Casos de uso: OMS, IMC, reglas     │
│ casos de uso            │ nutricionales, planes, recetas,    │
│                          │ reemplazos, adherencia, etc.      │
│                          │ (VIVE DENTRO del backend, NO      │
│                          │ como componente separado a nivel  │
│                          │ alto)                             │
├──────────────────────────┼───────────────────────────────────┤
│ Seguridad y autorización │ Middleware JWT + validación de     │
│ por rol                 │ roles (admin/medico/nutricionista/ │
│                          │ tutor) desde tabla usuarios.      │
│                          │ (VIVE DENTRO del backend)          │
├──────────────────────────┼───────────────────────────────────┤
│ Autenticación Supabase  │ Supabase Auth: login email/        │
│                          │ password, refresh token, sesión   │
│                          │ (desde frontend vía SDK directa y │
│                          │ desde backend vía service_role)    │
├──────────────────────────┼───────────────────────────────────┤
│ Persistencia de datos   │ PostgreSQL administrado por        │
│ NutriReuma              │ Supabase (tablas: usuarios,        │
│                          │ pacientes, recetas, planes, etc.)  │
├──────────────────────────┼───────────────────────────────────┤
│ Funciones auxiliares de │ Supabase Edge Functions (cálculos  │
│ recomendación           │ auxiliares, lógica serverless)     │
└──────────────────────────┴───────────────────────────────────┘


================================================================================
2. ¿CÓMO SE COMUNICAN LAS CAPAS? (FLUJO REAL DEL CÓDIGO)
================================================================================

El código fuente revela DOS flujos de comunicación principales:

── FLUJO A: Autenticación (Frontend ↔ Supabase Auth directo) ──

  [Flutter Web/Mobile]
      │  Supabase.initialize(SUPABASE_URL, SUPABASE_ANON_KEY)
      │  └─ auth.signInWithPassword(email, password)
      │  └─ auth.onAuthStateChange.listen(...)
      ▼
  [HTTPS / Internet]
      │
      ▼
  [Supabase Auth Service]  ← Valida credenciales, emite JWT
      │
      └─ Devuelve: access_token (JWT) + refresh_token + session


── FLUJO B: Negocio (Frontend ↔ FastAPI ↔ Supabase) ──

  [Flutter Web/Mobile]
      │  Dio HTTP Client → FASTAPI_BASE_URL
      │  Header: Authorization: Bearer {access_token}
      ▼
  [HTTPS / Internet]
      │
      ▼
  [FastAPI Backend]
      │  1. Middleware valida JWT (firma HMAC-SHA256 con SUPABASE_JWT_SECRET)
      │  2. Extrae sub (user_id) y rol desde tabla `usuarios`
      │  3. Middleware autoriza según rol requerido por endpoint
      │  4. Ejecuta lógica de negocio (casos de uso)
      │  5. Consulta/escribe en Supabase vía:
      │     - supabase-py (service_role key) para operaciones admin
      │     - SQL directo (asyncpg) para queries complejas
      ▼
  [HTTPS / Internet]
      │
      ▼
  [Supabase Platform]
      ├─ PostgreSQL (datos persistentes)
      ├─ Edge Functions (recomendaciones, cálculos)
      └─ Storage (imágenes de recetas)


── FLUJO C: Tiempo real (Supabase → Frontend, vía WebSocket) ──

  [Supabase Realtime]
      │  PostgresChangesSubscription en canal admin
      ▼
  [Frontend]  ← Escucha cambios vía supabaseClientProvider


================================================================================
3. CÓMO REPRESENTAR SUPABASE CORRECTAMENTE
================================================================================

Supabase NO es una "nube". Se representa como:

  ┌─────────────────────────────────────────────────┐
  │  «node» Plataforma Supabase                      │
  │  ├── «artifact» supabase_auth_service            │
  │  │     └── «manifest» Autenticación Supabase     │
  │  ├── «artifact» schema_nutrireuma                │
  │  │     └── «manifest» Persistencia de datos      │
  │  ├── «artifact» funciones_recomendacion           │
  │  │     └── «manifest» Funciones auxiliares       │
  │  └── «artifact» storage_imagenes                 │
  │        └── «manifest» Almacenamiento multimedia  │
  └─────────────────────────────────────────────────┘

Reglas:
  - Usar estereotipo «node» para Supabase.
  - NO usar símbolo de nube decorativa.
  - Los artefactos van DENTRO del nodo (listados con «deploy»).
  - Los artefactos «manifiestan» componentes (relación «manifest»).


================================================================================
4. ARTEFACTOS Y QUÉ COMPONENTE MANIFIESTA CADA UNO
================================================================================

  ARTEFACTO                        → MANIFIESTA (componente)
  ─────────────────────────────────────────────────────────────
  flutter_web_build                → Frontend Web NutriReuma
  nutrireuma_app.apk               → App Móvil NutriReuma
  backend_fastapi_container        → Backend / API FastAPI
  [contiene lógica de negocio]     → (se manifiesta INTERNAMENTE
  [contiene seguridad/roles]        →  como parte del backend)
  supabase_auth_service            → Autenticación Supabase
  schema_nutrireuma                → Persistencia de datos
  funciones_recomendacion          → Funciones auxiliares

IMPORTANTE: "Lógica de negocio" y "Seguridad/autorización" NO son
componentes independientes a nivel de diagrama de despliegue.
Son SUBSISTEMAS o paquetes internos del Backend / API FastAPI.
Para mantener el diagrama a alto nivel, se recomienda:

  OPCIÓN A (RECOMENDADA):
  - Solo mostrar "Backend / API FastAPI" como componente.
  - En una nota adjunta: "Contiene: lógica de negocio, casos de
    uso, autorización por rol, validación JWT."

  OPCIÓN B (si se requiere más detalle):
  - Dentro del nodo "Servidor API NutriReuma", incluir como
    componentes internos (anidados):
      ├── «component» Backend / API FastAPI
      │     └── (contiene internamente)
      │         ├── Lógica de negocio y casos de uso
      │         └── Seguridad y autorización por rol
  - Pero esto ya rompe la regla #3 (alto nivel).


================================================================================
5. NODOS DEL DIAGRAMA (ESTRUCTURA FINAL RECOMENDADA)
================================================================================

  ┌─────────────────────────────────────────────────────────────┐
  │ NODO                   │ ESTEREOTIPO │ PROPÓSITO            │
  ├────────────────────────┼─────────────┼──────────────────────┤
  │ Cliente Navegador Web  │ «device»    │ Ejecuta Flutter Web   │
  │ Dispositivo Móvil      │ «device»    │ Ejecuta Flutter APK   │
  │ Red de acceso /        │ «device»    │ Red entre cliente     │
  │   Internet HTTPS       │             │ y servidor            │
  │ Servidor API           │ «node»      │ Contenedor FastAPI    │
  │   NutriReuma           │             │                      │
  │ Red de servicios       │ «device»    │ Red entre backend     │
  │   externos /           │             │ y Supabase            │
  │   Internet segura      │             │                      │
  │ Plataforma Supabase    │ «node»      │ Servicios Supabase    │
  └────────────────────────┴─────────────┴──────────────────────┘

Orden lógico (izquierda a derecha):

  [Cliente Web] ──┐
                   ├──→ [Red de acceso / Internet HTTPS] ──→ [Servidor API NutriReuma] ──→ [Red servicios externos / Internet segura] ──→ [Plataforma Supabase]
  [Dispositivo    ──┘
   Móvil]


================================================================================
6. CONEXIONES Y FLUJO DE RED (ETIQUETAS CORRECTAS)
================================================================================

Conexión 1: Cliente → Red de acceso
  - Estereotipo: «communication»
  - Etiqueta: HTTPS REST/JSON + Bearer Token

Conexión 2: Red de acceso → Servidor API
  - Estereotipo: «communication»
  - Etiqueta: HTTPS REST/JSON + Bearer Token

Conexión 3: Servidor API → Red servicios externos
  - Estereotipo: «communication»
  - Etiqueta: SQL/API segura + Service Role JWT

Conexión 4: Red servicios externos → Plataforma Supabase
  - Estereotipo: «communication»
  - Etiqueta: HTTPS (PostgreSQL / REST / Realtime)

Conexión 5 (opcional): Cliente Web/Móvil → Red de acceso → Plataforma Supabase
  (solo para autenticación directa vía supabase_flutter SDK)
  - Etiqueta: HTTPS (Supabase Auth) + Anon Key

Relaciones internas a nodo:
  - «deploy» (del nodo al artefacto)
  - «manifest» (del artefacto al componente)


================================================================================
7. EVALUACIÓN DE LA ESTRUCTURA QUE PROPUSISTE
================================================================================

Veamos punto por punto tu propuesta:

✔ Nodos principales: Correctos. Los 6 nodos están bien elegidos.
✔ «device» Cliente Web → bien.
✔ «device» Dispositivo móvil Android → bien.
✔ «device» Red de acceso / Internet HTTPS → bien.
✔ «node» Servidor API NutriReuma → bien.
✔ «device» Red de servicios externos / Internet segura → bien.
✔ «node» Plataforma Supabase → bien.

✘ Artefacto "backend_fastapi_container": Está bien, pero considera
  que es un contenedor Docker. El nombre debería reflejar que es
  desplegable. Puede ser «artifact» backend_fastapi_container.

✘ Artefactos "supabase_auth_service", "schema_nutrireuma",
  "funciones_recomendacion": Necesitas especificar que son
  artefactos DENTRO del nodo Supabase.

⚠ Componentes "Lógica de negocio y casos de uso" y "Seguridad y
  autorización por rol": Tal como están, son componentes separados.
  A nivel alto deberían estar DENTRO del componente Backend o
  como nota, NO como componentes independientes en el diagrama
  de despliegue. Si los pones sueltos, parecerán servicios
  independientes desplegados por separado.

⚠ Componente "Persistencia de datos NutriReuma": Debe estar
  DENTRO del nodo Plataforma Supabase, no flotando.

⚠ Componente "Funciones auxiliares de recomendación": Debe
  estar DENTRO del nodo Plataforma Supabase.

⚠ No viste el almacenamiento de imágenes (recipe images via
  Supabase Storage). El código usa recipe_image_service.dart
  para subir imágenes. Considera agregar:
    - «artifact» storage_recetas → «manifest» Almacenamiento de
      imágenes

⚠ No representaste la conexión directa del frontend a Supabase
  Auth. El código REAL usa supabase_flutter SDK para login.
  Si omites esto, el diagrama no refleja la autenticación real.


================================================================================
8. NOMBRES ALINEADOS A NUTRIREUMA (RECOMENDACIONES FINALES)
================================================================================

  ELEMENTO                    NOMBRE RECOMENDADO
  ─────────────────────────────────────────────────────────────
  Nodo cliente web            Cliente Navegador Web
  Nodo cliente móvil          Dispositivo Móvil Android
  Nodo red cliente-servidor   Red de acceso / Internet HTTPS
  Nodo servidor               Servidor API NutriReuma
  Nodo red servidor-supabase  Red de servicios externos /
                                Internet segura
  Nodo supabase               Plataforma Supabase
  Artefacto web               flutter_web_build
  Artefacto móvil             nutrireuma_app.apk
  Artefacto backend           backend_fastapi_container
  Artefacto auth supabase     supabase_auth_service
  Artefacto BD                schema_nutrireuma
  Artefacto functions         funciones_recomendacion
  Artefacto storage           storage_imagenes_recetas
  Componente web              Frontend Web NutriReuma
  Componente móvil            App Móvil NutriReuma
  Componente backend          Backend / API FastAPI
  Componente auth             Autenticación Supabase
  Componente BD               Persistencia de datos NutriReuma
  Componente functions        Funciones de recomendación
  Componente storage          Almacenamiento multimedia


================================================================================
9. QUÉ NO INCLUIR (PARA NO SOBRECARGAR)
================================================================================

✘ .env como componente o artefacto         → Ir como nota
✘ Clases individuales (User, Patient, etc.) → Demasiado detalle
✘ Repositorios específicos (supabase_crud)  → Detalle interno
✘ Middleware detallado (CORS, JWT, etc.)    → Va dentro del backend
✘ Providers de Flutter (Riverpod)           → Detalle interno
✘ Módulos por rol (admin, medico, etc.)    → Van dentro del frontend
✘ Base de datos en tiempo real             → Es parte de Supabase
✘ Nube decorativa                           → Violación UML estándar
✘ Métodos de API endpoints específicos     → Solo "REST/JSON"
✘ DTOs, serializadores                     → Son implementación


================================================================================
10. QUÉ MANTENER EN EL DIAGRAMA
================================================================================

✔ SOLO 6 nodos (los listados)
✔ SOLO 5-7 artefactos (los esenciales)
✔ SOLO 5-7 componentes (los que se manifiestan)
✔ Conexiones siempre a través de nodos de red
✔ Etiquetas claras y estándar UML
✔ Relaciones «deploy» y «manifest» donde corresponden
✔ Notas para información secundaria (roles, .env, frameworks)


================================================================================
11. PREGUNTAS ADICIONALES SOBRE AUTENTICACIÓN VS AUTORIZACIÓN
================================================================================

¿Autenticación o autorización por rol en el frontend?
  - El frontend usa Supabase Auth para autenticación (login).
  - El rol se obtiene desde la tabla `usuarios` a través de una
    consulta al backend o a Supabase. El frontend solo MUESTRA
    UI según el rol, pero NO valida permisos.
  - La validación REAL de permisos ocurre en el middleware de
    FastAPI, que rechaza requests si el rol no coincide.
  - Conclusión: La autorización por rol es del BACKEND.
    Representar como parte del componente Backend / API FastAPI.


¿Debe aparecer la conexión directa Frontend → Supabase Auth?
  - Sí, porque el código REAL hace Supabase.initialize() y
    auth.signInWithPassword() desde el frontend.
  - Sin embargo, pasa por el mismo nodo "Red de acceso / Internet
    HTTPS" que las llamadas al backend.
  - Etiqueta sugerida: HTTPS (Supabase Auth) + Anon Key


¿Debe aparecer Supabase Realtime?
  - Opcional. Si se quiere mostrar, es un canal dentro de
    "Plataforma Supabase" que envía eventos al frontend.
  - Etiqueta: WebSocket (Realtime)


================================================================================
12. DIAGRAMA UML COMPLETO (TEXTO ESTRUCTURADO)
================================================================================

A continuación, la versión textual del diagrama UML combinado de
despliegue y componentes. Cada elemento con su estereotipo.


┌─────────────────────────────────────────────────────────────────┐
│ DIAGRAMA DE DESPLIEGUE ENRIQUECIDO CON COMPONENTES             │
│ PLATAFORMA: NutriReuma                                         │
│ UML 2.5 — Deployment Diagram + Component Diagram               │
└─────────────────────────────────────────────────────────────────┘


─── NODO 1: Cliente Navegador Web ─────────────────────────────────

  «device»
  ┌─────────────────────────────────────────┐
  │ Cliente Navegador Web                   │
  │                                         │
  │  «deploy»                               │
  │  ┌─────────────────────────────────┐    │
  │  │ «artifact» flutter_web_build    │    │
  │  │                                 │    │
  │  │  «manifest»                     │    │
  │  │  ┌─────────────────────────┐    │    │
  │  │  │ «component»             │    │    │
  │  │  │ Frontend Web NutriReuma │    │    │
  │  │  └─────────────────────────┘    │    │
  │  └─────────────────────────────────┘    │
  └─────────────────────────────────────────┘


─── NODO 2: Dispositivo Móvil Android ────────────────────────────

  «device»
  ┌─────────────────────────────────────────┐
  │ Dispositivo Móvil Android               │
  │                                         │
  │  «deploy»                               │
  │  ┌─────────────────────────────────┐    │
  │  │ «artifact» nutrireuma_app.apk   │    │
  │  │                                 │    │
  │  │  «manifest»                     │    │
  │  │  ┌─────────────────────────┐    │    │
  │  │  │ «component»             │    │    │
  │  │  │ App Móvil NutriReuma   │    │    │
  │  │  └─────────────────────────┘    │    │
  │  └─────────────────────────────────┘    │
  └─────────────────────────────────────────┘


─── NODO 3: Red de acceso / Internet HTTPS ───────────────────────

  «device»
  ┌─────────────────────────────────────────┐
  │ Red de acceso / Internet HTTPS          │
  │                                         │
  │  Punto de tránsito:                     │
  │  • HTTPS / TLS 1.3                      │
  │  • REST + JSON                          │
  │  • Bearer Token (JWT)                   │
  │  • WebSocket (Realtime)                 │
  └─────────────────────────────────────────┘


─── NODO 4: Servidor API NutriReuma ──────────────────────────────

  «node»
  ┌──────────────────────────────────────────────┐
  │ Servidor API NutriReuma                      │
  │                                              │
  │  «deploy»                                    │
  │  ┌────────────────────────────────────────┐  │
  │  │ «artifact» backend_fastapi_container   │  │
  │  │                                        │  │
  │  │  «manifest»                            │  │
  │  │  ┌────────────────────────────────┐   │  │
  │  │  │ «component»                    │   │  │
  │  │  │ Backend / API FastAPI          │   │  │
  │  │  │                                │   │  │
  │  │  │  ┌──────────────────────┐      │   │  │
  │  │  │  │ Lógica de negocio    │      │   │  │
  │  │  │  │ y casos de uso       │      │   │  │
  │  │  │  └──────────────────────┘      │   │  │
  │  │  │  ┌──────────────────────┐      │   │  │
  │  │  │  │ Seguridad y          │      │   │  │
  │  │  │  │ autorización por rol │      │   │  │
  │  │  │  └──────────────────────┘      │   │  │
  │  │  └────────────────────────────────┘   │  │
  │  └────────────────────────────────────────┘  │
  └──────────────────────────────────────────────┘

  Nota: [Los subsistemas internos "Lógica de negocio" y
   "Seguridad" son parte del componente Backend, no son
   componentes independientes en el diagrama de despliegue]


─── NODO 5: Red de servicios externos / Internet segura ─────────

  «device»
  ┌─────────────────────────────────────────┐
  │ Red de servicios externos /             │
  │ Internet segura                         │
  │                                         │
  │  Punto de tránsito:                     │
  │  • HTTPS / TLS 1.3                      │
  │  • SQL sobre HTTPS (pgbouncer)          │
  │  • REST API + Service Role JWT          │
  │  • Edge Functions HTTP                  │
  └─────────────────────────────────────────┘


─── NODO 6: Plataforma Supabase ─────────────────────────────────

  «node»
  ┌───────────────────────────────────────────────────────┐
  │ Plataforma Supabase                                   │
  │                                                       │
  │  «deploy»  ┌──────────────────────────────────┐       │
  │  ┌─────────┤ «artifact» supabase_auth_service  │       │
  │  │         │                                    │       │
  │  │         │  «manifest»                        │       │
  │  │         │  ┌────────────────────────────┐    │       │
  │  │         │  │ «component»                │    │       │
  │  │         │  │ Autenticación Supabase     │    │       │
  │  │         │  └────────────────────────────┘    │       │
  │  │         └──────────────────────────────────┘       │
  │  │                                                    │
  │  │  ┌──────────────────────────────────┐              │
  │  ├──┤ «artifact» schema_nutrireuma     │              │
  │  │  │  «manifest»                      │              │
  │  │  │  ┌────────────────────────────┐  │              │
  │  │  │  │ «component»                │  │              │
  │  │  │  │ Persistencia de datos      │  │              │
  │  │  │  │ NutriReuma                 │  │              │
  │  │  │  └────────────────────────────┘  │              │
  │  │  └──────────────────────────────────┘              │
  │  │                                                    │
  │  │  ┌──────────────────────────────────┐              │
  │  ├──┤ «artifact» funciones_recomendacion│             │
  │  │  │  «manifest»                      │              │
  │  │  │  ┌────────────────────────────┐  │              │
  │  │  │  │ «component»                │  │              │
  │  │  │  │ Funciones de recomendación │  │              │
  │  │  │  └────────────────────────────┘  │              │
  │  │  └──────────────────────────────────┘              │
  │  │                                                    │
  │  │  ┌──────────────────────────────────┐              │
  │  └──┤ «artifact» storage_imagenes      │              │
  │     │  «manifest»                      │              │
  │     │  ┌────────────────────────────┐  │              │
  │     │  │ «component»                │  │              │
  │     │  │ Almacenamiento multimedia  │  │              │
  │     │  └────────────────────────────┘  │              │
  │     └──────────────────────────────────┘              │
  └───────────────────────────────────────────────────────┘


─── CONEXIONES ──────────────────────────────────────────────────

  [Cliente Navegador Web] ─────────────────────────────────┐
      │  «communication»                                    │
      │  HTTPS REST/JSON + Bearer Token                    │
      │  HTTPS (Supabase Auth) + Anon Key                  │
      ▼                                                    │
  [Red de acceso / Internet HTTPS] ◄────────────────────────┘
      │  «communication»
      │  HTTPS REST/JSON + Bearer Token
      ▼
  [Servidor API NutriReuma]
      │  «communication»
      │  SQL/API segura + Service Role JWT
      ▼
  [Red de servicios externos / Internet segura]
      │  «communication»
      │  HTTPS (PostgreSQL / REST / Edge Functions)
      ▼
  [Plataforma Supabase]


─── FLUJO COMPLETO (TRAZABILIDAD EXTREMO A EXTREMO) ──────────────

  1. Usuario abre flutter_web_build en navegador
     → Frontend Web NutriReuma solicita login
     → HTTPS (Supabase Auth) + Anon Key
     → Red de acceso / Internet HTTPS
     → Plataforma Supabase (supabase_auth_service)
     → Devuelve JWT + session

  2. Frontend Web NutriReuma tiene JWT
     → HTTPS REST/JSON + Bearer Token
     → Red de acceso / Internet HTTPS
     → Servidor API NutriReuma
     → backend_fastapi_container recibe request
     → Seguridad y autorización por rol valida JWT + rol
     → Lógica de negocio ejecuta caso de uso
     → SQL/API segura + Service Role JWT
     → Red de servicios externos / Internet segura
     → Plataforma Supabase (schema_nutrireuma / functions)
     → Respuesta viaja de vuelta por el mismo camino

  3. Admin sube imagen de receta
     → Frontend Web NutriReuma
     → HTTPS REST/JSON + Bearer Token
     → Red de acceso / Internet HTTPS
     → Servidor API NutriReuma
     → backend_fastapi_container procesa y sube
     → SQL/API segura + Service Role JWT
     → Red de servicios externos / Internet segura
     → Plataforma Supabase (storage_imagenes)
     → URL firmada devuelta al frontend


================================================================================
13. ETIQUETAS RECOMENDADAS PARA LAS CONEXIONES
================================================================================

  CONEXIÓN                           ETIQUETA
  ─────────────────────────────────────────────────────────────
  Cliente → Red de acceso            HTTPS REST/JSON + Bearer Token
  Cliente → Red de acceso (auth)     HTTPS (Supabase Auth) + Anon Key
  Red de acceso → Servidor API       Reenvía: HTTPS REST/JSON
  Servidor API → Red servicios       SQL/API segura + Service Role JWT
  Red servicios → Supabase           HTTPS (PostgreSQL / REST / Functions)
  Supabase → Frontend (Realtime)     WebSocket (Realtime)
  Nodo → Artefacto                   «deploy»
  Artefacto → Componente             «manifest»


================================================================================
14. CORRECCIONES A TU PROPUESTA ORIGINAL
================================================================================

Corrección 1:
  Tus componentes "Lógica de negocio y casos de uso" y
  "Seguridad y autorización por rol" deben estar ANIDADOS
  dentro de "Backend / API FastAPI" o ser referenciados como
  nota. Si los pones al mismo nivel, parecerán nodos
  independientes.

Corrección 2:
  "Persistencia de datos NutriReuma" y "Funciones auxiliares
  de recomendación" deben estar DENTRO del nodo
  "Plataforma Supabase", no fuera.

Corrección 3:
  Agregar "Almacenamiento multimedia" como componente dentro
  de Supabase para reflejar el uso real de Supabase Storage
  (recipe_image_service.dart).

Corrección 4:
  Agregar conexión de autenticación directa Frontend →
  Supabase Auth, porque el código REAL usa supabase_flutter
  SDK con anon key, no pasa por FastAPI.

Corrección 5:
  La red "Red de servicios externos / Internet segura" debe
  aparecer entre Servidor API y Supabase, no al mismo nivel
  que la red de acceso.

Corrección 6:
  Las conexiones no deben ser flechas directas Cliente →
  Servidor. Deben ser:
    Cliente → Red → Servidor → Red → Supabase
  Esto ya lo tienes bien en tu planteamiento original.


================================================================================
15. VERIFICACIÓN CONTRA LAS 15 OBSERVACIONES DE CORRECCIÓN
================================================================================

  #  OBSERVACIÓN                       ESTADO
  ─────────────────────────────────────────────────────────────
  1  Arquitectura simplificada         ✔ 5-7 componentes
  2  Sin detalle interno               ✔ Sin clases/repos
  3  App + dominio unificados          ✔ Viven dentro del backend
  4  Comp. = despliegue                ✔ Mismos nombres en ambos
  5  Sin nube decorativa               ✔ Supabase es «node»
  6  Supabase como nodo UML           ✔ «node» Plataforma Supabase
  7  Conexiones por red                ✔ 2 nodos de red
  8  Nodo red entre cliente y API      ✔ «device» Red de acceso
  9  Nodo red entre API y Supabase     ✔ «device» Red servicios
  10  UML despliegue + componentes     ✔ Enriquecido
  11  «deploy» correcto                ✔ Nodo → Artefacto
  12  «manifest» correcto              ✔ Artefacto → Componente
  13  .env como nota, no bloque        ✔ Nota, no diagrama
  14  Autorización por rol en backend  ✔ Dentro de FastAPI
  15  Auth en Supabase, authz en API   ✔ Roles validados en backend


================================================================================
16. RECOMENDACIÓN FINAL
================================================================================

Tu estructura propuesta es 85% correcta. Solo necesitas:

  1. ANIDAR "Lógica de negocio" y "Seguridad" dentro del
     backend (o ponerlos como nota).

  2. MOVER "Persistencia" y "Funciones" dentro del nodo
     Supabase.

  3. AGREGAR "Almacenamiento multimedia" (storage).

  4. AGREGAR la ruta de autenticación directa Frontend →
     Supabase (no pasa por FastAPI).

  5. Colocar las conexiones en el orden correcto:
     Cliente → Red acceso → Servidor API → Red servicios →
     Supabase.

El diagrama resultante tendrá 6 nodos, 6-7 artefactos,
6-7 componentes, y 2 nodos de red intermedios,
cumpliendo estrictamente con UML 2.5 estándar.

================================================================================
FIN DEL DOCUMENTO
================================================================================
