import "package:flutter_riverpod/flutter_riverpod.dart";
import "repositorio_medico.dart";

final supervisionAdherenciaProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(repositorioMedicoProvider);
  return repo.obtenerSupervisionAdherencia();
});
