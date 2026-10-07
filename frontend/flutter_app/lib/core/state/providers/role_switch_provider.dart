import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../shared/models/app_role.dart";
import "auth_providers.dart";
import "patient_providers.dart";

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

final targetRoleProvider = StateProvider<AppRole?>((ref) => null);

class RoleSwitchNotifier extends StateNotifier<bool> {
  RoleSwitchNotifier(this.ref) : super(false);

  final Ref ref;

  Future<void> switchRole(int selectedRolId) async {
    final targetRole = tryParseRole(selectedRolId);
    if (targetRole == null) return;

    final previousRole = ref.read(activeRoleOverrideProvider) ??
        ref.read(appRoleProvider).valueOrNull;
    final previousProfile = ref.read(miPerfilOverrideProvider) ??
        ref.read(miPerfilProvider).valueOrNull;

    if (previousRole == targetRole) return;

    // 1. Cambio INMEDIATO e INSTANTÁNEO de rol y perfil en el estado local
    ref.read(targetRoleProvider.notifier).state = targetRole;
    ref.read(activeRoleOverrideProvider.notifier).state = targetRole;

    if (previousProfile != null) {
      ref.read(miPerfilOverrideProvider.notifier).state = {
        ...previousProfile,
        "id_rol": selectedRolId,
        "rol_nombre": targetRole.label,
      };
    }

    // 2. Invalidar proveedores dependientes del rol anterior para que el nuevo rol cargue datos limpios
    ref.invalidate(misPacientesProvider);
    ref.invalidate(usersListProvider);
    ref.invalidate(patientsListProvider);

    // 3. Persistir en el backend de forma asíncrona y fluida
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.switchActiveRole(selectedRolId);

      // Sincronizar el perfil completo desde el backend
      final freshProfile = await repo.fetchMyProfile();
      if (mounted) {
        ref.read(miPerfilOverrideProvider.notifier).state = freshProfile;
      }
    } catch (e) {
      // Si falla la llamada al backend, revertir al rol anterior
      if (mounted) {
        ref.read(activeRoleOverrideProvider.notifier).state = previousRole;
        ref.read(targetRoleProvider.notifier).state = previousRole;
        ref.read(miPerfilOverrideProvider.notifier).state = previousProfile;
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text("Error al cambiar de rol: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

final roleSwitchLoadingProvider =
    StateNotifierProvider<RoleSwitchNotifier, bool>((ref) {
  return RoleSwitchNotifier(ref);
});
