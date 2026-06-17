import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:intl/date_symbol_data_local.dart";

import "core/config/app_config.dart";

Future<void> bootstrapApp(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Ejecutamos las inicializaciones críticas en paralelo sin bloquear el arranque visual
  final initTasks = Future.wait([
    initializeDateFormatting('es_EC', null),
    if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty)
      Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      ),
  ]);

  if (AppConfig.supabaseUrl.isEmpty || AppConfig.supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  // Lanzamos la app inmediatamente
  runApp(ProviderScope(child: app));
  
  // Las tareas de fondo pueden terminar después de que la UI ya es visible
  await initTasks;
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
