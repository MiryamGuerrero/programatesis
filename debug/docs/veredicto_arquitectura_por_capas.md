# Análisis y veredicto de arquitectura por capas del proyecto

## 1. Objetivo del análisis

Este documento resume el análisis de la estructura de carpetas del proyecto `programatesis`, con el objetivo de determinar si se está aplicando correctamente una arquitectura de desarrollo de software por capas.

El análisis se basa únicamente en la estructura de directorios proporcionada. Se ignoran archivos de desarrollo, depuración, pruebas, respaldos, logs, scripts auxiliares y documentación que no forman parte directa del código productivo de la aplicación.

---

## 2. Veredicto general

**Veredicto:** Parcialmente correcto.

**Cumplimiento estimado de arquitectura por capas:** 70% a 75%.

**Arquitectura detectada:**

- Backend orientado a arquitectura por capas.
- Frontend organizado principalmente por funcionalidades, módulos y roles.
- Existen señales claras de separación de responsabilidades, especialmente en el backend.
- Todavía hay inconsistencias estructurales que impiden considerar la arquitectura como completamente limpia o uniforme.

Conclusión breve:

> El proyecto sí tiene una base clara de arquitectura por capas, principalmente en el backend. Sin embargo, la aplicación todavía presenta carpetas paralelas, mezcla de convenciones y una organización frontend más modular que estrictamente por capas.

---

## 3. Análisis del backend

El backend es la parte del proyecto que mejor refleja una arquitectura por capas.

Se identifican las siguientes carpetas principales:

```txt
backend/app/api
backend/app/aplicacion
backend/app/domain
backend/app/infraestructura
backend/app/core
```

Esta organización indica una separación razonable entre presentación, aplicación, dominio, infraestructura y configuración general.

---

### 3.1. Capa de presentación

Carpetas relacionadas:

```txt
backend/app/api
backend/app/api/v1
backend/app/api/v1/endpoints
backend/app/api/v1/router.py
backend/app/api/v1/route_registry.py
```

Evaluación:

La capa de presentación está representada por la carpeta `api`, donde se encuentran rutas, endpoints y archivos relacionados con el registro de rutas.

Esto es correcto dentro de una arquitectura por capas, ya que la capa de presentación debe encargarse de recibir solicitudes, validar entrada básica y delegar la lógica a capas inferiores.

Posible riesgo:

Dentro de `backend/app/api/v1` existe un archivo llamado:

```txt
use_cases.py
```

En una arquitectura por capas estricta, los casos de uso deberían estar en la capa de aplicación, no dentro de la capa API. Este archivo debe revisarse para verificar si realmente contiene lógica de aplicación o si solo actúa como puente hacia la capa correspondiente.

---

### 3.2. Capa de aplicación

Carpetas relacionadas:

```txt
backend/app/aplicacion/clinica
backend/app/aplicacion/nutricion
```

Archivos representativos:

```txt
gestionar_catalogos.py
gestionar_control_clinico.py
gestionar_pacientes.py
gestionar_perfil_usuario.py
gestionar_usuarios.py
supervisar_adherencia.py
evaluar_reglas_paciente.py
generar_plan_automatico.py
generar_plan_semanal.py
gestionar_ingredientes.py
gestionar_seguimiento.py
gestionar_variables.py
```

Evaluación:

Esta capa está bien identificada. Los nombres de los archivos sugieren casos de uso o servicios de aplicación, ya que representan acciones del sistema como gestionar pacientes, generar planes o evaluar reglas.

Esto es positivo porque la capa de aplicación debe coordinar los procesos del sistema sin depender directamente de detalles técnicos como base de datos, frameworks o controladores HTTP.

---

### 3.3. Capa de dominio

Carpetas relacionadas:

```txt
backend/app/domain/modelos
backend/app/domain/repositorios
backend/app/domain/servicios
backend/app/domain/dtos
backend/app/domain/excepciones.py
```

Archivos representativos:

```txt
clinico.py
nutricion.py
paciente.py
plan_nutricional.py
reglas.py
seguimiento.py
usuario.py
interfaces.py
resolutor_conflictos.py
restricciones_alimentarias.py
servicio_heuristico.py
servicio_oms.py
servicio_planificador.py
```

Evaluación:

La capa de dominio está bien planteada. Contiene modelos, servicios de dominio, excepciones e interfaces de repositorios.

Esto se alinea con una arquitectura por capas, ya que el dominio debe contener las reglas de negocio principales y no depender directamente de infraestructura externa.

