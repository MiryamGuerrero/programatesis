import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";
import "repositorio_medico.dart";

class MedicalRulesState {
  final bool isLoading;
  final List<Map<String, dynamic>> rulesClinicas;
  final int totalClinicas;
  final int offsetClinicas;

  final List<Map<String, dynamic>> rulesTemporales;
  final int totalTemporales;
  final int offsetTemporales;

  final String searchQuery;
  final Map<String, List<dynamic>> formData;
  final String? errorMessage;
  final String origenFilter;
  final int? idCondicionFilter;
  final int? idAccionFilter;
  final int? idTipoObjetivoFilter;
  final int? idObjetivoFilter;
  final int strictRulesCount;
  final int clinicalRulesCount;
  final int temporalRulesCount;
  final Map<String, Map<int, List<Map<String, dynamic>>>> cachedPagesByOrigen;

  const MedicalRulesState({
    this.isLoading = true,
    this.rulesClinicas = const [],
    this.totalClinicas = 0,
    this.offsetClinicas = 0,
    this.rulesTemporales = const [],
    this.totalTemporales = 0,
    this.offsetTemporales = 0,
    this.searchQuery = "",
    this.formData = const {},
    this.errorMessage,
    this.origenFilter = "CLINICA",
    this.idCondicionFilter,
    this.idAccionFilter,
    this.idTipoObjetivoFilter,
    this.idObjetivoFilter,
    this.strictRulesCount = 0,
    this.clinicalRulesCount = 0,
    this.temporalRulesCount = 0,
    this.cachedPagesByOrigen = const {"CLINICA": {}, "TEMPORAL": {}},
  });

  /// Lista correspondiente a la pestaña activa
  List<Map<String, dynamic>> get rules =>
      origenFilter == "TEMPORAL" ? rulesTemporales : rulesClinicas;

  /// Total de registros de la pestaña activa
  int get totalItems =>
      origenFilter == "TEMPORAL" ? totalTemporales : totalClinicas;

  /// Offset de paginación de la pestaña activa
  int get offset =>
      origenFilter == "TEMPORAL" ? offsetTemporales : offsetClinicas;

  bool get hasDataForCurrentOrigen =>
      origenFilter == "TEMPORAL" ? rulesTemporales.isNotEmpty : rulesClinicas.isNotEmpty;

  bool get activeFilters =>
      searchQuery.isNotEmpty ||
      idCondicionFilter != null ||
      idAccionFilter != null ||
      idTipoObjetivoFilter != null ||
      idObjetivoFilter != null;

  MedicalRulesState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? rulesClinicas,
    int? totalClinicas,
    int? offsetClinicas,
    List<Map<String, dynamic>>? rulesTemporales,
    int? totalTemporales,
    int? offsetTemporales,
    String? searchQuery,
    Map<String, List<dynamic>>? formData,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? origenFilter,
    int? idCondicionFilter,
    int? idAccionFilter,
    int? idTipoObjetivoFilter,
    int? idObjetivoFilter,
    int? strictRulesCount,
    int? clinicalRulesCount,
    int? temporalRulesCount,
    Map<String, Map<int, List<Map<String, dynamic>>>>? cachedPagesByOrigen,
    bool clearCondicionFilter = false,
    bool clearAccionFilter = false,
    bool clearTipoObjetivoFilter = false,
    bool clearObjetivoFilter = false,
  }) {
    return MedicalRulesState(
      isLoading: isLoading ?? this.isLoading,
      rulesClinicas: rulesClinicas ?? this.rulesClinicas,
      totalClinicas: totalClinicas ?? this.totalClinicas,
      offsetClinicas: offsetClinicas ?? this.offsetClinicas,
      rulesTemporales: rulesTemporales ?? this.rulesTemporales,
      totalTemporales: totalTemporales ?? this.totalTemporales,
      offsetTemporales: offsetTemporales ?? this.offsetTemporales,
      searchQuery: searchQuery ?? this.searchQuery,
      formData: formData ?? this.formData,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      origenFilter: origenFilter ?? this.origenFilter,
      idCondicionFilter: clearCondicionFilter ? null : (idCondicionFilter ?? this.idCondicionFilter),
      idAccionFilter: clearAccionFilter ? null : (idAccionFilter ?? this.idAccionFilter),
      idTipoObjetivoFilter: clearTipoObjetivoFilter ? null : (idTipoObjetivoFilter ?? this.idTipoObjetivoFilter),
      idObjetivoFilter: clearObjetivoFilter ? null : (idObjetivoFilter ?? this.idObjetivoFilter),
      strictRulesCount: strictRulesCount ?? this.strictRulesCount,
      clinicalRulesCount: clinicalRulesCount ?? this.clinicalRulesCount,
      temporalRulesCount: temporalRulesCount ?? this.temporalRulesCount,
      cachedPagesByOrigen: cachedPagesByOrigen ?? this.cachedPagesByOrigen,
    );
  }
}

