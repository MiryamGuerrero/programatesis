# Division de Endpoints FastAPI por equipo

## Endpoints Admin + Medico
Archivo: backend/app/api/v1/endpoints/admin_medico.py
Servicios: backend/app/services/admin_medico

- /imc-calculo
- /diagnostico-oms
- /reglas-evaluacion
- /adherencia-calculo

## Endpoints Nutricionista + Tutor
Archivo: backend/app/api/v1/endpoints/nutricion_tutor.py
Servicios: backend/app/services/nutricion_tutor

- /ingredientes-permitidos
- /recetas-permitidas
- /plan-automatico
- /reemplazo-equivalente
- /preferencias-aprendidas

## Objetivo

- Reducir conflictos de merge.
- Permitir ownership claro por modulo.
- Hacer code review por dominio y no por archivo monolitico.
- Reusar logica transversal desde backend/app/services/compartido.