Punto importante:

La existencia de `domain/repositorios/interfaces.py` es positiva, porque permite que el dominio defina contratos sin conocer la implementación concreta de la base de datos.

---

### 3.4. Capa de infraestructura

Carpetas relacionadas:

```txt
backend/app/infraestructura/repositorios
```

Archivos representativos:

```txt
base.py
repositorio_clinico.py
repositorio_composicion.py
repositorio_ingrediente.py
repositorio_nutricion.py
repositorio_paciente.py
repositorio_perfil.py
repositorio_receta.py
repositorio_regla.py
repositorio_seguimiento.py
```

Evaluación:

La infraestructura está correctamente separada en una carpeta propia. Los repositorios concretos se encuentran dentro de `infraestructura`, lo cual es adecuado porque esta capa debe manejar detalles técnicos como acceso a datos, conexión con Supabase, consultas y persistencia.

Esta separación favorece la mantenibilidad, la escalabilidad y la posibilidad de cambiar la tecnología de almacenamiento sin afectar directamente al dominio.

---

### 3.5. Capa core o configuración

Carpeta relacionada:

```txt
backend/app/core
```

Archivos encontrados:

```txt
auth_onboarding.py
config.py
db.py
security.py
supabase_client.py
```

Evaluación:

La carpeta `core` agrupa configuración, seguridad, conexión a base de datos y cliente de Supabase.

Esto puede ser aceptable, pero debe revisarse con cuidado. Algunos archivos de `core` podrían pertenecer más claramente a infraestructura, especialmente:

```txt
db.py
supabase_client.py
```

Mientras que otros pueden permanecer como configuración transversal:

```txt
config.py
security.py
```

Recomendación:

Separar mejor lo que es configuración general de lo que es infraestructura técnica.

---

## 4. Problemas detectados en el backend

Aunque el backend tiene una buena base de arquitectura por capas, se observan algunas inconsistencias.

---

### 4.1. Carpetas paralelas o posiblemente heredadas

Además de las carpetas principales de arquitectura por capas, existen estas carpetas:

```txt
backend/app/repositories
backend/app/schemas
backend/app/services
```

Problema:

Estas carpetas parecen pertenecer a una estructura anterior o paralela. Aunque podrían estar vacías o incompletas, generan confusión porque conviven dos estilos arquitectónicos:

```txt
Estilo 1:
api
aplicacion
domain
infraestructura

Estilo 2:
controllers
services
repositories
schemas
```

Riesgo:

Si ambas estructuras contienen lógica activa, el proyecto puede volverse difícil de mantener porque no queda claro dónde debe ir cada responsabilidad.

Recomendación:

Revisar si estas carpetas están vacías, en desuso o todavía contienen código funcional. Si están en desuso, eliminarlas o documentarlas como obsoletas. Si contienen código activo, migrarlo a las capas correspondientes.

---

### 4.2. Posible mezcla de casos de uso dentro de API

Archivo a revisar:

```txt
backend/app/api/v1/use_cases.py
```

Problema:

Los casos de uso deberían estar en la capa de aplicación, no en la capa API.

Recomendación:

Revisar el contenido de este archivo. Si contiene lógica de negocio o coordinación de procesos, moverlo a:

```txt
backend/app/aplicacion
```

Si solo contiene adaptadores o llamadas simples, renombrarlo para evitar confusión.

---

### 4.3. Posible mezcla de responsabilidades en core

Archivos a revisar:

```txt
backend/app/core/db.py
backend/app/core/supabase_client.py
```

Problema:

La conexión a base de datos y el cliente de Supabase son detalles técnicos. En una arquitectura por capas estricta, podrían pertenecer a infraestructura.

Recomendación:

Evaluar si conviene mover estos archivos a:

```txt
backend/app/infraestructura/database
backend/app/infraestructura/supabase
```

---

## 5. Veredicto del backend

**Estado:** Aplica arquitectura por capas de forma bastante clara.

**Calificación aproximada:** 8/10.

Fortalezas:

- Existe separación entre API, aplicación, dominio e infraestructura.
- Los casos de uso parecen estar agrupados en `aplicacion`.
- Los modelos y servicios de negocio están en `domain`.
- Los repositorios concretos están en `infraestructura`.
- Existen interfaces de repositorios dentro del dominio.

Debilidades:

