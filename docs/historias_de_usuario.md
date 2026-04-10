# Historias de Usuario

---

## Historias de Usuario (HU)

---

### HU-01 — Gestión de cuentas del personal profesional

| Campo | Detalle |
|-------|---------|
| **ID** | HU-01 |
| **Título** | Gestión de cuentas del personal profesional |
| **Rol** | Administrador |
| **Estimación** | 15 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HT-01, HT-02, HT-03 |

**Descripción:**
Como Administrador, quiero crear, editar, activar, desactivar y consultar cuentas del personal profesional, para controlar el acceso al sistema según el rol asignado.

**Pruebas de aceptación:**
- El administrador puede registrar cuentas para administrador, médico y nutricionista.
- El sistema no permite duplicar usuarios con la misma cédula, correo o nombre de usuario.
- El administrador puede activar y desactivar cuentas.
- Solo el administrador puede acceder a este módulo.
- La acción queda registrada en auditoría.

---

### HU-02 — Registro de tutor y generación de acceso

| Campo | Detalle |
|-------|---------|
| **ID** | HU-02 |
| **Título** | Registro de tutor y generación de acceso |
| **Rol** | Médico |
| **Estimación** | 15 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-01, HT-02 |

**Descripción:**
Como Médico, quiero registrar al tutor responsable del paciente y generar su acceso, para permitirle consultar y gestionar el seguimiento alimenticio.

**Pruebas de aceptación:**
- El sistema registra datos completos del tutor.
- Genera credenciales iniciales.
- El tutor queda disponible para consulta posterior.
- No se permite guardar campos obligatorios vacíos.
- El registro queda auditado.

---

### HU-03 — Asociación de uno o varios pacientes a un tutor

| Campo | Detalle |
|-------|---------|
| **ID** | HU-03 |
| **Título** | Asociación de uno o varios pacientes a un tutor |
| **Rol** | Médico |
| **Estimación** | 10 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-02, HT-03 |

**Descripción:**
Como Médico, quiero asociar uno o varios pacientes a un mismo tutor, para reflejar correctamente la realidad familiar y permitir su gestión desde una sola cuenta.

**Pruebas de aceptación:**
- Un tutor puede quedar vinculado a más de un paciente.
- Cada paciente tiene al menos un tutor asociado.
- El tutor solo visualiza sus pacientes asociados.
- La asociación puede actualizarse.
- La relación se mantiene íntegra en base de datos.

---

### HU-04 — Primer ingreso del tutor

| Campo | Detalle |
|-------|---------|
| **ID** | HU-04 |
| **Título** | Primer ingreso del tutor |
| **Rol** | Tutor |
| **Estimación** | 10 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-02, HU-03, HT-02 |

**Descripción:**
Como Tutor, quiero cambiar mi contraseña temporal en el primer ingreso, para proteger mi cuenta y acceder de forma segura a los pacientes asociados.

**Pruebas de aceptación:**
- El sistema obliga al cambio de contraseña temporal.
- No permite continuar si el cambio no se completa.
- Tras el cambio, muestra los pacientes asociados.
- La contraseña nueva debe cumplir reglas de seguridad.
- El evento queda registrado.

---

### HU-05 — Registro inicial del paciente

| Campo | Detalle |
|-------|---------|
| **ID** | HU-05 |
| **Título** | Registro inicial del paciente |
| **Rol** | Médico |
| **Estimación** | 20 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-03, HT-03, HT-04 |

**Descripción:**
Como Médico, quiero registrar la información inicial del paciente pediátrico, para iniciar su seguimiento clínico y nutricional dentro del sistema.

**Pruebas de aceptación:**
- El sistema registra datos personales y condición clínica base del paciente.
- El paciente queda asociado a su tutor.
- No se permiten campos obligatorios vacíos.
- El registro queda disponible para controles posteriores.
- La información se almacena correctamente.

---

### HU-06 — Registro de alergias alimentarias

| Campo | Detalle |
|-------|---------|
| **ID** | HU-06 |
| **Título** | Registro de alergias alimentarias |
| **Rol** | Médico |
| **Estimación** | 10 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-05, HT-06 |

**Descripción:**
Como Médico, quiero registrar alergias por ingrediente y grupo alimentario, para evitar recomendaciones incompatibles con el paciente.

**Pruebas de aceptación:**
- Permite registrar alergias por ingrediente específico.
- Permite registrar alergias por grupo alimentario.
- Las alergias quedan asociadas al paciente.
- Pueden actualizarse en controles posteriores.
- Quedan disponibles para la lógica de exclusión.

---

### HU-07 — Registro de datos clínicos y controles

| Campo | Detalle |
|-------|---------|
| **ID** | HU-07 |
| **Título** | Registro de datos clínicos y controles |
| **Rol** | Médico |
| **Estimación** | 15 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-05, HT-04 |

**Descripción:**
Como Médico, quiero registrar y actualizar peso, talla, dolor, inflamación, fatiga y rigidez matutina, para monitorear la evolución clínica del paciente.

**Pruebas de aceptación:**
- Registra peso en kg y talla en cm.
- Registra síntomas clínicos del control.
- Permite actualizar datos en controles mensuales.
- Los datos quedan vinculados al paciente y fecha.
- El sistema valida rangos razonables.

---

### HU-08 — Cálculo y visualización de IMC y condición nutricional

| Campo | Detalle |
|-------|---------|
| **ID** | HU-08 |
| **Título** | Cálculo y visualización de IMC y condición nutricional |
| **Rol** | Médico, Nutricionista o Tutor |
| **Estimación** | 10 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-07, HT-05 |

**Descripción:**
Como Médico, Nutricionista o Tutor, quiero que el sistema calcule automáticamente el IMC y determine la condición nutricional vigente del paciente, para disponer de una clasificación objetiva del estado nutricional y poder consultarla según el nivel de acceso correspondiente.

**Pruebas de aceptación:**
- El sistema calcula automáticamente el IMC a partir de peso y talla.
- Determina la condición nutricional vigente.
- El resultado queda asociado al control.
- Médico y nutricionista pueden consultarlo para seguimiento.
- El tutor puede visualizarlo en modo lectura.
- El resultado queda disponible para reglas nutricionales.

---

### HU-09 — Registro de condiciones temporales del control

| Campo | Detalle |
|-------|---------|
| **ID** | HU-09 |
| **Título** | Registro de condiciones temporales del control |
| **Rol** | Médico |
| **Estimación** | 10 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-07, HU-12 |

**Descripción:**
Como Médico, quiero registrar condiciones temporales del período, para que el sistema ajuste las recomendaciones mientras esas condiciones estén activas.

**Pruebas de aceptación:**
- Permite registrar condiciones como náuseas, acidez, o flujo.
- La condición queda asociada al control mensual.
- Su efecto aplica solo mientras esté activa.
- Puede no registrarse ninguna condición temporal.
- La información queda disponible para el motor de reglas.

---

### HU-10 — Consulta global de pacientes por personal de salud

| Campo | Detalle |
|-------|---------|
| **ID** | HU-10 |
| **Título** | Consulta global de pacientes por personal de salud |
| **Rol** | Médico o Nutricionista |
| **Estimación** | 10 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-05, HT-02 |

**Descripción:**
Como Médico o Nutricionista, quiero consultar la información completa de los pacientes registrados, para asegurar continuidad en el seguimiento clínico y nutricional.

**Pruebas de aceptación:**
- Médico y nutricionista pueden consultar pacientes registrados.
- El tutor no puede consultar pacientes no asociados.
- La consulta respeta el rol autenticado.
- La búsqueda responde dentro del tiempo esperado.
- La información mostrada es coherente con el estado del paciente.

---

### HU-11 — Historial de evolución del paciente

