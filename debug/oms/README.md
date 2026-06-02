# Referencia limpia OMS para estado nutricional

Generado: 2026-05-14T15:47:26

## Archivos CSV

- `oms_referencia_zscore.csv`: tabla LMS y cortes SD para WFL, WFH, LHFA, BMI, HFA y WFA.
- `oms_referencia_percentil.csv`: percentiles de las mismas referencias.
- `oms_indicador.csv`: catálogo de indicadores y cuándo usar cada uno.
- `condicion.csv`: catálogo de condiciones nutricionales/talla con IDs.
- `oms_clasificacion_zscore.csv`: reglas limpias de clasificación por z-score.
- `oms_fuente_archivo.csv`: auditoría de archivos usados, duplicados y fuentes originales.
- `schema_referencia.sql`: DDL para crear el esquema `referencia` en PostgreSQL.
- `prompt_algoritmo_estado_nutricional.txt`: prompt para pedir al agente que programe el algoritmo.

## Regla clínica principal

El estado de peso se clasifica así:

- 0 a 23 meses: WFL, peso para longitud.
- 24 a 60 meses: WFH, peso para talla.
- 61 a 228 meses: BMI/IMC para edad.

La talla se clasifica así:

- 0 a 60 meses: LHFA, longitud/talla para edad.
- 61 a 228 meses: HFA, talla para edad.

WFA se dejó como alerta secundaria porque peso/edad no debe reemplazar el diagnóstico de peso principal.

## Conteos

- Filas z-score: 6910
- Filas percentil: 6910
- Archivos auditados: 32
