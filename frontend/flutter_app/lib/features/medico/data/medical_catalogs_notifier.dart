import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";
import "repositorio_medico.dart";

class MedicalRulesState {
  final bool isLoading;
  final List<Map<String, dynamic>> rules;
  final int totalItems;
  final int offset;
  final Map<String, List<dynamic>> formData;
  final String? errorMessage;
  final String? origenFilter;
  final int? idCondicionFilter;
  final int? idAccionFilter;
  final int? idTipoObjetivoFilter;
  final int? idObjetivoFilter;
  final String searchQuery;
  final int strictRulesCount;
  final int clinicalRulesCount;
  final int temporalRulesCount;

  const MedicalRulesState({
    this.isLoading = true,
    this.rules = const [],
    this.totalItems = 0,
    this.offset = 0,
    this.formData = const {},
    this.errorMessage,
    this.origenFilter = "CLINICA",
    this.idCondicionFilter,
    this.idAccionFilter,
    this.idTipoObjetivoFilter,
    this.idObjetivoFilter,
    this.searchQuery = "",
    this.strictRulesCount = 0,
    this.clinicalRulesCount = 0,
    this.temporalRulesCount = 0,
  });

  MedicalRulesState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? rules,
    int? totalItems,
    int? offset,
    Map<String, List<dynamic>>? formData,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? origenFilter,
    int? idCondicionFilter,
    int? idAccionFilter,
    int? idTipoObjetivoFilter,
    int? idObjetivoFilter,
    String? searchQuery,
    int? strictRulesCount,
    int? clinicalRulesCount,
    int? temporalRulesCount,
    bool clearCondicionFilter = false,
    bool clearAccionFilter = false,
    bool clearTipoObjetivoFilter = false,
    bool clearObjetivoFilter = false,
  }) {
    return MedicalRulesState(
      isLoading: isLoading ?? this.isLoading,
      rules: rules ?? this.rules,
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
      formData: formData ?? this.formData,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      origenFilter: origenFilter ?? this.origenFilter,
      idCondicionFilter: clearCondicionFilter ? null : (idCondicionFilter ?? this.idCondicionFilter),
      idAccionFilter: clearAccionFilter ? null : (idAccionFilter ?? this.idAccionFilter),
      idTipoObjetivoFilter: clearTipoObjetivoFilter ? null : (idTipoObjetivoFilter ?? this.idTipoObjetivoFilter),
      idObjetivoFilter: clearObjetivoFilter ? null : (idObjetivoFilter ?? this.idObjetivoFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      strictRulesCount: strictRulesCount ?? this.strictRulesCount,
      clinicalRulesCount: clinicalRulesCount ?? this.clinicalRulesCount,
      temporalRulesCount: temporalRulesCount ?? this.temporalRulesCount,
    );
  }
}

class MedicalRulesNotifier extends StateNotifier<MedicalRulesState> {
  MedicalRulesNotifier(this._ref) : super(const MedicalRulesState());

  final Ref _ref;
  static const int pageSize = 5;

  Future<void> loadPage({int? offset}) async {
    final nextOffset = offset ?? state.offset;
    state = state.copyWith(isLoading: true, offset: nextOffset, clearErrorMessage: true);
    
    try {
      final repo = _ref.read(repositorioMedicoProvider);
      final dio = _ref.read(dioProvider);
      
      // Load form data if empty
      if (state.formData.isEmpty) {
        final res = await dio.get("reglas-medicas/form-data");
        final fData = Map<String, List<dynamic>>.from(
          (res.data as Map).map((k, v) => MapEntry(k.toString(), List<Map<String, dynamic>>.from(v as List)))
        );
        state = state.copyWith(formData: fData);
      }

      // Fetch statistics
      final statsRes = await dio.get("reglas-medicas/estadisticas");
      final stats = statsRes.data as Map<String, dynamic>;
      final strictCount = stats["estrictas"] as int? ?? 0;
      final clinicasCount = stats["clinicas"] as int? ?? 0;
      final temporalesCount = stats["temporales"] as int? ?? 0;

      final result = await repo.fetchMedicalRulesPage(
        query: state.searchQuery,
        limit: pageSize,
        offset: nextOffset,
        origen: state.origenFilter,
        idCondicion: state.idCondicionFilter,
        idAccion: state.idAccionFilter,
        idTipoObjetivo: state.idTipoObjetivoFilter,
        idObjetivo: state.idObjetivoFilter,
      );
      
      state = state.copyWith(
        isLoading: false,
        rules: result.items,
        totalItems: result.total,
        strictRulesCount: strictCount,
        clinicalRulesCount: clinicasCount,
        temporalRulesCount: temporalesCount,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al cargar reglas: $e",
      );
    }
  }

