# Arranque de la app

## 1. Requisitos previos

- Python 3.11+
- Flutter SDK instalado
- Chrome (para web)
- Proyecto Supabase activo
- Credenciales y variables en backend/.env

## 2. Configurar variables backend

Archivo:

- backend/.env

Base recomendada:

- copiar desde backend/.env.example

Variables clave:

- SUPABASE_URL
- SUPABASE_ANON_KEY
- SUPABASE_SERVICE_ROLE_KEY
- SUPABASE_JWT_SECRET
- ONBOARDING_WEB_REDIRECT_URL
- ONBOARDING_TUTOR_REDIRECT_URL
- DATABASE_URL
- CORS_ORIGINS

Valores sugeridos en desarrollo:

- ONBOARDING_WEB_REDIRECT_URL=http://localhost:3000
- ONBOARDING_TUTOR_REDIRECT_URL=reumanutri://auth/set-password

## 3. Levantar backend FastAPI

Desde la raiz del proyecto:

```powershell
cd <raiz-del-proyecto>
python -m venv .venv
.\.venv\Scripts\Activate.ps1
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Validacion:

- abrir http://127.0.0.1:8000/health
- respuesta esperada: {"status":"ok"}

## 4. Levantar frontend web (admin, medico, nutricionista)

En otra terminal:

```powershell
cd frontend/flutter_app
flutter pub get
flutter run -d chrome -t lib/main_web.dart --dart-define=SUPABASE_URL=https://<project-id>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable-key> --dart-define=FASTAPI_BASE_URL=http://127.0.0.1:8000/api/v1
```

## 5. Levantar app tutor mobile

En otra terminal:

```powershell
cd frontend/flutter_app
flutter pub get
flutter run -d <DEVICE_ID> -t lib/main_tutor_mobile.dart --dart-define=SUPABASE_URL=https://<project-id>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable-key> --dart-define=FASTAPI_BASE_URL=http://<ip-local-o-host>:8000/api/v1
```

Notas:

- En movil, FASTAPI_BASE_URL debe apuntar a una IP accesible por el dispositivo.
- Verifica el dispositivo con flutter devices.

## 6. Orden recomendado de arranque

1. Backend FastAPI
2. Frontend web
3. Frontend mobile (si aplica)

## 7. Problemas comunes

### 7.1 Pantalla de configuracion faltante en Flutter

Causa:

- faltan SUPABASE_URL o SUPABASE_ANON_KEY en los --dart-define.

### 7.2 Error de CORS al consumir API

Causa:

- CORS_ORIGINS incompleto en backend/.env.

### 7.3 Login falla en web

Revisar:

- URL/key de Supabase correctas
- usuario habilitado en Supabase Auth
- politicas RLS y role metadata

## 9. Configuracion Supabase para onboarding por email

Esta app crea usuarios en Supabase Auth desde backend y envia un correo para configurar contrasena inicial.

### 9.1 SMTP y remitente

En Supabase Dashboard:

1. Authentication > Providers > Email.
2. Activar Custom SMTP.
3. Configurar SMTP de Gmail (ya lo tienes hecho) y guardar.
4. Verificar remitente y nombre del remitente.

### 9.2 URLs de redireccion

En Authentication > URL Configuration:

1. Configurar Site URL (por ejemplo tu web de produccion).
2. Agregar Additional Redirect URLs:
	- http://localhost:3000
	- https://tu-web-produccion
	- reumanutri://auth/set-password

Notas:

- Para tutor, la app movil abre deep link con esquema reumanutri.
- Para admin/medico/nutricionista, el enlace abre la web.

### 9.3 Plantilla de correo de recuperacion

En Authentication > Email Templates > Reset Password:

1. Mantener habilitada la plantilla.
2. Usar el boton/link con {{ .ConfirmationURL }} en el HTML.
3. Ajustar el texto para indicar que es configuracion inicial de contrasena.

### 9.4 Politica de password

En Authentication > Policies:

1. Definir largo minimo recomendado (>= 8).
2. Si activas reglas mas estrictas, reflejarlas en el frontend.

### 9.5 Prueba end-to-end

1. Iniciar backend y frontend.
2. Crear usuario desde Admin (admin/medico/nutricionista) o registrar tutor desde Medico.
3. Verificar recepcion de correo.
4. Abrir enlace:
	- tutor -> app movil (deep link)
	- otros roles -> web
5. Configurar contrasena y validar login.

## 8. Endpoints de negocio principales

Todos bajo prefijo:

- /api/v1

Ejemplos:

- POST /imc-calculo
- POST /diagnostico-oms
- POST /reglas-evaluacion
- POST /ingredientes-permitidos
- POST /recetas-permitidas
- POST /plan-automatico
- POST /reemplazo-equivalente
- POST /adherencia-calculo
- POST /preferencias-aprendidas
