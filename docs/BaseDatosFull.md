# DOCUMENTACIÓN COMPLETA DE BASE DE DATOS - REUMA NUTRI

---

## CONTEXTO DE LA APLICACIÓN

**Reuma Nutri** es una plataforma integral de gestión nutricional especializada para pacientes con enfermedades reumáticas. Su objetivo es proporcionar planes alimenticios personalizados que consideren las condiciones de salud específicas de cada paciente, alergias, restricciones alimentarias y preferencias personales.

La aplicación está compuesta por un **backend** desarrollado en Python (FastAPI) que se conecta a una base de datos **PostgreSQL** alojada en **Supabase**, y un **frontend** web. La base de datos está organizada en los siguientes esquemas:

| Esquema | Propósito |
|---------|-----------|
| `usuarios` | Gestión de usuarios, pacientes, tutores, roles y ubicaciones geográficas |
| `clinico` | Datos clínicos: diagnósticos, alergias, controles, restricciones y recomendaciones |
| `nutricion` | Catálogo nutricional: ingredientes, recetas, nutrientes, grupos alimentarios |
| `interaccion` | Interacción paciente-sistema: planes nutricionales, evaluaciones, preferencias |
| `heuristico` | Motor de reglas heurísticas para determinar acciones según condiciones |
| `referencia` | Tablas de referencia OMS (Organización Mundial de la Salud) para evaluación nutricional |
| `seguridad` | Auditoría y registro de errores del sistema |
| `public` | Vistas y tablas públicas |

---

## ESQUEMA: usuarios

Gestiona toda la información relacionada con personas (usuarios, pacientes, tutores), roles, parentescos y ubicaciones geográficas (cantones, parroquias).

---

### TABLA: canton
**Descripción:** Catálogo de cantones/provincias del Ecuador para ubicación geográfica de pacientes.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del cantón | integer(32) | NO | Entero positivo autogenerado (secuencia `usuarios.provincia_id_seq`) |
| nombre | Nombre del cantón | text | NO | Cadena de texto con el nombre geográfico |

---

### TABLA: parroquia
**Descripción:** Catálogo de parroquias del Ecuador, asociadas a un cantón.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la parroquia | integer(32) | NO | Entero positivo autogenerado (secuencia `usuarios.parroquia_id_seq`) |
| nombre | Nombre de la parroquia | character varying(100) | NO | Cadena de texto [A-Z\|a-z\| espacios] |
| id_canton (FK) | Identificador del cantón al que pertenece | integer(32) | NO | Entero positivo - FK a `canton.id` |

---

### TABLA: catalogo_sexo
**Descripción:** Catálogo de sexos biológicos.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del sexo | integer(32) | NO | Entero positivo autogenerado (secuencia `usuarios.catalogo_sexo_id_seq`) |
| descripcion | Descripción del sexo | character varying(50) | NO | [Masculino \| Femenino \| Otro] |

---

### TABLA: parentesco
**Descripción:** Catálogo de tipos de parentesco entre tutor y paciente.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del parentesco | integer(32) | NO | Entero positivo autogenerado (secuencia `usuarios.parentesco_id_seq`) |
| nombre | Nombre del parentesco | character varying(50) | NO | [Padre, Madre, Hermano, Abuelo, Tío, Otro] |

---

### TABLA: rol
**Descripción:** Catálogo de roles del sistema para control de acceso.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del rol | integer(32) | NO | Entero positivo autogenerado (secuencia `usuarios.rol_id_seq`) |
| nombre | Nombre del rol | character varying(50) | NO | [admin, medico, nutricionista, paciente, tutor] |
| descripcion | Descripción del rol | text | SI | Texto descriptivo del rol |
| activo | Indica si el rol está activo | boolean | SI | [true \| false] - Default: true |

---

### TABLA: usuario
**Descripción:** Usuarios del sistema con credenciales de acceso y datos personales.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del usuario | uuid | NO | UUID v4 generado automáticamente (`gen_random_uuid()`) |
| auth_user_id | ID del usuario en Supabase Auth | uuid | SI | UUID del usuario autenticado en Supabase |
| id_rol (FK) | Rol asignado al usuario | integer(32) | NO | Entero positivo - FK a `rol.id` |
| cedula | Cédula de identidad del usuario | character varying(20) | SI | [0000000000]* - 10 dígitos [0-9] |
| username | Nombre de usuario para inicio de sesión | character varying(80) | SI | Cadena alfanumérica única |
| email | Correo electrónico del usuario | character varying(255) | NO | Formato email válido: `usuario@dominio.com` |
| nombre_completo | Nombres y apellidos completos | character varying(200) | NO | [A-Z\|a-z\| espacios] - Nombres + Apellidos |
| telefono | Número de teléfono de contacto | character varying(30) | SI | [0-9] - Código de área + número |
| direccion | Dirección de domicilio | text | SI | Texto con dirección física |
| requiere_cambio_password | Indica si el usuario debe cambiar su contraseña | boolean | NO | [true \| false] - Default: false |
| activo | Indica si el usuario está activo en el sistema | boolean | NO | [true \| false] - Default: true |
| ultimo_login | Fecha y hora del último inicio de sesión | timestamp without time zone | SI | Formato: YYYY-MM-DD HH:24:MI:SS |
| created_at | Fecha y hora de creación del registro | timestamp without time zone | NO | Default: `now()` - Formato: YYYY-MM-DD HH:24:MI:SS |
| updated_at | Fecha y hora de última modificación | timestamp without time zone | NO | Default: `now()` - Formato: YYYY-MM-DD HH:24:MI:SS |
| created_by | ID del usuario que creó el registro | uuid | SI | UUID - FK a `usuario.id` |
| updated_by | ID del usuario que modificó el registro | uuid | SI | UUID - FK a `usuario.id` |
| deactivated_at | Fecha y hora de desactivación | timestamp without time zone | SI | Formato: YYYY-MM-DD HH:24:MI:SS |
| deactivated_by | ID del usuario que desactivó | uuid | SI | UUID - FK a `usuario.id` |
| deactivated_reason | Motivo de desactivación | text | SI | Texto explicativo |
| cedula_enc | Cédula encriptada para protección de datos | bytea | SI | Dato binario encriptado |

---

### TABLA: paciente
**Descripción:** Pacientes registrados en el sistema para seguimiento nutricional.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del paciente | uuid | NO | UUID v4 generado automáticamente (`gen_random_uuid()`) |
| nombre_completo | Nombre completo del paciente | character varying(200) | NO | [A-Z\|a-z\| espacios] |
| fecha_nacimiento | Fecha de nacimiento del paciente | date | NO | Formato: YYYY-MM-DD |
| id_sexo (FK) | Sexo del paciente | integer(32) | NO | Entero positivo - FK a `catalogo_sexo.id` |
| id_canton (FK) | Cantón de residencia del paciente | integer(32) | SI | Entero positivo - FK a `canton.id` |
| activo | Indica si el paciente está activo | boolean | NO | [true \| false] - Default: true |
| created_at | Fecha de creación del registro | timestamp without time zone | NO | Default: `now()` |
| updated_at | Fecha de última modificación | timestamp without time zone | NO | Default: `now()` |
| cedula | Cédula de identidad del paciente | text | SI | [0000000000]* - 10 dígitos [0-9] |
| id_parroquia (FK) | Parroquia de residencia del paciente | integer(32) | SI | Entero positivo - FK a `parroquia.id` |
| preferencias_configuradas | Indica si el paciente ha configurado preferencias | boolean | SI | [true \| false] - Default: false |

---

### TABLA: tutor_paciente
**Descripción:** Relación entre tutores (usuarios) y pacientes que tienen bajo su cuidado.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la relación tutor-paciente | bigint(64) | NO | Entero positivo autogenerado (secuencia `usuarios.tutor_paciente_id_seq`) |
| id_usuario_tutor (FK) | ID del usuario tutor | uuid | NO | UUID - FK a `usuario.id` |
| id_paciente (FK) | ID del paciente asignado | uuid | NO | UUID - FK a `paciente.id` |
| id_parentesco (FK) | Tipo de parentesco del tutor con el paciente | integer(32) | SI | Entero positivo - FK a `parentesco.id` |
| es_principal | Indica si es el tutor principal | boolean | NO | [true \| false] - Default: false |
| activo | Indica si la relación está activa | boolean | NO | [true \| false] - Default: true |
| created_at | Fecha de creación del registro | timestamp without time zone | NO | Default: `now()` |

---

### TABLA: vista_gestion_pacientes (VIEW)
**Descripción:** Vista que consolida información de pacientes para gestión médica, incluyendo diagnóstico principal, severidad y condición nutricional.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id | Identificador del paciente | uuid | SI | UUID del paciente |
| nombre_completo | Nombre completo del paciente | character varying(200) | SI | [A-Z\|a-z\| espacios] |
| cedula | Cédula del paciente | text | SI | 10 dígitos [0-9] |
| enfermedad_principal | Diagnóstico principal del paciente | character varying(150) | SI | Nombre de la condición/enfermedad |
| edad_anios | Edad del paciente en años | integer(32) | SI | Entero positivo |
| severidad | Nivel de severidad de la condición | character varying(50) | SI | [Leve \| Moderada \| Severa] |
| condicion_nutricional | Estado/condición nutricional actual | character varying(150) | SI | Texto descriptivo |
| ultima_atencion | Fecha de la última atención registrada | date | SI | Formato: YYYY-MM-DD |

