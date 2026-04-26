import "package:flutter_riverpod/flutter_riverpod.dart";
import "repositorio_tutor.dart";

/// Provider para obtener el plan del día
final planDiarioProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String idPaciente, String fecha})>((ref, arg) async {
  final repo = ref.watch(repositorioTutorProvider);
  return repo.obtenerPlanDiario(arg.idPaciente, arg.fecha);
});

/// Provider para obtener estadísticas de adherencia
final adherenciaProvider = FutureProvider.family<Map<String, dynamic>, ({String idPaciente, int dias})>((ref, arg) async {
  final repo = ref.watch(repositorioTutorProvider);
  return repo.obtenerEstadisticasAdherencia(arg.idPaciente, dias: arg.dias);
});

/// Notificador para gestionar acciones de consumo
class SeguimientoNotifier extends StateNotifier<AsyncValue<void>> {
  final RepositorioTutor _repo;
  SeguimientoNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> marcarConsumido(int idPlanItem, WidgetRef ref, {required String idPaciente, required String fecha}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.registrarConsumo(idPlanItem, 1); // 1 = Consumido
      state = const AsyncValue.data(null);
      // Refrescar la lista
      ref.invalidate(planDiarioProvider((idPaciente: idPaciente, fecha: fecha)));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final seguimientoNotifierProvider = StateNotifierProvider<SeguimientoNotifier, AsyncValue<void>>((ref) {
  return SeguimientoNotifier(ref.watch(repositorioTutorProvider));
});
