import "package:flutter_riverpod/flutter_riverpod.dart";
import "repositorio_medico.dart";

final supervisionAdherenciaProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(repositorioMedicoProvider);
  return repo.obtenerSupervisionAdherencia();
});

final medicoPatientsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(repositorioMedicoProvider);
  return repo.listarPacientes();
});

final medicoPatientExpedienteProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, idPaciente) async {
  final repo = ref.watch(repositorioMedicoProvider);
  return repo.obtenerExpedienteCompleto(idPaciente);
});