---

## ESQUEMA: clinico

Gestiona toda la información clínica de los pacientes: alergias, diagnósticos, controles, restricciones y recomendaciones.

---

### TABLA: catalogo_restriccion_alimentaria
**Descripción:** Catálogo de tipos de restricciones alimentarias que pueden aplicarse a pacientes.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| codigo (PK) | Código único identificador de la restricción | text | NO | Código alfanumérico único |
| nombre | Nombre de la restricción alimentaria | text | NO | [Vegetariano, Vegano, Sin gluten, Sin lactosa, Diabético, etc.] |
| descripcion | Descripción detallada de la restricción | text | SI | Texto explicativo |
| etiqueta_bloqueante_codigo | Código de la etiqueta nutricional bloqueante asociada | text | NO | Código FK a etiqueta nutricional |
| activa | Indica si la restricción está activa | boolean | NO | [true \| false] - Default: true |
| created_at | Fecha de creación del registro | timestamp with time zone | NO | Default: `now()` |

---

### TABLA: diagnostico_paciente
**Descripción:** Diagnósticos médicos asignados a pacientes, incluyendo condiciones reumáticas.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del diagnóstico | bigint(64) | NO | Entero positivo autogenerado (secuencia `clinico.diagnostico_paciente_id_seq`) |
| id_paciente | ID del paciente diagnosticado | uuid | NO | UUID - FK a `paciente.id` |
| id_condicion | ID de la condición médica diagnosticada | integer(32) | NO | FK a condición |
| fecha_diagnostico | Fecha en que se realizó el diagnóstico | date | NO | Default: `CURRENT_DATE` - Formato: YYYY-MM-DD |
| es_cronico | Indica si la condición es crónica | boolean | NO | [true \| false] - Default: true |
| esta_activo | Indica si el diagnóstico está activo | boolean | NO | [true \| false] - Default: true |
| observaciones | Observaciones adicionales del diagnóstico | text | SI | Texto libre |
| fecha_fin | Fecha de finalización del diagnóstico | date | SI | Formato: YYYY-MM-DD |
| created_at | Fecha de creación del registro | timestamp without time zone | SI | Default: `now()` |
| updated_at | Fecha de última modificación | timestamp without time zone | SI | Default: `now()` |

---

### TABLA: alergia_paciente_ingrediente
**Descripción:** Registro de alergias de pacientes a ingredientes específicos.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del registro de alergia | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente con alergia | uuid | NO | UUID - FK a `paciente.id` |
| id_ingrediente | ID del ingrediente al que es alérgico | integer(32) | NO | FK a `nutricion.ingrediente.id` |
| fecha_registro | Fecha de registro de la alergia | date | NO | Default: `CURRENT_DATE` |
| activa | Indica si la alergia está activa | boolean | NO | [true \| false] - Default: true |
| observacion | Observación sobre la alergia | text | SI | Síntomas, reacciones, nivel de severidad |
| fecha_fin | Fecha en que cesó la alergia | date | SI | Formato: YYYY-MM-DD |
| updated_at | Fecha de última modificación | timestamp without time zone | SI | Default: `now()` |
| created_at | Fecha de creación del registro | timestamp without time zone | SI | Default: `now()` |

---

### TABLA: alergia_paciente_subgrupo
**Descripción:** Registro de alergias de pacientes a subgrupos alimentarios completos.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del registro | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente con alergia | uuid | NO | UUID - FK a `paciente.id` |
| id_subgrupo_alimentario | ID del subgrupo alimentario alergénico | integer(32) | NO | FK a `nutricion.subgrupo_alimentario.id` |
| fecha_registro | Fecha de registro de la alergia | date | NO | Default: `CURRENT_DATE` |
| activa | Indica si la alergia está activa | boolean | NO | [true \| false] - Default: true |
| observacion | Observación sobre la alergia | text | SI | Descripción de síntomas o reacciones |
| created_at | Fecha de creación del registro | timestamp without time zone | NO | Default: `now()` |
| updated_at | Fecha de última modificación | timestamp without time zone | NO | Default: `now()` |
| fecha_fin | Fecha en que cesó la alergia | date | SI | Formato: YYYY-MM-DD |

---

### TABLA: control_paciente
**Descripción:** Registro de controles periódicos del paciente (peso, talla, IMC, evaluación de síntomas).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del control | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente | uuid | NO | UUID - FK a `paciente.id` |
| fecha_control | Fecha del control | date | NO | Default: `CURRENT_DATE` |
| peso_kg | Peso del paciente en kilogramos | numeric(6,2) | NO | Número positivo (máx 9999.99 kg) |
| talla_cm | Talla/estatura del paciente en centímetros | numeric(6,2) | NO | Número positivo (máx 9999.99 cm) |
| edad_meses | Edad del paciente en meses al momento del control | integer(32) | NO | Entero positivo |
| imc_calculado | Índice de Masa Corporal calculado | numeric(8,4) | SI | Fórmula: peso / (talla^2) |
| id_condicion_nutricional_resultado | Condición nutricional resultante del control | integer(32) | SI | FK a condición nutricional |
| estado_nutricional | Estado nutricional determinado | character varying(150) | SI | [Normal, Sobrepeso, Obesidad, Desnutrición, etc.] |
| puntos_dolor | Puntuación de dolor del paciente (escala) | integer(32) | SI | Entero 0-10 |
| escala_inflamacion | Escala de inflamación (EVA) | integer(32) | SI | Entero 0-10 |
| nivel_fatiga | Nivel de fatiga reportado | integer(32) | SI | Entero 0-10 |
| minutos_rigidez | Minutos de rigidez matutina | integer(32) | SI | Entero >= 0 |
| en_brote | Indica si el paciente está en brote | boolean | SI | [true \| false] |
| nota_evolucion | Nota de evolución del paciente | text | SI | Texto libre con observaciones |
| created_at | Fecha de creación del registro | timestamp without time zone | NO | Default: `now()` |
| id_medico | ID del médico que realizó el control | uuid | SI | UUID del usuario médico |
| id_nutricionista | ID del nutricionista que realizó el control | uuid | SI | UUID del usuario nutricionista |
| fecha_proxima_cita | Fecha sugerida para próxima cita | date | SI | Formato: YYYY-MM-DD |
| articulaciones_inflamadas | Conteo de articulaciones inflamadas | integer(32) | SI | Entero >= 0 - Default: 0 |
| articulaciones_dolorosas | Conteo de articulaciones dolorosas | integer(32) | SI | Entero >= 0 - Default: 0 |
| estado_enfermedad | Estado general de la enfermedad | character varying(50) | SI | [Activo, Remisión, Estable, Brote] - Default: 'Estable' |

---

### TABLA: control_condicion_activa
**Descripción:** Relación entre controles y condiciones activas del paciente durante ese control.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del registro | bigint(64) | NO | Entero positivo autogenerado |
| id_control (FK) | ID del control asociado | bigint(64) | NO | FK a `control_paciente.id` |
| id_condicion | ID de la condición activa | integer(32) | NO | FK a condición |
| fecha_inicio | Fecha de inicio de la condición | date | SI | Formato: YYYY-MM-DD |
| fecha_fin | Fecha de fin de la condición | date | SI | Formato: YYYY-MM-DD |
| esta_activa | Indica si la condición está activa | boolean | SI | [true \| false] - Default: true |
| observacion | Observación sobre la condición | text | SI | Texto libre |
| fecha_registro | Fecha de registro | timestamp with time zone | SI | Default: `now()` |

---

### TABLA: restriccion_paciente
**Descripción:** Restricciones alimentarias asignadas a un paciente.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la restricción | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente | uuid | NO | UUID - FK a `paciente.id` |
| codigo_restriccion (FK) | Código del tipo de restricción | text | NO | FK a `catalogo_restriccion_alimentaria.codigo` |
| fecha_registro | Fecha de registro de la restricción | timestamp with time zone | NO | Default: `now()` |
| activa | Indica si la restricción está activa | boolean | NO | [true \| false] - Default: true |
| observacion | Observación sobre la restricción | text | SI | Texto explicativo |
| created_at | Fecha de creación del registro | timestamp with time zone | NO | Default: `now()` |

---

