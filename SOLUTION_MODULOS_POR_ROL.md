# Solución: Usuario no puede acceder a módulos por rol

## Resumen del Problema
Usuario se queda en pantalla de inicio y no puede acceder a módulos de diferentes roles.

## Diagnóstico Completado

### ✅ BD Verificada
- Tabla `usuarios.usuario`: 4 usuarios activos con roles (admin, medico, nutricionista, tutor)
- Tabla `usuarios.rol`: Configurada correctamente (IDs 1-4, códigos en MAYÚSCULAS)
- Estructura correcta con `auth_user_id`, `id_rol`, `email`, `activo`

### ✅ Backend Verificado  
- `/health` → OK (status 200)
- `/auth-context` → OK (retorna correctamente el rol del usuario)
- Endpoint registrado y funcionando en puerto 8000

### ✅ Timeout Aumentado
- **CAMBIO REALIZADO**: `_roleBackendTimeout` de 2 segundos → 6 segundos
- **ARCHIVO**: `frontend/flutter_app/lib/core/state/app_providers.dart`
- También aumentado: `_roleUsersLookupTimeout` de 2s → 5s

## Causas Identificadas

### 1️⃣ Timeout Insuficiente (SOLUCIONADO)
- El timeout de 2 segundos era demasiado corto
- Si el backend tardaba más, el frontend fallaba a los fallbacks
- Resultado: El usuario siempre obtenía rol "tutor" por defecto
- **Solución**: Aumentado a 6 segundos

### 2️⃣ JWT sin Metadatos de Rol (REQUIERE SOLUCIÓN EN SUPABASE)
- Cuando el usuario se autentica en Supabase, el JWT NO incluye el rol en `app_metadata`
- El frontend intenta obtener el rol desde:
  1. JWT (fallido - no tiene role)
  2. Backend (EXITOSO después del timeout)
  3. BD directamente (como fallback)
- **Problema**: Sin metadatos en JWT, siempre requiere que el backend responda rápido

### 3️⃣ Falta de Sincronización de Roles en Supabase
- No hay un trigger que agregue el rol a los metadatos cuando el usuario se crea/autentica
- Esto es estándar en Supabase para aplicaciones con múltiples roles

## Soluciones Implementadas

### ✅ 1. Aumentado Timeouts en Frontend
```dart
// ANTES:
const Duration _roleBackendTimeout = Duration(seconds: 2);
const Duration _roleUsersLookupTimeout = Duration(seconds: 2);

// DESPUÉS:
const Duration _roleBackendTimeout = Duration(seconds: 6);
const Duration _roleUsersLookupTimeout = Duration(seconds: 5);
```

## Soluciones Recomendadas (SIGUIENTE PASO)

### 🔧 2. Agregar Trigger en Supabase para Sincronizar Roles

Crear un trigger en la tabla `auth.users` que agregue el rol a los metadatos:

```sql
-- 1. Crear función que se ejecute cuando se crea un usuario en auth.users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public, usuarios
as $$
begin
  -- Buscar el usuario en la tabla usuarios.usuario por email
  update auth.users
  set raw_app_meta_data = 
    jsonb_set(
      coalesce(raw_app_meta_data, '{}'::jsonb),
      '{role}',
      (select jsonb_build_object(
        'role',
        lower(r.codigo)
      ) from usuarios.usuario u
      inner join usuarios.rol r on r.id = u.id_rol
      where u.auth_user_id = new.id
      limit 1)::jsonb
    )
  where id = new.id;
  
  return new;
end;
$$;

-- 2. Crear trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- 3. Actualizar usuarios existentes
update auth.users
set raw_app_meta_data = 
  jsonb_set(
    coalesce(raw_app_meta_data, '{}'::jsonb),
    '{role}',
    (select jsonb_build_object(
      'role',
      lower(r.codigo)
    ) from usuarios.usuario u
    inner join usuarios.rol r on r.id = u.id_rol
    where u.auth_user_id = auth.users.id
    limit 1)::jsonb
  );
```

### 🔍 3. Verificación en Producción

Después de implementar los cambios:

1. **Prueba el login**:
   - Accede con `medico@reumanutri.app` / `password`
   - Deberías ver los módulos del médico (Pacientes, Historia Clínica, etc.)
   - NO solo el módulo "Mi Plan" del tutor

2. **Verifica el rol en el navegador** (Flutter web):
   - Abre DevTools (F12)
   - Network → busca requests a `/auth-context`
   - Verifica que retorna `"role": "medico"` (no `"tutor"`)

3. **Revisa localStorage** (Flutter web):
   - En Storage → LocalStorage
   - Busca `supabase.auth` para ver si el JWT contiene el rol

## Archivos Modificados

1. ✅ `frontend/flutter_app/lib/core/state/app_providers.dart`
   - Timeouts aumentados
   
2. 📝 `supabase/sql/` (PENDIENTE)
   - Necesita trigger para sincronizar roles

## Testing Recomendado

```bash
# Terminal 1: Backend
cd backend
python -m uvicorn app.main:app --reload --port 8000

# Terminal 2: Frontend
cd frontend/flutter_app
flutter run -d web

# Entonces:
# 1. Login con medico@reumanutri.app
# 2. Verifica que ve los módulos del médico
# 3. Cambia entre módulos usando la navegación lateral
# 4. Verifica que el rol persiste cuando refrescas la página
```

## Notas Importantes

- El backend SIEMPRE resuelve el rol correctamente desde la tabla `usuarios.usuario`
- El problema es que el frontend necesita esperar a que el backend responda
- El timeout de 6 segundos debería ser suficiente en la mayoría de casos
- En producción, considerar usar Supabase RLS + triggers para mejor seguridad

## Próximos Pasos

1. ✅ Implementar el trigger en Supabase (crear el SQL en `supabase/sql/`)
2. ✅ Aplicar el SQL a la BD de Supabase
3. ✅ Probar login con diferentes usuarios
4. ✅ Verificar que la navegación entre módulos funciona
5. ✅ Verificar que el rol persiste en refresco de página