| Campo | Detalle |
|-------|---------|
| **ID** | HU-11 |
| **Título** | Historial de evolución del paciente |
| **Rol** | Médico, Nutricionista o Tutor |
| **Estimación** | 10 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-07, HU-08, HU-09, HT-17 |

**Descripción:**
Como Médico, Nutricionista o Tutor, quiero consultar el historial de evolución del paciente, para comprender sus cambios clínicos y alimentarios a lo largo del tiempo.

**Pruebas de aceptación:**
- El historial muestra controles, IMC, condición nutricional y seguimiento alimentario.
- La información se presenta en orden cronológico.
- Cada rol visualiza únicamente lo que le corresponde.
- La consulta no altera datos.
- El tiempo de carga es aceptable.

---

### HU-12 — Gestión del catálogo general de condiciones

| Campo | Detalle |
|-------|---------|
| **ID** | HU-12 |
| **Título** | Gestión del catálogo general de condiciones |
| **Rol** | Médico |
| **Estimación** | 15 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HT-06 |

**Descripción:**
Como Médico, quiero administrar el catálogo general de condiciones, para disponer de una base organizada de condiciones clínicas, temporales y nutricionales.

**Pruebas de aceptación:**
- Permite crear, consultar y actualizar el catálogo.
- El catálogo organiza condiciones por tipo.
- No permite inconsistencias básicas.
- Las condiciones quedan disponibles para reglas.
- La gestión queda auditada.

---

### HU-13 — Gestión de tipos de condición

| Campo | Detalle |
|-------|---------|
| **ID** | HU-13 |
| **Título** | Gestión de tipos de condición |
| **Rol** | Médico |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-12 |

**Descripción:**
Como Médico, quiero registrar, consultar y actualizar los tipos de condición, para organizar el catálogo general del sistema.

**Pruebas de aceptación:**
- El sistema permite registrar tipos de condición.
- Los tipos pueden clasificarse como clínica, temporal o nutricional.
- El sistema permite editarlos.
- No se permiten duplicados inconsistentes.
- Los tipos quedan disponibles para asociar condiciones específicas.

---

### HU-14 — Gestión de condiciones del catálogo

| Campo | Detalle |
|-------|---------|
| **ID** | HU-14 |
| **Título** | Gestión de condiciones del catálogo |
| **Rol** | Médico o Nutricionista |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-13 |

**Descripción:**
Como Médico o Nutricionista, quiero registrar, consultar y actualizar las condiciones específicas del catálogo, para disponer de las entidades base que utilizará el sistema.

**Pruebas de aceptación:**
- Permite registrar condiciones por tipo.
- Las condiciones pueden editarse y consultarse.
- No se permiten duplicados inconsistentes.
- Quedan disponibles para reglas y clasificación.
- La información se almacena correctamente.

---

### HU-15 — Definición de reglas clínicas y temporales

| Campo | Detalle |
|-------|---------|
| **ID** | HU-15 |
| **Título** | Definición de reglas clínicas y temporales |
| **Rol** | Médico |
| **Estimación** | 15 puntos |
| **Prioridad** | Alta |
| **Dependencias** | HU-14, HT-07 |

**Descripción:**
Como Médico, quiero crear reglas alimentarias para condiciones clínicas y temporales, para ajustar las recomendaciones según el estado del paciente.

**Pruebas de aceptación:**
- La regla puede actuar sobre ingrediente, grupo o etiqueta.
- Puede ejecutar eliminar, disminuir o priorizar.
- Queda asociada a una condición clínica o temporal.
- Puede editarse y consultarse.
- Si el elemento requerido no existe, el médico puede registrarlo desde el mismo flujo, según sus permisos.
- El motor la reconoce al evaluar al paciente.

---

### HU-16 — Creación contextual de ingrediente, etiqueta o grupo durante reglas médicas

| Campo | Detalle |
|-------|---------|
| **ID** | HU-16 |
| **Título** | Creación contextual de ingrediente, etiqueta o grupo durante reglas médicas |
| **Rol** | Médico |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-15, HU-20, HT-34 |

**Descripción:**
Como Médico, quiero registrar un ingrediente, una etiqueta nutricional o un grupo alimentario desde el mismo proceso de creación de reglas, para no interrumpir la definición de reglas clínicas o temporales cuando el elemento que necesito aún no existe en el sistema.

**Pruebas de aceptación:**
- El médico puede crear un ingrediente desde el flujo de reglas.
- Puede crear una etiqueta nutricional desde el flujo de reglas.
- Puede crear un grupo alimentario desde el flujo de reglas.
- El nuevo elemento queda disponible inmediatamente.
- La creación respeta permisos y validaciones.
- La acción queda registrada en auditoría.

---

### HU-17 — Gestión de condiciones nutricionales

| Campo | Detalle |
|-------|---------|
| **ID** | HU-17 |
| **Título** | Gestión de condiciones nutricionales |
| **Rol** | Nutricionista |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-14, HT-21 |

**Descripción:**
Como Nutricionista, quiero registrar, consultar, actualizar y organizar las condiciones nutricionales del sistema, para disponer de un catálogo técnico que pueda ser usado en el diagnóstico nutricional y en la definición de reglas alimentarias.

**Pruebas de aceptación:**
- El sistema permite registrar condiciones como bajo peso, normopeso, sobrepeso u obesidad.
- Cada condición nutricional queda asociada a su tipo.
- El nutricionista puede consultarlas y actualizarlas.
- No se permiten duplicados inconsistentes.
- Quedan disponibles para reglas nutricionales.

---

### HU-18 — Definición de reglas nutricionales

| Campo | Detalle |
|-------|---------|
| **ID** | HU-18 |
| **Título** | Definición de reglas nutricionales |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HU-17, HT-21 |

**Descripción:**
Como Nutricionista, quiero asociar una o varias reglas alimentarias a una condición nutricional, para representar de forma completa las restricciones y prioridades que correspondan al estado nutricional del paciente.

**Pruebas de aceptación:**
- Una condición nutricional puede tener varias reglas.
- Las reglas pueden actuar sobre ingredientes, grupos o etiquetas.
- Cada regla puede eliminar, disminuir o priorizar.
- Las reglas quedan asociadas correctamente a la condición.
- Si el elemento requerido no existe, el nutricionista puede registrarlo desde el mismo flujo.
- El motor aplica el conjunto completo de reglas activas.

---

### HU-19 — Creación contextual de ingrediente, etiqueta o grupo durante reglas nutricionales

| Campo | Detalle |
|-------|---------|
| **ID** | HU-19 |
| **Título** | Creación contextual de ingrediente, etiqueta o grupo durante reglas nutricionales |
| **Rol** | Nutricionista |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-18, HU-20, HT-34 |

**Descripción:**
Como Nutricionista, quiero registrar un ingrediente, una etiqueta nutricional o un grupo alimentario desde el mismo proceso de creación de reglas nutricionales, para mantener continuidad en la configuración del sistema cuando el elemento requerido aún no existe.

**Pruebas de aceptación:**
- El nutricionista puede crear un ingrediente desde el flujo de reglas.
- Puede crear una etiqueta nutricional desde el flujo de reglas.
- Puede crear un grupo alimentario desde el flujo de reglas.
- El nuevo elemento queda disponible inmediatamente.
- La creación respeta permisos y validaciones.
- La acción queda registrada en auditoría.

---

### HU-20 — Gestión de ingredientes, grupos y etiquetas

| Campo | Detalle |
|-------|---------|
| **ID** | HU-20 |
| **Título** | Gestión de ingredientes, grupos y etiquetas |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-08 |

**Descripción:**
Como Nutricionista, quiero gestionar ingredientes, grupos alimentarios y etiquetas nutricionales, para estructurar la base del repositorio nutricional.

