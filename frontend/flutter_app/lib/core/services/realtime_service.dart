import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../state/app_providers.dart";
import "../../shared/models/app_role.dart";

final realtimeServiceProvider = Provider((ref) => RealtimeService(ref));

class RealtimeService {
  final Ref _ref;
  RealtimeService(this._ref);

  RealtimeChannel? _userChannel;

  void init() {
    final role = _ref.read(appRoleProvider).valueOrNull;
    if (role != AppRole.admin) return;

    final supabase = _ref.read(supabaseClientProvider);

    // 1. Escuchar Nuevos Registros en la tabla usuarios.usuario
    _userChannel = supabase
        .channel('public:usuario')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'usuarios',
          table: 'usuario',
          callback: (payload) {
            final nombre =
                payload.newRecord['nombre_completo'] ?? "Nuevo Usuario";
            final email = payload.newRecord['email'] ?? "";
            final rolId = payload.newRecord['id_rol'];

            String rolDesc = "usuario";
            if (rolId == 1) {
              rolDesc = "Administrador";
            } else if (rolId == 2) {
              rolDesc = "Médico";
            } else if (rolId == 3) {
              rolDesc = "Nutricionista";
            } else if (rolId == 4) {
              rolDesc = "Tutor";
            }

            _ref.read(notificationProvider.notifier).add(
                  "Nuevo Registro Detectado",
                  "Se ha registrado un nuevo $rolDesc: $nombre ($email)",
                  type: NutriNotificationType.info,
                );
          },
        )
        .subscribe();

    // 2. Escuchar Inicios de Sesión (Vía Auth)
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        final email = data.session?.user.email ?? "Desconocido";
        _ref.read(notificationProvider.notifier).add(
              "Inicio de Sesión",
              "El usuario $email ha ingresado al sistema.",
              type: NutriNotificationType.success,
            );
      }
    });
  }

  void dispose() {
    _userChannel?.unsubscribe();
  }
}