class MedicalRulesNotifier extends StateNotifier<MedicalRulesState> {
  MedicalRulesNotifier(this._ref) : super(const MedicalRulesState());

  final Ref _ref;
  static const int pageSize = 5;
  Future<void>? _formDataRequest;

  Future<void> loadPageIfNeeded({String? origen}) async {
    final target = origen ?? state.origenFilter;
    final hasData = target == "TEMPORAL"
        ? state.rulesTemporales.isNotEmpty
        : state.rulesClinicas.isNotEmpty;
    if (hasData) {
      return;
    }
    return loadPage(origen: target);
  }  Future<void> loadPage({int? offset, String? origen, bool force = false}) async {
    final targetOrigen = origen ?? state.origenFilter;
    final currentOffset = targetOrigen == "TEMPORAL"
        ? state.offsetTemporales
        : state.offsetClinicas;
    final nextOffset = offset ?? currentOffset;

    // Cache hit: instant retrieval without API call when navigating back without filters
    final origenCache = state.cachedPagesByOrigen[targetOrigen] ?? {};
    if (!force && !state.activeFilters && origenCache.containsKey(nextOffset)) {
      final cachedItems = origenCache[nextOffset]!;
      if (targetOrigen == "TEMPORAL") {
        state = state.copyWith(
          isLoading: false,
          rulesTemporales: cachedItems,
          offsetTemporales: nextOffset,
          clearErrorMessage: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          rulesClinicas: cachedItems,
          offsetClinicas: nextOffset,
          clearErrorMessage: true,
        );
      }
      return;
    }

    final hasData = targetOrigen == "TEMPORAL"
        ? state.rulesTemporales.isNotEmpty
        : state.rulesClinicas.isNotEmpty;

    final shouldShowLoading = !hasData || force || offset != null;
    if (shouldShowLoading) {
      if (targetOrigen == "TEMPORAL") {
        state = state.copyWith(
            isLoading: true,
            offsetTemporales: nextOffset,
            clearErrorMessage: true);
      } else {
        state = state.copyWith(
            isLoading: true,
            offsetClinicas: nextOffset,
            clearErrorMessage: true);
      }
    }

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
        origen: targetOrigen,
        idCondicion: state.idCondicionFilter,
        idAccion: state.idAccionFilter,
        idTipoObjetivo: state.idTipoObjetivoFilter,
        idObjetivo: state.idObjetivoFilter,
      );

      final newCache = Map<String, Map<int, List<Map<String, dynamic>>>>.from(
        state.cachedPagesByOrigen.map((k, v) => MapEntry(k, Map<int, List<Map<String, dynamic>>>.from(v))),
      );
      if (!state.activeFilters) {
        newCache.putIfAbsent(targetOrigen, () => {})[nextOffset] = result.items;
      }