**Pruebas de aceptación:**
- Permite registrar ingredientes.
- Permite registrar grupos y etiquetas.
- Los elementos pueden editarse y consultarse.
- Los datos se relacionan correctamente con recetas y reglas.
- La estructura queda disponible para recomendaciones y reemplazos.

---

### HU-21 — Gestión de sustitutos de ingredientes

| Campo | Detalle |
|-------|---------|
| **ID** | HU-21 |
| **Título** | Gestión de sustitutos de ingredientes |
| **Rol** | Nutricionista |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Media |
| **Dependencias** | HU-20, HT-09 |

**Descripción:**
Como Nutricionista, quiero registrar sustitutos válidos para los ingredientes, para que el sistema pueda utilizarlos en reemplazos y recomendaciones cuando corresponda.

**Pruebas de aceptación:**
- Cada ingrediente puede tener uno o varios sustitutos.
- Los sustitutos quedan relacionados correctamente.
- Pueden consultarse y actualizarse.
- El sistema puede usarlos en reemplazos.
- No se sugieren sustitutos incompatibles.

---

### HU-22 — Registro de composición nutricional de ingredientes

| Campo | Detalle |
|-------|---------|
| **ID** | HU-22 |
| **Título** | Registro de composición nutricional de ingredientes |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HU-20, HT-22 |

**Descripción:**
Como Nutricionista, quiero registrar la composición nutricional de cada ingrediente en una medida estandarizada por 100 gramos, para que el sistema pueda calcular automáticamente el aporte nutricional de las recetas y apoyar la planificación alimenticia del paciente.

**Pruebas de aceptación:**
- Permite registrar calorías, proteínas, grasas y carbohidratos por 100 g.
- Permite registrar micronutrientes definidos por el proyecto.
- La información queda asociada al ingrediente.
- Puede actualizarse.
- Los datos quedan disponibles para cálculo de recetas y planes.

---

### HU-23 — Gestión de recetas del repositorio nutricional

| Campo | Detalle |
|-------|---------|
| **ID** | HU-23 |
| **Título** | Gestión de recetas del repositorio nutricional |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-08 |

**Descripción:**
Como Nutricionista, quiero registrar, consultar, actualizar y organizar recetas, para construir el repositorio nutricional del sistema.

**Pruebas de aceptación:**
- Cada receta registra nombre, ingredientes, preparación e imágenes.
- Permite editar recetas.
- No permite guardar recetas incompletas.
- Las recetas pueden consultarse posteriormente.
- Quedan disponibles para el motor y los planes.

---

### HU-24 — Cálculo nutricional automático de recetas

| Campo | Detalle |
|-------|---------|
| **ID** | HU-24 |
| **Título** | Cálculo nutricional automático de recetas |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HU-23, HU-22, HT-23 |

**Descripción:**
Como Nutricionista, quiero que el sistema calcule automáticamente el valor nutricional total y por porción de cada receta, para usar recetas técnicamente validadas dentro de la planificación alimenticia.

**Pruebas de aceptación:**
- El sistema suma automáticamente el aporte de ingredientes.
- Calcula valor total de la receta.
- Calcula valor por porción.
- Se actualiza si cambian ingredientes o gramos.
- La información queda visible para el nutricionista.

---

### HU-25 — Doble clasificación de recetas

| Campo | Detalle |
|-------|---------|
| **ID** | HU-25 |
| **Título** | Doble clasificación de recetas |
| **Rol** | Nutricionista |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Media |
| **Dependencias** | HU-23, HT-24 |

**Descripción:**
Como Nutricionista, quiero clasificar cada receta por tiempo de comida y tipo de plato, para organizar mejor el repositorio y facilitar su uso dentro del plan nutricional.

**Pruebas de aceptación:**
- Una receta puede tener uno o varios tiempos de comida.
- Una receta puede tener uno o varios tipos de plato.
- La clasificación queda guardada correctamente.
- Puede filtrarse por estas clasificaciones.
- La información puede usarse en planificación.

---

### HU-26 — Recomendación de ingredientes permitidos por paciente

| Campo | Detalle |
|-------|---------|
| **ID** | HU-26 |
| **Título** | Recomendación de ingredientes permitidos por paciente |
| **Rol** | Médico o Nutricionista |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-15, HU-18, HU-20, HU-22, HT-10 |

**Descripción:**
Como Médico o Nutricionista, quiero consultar y recomendar ingredientes desde la lista de ingredientes permitidos del paciente, para orientar decisiones alimentarias seguras y coherentes con su condición clínica y nutricional actual.

**Pruebas de aceptación:**
- El sistema muestra únicamente ingredientes permitidos para el paciente seleccionado.
- Excluye ingredientes restringidos por alergias.
- Considera reglas clínicas, nutricionales y temporales activas.
- Médico y nutricionista pueden consultar la lista desde sus módulos autorizados.
- La consulta responde con base en el estado vigente del paciente.

---

### HU-27 — Consulta del repositorio de recetas permitidas

| Campo | Detalle |
|-------|---------|
| **ID** | HU-27 |
| **Título** | Consulta del repositorio de recetas permitidas |
| **Rol** | Médico, Nutricionista o Tutor |
| **Estimación** | 20 puntos (L) |
| **Prioridad** | Alta |
| **Dependencias** | HU-15, HU-18, HU-23, HU-20, HT-10 |

**Descripción:**
Como Médico, Nutricionista o Tutor, quiero consultar el repositorio de recetas permitidas del paciente, para contar con opciones alimentarias seguras y adaptadas a su condición actual.

**Pruebas de aceptación:**
- El repositorio excluye recetas incompatibles con alergias.
- Aplica reglas clínicas, nutricionales y temporales.
- Solo muestra recetas permitidas para el paciente seleccionado.
- El resultado cambia si cambian las condiciones activas.
- La consulta es visible para los roles autorizados.

---

### HU-28 — Creación de planes manuales con plantilla base

| Campo | Detalle |
|-------|---------|
| **ID** | HU-28 |
| **Título** | Creación de planes manuales con plantilla base |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HU-24, HU-25, HU-27, HT-12 |

**Descripción:**
Como Nutricionista, quiero armar un plan manual a partir de una semana tipo o una plantilla base de varios días, para construir la intervención alimenticia del paciente sin tener que diseñar cada día del mes desde cero.

**Pruebas de aceptación:**
- El nutricionista puede definir cuántas comidas por día tendrá el plan.
- Puede organizar recetas por día y tiempo de comida.
- Solo puede usar recetas permitidas para el paciente.
- El plan manual queda guardado y tiene prioridad sobre el automático.
- La estructura del plan puede reutilizarse para la construcción mensual.

---

### HU-29 — Replicación de semana tipo dentro del mes

| Campo | Detalle |
|-------|---------|
| **ID** | HU-29 |
| **Título** | Replicación de semana tipo dentro del mes |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HU-28, HT-12 |

**Descripción:**
Como Nutricionista, quiero diseñar una semana tipo o un bloque de dos semanas y replicarlo hasta completar el mes, para construir planes mensuales con coherencia nutricional sin rehacer manualmente toda la programación.

**Pruebas de aceptación:**
- El nutricionista puede crear una semana tipo.
- Puede crear un bloque de dos semanas.
- El sistema permite replicar la estructura hasta completar el mes.
- La réplica mantiene la organización base del plan.
- El nutricionista puede ajustar semanas específicas después de replicar.

---

### HU-30 — Visualización de barra de metas de energía y proteína del plan manual

| Campo | Detalle |
|-------|---------|
| **ID** | HU-30 |
| **Título** | Visualización de barra de metas de energía y proteína del plan manual |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Media |
| **Dependencias** | HU-24, HU-28, HT-25 |

**Descripción:**
Como Nutricionista, quiero visualizar una barra de avance de energía y proteína mientras armo el plan, para verificar si la selección de recetas cubre las metas alimentarias del niño.

