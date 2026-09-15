import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

class AdminUsersState {
  final bool isLoading;
  final List<Map<String, dynamic>> users;
  final String searchQuery;
  final Set<int> selectedRolIds;
  final bool? selectedActivo;
  final int totalItems;
  final int offset;
  final Map<int, int> roleCounts;
  final String? errorMessage;
  final Map<int, List<Map<String, dynamic>>> cachedPages;

  const AdminUsersState({
    this.isLoading = true,
    this.users = const [],
    this.searchQuery = "",
    this.selectedRolIds = const {},
    this.selectedActivo,
    this.totalItems = 0,
    this.offset = 0,
    this.roleCounts = const {},
    this.errorMessage,
    this.cachedPages = const {},
  });

  AdminUsersState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? users,
    String? searchQuery,
    Set<int>? selectedRolIds,
    bool? selectedActivo,
    bool clearActivo = false,
    int? totalItems,
    int? offset,
    Map<int, int>? roleCounts,
    String? errorMessage,
    bool clearErrorMessage = false,
    Map<int, List<Map<String, dynamic>>>? cachedPages,
  }) {
    return AdminUsersState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRolIds: selectedRolIds ?? this.selectedRolIds,
      selectedActivo: clearActivo ? null : (selectedActivo ?? this.selectedActivo),
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
      roleCounts: roleCounts ?? this.roleCounts,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      cachedPages: cachedPages ?? this.cachedPages,
    );
  }

  bool get activeFilters => searchQuery.isNotEmpty || selectedRolIds.isNotEmpty || selectedActivo != null;
}

class AdminUsersNotifier extends StateNotifier<AdminUsersState> {
  AdminUsersNotifier(
    this._ref, {
    this.allowedRolIds = const {},
    Set<int> initialSelectedRolIds = const {},
  }) : super(AdminUsersState(selectedRolIds: initialSelectedRolIds));

  final Ref _ref;
  final Set<int> allowedRolIds;
  static const int pageSize = 5;

  List<int> get _effectiveRolIds {
    if (state.selectedRolIds.isEmpty) return allowedRolIds.toList();
    if (allowedRolIds.isEmpty) return state.selectedRolIds.toList();
    final scopedSelection = state.selectedRolIds
        .where((rolId) => allowedRolIds.contains(rolId))
        .toList();
    return scopedSelection.isEmpty ? allowedRolIds.toList() : scopedSelection;
  }

  List<int> get effectiveRolIds => _effectiveRolIds;

  Future<Map<int, int>> _loadRoleCounts() async {
    if (allowedRolIds.isEmpty) return const {};

    final repo = _ref.read(supabaseCrudRepositoryProvider);
    final entries = await Future.wait(
      allowedRolIds.map((roleId) async {
        final result = await repo.fetchUsersPage(
          query: "",
          rolIds: [roleId],
          limit: 1,
          offset: 0,
        );
        return MapEntry(roleId, result.total);
      }),
    );

    return Map<int, int>.fromEntries(entries);
  }

  Future<void> loadPageIfNeeded({int? offset}) async {
    if (state.users.isNotEmpty && !state.isLoading) {
      return;
    }
    return loadPage(offset: offset);
  }

