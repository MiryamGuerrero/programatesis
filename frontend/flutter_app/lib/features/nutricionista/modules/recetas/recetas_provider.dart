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
    this.totalItems = 0,
    this.activos = 0,
    this.inactivos = 0,
  });

  final int totalItems;
  final int activos;
  final int inactivos;

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
    int? totalItems,
    int? activos,
    int? inactivos,
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
      totalItems: totalItems ?? this.totalItems,
      activos: activos ?? this.activos,
      inactivos: inactivos ?? this.inactivos,
    );
  }

  int get totalPages => (totalItems / pageSize).ceil();

  List<Map<String, dynamic>> get visibleRecetas => recetas;

  bool get filtrosActivos =>
      query.trim().isNotEmpty ||
      momentoSeleccionado != null ||
      tipoPlatoSeleccionado != null;
}

class RecetasNotifier extends StateNotifier<RecetasState> {
  RecetasNotifier(this._ref) : super(const RecetasState());

  final Ref _ref;

  Future<void> loadRecetas({bool reload = false}) async {
    if (reload || state.recetas.isEmpty) {
      state = state.copyWith(isLoading: true, clearError: true);
      if (reload || state.totalItems == 0) {
        await _loadMetadata();
      }
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final repo = _ref.read(supabaseCrudRepositoryProvider);
      final dio = _ref.read(dioProvider);

      // Cargar catálogos solo si están vacíos
      if (state.momentosComida.isEmpty || state.tiposPlato.isEmpty) {
        final catalogs = await Future.wait([
          dio.get("crud/momentos"),
          dio.get("crud/tipos-plato"),
        ]);
        state = state.copyWith(
          momentosComida: _toRows((catalogs[0] as Response).data),
          tiposPlato: _toRows((catalogs[1] as Response).data),
        );
      }

      final result = await repo.fetchRecetasPage(
        query: state.query,
        idMomento: state.momentoSeleccionado,
        idTipoPlato: state.tipoPlatoSeleccionado,
        limit: RecetasState.pageSize,
        offset: state.currentPage * RecetasState.pageSize,
      );

      state = state.copyWith(
        isLoading: false,
        recetas: result.items,
        totalItems: result.total,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: "No se pudieron cargar las recetas.",
      );
    }
  }

  Future<void> _loadMetadata() async {
    state = state.copyWith(isLoadingMetadata: true);
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get("crud/recetas/metadatos");
      final data = Map<String, dynamic>.from(res.data);
      state = state.copyWith(
        isLoadingMetadata: false,
        activos: (data["activos"] as num?)?.toInt() ?? 0,
        inactivos: (data["inactivos"] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMetadata: false);
    }
  }

  void setQuery(String value) {
    state = state.copyWith(query: value, currentPage: 0);
    loadRecetas();
  }

  void setMomentoSeleccionado(int? value) {
    state = state.copyWith(momentoSeleccionado: value, currentPage: 0);
    loadRecetas();
  }

  void setTipoPlatoSeleccionado(int? value) {
    state = state.copyWith(tipoPlatoSeleccionado: value, currentPage: 0);
    loadRecetas();
  }

  void clearFilters() {
    state = state.copyWith(
      query: "",
      clearMomentoSeleccionado: true,
      clearTipoPlatoSeleccionado: true,
      currentPage: 0,
    );
    loadRecetas();
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
      loadRecetas();
    }
  }

  void previousPage() {
    if (state.currentPage > 0) {
      state = state.copyWith(currentPage: state.currentPage - 1);
      loadRecetas();
    }
  }

  Future<void> toggleActiva(int id, bool valor) async {
    // 1. Actualización Granular Local (Sin carga global)
    final index = state.recetas.indexWhere((r) => r["id"] == id);
    if (index != -1) {
      final updatedRecetas = List<Map<String, dynamic>>.from(state.recetas);
      final oldItem = updatedRecetas[index];
      updatedRecetas[index] = {...oldItem, "activa": valor};

      state = state.copyWith(
        recetas: updatedRecetas,
        activos: valor ? state.activos + 1 : state.activos - 1,
        inactivos: valor ? state.inactivos - 1 : state.inactivos + 1,
      );
    }

    // 2. Sincronización con el servidor
    try {
      final dio = _ref.read(dioProvider);
      await dio.patch("crud/recetas/$id/estado", data: {"activa": valor});
    } catch (_) {
      // Revertir en caso de error (opcional para robustez extrema)
      loadRecetas();
    }
  }

  Future<void> eliminarReceta(int id) async {
    // 1. Remoción Granular Local
    final index = state.recetas.indexWhere((r) => r["id"] == id);
    if (index != -1) {
      final updatedRecetas = List<Map<String, dynamic>>.from(state.recetas);
      final wasActive = updatedRecetas[index]["activa"] == true;
      updatedRecetas.removeAt(index);

      state = state.copyWith(
        recetas: updatedRecetas,
        totalItems: state.totalItems - 1,
        activos: wasActive ? state.activos - 1 : state.activos,
        inactivos: wasActive ? state.inactivos : state.inactivos - 1,
      );
    }

    // 2. Sincronización con el servidor
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete("crud/recetas/$id");
    } catch (_) {
      loadRecetas();
    }
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