      if (targetOrigen == "TEMPORAL") {
        state = state.copyWith(
          isLoading: false,
          rulesTemporales: result.items,
          totalTemporales: result.total,
          offsetTemporales: nextOffset,
          strictRulesCount: strictCount,
          clinicalRulesCount: clinicasCount,
          temporalRulesCount: temporalesCount,
          cachedPagesByOrigen: newCache,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          rulesClinicas: result.items,
          totalClinicas: result.total,
          offsetClinicas: nextOffset,
          strictRulesCount: strictCount,
          clinicalRulesCount: clinicasCount,
          temporalRulesCount: temporalesCount,
          cachedPagesByOrigen: newCache,
        );
      }
      unawaited(loadFormData());
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al cargar reglas: $e",
      );
    }
  }

  /// Carga silenciosa para actualización por eventos Realtime o mutaciones CRUD
  Future<void> loadPageSilently({String? origen}) async {
    final targetOrigen = origen ?? state.origenFilter;
    final currentOffset = targetOrigen == "TEMPORAL"
        ? state.offsetTemporales
        : state.offsetClinicas;

    try {
      final repo = _ref.read(repositorioMedicoProvider);
      final dio = _ref.read(dioProvider);

      final statsRes = await dio.get("reglas-medicas/estadisticas");
      final stats = statsRes.data as Map<String, dynamic>;
      final strictCount = stats["estrictas"] as int? ?? 0;
      final clinicasCount = stats["clinicas"] as int? ?? 0;
      final temporalesCount = stats["temporales"] as int? ?? 0;

      final result = await repo.fetchMedicalRulesPage(
        query: state.searchQuery,
        limit: pageSize,
        offset: currentOffset,
        origen: targetOrigen,
        idCondicion: state.idCondicionFilter,
        idAccion: state.idAccionFilter,
        idTipoObjetivo: state.idTipoObjetivoFilter,
        idObjetivo: state.idObjetivoFilter,
      );

      if (targetOrigen == "TEMPORAL") {
        state = state.copyWith(
          rulesTemporales: result.items,
          totalTemporales: result.total,
          offsetTemporales: currentOffset,
          strictRulesCount: strictCount,
          clinicalRulesCount: clinicasCount,
          temporalRulesCount: temporalesCount,
        );
      } else {
        state = state.copyWith(
          rulesClinicas: result.items,
          totalClinicas: result.total,
          offsetClinicas: currentOffset,
          strictRulesCount: strictCount,
          clinicalRulesCount: clinicasCount,
          temporalRulesCount: temporalesCount,
        );
      }
    } catch (_) {}
  }

  /// Refresca ambas pestañas silenciosamente ante eventos Realtime de base de datos
  Future<void> refreshAllSilently() async {
    state = state.copyWith(cachedPagesByOrigen: const {"CLINICA": {}, "TEMPORAL": {}});
    await Future.wait([
      loadPageSilently(origen: "CLINICA"),
      loadPageSilently(origen: "TEMPORAL"),
    ]);
  }

  /// Cambio reactivo puro en memoria entre pestañas (0 llamadas a la API si ya existen los datos)
  void setOrigenFilter(String? origen) {
    final target = origen ?? "CLINICA";
    if (state.origenFilter == target) return;

    state = state.copyWith(
      origenFilter: target,
      clearCondicionFilter: true,
      clearAccionFilter: true,
      clearTipoObjetivoFilter: true,
      clearObjetivoFilter: true,
    );

    final hasTargetData = target == "TEMPORAL"
        ? state.rulesTemporales.isNotEmpty
        : state.rulesClinicas.isNotEmpty;

    if (!hasTargetData) {
      loadPage(origen: target, offset: 0);
    }
  }

  void setIdCondicionFilter(int? idCondicion) {
    state = state.copyWith(
      idCondicionFilter: idCondicion,
      offsetClinicas: 0,
      offsetTemporales: 0,
      clearCondicionFilter: idCondicion == null,
      cachedPagesByOrigen: const {"CLINICA": {}, "TEMPORAL": {}},
    );
    loadPage(offset: 0, force: true);
  }

  void setIdAccionFilter(int? idAccion) {
    state = state.copyWith(
      idAccionFilter: idAccion,
      offsetClinicas: 0,
      offsetTemporales: 0,
      clearAccionFilter: idAccion == null,
      cachedPagesByOrigen: const {"CLINICA": {}, "TEMPORAL": {}},
    );
    loadPage(offset: 0, force: true);
  }

  void setIdTipoObjetivoFilter(int? idTipoObjetivo) {
    state = state.copyWith(
      idTipoObjetivoFilter: idTipoObjetivo, 
      offsetClinicas: 0,
      offsetTemporales: 0,
      clearTipoObjetivoFilter: idTipoObjetivo == null,
      clearObjetivoFilter: true,
      cachedPagesByOrigen: const {"CLINICA": {}, "TEMPORAL": {}},
    );
    loadPage(offset: 0, force: true);
  }

  void setIdObjetivoFilter(int? idObjetivo) {
    state = state.copyWith(
      idObjetivoFilter: idObjetivo,
      offsetClinicas: 0,
      offsetTemporales: 0,
      clearObjetivoFilter: idObjetivo == null,
      cachedPagesByOrigen: const {"CLINICA": {}, "TEMPORAL": {}},
    );
    loadPage(offset: 0, force: true);
  }

  Future<void> loadFormData() {
    if (state.formData.isNotEmpty) return Future.value();
    final activeRequest = _formDataRequest;
    if (activeRequest != null) return activeRequest;

    final request = _fetchFormData();
    _formDataRequest = request;
    request.whenComplete(() {
      if (identical(_formDataRequest, request)) _formDataRequest = null;
    });
    return request;
  }

  Future<void> _fetchFormData() async {
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get("reglas-medicas/form-data");
      final formData = Map<String, List<dynamic>>.from(
        (response.data as Map).map(
          (key, value) => MapEntry(
            key.toString(),
            List<Map<String, dynamic>>.from(value as List),
          ),
        ),
      );
      state = state.copyWith(formData: formData);
    } catch (e) {
      state = state.copyWith(
        errorMessage: "Error al cargar datos del formulario: $e",
      );
    }
  }

  void setSearchQuery(String query) {
    final trimmed = query.trim();
    if (state.searchQuery == trimmed) return;
    state = state.copyWith(
      searchQuery: trimmed,
      offsetClinicas: 0,
      offsetTemporales: 0,
      cachedPagesByOrigen: const {"CLINICA": {}, "TEMPORAL": {}},
    );
    loadPage(offset: 0, force: true);
  }

  void clearFilters() {
    state = state.copyWith(
      offsetClinicas: 0,
      offsetTemporales: 0,
      searchQuery: "",
      clearCondicionFilter: true,
      clearAccionFilter: true,
      clearTipoObjetivoFilter: true,
      clearObjetivoFilter: true,
      cachedPagesByOrigen: const {"CLINICA": {}, "TEMPORAL": {}},
    );
    loadPage(offset: 0, force: true);
  }

  Future<void> refreshAfterMutation({String? preferredOrigen}) async {
    state = state.copyWith(
      cachedPagesByOrigen: const {"CLINICA": {}, "TEMPORAL": {}},
    );
    if (preferredOrigen != null && state.origenFilter != preferredOrigen) {
      state = state.copyWith(
        origenFilter: preferredOrigen,
        offsetClinicas: 0,
        offsetTemporales: 0,
      );
    }
    await loadPage(force: true);
    final otherOrigen =
        state.origenFilter == "CLINICA" ? "TEMPORAL" : "CLINICA";
    await loadPageSilently(origen: otherOrigen);
  }

  Future<void> deleteRule(int id) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete("reglas-medicas/$id");
      await refreshAfterMutation();
    } catch (e) {
      state = state.copyWith(errorMessage: "Error al eliminar: $e");
    }
  }
}

