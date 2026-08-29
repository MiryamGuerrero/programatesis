import "package:flutter_riverpod/flutter_riverpod.dart";
import "repositorio_tutor.dart";

import "../../../core/state/app_providers.dart";

/// Provider para obtener el plan del día
final planDiarioProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({String idPaciente, String fecha})>((ref, arg) async {
  final repo = ref.watch(repositorioTutorProvider);
  return repo.obtenerPlanDiario(arg.idPaciente, arg.fecha);
});

/// Provider para obtener estadísticas de adherencia
final adherenciaProvider = FutureProvider.family<Map<String, dynamic>,
    ({String idPaciente, int dias})>((ref, arg) async {
  final repo = ref.watch(repositorioTutorProvider);
  return repo.obtenerEstadisticasAdherencia(arg.idPaciente, dias: arg.dias);
});

/// Provider para obtener momentos de comida
final momentosComidaProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('tutor/momentos-comida');
  return List<Map<String, dynamic>>.from(resp.data);
});

/// Provider para obtener tipos de plato
final tiposPlatoProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('tutor/tipos-plato');
  return List<Map<String, dynamic>>.from(resp.data);
});

/// Provider para obtener subgrupos de preferencia de un paciente
final subgruposGustosProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, idPaciente) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('tutor/subgrupos-preferencia/$idPaciente');
  return List<Map<String, dynamic>>.from(resp.data);
});

/// Provider para obtener las recetas seguras iniciales de un paciente
final recetasSegurasInicialesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, idPaciente) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('tutor/recetas-seguras/$idPaciente',
      queryParameters: {'consulta': '', 'limite': 20, 'offset': 0});
  return List<Map<String, dynamic>>.from(resp.data);
});

/// Notificador para gestionar acciones de consumo
class SeguimientoNotifier extends StateNotifier<AsyncValue<void>> {
  final RepositorioTutor _repo;
  SeguimientoNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> marcarConsumido(int idPlanItem, WidgetRef ref,
      {required String idPaciente, required String fecha}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.registrarConsumo(idPlanItem, 1); // 1 = Consumido
      await ref.refresh(
          planDiarioProvider((idPaciente: idPaciente, fecha: fecha)).future);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final seguimientoNotifierProvider =
    StateNotifierProvider<SeguimientoNotifier, AsyncValue<void>>((ref) {
  return SeguimientoNotifier(ref.watch(repositorioTutorProvider));
});
