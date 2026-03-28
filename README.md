# Reuma Nutri - Base Full-Stack Multimodal

Base completa para una aplicacion de soporte nutricional clinico pediatrico con:

- Frontend: Flutter (Web + Mobile)
- Backend inteligente: FastAPI
- Backend directo: Supabase (PostgreSQL + Auth + Storage)

## 1) Estructura del proyecto

```text
Reuma Nutri/
  backend/
    app/
      api/
      core/
      repositories/
      schemas/
      services/
        admin_medico/
        nutricion_tutor/
        compartido/
      main.py
    tests/
    requirements.txt
    .env.example
  frontend/
    flutter_app/
      lib/
      pubspec.yaml
  supabase/
    rls_policies.sql
    seed_catalogs.sql
  docs/
    abrir_tutor_en_celular.md
    arquitectura_patrones.md
    architecture_multimodal.md
    division_backend_endpoints.md
    estructura_por_capas.md
    module_traceability.md
    pasos_correccion.md
    pasos_reparto_equipo.md
    responsabilidades_distribuidas.md
  base_de_datos.sql
```

## 2) Arquitectura operativa

### Patron multimodal

- Modo 1 (Directo a Supabase): CRUD de catalogos y registros simples.
- Modo 2 (Inteligente via FastAPI): calculos, reglas, filtrado, planificacion y aprendizaje.

### Regla de uso

- Operaciones simples -> Flutter usa Supabase SDK directo.
- Operaciones complejas -> Flutter llama FastAPI y FastAPI usa PostgreSQL/Supabase.

## 3) Endpoints FastAPI incluidos

- POST /api/v1/imc-calculo
- POST /api/v1/diagnostico-oms
- POST /api/v1/reglas-evaluacion
- POST /api/v1/ingredientes-permitidos
- POST /api/v1/recetas-permitidas
- POST /api/v1/plan-automatico
- POST /api/v1/reemplazo-equivalente
- POST /api/v1/adherencia-calculo
- POST /api/v1/preferencias-aprendidas

## 4) Seguridad y RLS

- JWT de Supabase validado en FastAPI.
- Roles soportados: admin, medico, nutricionista, tutor.
- Politicas RLS por rol y por relacion tutor-paciente en:
  - supabase/rls_policies.sql

## 5) Levantar backend FastAPI

1. Crear entorno e instalar dependencias:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

2. Configurar variables:

```powershell
copy .env.example .env
# luego editar .env
```

3. Ejecutar API:

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## 6) Levantar Flutter separado (web y mobile tutor)

### Web (Admin, Medico, Nutricionista)

```powershell
cd frontend/flutter_app
flutter pub get
flutter run -d chrome -t lib/main_web.dart --dart-define=SUPABASE_URL=https://<project-id>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable-key> --dart-define=FASTAPI_BASE_URL=http://<ip-local>:8000/api/v1
```

### Mobile Tutor (Android/iOS)

```powershell
cd frontend/flutter_app
flutter pub get
flutter run -d <DEVICE_ID> -t lib/main_tutor_mobile.dart --dart-define=SUPABASE_URL=https://<project-id>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable-key> --dart-define=FASTAPI_BASE_URL=http://<ip-local>:8000/api/v1
```

Si aun no aparece telefono en flutter devices, revisa docs/abrir_tutor_en_celular.md.

## 7) Configuracion Supabase recomendada

1. Ejecutar en SQL Editor:
   - base_de_datos.sql
   - supabase/seed_catalogs.sql
   - supabase/rls_policies.sql

2. En API Settings exponer schemas:
   - usuarios, clinico, nutricion, interaccion, heuristico, referencia

3. Guardar app_metadata.role en el usuario autenticado.

## 8) Reparto de equipo y arquitectura

- Arquitectura distribuida y ownership: docs/responsabilidades_distribuidas.md
- Patrones arquitectonicos aplicados: docs/arquitectura_patrones.md
- Division de endpoints backend: docs/division_backend_endpoints.md
- Estructura final por capas y carpetas por profesional: docs/estructura_por_capas.md
- Plan de reparto practico por semana: docs/pasos_reparto_equipo.md

## 9) Modulos por rol incluidos en Flutter

- Admin:
  - Gestion de usuarios
  - Catalogos

- Medico:
  - Registro clinico
  - Diagnostico OMS
  - Reglas medicas

- Nutricionista:
  - Ingredientes
  - Recetas
  - Plan manual (semana tipo + replicacion)
  - Reglas nutricionales

- Tutor:
  - Ver plan
  - Registrar consumo
  - Reemplazo por equivalentes
  - Calificacion de recetas