final medicalRulesProvider =
    StateNotifierProvider<MedicalRulesNotifier, MedicalRulesState>((ref) {
  return MedicalRulesNotifier(ref);
});

// --- CATALOGO CONDICIONES NOTIFIER (ARQUITECTURA REACTIVA) ---

class MedicalConditionsState {
  final bool isLoading;
  final List<Map<String, dynamic>> conditionsClinicas;
  final int totalClinicas;
  final int offsetClinicas;

  final List<Map<String, dynamic>> conditionsTemporales;
  final int totalTemporales;
  final int offsetTemporales;

  final String searchQuery;
  final int selectedTipo; // 1: Clínicas, 2: Temporales
  final String? errorMessage;
  final Map<int, Map<int, List<Map<String, dynamic>>>> cachedPagesByTipo;

  const MedicalConditionsState({
    this.isLoading = true,
    this.conditionsClinicas = const [],
    this.totalClinicas = 0,
    this.offsetClinicas = 0,
    this.conditionsTemporales = const [],
    this.totalTemporales = 0,
    this.offsetTemporales = 0,
    this.searchQuery = "",
    this.selectedTipo = 1,
    this.errorMessage,
    this.cachedPagesByTipo = const {1: {}, 2: {}},
  });

  /// Lista correspondiente a la pestaña activa
  List<Map<String, dynamic>> get conditions =>
      selectedTipo == 2 ? conditionsTemporales : conditionsClinicas;

