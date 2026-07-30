import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/app_config.dart';
import 'core/services/deep_link_service.dart';

Future<void> bootstrapApp(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.supabaseUrl.isEmpty || AppConfig.supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  // Inicializamos el servicio de deep links ANTES de Supabase para capturar
  // el URI inicial (cold start desde un deep link de correo).
  if (!kIsWeb) {
    await DeepLinkService().initialize();
  }

  // Supabase e internacionalización en paralelo.
  // IMPORTANTE: Supabase.initialize() debe completar ANTES de runApp porque
  // los providers acceden a Supabase.instance.client en su construcción.
  // Con PKCE, el initialize también procesa el "code" de la URL (web) o del
  // deep link y emite el AuthChangeEvent correspondiente al stream.
  await Future.wait([
    initializeDateFormatting('es_EC', null),
    Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        // PKCE: el código de autorización viaja en "?code=..." permitiendo
        // que la app lo capture vía deep link en móvil y vía URL en web.
        authFlowType: AuthFlowType.pkce,
      ),
    ),
  ]);

  runApp(ProviderScope(child: app));
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Faltan variables SUPABASE_URL y SUPABASE_ANON_KEY. "
              "Ejecuta Flutter con --dart-define.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