**Pruebas de aceptación:**
- El sistema muestra el avance de energía del día.
- El sistema muestra el avance de proteína del día.
- El cálculo cambia al agregar o quitar recetas.
- La información corresponde al paciente y día seleccionado.
- Sirve como apoyo durante la construcción del plan manual.

---

### HU-31 — Solicitud de plan diario, semanal o mensual

| Campo | Detalle |
|-------|---------|
| **ID** | HU-31 |
| **Título** | Solicitud de plan diario, semanal o mensual |
| **Rol** | Tutor |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HU-27, HT-27, HT-28 |

**Descripción:**
Como Tutor, quiero solicitar un plan diario, semanal o mensual para el paciente únicamente cuando no exista un plan manual vigente definido por el nutricionista, para recibir una guía alimentaria estructurada sin interferir con la intervención profesional activa.

**Pruebas de aceptación:**
- Si existe un plan manual vigente del nutricionista, el tutor no puede generar otro plan.
- Si no existe plan manual vigente, el tutor puede solicitar plan diario, semanal o mensual.
- El sistema le pide cuántas comidas por día requiere el plan automático.
- El plan generado respeta restricciones y reglas activas.
- La solicitud funciona correctamente en móvil.

---

### HU-32 — Solicitud de recomendación puntual

| Campo | Detalle |
|-------|---------|
| **ID** | HU-32 |
| **Título** | Solicitud de recomendación puntual |
| **Rol** | Tutor |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Media |
| **Dependencias** | HU-27, HT-11 |

**Descripción:**
Como Tutor, quiero solicitar una recomendación puntual de una sola comida, para recibir apoyo inmediato sin necesidad de generar un plan completo.

**Pruebas de aceptación:**
- El tutor puede solicitar una recomendación puntual.
- La recomendación sale del conjunto permitido del paciente.
- El sistema no genera un plan completo.
- El resultado puede registrarse posteriormente.
- La respuesta se presenta correctamente.

---

### HU-33 — Consulta de pacientes asociados por parte del tutor

| Campo | Detalle |
|-------|---------|
| **ID** | HU-33 |
| **Título** | Consulta de pacientes asociados por parte del tutor |
| **Rol** | Tutor |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-03, HT-26 |

**Descripción:**
Como Tutor, quiero visualizar los pacientes asociados a mi cuenta, para seleccionar correctamente a quién voy a consultar o dar seguimiento.

**Pruebas de aceptación:**
- El tutor ve uno o varios pacientes asociados.
- No puede ver pacientes no vinculados.
- Puede seleccionar un paciente para abrir su información.
- La navegación funciona en móvil.
- La lista carga correctamente después del inicio de sesión.

---

### HU-34 — Consulta del plan vigente y recetas permitidas

| Campo | Detalle |
|-------|---------|
| **ID** | HU-34 |
| **Título** | Consulta del plan vigente y recetas permitidas |
| **Rol** | Tutor |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-27, HU-31, HU-33, HT-13 |

**Descripción:**
Como Tutor, quiero consultar el plan vigente y las recetas permitidas del paciente desde el móvil, para seguir de forma práctica la alimentación indicada.

**Pruebas de aceptación:**
- El tutor puede ver el plan vigente del paciente.
- Puede consultar el repositorio de recetas permitidas.
- La información corresponde al paciente seleccionado.
- La visualización es adecuada en móvil.
- Los datos reflejan el estado actual.

---

### HU-35 — Filtrado del repositorio permitido por tiempo de comida y tipo de plato

| Campo | Detalle |
|-------|---------|
| **ID** | HU-35 |
| **Título** | Filtrado del repositorio permitido por tiempo de comida y tipo de plato |
| **Rol** | Tutor |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-25, HU-27, HU-34, HT-24 |

**Descripción:**
Como Tutor, quiero filtrar el repositorio de recetas permitidas por tiempo de comida y tipo de plato, para encontrar opciones más útiles según el momento del día y la necesidad del paciente.

**Pruebas de aceptación:**
- El tutor puede filtrar por tiempo de comida.
- El tutor puede filtrar por tipo de plato.
- El sistema solo muestra recetas permitidas para el paciente seleccionado.
- Los filtros pueden combinarse.
- La navegación funciona correctamente en móvil.

---

### HU-36 — Consulta completa del detalle de receta e historial alimentario

| Campo | Detalle |
|-------|---------|
| **ID** | HU-36 |
| **Título** | Consulta completa del detalle de receta e historial alimentario |
| **Rol** | Tutor |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-34, HT-13, HT-23, HT-24 |

**Descripción:**
Como Tutor, quiero consultar el detalle completo de una receta, incluyendo ingredientes, cantidades, preparación, clasificación, imágenes e información asociada, además del historial alimentario del paciente, para comprender mejor lo recomendado y poder prepararlo correctamente en casa.

**Pruebas de aceptación:**
- El tutor puede ver ingredientes y cantidades.
- Puede ver pasos de preparación.
- Puede ver imágenes, tiempo de comida y tipo de plato cuando estén definidos.
- Puede consultar el historial alimentario del paciente.
- La consulta está disponible en móvil y corresponde al paciente seleccionado.

---

### HU-37 — Reemplazo de recetas del plan

| Campo | Detalle |
|-------|---------|
| **ID** | HU-37 |
| **Título** | Reemplazo de recetas del plan |
| **Rol** | Tutor |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-21, HU-31, HT-11 |

**Descripción:**
Como Tutor, quiero reemplazar una receta por otra válida, para adaptar el plan a la aceptación o disponibilidad alimentaria sin incumplir restricciones del paciente.

**Pruebas de aceptación:**
- El sistema presenta alternativas válidas.
- No muestra recetas incompatibles.
- Considera sustitutos cuando corresponda.
- La receta elegida queda registrada como reemplazo.
- El plan se actualiza correctamente.

---

### HU-38 — Reemplazo equivalente de recetas en planes automáticos

| Campo | Detalle |
|-------|---------|
| **ID** | HU-38 |
| **Título** | Reemplazo equivalente de recetas en planes automáticos |
| **Rol** | Tutor |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Media |
| **Dependencias** | HU-21, HU-37, HT-33 |

**Descripción:**
Como Tutor, quiero reemplazar recetas de un plan automático por otras con propiedades equivalentes en gramos, para conservar la coherencia nutricional del plan sin salir de las opciones seguras del paciente.

**Pruebas de aceptación:**
- El reemplazo solo se habilita sobre planes automáticos.
- El sistema ofrece alternativas nutricionalmente equivalentes según la lógica definida.
- El tutor puede seleccionar cualquiera de las alternativas propuestas.
- El reemplazo queda registrado en el historial.
- La sustitución no viola restricciones del paciente.

---

### HU-39 — Registro del resultado de comidas del plan

| Campo | Detalle |
|-------|---------|
| **ID** | HU-39 |
| **Título** | Registro del resultado de comidas del plan |
| **Rol** | Tutor |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-31, HU-37, HT-14 |

**Descripción:**
Como Tutor, quiero registrar si una comida del plan fue consumida, no consumida o reemplazada, para dar seguimiento al cumplimiento alimentario del paciente.

**Pruebas de aceptación:**
- El tutor puede registrar el resultado de cada comida.
- El sistema distingue consumida, no consumida y reemplazada.
- El registro queda asociado al paciente y fecha.
- La información se guarda en historial.
- Los datos quedan listos para el cálculo de adhesión.

---

### HU-40 — Registro del resultado de recomendación puntual

| Campo | Detalle |
|-------|---------|
| **ID** | HU-40 |
| **Título** | Registro del resultado de recomendación puntual |
| **Rol** | Tutor |
| **Estimación** | 5 puntos (XS) |
| **Prioridad** | Media |
| **Dependencias** | HU-32, HT-14 |