### TABLA: recomendacion_ingrediente
**Descripción:** Recomendaciones de ingredientes específicos para pacientes por parte de profesionales.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la recomendación | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente recomendado | uuid | NO | UUID - FK a `paciente.id` |
| id_ingrediente | ID del ingrediente recomendado | integer(32) | NO | FK a `nutricion.ingrediente.id` |
| id_profesional | ID del profesional que recomienda | uuid | SI | UUID del usuario profesional |
| id_rol_recomienda | Rol del profesional que recomienda | integer(32) | SI | FK a `rol.id` |
| motivo | Motivo de la recomendación | text | SI | Texto explicativo |
| prioridad | Nivel de prioridad de la recomendación | integer(32) | SI | [1: Baja \| 2: Media \| 3: Alta] - Default: 2 |
| fecha_recomendacion | Fecha de la recomendación | date | SI | Default: `CURRENT_DATE` |
| activa | Indica si la recomendación está activa | boolean | SI | [true \| false] - Default: true |
| created_at | Fecha de creación del registro | timestamp without time zone | SI | Default: `CURRENT_TIMESTAMP` |
| updated_at | Fecha de última modificación | timestamp without time zone | SI | Default: `CURRENT_TIMESTAMP` |

---

### TABLA: validacion_control_nutricional_mensual
**Descripción:** Validación mensual de controles nutricionales para asegurar que se haya realizado al menos un control por mes.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la validación | bigint(64) | NO | Entero positivo autogenerado |
| id_control | ID del control nutricional validado | bigint(64) | NO | FK a `control_paciente.id` |
| id_paciente | ID del paciente | uuid | NO | UUID - FK a `paciente.id` |
| anio | Año de la validación | integer(32) | NO | [2024-2099] |
| mes | Mes de la validación | integer(32) | NO | [1-12] |
| confirmado | Indica si el mes fue confirmado | boolean | NO | [true \| false] - Default: true |
| fecha_confirmacion | Fecha de confirmación | timestamp without time zone | NO | Default: `now()` |

---

### TABLA: v_recomendaciones_activas_paciente (VIEW)
**Descripción:** Vista de recomendaciones activas de ingredientes por paciente.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id_paciente | ID del paciente | uuid | SI | UUID del paciente |
| id_ingrediente | ID del ingrediente recomendado | integer(32) | SI | FK a ingrediente |
| ingrediente_nombre | Nombre del ingrediente | character varying(180) | SI | Nombre descriptivo |
| id_rol_recomienda | Rol del profesional que recomienda | integer(32) | SI | FK a rol |
| id_profesional | ID del profesional | uuid | SI | UUID del profesional |
| motivo | Motivo de la recomendación | text | SI | Texto explicativo |
| prioridad | Prioridad de la recomendación | integer(32) | SI | [1-3] |
| fecha_recomendacion | Fecha de recomendación | date | SI | Formato: YYYY-MM-DD |

---

## ESQUEMA: nutricion

Catálogo nutricional completo del sistema: ingredientes, su composición nutricional, recetas, grupos alimentarios, etiquetas y métricas.

---

### TABLA: grupo_alimentario
**Descripción:** Clasificación de alto nivel de grupos alimentarios.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del grupo alimentario | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del grupo alimentario | character varying(120) | NO | [Lácteos, Carnes, Frutas, Verduras, Cereales, Legumbres, Grasas, Azúcares, etc.] |

---

### TABLA: subgrupo_alimentario
**Descripción:** Subclasificación dentro de un grupo alimentario.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del subgrupo | integer(32) | NO | Entero positivo autogenerado |
| id_grupo_alimentario (FK) | ID del grupo alimentario padre | integer(32) | NO | FK a `grupo_alimentario.id` |
| nombre | Nombre del subgrupo alimentario | character varying(120) | NO | Ej: "Lácteos enteros", "Carnes rojas", "Frutas cítricas" |
| emoji | Emoji representativo del subgrupo | character varying(10) | SI | Carácter emoji Unicode |

---

### TABLA: ingrediente
**Descripción:** Catálogo de ingredientes alimentarios con su información general.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del ingrediente | integer(32) | NO | Entero positivo autogenerado |
| id_grupo_alimentario (FK) | ID del grupo alimentario al que pertenece | integer(32) | NO | FK a `grupo_alimentario.id` |
| id_subgrupo_alimentario (FK) | ID del subgrupo alimentario al que pertenece | integer(32) | NO | FK a `subgrupo_alimentario.id` |
| nombre | Nombre del ingrediente | character varying(180) | NO | [A-Z\|a-z\| espacios] - Nombre único |
| factor_parte_comestible | Factor de porción comestible (rendimiento) | numeric(12,2) | NO | [0.00 - 1.00] - Ej: 0.85 = 85% comestible |
| activo | Indica si el ingrediente está activo | boolean | NO | [true \| false] - Default: true |
| created_at | Fecha de creación del registro | timestamp without time zone | NO | Default: `now()` |
| updated_at | Fecha de última modificación | timestamp without time zone | NO | Default: `now()` |
| imagen_referencia | URL de imagen de referencia del ingrediente | text | SI | URL de imagen |
| sinonimos | Lista de sinónimos o nombres alternativos | ARRAY[text] | SI | ARRAY['nombre1', 'nombre2'] - Default: ARRAY[] |

---

### TABLA: ingrediente_composicion
**Descripción:** Composición nutricional completa de cada ingrediente por 100g.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id_ingrediente (PK)(FK) | ID del ingrediente | integer(32) | NO | FK a `ingrediente.id` |
| energia_kcal | Energía (kcal) | numeric(18,3) | NO | >= 0 |
| agua_g | Agua (g) | numeric(18,3) | NO | >= 0 |
| alcohol_g | Alcohol (g) | numeric(18,3) | NO | >= 0 |
| proteinas_g | Proteínas (g) | numeric(18,3) | NO | >= 0 |
| hidratos_carbono_g | Hidratos de carbono (g) | numeric(18,8) | NO | >= 0 |
| almidon_g | Almidón (g) | numeric(18,8) | NO | >= 0 |
| azucares_sencillos_g | Azúcares sencillos (g) | numeric(18,3) | NO | >= 0 |
| azucares_libres_g | Azúcares libres (g) | numeric(18,3) | NO | >= 0 |
| fibra_vegetal_g | Fibra vegetal (g) | numeric(18,3) | NO | >= 0 |
| grasa_total_g | Grasa total (g) | numeric(18,3) | NO | >= 0 |
| ags_g | Ácidos grasos saturados (g) | numeric(18,3) | NO | >= 0 |
| agm_g | Ácidos grasos monoinsaturados (g) | numeric(18,3) | NO | >= 0 |
| agp_g | Ácidos grasos poliinsaturados (g) | numeric(18,3) | NO | >= 0 |
| colesterol_mg | Colesterol (mg) | numeric(18,3) | NO | >= 0 |
| vitamina_a_eq_retinol_ug | Vitamina A - equivalentes de retinol (µg) | numeric(18,3) | NO | >= 0 |
| retinol_ug | Retinol (µg) | numeric(18,3) | NO | >= 0 |
| carotenoides_eq_beta_caroteno_ug | Carotenoides - equivalentes de beta-caroteno (µg) | numeric(18,8) | NO | >= 0 |
| vit_d_ug | Vitamina D (µg) | numeric(18,3) | NO | >= 0 |
| vit_e_eq_alpha_tocoferol_mg | Vitamina E - equivalentes de alfa-tocoferol (mg) | numeric(18,3) | NO | >= 0 |
| vit_k_ug | Vitamina K (µg) | numeric(18,3) | NO | >= 0 |
| vitamina_b1_mg | Vitamina B1 - Tiamina (mg) | numeric(18,3) | NO | >= 0 |
| vitamina_b2_mg | Vitamina B2 - Riboflavina (mg) | numeric(18,3) | NO | >= 0 |
| eq_niacina_mg | Equivalentes de niacina (mg) | numeric(18,3) | NO | >= 0 |
| vit_b6_mg | Vitamina B6 (mg) | numeric(18,3) | NO | >= 0 |
| eq_folato_dietetico_ug | Equivalentes de folato dietético (µg) | numeric(18,3) | NO | >= 0 |
| vit_b12_ug | Vitamina B12 (µg) | numeric(18,3) | NO | >= 0 |
| pantotenico_mg | Ácido pantoténico - B5 (mg) | numeric(18,3) | NO | >= 0 |
| biotina_ug | Biotina - B7 (µg) | numeric(18,3) | NO | >= 0 |
| vit_c_mg | Vitamina C (mg) | numeric(18,3) | NO | >= 0 |
| calcio_mg | Calcio (mg) | numeric(18,3) | NO | >= 0 |
| fosforo_mg | Fósforo (mg) | numeric(18,3) | NO | >= 0 |
| hierro_mg | Hierro (mg) | numeric(18,3) | NO | >= 0 |
| iodo_ug | Yodo (µg) | numeric(18,3) | NO | >= 0 |
| cinc_mg | Zinc (mg) | numeric(18,3) | NO | >= 0 |
| magnesio_mg | Magnesio (mg) | numeric(18,3) | NO | >= 0 |
| sodio_mg | Sodio (mg) | numeric(18,3) | NO | >= 0 |
| potasio_mg | Potasio (mg) | numeric(18,3) | NO | >= 0 |
| manganeso_mg | Manganeso (mg) | numeric(18,3) | NO | >= 0 |
| cobre_mg | Cobre (mg) | numeric(18,3) | NO | >= 0 |
| selenio_ug | Selenio (µg) | numeric(18,3) | NO | >= 0 |
| omega3_g | Omega-3 (g) | numeric(18,3) | NO | >= 0 |
| tipo_omega3 | Tipo de omega-3 | character varying(255) | NO | [ALA, EPA, DHA, EPA+DHA] |
| grasas_trans_g | Grasas trans (g) | numeric(18,3) | NO | >= 0 |
| polifenoles_mg | Polifenoles (mg) | numeric(18,3) | NO | >= 0 |
| probioticos_billones_ufc | Probióticos (billones de UFC) | numeric(18,3) | NO | >= 0 |

