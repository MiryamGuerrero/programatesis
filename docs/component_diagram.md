# Diagrama de Componentes - Arquitectura Reuma Nutri

```plantuml
@startuml ReumaNutri_ComponentDiagram
!define INTERFACE_BG #E1F5FF
!define COMPONENT_BG #B3E5FC
!define SERVICE_BG #FFF9C4
!define REPOSITORY_BG #FFE0B2
!define DATABASE_BG #C8E6C9

skinparam componentStyle rectangle
skinparam linetype ortho
skinparam classBackgroundColor #FFFFFF
skinparam classBorderColor #333333

package "Capa de Presentación" #E3F2FD {
    package "<<interfaces>>" #F0F9FF {
        interface "IAdminUI" as IAdminUI
        interface "IMedicoUI" as IMedicoUI
        interface "INutricionistaUI" as INutricionistaUI
        interface "ITutorUI" as ITutorUI
    }
    
    package "<<componentes>>" #E1F5FF {
        component "Admin Module\n(usuarios, catalogos)" as AdminModule
        component "Medico Module\n(registro clínico, diagnóstico)" as MedicoModule
        component "Nutricionista Module\n(ingredientes, recetas, plan)" as NutricionistaModule
        component "Tutor Module\n(plan, consumo, reemplazos)" as TutorModule
    }
    
    package "<<componentes>> Backend API" #B3E5FC {
        component "Auth Context\nauth_context.py" as AuthContext
        component "Admin Endpoints\nadmin_endpoints.py" as AdminEndpoints
        component "Medico Endpoints\nmedico_endpoints.py" as MedicoEndpoints
        component "Nutricionista Endpoints\nnutricionista_endpoints.py" as NutricionistaEndpoints
        component "Tutor Endpoints\ntutor_endpoints.py" as TutorEndpoints
        component "Route Registry\nroute_registry.py" as RouteRegistry
    }
}

package "Capa de Lógica de Negocio" #FFFACD {
    package "<<Service>>" #FFF9C4 {
        component "Admin Service\nadmin_crud_service.py" as AdminService
        component "Medico Service\nLógica Clínica" as MedicoService
        component "Nutricionista Service\nLógica Nutricional" as NutricionistaService
        component "Tutor Service\nLógica Plan & Consumo" as TutorService
    }
    
    package "<<Controller>>" #FFF8DC {
        component "Auth Controller\nauth_onboarding.py" as AuthController
        component "Validation Controller\nValidación centralizada" as ValidationController
        component "Notification Controller\nNotificaciones" as NotificationController
        component "Report Controller\nReportes" as ReportController
    }
}

package "Capa de Acceso a Datos" #FFEDCC {
    package "<<CRUD>>" #FFE0B2 {
        component "Admin Repository\nadmin_crud_repository.py" as AdminRepository
        component "Medico Repository\nmedico_repository.py" as MedicoRepository
        component "Nutricionista Repository\nnutricionista_repository.py" as NutricionistaRepository
        component "Tutor Repository\ntutor_repository.py" as TutorRepository
    }
    
    package "<<Infrastructure>>" #FFCCBC {
        component "Supabase Client\nsupabase_client.py" as SupabaseClient
        component "Config Manager\nconfig.py" as ConfigManager
        component "Security Handler\nsecurity.py" as SecurityHandler
        component "Dependencies\ndeps.py" as Dependencies
    }
}

package "Base de Datos PostgreSQL" #C8E6C9 {
    database "PostgreSQL\napp_schemas" as PostgreSQL
    component "Edge Functions\n[plan-inteligente]\n[recomendacion-puntual]\n[reemplazo-equivalente]" as EdgeFunctions
}

' === CONEXIONES CAPA PRESENTACIÓN ===
AdminModule -down- IAdminUI
MedicoModule -down- IMedicoUI
NutricionistaModule -down- INutricionistaUI
TutorModule -down- ITutorUI

AdminModule -.-> AdminEndpoints : HTTP
MedicoModule -.-> MedicoEndpoints : HTTP
NutricionistaModule -.-> NutricionistaEndpoints : HTTP
TutorModule -.-> TutorEndpoints : HTTP

AdminEndpoints -right- RouteRegistry
MedicoEndpoints -right- RouteRegistry
NutricionistaEndpoints -right- RouteRegistry
TutorEndpoints -right- RouteRegistry
AuthContext -down- RouteRegistry

' === CONEXIONES CAPA NEGOCIO ===
AdminEndpoints -.down-> AdminService : llama
MedicoEndpoints -.down-> MedicoService : llama
NutricionistaEndpoints -.down-> NutricionistaService : llama
TutorEndpoints -.down-> TutorService : llama

AdminService -right-> ValidationController : usa
MedicoService -right-> AuthController : usa
MedicoService -right-> ValidationController : usa
NutricionistaService -right-> ValidationController : usa
TutorService -right-> AuthController : usa

AuthContext -right- AuthController : integra

' === CONEXIONES CAPA ACCESO A DATOS ===
AdminService -.down-> AdminRepository : persiste
MedicoService -.down-> MedicoRepository : persiste
NutricionistaService -.down-> NutricionistaRepository : persiste
TutorService -.down-> TutorRepository : persiste

AdminRepository -down- SupabaseClient : usa
MedicoRepository -down- SupabaseClient : usa
NutricionistaRepository -down- SupabaseClient : usa
TutorRepository -down- SupabaseClient : usa

SupabaseClient -down- SecurityHandler : secured by
SupabaseClient -down- ConfigManager : configured by
SupabaseClient -down- Dependencies : depends on

' === CONEXIÓN A BASE DE DATOS ===
SupabaseClient -.down-> PostgreSQL : CRUD & RPC
PostgreSQL -right- EdgeFunctions : ejecuta

' === LEYENDA ===
note right of PostgreSQL
  **Flujo Simple (CRUD):**
  Flutter → API → Repository → Supabase
  
  **Flujo Inteligente (con Reglas):**
  Flutter → API → Service → Repository → Supabase → Edge Functions
end note

@enduml
```

