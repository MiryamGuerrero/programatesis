# Arquitectura Distribuida y Reparto de Responsabilidades

## 1. Arquitectura distribuida (entendible)

### Capa de presentacion -> Flutter
- Web App: Admin, Medico, Nutricionista.
- Mobile App Tutor: solo Tutor.
- Entrypoints separados para despliegue:
  - lib/main_web.dart
  - lib/main_tutor_mobile.dart

### Capa de datos -> Supabase
- PostgreSQL como fuente de verdad.
- Auth para identidad y rol.
- RLS para seguridad por perfil y por relacion tutor-paciente.

### Capa de logica inteligente -> FastAPI
- Endpoints de calculo y decision automatica.
- FastAPI consulta PostgreSQL con reglas y referencias OMS.

## 2. Patrones que esta usando el sistema

- Arquitectura en capas:
  - presentacion, acceso a datos, servicios de negocio.
- BaaS (Backend as a Service):
  - Supabase para Auth, DB y Storage.
- Microservicio de inteligencia:
  - FastAPI como servicio especializado para logica compleja.
- Sistema experto:
  - motor de reglas (eliminar, reducir, priorizar).
- Sistema adaptativo:
  - aprendizaje de preferencias en base a consumo/calificacion.

## 3. Division de trabajo entre 2 personas

### Persona A -> Admin + Medico
Responsabilidad funcional:
- Gestion de usuarios
- Registro clinico
- Diagnostico OMS
- Reglas medicas

Responsabilidad tecnica:
- Flutter web modules: features/admin, features/medico
- FastAPI endpoints: admin_medico.py
- FastAPI services: backend/app/services/admin_medico
- Supabase schemas foco: usuarios, clinico

### Persona B -> Nutricionista
Responsabilidad funcional:
- Ingredientes
- Recetas
- Plan manual y plan automatico
- Reglas nutricionales
- Preferencias aprendidas

Responsabilidad tecnica:
- Flutter web modules: features/nutricionista
- FastAPI endpoints: nutricion_tutor.py
- FastAPI services: backend/app/services/nutricion_tutor
- Supabase schemas foco: nutricion, heuristico, interaccion, referencia

### Fase conjunta (A + B) -> App movil Tutor
Responsabilidad funcional:
- Ver plan
- Registrar consumo
- Reemplazos
- Calificar recetas

Responsabilidad tecnica:
- Flutter mobile entrypoint: main_tutor_mobile.dart
- Flutter modules: features/tutor
- FastAPI servicios compartidos: backend/app/services/compartido
- Integracion final con endpoints y RLS

## 4. Reglas de colaboracion para no pisarse

- Una persona por carpeta funcional principal.
- PRs pequenos por modulo.
- Contrato API estable via schemas Pydantic.
- Migraciones SQL versionadas y revisadas por ambos.
- QA cruzado: A prueba modulos B y B prueba modulos A.

## 5. Comandos de ejecucion separados

### Web (Admin, Medico, Nutricionista)
flutter run -d chrome -t lib/main_web.dart --dart-define=SUPABASE_URL=https://yuasobxhctmukvozmrta.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_IDWe5z7tqSdlHW4rixjDfw_vJxoFaAL --dart-define=FASTAPI_BASE_URL=http://192.168.100.12:8000/api/v1

### Mobile Tutor (Android/iOS)
flutter run -d <DEVICE_ID> -t lib/main_tutor_mobile.dart --dart-define=SUPABASE_URL=https://yuasobxhctmukvozmrta.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_IDWe5z7tqSdlHW4rixjDfw_vJxoFaAL --dart-define=FASTAPI_BASE_URL=http://192.168.100.12:8000/api/v1

## 6. Nota importante para celular

Actualmente Flutter detecta dispositivos web/desktop, no telefono fisico.
Para correr en telefono necesitas:
- Android Studio + Android SDK
- habilitar USB debugging
- validar que flutter devices muestre el telefono