---

### TABLA: ingrediente_etiqueta
**Descripción:** Relación muchos-a-muchos entre ingredientes y etiquetas nutricionales.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id_ingrediente (PK)(FK) | ID del ingrediente | integer(32) | NO | FK a `ingrediente.id` |
| id_etiqueta (PK)(FK) | ID de la etiqueta nutricional | integer(32) | NO | FK a `etiqueta_nutricional.id` |

---

### TABLA: ingrediente_sinonimo
**Descripción:** Nombres alternativos o sinónimos para ingredientes.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del sinónimo | bigint(64) | NO | Entero positivo autogenerado |
| id_ingrediente (FK) | ID del ingrediente | integer(32) | NO | FK a `ingrediente.id` |
| sinonimo | Nombre alternativo del ingrediente | character varying(255) | NO | [A-Z\|a-z\| espacios] - Nombre alternativo |

---

### TABLA: ingrediente_nutriente
**Descripción:** Relación entre ingredientes y nutrientes con valor por 100g (modelo flexible).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del registro | bigint(64) | NO | Entero positivo autogenerado |
| id_ingrediente (FK) | ID del ingrediente | integer(32) | NO | FK a `ingrediente.id` |
| id_nutriente (FK) | ID del nutriente | integer(32) | NO | FK a `nutriente.id` |
| valor_por_100g | Cantidad del nutriente por 100g | numeric(18,8) | NO | >= 0 |

---

### TABLA: metrica_def
**Descripción:** Definición de métricas utilizadas para medir ingredientes (tazas, cucharadas, etc.).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la métrica | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre de la métrica | character varying(160) | NO | [taza, cucharada, cucharadita, unidad, gramo, etc.] |
| formula_referencia | Fórmula o referencia de conversión | text | NO | Expresión de conversión a gramos |
| unidad_medida | Unidad de medida base | character varying(30) | NO | [g, ml, unidad] |
| activa | Indica si la métrica está activa | boolean | NO | [true \| false] - Default: true |

---

### TABLA: ingrediente_metrica
**Descripción:** Valores de conversión de métricas aplicadas a ingredientes específicos.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del registro | bigint(64) | NO | Entero positivo autogenerado |
| id_ingrediente (FK) | ID del ingrediente | integer(32) | NO | FK a `ingrediente.id` |
| id_metrica (FK) | ID de la métrica | integer(32) | NO | FK a `metrica_def.id` |
| valor_numerico | Valor numérico de conversión | numeric(18,8) | NO | Número positivo de conversión a gramos |

---

### TABLA: clasificacion_nutriente
**Descripción:** Clasificación de nutrientes (macronutrientes, micronutrientes, etc.).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la clasificación | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre de la clasificación | character varying(100) | NO | [Macronutriente, Vitamina, Mineral, Oligoelemento, etc.] |

---

### TABLA: nutriente
**Descripción:** Catálogo de nutrientes con su unidad de medida.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del nutriente | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del nutriente | character varying(140) | NO | [Proteínas, Carbohidratos, Vitamina C, Calcio, etc.] |
| unidad_medida | Unidad de medida del nutriente | character varying(30) | NO | [g, mg, µg, kcal, UFC] |
| id_clasificacion (FK) | Clasificación del nutriente | integer(32) | SI | FK a `clasificacion_nutriente.id` |
| activo | Indica si el nutriente está activo | boolean | NO | [true \| false] - Default: true |

---

### TABLA: etiqueta_nutricional
**Descripción:** Etiquetas nutricionales para clasificar ingredientes y recetas (ej: "Alto en fibra", "Sin gluten", "Fuente de calcio").

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la etiqueta | integer(32) | NO | Entero positivo autogenerado |
| nombre_visible | Nombre visible de la etiqueta | character varying(160) | NO | Texto descriptivo para mostrar al usuario |
| descripcion | Descripción detallada de la etiqueta | text | SI | Texto explicativo |
| created_at | Fecha de creación | timestamp with time zone | SI | Default: `now()` |
| codigo | Código interno de la etiqueta | text | SI | Código alfanumérico único para referencia interna |

---

### TABLA: tipo_plato
**Descripción:** Clasificación de tipos de plato (entrada, plato fuerte, postre, etc.).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del tipo de plato | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del tipo de plato | character varying(100) | NO | [Entrada, Plato fuerte, Acompañamiento, Postre, Bebida] |

---

### TABLA: momento_comida
**Descripción:** Momentos del día para las comidas (desayuno, almuerzo, cena, snacks).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del momento | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del momento de comida | character varying(100) | NO | [Desayuno, Snack mañana, Almuerzo, Snack tarde, Cena] |
| orden | Orden de aparición en el día | integer(32) | SI | [1-5] - Define secuencia |
| hora_inicio | Hora de inicio recomendada | time without time zone | SI | Formato: HH:24:MI |
| hora_fin | Hora de fin recomendada | time without time zone | SI | Formato: HH:24:MI |
| obligatorio | Indica si el momento es obligatorio | boolean | SI | [true \| false] - Default: false |
| activo | Indica si el momento está activo | boolean | SI | [true \| false] - Default: true |
| color | Color representativo para UI | character varying(7) | SI | Código hex: #RRGGBB - Default: '#4CAF50' |

---

### TABLA: momento_tipo_plato_factible
**Descripción:** Relación entre momentos de comida y tipos de plato factibles para ese momento.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único | bigint(64) | NO | Entero positivo autogenerado |
| id_momento (FK) | ID del momento de comida | integer(32) | NO | FK a `momento_comida.id` |
| id_tipo_plato (FK) | ID del tipo de plato | integer(32) | NO | FK a `tipo_plato.id` |
| created_at | Fecha de creación | timestamp with time zone | NO | Default: `now()` |
| updated_at | Fecha de modificación | timestamp with time zone | NO | Default: `now()` |

---

### TABLA: receta
**Descripción:** Catálogo de recetas del sistema.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la receta | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre de la receta | character varying(150) | NO | [A-Z\|a-z\| espacio] - Nombre descriptivo |
| porciones | Número de porciones que rinde | integer(32) | NO | Entero positivo - Default: 1 |
| activa | Indica si la receta está activa | boolean | NO | [true \| false] - Default: true |
| created_at | Fecha de creación | timestamp without time zone | NO | Default: `now()` |
| updated_at | Fecha de modificación | timestamp without time zone | NO | Default: `now()` |
| descripcion | Descripción corta de la receta | text | SI | Texto breve descriptivo |
| descripcion_larga | Descripción detallada de la receta | text | SI | Texto extenso |
| dificultad | Nivel de dificultad de la receta | text | SI | ['Fácil' \| 'Media' \| 'Difícil'] - CHECK constraint |
| tiempo_preparacion_min | Tiempo de preparación en minutos | integer(32) | SI | Entero >= 0 - Default: 0 |
| tiempo_coccion_min | Tiempo de cocción en minutos | integer(32) | SI | Entero >= 0 - Default: 0 |
| imagen_url | URL de la imagen de la receta | text | SI | URL de imagen |
| categoria | Categoría de la receta | text | SI | Texto clasificatorio |
| subcategoria | Subcategoría de la receta | text | SI | Texto subclasificatorio |
| tiempo_total_min | Tiempo total estimado en minutos | integer(32) | SI | Entero >= 0 |
| calorias_por_porcion | Calorías calculadas por porción | numeric(10,2) | SI | >= 0 - Default: 0 |

---

### TABLA: receta_ingrediente
**Descripción:** Ingredientes que componen una receta con sus cantidades.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del registro | bigint(64) | NO | Entero positivo autogenerado |
| id_receta (FK) | ID de la receta | integer(32) | NO | FK a `receta.id` |
| id_ingrediente (FK) | ID del ingrediente | integer(32) | NO | FK a `ingrediente.id` |
| cantidad_visual | Cantidad para mostrar al usuario | numeric(10,2) | SI | Número positivo |
| unidad_visual | Unidad de medida para mostrar | character varying(50) | SI | [tazas, cucharadas, unidades, g, ml] |
| peso_en_gramos | Cantidad en gramos para cálculos nutricionales | numeric(12,4) | NO | Número positivo |
| es_principal | Indica si es ingrediente principal | boolean | NO | [true \| false] - Default: false |
| observaciones | Observaciones sobre el ingrediente | text | SI | Notas adicionales |

