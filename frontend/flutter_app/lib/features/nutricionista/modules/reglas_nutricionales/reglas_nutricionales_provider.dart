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
  final String indicadorFilter; // BMI (Peso) | HFA (Estatura)
  final int? filtroCondicion;
  final int? filtroAccion;
  final int? filtroTipoObjetivo;
  final int? filtroObjetivo;
  final String? errorMessage;
  final int totalItems;
  final int offset;

  // Estadísticas del motor
  final int strictRulesCount;
  final int pesoRulesCount;
  final int estaturaRulesCount;

  const ReglasNutricionalesState({
    this.isLoading = true,
    this.rules = const [],
    this.formData = const <String, List<dynamic>>{},
    this.searchQuery = "",
    this.indicadorFilter = "BMI",
    this.filtroCondicion,
    this.filtroAccion,
    this.filtroTipoObjetivo,
    this.filtroObjetivo,
    this.errorMessage,
    this.totalItems = 0,
    this.offset = 0,
    this.strictRulesCount = 0,
    this.pesoRulesCount = 0,
    this.estaturaRulesCount = 0,
  });

  ReglasNutricionalesState copyWith({
    bool? isLoading,
    List<dynamic>? rules,
    Map<String, List<dynamic>>? formData,
    String? searchQuery,
    String? indicadorFilter,
    int? filtroCondicion,
    int? filtroAccion,
    int? filtroTipoObjetivo,
    int? filtroObjetivo,
    String? errorMessage,
    bool clearFiltroCondicion = false,
    bool clearFiltroAccion = false,
    bool clearFiltroTipoObjetivo = false,
    bool clearFiltroObjetivo = false,
    bool clearErrorMessage = false,
    int? totalItems,
    int? offset,
    int? strictRulesCount,
    int? pesoRulesCount,
    int? estaturaRulesCount,
  }) {
    return ReglasNutricionalesState(
      isLoading: isLoading ?? this.isLoading,
      rules: rules ?? this.rules,
      formData: formData ?? this.formData,
      searchQuery: searchQuery ?? this.searchQuery,
      indicadorFilter: indicadorFilter ?? this.indicadorFilter,
      filtroCondicion: clearFiltroCondicion
          ? null
          : (filtroCondicion ?? this.filtroCondicion),
      filtroAccion:
          clearFiltroAccion ? null : (filtroAccion ?? this.filtroAccion),
      filtroTipoObjetivo: clearFiltroTipoObjetivo
          ? null
          : (filtroTipoObjetivo ?? this.filtroTipoObjetivo),
      filtroObjetivo: clearFiltroObjetivo
          ? null
          : (filtroObjetivo ?? this.filtroObjetivo),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
      strictRulesCount: strictRulesCount ?? this.strictRulesCount,
      pesoRulesCount: pesoRulesCount ?? this.pesoRulesCount,
      estaturaRulesCount: estaturaRulesCount ?? this.estaturaRulesCount,
    );
  }

  bool get activeFilters =>
      searchQuery.isNotEmpty ||
      filtroCondicion != null ||
      filtroAccion != null ||
      filtroTipoObjetivo != null ||
      filtroObjetivo != null;
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
      // 1. Cargar Estadísticas
      final statsRes = await _dio.get("reglas-nutricionales/estadisticas");
      final stats = Map<String, dynamic>.from(statsRes.data as Map);
      final strictCount = (stats["estrictas"] as num?)?.toInt() ?? 0;
      final pesoCount = (stats["peso"] as num?)?.toInt() ?? 0;
      final estaturaCount = (stats["estatura"] as num?)?.toInt() ?? 0;

      // 2. Cargar listado de reglas filtradas
      final Map<String, dynamic> queryParams = {
        "limit": pageSize,
        "offset": nextOffset,
        "include_total": true,
        "indicador": state.indicadorFilter,
        if (state.searchQuery.isNotEmpty) "q": state.searchQuery,
        if (state.filtroCondicion != null) "id_condicion": state.filtroCondicion,
        if (state.filtroAccion != null) "id_accion": state.filtroAccion,
        if (state.filtroTipoObjetivo != null) "id_tipo_objetivo": state.filtroTipoObjetivo,
        if (state.filtroObjetivo != null) "id_objetivo": state.filtroObjetivo,
      };

      final List<Future<dynamic>> requests = [
        _dio.get("reglas-nutricionales", queryParameters: queryParams),
      ];

      // Solo cargar catálogos si no existen en memoria
      if (state.formData.isEmpty) {
        requests.add(_dio.get(
          "reglas-nutricionales/form-data",
          queryParameters: {"compact": false}, // Necesitamos todos los ingredientes, grupos, etc.
        ));
      }

      final results = await Future.wait(requests);
      final rulesResult = Map<String, dynamic>.from(results[0].data as Map);

      state = state.copyWith(
        isLoading: false,
        rules: rulesResult["items"] as List? ?? [],
        totalItems: rulesResult["total"] ?? 0,
        strictRulesCount: strictCount,
        pesoRulesCount: pesoCount,
        estaturaRulesCount: estaturaCount,
        formData: results.length > 1
            ? Map<String, List<dynamic>>.from(
                (results[1].data as Map).map(
                  (k, v) => MapEntry(
                    k.toString(),
                    List<Map<String, dynamic>>.from(v as List),
                  ),
                ),
              )
            : state.formData,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al sincronizar motor de reglas: $e",
      );
    }
  }

  void setIndicadorFilter(String value) {
    state = state.copyWith(
      indicadorFilter: value,
      offset: 0,
      clearFiltroCondicion: true,
      clearFiltroAccion: true,
      clearFiltroTipoObjetivo: true,
      clearFiltroObjetivo: true,
    );
    loadData(offset: 0);
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value, offset: 0);
    loadData(offset: 0);
  }

  void setFiltroCondicion(int? value) {
    state = state.copyWith(
      filtroCondicion: value,
      clearFiltroCondicion: value == null,
      offset: 0,
    );
    loadData(offset: 0);
  }

  void setFiltroAccion(int? value) {
    state = state.copyWith(
      filtroAccion: value,
      clearFiltroAccion: value == null,
      offset: 0,
    );
    loadData(offset: 0);
  }

  void setFiltroTipoObjetivo(int? value) {
    state = state.copyWith(
      filtroTipoObjetivo: value,
      clearFiltroTipoObjetivo: value == null,
      clearFiltroObjetivo: true,
      offset: 0,
    );
    loadData(offset: 0);
  }

  void setFiltroObjetivo(int? value) {
    state = state.copyWith(
      filtroObjetivo: value,
      clearFiltroObjetivo: value == null,
      offset: 0,
    );
    loadData(offset: 0);
  }

  void clearAllFilters() {
    state = state.copyWith(
      searchQuery: "",
      clearFiltroCondicion: true,
      clearFiltroAccion: true,
      clearFiltroTipoObjetivo: true,
      clearFiltroObjetivo: true,
      offset: 0,
    );
    loadData(offset: 0);
  }

  Future<void> deleteRule(int id) async {
    final oldRules = List<dynamic>.from(state.rules);
    final nextRules = oldRules.where((r) => r["id"] != id).toList();

    state = state.copyWith(
      rules: nextRules,
      totalItems: state.totalItems - 1,
    );

    try {
      await _dio.delete("reglas-nutricionales/$id");
      // Recargar estadísticas tras eliminar
      loadData();
    } catch (_) {
      state = state.copyWith(
        rules: oldRules,
        totalItems: state.totalItems + 1,
        errorMessage: "No se pudo eliminar la regla seleccionada",
      );
    }
  }
}

final reglasNutricionalesProvider = StateNotifierProvider<
    ReglasNutricionalesNotifier, ReglasNutricionalesState>((ref) {
  return ReglasNutricionalesNotifier(ref.watch(dioProvider));
});
