# Pasos de Correccion y Ejecucion

## 1) Backend FastAPI

1. Ir a la carpeta backend:

```powershell
cd backend
```

2. Crear entorno virtual:

```powershell
C:/Users/mirya/AppData/Local/Programs/Python/Python311/python.exe -m venv .venv
```

3. Instalar dependencias:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

4. Si aparece warning de invalid distribution ~ip, limpiar:

```powershell
Get-ChildItem ".venv\Lib\site-packages" -Filter "~ip*" | ForEach-Object { Remove-Item $_.FullName -Recurse -Force }
```

5. Crear y ajustar .env (ya creado en este proyecto):

- backend/.env

6. Levantar API:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

7. Verificar:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8000/health"
```

## 2) Supabase SQL (seed + RLS + schemas)

Desde Supabase SQL Editor, ejecutar en este orden:

```text
base_de_datos.sql
supabase/seed_catalogs.sql
supabase/rls_policies.sql
supabase/expose_schemas.sql
supabase/grant_postgrest_privileges.sql
supabase/seed_oms_demo.sql
```

Validacion recomendada:

- Probar login con un usuario de cada rol.
- Probar GET/SELECT de tablas expuestas por PostgREST.
- Probar endpoint protegido en FastAPI con bearer token del login.

## 3) Flutter SDK + Frontend

1. Instalar Flutter (si no existe):

```powershell
git clone https://github.com/flutter/flutter.git -b stable $env:USERPROFILE\flutter
```

2. Agregar Flutter al PATH (usuario):

```powershell
$flutterBin = "$env:USERPROFILE\flutter\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$flutterBin*") {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterBin", "User")
}
```

3. Preparar frontend:

```powershell
cd frontend/flutter_app
flutter config --enable-web
flutter create .
flutter pub get
```

4. Ejecutar en Chrome con defines:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://<project-id>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable-key> --dart-define=FASTAPI_BASE_URL=http://localhost:8000/api/v1
```

## 4) Errores comunes y como corregir

- Error: This application is not configured to build on the web
  - Solucion: ejecutar `flutter create .` en frontend/flutter_app.

- Error: Import "fastapi" could not be resolved
  - Solucion: activar entorno virtual o usar .venv para ejecutar uvicorn.

- Error: Invalid API key en cliente Supabase
  - Solucion: usar anon key o publishable key para frontend.
  - No usar sb_secret en cliente web.

- Error CORS en navegador
  - Solucion: revisar backend/.env y usar CORS_ORIGINS=* para pruebas.

- Error RLS bloquea tutor
  - Solucion: verificar que exista relacion en usuarios.tutor_paciente y que el JWT tenga role correcto en app_metadata.
