import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

class AdminUsersState {
  final bool isLoading;
  final List<Map<String, dynamic>> users;
  final String searchQuery;
  final Set<int> selectedRolIds;
  final int totalItems;
  final int offset;
  final String? errorMessage;

  const AdminUsersState({
    this.isLoading = true,
    this.users = const [],
    this.searchQuery = "",
    this.selectedRolIds = const {},
    this.totalItems = 0,
    this.offset = 0,
    this.errorMessage,
  });

  AdminUsersState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? users,
    String? searchQuery,
    Set<int>? selectedRolIds,
    int? totalItems,
    int? offset,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AdminUsersState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRolIds: selectedRolIds ?? this.selectedRolIds,
      totalItems: totalItems ?? this.totalItems,
      offset: offset ?? this.offset,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get activeFilters => searchQuery.isNotEmpty || selectedRolIds.isNotEmpty;
}

class AdminUsersNotifier extends StateNotifier<AdminUsersState> {
  AdminUsersNotifier(this._ref) : super(const AdminUsersState());

  final Ref _ref;
  static const int pageSize = 5;

  Future<void> loadPage({int? offset}) async {
    final nextOffset = offset ?? state.offset;
    state = state.copyWith(isLoading: true, offset: nextOffset, clearErrorMessage: true);
    
    try {
      final repo = _ref.read(supabaseCrudRepositoryProvider);
      final result = await repo.fetchUsersPage(
        query: state.searchQuery,
        rolIds: state.selectedRolIds.toList(),
        limit: pageSize,
        offset: nextOffset,
      );
      
      state = state.copyWith(
        isLoading: false,
        users: result.items,
        totalItems: result.total,
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
    state = state.copyWith(searchQuery: query, offset: 0);
    loadPage(offset: 0);
  }

  void toggleRol(int rolId) {
    final next = Set<int>.from(state.selectedRolIds);
    if (next.contains(rolId)) {
      next.remove(rolId);
    } else {
      next.add(rolId);
    }
    state = state.copyWith(selectedRolIds: next, offset: 0);
    loadPage(offset: 0);
  }

  void clearFilters() {
    state = state.copyWith(searchQuery: "", selectedRolIds: {}, offset: 0);
    loadPage(offset: 0);
  }

  Future<void> toggleUserStatus(String userId, bool currentStatus) async {
    // Optimistic UI
    final oldUsers = List<Map<String, dynamic>>.from(state.users);
    final nextUsers = oldUsers.map((u) {
      if (u["id"] == userId) {
        return {...u, "activo": !currentStatus};
      }
      return u;
    }).toList();
    
    state = state.copyWith(users: nextUsers);
    
    try {
      final repo = _ref.read(supabaseCrudRepositoryProvider);
      await repo.updateUser(userId: userId, activo: !currentStatus);
    } catch (e) {
      state = state.copyWith(users: oldUsers, errorMessage: "Error al actualizar estado");
    }
  }

  Future<void> deleteUser(String userId) async {
    final oldUsers = List<Map<String, dynamic>>.from(state.users);
    final nextUsers = oldUsers.where((u) => u["id"] != userId).toList();
    
    state = state.copyWith(users: nextUsers, totalItems: state.totalItems - 1);
    
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete("usuarios/$userId");
    } catch (e) {
      state = state.copyWith(users: oldUsers, totalItems: state.totalItems + 1, errorMessage: "Error al eliminar usuario");
    }
  }
}

// Proveedor para Equipo Médico (Excluye Tutor si no se selecciona)
final adminUsersProvider = StateNotifierProvider<AdminUsersNotifier, AdminUsersState>((ref) {
  return AdminUsersNotifier(ref);
});

// Proveedor para Tutores (Filtra por id_rol = 4 por defecto)
final adminTutorsProvider = StateNotifierProvider<AdminUsersNotifier, AdminUsersState>((ref) {
  final notifier = AdminUsersNotifier(ref);
  // Inicializamos con rol de tutor (id_rol = 4)
  notifier.state = notifier.state.copyWith(selectedRolIds: {4});
  return notifier;
});