## Estructura de Componentes por Capa

### 1️⃣ Capa Presentación
- **Frontend Flutter**: Módulos separados por rol (Admin, Medico, Nutricionista, Tutor)
- **Backend API FastAPI**: Endpoints organizados por rol + Auth Context + Health Check
- **Route Registry**: Orquestación declarativa y OOP de todas las rutas

### 2️⃣ Capa Aplicación/Negocio
- **Servicios por Rol**: Lógica específica de cada rol
- **Servicios Compartidos**: Auth, Validación, Notificaciones
- Las reglas de negocio se concentran en esta capa, NO en endpoints ni widgets

### 3️⃣ Capa Infraestructura
- **Repositorios**: Adaptadores de persistencia por rol
- **Core**: Configuración, seguridad, cliente Supabase, autenticación

### 4️⃣ Persistencia
- **PostgreSQL + Supabase**: Base de datos principal
- **Edge Functions**: Lógica serverless (plan inteligente, recomendaciones, reemplazos)
- **Datos CSV**: Ingredientes y datos OMS cargados bulk

## Flujos de Integración

```
✅ Flujo Simple (CRUD):
   Flutter → FastAPI Endpoint → Repositorio → Supabase

✅ Flujo Inteligente (con reglas):
   Flutter → FastAPI Endpoint → Servicio → Repositorio → Supabase → Edge Functions
```

## Convenciones Operativas
1. Nuevos endpoints → `backend/app/api/v1/endpoints/roles/<rol>_endpoints.py`
2. Nueva lógica → `backend/app/services/roles/<rol>/`
3. Nuevos módulos frontend → `frontend/flutter_app/lib/features/roles/`
