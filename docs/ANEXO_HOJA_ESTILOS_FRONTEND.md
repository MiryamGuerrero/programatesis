# Anexo: Hoja de estilos del frontend

## 1. Contexto general

El frontend de ReumaNutri fue desarrollado en Flutter, por lo que no utiliza una hoja de estilos CSS tradicional. La identidad visual se define principalmente mediante el archivo:

`programatesis/frontend/flutter_app/lib/core/theme/app_theme.dart`

Este archivo centraliza el tema visual de la aplicacion mediante `ThemeData`, `ColorScheme`, estilos de botones, campos de texto, tarjetas, barra superior y navegacion. Adicionalmente, los tamanos, espaciados y puntos de quiebre responsivos se encuentran en:

`programatesis/frontend/flutter_app/lib/core/theme/app_sizes.dart`

`programatesis/frontend/flutter_app/lib/core/theme/app_breakpoints.dart`

## 2. Paleta cromatica institucional

La interfaz toma como base una paleta clinica, limpia y moderna, orientada a una aplicacion de soporte nutricional y seguimiento pediatrico-reumatologico. Se priorizan tonos azules para confianza, salud digital y estructura visual; verdes para nutricion, bienestar y acciones positivas; y grises claros para mantener una lectura limpia.

| Uso | Nombre en codigo | Color HEX | Aplicacion |
|---|---:|---:|---|
| Color primario | `azulPrincipal` | `#0171BB` | Botones principales, seleccion de navegacion, iconos activos, estados de foco |
| Color secundario | `verdeSalud` | `#70A81C` | Acciones positivas, botones de creacion, etiquetas de exito, enfasis nutricional |
| Azul oscuro | `azulOscuro` | `#005686` | Titulos, elementos de mayor jerarquia y variantes del azul institucional |
| Fondo general | `grisFondo` / `grisLienzo` | `#F8FAFC` | Fondo principal de pantallas y formularios |
| Superficie elevada | `superficieElevada` | `#FFFFFF` | Tarjetas, app bar, paneles y contenedores |
| Celeste pastel | `pastelCeleste` | `#E0F2FE` | Fondos suaves para seleccion, iconos o secciones informativas |
| Cian limpio | `cianLimpio` | `#CFFAFE` | Apoyo visual en secciones informativas |
| Verde lima | `verdeLima` | `#D9F99D` | Apoyo nutricional y resaltados suaves |
| Naranja alerta | `naranjaAlerta` | `#F59E0B` | Advertencias, validaciones y mensajes preventivos |

Colores complementarios usados en la interfaz:

| Uso | Color HEX |
|---|---:|
| Texto principal | `#1E293B` |
| Texto secundario / iconos inactivos | `#64748B` |
| Texto auxiliar / placeholder | `#94A3B8` |
| Bordes generales | `#CBD5E1` |
| Bordes suaves | `#E2E8F0` |
| Separadores / bordes de tarjetas | `#F1F5F9` |
| Azul de sidebar y marca en shell | `#0068B7` |
| Verde de seleccion en sidebar | `#58A932` |

## 3. Tipografia

La aplicacion usa Google Fonts:

| Fuente | Uso |
|---|---|
| `Lato` | Texto base, parrafos, descripciones y contenido general |
| `Inter` | Encabezados del tema Material 3 y titulos principales |
| `Montserrat` | Componentes destacados, tarjetas KPI, badges, navegacion, marca y rotulos en mayuscula |

Jerarquia recomendada:

| Elemento | Estilo recomendado |
|---|---|
| Titulos principales | Inter / Montserrat, peso 700-800 |
| Subtitulos | Inter, peso 600 |
| Texto de contenido | Lato, peso 400-600 |
| Etiquetas, badges y KPIs | Montserrat, peso 700-800, texto corto |
| Placeholders | Lato o Inter, color `#94A3B8` |

## 4. Componentes visuales principales

### Botones

Los botones siguen Material 3 con forma redondeada tipo pastilla.