---

### TABLA: receta_paso
**Descripción:** Pasos de preparación de una receta.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del paso | integer(32) | NO | Entero positivo autogenerado |
| id_receta (FK) | ID de la receta | integer(32) | SI | FK a `receta.id` |
| numero_paso | Número de orden del paso | integer(32) | NO | Entero positivo secuencial |
| descripcion | Descripción del paso | text | NO | Instrucción detallada |
| tiempo_estimado | Tiempo estimado para el paso | text | SI | [5 minutos, 10 minutos, etc.] |
| nota_adicional | Nota adicional sobre el paso | text | SI | Consejo o advertencia |

---

### TABLA: receta_etiqueta
**Descripción:** Relación muchos-a-muchos entre recetas y etiquetas nutricionales.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del registro | integer(32) | NO | Entero positivo autogenerado |
| id_receta (FK) | ID de la receta | integer(32) | NO | FK a `receta.id` |
| id_etiqueta (FK) | ID de la etiqueta nutricional | integer(32) | NO | FK a `etiqueta_nutricional.id` |
| created_at | Fecha de creación | timestamp without time zone | SI | Default: `CURRENT_TIMESTAMP` |

---

### TABLA: receta_momento
**Descripción:** Asociación de recetas con momentos de comida (desayuno, almuerzo, etc.).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id_receta (PK)(FK) | ID de la receta | integer(32) | NO | FK a `receta.id` |
| id_momento (PK)(FK) | ID del momento de comida | integer(32) | NO | FK a `momento_comida.id` |

---

### TABLA: receta_tipo_plato
**Descripción:** Asociación de recetas con tipos de plato.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id_receta (PK)(FK) | ID de la receta | integer(32) | NO | FK a `receta.id` |
| id_tipo_plato (PK)(FK) | ID del tipo de plato | integer(32) | NO | FK a `tipo_plato.id` |

---

### TABLA: receta_imagen
**Descripción:** Imágenes asociadas a recetas.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la imagen | bigint(64) | NO | Entero positivo autogenerado |
| id_receta (FK) | ID de la receta asociada | integer(32) | NO | FK a `receta.id` |
| imagen_url | URL de la imagen | text | NO | URL válida de imagen |

---

### TABLA: receta_nutriente_calculado
**Descripción:** Nutrientes calculados para una receta (a partir de la suma de sus ingredientes).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del registro | bigint(64) | NO | Entero positivo autogenerado |
| id_receta (FK) | ID de la receta | integer(32) | NO | FK a `receta.id` |
| id_nutriente (FK) | ID del nutriente | integer(32) | NO | FK a `nutriente.id` |
| valor_total | Valor total del nutriente en la receta completa | numeric(18,8) | NO | >= 0 |
| valor_por_porcion | Valor del nutriente por porción | numeric(18,8) | NO | >= 0 |

---

### TABLA: regla_menu_combinacion
**Descripción:** Reglas que definen combinaciones de platillos permitidas para menús.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la regla | bigint(64) | NO | Entero positivo autogenerado |
| id_momento (FK) | ID del momento de comida | integer(32) | NO | FK a `momento_comida.id` |
| rol | Rol al que aplica la combinación | text | NO | ['desayuno', 'almuerzo', 'cena', 'snack'] |
| platillos | Configuración JSON de platillos permitidos | jsonb | NO | Default: '[]' - Estructura JSON |
| platillos_key | Clave identificadora de la combinación | text | NO | Texto único |
| activo | Indica si la regla está activa | boolean | NO | [true \| false] - Default: true |
| created_at | Fecha de creación | timestamp with time zone | NO | Default: `now()` |
| updated_at | Fecha de modificación | timestamp with time zone | NO | Default: `now()` |

---

### TABLA: regla_menu_combinacion_condicion
**Descripción:** Condiciones asociadas a las reglas de combinación de menús.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id_regla_menu_combinacion (PK)(FK) | ID de la regla de combinación | bigint(64) | NO | FK a `regla_menu_combinacion.id` |
| id_condicion_nutricional (PK) | ID de la condición nutricional | integer(32) | NO | FK a condición nutricional |

---

### TABLA: vista_recetas_detalle (VIEW)
**Descripción:** Vista detallada de recetas con información agregada de ingredientes, nutrientes y clasificaciones.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id | ID de la receta | integer(32) | SI | FK a receta |
| nombre | Nombre de la receta | character varying(150) | SI | Nombre descriptivo |
| imagen_url | URL de la imagen | text | SI | URL |
| tiempo_total_min | Tiempo total en minutos | integer(32) | SI | Entero positivo |
| dificultad | Nivel de dificultad | text | SI | ['Fácil' \| 'Media' \| 'Difícil'] |
| calorias_por_porcion | Calorías por porción | numeric(10,2) | SI | >= 0 |
| activa | Indica si está activa | boolean | SI | [true \| false] |
| calorias_totales | Calorías totales de la receta | numeric | SI | >= 0 |
| proteinas_totales | Proteínas totales | numeric | SI | >= 0 |
| ingredientes_ids | IDs de ingredientes | ARRAY | SI | Lista de IDs |
| subgrupos_ids | IDs de subgrupos alimentarios | ARRAY | SI | Lista de IDs |
| grupos_ids | IDs de grupos alimentarios | ARRAY | SI | Lista de IDs |
| etiquetas_codigos | Códigos de etiquetas | ARRAY | SI | Lista de códigos |
| ingredientes_nombres | Nombres de ingredientes | ARRAY | SI | Lista de nombres |
| tipos_plato_ids | IDs de tipos de plato | ARRAY | SI | Lista de IDs |
| momentos_ids | IDs de momentos de comida | ARRAY | SI | Lista de IDs |

---

## ESQUEMA: interaccion

Gestiona toda la interacción entre pacientes y el sistema: planes nutricionales, evaluaciones de recetas, preferencias y recomendaciones puntuales.

---

### TABLA: catalogo_estado_consumo
**Descripción:** Catálogo de estados de consumo para seguimiento de plan items.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del estado | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del estado | character varying(20) | NO | [Consumido, No consumido, Reemplazado, Parcial] |

---

### TABLA: catalogo_estado_plan
**Descripción:** Catálogo de estados de un plan nutricional.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del estado | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del estado | character varying(20) | NO | [Activo, Completado, Cancelado, Pausado] |

---

### TABLA: catalogo_motivo_rechazo
**Descripción:** Catálogo de motivos por los que un paciente rechaza una receta.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del motivo | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del motivo | character varying(100) | NO | [No me gusta, Alergia, Preferencia, Otro] |

---

### TABLA: catalogo_origen_plan
**Descripción:** Catálogo de orígenes de un plan nutricional.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del origen | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del origen | character varying(20) | NO | [Manual, Automático, Plantilla, Inteligente] |

---

### TABLA: catalogo_tipo_plan
**Descripción:** Catálogo de tipos de plan nutricional.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del tipo | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del tipo | character varying(20) | NO | [Semanal, Quincenal, Mensual, Personalizado] |

---

### TABLA: plan_nutricional
**Descripción:** Planes nutricionales asignados a pacientes.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del plan | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente | uuid | NO | UUID - FK a `paciente.id` |
| id_tipo_plan (FK) | ID del tipo de plan | integer(32) | NO | FK a `catalogo_tipo_plan.id` |
| id_origen_plan (FK) | ID del origen del plan | integer(32) | NO | FK a `catalogo_origen_plan.id` |
| id_estado_plan (FK) | ID del estado del plan | integer(32) | NO | FK a `catalogo_estado_plan.id` |
| es_plantilla | Indica si es una plantilla reutilizable | boolean | NO | [true \| false] - Default: false |
| comidas_por_dia | Número de comidas por día | integer(32) | NO | Entero positivo |
| fecha_inicio | Fecha de inicio del plan | date | NO | Formato: YYYY-MM-DD |
| fecha_fin | Fecha de fin del plan | date | NO | Formato: YYYY-MM-DD |
| creado_por | ID del usuario que creó el plan | uuid | SI | UUID del profesional |
| vigente | Indica si el plan está vigente | boolean | NO | [true \| false] - Default: true |
| created_at | Fecha de creación | timestamp without time zone | NO | Default: `now()` |

---

### TABLA: plan_item
**Descripción:** Items (comidas) individuales dentro de un plan nutricional.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del item | bigint(64) | NO | Entero positivo autogenerado |
| id_plan (FK) | ID del plan al que pertenece | bigint(64) | NO | FK a `plan_nutricional.id` |
| fecha_programada | Fecha programada para este item | date | NO | Formato: YYYY-MM-DD |
| id_momento | ID del momento de comida | integer(32) | NO | FK a `momento_comida.id` |
| id_receta | ID de la receta asignada | integer(32) | NO | FK a `receta.id` |
| energia_objetivo_kcal | Objetivo de energía en kcal | numeric(12,2) | SI | >= 0 |
| proteina_objetivo_g | Objetivo de proteína en gramos | numeric(12,2) | SI | >= 0 |
| consumida | Indica si fue consumida | boolean | SI | [true \| false] - Default: false |

