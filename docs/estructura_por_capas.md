# Estructura final por capas y profesionales

## 1) Capa de presentacion (Flutter)

Ruta base: frontend/flutter_app/lib

- app.dart, main_web.dart:
  - Web para Admin, Medico y Nutricionista.
- tutor_mobile_app.dart, main_tutor_mobile.dart:
  - App movil exclusiva para Tutor.
- features/admin:
  - Modulos de gestion de usuarios y catalogos.
- features/medico:
  - Modulos de registro clinico, diagnostico OMS y reglas medicas.
- features/nutricionista:
  - Modulos de ingredientes, recetas, plan y reglas nutricionales.
- features/tutor:
  - Modulos de plan, consumo, reemplazos y calificacion.

## 2) Capa de logica inteligente (FastAPI)

Ruta base: backend/app

- api/v1/endpoints/admin_medico.py:
  - Endpoints del frente Admin/Medico.
- api/v1/endpoints/nutricion_tutor.py:
  - Endpoints del frente Nutricionista/Tutor.
- services/admin_medico:
  - Servicios clinicos y de seguimiento.
- services/nutricion_tutor:
  - Servicios de reglas nutricionales, recetas, planificacion y preferencias.
- services/compartido:
  - Componentes reutilizables entre dominios, como motor de reglas.

## 3) Capa de datos y seguridad (Supabase)

Ruta base: supabase

- rls_policies.sql:
  - Politicas de seguridad por rol y relacion tutor-paciente.
- seed_catalogs.sql:
  - Catalogos base del dominio.
- expose_schemas.sql, force_postgrest_schemas.sql, grant_postgrest_privileges.sql:
  - Exposicion y permisos de schemas para PostgREST.
- seed_oms_demo.sql:
  - Datos demo de referencia OMS para pruebas.

## 4) Capa de conocimiento experto (SQL base)

- base_de_datos.sql:
  - Modelo principal clinico-nutricional y conocimiento estructurado.

## 5) Regla de ownership para colaborar sin conflictos

- Persona A:
  - frontend/flutter_app/lib/features/admin
  - frontend/flutter_app/lib/features/medico
  - backend/app/api/v1/endpoints/admin_medico.py
  - backend/app/services/admin_medico
- Persona B:
  - frontend/flutter_app/lib/features/nutricionista
  - frontend/flutter_app/lib/features/tutor
  - backend/app/api/v1/endpoints/nutricion_tutor.py
  - backend/app/services/nutricion_tutor
- Compartido:
  - backend/app/services/compartido
  - scripts SQL en supabase

## 6) Convencion recomendada para nuevos modulos

- Un modulo nuevo debe vivir en la carpeta del profesional responsable.
- Si el modulo se reutiliza por mas de un profesional, moverlo a compartido.
- Mantener contratos de entrada/salida en schemas Pydantic antes de codificar UI.
