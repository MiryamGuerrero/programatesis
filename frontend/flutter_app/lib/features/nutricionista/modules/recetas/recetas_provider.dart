import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

class RecetasState {
  final bool isLoading;
  final bool isLoadingMetadata;
  final bool isDeleting;
  final String? error;
  final List<Map<String, dynamic>> recetas;
  final List<Map<String, dynamic>> momentosComida;
  final List<Map<String, dynamic>> tiposPlato;
  final String query;
  final int? momentoSeleccionado;
  final int? tipoPlatoSeleccionado;
  final int currentPage;

  static const int pageSize = 12;

  const RecetasState({
    this.isLoading = false,
    this.isLoadingMetadata = false,
    this.isDeleting = false,
    this.error,
    this.recetas = const [],
    this.momentosComida = const [],
    this.tiposPlato = const [],
    this.query = "",
    this.momentoSeleccionado,
    this.tipoPlatoSeleccionado,
    this.currentPage = 0,
  });

  RecetasState copyWith({
    bool? isLoading,
    bool? isLoadingMetadata,
    bool? isDeleting,
    String? error,
    bool clearError = false,
    List<Map<String, dynamic>>? recetas,
    List<Map<String, dynamic>>? momentosComida,
    List<Map<String, dynamic>>? tiposPlato,
    String? query,
    int? momentoSeleccionado,
    int? tipoPlatoSeleccionado,
    bool clearMomentoSeleccionado = false,
    bool clearTipoPlatoSeleccionado = false,
    int? currentPage,
  }) {
    return RecetasState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMetadata: isLoadingMetadata ?? this.isLoadingMetadata,
      isDeleting: isDeleting ?? this.isDeleting,
      error: clearError ? null : (error ?? this.error),
      recetas: recetas ?? this.recetas,
      momentosComida: momentosComida ?? this.momentosComida,
      tiposPlato: tiposPlato ?? this.tiposPlato,
      query: query ?? this.query,
      momentoSeleccionado: clearMomentoSeleccionado
          ? null
          : (momentoSeleccionado ?? this.momentoSeleccionado),
      tipoPlatoSeleccionado: clearTipoPlatoSeleccionado
          ? null
          : (tipoPlatoSeleccionado ?? this.tipoPlatoSeleccionado),
      currentPage: currentPage ?? this.currentPage,
    );
  }

  List<Map<String, dynamic>> get filteredRecetas {
    return recetas.where((row) {
      final queryValue = query.trim().toLowerCase();
      final textoBusqueda = [
        row["nombre"],
        row["descripcion"],
        row["categoria"],
        row["momentos_nombres"],
        row["tipos_plato_nombres"],
      ].whereType<Object>().join(" ").toLowerCase();

      final coincideBusqueda =
          queryValue.isEmpty || textoBusqueda.contains(queryValue);
      final coincideMomento = momentoSeleccionado == null ||
          _contieneId(row, ["momentos_ids", "momentos"], momentoSeleccionado!);
      final coincideTipoPlato = tipoPlatoSeleccionado == null ||
          _contieneId(
              row, ["tipos_plato_ids", "tipos_plato"], tipoPlatoSeleccionado!);

      return coincideBusqueda && coincideMomento && coincideTipoPlato;
    }).toList();
  }

  int get totalItems => filteredRecetas.length;

  int get totalPages => (totalItems / pageSize).ceil();

  List<Map<String, dynamic>> get visibleRecetas {
    final startIndex = currentPage * pageSize;
    final endIndex = (startIndex + pageSize < totalItems)
        ? startIndex + pageSize
        : totalItems;
    if (startIndex >= totalItems) {
      return const [];
    }
    return filteredRecetas.sublist(startIndex, endIndex);
  }

  int get activos => recetas.where((r) => r["activa"] == true).length;

  int get inactivos => recetas.length - activos;

  bool get filtrosActivos =>
      query.trim().isNotEmpty ||
      momentoSeleccionado != null ||
      tipoPlatoSeleccionado != null;

  static bool _contieneId(
      Map<String, dynamic> row, List<String> keys, int idBuscado) {
    for (final key in keys) {
      final value = row[key];
      if (value is List && value.any((item) => _asInt(item) == idBuscado)) {
        return true;
      }
      if (_asInt(value) == idBuscado) {
        return true;
      }
    }
    return false;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "");
  }
}

class RecetasNotifier extends StateNotifier<RecetasState> {
  RecetasNotifier(this._ref) : super(const RecetasState());

  final Ref _ref;

  Future<void> loadRecetas({bool reload = false}) async {
    state = state.copyWith(
      isLoading: true,
      isLoadingMetadata: reload || state.recetas.isEmpty,
      recetas: reload ? const [] : state.recetas,
      clearError: true,
    );
    try {
      final repo = _ref.read(supabaseCrudRepositoryProvider);
      final dio = _ref.read(dioProvider);
      final results = await Future.wait([
        repo.fetchRecetas(limit: 1000),
        dio.get("crud/momentos"),
        dio.get("crud/tipos-plato"),
      ]);

      state = state.copyWith(
        isLoading: false,
        isLoadingMetadata: false,
        recetas: List<Map<String, dynamic>>.from(results[0] as List),
        momentosComida: _toRows((results[1] as Response).data),
        tiposPlato: _toRows((results[2] as Response).data),
        currentPage: 0,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMetadata: false,
        error: "No se pudieron cargar las recetas.",
      );
    }
  }

  void setQuery(String value) {
    state = state.copyWith(query: value, currentPage: 0);
  }

  void setMomentoSeleccionado(int? value) {
    state = state.copyWith(momentoSeleccionado: value, currentPage: 0);
  }

  void setTipoPlatoSeleccionado(int? value) {
    state = state.copyWith(tipoPlatoSeleccionado: value, currentPage: 0);
  }

  void clearFilters() {
    state = state.copyWith(
      query: "",
      clearMomentoSeleccionado: true,
      clearTipoPlatoSeleccionado: true,
      currentPage: 0,
    );
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value, clearError: value);
  }

  void setDeleting(bool value) {
    state = state.copyWith(isDeleting: value);
  }

  void nextPage() {
    if (state.currentPage < state.totalPages - 1) {
      state = state.copyWith(currentPage: state.currentPage + 1);
    }
  }

  void previousPage() {
    if (state.currentPage > 0) {
      state = state.copyWith(currentPage: state.currentPage - 1);
    }
  }

  Future<void> toggleActiva(int id, bool valor) async {
    final dio = _ref.read(dioProvider);
    await dio.patch("crud/recetas/$id/estado", data: {"activa": valor});
    await loadRecetas();
  }

  Future<void> eliminarReceta(int id) async {
    final dio = _ref.read(dioProvider);
    await dio.delete("crud/recetas/$id");
    await loadRecetas();
  }

  static List<Map<String, dynamic>> _toRows(dynamic payload) {
    if (payload is! List) return const [];
    return payload
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}

final recetasProvider =
    StateNotifierProvider<RecetasNotifier, RecetasState>((ref) {
  return RecetasNotifier(ref);
});