---

### TABLA: seguimiento_plan_item
**Descripción:** Seguimiento del consumo de cada item del plan (reemplazos, cumplimiento).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del seguimiento | bigint(64) | NO | Entero positivo autogenerado |
| id_plan_item (FK) | ID del plan item | bigint(64) | NO | FK a `plan_item.id` |
| id_estado_consumo (FK) | ID del estado de consumo | integer(32) | NO | FK a `catalogo_estado_consumo.id` |
| id_receta_reemplazo | ID de la receta de reemplazo | integer(32) | SI | FK a `receta.id` |
| fecha_consumo | Fecha y hora de consumo | timestamp without time zone | SI | Formato: YYYY-MM-DD HH:24:MI:SS |
| observacion | Observación sobre el consumo | text | SI | Texto libre |

---

### TABLA: evaluacion_receta
**Descripción:** Evaluaciones (calificaciones) de recetas realizadas por pacientes.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la evaluación | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente que evalúa | uuid | NO | UUID - FK a `paciente.id` |
| id_receta | ID de la receta evaluada | integer(32) | NO | FK a `receta.id` |
| estrellas | Calificación en estrellas | integer(32) | NO | [1 - 5] - CHECK: estrellas >= 1 AND estrellas <= 5 |
| comentario | Comentario de la evaluación | text | SI | Texto libre |
| id_motivo_rechazo (FK) | Motivo si la receta fue rechazada | integer(32) | SI | FK a `catalogo_motivo_rechazo.id` |
| origen_evaluacion | Origen de la evaluación | character varying(20) | NO | [plan, recomendacion, manual] |
| created_at | Fecha de creación | timestamp without time zone | NO | Default: `now()` |

---

### TABLA: preferencia_paciente
**Descripción:** Preferencias de pacientes sobre subgrupos alimentarios.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la preferencia | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente | uuid | NO | UUID - FK a `paciente.id` |
| id_subgrupo_alimentario | ID del subgrupo alimentario | integer(32) | NO | FK a `subgrupo_alimentario.id` |
| created_at | Fecha de creación | timestamp with time zone | SI | Default: `now()` |

---

### TABLA: preferencia_receta
**Descripción:** Preferencias de pacientes sobre recetas específicas (puntaje de ajuste).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente | uuid | NO | UUID - FK a `paciente.id` |
| id_receta | ID de la receta | integer(32) | NO | FK a `receta.id` |
| puntaje_ajuste | Puntaje de ajuste/preferencia | numeric(10,2) | NO | Número que representa nivel de preferencia |
| ultima_actualizacion | Última actualización | timestamp without time zone | NO | Default: `now()` |

---

### TABLA: recomendacion_puntual
**Descripción:** Recomendaciones puntuales de recetas a pacientes en un momento dado.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único | bigint(64) | NO | Entero positivo autogenerado |
| id_paciente | ID del paciente | uuid | NO | UUID - FK a `paciente.id` |
| id_momento | ID del momento de comida | integer(32) | SI | FK a `momento_comida.id` |
| id_receta | ID de la receta recomendada | integer(32) | NO | FK a `receta.id` |
| fecha_solicitud | Fecha de solicitud | timestamp without time zone | NO | Default: `now()` |
| resultado_consumo | Resultado del consumo | character varying(20) | SI | [aceptado, rechazado, pendiente] |
| calificacion_estrellas | Calificación si fue aceptada | integer(32) | SI | [1-5] |
| id_motivo_rechazo (FK) | Motivo de rechazo | integer(32) | SI | FK a `catalogo_motivo_rechazo.id` |

---

## ESQUEMA: heuristico

Motor de reglas heurísticas que determina acciones a tomar basadas en condiciones específicas. Se utiliza para la lógica de negocio de planes nutricionales y acciones automáticas.

---

### TABLA: catalogo_accion
**Descripción:** Catálogo de acciones posibles del sistema.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la acción | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre de la acción | character varying(50) | NO | [bloquear, permitir, recomendar, sugerir, alertar] |
| peso_puntaje | Peso o puntaje asociado a la acción | integer(32) | SI | Entero relativo para ponderación |

---

### TABLA: catalogo_objetivo_regla
**Descripción:** Catálogo de objetivos de las reglas (a qué apunta la regla).

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del objetivo | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del objetivo | character varying(80) | NO | [ingrediente, grupo_alimentario, subgrupo, etiqueta, receta] |

---

### TABLA: catalogo_tipo_condicion
**Descripción:** Catálogo de tipos de condición para las reglas.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del tipo | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre del tipo | character varying(60) | NO | [alergia, restriccion, diagnostico, preferencia, nutricional] |

---

### TABLA: condicion
**Descripción:** Condiciones médicas/nutricionales que activan reglas.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la condición | integer(32) | NO | Entero positivo autogenerado |
| nombre | Nombre de la condición | character varying(150) | NO | [Artritis Reumatoide, Lupus, Diabetes, Hipertensión, etc.] |
| id_tipo_condicion (FK) | Tipo de condición | integer(32) | NO | FK a `catalogo_tipo_condicion.id` |
| descripcion | Descripción detallada | text | SI | Texto explicativo |
| activa | Indica si la condición está activa | boolean | NO | [true \| false] - Default: true |
| dias_duracion_estandar | Duración estándar en días | integer(32) | SI | Default: 3 |
| z_min | Valor Z-score mínimo (referencia OMS) | numeric(6,2) | SI | Valor Z-score |
| z_max | Valor Z-score máximo (referencia OMS) | numeric(6,2) | SI | Valor Z-score |
| incluye_min | Incluye el valor mínimo en el rango | boolean | SI | [true \| false] - Default: false |
| incluye_max | Incluye el valor máximo en el rango | boolean | SI | [true \| false] - Default: false |
| orden_oms | Orden de evaluación OMS | smallint(16) | SI | Entero pequeño para ordenamiento |
| indicador_id | ID del indicador OMS asociado | integer(32) | SI | FK a indicador OMS |
| indicador_codigo | Código del indicador OMS | character varying(100) | SI | Código de referencia |
| edad_min_meses | Edad mínima en meses para aplicar | integer(32) | SI | >= 0 |
| edad_max_meses | Edad máxima en meses para aplicar | integer(32) | SI | >= 0 |
| nivel_alerta | Nivel de alerta de la condición | character varying(50) | SI | [Verde, Amarillo, Rojo] |
| color_alerta | Color representativo de alerta | character varying(20) | SI | Código hex o nombre de color |

---

### TABLA: regla
**Descripción:** Reglas heurísticas que definen acciones basadas en condiciones, apuntando a ingredientes, grupos, subgrupos, etiquetas o recetas.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la regla | bigint(64) | NO | Entero positivo autogenerado |
| id_accion (FK) | Acción a ejecutar | integer(32) | NO | FK a `catalogo_accion.id` |
| id_tipo_objetivo (FK) | Tipo de objetivo de la regla | integer(32) | NO | FK a `catalogo_objetivo_regla.id` |
| id_ingrediente | Ingrediente objetivo (si aplica) | integer(32) | SI | FK a `ingrediente.id` |
| id_grupo_alimentario | Grupo alimentario objetivo (si aplica) | integer(32) | SI | FK a `grupo_alimentario.id` |
| id_etiqueta | Etiqueta nutricional objetivo (si aplica) | integer(32) | SI | FK a `etiqueta_nutricional.id` |
| mensaje_error | Mensaje de error o advertencia | text | SI | Texto para mostrar al usuario |
| origen_regla | Origen de la regla | character varying(20) | NO | [automatico, manual, sistema] |
| created_by | ID del usuario que creó la regla | uuid | SI | UUID del usuario |
| created_at | Fecha de creación | timestamp without time zone | NO | Default: `now()` |
| id_subgrupo_alimentario | Subgrupo alimentario objetivo (si aplica) | integer(32) | SI | FK a `subgrupo_alimentario.id` |
| id_receta | Receta objetivo (si aplica) | integer(32) | SI | FK a `receta.id` |
| es_estricta | Indica si la regla es estricta (no permite excepciones) | boolean | NO | [true \| false] - Default: false |

**CHECK:** La regla debe apuntar exactamente a UN objetivo: (ingrediente + subgrupo + grupo + etiqueta + receta) = 1

---

### TABLA: condicion_regla
**Descripción:** Relación muchos-a-muchos entre condiciones y reglas.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la relación | bigint(64) | NO | Entero positivo autogenerado |
| id_condicion (FK) | ID de la condición | integer(32) | NO | FK a `condicion.id` |
| id_regla (FK) | ID de la regla | bigint(64) | NO | FK a `regla.id` |

---

## ESQUEMA: referencia

Tablas de referencia basadas en estándares de la OMS (Organización Mundial de la Salud) para evaluación del estado nutricional mediante puntuaciones Z y percentiles.

---

