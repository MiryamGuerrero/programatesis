# Runbook Despliegue Etiquetas Configurables

## Objetivo

Desplegar el motor de reglas de etiquetas nutricionales usando solo scripts canónicos y entorno único.

## Precondiciones

- Tener DATABASE_URL válido en backend/.env.
- Tener Python 3.11+ y dependencias instaladas en .venv.
- Ejecutar desde la raíz del repo.

## Entorno único

```powershell
cd c:/Users/mirya/Desktop/Reuma Nutri
.\.venv\Scripts\Activate.ps1
```

## Orden de ejecución SQL (canónico)

1. Motor de etiquetas:

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/nutricion_etiquetas_motor.sql
```

2. RLS del motor de reglas:

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/rls_dom_nutricion_reglas.sql
```

3. Exposición y grants PostgREST:

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/expose_schemas.sql
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/force_postgrest_schemas.sql
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/grant_postgrest_privileges.sql
```

4. Políticas generales y datos base (si aplica):

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/rls_policies.sql
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/seed_catalogs.sql
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/seed_oms_demo.sql
```

## Verificación post-despliegue

1. Backend:

```powershell
Set-Location "c:/Users/mirya/Desktop/Reuma Nutri/backend"
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" -m pytest -q
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv/Scripts/python.exe" -c "import app.main; print('APP_IMPORT_OK')"
```

2. Flutter:

```powershell
Set-Location "c:/Users/mirya/Desktop/Reuma Nutri/frontend/flutter_app"
flutter analyze
flutter test
```

## Criterios de salida

- Cada aplicación SQL devuelve MIGRATION_APPLIED_OK.
- pytest pasa.
- Import de app imprime APP_IMPORT_OK.
- flutter analyze sin errores bloqueantes.
- flutter test pasa.