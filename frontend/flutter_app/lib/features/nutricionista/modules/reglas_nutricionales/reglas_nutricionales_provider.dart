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
  final int totalItems;
  final int offset;

  const ReglasNutricionalesState({
    this.isLoading = true,
    this.rules = const [],
    this.formData = const <String, List<dynamic>>{},
    this.searchQuery = "",
    this.selectedObjetivos = const <String>{},
    this.filtroCondicion,
    this.filtroAccion,
    this.errorMessage,
    this.totalItems = 0,
    this.offset = 0,
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
    int? totalItems,
    int? offset,
  }) {
    return ReglasNutricionalesState(
      isLoading: isLoading ?? this.isLoading,
      rules: rules ?? this.rules,
      formData: formData ?? this.formData,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedObjetivos: selectedObjetivos ?? this.selectedObjetivos,
      filtroCondicion: clearFiltroCondicion
          ? null
          : (filtroCondicion ?? this.filtroCondicion),
      filtroAccion:
          clearFiltroAccion ? null : (filtroAccion ?? this.filtroAccion),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
    );
  }

  List<dynamic> get filteredRules => rules;

  int get strictCount =>
      rules.where((r) => (r as Map<String, dynamic>)["es_estricta"] == true).length;

  bool get activeFilters =>
      searchQuery.isNotEmpty ||
      selectedObjetivos.isNotEmpty ||
      filtroCondicion != null ||
      filtroAccion != null;
}

class ReglasNutricionalesNotifier
    extends StateNotifier<ReglasNutricionalesState> {
  ReglasNutricionalesNotifier(this._dio)
      : super(const ReglasNutricionalesState());

  final Dio _dio;
  static const int pageSize = 5;

  Future<void> loadData({int? offset}) async {
    final nextOffset = offset ?? state.offset;
    state = state.copyWith(isLoading: true, clearErrorMessage: true, offset: nextOffset);
    try {
      final List<Future<dynamic>> requests = [
        _dio.get("reglas-nutricionales", queryParameters: {
          "limit": pageSize,
          "offset": nextOffset,
          "include_total": true,
        }),
      ];

      // Solo cargar catálogos si no existen en memoria
      if (state.formData.isEmpty) {
        requests.add(_dio.get(
          "reglas-nutricionales/form-data",
          queryParameters: {"compact": true},
        ));
      }

      final results = await Future.wait(requests);
      final rulesResult = Map<String, dynamic>.from(results[0].data as Map);

      state = state.copyWith(
        isLoading: false,
        rules: rulesResult["items"] as List,
        totalItems: rulesResult["total"] ?? 0,
        formData: results.length > 1
            ? Map<String, List<dynamic>>.from(results[1].data as Map)
            : state.formData,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al sincronizar motor de reglas",
      );
    }
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value, offset: 0);
    loadData(offset: 0);
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
    state = state.copyWith(
        filtroCondicion: value, clearFiltroCondicion: value == null);
  }

  void setFiltroAccion(int? value) {
    state = state.copyWith(
        filtroAccion: value, clearFiltroAccion: value == null);
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
    // 1. Actualización Granular Local
    final oldRules = List<dynamic>.from(state.rules);
    final nextRules = oldRules.where((r) => r["id"] != id).toList();

    state = state.copyWith(
        rules: nextRules, totalItems: state.totalItems - 1);

    // 2. Sincronización con el servidor
    try {
      await _dio.delete("reglas-nutricionales/$id");
    } catch (_) {
      // Revertir en caso de error
      state = state.copyWith(rules: oldRules, totalItems: state.totalItems + 1);
      state = state.copyWith(
        errorMessage: "No se pudo eliminar la regla seleccionada",
      );
    }
  }
}

final reglasNutricionalesProvider = StateNotifierProvider<
    ReglasNutricionalesNotifier, ReglasNutricionalesState>((ref) {
  return ReglasNutricionalesNotifier(ref.watch(dioProvider));
});
