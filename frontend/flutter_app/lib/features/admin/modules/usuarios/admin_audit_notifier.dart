import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

class AdminAuditState {
  final bool isLoading;
  final List<Map<String, dynamic>> controls;
  final String searchQuery;
  final bool? selectedActivo;
  final bool? selectedBrote;
  final int totalItems;
  final int offset;
  final String? errorMessage;

  const AdminAuditState({
    this.isLoading = true,
    this.controls = const [],
    this.searchQuery = "",
    this.selectedActivo,
    this.selectedBrote,
    this.totalItems = 0,
    this.offset = 0,
    this.errorMessage,
  });

  AdminAuditState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? controls,
    String? searchQuery,
    bool? selectedActivo,
    bool clearActivo = false,
    bool? selectedBrote,
    bool clearBrote = false,
    int? totalItems,
    int? offset,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AdminAuditState(
      isLoading: isLoading ?? this.isLoading,
      controls: controls ?? this.controls,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedActivo: clearActivo ? null : (selectedActivo ?? this.selectedActivo),
      selectedBrote: clearBrote ? null : (selectedBrote ?? this.selectedBrote),
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get activeFilters => searchQuery.isNotEmpty || selectedActivo != null || selectedBrote != null;
}

class AdminAuditNotifier extends StateNotifier<AdminAuditState> {
  AdminAuditNotifier(this._ref) : super(const AdminAuditState());

  final Ref _ref;
  static const int pageSize = 10;

  Future<void> loadPage({int? offset}) async {
    final nextOffset = offset ?? state.offset;
    state = state.copyWith(
        isLoading: true, offset: nextOffset, clearErrorMessage: true);

    try {
      final repo = _ref.read(supabaseCrudRepositoryProvider);
      final result = await repo.fetchAuditControls(
        query: state.searchQuery,
        activo: state.selectedActivo,
        enBrote: state.selectedBrote,
        limit: pageSize,
        offset: nextOffset,
      );
      state = state.copyWith(
        isLoading: false,
        controls: result.items,
        totalItems: result.total,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> setQuery(String q) async {
    state = state.copyWith(searchQuery: q, offset: 0);
    await loadPage(offset: 0);
  }

  Future<void> setActivoFilter(bool? val) async {
    if (val == null) {
      state = state.copyWith(clearActivo: true, offset: 0);
    } else {
      state = state.copyWith(selectedActivo: val, offset: 0);
    }
    await loadPage(offset: 0);
  }

  Future<void> setBroteFilter(bool? val) async {
    if (val == null) {
      state = state.copyWith(clearBrote: true, offset: 0);
    } else {
      state = state.copyWith(selectedBrote: val, offset: 0);
    }
    await loadPage(offset: 0);
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      searchQuery: "",
      clearActivo: true,
      clearBrote: true,
      offset: 0,
    );
    await loadPage(offset: 0);
  }
}

final adminAuditProvider =
    StateNotifierProvider<AdminAuditNotifier, AdminAuditState>((ref) {
  return AdminAuditNotifier(ref);
});
