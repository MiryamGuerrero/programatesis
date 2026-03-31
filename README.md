# Reuma Nutri

Aplicacion de soporte nutricional clinico pediatrico.

Componentes de la app:

- Frontend Flutter (web y mobile) en frontend/flutter_app
- Backend FastAPI en backend/app
- Base de datos y scripts SQL en supabase y base_de_datos.sql

## Modulos funcionales por rol

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
  - Plan nutricional
  - Reglas nutricionales
- Tutor:
  - Ver plan
  - Registrar consumo
  - Reemplazo por equivalentes
  - Calificacion de recetas

## Endpoints funcionales

- POST /api/v1/imc-calculo
- POST /api/v1/diagnostico-oms
- POST /api/v1/reglas-evaluacion
- POST /api/v1/ingredientes-permitidos
- POST /api/v1/recetas-permitidas
- POST /api/v1/plan-automatico
- POST /api/v1/reemplazo-equivalente
- POST /api/v1/adherencia-calculo
- POST /api/v1/preferencias-aprendidas

## Seguridad

- Roles soportados: admin, medico, nutricionista, tutor.
- Politicas RLS definidas en supabase/rls_policies.sql.

## Documentacion en docs

- Arquitectura por capas: docs/arquitectura_por_capas.md
- Arranque de la app: docs/arranque_app.md
