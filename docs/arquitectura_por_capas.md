# Arquitectura por capas - Reuma Nutri

## 1. Objetivo

El proyecto adopta una arquitectura por capas con organizacion por rol y modulo.
La meta es que cada parte tenga una responsabilidad clara y que la app pueda evolucionar sin mezclar UI, reglas de negocio y acceso a datos.

## 2. Capas oficiales

### 2.1 Presentacion

- Frontend Flutter: frontend/flutter_app/lib
- Backend API HTTP: backend/app/api

Responsabilidad:

- Exponer pantallas, rutas y contratos HTTP.
- No colocar reglas de negocio complejas en esta capa.

### 2.2 Aplicacion y negocio

- Servicios por rol: backend/app/services/roles
- Servicios compartidos: backend/app/services/shared

Responsabilidad:

- Orquestar casos de uso.
- Aplicar reglas de negocio.
- Mantener logica desacoplada de detalles de infraestructura.

### 2.3 Infraestructura y persistencia

- Repositorios: backend/app/repositories
- Conectores core: backend/app/core
- SQL operativo: supabase

Responsabilidad:

- Adaptadores de base de datos y proveedores externos.
- Credenciales, seguridad, acceso a PostgreSQL/Supabase.

## 3. Estructura por rol

### 3.1 Backend

- API por rol: backend/app/api/v1/endpoints/roles
- Servicios por rol: backend/app/services/roles

Roles activos:

- admin
- medico
- nutricionista
- tutor

Cada rol debe contener su carpeta modules con sus submodulos funcionales.

### 3.2 Frontend

- Features por rol: frontend/flutter_app/lib/features

Cada rol se organiza en modules para evitar pantallas planas y mantener ownership por dominio.

## 4. Enrutamiento orientado a objetos

El armado del router principal ahora es declarativo y OOP en:

- backend/app/api/v1/route_registry.py

Beneficios:

- Registro unico de modulos HTTP.
- Clasificacion por capa y por rol.
- Menos acoplamiento en router.py.

## 5. Regla de integracion de capas

- Flujo simple (CRUD sin inteligencia): Flutter -> API CRUD/Supabase.
- Flujo inteligente (reglas/etiquetas/diagnostico): Flutter -> FastAPI -> repositorios/DB.

La inteligencia se concentra en servicios de negocio y no en pantallas.

## 6. Politica de repositorio operativo

En la raiz del repositorio deben quedar solo archivos operativos para correr la app.
Los scripts de migracion/ad-hoc y documentos legacy fuera de uso se eliminan para mantener el proyecto limpio.

## 7. Resultado esperado

- Menos deuda tecnica por scripts sueltos.
- Estructura predecible por rol y modulo.
- Mantenimiento mas simple para equipo backend y frontend.