  /// Total de registros correspondiente a la pestaña activa
  int get totalItems =>
      selectedTipo == 2 ? totalTemporales : totalClinicas;

  /// Offset de paginación correspondiente a la pestaña activa
  int get offset =>
      selectedTipo == 2 ? offsetTemporales : offsetClinicas;

  bool get hasDataForSelectedTipo =>
      selectedTipo == 2 ? conditionsTemporales.isNotEmpty : conditionsClinicas.isNotEmpty;

  bool get activeFilters => searchQuery.isNotEmpty;

  MedicalConditionsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? conditionsClinicas,
    int? totalClinicas,
    int? offsetClinicas,
    List<Map<String, dynamic>>? conditionsTemporales,
    int? totalTemporales,
    int? offsetTemporales,
    String? searchQuery,
    int? selectedTipo,
    String? errorMessage,
    bool clearErrorMessage = false,
    Map<int, Map<int, List<Map<String, dynamic>>>>? cachedPagesByTipo,
  }) {
    return MedicalConditionsState(
      isLoading: isLoading ?? this.isLoading,
      conditionsClinicas: conditionsClinicas ?? this.conditionsClinicas,
      totalClinicas: totalClinicas ?? this.totalClinicas,
      offsetClinicas: offsetClinicas ?? this.offsetClinicas,
      conditionsTemporales: conditionsTemporales ?? this.conditionsTemporales,
      totalTemporales: totalTemporales ?? this.totalTemporales,
      offsetTemporales: offsetTemporales ?? this.offsetTemporales,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTipo: selectedTipo ?? this.selectedTipo,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      cachedPagesByTipo: cachedPagesByTipo ?? this.cachedPagesByTipo,
    );
  }
}

class MedicalConditionsNotifier extends StateNotifier<MedicalConditionsState> {
  MedicalConditionsNotifier(this._ref) : super(const MedicalConditionsState());

  final Ref _ref;
  static const int pageSize = 5;

  Future<void> loadPageIfNeeded({int? tipo}) async {
    final targetTipo = tipo ?? state.selectedTipo;
    final hasData = targetTipo == 2
        ? state.conditionsTemporales.isNotEmpty
        : state.conditionsClinicas.isNotEmpty;
    if (hasData) {
      return;
    }
    return loadPage(tipo: targetTipo);
  }