| Tipo | Uso | Estilo |
|---|---|---|
| `FilledButton` | Accion principal | Fondo azul o verde, texto blanco, alto aproximado 48 px |
| `ElevatedButton` | Accion destacada | Elevacion ligera, bordes redondeados |
| `OutlinedButton` | Accion secundaria | Borde gris o azul, fondo blanco |

Valores base:

- Padding: 14 px vertical y 24 px horizontal.
- Radio: `StadiumBorder` o radio entre 12 px y 28 px segun el componente.
- Texto: peso bold, tamano aproximado 13-16 px.

### Campos de entrada

Los campos de texto utilizan fondo blanco, bordes suaves y alto nivel de redondez.

- Fondo: `#FFFFFF`.
- Borde normal: `#E2E8F0`.
- Borde enfocado: `#0171BB`, grosor 2 px.
- Radio: 28 px.
- Padding interno: 20 px horizontal y 16 px vertical.
- Placeholder: `#94A3B8`.

### Tarjetas

Las tarjetas son superficies blancas sobre fondo gris claro.

- Fondo: `#FFFFFF`.
- Radio general: 16 px.
- Borde: `#F1F5F9`.
- Elevacion: baja o nula.
- Sombra: suave, generalmente negro con opacidad entre 0.02 y 0.05.

### Tablas y contenedores

Los contenedores de tablas usan una estetica limpia y administrativa:

- Fondo: blanco.
- Radio: 8 px.
- Borde: `#E2E8F0`.
- Sombra ligera.
- Separadores internos: `#F1F5F9`.

### Badges o etiquetas

Los badges se usan para estados como exito, informacion, advertencia o error.

| Estado | Fondo | Texto |
|---|---:|---:|
| Exito | `#DCFCE7` | `#166534` |
| Informacion | `#DBEAFE` | `#1E40AF` |
| Advertencia | `#FEF9C3` | `#854D0E` |
| Error | `#FEE2E2` | `#991B1B` |

## 5. Navegacion y estructura de pantalla

La aplicacion maneja dos patrones de navegacion:

1. En escritorio, usa un layout con encabezado superior y menu lateral.
2. En movil, usa barra de navegacion inferior.

### Encabezado superior

- Fondo: blanco.
- Altura aproximada: 75 px.
- Marca: texto "Nutri" en azul `#0068B7` y "Reuma" en verde `#58A932`.
- Incluye logo, notificaciones, informacion del usuario y boton de cierre de sesion.

### Menu lateral de escritorio

- Fondo: azul institucional `#0068B7`.
- Opcion activa: verde `#58A932`.
- Texto e iconos: blanco.
- Ancho expandido: 280 px.
- Ancho contraido: 85 px.

### Navegacion movil

- Fondo: blanco.
- Indicador activo: azul `#0171BB` con opacidad baja.
- Icono activo: `#0171BB`.
- Icono inactivo: `#64748B`.
- Altura aproximada: 80 px.

## 6. Espaciado, radios y tamanos

Los espaciados se definen en `AppSpacing`:

| Token | Valor |
|---|---:|
| `xs` | 4 px |
| `sm` | 8 px |
| `md` | 16 px |
| `lg` | 24 px |
| `xl` | 32 px |
| `xxl` | 48 px |

Los tamanos base se definen en `AppSizes`:

| Elemento | Valor |
|---|---:|
| Alto de boton | 48 px |
| Alto de boton grande | 56 px |
| Alto de input | 52 px |
| Radio de tarjeta | 16 px |
| Radio de boton | 28 px |
| Radio de input | 28 px |
| Icono pequeno | 18 px |
| Icono mediano | 24 px |
| Icono grande | 32 px |
| Ancho maximo de contenido | 1200 px |
| Ancho maximo de formulario | 500 px |

## 7. Diseno responsivo

Los puntos de quiebre se encuentran en `AppBreakpoints`:

| Pantalla | Ancho |
|---|---:|
| Mobile small | 320 px |
| Mobile | 480 px |
| Tablet | 768 px |
| Desktop | 1024 px |
| Desktop large | 1440 px |