**Descripción:**
Como Tutor, quiero registrar si una recomendación puntual fue aceptada o no, para aportar retroalimentación al sistema aunque no exista un plan activo.

**Pruebas de aceptación:**
- El tutor puede registrar el resultado de una recomendación puntual.
- El sistema almacena el evento sin calcular adhesión.
- El dato queda asociado al paciente y a la recomendación emitida.
- El registro queda disponible para análisis posterior.
- La operación se completa sin errores.

---

### HU-41 — Calificación de recetas

| Campo | Detalle |
|-------|---------|
| **ID** | HU-41 |
| **Título** | Calificación de recetas |
| **Rol** | Tutor |
| **Estimación** | 5 puntos (XS) |
| **Prioridad** | Media |
| **Dependencias** | HU-36, HT-14 |

**Descripción:**
Como Tutor, quiero calificar las recetas con una escala de 1 a 5 estrellas, para reflejar el nivel de aceptación del paciente y mejorar recomendaciones futuras.

**Pruebas de aceptación:**
- El tutor puede calificar con 1 a 5 estrellas.
- La calificación queda almacenada correctamente.
- Se asocia al paciente y receta correspondiente.
- Puede consultarse posteriormente.
- El dato queda disponible para priorización futura.

---

### HU-42 — Registro simplificado del motivo de rechazo de una receta

| Campo | Detalle |
|-------|---------|
| **ID** | HU-42 |
| **Título** | Registro simplificado del motivo de rechazo de una receta |
| **Rol** | Tutor |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Media |
| **Dependencias** | HU-41, HT-14 |

**Descripción:**
Como Tutor, quiero indicar de forma rápida por qué una receta no le gustó al paciente, para aportar una retroalimentación útil al sistema sin que el proceso sea tedioso.

**Pruebas de aceptación:**
- El tutor puede registrar un motivo de rechazo con pocas opciones simples.
- El registro del motivo es opcional.
- El flujo no interrumpe la navegación principal.
- El motivo queda asociado a la receta y paciente.
- La información puede usarse para mejorar recomendaciones futuras.

---

### HU-43 — Activación del análisis de rechazo por solicitud del nutricionista

| Campo | Detalle |
|-------|---------|
| **ID** | HU-43 |
| **Título** | Activación del análisis de rechazo por solicitud del nutricionista |
| **Rol** | Nutricionista |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Media |
| **Dependencias** | HU-42, HT-32 |

**Descripción:**
Como Nutricionista, quiero habilitar la captura de motivos de rechazo de recetas para un paciente o período específico, para profundizar el aprendizaje de preferencias solo cuando sea clínicamente necesario.

**Pruebas de aceptación:**
- El nutricionista puede activar o desactivar esta captura adicional.
- El tutor solo visualiza la opción cuando el proceso ha sido habilitado.
- El motivo de rechazo sigue siendo opcional y rápido.
- La activación puede asociarse al paciente o al plan vigente.
- La información queda disponible para análisis posterior.

---

### HU-44 — Cálculo de adhesión del plan alimenticio

| Campo | Detalle |
|-------|---------|
| **ID** | HU-44 |
| **Título** | Cálculo de adhesión del plan alimenticio |
| **Rol** | Nutricionista y Médico |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HU-39, HT-15, HT-28 |

**Descripción:**
Como Nutricionista y Médico, quiero consultar el porcentaje de adhesión del plan alimenticio, para evaluar el cumplimiento del paciente respecto al plan vigente.

**Pruebas de aceptación:**
- La adhesión se calcula solo si existe un plan vigente.
- Usa los registros de comidas del plan.
- No calcula adhesión para recomendaciones puntuales aisladas.
- El resultado queda disponible para consulta profesional.
- El porcentaje refleja correctamente el cumplimiento.

---

### HU-45 — Aprendizaje de preferencias del paciente a partir de calificaciones

| Campo | Detalle |
|-------|---------|
| **ID** | HU-45 |
| **Título** | Aprendizaje de preferencias del paciente a partir de calificaciones |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HU-41, HT-14, HT-31 |

**Descripción:**
Como Nutricionista, quiero que el sistema aprenda las preferencias del paciente a partir de las calificaciones realizadas sobre recetas del repositorio y del plan nutricional, para mejorar futuras recomendaciones y la generación automática de planes.

**Pruebas de aceptación:**
- El sistema usa calificaciones del plan y del repositorio.
- Las recetas mejor valoradas tienen mayor prioridad en recomendaciones futuras.
- El aprendizaje no anula restricciones clínicas ni nutricionales.
- El resultado influye en la generación de planes automáticos.
- El comportamiento puede observarse en recomendaciones posteriores.

---

### HU-46 — Comparación gráfica entre adherencia y dolor

| Campo | Detalle |
|-------|---------|
| **ID** | HU-46 |
| **Título** | Comparación gráfica entre adherencia y dolor |
| **Rol** | Nutricionista |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Media |
| **Dependencias** | HU-11, HU-44, HT-16 |

**Descripción:**
Como Nutricionista, quiero comparar gráficamente la adherencia alimentaria con el nivel de dolor del paciente, para evaluar si el plan nutricional está contribuyendo favorablemente al control clínico.

**Pruebas de aceptación:**
- El sistema muestra la adherencia del paciente.
- El sistema muestra el nivel de dolor de los controles correspondientes.
- Ambos indicadores pueden compararse en una misma vista temporal.
- La información se alimenta de datos reales del sistema.
- La visualización está disponible para el nutricionista.

---

## Historias Técnicas (HT)

---

### HT-01 — Preparación del entorno base de desarrollo

| Campo | Detalle |
|-------|---------|
| **ID** | HT-01 |
| **Título** | Preparación del entorno base de desarrollo |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | Ninguna |

**Descripción:**
Configurar y documentar el entorno base del proyecto con Flutter, Dart, Python, FastAPI, Supabase, PostgreSQL, Git y herramientas de apoyo, garantizando una base homogénea y reproducible para ambos desarrolladores.

**Pruebas de aceptación:**
- Flutter ejecuta correctamente web y móvil.
- FastAPI inicia sin errores críticos.
- La conexión con Supabase funciona.
- Git y el repositorio están operativos.
- Un segundo desarrollador puede levantar el proyecto.

---

### HT-02 — Autenticación y autorización segura

| Campo | Detalle |
|-------|---------|
| **ID** | HT-02 |
| **Título** | Autenticación y autorización segura |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-01 |

**Descripción:**
Configurar autenticación con Supabase Auth y control de acceso por roles mediante JWT y políticas de autorización, asegurando que cada usuario acceda únicamente a lo que le corresponde.

**Pruebas de aceptación:**
- El sistema autentica usuarios con credenciales válidas.
- Los roles restringen accesos correctamente.
- El tutor solo accede a sus pacientes.
- El sistema rechaza accesos indebidos.
- Se registran eventos relevantes de seguridad.

---

### HT-03 — Modelado de base de datos

| Campo | Detalle |
|-------|---------|
| **ID** | HT-03 |
| **Título** | Modelado de base de datos |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-01 |

**Descripción:**
Diseñar, normalizar e implementar el modelo relacional para usuarios, tutores, pacientes, controles, condiciones, reglas, recetas, ingredientes, planes, resultados y auditoría, garantizando integridad y trazabilidad.

**Pruebas de aceptación:**
- El modelo cumple integridad referencial.
- Permite relación tutor con varios pacientes.
- Soporta historial clínico y nutricional.
- Soporta reglas, repositorio y planes.
- Se valida mediante pruebas de persistencia.

---

### HT-04 — Persistencia de información clínica y nutricional

| Campo | Detalle |
|-------|---------|
| **ID** | HT-04 |
| **Título** | Persistencia de información clínica y nutricional |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-03 |

