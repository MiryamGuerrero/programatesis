Reconstrucción limpia de referencias OMS 2007 para pacientes de 5 a 19 años

Archivos principales:
1. referencia_indicador_antropometrico.csv
2. referencia_condicion_nutricional.csv
3. referencia_oms_curva.csv
4. referencia_oms_curva_punto.csv
5. referencia_oms_curva_percentil.csv
6. schema_referencia_oms.sql
7. servicio_oms_refinado.py

Decisión técnica importante:
- Se usaron solo los archivos correctos de BMI e HFA con 168 filas, edades 61 a 228 meses.
- Se ignoraron los archivos duplicados de HFA que tenían solo 61 filas y medianas cercanas a 18-30, porque esos valores corresponden a peso/edad, no a talla/edad.
- El diagnóstico NO debe venir desde oms_curva. El diagnóstico se calcula después del Z-score usando referencia_condicion_nutricional.

Reglas OMS usadas:
BMI/edad:
- z < -3: Delgadez severa
- -3 <= z < -2: Delgadez
- -2 <= z <= +1: Normal
- +1 < z <= +2: Sobrepeso
- z > +2: Obesidad

Talla/edad:
- z < -3: Talla baja severa
- -3 <= z < -2: Talla baja
- -2 <= z <= +3: Talla adecuada para la edad
- z > +3: Talla muy alta para la edad

Ejemplo auditado:
Niño, 120 meses, 110 cm, 30 kg:
- IMC = 24.79
- BMI/edad debe quedar en obesidad, no normal.
- Talla/edad debe quedar como talla baja severa.