Criterio de uso:

- Menor a 1024 px: se prioriza navegacion inferior y pantallas en una sola columna.
- Desde 1024 px: se activa layout de escritorio con menu lateral.
- El contenido no debe superar 1200 px de ancho para evitar pantallas demasiado extendidas.

## 8. Ubicacion de recursos visuales y mockups

### Imagenes usadas por la aplicacion

Las imagenes que forman parte del frontend deben colocarse en:

`programatesis/frontend/flutter_app/assets/images/`

Cuando una imagen se use dentro de Flutter, debe declararse tambien en:

`programatesis/frontend/flutter_app/pubspec.yaml`

Ejemplo:

```yaml
flutter:
  assets:
    - assets/images/logo 1.webp
    - assets/images/logo sin.webp
    - assets/images/nutri_clinic_hero.webp
```

Formato recomendado:

- Preferir `.webp` para imagenes finales por menor peso.
- Mantener `.png` solo como respaldo o fuente original.
- Usar nombres descriptivos sin tildes.
- Evitar espacios en nombres nuevos; usar guion bajo.

### Mockups para documentacion

Los mockups y capturas para anexos, evidencias o documentacion se ubican actualmente en:

`programatesis/debug/moocks/`

Esta carpeta debe usarse para conservar capturas de pantalla, prototipos, disenos de referencia o imagenes que no necesariamente se cargan dentro de la app.

Uso recomendado:

| Tipo de archivo | Ubicacion |
|---|---|
| Imagen usada por la app | `frontend/flutter_app/assets/images/` |
| Mockup o captura para tesis/documentacion | `debug/moocks/` |
| Documento explicativo del mockup | `docs/` |
| Imagen final optimizada para produccion | `assets/images/*.webp` |

## 9. Criterios para elaborar mockups

Para que los mockups mantengan coherencia con la aplicacion:

- Usar fondo general `#F8FAFC`.
- Usar tarjetas blancas con borde `#F1F5F9` y radio de 16 px.
- Usar azul `#0171BB` para acciones principales.
- Usar verde `#70A81C` o `#58A932` para acciones positivas, seleccion o nutricion.
- Usar texto principal `#1E293B` y texto secundario `#64748B`.
- Mantener estructura de dashboard en escritorio: header superior, sidebar azul y contenido central.
- Mantener estructura movil con app bar superior y navegacion inferior.
- No saturar las pantallas: usar espacios de 16 px, 24 px y 32 px.
- Representar estados importantes: cargando, vacio, error, exito, advertencia y seleccion activa.

## 10. Pantallas sugeridas para incluir en el anexo de mockups

Se recomienda documentar al menos las siguientes vistas:

| Modulo | Mockup recomendado |
|---|---|
| Autenticacion | Login institucional |
| Medico | Gestion de pacientes, expediente, control mensual, alergias/condiciones |
| Nutricionista | Ingredientes, recetas, reglas nutricionales, plan manual |
| Tutor | Inicio, calendario, plan diario, compras, gustos |
| Administracion | Gestion de usuarios y catalogos |
| Componentes | Modal, tabla, formulario, badge, KPI y estado vacio |

## 11. Fragmento base de estilo para documentar

```dart
class AppTema {
  static const Color azulPrincipal = Color(0xFF0171BB);
  static const Color verdeSalud = Color(0xFF70A81C);
  static const Color azulOscuro = Color(0xFF005686);
  static const Color grisFondo = Color(0xFFF8FAFC);
  static const Color grisLienzo = Color(0xFFF8FAFC);
  static const Color pastelCeleste = Color(0xFFE0F2FE);
  static const Color cianLimpio = Color(0xFFCFFAFE);
  static const Color verdeLima = Color(0xFFD9F99D);
  static const Color naranjaAlerta = Color(0xFFF59E0B);
  static const Color superficieElevada = Colors.white;
}
```

Este fragmento resume la base cromatica de la interfaz y puede citarse como la hoja de estilos principal del frontend.