### TABLA: condicion (referencia)
**Descripción:** Condiciones médicas de referencia con clasificación por tipo y grupo diagnóstico.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la condición | integer(32) | NO | Entero positivo |
| nombre | Nombre de la condición | text | NO | Nombre estándar |
| tipo | Tipo de condición | text | NO | [nutricional, reumatica, alergica, metabolica] |
| edad_uso | Rango de edad sugerido para uso del indicador | text | SI | Ej: "0-60 meses", "5-19 años" |
| grupo_diagnostico | Grupo diagnóstico al que pertenece | text | NO | [desnutricion, sobrepeso, obesidad, riesgo] |

---

### TABLA: oms_indicador
**Descripción:** Indicadores de crecimiento y nutrición definidos por la OMS.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| ref_code (PK) | Código único de referencia del indicador | text | NO | Código alfanumérico: [wfh, hfa, wfa, bmi, muac] |
| nombre | Nombre del indicador | text | NO | [Weight-for-height, Height-for-age, Weight-for-age, BMI-for-age] |
| estandar | Estándar de referencia | text | NO | [WHO 2006, WHO 2007] |
| edad_aplicable | Rango de edad aplicable | text | NO | [0-5 years, 5-19 years, 0-19 years] |
| clave_busqueda | Clave para búsqueda en tablas | text | NO | Texto clave |
| variable_observada | Variable observada por el indicador | text | NO | [weight, height, bmi] |
| uso_clinico | Uso clínico del indicador | text | NO | Descripción de uso clínico |

---

### TABLA: oms_fuente_archivo
**Descripción:** Registro de archivos fuente OMS importados para referencia.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| source_file (PK) | Nombre del archivo fuente | text | NO | Nombre del archivo CSV/JSON importado |
| ref_code_detectado | Código de referencia detectado en el archivo | text | SI | Código de indicador |
| tipo_tabla | Tipo de tabla en el archivo | text | SI | [zscore, percentil, clasificacion] |
| sexo | Sexo al que aplica | character(1) | SI | ['M' \| 'F'] |
| usado_en_csv_limpio | Archivo CSV limpio generado | text | SI | Nombre del archivo procesado |
| filas_datos | Número de filas de datos importados | integer(32) | SI | Entero positivo |
| columnas | Número de columnas en el archivo | integer(32) | SI | Entero positivo |
| primer_valor_clave | Primer valor de la clave de referencia | text | SI | Texto |
| ultimo_valor_clave | Último valor de la clave de referencia | text | SI | Texto |
| sha256 | Hash SHA256 del archivo para verificación | text | SI | Hash hexadecimal |
| nota | Nota adicional sobre el archivo | text | SI | Texto libre |

---

### TABLA: oms_referencia_zscore
**Descripción:** Tabla de referencia de Z-scores de la OMS para evaluación nutricional.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único | bigint(64) | NO | Entero positivo autogenerado |
| ref_code (FK) | Código del indicador OMS | text | NO | FK a `oms_indicador.ref_code` |
| sexo | Sexo | character(1) | NO | ['M' \| 'F'] - CHECK constraint |
| edad_meses | Edad en meses | numeric(8,3) | SI | >= 0 |
| edad_dias | Edad en días | integer(32) | SI | >= 0 |
| medida_cm | Medida en centímetros | numeric(6,2) | SI | >= 0 |
| l | Parámetro Lambda (Box-Cox) | numeric(14,7) | NO | Valor estadístico |
| m | Parámetro Mediana | numeric(14,7) | NO | Valor estadístico |
| s | Parámetro Sigma (Coeficiente de variación) | numeric(14,7) | NO | Valor estadístico |
| stdev | Desviación estándar | numeric(14,7) | SI | Valor estadístico |
| sd5neg | -5 Desviaciones estándar | numeric(14,3) | SI | Valor Z = -5 |
| sd4neg | -4 Desviaciones estándar | numeric(14,3) | SI | Valor Z = -4 |
| sd3neg | -3 Desviaciones estándar | numeric(14,3) | SI | Valor Z = -3 |
| sd2neg | -2 Desviaciones estándar | numeric(14,3) | SI | Valor Z = -2 |
| sd1neg | -1 Desviación estándar | numeric(14,3) | SI | Valor Z = -1 |
| sd0 | Mediana (0 Desviaciones estándar) | numeric(14,3) | SI | Valor Z = 0 |
| sd1 | +1 Desviación estándar | numeric(14,3) | SI | Valor Z = +1 |
| sd2 | +2 Desviaciones estándar | numeric(14,3) | SI | Valor Z = +2 |
| sd3 | +3 Desviaciones estándar | numeric(14,3) | SI | Valor Z = +3 |
| sd4 | +4 Desviaciones estándar | numeric(14,3) | SI | Valor Z = +4 |
| source_file | Archivo fuente de origen | text | NO | FK a `oms_fuente_archivo.source_file` |

---

### TABLA: oms_referencia_percentil
**Descripción:** Tabla de referencia de percentiles de la OMS para evaluación nutricional.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único | bigint(64) | NO | Entero positivo autogenerado |
| ref_code (FK) | Código del indicador OMS | text | NO | FK a `oms_indicador.ref_code` |
| sexo | Sexo | character(1) | NO | ['M' \| 'F'] - CHECK constraint |
| edad_meses | Edad en meses | numeric(8,3) | SI | >= 0 |
| edad_dias | Edad en días | integer(32) | SI | >= 0 |
| medida_cm | Medida en centímetros | numeric(6,2) | SI | >= 0 |
| l | Parámetro Lambda (Box-Cox) | numeric(14,7) | NO | Valor estadístico |
| m | Parámetro Mediana | numeric(14,7) | NO | Valor estadístico |
| s | Parámetro Sigma (Coeficiente de variación) | numeric(14,7) | NO | Valor estadístico |
| stdev | Desviación estándar | numeric(14,7) | SI | Valor estadístico |
| p01 | Percentil 0.1 | numeric(14,3) | SI | Valor |
| p1 | Percentil 1 | numeric(14,3) | SI | Valor |
| p3 | Percentil 3 | numeric(14,3) | SI | Valor |
| p5 | Percentil 5 | numeric(14,3) | SI | Valor |
| p10 | Percentil 10 | numeric(14,3) | SI | Valor |
| p15 | Percentil 15 | numeric(14,3) | SI | Valor |
| p25 | Percentil 25 | numeric(14,3) | SI | Valor |
| p50 | Percentil 50 | numeric(14,3) | SI | Valor |
| p75 | Percentil 75 | numeric(14,3) | SI | Valor |
| p85 | Percentil 85 | numeric(14,3) | SI | Valor |
| p90 | Percentil 90 | numeric(14,3) | SI | Valor |
| p95 | Percentil 95 | numeric(14,3) | SI | Valor |
| p97 | Percentil 97 | numeric(14,3) | SI | Valor |
| p99 | Percentil 99 | numeric(14,3) | SI | Valor |
| p999 | Percentil 99.9 | numeric(14,3) | SI | Valor |
| source_file | Archivo fuente de origen | text | NO | FK a `oms_fuente_archivo.source_file` |

---

### TABLA: oms_clasificacion_zscore
**Descripción:** Clasificación de diagnósticos nutricionales basados en rangos de Z-score.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| ref_code (PK)(FK) | Código del indicador OMS | text | NO | FK a `oms_indicador.ref_code` |
| edad_meses_min (PK) | Edad mínima en meses para la clasificación | integer(32) | NO | >= 0 |
| edad_meses_max (PK) | Edad máxima en meses para la clasificación | integer(32) | NO | >= 0 |
| z_min | Límite inferior del rango Z-score | numeric(5,2) | SI | Valor Z-score |
| z_max | Límite superior del rango Z-score | numeric(5,2) | SI | Valor Z-score |
| incluye_min | Incluye el límite inferior | boolean | NO | Default: false |
| incluye_max | Incluye el límite superior | boolean | NO | Default: false |
| diagnostico (PK) | Diagnóstico asociado al rango | text | NO | [Normal, Desnutrición aguda moderada, Desnutrición aguda severa, Sobrepeso, Obesidad] |
| condicion_id (FK) | ID de la condición asociada | integer(32) | NO | FK a `condicion.id` |
| grupo_diagnostico | Grupo diagnóstico | text | NO | [desnutricion, sobrepeso, obesidad, normal] |

---

## ESQUEMA: seguridad

Registros de auditoría y errores del sistema para monitoreo y seguridad.

---

### TABLA: log_auditoria
**Descripción:** Registro de auditoría de todas las operaciones CRUD importantes del sistema.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del log | bigint(64) | NO | Entero positivo autogenerado |
| id_usuario | ID del usuario que realizó la acción | uuid | SI | UUID del usuario |
| accion | Acción realizada | character varying(100) | NO | [INSERT, UPDATE, DELETE, SELECT, LOGIN, LOGOUT] |
| esquema_afectado | Esquema de la tabla afectada | character varying(100) | SI | Nombre del esquema |
| tabla_afectada | Nombre de la tabla afectada | character varying(100) | NO | Nombre de la tabla |
| id_registro_afectado | ID del registro afectado | character varying(150) | SI | ID del registro como texto |
| detalle | Detalle de la acción | text | SI | Texto descriptivo |
| payload_anterior | Estado anterior del registro (antes del cambio) | jsonb | SI | Objeto JSON |
| payload_nuevo | Estado nuevo del registro (después del cambio) | jsonb | SI | Objeto JSON |
| fecha_registro | Fecha y hora del registro | timestamp without time zone | NO | Default: `CURRENT_TIMESTAMP` |