  void setOrigenFilter(String? origen) {
    state = state.copyWith(
      origenFilter: origen, 
      offset: 0,
      clearCondicionFilter: true,
      clearAccionFilter: true,
      clearTipoObjetivoFilter: true,
      clearObjetivoFilter: true,
    );
    loadPage(offset: 0);
  }

  void setIdCondicionFilter(int? idCondicion) {
    state = state.copyWith(idCondicionFilter: idCondicion, offset: 0, clearCondicionFilter: idCondicion == null);
    loadPage(offset: 0);
  }

  void setIdAccionFilter(int? idAccion) {
    state = state.copyWith(idAccionFilter: idAccion, offset: 0, clearAccionFilter: idAccion == null);
    loadPage(offset: 0);
  }

  void setIdTipoObjetivoFilter(int? idTipoObjetivo) {
    state = state.copyWith(
      idTipoObjetivoFilter: idTipoObjetivo, 
      offset: 0, 
      clearTipoObjetivoFilter: idTipoObjetivo == null,
      clearObjetivoFilter: true,
    );
    loadPage(offset: 0);
  }

  void setIdObjetivoFilter(int? idObjetivo) {
    state = state.copyWith(idObjetivoFilter: idObjetivo, offset: 0, clearObjetivoFilter: idObjetivo == null);
    loadPage(offset: 0);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, offset: 0);
    loadPage(offset: 0);
  }

  void clearFilters() {
    state = state.copyWith(
      offset: 0,
      searchQuery: "",
      clearCondicionFilter: true,
      clearAccionFilter: true,
      clearTipoObjetivoFilter: true,
      clearObjetivoFilter: true,
    );
    loadPage(offset: 0);
  }

  Future<void> deleteRule(int id) async {
    final oldRules = List<Map<String, dynamic>>.from(state.rules);
    state = state.copyWith(rules: oldRules.where((r) => r["id"] != id).toList(), totalItems: state.totalItems - 1);
    
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete("reglas-medicas/$id");
    } catch (e) {
      state = state.copyWith(rules: oldRules, totalItems: state.totalItems + 1, errorMessage: "Error al eliminar");
    }
  }
}

final medicalRulesProvider = StateNotifierProvider<MedicalRulesNotifier, MedicalRulesState>((ref) {
  return MedicalRulesNotifier(ref);
});

// --- CATALOGO CONDICIONES NOTIFIER ---

class MedicalConditionsState {
  final bool isLoading;
  final List<Map<String, dynamic>> conditions;
  final String searchQuery;
  final int? selectedTipo;
  final int totalItems;
  final int offset;
  final String? errorMessage;

  const MedicalConditionsState({
    this.isLoading = true,
    this.conditions = const [],
    this.searchQuery = "",
    this.selectedTipo,
    this.totalItems = 0,
    this.offset = 0,
    this.errorMessage,
  });

  MedicalConditionsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? conditions,
    String? searchQuery,
    int? selectedTipo,
    int? totalItems,
    int? offset,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return MedicalConditionsState(
      isLoading: isLoading ?? this.isLoading,
      conditions: conditions ?? this.conditions,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTipo: selectedTipo ?? this.selectedTipo,
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MedicalConditionsNotifier extends StateNotifier<MedicalConditionsState> {
  MedicalConditionsNotifier(this._ref) : super(const MedicalConditionsState());

  final Ref _ref;
  static const int pageSize = 5;

  Future<void> loadPage({int? offset}) async {
    final nextOffset = offset ?? state.offset;
    state = state.copyWith(isLoading: true, offset: nextOffset, clearErrorMessage: true);
    
    try {
      final repo = _ref.read(repositorioMedicoProvider);
      final result = await repo.fetchMedicalConditionsPage(
        query: state.searchQuery,
        tipo: state.selectedTipo,
        limit: pageSize,
        offset: nextOffset,
      );
      
      state = state.copyWith(
        isLoading: false,
        conditions: result.items,
        totalItems: result.total,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al cargar catálogo: $e",
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, offset: 0);
    loadPage(offset: 0);
  }

  void setTipo(int? tipo) {
    state = state.copyWith(selectedTipo: tipo, offset: 0);
    loadPage(offset: 0);
  }
}

final medicalConditionsProvider = StateNotifierProvider<MedicalConditionsNotifier, MedicalConditionsState>((ref) {
  return MedicalConditionsNotifier(ref);
});
