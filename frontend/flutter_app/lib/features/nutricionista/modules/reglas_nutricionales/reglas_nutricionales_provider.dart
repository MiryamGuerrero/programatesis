import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

String reglasNutricionalesTargetName(Map<String, dynamic> rule) =>
    rule["ingrediente_nombre"] ??
    rule["grupo_nombre"] ??
    rule["subgrupo_nombre"] ??
    rule["etiqueta_nombre"] ??
    "Objetivo";

class ReglasNutricionalesState {
  final bool isLoading;
  final List<dynamic> rules;
  final Map<String, List<dynamic>> formData;
  final String searchQuery;
  final Set<String> selectedObjetivos;
  final int? filtroCondicion;
  final int? filtroAccion;
  final String? errorMessage;

  const ReglasNutricionalesState({
    this.isLoading = true,
    this.rules = const [],
    this.formData = const <String, List<dynamic>>{},
    this.searchQuery = "",
    this.selectedObjetivos = const <String>{},
    this.filtroCondicion,
    this.filtroAccion,
    this.errorMessage,
  });

  ReglasNutricionalesState copyWith({
    bool? isLoading,
    List<dynamic>? rules,
    Map<String, List<dynamic>>? formData,
    String? searchQuery,
    Set<String>? selectedObjetivos,
    int? filtroCondicion,
    int? filtroAccion,
    String? errorMessage,
    bool clearFiltroCondicion = false,
    bool clearFiltroAccion = false,
    bool clearErrorMessage = false,
  }) {
    return ReglasNutricionalesState(
      isLoading: isLoading ?? this.isLoading,
      rules: rules ?? this.rules,
      formData: formData ?? this.formData,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedObjetivos: selectedObjetivos ?? this.selectedObjetivos,
      filtroCondicion:
          clearFiltroCondicion ? null : (filtroCondicion ?? this.filtroCondicion),
      filtroAccion:
          clearFiltroAccion ? null : (filtroAccion ?? this.filtroAccion),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  List<dynamic> get filteredRules {
    final query = searchQuery.toLowerCase();

    return rules.where((r) {
      final rule = r as Map<String, dynamic>;
      final targetName = reglasNutricionalesTargetName(rule).toLowerCase();
      final matchesSearch = targetName.contains(query);
      final matchesTipo = selectedObjetivos.isEmpty ||
          selectedObjetivos.contains(rule["objetivo_codigo"]);

      final condicionesIdsRaw = rule["id_condiciones"];
      final condicionesIds =
          condicionesIdsRaw is List ? condicionesIdsRaw.cast<int>() : <int>[];

      final matchesCondicion =
          filtroCondicion == null || condicionesIds.contains(filtroCondicion);
      final matchesAccion = filtroAccion == null || rule["id_accion"] == filtroAccion;

      return matchesSearch && matchesTipo && matchesCondicion && matchesAccion;
    }).toList();
  }

  int get strictCount =>
      rules.where((r) => (r as Map<String, dynamic>)["es_estricta"] == true).length;

  bool get activeFilters =>
      searchQuery.isNotEmpty ||
      selectedObjetivos.isNotEmpty ||
      filtroCondicion != null ||
      filtroAccion != null;
}

class ReglasNutricionalesNotifier extends StateNotifier<ReglasNutricionalesState> {
  ReglasNutricionalesNotifier(this._dio) : super(const ReglasNutricionalesState());

  final Dio _dio;

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final results = await Future.wait([
        _dio.get("reglas-nutricionales"),
        _dio.get(
          "reglas-nutricionales/form-data",
          queryParameters: {"compact": true},
        ),
      ]);

      state = state.copyWith(
        isLoading: false,
        rules: results[0].data as List,
        formData: Map<String, List<dynamic>>.from(results[1].data as Map),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al sincronizar motor de reglas",
      );
    }
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void clearObjetivos() {
    state = state.copyWith(selectedObjetivos: <String>{});
  }

  void toggleObjetivo(String value) {
    final next = Set<String>.from(state.selectedObjetivos);
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    state = state.copyWith(selectedObjetivos: next);
  }

  void setFiltroCondicion(int? value) {
    state = state.copyWith(filtroCondicion: value, clearFiltroCondicion: value == null);
  }

  void setFiltroAccion(int? value) {
    state = state.copyWith(filtroAccion: value, clearFiltroAccion: value == null);
  }

  void clearAllFilters() {
    state = state.copyWith(
      searchQuery: "",
      selectedObjetivos: <String>{},
      clearFiltroCondicion: true,
      clearFiltroAccion: true,
    );
  }

  Future<void> deleteRule(int id) async {
    try {
      await _dio.delete("reglas-nutricionales/$id");
      await loadData();
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "No se pudo eliminar la regla seleccionada",
      );
    }
  }
}

final reglasNutricionalesProvider = StateNotifierProvider<
    ReglasNutricionalesNotifier, ReglasNutricionalesState>((ref) {
  return ReglasNutricionalesNotifier(ref.watch(dioProvider));
});
