import "package:flutter/foundation.dart";
import "app.dart";
import "bootstrap.dart";
import "tutor_mobile_app.dart";

Future<void> main() async {
  // En dispositivos móviles (Android / iOS) inicia la experiencia móvil para tutores
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await bootstrapApp(const TutorMobileApp());
  } else {
    await bootstrapApp(const ReumaNutriApp());
  }
}
