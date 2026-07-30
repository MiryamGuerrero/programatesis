import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Servicio que captura deep links entrantes en plataformas móviles.
///
/// Expone:
/// - [initialLink]: el URI con el que la app fue lanzada (si la abrió un deep link).
/// - [linkStream]: stream de URIs que llegan mientras la app está en ejecución.
///
/// Solo activo en plataformas nativas (Android / iOS). En web siempre devuelve
/// null / stream vacío porque en web Supabase gestiona el redirect directamente
/// a través de la URL del navegador.
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  final StreamController<Uri> _controller =
      StreamController<Uri>.broadcast();

  Uri? _initialUri;
  bool _initialized = false;

  /// URI con el que la app fue lanzada desde frío. Puede ser null si la app
  /// se abrió normalmente (no desde un deep link).
  Uri? get initialLink => _initialUri;

  /// Stream de URIs entrantes mientras la app está corriendo.
  Stream<Uri> get linkStream => _controller.stream;

  /// Inicializa el servicio. Debe llamarse una sola vez durante el bootstrap.
  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    // Captura el URI inicial (lanzamiento en frío desde deep link).
    try {
      _initialUri = await _appLinks.getInitialLink();
    } catch (_) {
      // Si falla, simplemente no hay URI inicial.
      _initialUri = null;
    }

    // Escucha deep links que llegan mientras la app está corriendo (background).
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _controller.add(uri),
      onError: (_) {}, // Los errores son ignorados silenciosamente.
    );
  }

  /// Libera los recursos. En la práctica, el servicio vive toda la vida de la
  /// app, pero se ofrece para completitud.
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
