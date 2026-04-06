# Runbook Despliegue Etiquetas Configurables

## Objetivo

Desplegar el motor de reglas de etiquetas nutricionales en una base que puede estar en modo legacy (`dom_nutricion`) y dejar validado el estado final.

## Precondiciones

- Tener `DATABASE_URL` valido en `backend/.env`.
- Tener Python 3.11+ y dependencias del backend instaladas.
- Ejecutar desde la raiz del repo.

## Orden de ejecucion SQL (obligatorio)

1. Compatibilidad legacy -> split schemas:

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/bootstrap_dom_nutricion_split_from_legacy.sql
```

2. Motor de etiquetas:

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/nutricion_etiquetas_motor_20260404.sql
```

3. Ajustes de longitud y consistencia:

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/fix_etiqueta_regla_condicion_campo_objetivo_len_20260405.sql
```

4. RLS reglas:

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/rls_dom_nutricion_reglas_20260404.sql
```

5. Exposicion y grants PostgREST:

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/expose_schemas.sql
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/force_postgrest_schemas.sql
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/grant_postgrest_privileges.sql
```

6. Indices criticos:

```powershell
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" backend/scripts/apply_supabase_sql.py --env-file backend/.env --sql-file supabase/recreate_variable_idx.sql
```

## Verificacion post-despliegue

1. Backend:

```powershell
Set-Location "c:/Users/mirya/Desktop/Reuma Nutri/backend"
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" -m pytest -q
& "c:/Users/mirya/Desktop/Reuma Nutri/.venv-1/Scripts/python.exe" -c "import app.main; print('APP_IMPORT_OK')"
```

2. Flutter:

```powershell
Set-Location "c:/Users/mirya/Desktop/Reuma Nutri/frontend/flutter_app"
flutter analyze
flutter test
```

## Criterios de salida

- Cada aplicacion SQL devuelve `MIGRATION_APPLIED_OK`.
- `pytest` pasa.
- Import de app imprime `APP_IMPORT_OK`.
- `flutter analyze` sin errores bloqueantes.
- `flutter test` pasa.

## Rollback operativo sugerido

- Si falla en pasos 1-3, corregir script/estructura y reintentar desde el paso fallido.
- Si falla en pasos 4-6, revertir solo la parte de politicas/permisos/indices afectada y reaplicar.
- No ejecutar `base_de_datos.sql` completo sobre entornos con objetos existentes sin plan de migracion dedicado.