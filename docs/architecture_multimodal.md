# Arquitectura Multimodal Reuma Nutri

## 1. Capas y responsabilidades

### Frontend (Flutter)

- Capa Presentacion:
  - Pantallas por rol en lib/features/*/presentation
- Capa Estado:
  - Riverpod en lib/core/state/app_providers.dart
- Capa Datos:
  - SupabaseCrudRepository para CRUD simple
  - InteligenciaApiRepository para casos complejos

### Backend Inteligente (FastAPI)

- Capa API:
  - app/api/v1/endpoints/admin_medico.py
  - app/api/v1/endpoints/nutricion_tutor.py
- Capa Servicios:
  - app/services/admin_medico
  - app/services/nutricion_tutor
  - app/services/compartido
- Capa Repositorios:
  - SQL desacoplado por contexto (clinico, nutricion, reglas, interaccion)
- Capa Core:
  - Configuracion, seguridad JWT, conexion DB SSL

### Backend Directo (Supabase)

- PostgreSQL como sistema de registro principal
- Auth para identidad y claims de rol
- RLS para seguridad por fila y por relacion tutor-paciente

## 2. Por que es multimodal y no solo hibrida

No solo se ejecuta una misma UI en dos plataformas; existen dos modos de operacion de datos en tiempo real:

1. Modo transaccional directo:
   - Flutter <-> Supabase (lecturas/escrituras simples)
2. Modo cognitivo/algoritmico:
   - Flutter <-> FastAPI <-> PostgreSQL/Supabase (calculos y decision automatizada)

El sistema decide el canal segun la complejidad de la operacion, mezclando:

- modalidad de consumo (web/mobile)
- modalidad de backend (directo/inteligente)
- modalidad de decision (manual/algoritmica)

Por eso es multimodal en interfaz y en procesamiento.

## 3. Flujos criticos

### Flujo A: Registro clinico + IMC

1. Medico carga peso/talla en Flutter.
2. Flutter llama /imc-calculo en FastAPI.
3. FastAPI devuelve IMC y clasificacion.
4. Flutter persiste control clinico en Supabase.

### Flujo B: Recetas permitidas

1. Nutricionista solicita recetas para paciente.
2. FastAPI obtiene condiciones, alergias y reglas.
3. Motor de reglas filtra ingredientes.
4. Se calculan recetas permitidas y nutrientes.

### Flujo C: Aprendizaje de preferencias

1. Tutor registra consumo y califica recetas.
2. FastAPI combina adherencia + estrellas.
3. Genera score de receta e ingrediente.
4. Opcionalmente persiste en tablas de preferencias.

## 4. Escalabilidad

- Desacople de API y DB permite migrar algoritmos a workers.
- Repositorios por contexto facilitan optimizacion SQL.
- RLS mantiene seguridad aunque aumenten clientes.
- Flutter comparte dominio entre web y movil sin duplicar logica.
