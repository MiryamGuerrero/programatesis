# Como abrir la app Tutor en celular

## Opcion A (rapida) - usar web en celular

1. Desde frontend/flutter_app ejecuta:
flutter run -d web-server -t lib/main_tutor_mobile.dart --web-hostname=0.0.0.0 --web-port=8080 --dart-define=SUPABASE_URL=https://yuasobxhctmukvozmrta.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_IDWe5z7tqSdlHW4rixjDfw_vJxoFaAL --dart-define=FASTAPI_BASE_URL=http://192.168.100.12:8000/api/v1

2. En el celular (misma red WiFi), abre:
http://192.168.100.12:8080

3. Inicia sesion Tutor:
- tutor@reumanutri.app
- Tutor2026!

## Opcion B (app movil real Android)

1. Instala Android Studio.
2. Abre SDK Manager y instala Android SDK.
3. En el telefono activa Developer Options + USB debugging.
4. Conecta el telefono por USB y acepta huella RSA.
5. Verifica deteccion:
flutter devices

6. Ejecuta la app movil tutor:
flutter run -d <DEVICE_ID> -t lib/main_tutor_mobile.dart --dart-define=SUPABASE_URL=https://yuasobxhctmukvozmrta.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_IDWe5z7tqSdlHW4rixjDfw_vJxoFaAL --dart-define=FASTAPI_BASE_URL=http://192.168.100.12:8000/api/v1

## Si no aparece el telefono

- Ejecuta flutter doctor
- Ejecuta adb devices
- Instala drivers USB del fabricante (si aplica)
- Cambia modo USB a transferencia de archivos