  Future<void> loadPage({int? offset, bool forceRefresh = false, bool refreshRoleCounts = false}) async {
    final nextOffset = offset ?? state.offset;

    // Cache hit: instant retrieval without API call when navigating back without filters
    if (!forceRefresh && !state.activeFilters && state.cachedPages.containsKey(nextOffset)) {
      state = state.copyWith(
        isLoading: false,
        offset: nextOffset,
        users: state.cachedPages[nextOffset]!,
        clearErrorMessage: true,
      );
      return;
    }

    final currentCached = forceRefresh ? <int, List<Map<String, dynamic>>>{} : state.cachedPages;
    state = state.copyWith(
        isLoading: true,
        offset: nextOffset,
        cachedPages: currentCached,
        clearErrorMessage: true);

    try {
      final repo = _ref.read(supabaseCrudRepositoryProvider);

      final shouldLoadRoleCounts = allowedRolIds.isNotEmpty &&
          (state.roleCounts.isEmpty || refreshRoleCounts || (forceRefresh && state.searchQuery.isEmpty));

      final userPageFuture = repo.fetchUsersPage(
        query: state.searchQuery,
        rolIds: _effectiveRolIds,
        limit: pageSize,
        offset: nextOffset,
        activo: state.selectedActivo,
      );

      final roleCountsFuture = shouldLoadRoleCounts
          ? _loadRoleCounts()
          : Future.value(state.roleCounts);

      final results = await Future.wait([
        userPageFuture,
        roleCountsFuture,
      ]);
      final result = results[0] as ({List<Map<String, dynamic>> items, int total});
      final roleCounts = results[1] as Map<int, int>;

      final updatedCache = Map<int, List<Map<String, dynamic>>>.from(state.cachedPages);
      if (!state.activeFilters) {
        updatedCache[nextOffset] = result.items;
      }

      state = state.copyWith(
        isLoading: false,
        users: result.items,
        totalItems: result.total,
        roleCounts: roleCounts,
        cachedPages: updatedCache,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error al cargar usuarios: $e",
      );
    }
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query, offset: 0, cachedPages: const {});
    loadPage(offset: 0, forceRefresh: true);
  }

  void toggleRol(int rolId) {
    final next = Set<int>.from(state.selectedRolIds);
    if (next.contains(rolId)) {
      next.remove(rolId);
    } else {
      next.add(rolId);
    }
    state = state.copyWith(selectedRolIds: next, offset: 0, cachedPages: const {});
    loadPage(offset: 0, forceRefresh: true);
  }

  void setStatusFilter(bool? activo) {
    if (state.selectedActivo == activo) return;
    if (activo == null) {
      state = state.copyWith(clearActivo: true, offset: 0, cachedPages: const {});
    } else {
      state = state.copyWith(selectedActivo: activo, offset: 0, cachedPages: const {});
    }
    loadPage(offset: 0, forceRefresh: true);
  }

  void clearFilters() {
    state = state.copyWith(searchQuery: "", selectedRolIds: {}, clearActivo: true, offset: 0, cachedPages: const {});
    loadPage(offset: 0, forceRefresh: true);
  }

  Future<void> toggleUserStatus(String userId, bool currentStatus) async {
    // Optimistic UI and cache invalidation
    final oldUsers = List<Map<String, dynamic>>.from(state.users);
    final nextUsers = oldUsers.map((u) {
      if (u["id"] == userId) {
        return {...u, "activo": !currentStatus};
      }
      return u;
    }).toList();

    state = state.copyWith(users: nextUsers, cachedPages: const {});

    try {
      final repo = _ref.read(supabaseCrudRepositoryProvider);
      await repo.updateUser(userId: userId, activo: !currentStatus);
    } catch (e) {
      state = state.copyWith(
          users: oldUsers, errorMessage: "Error al actualizar estado");
    }
  }

  Future<bool> deleteUser(String userId) async {
    final oldUsers = List<Map<String, dynamic>>.from(state.users);
    final nextUsers = oldUsers.where((u) => u["id"] != userId).toList();

    state = state.copyWith(
        users: nextUsers,
        totalItems: state.totalItems - 1,
        cachedPages: const {});

    try {
      final dio = _ref.read(dioProvider);
      await dio.delete("usuarios/$userId");
      return true;
    } catch (e) {
      state = state.copyWith(
          users: oldUsers,
          totalItems: state.totalItems + 1,
          errorMessage: "Error al eliminar usuario");
      return false;
    }
  }

  Future<bool> resendInviteEmail(String userId) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.post("usuarios/$userId/reenviar-invitacion");
      return true;
    } catch (e) {
      state = state.copyWith(
          errorMessage: "Error al reenviar correo de configuración");
      return false;
    }
  }
}

final adminUsersProvider =
    StateNotifierProvider<AdminUsersNotifier, AdminUsersState>((ref) {
  return AdminUsersNotifier(ref, allowedRolIds: const {1, 2, 3});
});

// Proveedor para Tutores (Filtra por id_rol = 4 por defecto)
final adminTutorsProvider =
    StateNotifierProvider<AdminUsersNotifier, AdminUsersState>((ref) {
  return AdminUsersNotifier(
    ref,
    allowedRolIds: const {4},
    initialSelectedRolIds: const {4},
  );
});
