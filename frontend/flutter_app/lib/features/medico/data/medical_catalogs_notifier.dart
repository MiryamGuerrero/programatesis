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

  const MedicalRulesState({
    this.isLoading = true,
    this.rules = const [],
    this.totalItems = 0,
    this.offset = 0,
    this.formData = const {},
    this.errorMessage,
  });

  MedicalRulesState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? rules,
    int? totalItems,
    int? offset,
    Map<String, List<dynamic>>? formData,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return MedicalRulesState(
      isLoading: isLoading ?? this.isLoading,
      rules: rules ?? this.rules,
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
      formData: formData ?? this.formData,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
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
      
      // Load form data if empty
      if (state.formData.isEmpty) {
        final dio = _ref.read(dioProvider);
        final res = await dio.get("reglas-medicas/form-data");
        final fData = Map<String, List<dynamic>>.from(
          (res.data as Map).map((k, v) => MapEntry(k.toString(), List<Map<String, dynamic>>.from(v as List)))
        );
        state = state.copyWith(formData: fData);
      }

      final result = await repo.fetchMedicalRulesPage(
        limit: pageSize,
        offset: nextOffset,
      );
      
      state = state.copyWith(
        isLoading: false,
        rules: result.items,
        totalItems: result.total,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al cargar reglas: $e",
      );
    }
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
