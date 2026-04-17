# APLICACIÓN WEB LEVANTADA ✅

## Estado Actual

```
Backend FastAPI:
  URL: http://localhost:8000
  Status: ✅ Activo (puerto 8000)
  Endpoints: /health, /api/v1/auth-context, etc.

Frontend Flutter Web:
  Status: ✅ Compilando/Iniciando
  Compilador: Chrome Debug Mode
  DevTools: http://127.0.0.1:50679/lKoue8wOzVM=/devtools/
```

## Acceder a la Aplicación

1. **Espera a que Flutter termine de compilar** (puede tardar 1-2 minutos)
2. **Se abrirá automáticamente en Chrome**
3. **O accede manualmente a**: `http://localhost:3000` o `http://localhost:5173`

## Qué Verificar

### Login
- [ ] Accede con `medico@reumanutri.app` / `password`
- [ ] O prueba con otro usuario:
  - admin@reumanutri.app
  - nutricionista@reumanutri.app
  - tutor@reumanutri.app

### Verificación de Roles
Después de login, deberías ver:

**Si eres Médico:**
- Pacientes y Tutores
- Historia Clínica y Controles
- Diagnóstico e IMC
- Alergias y Condiciones
- Catálogo de Condiciones
- Reglas Médicas
- Consulta y Evolución
- Perfil

**Si eres Nutricionista:**
- Ingredientes
- Recetas
- Plan Manual
- Perfil

**Si eres Admin:**
- Usuarios
- Perfil

**Si eres Tutor:**
- Mi Plan
- Consumo
- Reemplazos
- Calificar
- Perfil

### Pruebas Adicionales
- [ ] Cambia entre módulos usando la navegación lateral
- [ ] Haz logout y login con otro usuario
- [ ] Recarga la página (F5) y verifica que el rol persiste
- [ ] Abre DevTools (F12) y revisa la consola para errores

## Logs en Tiempo Real

El backend mostrará:
```
INFO: GET /api/v1/auth-context
INFO: GET /api/v1/health
```

Flutter mostrará:
```
[hot] reload complete
[debug] Role resuelto: medico
```

## Si hay Problemas

1. **Timeout en login**: Verifica que el backend sigue corriendo en puerto 8000
2. **Rol incorrecto**: Revisa los metadatos en DevTools → Application → LocalStorage
3. **Módulos no aparecen**: Abre la página de Debug (si eres admin)

---

**Aplicación lista para pruebas** ✅
