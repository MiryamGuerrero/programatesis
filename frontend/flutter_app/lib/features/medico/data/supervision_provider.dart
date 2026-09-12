import "package:flutter_riverpod/flutter_riverpod.dart";

import "repositorio_medico.dart";

class MedicalPatientsState {
  final bool isLoading;
  final List<Map<String, dynamic>> patients;
  final String searchQuery;
  final String estadoFiltro; // "todos" | "activos" | "archivados"
  final int totalItems;
  final int offset;
  final String? errorMessage;
  final Map<int, List<Map<String, dynamic>>> cachedPages;

  const MedicalPatientsState({
    this.isLoading = true,
    this.patients = const [],
    this.searchQuery = "",
    this.estadoFiltro = "todos",
    this.totalItems = 0,
    this.offset = 0,
    this.errorMessage,
    this.cachedPages = const {},
  });

  MedicalPatientsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? patients,
    String? searchQuery,
    String? estadoFiltro,
    int? totalItems,
    int? offset,
    String? errorMessage,
    bool clearErrorMessage = false,
    Map<int, List<Map<String, dynamic>>>? cachedPages,
  }) {
    return MedicalPatientsState(
      isLoading: isLoading ?? this.isLoading,
      patients: patients ?? this.patients,
      searchQuery: searchQuery ?? this.searchQuery,
      estadoFiltro: estadoFiltro ?? this.estadoFiltro,
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      cachedPages: cachedPages ?? this.cachedPages,
    );
  }

  bool get activeFilters => searchQuery.isNotEmpty || estadoFiltro != "todos";
}

class MedicalPatientsNotifier extends StateNotifier<MedicalPatientsState> {
  MedicalPatientsNotifier(this._ref) : super(const MedicalPatientsState()) {
    loadPageIfNeeded();
  }

  final Ref _ref;
  static const int pageSize = 5;

  Future<void> loadPageIfNeeded({int? offset}) async {
    if (state.patients.isNotEmpty && !state.isLoading) {
      return;
    }
    return loadPage(offset: offset);
  }

  Future<void> loadPage({int? offset, bool forceRefresh = false}) async {
    final nextOffset = offset ?? state.offset;

    // Cache hit: instant retrieval without API call when navigating back without filters
    if (!forceRefresh && !state.activeFilters && state.cachedPages.containsKey(nextOffset)) {
      state = state.copyWith(
        isLoading: false,
        offset: nextOffset,
        patients: state.cachedPages[nextOffset]!,
        clearErrorMessage: true,
      );
      return;
    }

    final currentCached = forceRefresh ? <int, List<Map<String, dynamic>>>{} : state.cachedPages;
    state = state.copyWith(
      isLoading: true,
      offset: nextOffset,
      cachedPages: currentCached,
      clearErrorMessage: true,
    );
    
    try {
      final repo = _ref.read(repositorioMedicoProvider);
      final result = await repo.fetchPatientsPage(
        query: state.searchQuery,
        limit: pageSize,
        offset: nextOffset,
        estado: state.estadoFiltro,
      );
      
      final updatedCache = Map<int, List<Map<String, dynamic>>>.from(state.cachedPages);
      if (!state.activeFilters) {
        updatedCache[nextOffset] = result.items;
      }

      state = state.copyWith(
        isLoading: false,
        patients: result.items,
        totalItems: result.total,
        cachedPages: updatedCache,
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
        estado: state.estadoFiltro,
      );
      final updatedCache = Map<int, List<Map<String, dynamic>>>.from(state.cachedPages);
      if (!state.activeFilters) {
        updatedCache[state.offset] = result.items;
      }
      state = state.copyWith(
        patients: result.items,
        totalItems: result.total,
        cachedPages: updatedCache,
      );
    } catch (_) {}
  }

  void invalidateCache() {
    state = state.copyWith(cachedPages: const {});
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query, offset: 0, cachedPages: const {});
    loadPage(offset: 0, forceRefresh: true);
  }

  void setEstadoFiltro(String estado) {
    if (state.estadoFiltro == estado) return;
    state = state.copyWith(estadoFiltro: estado, offset: 0, cachedPages: const {});
    loadPage(offset: 0, forceRefresh: true);
  }

  void clearFilters() {
    state = state.copyWith(searchQuery: "", estadoFiltro: "todos", offset: 0, cachedPages: const {});
    loadPage(offset: 0, forceRefresh: true);
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