- Hay carpetas paralelas como `services`, `repositories` y `schemas`.
- Existe un posible archivo de casos de uso dentro de `api`.
- `core` mezcla configuración con detalles de infraestructura.
- Se debe confirmar mediante revisión de código si las dependencias entre capas están correctamente dirigidas.

---

## 6. Análisis del frontend

El frontend no sigue una arquitectura por capas estricta. Se observa principalmente una arquitectura modular por funcionalidades y roles.

Estructura principal:

```txt
frontend/flutter_app/lib
frontend/flutter_app/lib/core
frontend/flutter_app/lib/features
frontend/flutter_app/lib/shared
```

Dentro de `features` se organiza el código por roles:

```txt
features/admin
features/auth
features/medico
features/nutricionista
features/perfil
features/roles
features/shared
features/tutor
```

Esta organización no es incorrecta. En Flutter, una arquitectura por features o funcionalidades puede ser válida. Sin embargo, no equivale necesariamente a arquitectura por capas.

---

### 6.1. Separación parcial por capas en algunas features

Algunas funcionalidades sí muestran separación entre datos y presentación:

```txt
features/medico/data
features/medico/presentation
features/tutor/data
features/tutor/presentation
```

Esto es positivo, porque permite separar acceso a datos de interfaces visuales.

---

### 6.2. Módulos con páginas directamente incluidas

En otras partes, los módulos contienen directamente páginas de interfaz:

```txt
features/nutricionista/modules/ingredientes/ingredientes_page.dart
features/nutricionista/modules/recetas/recetas_page.dart
features/admin/modules/usuarios/admin_users_page.dart
```

Esto indica que la organización se basa más en módulos visuales que en capas.

No necesariamente está mal, pero no se puede afirmar que el frontend aplique una arquitectura por capas completa.

---

### 6.3. Repositorios compartidos

Se observa la carpeta:

```txt
frontend/flutter_app/lib/shared/repositories
```

Archivos representativos:

```txt
inteligencia_api_repository.dart
supabase_crud_repository.dart
```

Riesgo:

Si estos repositorios son usados directamente desde páginas o widgets, entonces la presentación estaría acoplada a la infraestructura o acceso a datos.

Recomendación:

Verificar que las páginas no llamen directamente a repositorios concretos. Lo ideal sería usar servicios, providers, casos de uso o controladores de estado intermedios.

---

## 7. Veredicto del frontend

**Estado:** No aplica arquitectura por capas de forma estricta.

**Calificación aproximada:** 6/10.

Fortalezas:

- Está organizado por funcionalidades y roles.
- Tiene carpetas `data` y `presentation` en algunas features.
- Tiene carpetas `core` y `shared`, útiles para elementos transversales.
- La estructura modular puede ser adecuada para Flutter.

Debilidades:

- No todas las features tienen separación uniforme entre `data`, `domain` y `presentation`.
- Varias páginas están directamente dentro de `modules`.
- No se observa una capa de dominio clara en el frontend.
- Puede existir acoplamiento entre UI y repositorios.
- La convención arquitectónica no es uniforme entre módulos.

---

## 8. Evaluación general por capas

| Capa | Backend | Frontend | Evaluación general |
|---|---|---|---|
| Presentación | Bien aplicada con `api/endpoints` | Parcial, representada por páginas y widgets | Parcialmente correcta |
| Aplicación | Bien aplicada con `app/aplicacion` | No claramente identificada | Parcial |
| Dominio | Bien aplicada con `app/domain` | No claramente identificada | Correcta en backend, débil en frontend |
| Infraestructura | Bien aplicada con `app/infraestructura` | Parcial con repositorios en `data` y `shared` | Parcialmente correcta |
| Shared/Core | Parcial | Parcial | Necesita mayor estandarización |

---

## 9. Problemas arquitectónicos principales

| Problema | Descripción | Impacto |
|---|---|---|
| Doble convención en backend | Coexisten `aplicacion/domain/infraestructura` con `services/repositories/schemas` | Puede generar confusión y duplicidad |
| Casos de uso dentro de API | Existe `api/v1/use_cases.py` | Puede mezclar presentación con aplicación |
| Core con responsabilidades técnicas | `db.py` y `supabase_client.py` están dentro de `core` | Puede mezclar configuración con infraestructura |
| Frontend no uniforme | Algunas features tienen `data/presentation`, otras solo `modules` | Dificulta mantenimiento y escalabilidad |
| Falta de dominio en frontend | No se identifica una capa `domain` en cada feature | La lógica puede terminar mezclada en UI o repositorios |
| Posible acoplamiento UI-repositorio | Repositorios compartidos podrían ser llamados desde páginas | Reduce testabilidad y aumenta dependencia técnica |