  Future<void> loadPage({int? offset, int? tipo, bool force = false}) async {
    final targetTipo = tipo ?? state.selectedTipo;
    final currentOffset =
        targetTipo == 2 ? state.offsetTemporales : state.offsetClinicas;
    final nextOffset = offset ?? currentOffset;

    // Cache hit: instant retrieval without API call when navigating back without filters
    final tipoCache = state.cachedPagesByTipo[targetTipo] ?? {};
    if (!force && !state.activeFilters && tipoCache.containsKey(nextOffset)) {
      final cachedItems = tipoCache[nextOffset]!;
      if (targetTipo == 2) {
        state = state.copyWith(
          isLoading: false,
          conditionsTemporales: cachedItems,
          offsetTemporales: nextOffset,
          clearErrorMessage: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          conditionsClinicas: cachedItems,
          offsetClinicas: nextOffset,
          clearErrorMessage: true,
        );
      }
      return;
    }

    final hasData = targetTipo == 2
        ? state.conditionsTemporales.isNotEmpty
        : state.conditionsClinicas.isNotEmpty;

    // Solo mostramos shimmer si la pestaña activa no tiene datos o si es forzado explícitamente
    final shouldShowLoading = !hasData || force || offset != null;
    if (shouldShowLoading) {
      if (targetTipo == 2) {
        state = state.copyWith(
            isLoading: true,
            offsetTemporales: nextOffset,
            clearErrorMessage: true);
      } else {
        state = state.copyWith(
            isLoading: true,
            offsetClinicas: nextOffset,
            clearErrorMessage: true);
      }
    }

    try {
      final repo = _ref.read(repositorioMedicoProvider);
      final result = await repo.fetchMedicalConditionsPage(
        query: state.searchQuery,
        tipo: targetTipo,
        limit: pageSize,
        offset: nextOffset,
      );

      final newCache = Map<int, Map<int, List<Map<String, dynamic>>>>.from(
        state.cachedPagesByTipo.map((k, v) => MapEntry(k, Map<int, List<Map<String, dynamic>>>.from(v))),
      );
      if (!state.activeFilters) {
        newCache.putIfAbsent(targetTipo, () => {})[nextOffset] = result.items;
      }

      if (targetTipo == 2) {
        state = state.copyWith(
          isLoading: false,
          conditionsTemporales: result.items,
          totalTemporales: result.total,
          offsetTemporales: nextOffset,
          cachedPagesByTipo: newCache,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          conditionsClinicas: result.items,
          totalClinicas: result.total,
          offsetClinicas: nextOffset,
          cachedPagesByTipo: newCache,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al cargar catálogo: $e",
      );
    }
  }

  /// Carga y actualiza datos silenciosamente en segundo plano únicamente cuando la información
  /// ha sido alterada (operaciones CRUD o eventos Realtime de base de datos)
  Future<void> loadPageSilently({int? tipo}) async {
    final targetTipo = tipo ?? state.selectedTipo;
    final currentOffset =
        targetTipo == 2 ? state.offsetTemporales : state.offsetClinicas;

    try {
      final repo = _ref.read(repositorioMedicoProvider);
      final result = await repo.fetchMedicalConditionsPage(
        query: state.searchQuery,
        tipo: targetTipo,
        limit: pageSize,
        offset: currentOffset,
      );

      if (targetTipo == 2) {
        state = state.copyWith(
          conditionsTemporales: result.items,
          totalTemporales: result.total,
        );
      } else {
        state = state.copyWith(
          conditionsClinicas: result.items,
          totalClinicas: result.total,
        );
      }
    } catch (_) {}
  }

  /// Refresca ambas pestañas de forma silenciosa al detectar alteraciones reales en la base de datos
  Future<void> refreshAllSilently() async {
    state = state.copyWith(cachedPagesByTipo: const {1: {}, 2: {}});
    await Future.wait([
      loadPageSilently(tipo: 1),
      loadPageSilently(tipo: 2),
    ]);
  }

  /// Cambio reactivo puro en memoria entre pestañas.
  /// NO consulta a la API si la pestaña ya tiene información cargada en memoria.
  void setTipo(int tipo) {
    if (state.selectedTipo == tipo) return;

    // Cambio reactivo puro de estado en memoria (0 peticiones a la API)
    state = state.copyWith(selectedTipo: tipo);

    final hasTargetData = tipo == 2
        ? state.conditionsTemporales.isNotEmpty
        : state.conditionsClinicas.isNotEmpty;

    // Solo consulta a la API si es la primera vez que se visita esa categoría y no tiene datos
    if (!hasTargetData) {
      loadPage(tipo: tipo, offset: 0);
    }
  }

  void setSearchQuery(String query) {
    final trimmed = query.trim();
    if (state.searchQuery == trimmed) return;

    state = state.copyWith(
      searchQuery: trimmed,
      offsetClinicas: 0,
      offsetTemporales: 0,
      cachedPagesByTipo: const {1: {}, 2: {}},
    );
    loadPage(offset: 0, force: true);
  }
}

final medicalConditionsProvider =
    StateNotifierProvider<MedicalConditionsNotifier, MedicalConditionsState>(
        (ref) {
  return MedicalConditionsNotifier(ref);
});
