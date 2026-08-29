import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "repositorio_medico.dart";

class MedicalPatientsState {
  final bool isLoading;
  final List<Map<String, dynamic>> patients;
  final String searchQuery;
  final int totalItems;
  final int offset;
  final String? errorMessage;

  const MedicalPatientsState({
    this.isLoading = true,
    this.patients = const [],
    this.searchQuery = "",
    this.totalItems = 0,
    this.offset = 0,
    this.errorMessage,
  });

  MedicalPatientsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? patients,
    String? searchQuery,
    int? totalItems,
    int? offset,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return MedicalPatientsState(
      isLoading: isLoading ?? this.isLoading,
      patients: patients ?? this.patients,
      searchQuery: searchQuery ?? this.searchQuery,
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get activeFilters => searchQuery.isNotEmpty;
}

class MedicalPatientsNotifier extends StateNotifier<MedicalPatientsState> {
  MedicalPatientsNotifier(this._ref) : super(const MedicalPatientsState());

  final Ref _ref;
  static const int pageSize = 5;

  Future<void> loadPage({int? offset}) async {
    final nextOffset = offset ?? state.offset;
    state = state.copyWith(isLoading: true, offset: nextOffset, clearErrorMessage: true);
    
    try {
      final repo = _ref.read(repositorioMedicoProvider);
      final result = await repo.fetchPatientsPage(
        query: state.searchQuery,
        limit: pageSize,
        offset: nextOffset,
      );
      
      state = state.copyWith(
        isLoading: false,
        patients: result.items,
        totalItems: result.total,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al cargar pacientes: $e",
      );
    }
  }

  Future<void> loadPageSilently() async {
    try {
      final repo = _ref.read(repositorioMedicoProvider);
      final result = await repo.fetchPatientsPage(
        query: state.searchQuery,
        limit: pageSize,
        offset: state.offset,
      );
      state = state.copyWith(
        patients: result.items,
        totalItems: result.total,
      );
    } catch (_) {}
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query, offset: 0);
    loadPage(offset: 0);
  }

  void clearFilters() {
    state = state.copyWith(searchQuery: "", offset: 0);
    loadPage(offset: 0);
  }
}

final medicalPatientsProvider = StateNotifierProvider<MedicalPatientsNotifier, MedicalPatientsState>((ref) {
  return MedicalPatientsNotifier(ref);
});

// Mantener los otros proveedores existentes
final supervisionAdherenciaProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(repositorioMedicoProvider);
  return repo.obtenerSupervisionAdherencia();
});

final medicoPatientsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(repositorioMedicoProvider);
  return repo.listarPacientes();
});

final medicoPatientExpedienteProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, idPaciente) async {
  final repo = ref.watch(repositorioMedicoProvider);
  return repo.obtenerExpedienteCompleto(idPaciente);
});