---

### TABLA: log_error
**Descripción:** Registro de errores del sistema para diagnóstico.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único del error | bigint(64) | NO | Entero positivo autogenerado |
| modulo | Módulo donde ocurrió el error | character varying(100) | NO | [api, auth, nutricion, plan, recomendacion, etc.] |
| mensaje | Mensaje de error | text | NO | Texto del error |
| stack_trace | Traza completa del error | text | SI | Stack trace detallado |
| payload | Datos adicionales del contexto del error | jsonb | SI | Objeto JSON con contexto |
| fecha_registro | Fecha y hora del error | timestamp without time zone | NO | Default: `CURRENT_TIMESTAMP` |

---

## ESQUEMA: public

Tablas y vistas públicas del sistema.

---

### TABLA: receta_imagen (public)
**Descripción:** Imágenes de recetas en el esquema público.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id (PK) | Identificador único de la imagen | bigint(64) | NO | Entero positivo autogenerado |
| id_receta | ID de la receta | bigint(64) | SI | FK a receta |
| imagen_url | URL de la imagen | text | NO | URL válida |
| created_at | Fecha de creación | timestamp with time zone | SI | Default: `now()` |

---

### VISTAS: v_almuerzo_id, v_cena_id, v_snack_manana_id, v_snack_tarde_id
**Descripción:** Vistas que listan IDs de recetas filtradas por momento de comida.

| Nombre del campo | Descripción | Tipo de dato y tamaño | Permite NULL | Valor permitido del dato |
|-----------------|-------------|----------------------|-------------|------------------------|
| id | ID de la receta | integer(32) | SI | FK a receta.id filtrada por momento |

---

## RELACIONES CLAVE (RESUMEN DE FK)

| Tabla | Columna FK | Tabla Referencia | Columna Referencia |
|-------|-----------|-----------------|-------------------|
| `usuarios.usuario` | id_rol | `usuarios.rol` | id |
| `usuarios.paciente` | id_sexo | `usuarios.catalogo_sexo` | id |
| `usuarios.paciente` | id_canton | `usuarios.canton` | id |
| `usuarios.paciente` | id_parroquia | `usuarios.parroquia` | id |
| `usuarios.parroquia` | id_canton | `usuarios.canton` | id |
| `usuarios.tutor_paciente` | id_usuario_tutor | `usuarios.usuario` | id |
| `usuarios.tutor_paciente` | id_paciente | `usuarios.paciente` | id |
| `usuarios.tutor_paciente` | id_parentesco | `usuarios.parentesco` | id |
| `clinico.restriccion_paciente` | codigo_restriccion | `clinico.catalogo_restriccion_alimentaria` | codigo |
| `clinico.control_condicion_activa` | id_control | `clinico.control_paciente` | id |
| `nutricion.ingrediente` | id_grupo_alimentario | `nutricion.grupo_alimentario` | id |
| `nutricion.ingrediente` | id_subgrupo_alimentario | `nutricion.subgrupo_alimentario` | id |
| `nutricion.subgrupo_alimentario` | id_grupo_alimentario | `nutricion.grupo_alimentario` | id |
| `nutricion.ingrediente_composicion` | id_ingrediente | `nutricion.ingrediente` | id |
| `nutricion.ingrediente_etiqueta` | id_ingrediente | `nutricion.ingrediente` | id |
| `nutricion.ingrediente_etiqueta` | id_etiqueta | `nutricion.etiqueta_nutricional` | id |
| `nutricion.ingrediente_metrica` | id_ingrediente | `nutricion.ingrediente` | id |
| `nutricion.ingrediente_metrica` | id_metrica | `nutricion.metrica_def` | id |
| `nutricion.ingrediente_nutriente` | id_ingrediente | `nutricion.ingrediente` | id |
| `nutricion.ingrediente_nutriente` | id_nutriente | `nutricion.nutriente` | id |
| `nutricion.ingrediente_sinonimo` | id_ingrediente | `nutricion.ingrediente` | id |
| `nutricion.nutriente` | id_clasificacion | `nutricion.clasificacion_nutriente` | id |
| `nutricion.receta_etiqueta` | id_receta | `nutricion.receta` | id |
| `nutricion.receta_etiqueta` | id_etiqueta | `nutricion.etiqueta_nutricional` | id |
| `nutricion.receta_ingrediente` | id_receta | `nutricion.receta` | id |
| `nutricion.receta_ingrediente` | id_ingrediente | `nutricion.ingrediente` | id |
| `nutricion.receta_paso` | id_receta | `nutricion.receta` | id |
| `nutricion.receta_momento` | id_receta | `nutricion.receta` | id |
| `nutricion.receta_momento` | id_momento | `nutricion.momento_comida` | id |
| `nutricion.receta_tipo_plato` | id_receta | `nutricion.receta` | id |
| `nutricion.receta_tipo_plato` | id_tipo_plato | `nutricion.tipo_plato` | id |
| `nutricion.receta_nutriente_calculado` | id_receta | `nutricion.receta` | id |
| `nutricion.receta_nutriente_calculado` | id_nutriente | `nutricion.nutriente` | id |
| `nutricion.receta_imagen` | id_receta | `nutricion.receta` | id |
| `nutricion.momento_tipo_plato_factible` | id_momento | `nutricion.momento_comida` | id |
| `nutricion.momento_tipo_plato_factible` | id_tipo_plato | `nutricion.tipo_plato` | id |
| `nutricion.regla_menu_combinacion` | id_momento | `nutricion.momento_comida` | id |
| `nutricion.regla_menu_combinacion_condicion` | id_regla_menu_combinacion | `nutricion.regla_menu_combinacion` | id |
| `interaccion.plan_nutricional` | id_tipo_plan | `interaccion.catalogo_tipo_plan` | id |
| `interaccion.plan_nutricional` | id_origen_plan | `interaccion.catalogo_origen_plan` | id |
| `interaccion.plan_nutricional` | id_estado_plan | `interaccion.catalogo_estado_plan` | id |
| `interaccion.plan_item` | id_plan | `interaccion.plan_nutricional` | id |
| `interaccion.seguimiento_plan_item` | id_plan_item | `interaccion.plan_item` | id |
| `interaccion.seguimiento_plan_item` | id_estado_consumo | `interaccion.catalogo_estado_consumo` | id |
| `interaccion.evaluacion_receta` | id_motivo_rechazo | `interaccion.catalogo_motivo_rechazo` | id |
| `interaccion.recomendacion_puntual` | id_motivo_rechazo | `interaccion.catalogo_motivo_rechazo` | id |
| `heuristico.condicion` | id_tipo_condicion | `heuristico.catalogo_tipo_condicion` | id |
| `heuristico.regla` | id_accion | `heuristico.catalogo_accion` | id |
| `heuristico.regla` | id_tipo_objetivo | `heuristico.catalogo_objetivo_regla` | id |
| `heuristico.condicion_regla` | id_condicion | `heuristico.condicion` | id |
| `heuristico.condicion_regla` | id_regla | `heuristico.regla` | id |
| `referencia.oms_clasificacion_zscore` | ref_code | `referencia.oms_indicador` | ref_code |
| `referencia.oms_clasificacion_zscore` | condicion_id | `referencia.condicion` | id |
| `referencia.oms_referencia_percentil` | ref_code | `referencia.oms_indicador` | ref_code |
| `referencia.oms_referencia_zscore` | ref_code | `referencia.oms_indicador` | ref_code |

---

## RESUMEN DE ESQUEMAS Y TABLAS

| Esquema | Tablas | Tablas (Vista) | Propósito |
|---------|--------|----------------|-----------|
| `usuarios` | 7 | 1 | Gestión de usuarios, pacientes, tutores, roles y ubicaciones |
| `clinico` | 8 | 1 | Datos clínicos: diagnósticos, alergias, controles, restricciones |
| `nutricion` | 17 | 1 | Catálogo nutricional completo: ingredientes, recetas, nutrientes |
| `interaccion` | 10 | 0 | Planes nutricionales, evaluaciones, preferencias |
| `heuristico` | 6 | 0 | Motor de reglas heurísticas |
| `referencia` | 6 | 0 | Estándares OMS de evaluación nutricional |
| `seguridad` | 2 | 0 | Auditoría y registro de errores |
| `public` | 5 | 4 | Tablas y vistas públicas |
| **TOTAL** | **61** | **7** | **68 objetos en total** |

---

*Documentación generada el: 08/06/2026*
*Proyecto: Reuma Nutri - Sistema de Gestión Nutricional para Enfermedades Reumáticas*
*Base de datos: Supabase (PostgreSQL 17.6)*