**Descripción:**
Implementar en backend y base de datos la persistencia de datos clínicos iniciales, controles mensuales, evolución del paciente y relaciones principales del seguimiento clínico-nutricional.

**Pruebas de aceptación:**
- El backend guarda información clínica inicial y mensual.
- Los registros quedan relacionados con paciente y tutor.
- Los cambios pueden consultarse sin pérdida.
- Soporta actualizaciones y consulta histórica.
- No genera inconsistencias entre módulos.

---

### HT-05 — Algoritmo de IMC y condición nutricional

| Campo | Detalle |
|-------|---------|
| **ID** | HT-05 |
| **Título** | Algoritmo de IMC y condición nutricional |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HT-04 |

**Descripción:**
Desarrollar la lógica de cálculo automático de IMC y determinación de la condición nutricional vigente, asegurando exactitud en la clasificación y trazabilidad del resultado.

**Pruebas de aceptación:**
- Usa peso en kg y talla en cm para el cálculo correspondiente.
- Devuelve una condición nutricional válida del catálogo.
- El resultado queda almacenado en el control.
- Puede ser consultado por backend y frontend.
- El resultado queda disponible para reglas nutricionales.

---

### HT-06 — Soporte técnico del catálogo general de condiciones

| Campo | Detalle |
|-------|---------|
| **ID** | HT-06 |
| **Título** | Soporte técnico del catálogo general de condiciones |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HT-03 |

**Descripción:**
Construir la estructura de datos y servicios para administrar tipos de condición y condiciones clínicas, nutricionales y temporales, de modo que puedan ser utilizadas como base de las reglas alimentarias.

**Pruebas de aceptación:**
- Existen tablas y servicios para tipos de condición.
- Existen tablas y servicios para condiciones concretas.
- El backend permite CRUD controlado del catálogo.
- La estructura puede usarse en el módulo de reglas.
- Se previenen duplicados inconsistentes.

---

### HT-07 — Implementación del motor heurístico de reglas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-07 |
| **Título** | Implementación del motor heurístico de reglas |
| **Estimación** | 30 puntos (XL) |
| **Prioridad** | Alta |
| **Dependencias** | HT-04, HT-05, HT-06 |

**Descripción:**
Desarrollar el motor heurístico encargado de aplicar reglas alimentarias sobre ingredientes, grupos y etiquetas nutricionales, utilizando las acciones eliminar, disminuir y priorizar, respetando la jerarquía funcional definida por el sistema.

**Pruebas de aceptación:**
- El motor interpreta reglas clínicas, nutricionales y temporales.
- Aplica eliminar, disminuir y priorizar.
- La jerarquía se ejecuta en el orden definido.
- La lógica puede consumirse por API.
- El resultado es consistente en escenarios combinados.

---

### HT-08 — Persistencia del repositorio nutricional

| Campo | Detalle |
|-------|---------|
| **ID** | HT-08 |
| **Título** | Persistencia del repositorio nutricional |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-03 |

**Descripción:**
Implementar la estructura técnica para almacenar y gestionar recetas, ingredientes, grupos alimentarios, etiquetas nutricionales, imágenes y relaciones básicas del repositorio nutricional.

**Pruebas de aceptación:**
- El backend soporta CRUD de recetas.
- Soporta CRUD de ingredientes, grupos y etiquetas.
- Las imágenes pueden asociarse a recetas.
- Las relaciones se mantienen correctamente.
- El repositorio queda disponible para el motor.

---

### HT-09 — Soporte técnico de sustitutos

| Campo | Detalle |
|-------|---------|
| **ID** | HT-09 |
| **Título** | Soporte técnico de sustitutos |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HT-08 |

**Descripción:**
Diseñar e implementar la lógica y persistencia de sustitutos válidos de ingredientes, para que puedan ser utilizados en recomendaciones y reemplazos sin romper restricciones del paciente.

**Pruebas de aceptación:**
- Cada ingrediente puede tener uno o varios sustitutos.
- Los sustitutos quedan relacionados correctamente.
- La lógica de consulta los reconoce.
- El sistema puede usarlos en reemplazos.
- No se sugieren sustitutos incompatibles.

---

### HT-10 — Lógica de construcción de recetas permitidas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-10 |
| **Título** | Lógica de construcción de recetas permitidas |
| **Estimación** | 30 puntos (XL) |
| **Prioridad** | Alta |
| **Dependencias** | HT-07, HT-08, HT-09 |

**Descripción:**
Implementar la lógica de filtrado que construye el repositorio de recetas permitidas de cada paciente, excluyendo recetas incompatibles por alergias y ajustando resultados según reglas activas.

**Pruebas de aceptación:**
- Las recetas con alérgenos se excluyen obligatoriamente.
- Se aplican reglas clínicas, nutricionales y temporales.
- El resultado depende del estado vigente del paciente.
- El repositorio permitido puede consultarse por API.
- Ninguna receta permitida viola restricciones críticas.

---

### HT-11 — Servicios de recomendación puntual y reemplazo

| Campo | Detalle |
|-------|---------|
| **ID** | HT-11 |
| **Título** | Servicios de recomendación puntual y reemplazo |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HT-10 |

**Descripción:**
Desarrollar endpoints y lógica de negocio para emitir recomendaciones puntuales de una comida y sugerir reemplazos válidos dentro del conjunto permitido del paciente.

**Pruebas de aceptación:**
- Existe un endpoint para recomendación puntual.
- Existe un endpoint para reemplazo.
- Ambos usan únicamente recetas permitidas.
- La respuesta incluye información útil para frontend.
- Respetan restricciones activas.

---

### HT-12 — Algoritmos de planificación alimenticia

| Campo | Detalle |
|-------|---------|
| **ID** | HT-12 |
| **Título** | Algoritmos de planificación alimenticia |
| **Estimación** | 20 puntos (L) |
| **Prioridad** | Alta |
| **Dependencias** | HT-10 |

**Descripción:**
Desarrollar la lógica de generación y gestión de planes diarios, semanales y mensuales, considerando la prioridad del plan manual sobre el automático y utilizando exclusivamente recetas compatibles con el paciente.

**Pruebas de aceptación:**
- El sistema genera planes automáticos válidos.
- La lógica reconoce y prioriza el plan manual vigente.
- Soporta planes diarios, semanales y mensuales.
- La estructura del plan se organiza por tiempo de comida.
- Los planes pueden consultarse posteriormente.

---

### HT-13 — Base de presentación multiplataforma en Flutter

| Campo | Detalle |
|-------|---------|
| **ID** | HT-13 |
| **Título** | Base de presentación multiplataforma en Flutter |
| **Estimación** | 20 puntos (L) |
| **Prioridad** | Alta |
| **Dependencias** | HT-01 |

**Descripción:**
Construir la base de presentación del sistema en Flutter para atender, desde una misma tecnología, dos contextos de uso distintos: una aplicación web destinada a administrador, médico y nutricionista, y una aplicación móvil destinada al tutor.

**Pruebas de aceptación:**
- La base funciona en web y móvil.
- Se reutilizan componentes entre ambos contextos.
- La navegación responde a perfiles distintos.
- El diseño se adapta a tamaños de pantalla.
- Se reduce duplicación innecesaria de interfaz.

---

### HT-14 — Persistencia de resultados y retroalimentación

| Campo | Detalle |
|-------|---------|
| **ID** | HT-14 |
| **Título** | Persistencia de resultados y retroalimentación |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HT-03, HT-13 |

**Descripción:**
Implementar la estructura técnica para registrar resultados de comidas del plan, resultados de recomendaciones puntuales, calificaciones y motivos de rechazo de recetas.

