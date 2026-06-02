# Referencia OMS limpia

El esquema `referencia` se reconstruye desde los CSV limpios de `oms/` con:

```bash
cd backend
python scripts/reset_referencia_oms.py
```

El script borra `referencia` completo, ejecuta `oms/schema_referencia.sql`, importa los CSV y valida conteos, duplicados, indicadores, sexos, rangos y valores z-score.

## Regla clinica

El diagnostico principal de peso no usa peso/edad como criterio principal. El peso depende de la longitud, talla o IMC segun edad:

- 0 a 23 meses: `WFL`, peso para longitud.
- 24 a 60 meses: `WFH`, peso para talla.
- 61 a 228 meses: `BMI`, IMC para edad.

La talla se evalua asi:

- 0 a 60 meses: `LHFA`, longitud/talla para edad.
- 61 a 228 meses: `HFA`, talla para edad.

`WFA` queda solo como alerta secundaria. No reemplaza el diagnostico principal porque no distingue entre un paciente bajo, alto, delgado o con exceso de peso.

## Salida del algoritmo

`ServicioOMS.evaluar_paciente_integral` devuelve:

- diagnostico de peso con indicador, z-score, condicion y explicacion.
- diagnostico de talla con indicador, z-score, condicion y explicacion.
- WFA como complemento si hay referencia.
- resumen clinico automatico.

El diagnostico principal siempre sale de z-score y no mezcla percentiles.
