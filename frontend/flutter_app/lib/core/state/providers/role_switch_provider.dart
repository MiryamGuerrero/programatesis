import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../shared/models/app_role.dart";
import "auth_providers.dart";
import "network_providers.dart";
import "patient_providers.dart";

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

final targetRoleProvider = StateProvider<AppRole?>((ref) => null);

class RoleSwitchNotifier extends StateNotifier<bool> {
  RoleSwitchNotifier(this.ref) : super(false);

  final Ref ref;

  Future<void> switchRole(int selectedRolId) async {
    if (state) return;

    final targetRole = tryParseRole(selectedRolId) ?? AppRole.tutor;
    ref.read(targetRoleProvider.notifier).state = targetRole;
    state = true;

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.switchActiveRole(selectedRolId);

      final client = ref.read(supabaseClientProvider);
      await client.auth.refreshSession();

      // Consultar directamente el nuevo perfil actualizado desde el backend
      final freshProfile = await repo.fetchMyProfile();

      // Actualizar de forma determinista e inmediata el rol y el perfil activos
      ref.read(activeRoleOverrideProvider.notifier).state = targetRole;
      ref.read(miPerfilOverrideProvider.notifier).state = freshProfile;

      // Invalidar listas dependientes del rol anterior
      ref.invalidate(misPacientesProvider);
      ref.invalidate(usersListProvider);
      ref.invalidate(patientsListProvider);

      // Esperar 150ms para que la propagación del nuevo rol y perfil
      // esté completamente asentada antes de liberar la pantalla de carga
      await Future<void>.delayed(const Duration(milliseconds: 150));
    } catch (e) {
      ref.read(activeRoleOverrideProvider.notifier).state = null;
      ref.read(miPerfilOverrideProvider.notifier).state = null;
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Error al cambiar de rol: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      ref.read(targetRoleProvider.notifier).state = null;
      state = false;
    }
  }
}

final roleSwitchLoadingProvider =
    StateNotifierProvider<RoleSwitchNotifier, bool>((ref) {
  return RoleSwitchNotifier(ref);
});
