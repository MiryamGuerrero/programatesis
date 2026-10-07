import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../services/notification_service.dart";
import "auth_providers.dart";
import "patient_providers.dart";
import "role_switch_provider.dart";

/// Invalida y reinicia todo el estado asociado al usuario previo
/// para garantizar que un nuevo usuario que inicie sesión en el mismo
/// dispositivo nunca vea datos ni cachés de la sesión anterior.
void clearUserSessionState(WidgetRef ref) {
  _performCleanup(ref.read, ref.invalidate);
}

void clearUserSessionStateWithRef(Ref ref) {
  _performCleanup(ref.read, ref.invalidate);
}

void _performCleanup(
  T Function<T>(ProviderListenable<T>) read,
  void Function(ProviderOrFamily) invalidate,
) {
  // 1. Limpiar identificadores y overrides del usuario previo
  try {
    read(selectedPatientIdProvider.notifier).state = null;
  } catch (_) {}
  try {
    read(activeRoleOverrideProvider.notifier).state = null;
  } catch (_) {}
  try {
    read(miPerfilOverrideProvider.notifier).state = null;
  } catch (_) {}
  try {
    read(targetRoleProvider.notifier).state = null;
  } catch (_) {}
  try {
    invalidate(roleSwitchLoadingProvider);
  } catch (_) {}

  // 2. Invalidar proveedores de pacientes y datos clínicos
  invalidate(misPacientesProvider);
  invalidate(patientsListProvider);
  invalidate(usersListProvider);
  invalidate(miPerfilProvider);
  invalidate(appRoleProvider);
  invalidate(tipSaludableProvider);

  // 3. Limpiar catálogos cacheados en memoria si existieran
  try {
    read(supabaseCrudRepositoryProvider).invalidateCatalogs();
  } catch (_) {}

  // 4. Cancelar notificaciones locales programadas para el usuario anterior
  try {
    read(notificationServiceProvider)
        .cancelarTodasLasNotificaciones()
        .catchError((_) {});
  } catch (_) {}
}
