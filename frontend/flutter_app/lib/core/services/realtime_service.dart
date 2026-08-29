import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../state/app_providers.dart";
import "../../shared/models/app_role.dart";

final realtimeServiceProvider = Provider((ref) => RealtimeService(ref));

class RealtimeService {
  final Ref _ref;
  RealtimeService(this._ref);

  RealtimeChannel? _adminChannel;
  RealtimeChannel? _clinicoChannel;
  RealtimeChannel? _pacienteChannel;
  RealtimeChannel? _nutricionChannel;

  void init() {
    final role = _ref.read(appRoleProvider).valueOrNull;
    if (role == null) return;

    final supabase = _ref.read(supabaseClientProvider);

    if (role == AppRole.admin) {
      // 1. Escuchar Nuevos Registros en la tabla usuarios.usuario
      _adminChannel = supabase
          .channel('public:usuario')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'usuarios',
            table: 'usuario',
            callback: (payload) {
              final nombre = payload.newRecord['nombre_completo'] ?? "Nuevo Usuario";
              final email = payload.newRecord['email'] ?? "";
              final rolId = payload.newRecord['id_rol'];

              String rolDesc = "usuario";
              if (rolId == 1) {
                rolDesc = "Administrador";
              } else if (rolId == 2) {
                rolDesc = "Médico";
              } else if (rolId == 3) {
                rolDesc = "Nutricionista";
              }

              _ref.read(notificationProvider.notifier).add(
                    "Nuevo Registro Detectado",
                    "Se ha registrado un nuevo $rolDesc: $nombre ($email)",
                    type: NutriNotificationType.info,
                  );
            },
          )
          .subscribe();

      // Escuchar Inicios de Sesión
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

    // PACIENTES (Todos los roles, excepto admin)
    if (role == AppRole.medico || role == AppRole.nutricionista) {
      _pacienteChannel = supabase
          .channel('public:paciente')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'usuarios',
            table: 'paciente',
            callback: (payload) {
              final nombre = payload.newRecord['nombre_completo'] ?? "Paciente";
              _ref.read(notificationProvider.notifier).add(
                    "Nuevo paciente registrado",
                    "Se ha ingresado al paciente $nombre al sistema.",
                    type: NutriNotificationType.info,
                  );
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'usuarios',
            table: 'paciente',
            callback: (payload) {
              final nombre = payload.newRecord['nombre_completo'] ?? "Paciente";
              _ref.read(notificationProvider.notifier).add(
                    "Datos actualizados",
                    "Se ha modificado el perfil del paciente $nombre.",
                    type: NutriNotificationType.warning,
                  );
            },
          )
          .subscribe();
    }

    // CONTROLES MÉDICOS (Solo Nutricionista)
    if (role == AppRole.nutricionista) {
      _clinicoChannel = supabase
          .channel('public:control_paciente')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'clinico',
            table: 'control_paciente',
            callback: (payload) async {
              final pacienteId = payload.newRecord['id_paciente'];
              String nombre = "ID $pacienteId";
              try {
                final res = await supabase.schema('usuarios').from('paciente').select('nombre_completo').eq('id', pacienteId).single();
                nombre = res['nombre_completo'] ?? nombre;
              } catch (_) {}
              
              final diag = payload.newRecord['estado_nutricional'] ?? "";
              final isFueraRango = diag.toString().contains("Fuera de rango");
              
              _ref.read(notificationProvider.notifier).add(
                    isFueraRango ? "Evaluación Nutricional Pendiente" : "Control médico finalizado",
                    isFueraRango 
                      ? "El paciente $nombre está fuera de los rangos de la OMS. Requiere evaluación manual."
                      : "El paciente $nombre fue evaluado. Listo para plan nutricional.",
                    type: isFueraRango ? NutriNotificationType.error : NutriNotificationType.success,
                  );
            },
          )
          .subscribe();
    }

    // PLANES NUTRICIONALES (Solo Médico)
    if (role == AppRole.medico) {
      _nutricionChannel = supabase
          .channel('public:plan_nutricional')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'interaccion',
            table: 'plan_nutricional',
            callback: (payload) async {
              final pacienteId = payload.newRecord['id_paciente'];
              String nombre = "ID $pacienteId";
              try {
                final res = await supabase.schema('usuarios').from('paciente').select('nombre_completo').eq('id', pacienteId).single();
                nombre = res['nombre_completo'] ?? nombre;
              } catch (_) {}
              
              _ref.read(notificationProvider.notifier).add(
                    "Plan nutricional asignado",
                    "Se ha creado un plan semanal para el paciente $nombre.",
                    type: NutriNotificationType.success,
                  );
            },
          )
          .subscribe();
    }
  }

  void dispose() {
    _adminChannel?.unsubscribe();
    _pacienteChannel?.unsubscribe();
    _clinicoChannel?.unsubscribe();
    _nutricionChannel?.unsubscribe();
  }
}