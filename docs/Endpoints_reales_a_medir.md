# Endpoints reales a medir

| Proceso | Subproceso | Endpoint real |
|---|---|---|
| Búsqueda | Consulta de recetas seguras o permitidas | `POST /api/v1/recetas-permitidas` |
| Búsqueda | Consulta del detalle de receta | `GET /api/v1/tutor/receta-detalle/{id_receta}` |
| Búsqueda | Filtrado por momento o tipo de plato | `GET /api/v1/recetas-permitidas/tipos-disponibles` |
| Recomendación | Consulta del plan diario recomendado | `GET /api/v1/tutor/plan-diario/{id_paciente}` |
| Recomendación | Generación automática de plan | `POST /api/v1/tutor/generar-plan-automatico` |
| Recomendación | Intercambio o reemplazo de receta | `POST /api/v1/tutor/intercambiar-receta-plan` |
| Recomendación / validación | Monitoreo médico de consumo alimentario | `GET /api/v1/pacientes/{id_paciente}/consumo-alimentario` |

## Estratificación corregida con endpoints reales

Como el resultado contiene decimales, se toma el entero superior, por tanto, la muestra será de **385 ejecuciones**. En este estudio se aplicará **muestreo estratificado proporcional**, tomando como base una frecuencia mensual esperada de uso de los endpoints relacionados con la búsqueda y recomendación de recetas nutricionales personalizadas. La distribución no se realiza de forma arbitraria, sino considerando el comportamiento funcional esperado de los roles dentro del sistema.

Para el tutor se considera un uso diario de la aplicación, debido a que puede consultar recetas para los principales momentos de comida del paciente. Para el nutricionista se considera una frecuencia menor, asociada a la generación o ajuste de planes nutricionales. Para el médico se considera una revisión mensual del consumo alimentario, con una revisión adicional si existe alguna reacción, baja adherencia o novedad clínica.

### Tabla: Frecuencia mensual referencial por endpoint

| Proceso principal | Subproceso | Endpoint a medir | Rol | Base de cálculo mensual | Frecuencia mensual |
|---|---|---|---|---|---:|
| Búsqueda | Consulta de recetas seguras o permitidas | `POST /api/v1/recetas-permitidas` | Tutor / Nutricionista | 30 días × 3 momentos de comida | 90 |
| Búsqueda | Consulta del detalle de receta | `GET /api/v1/tutor/receta-detalle/{id_receta}` | Tutor | 30 días × 3 momentos de comida | 90 |
| Búsqueda | Filtrado por momento o tipo de plato | `GET /api/v1/recetas-permitidas/tipos-disponibles` | Tutor | 2 veces por semana × 4 semanas | 8 |
| Recomendación | Consulta del plan diario recomendado | `GET /api/v1/tutor/plan-diario/{id_paciente}` | Tutor | 3 veces por semana × 4 semanas | 12 |
| Recomendación | Generación automática de plan nutricional | `POST /api/v1/tutor/generar-plan-automatico` | Tutor / Nutricionista | 1 planificación mensual + 1 ajuste eventual | 2 |
| Recomendación | Intercambio o reemplazo de receta | `POST /api/v1/tutor/intercambiar-receta-plan` | Tutor | 2 reemplazos eventuales al mes | 2 |
| Recomendación / validación | Monitoreo médico del consumo alimentario | `GET /api/v1/pacientes/{id_paciente}/consumo-alimentario` | Médico | 1 revisión mensual + 1 revisión por novedad | 2 |
| **Total** |  |  |  |  | **206** |

## Cálculo de la afijación proporcional

La fórmula es:

$$
n_h = \frac{N_h}{N} \cdot n
$$

Donde:

| Símbolo | Descripción |
|---|---|
| $n_h$ | Muestra asignada al endpoint |
| $N_h$ | Frecuencia mensual referencial del endpoint |
| $N$ | Frecuencia mensual total referencial |
| $n$ | Tamaño total de la muestra, equivalente a 385 ejecuciones |

En este caso:

$$
N = 206
$$

$$
n = 385
$$

### Tabla: Estratificación final para las 385 ejecuciones

| Proceso principal | Subproceso | Endpoint a medir | $N_h$ | Proporción | Cálculo | Muestra asignada |
|---|---|---|---:|---:|---:|---:|
| Búsqueda | Consulta de recetas seguras o permitidas | `POST /api/v1/recetas-permitidas` | 90 | 43,69 % | $90/206 \times 385$ | 168 |
| Búsqueda | Consulta del detalle de receta | `GET /api/v1/tutor/receta-detalle/{id_receta}` | 90 | 43,69 % | $90/206 \times 385$ | 168 |
| Búsqueda | Filtrado por momento o tipo de plato | `GET /api/v1/recetas-permitidas/tipos-disponibles` | 8 | 3,88 % | $8/206 \times 385$ | 15 |
| Recomendación | Consulta del plan diario recomendado | `GET /api/v1/tutor/plan-diario/{id_paciente}` | 12 | 5,83 % | $12/206 \times 385$ | 22 |
| Recomendación | Generación automática de plan nutricional | `POST /api/v1/tutor/generar-plan-automatico` | 2 | 0,97 % | $2/206 \times 385$ | 4 |
| Recomendación | Intercambio o reemplazo de receta | `POST /api/v1/tutor/intercambiar-receta-plan` | 2 | 0,97 % | $2/206 \times 385$ | 4 |
| Recomendación / validación | Monitoreo médico del consumo alimentario | `GET /api/v1/pacientes/{id_paciente}/consumo-alimentario` | 2 | 0,97 % | $2/206 \times 385$ | 4 |
| **Total** |  |  | **206** | **100 %** |  | **385** |

## Justificación

La estratificación de la muestra se realizó mediante muestreo estratificado proporcional, tomando como referencia la frecuencia mensual esperada de uso de los endpoints relacionados con la búsqueda y recomendación de recetas nutricionales personalizadas. Para ello, se consideró el comportamiento funcional de los roles principales del sistema. El tutor representa el uso más frecuente, porque consulta recetas y detalles asociados a los momentos diarios de alimentación del paciente. El nutricionista interviene con menor frecuencia, principalmente durante la generación o ajuste del plan nutricional. El médico participa en la revisión del consumo alimentario durante el control mensual o ante una novedad clínica.

Cada subproceso fue vinculado con su endpoint real dentro de la API, con el fin de delimitar técnicamente qué solicitud será medida en las pruebas de rendimiento. Esto permite que la estratificación no se base únicamente en acciones funcionales generales, sino en operaciones concretas del backend. De esta manera, la asignación de las 385 ejecuciones responde a una frecuencia de uso esperada y a endpoints verificables en la documentación Swagger de la aplicación, evitando una distribución arbitraria de la muestra.