**Pruebas de aceptación:**
- Se almacenan resultados de comidas del plan.
- Se almacenan resultados de recomendaciones puntuales.
- Se almacenan calificaciones y motivos de rechazo cuando existan.
- Cada registro se vincula a paciente, tutor y contexto.
- La información queda disponible para consultas posteriores.

---

### HT-15 — Motor de cálculo de adhesión

| Campo | Detalle |
|-------|---------|
| **ID** | HT-15 |
| **Título** | Motor de cálculo de adhesión |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HT-12, HT-14, HT-28 |

**Descripción:**
Desarrollar la lógica de cálculo porcentual de adhesión alimentaria basada únicamente en comidas registradas dentro de un plan vigente.

**Pruebas de aceptación:**
- El cálculo solo se ejecuta si existe plan vigente.
- Usa registros reales de comidas del plan.
- No calcula adhesión para recomendaciones puntuales.
- El resultado queda disponible para consulta.
- El porcentaje es consistente con los datos almacenados.

---

### HT-16 — Visualización gráfica de evolución y comparativas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-16 |
| **Título** | Visualización gráfica de evolución y comparativas |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Media |
| **Dependencias** | HT-13, HT-14, HT-15 |

**Descripción:**
Integrar en Flutter los componentes necesarios para representar la evolución clínica y nutricional del paciente y la comparación entre adherencia y dolor.

**Pruebas de aceptación:**
- Las gráficas consumen datos reales del historial.
- La representación es clara y legible.
- La interfaz funciona correctamente.
- Los gráficos muestran indicadores definidos.
- No existen inconsistencias entre dato y visualización.

---

### HT-17 — Auditoría y transacciones críticas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-17 |
| **Título** | Auditoría y transacciones críticas |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-02, HT-03 |

**Descripción:**
Construir mecanismos de auditoría, registro de eventos y control de transacciones relevantes para proteger la trazabilidad del sistema.

**Pruebas de aceptación:**
- Se registran acciones relevantes de creación, actualización o eliminación.
- Se registran eventos de acceso significativos.
- El sistema conserva trazabilidad suficiente.
- Las operaciones críticas son consistentes.
- Los registros pueden consultarse posteriormente.

---

### HT-18 — Pruebas de rendimiento sobre tareas críticas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-18 |
| **Título** | Pruebas de rendimiento sobre tareas críticas |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HT-10, HT-12, HT-16 |

**Descripción:**
Diseñar y ejecutar pruebas de rendimiento sobre búsqueda en repositorio, consulta de historial, consulta de planes y procesamiento heurístico.

**Pruebas de aceptación:**
- Se prueban operaciones críticas definidas.
- Se registran tiempos de respuesta.
- El procesamiento heurístico se evalúa bajo carga razonable.
- Los resultados quedan documentados.
- Se identifican cuellos de botella cuando existan.

---

### HT-19 — Integración final de web, móvil, backend y base de datos

| Campo | Detalle |
|-------|---------|
| **ID** | HT-19 |
| **Título** | Integración final de web, móvil, backend y base de datos |
| **Estimación** | 30 puntos (XL) |
| **Prioridad** | Alta |
| **Dependencias** | HT-13, HT-14, HT-15, HT-16, HT-17 |

**Descripción:**
Integrar de manera funcional y estable la aplicación web, la aplicación móvil, la API y la base de datos, garantizando interoperabilidad entre módulos.

**Pruebas de aceptación:**
- Web y móvil consumen correctamente la API.
- Los datos fluyen sin inconsistencias.
- Las operaciones principales completan su ciclo funcional.
- Los errores de integración se detectan y corrigen.
- El sistema puede demostrarse como incremento integrado.

---

### HT-20 — Preparación de despliegue y alojamiento

| Campo | Detalle |
|-------|---------|
| **ID** | HT-20 |
| **Título** | Preparación de despliegue y alojamiento |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Media |
| **Dependencias** | HT-19 |

**Descripción:**
Configurar el despliegue del backend en Render, la base de datos en Supabase y la preparación de los artefactos web y móviles para el entorno de explotación.

**Pruebas de aceptación:**
- La API puede desplegarse en Render.
- La base de datos queda accesible en Supabase según configuración segura.
- La versión web puede publicarse.
- La versión móvil queda preparada para distribución.
- La configuración queda documentada.

---

### HT-21 — Soporte técnico para condiciones nutricionales y reglas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-21 |
| **Título** | Soporte técnico para condiciones nutricionales y reglas |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-06, HT-07 |

**Descripción:**
Diseñar e implementar la estructura técnica que permita administrar condiciones nutricionales y asociar múltiples reglas a una misma condición.

**Pruebas de aceptación:**
- La base soporta condiciones nutricionales.
- Una condición nutricional puede tener varias reglas asociadas.
- La trazabilidad entre condición y regla puede consultarse.
- El motor consume correctamente estas asociaciones.
- La configuración puede mantenerse sin inconsistencias.

---

### HT-22 — Soporte técnico para nutrientes por ingrediente

| Campo | Detalle |
|-------|---------|
| **ID** | HT-22 |
| **Título** | Soporte técnico para nutrientes por ingrediente |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-08 |

**Descripción:**
Diseñar la estructura de datos y servicios backend necesarios para almacenar y consultar macronutrientes y micronutrientes por cada 100 gramos de ingrediente.

**Pruebas de aceptación:**
- La base soporta macronutrientes y micronutrientes por ingrediente.
- El backend permite registrar y consultar estos valores.
- La estructura es reutilizable para recetas.
- Los datos pueden actualizarse sin romper relaciones.
- La información queda disponible para frontend y lógica nutricional.

---

### HT-23 — Cálculo nutricional automático de recetas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-23 |
| **Título** | Cálculo nutricional automático de recetas |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-22, HT-08 |

**Descripción:**
Construir la lógica técnica que calcule automáticamente el aporte nutricional total y por porción de cada receta a partir de sus ingredientes y cantidades registradas.

**Pruebas de aceptación:**
- El sistema suma nutrientes de todos los ingredientes de la receta.
- Calcula el aporte total.
- Calcula el aporte por porción.
- El resultado se actualiza cuando cambian ingredientes o cantidades.
- La información queda almacenada para consulta y planificación.

---

### HT-24 — Soporte técnico para doble clasificación de recetas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-24 |
| **Título** | Soporte técnico para doble clasificación de recetas |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Media |
| **Dependencias** | HT-08 |

**Descripción:**
Implementar la estructura técnica que permita asignar múltiples tiempos de comida y múltiples tipos de plato a una misma receta.

**Pruebas de aceptación:**
- Una receta puede tener varios tiempos de comida.
- Una receta puede tener varios tipos de plato.
- Las relaciones múltiples se almacenan correctamente.
- La clasificación puede consultarse y editarse.
- La información puede usarse como filtro.

---

### HT-25 — Apoyo visual al cumplimiento de metas nutricionales

| Campo | Detalle |
|-------|---------|
| **ID** | HT-25 |
| **Título** | Apoyo visual al cumplimiento de metas nutricionales |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Media |
| **Dependencias** | HT-23, HT-12 |

**Descripción:**
Desarrollar la lógica y servicios que calculen el avance de metas nutricionales diarias del paciente dentro del plan manual, permitiendo mostrar indicadores visuales de calorías y proteínas alcanzadas.

**Pruebas de aceptación:**
- El sistema calcula el avance diario según recetas asignadas.
- Considera al menos calorías y proteínas.
- El cálculo se actualiza al modificar el plan.
- La información puede enviarse a la interfaz.
- El resultado corresponde al paciente y día consultado.

---

### HT-26 — Navegación del tutor con múltiples pacientes

| Campo | Detalle |
|-------|---------|
| **ID** | HT-26 |
| **Título** | Navegación del tutor con múltiples pacientes |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-02, HT-13 |