---

## 10. Riesgos técnicos si se mantiene la estructura actual

1. Dificultad para ubicar nuevas funcionalidades.
2. Duplicidad de lógica entre servicios, casos de uso y repositorios.
3. Mayor acoplamiento entre presentación e infraestructura.
4. Menor facilidad para probar unidades de negocio.
5. Mayor riesgo de que las páginas o endpoints acumulen lógica de negocio.
6. Dificultad para escalar el proyecto con nuevos módulos.
7. Confusión para nuevos desarrolladores o para una IA que intente modificar el código.
8. Posibles cambios repetidos en diferentes carpetas por no existir una convención única.

---

## 11. Recomendaciones de mejora

### 11.1. Backend

Mantener como estructura oficial:

```txt
backend/app/api
backend/app/aplicacion
backend/app/domain
backend/app/infraestructura
backend/app/core
```

Acciones recomendadas:

1. Revisar si `backend/app/services`, `backend/app/repositories` y `backend/app/schemas` siguen siendo necesarias.
2. Migrar código activo de esas carpetas hacia las capas oficiales.
3. Revisar `backend/app/api/v1/use_cases.py`.
4. Mover la lógica de aplicación hacia `backend/app/aplicacion`.
5. Revisar si `db.py` y `supabase_client.py` deben moverse a infraestructura.
6. Documentar la regla de dependencias entre capas.

Regla recomendada de dependencias:

```txt
api -> aplicacion -> domain
infraestructura -> domain
aplicacion -> domain
api no debe acceder directamente a infraestructura
domain no debe depender de api, core ni infraestructura
```

---

### 11.2. Frontend

Definir una convención uniforme para cada feature.

Opción recomendada:

```txt
features/nombre_feature/
├── data/
├── domain/
├── presentation/
└── application/
```

O una versión más simple:

```txt
features/nombre_feature/
├── data/
├── models/
├── providers/
└── presentation/
```

Acciones recomendadas:

1. Estandarizar la estructura de `admin`, `medico`, `nutricionista` y `tutor`.
2. Evitar que las páginas llamen directamente a repositorios concretos.
3. Separar modelos de interfaz y modelos de dominio si el proyecto crece.
4. Ubicar widgets compartidos en `shared/widgets`.
5. Ubicar clientes HTTP, Supabase y configuración en `core`.
6. Usar providers, servicios o casos de uso como intermediarios entre UI y datos.

---

## 12. Plan de refactorización sugerido

### Fase 1: Auditoría sin modificar código

Objetivo:

Identificar qué archivos contienen lógica activa y qué carpetas están en desuso.

Tareas:

- Revisar imports.
- Detectar archivos no utilizados.
- Identificar llamadas directas desde endpoints hacia repositorios.
- Identificar llamadas directas desde páginas Flutter hacia repositorios.
- Confirmar si `services`, `repositories` y `schemas` están vacíos o en uso.

---

### Fase 2: Limpieza de backend

Objetivo:

Consolidar la arquitectura por capas en el backend.

Tareas:

- Mover casos de uso mal ubicados hacia `app/aplicacion`.
- Mover repositorios concretos hacia `app/infraestructura`.
- Mantener interfaces en `app/domain/repositorios`.
- Eliminar o archivar carpetas vacías o duplicadas.
- Documentar la estructura oficial.

---

### Fase 3: Revisión de dependencias

Objetivo:

Asegurar que las capas dependan en la dirección correcta.

Tareas:

- Verificar que `domain` no importe `api`, `infraestructura` ni frameworks externos.
- Verificar que `api` no acceda directamente a base de datos.
- Verificar que `aplicacion` use interfaces y no implementaciones concretas cuando sea posible.
- Verificar que `infraestructura` implemente contratos definidos en el dominio.

---

### Fase 4: Estandarización del frontend

Objetivo:

Definir una estructura uniforme para todas las features.

Tareas:

- Revisar cada feature: `admin`, `medico`, `nutricionista`, `tutor`, `auth`.
- Separar `data`, `presentation` y, si aplica, `domain`.
- Evitar lógica de negocio dentro de páginas y widgets.
- Revisar providers y repositorios.
- Consolidar widgets comunes.

---

### Fase 5: Documentación arquitectónica

Objetivo:

Evitar que el proyecto vuelva a mezclar responsabilidades.

Tareas:

