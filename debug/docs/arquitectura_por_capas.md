# Arquitectura de ReumaNutri (Hexagonal Pragmática)

## Estructura de Capas (Backend FastAPI)

El sistema utiliza una arquitectura de cebolla (Hexagonal) para asegurar que la lógica clínica sea independiente de la base de datos.

### 1. Capa de Dominio (`app/domain/`)
- **Modelos (`modelos/`)**: Entidades puras (Paciente, Regla, Diagnóstico).
- **Servicios (`servicios/`)**: Lógica matemática y clínica (Resolutor de Conflictos, Motor Heurístico).
- **Interfaces (`repositories/interfaces.py`)**: Contratos que la infraestructura debe cumplir.

### 2. Capa de Aplicación (`app/aplicacion/`)
- **Casos de Uso**: Coordinan los procesos de negocio.
  - `nutricion/`: Evaluación de reglas, gestión de ingredientes.
  - `clinica/`: Gestión de controles y diagnósticos OMS.

### 3. Capa de Infraestructura (`app/infraestructura/`)
- **Repositorios (`repositorios/`)**: Implementaciones SQL reales usando el esquema funcional (`nutricion`, `clinico`, `usuarios`).
- **Base de Datos**: PostgreSQL en Supabase. **Nota: No se utilizan esquemas `dom_*`.**

### 4. Capa de Interfaz (`app/api/`)
- **Routers**: Controladores delgados que delegan en Casos de Uso.
- **DTOs**: Modelos de entrada/salida (Pydantic).

---

## Estructura de Frontend (Flutter)
Organizado por módulos funcionales (`features/`):
- `features/<rol>/presentation`: Pantallas y Widgets.
- `features/<rol>/data`: Repositorios locales y consumo de API.

---

## Estándar de Codificación (3.2.6.2)
- **Idioma**: Español absoluto para nombres de funciones, variables y clases.
- **Nomenclatura**:
  - Clases: `PascalCase` (ej. `CasoUsoEvaluarReglas`).
  - Funciones: `snake_case` (ej. `obtener_perfil_paciente`).
  - Base de Datos: `snake_case` (esquemas reales).