**Descripción:**
Implementar la lógica de sesión, selección de contexto y carga de datos necesaria para que un tutor con varios pacientes asociados pueda navegar entre ellos sin mezclar información.

**Pruebas de aceptación:**
- El sistema mantiene el contexto del paciente seleccionado.
- Cambiar de paciente actualiza plan, historial y recetas.
- No se mezclan registros entre pacientes.
- La navegación es estable en móvil.
- El acceso sigue respetando las restricciones del tutor.

---

### HT-27 — Soporte técnico para solicitud de planes por período

| Campo | Detalle |
|-------|---------|
| **ID** | HT-27 |
| **Título** | Soporte técnico para solicitud de planes por período |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-12, HT-13, HT-26 |

**Descripción:**
Implementar la lógica backend necesaria para que el tutor pueda solicitar planes diarios, semanales o mensuales según el paciente seleccionado.

**Pruebas de aceptación:**
- El backend recibe solicitudes de plan por período.
- La generación se realiza para el paciente seleccionado.
- Los planes respetan reglas y restricciones activas.
- El sistema guarda vigencia y tipo de plan emitido.
- La información queda disponible para consulta.

---

### HT-28 — Distinción técnica entre plan estructurado y recomendación puntual

| Campo | Detalle |
|-------|---------|
| **ID** | HT-28 |
| **Título** | Distinción técnica entre plan estructurado y recomendación puntual |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Alta |
| **Dependencias** | HT-11, HT-12, HT-14, HT-15 |

**Descripción:**
Construir la lógica técnica que distinga claramente entre planes alimenticios estructurados y recomendaciones puntuales, asegurando que solo los planes participen en el cálculo de adhesión.

**Pruebas de aceptación:**
- El sistema diferencia registros provenientes de plan y de recomendación puntual.
- Las recomendaciones puntuales pueden guardar resultado sin generar adhesión.
- La adhesión usa únicamente comidas de planes vigentes.
- La trazabilidad entre ambos tipos de recomendación se conserva.
- El resultado es consistente en consultas y reportes.

---

### HT-29 — Arquitectura híbrida de acceso directo y acceso inteligente

| Campo | Detalle |
|-------|---------|
| **ID** | HT-29 |
| **Título** | Arquitectura híbrida de acceso directo y acceso inteligente |
| **Estimación** | 20 puntos (L) |
| **Prioridad** | Alta |
| **Dependencias** | HT-02, HT-03, HT-07, HT-12, HT-13 |

**Descripción:**
Diseñar e implementar una arquitectura de integración que permita operar el sistema en dos modalidades complementarias: Flutter + Supabase para operaciones estándar de autenticación, consulta y persistencia que no requieran procesamiento inteligente; y Flutter + FastAPI + Supabase para operaciones que sí requieran lógica heurística, cálculo nutricional, construcción del repositorio permitido, generación automática de planes, equivalencias y aprendizaje de preferencias.

**Pruebas de aceptación:**
- El sistema identifica qué operaciones pueden ejecutarse directamente contra Supabase.
- Las operaciones inteligentes se enrutan a FastAPI.
- La arquitectura evita duplicar lógica crítica entre cliente y backend.
- Los módulos mantienen consistencia aunque usen rutas distintas.
- La integración queda documentada.

---

### HT-30 — Ordenamiento contextual del repositorio permitido

| Campo | Detalle |
|-------|---------|
| **ID** | HT-30 |
| **Título** | Ordenamiento contextual del repositorio permitido |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Media |
| **Dependencias** | HT-10, HT-14, HT-24 |

**Descripción:**
Implementar la lógica de ordenamiento del repositorio permitido para que, según el momento del día en que consulta el tutor, el sistema priorice recetas compatibles con ese horario y, sobre ese subconjunto, reordene según las preferencias previamente aprendidas del paciente.

**Pruebas de aceptación:**
- El sistema identifica el contexto temporal de consulta.
- Ordena primero por tiempo de comida compatible.
- Luego reordena según preferencia aprendida.
- No altera restricciones de seguridad del paciente.
- El resultado puede consumirse desde la app móvil.

---

### HT-31 — Motor de preferencia aprendida para recetas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-31 |
| **Título** | Motor de preferencia aprendida para recetas |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-14, HT-12, HT-30 |

**Descripción:**
Construir la lógica técnica que consolide calificaciones de recetas del repositorio y del plan nutricional, generando una señal de preferencia por paciente que pueda ser usada para reordenar recomendaciones y favorecer recetas similares o previamente aceptadas.

**Pruebas de aceptación:**
- La lógica consolida calificaciones por paciente.
- Considera recetas calificadas desde plan y repositorio.
- La preferencia aprendida puede ser consultada por el motor de recomendación.
- No sobreescribe reglas de seguridad alimentaria.
- Mejora el orden de salida de recomendaciones futuras.

---

### HT-32 — Soporte técnico para captura condicional de motivo de rechazo

| Campo | Detalle |
|-------|---------|
| **ID** | HT-32 |
| **Título** | Soporte técnico para captura condicional de motivo de rechazo |
| **Estimación** | 10 puntos (S) |
| **Prioridad** | Media |
| **Dependencias** | HT-14, HT-31 |

**Descripción:**
Implementar la lógica y persistencia necesarias para habilitar de forma condicional la captura simplificada del motivo de rechazo de recetas, permitiendo que el nutricionista decida cuándo ese dato debe solicitarse al tutor.

**Pruebas de aceptación:**
- El sistema permite activar o desactivar la captura adicional.
- La configuración puede aplicarse por paciente o por período.
- El motivo de rechazo se almacena correctamente cuando existe.
- El flujo no exige texto libre obligatorio.
- La información puede ser utilizada por el motor de preferencia.

---

### HT-33 — Motor de equivalencia nutricional para reemplazos automáticos

| Campo | Detalle |
|-------|---------|
| **ID** | HT-33 |
| **Título** | Motor de equivalencia nutricional para reemplazos automáticos |
| **Estimación** | 20 puntos (L) |
| **Prioridad** | Media |
| **Dependencias** | HT-23, HT-12, HT-11 |

**Descripción:**
Desarrollar la lógica técnica que identifique recetas alternativas con propiedades equivalentes en gramos dentro del contexto del plan automático, permitiendo reemplazos controlados que mantengan compatibilidad clínica y coherencia nutricional.

**Pruebas de aceptación:**
- El motor calcula equivalencias según criterios nutricionales definidos.
- Solo propone reemplazos dentro del conjunto permitido del paciente.
- El reemplazo conserva restricciones clínicas y nutricionales.
- El resultado puede consumirse desde la app móvil.
- La sustitución queda registrada para seguimiento.

---

### HT-34 — Soporte técnico para creación contextual de elementos del repositorio desde reglas

| Campo | Detalle |
|-------|---------|
| **ID** | HT-34 |
| **Título** | Soporte técnico para creación contextual de elementos del repositorio desde reglas |
| **Estimación** | 15 puntos (M) |
| **Prioridad** | Alta |
| **Dependencias** | HT-08, HT-17, HT-21 |

**Descripción:**
Implementar la lógica, validaciones y persistencia necesarias para permitir que médico y nutricionista creen ingredientes, etiquetas nutricionales y grupos alimentarios directamente desde el flujo de definición de reglas, manteniendo consistencia con el repositorio nutricional central del sistema.

**Pruebas de aceptación:**
- El sistema permite crear ingredientes desde el flujo de reglas.
- Permite crear etiquetas nutricionales desde el flujo de reglas.
- Permite crear grupos alimentarios desde el flujo de reglas.
- Los nuevos elementos se guardan en el repositorio central.
- El elemento creado queda disponible inmediatamente para asociarlo a la regla activa.
- Se aplican validaciones para evitar duplicados inconsistentes.
- La acción queda registrada en auditoría.