- Crear o actualizar `docs/arquitectura_por_capas.md`.
- Definir dónde debe ir cada tipo de archivo.
- Agregar ejemplos de imports permitidos y no permitidos.
- Documentar reglas para nuevas funcionalidades.
- Incluir una guía para futuras modificaciones con IA.

---

## 13. Conclusión final

El proyecto sí presenta una arquitectura por capas en el backend y una intención clara de separar responsabilidades. La estructura `api`, `aplicacion`, `domain` e `infraestructura` es una base adecuada y bastante avanzada.

Sin embargo, el proyecto todavía no puede considerarse completamente limpio desde el punto de vista arquitectónico porque existen carpetas paralelas, posibles responsabilidades mezcladas y una estructura frontend que no sigue capas de manera uniforme.

Veredicto final:

```txt
El proyecto aplica arquitectura por capas de manera parcial y bastante avanzada en el backend,
pero requiere limpieza, estandarización y revisión de dependencias para considerarse una
arquitectura por capas completa y correctamente implementada.
```

---

# Instrucciones para la IA que realizará el análisis y cambios

## Rol esperado

Actúa como arquitecto de software senior y refactorizador de código.

Tu tarea es analizar el proyecto real y corregir progresivamente la arquitectura para alinearla con una arquitectura por capas, sin romper el funcionamiento existente.

---

## Reglas obligatorias

1. No modifiques archivos sin analizar primero.
2. No elimines código sin justificarlo.
3. No cambies el comportamiento funcional del sistema.
4. No muevas archivos masivamente sin verificar imports.
5. No mezcles lógica de negocio en controladores, rutas, páginas o widgets.
6. No hagas cambios en archivos de desarrollo, debug, logs, backups o documentación auxiliar salvo que se solicite.
7. Trabaja por fases y por módulos.
8. Después de cada cambio, explica qué archivos modificaste y por qué.
9. Si encuentras código duplicado, primero repórtalo y luego propone una consolidación.
10. Si hay dudas entre varias ubicaciones posibles, prioriza la estructura oficial del backend:

```txt
api
aplicacion
domain
infraestructura
core
```

---

## Tareas iniciales para la IA

Antes de cambiar código, realiza este diagnóstico:

1. Revisa la estructura real del proyecto.
2. Identifica archivos activos y archivos posiblemente obsoletos.
3. Revisa imports entre capas.
4. Detecta si `api` llama directamente a repositorios o base de datos.
5. Detecta si `domain` depende de infraestructura o frameworks.
6. Detecta si `aplicacion` contiene lógica de coordinación de casos de uso.
7. Detecta si `infraestructura` contiene implementaciones concretas de repositorios.
8. Detecta si el frontend llama directamente a repositorios desde páginas o widgets.
9. Entrega un reporte con evidencias concretas usando rutas de archivos.
10. Propón un plan de refactorización antes de modificar.

---

## Prompt sugerido para ejecutar en Codex, Gemini CLI u otra IA

```txt
Actúa como arquitecto de software senior.

Analiza este proyecto completo y usa el documento de veredicto arquitectónico como guía.

Objetivo:
Determinar si el proyecto aplica correctamente arquitectura por capas y corregir progresivamente las inconsistencias detectadas.

No modifiques archivos todavía.

Primero entrega:
1. Veredicto técnico actualizado basado en el código real.
2. Evidencias concretas con rutas de archivos.
3. Dependencias incorrectas entre capas.
4. Archivos que parecen estar mal ubicados.
5. Carpetas obsoletas, duplicadas o inconsistentes.
6. Riesgos técnicos.
7. Plan de refactorización por fases.

Después de entregar el diagnóstico, espera una instrucción explícita para empezar a modificar código.

Criterios:
- Backend debe seguir: api, aplicacion, domain, infraestructura, core.
- Frontend debe estandarizar features evitando lógica de negocio dentro de páginas.
- No romper funcionalidad existente.
- No eliminar archivos sin justificar.
- No modificar archivos de debug, logs, backups o scripts auxiliares salvo que sea necesario.
```

---

## Prompt para iniciar cambios de forma controlada

```txt
Ahora aplica la Fase 1 del plan de refactorización.

Solo realiza cambios seguros y pequeños.

Antes de modificar cada grupo de archivos:
1. Explica qué problema vas a corregir.
2. Indica qué archivos tocarás.
3. Aplica el cambio.
4. Verifica imports.
5. Resume lo realizado.

No avances a otra fase sin confirmación.
```
