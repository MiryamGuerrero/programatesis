import "package:dio/dio.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class AdminAccountsSupabaseRepository {
  AdminAccountsSupabaseRepository(this._client, this._dio);

  final SupabaseClient _client;
  final Dio _dio;

  static const List<String> _allowedRoleCodes = [
    "admin",
    "medico",
    "nutricionista",
    "tutor",
  ];

  List<Map<String, dynamic>> _toRows(dynamic payload) {
    if (payload is! List) {
      return const [];
    }

    return payload
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Options _authorizedOptions() {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception("Sesion expirada. Inicia sesion nuevamente.");
    }

    return Options(
      headers: {
        "Authorization": "Bearer $token",
      },
    );
  }

  bool _isSchemaCacheUnavailable(PostgrestException error) {
    final code = (error.code ?? "").toUpperCase();
    final text = [error.message, error.details, error.hint]
        .whereType<String>()
        .join(" ")
        .toLowerCase();

    return code == "PGRST002" || text.contains("schema cache");
  }

  Exception _mapDioException(DioException error, String fallback) {
    final statusCode = error.response?.statusCode;

    if (statusCode == 401) {
      return Exception("Sesion expirada. Inicia sesion nuevamente.");
    }
    if (statusCode == 403) {
      return Exception("No tienes permisos de administrador para esta accion.");
    }

    final payload = error.response?.data;
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);

      final detail = map["detail"];
      if (detail is String && detail.trim().isNotEmpty) {
        return Exception(detail);
      }
      if (map["message"] is String && (map["message"] as String).trim().isNotEmpty) {
        return Exception(map["message"].toString());
      }
      if (map["error"] is String && (map["error"] as String).trim().isNotEmpty) {
        return Exception(map["error"].toString());
      }
    }

    return Exception("$fallback (HTTP ${statusCode ?? "desconocido"})");
  }

  Future<List<Map<String, dynamic>>> _fetchRolesViaBackend() async {
    try {
      final response = await _dio.get(
        "crud/catalog",
        queryParameters: {
          "schema": "usuarios",
          "table": "rol",
        },
        options: _authorizedOptions(),
      );

      return _toRows(response.data)
          .where((row) => _allowedRoleCodes.contains((row["codigo"] ?? "").toString().toLowerCase()))
          .toList();
    } on DioException catch (error) {
      throw _mapDioException(error, "No fue posible cargar roles");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsersViaBackend({
    String? search,
    bool includeInactive = true,
  }) async {
    try {
      final response = await _dio.get(
        "crud/users",
        options: _authorizedOptions(),
      );

      var rows = _toRows(response.data);

      if (!includeInactive) {
        rows = rows.where((row) => row["activo"] == true).toList();
      }

      final term = (search ?? "").trim().toLowerCase();
      if (term.isNotEmpty) {
        rows = rows.where((row) {
          final haystack = [
            row["nombre_completo"],
            row["cedula"],
            row["email"],
            row["username"],
          ].map((v) => (v ?? "").toString().toLowerCase()).join(" ");
          return haystack.contains(term);
        }).toList();
      }

      return rows;
    } on DioException catch (error) {
      throw _mapDioException(error, "No fue posible consultar cuentas");
    }
  }

  Exception _mapPostgrestException(PostgrestException error, String fallback) {
    final code = (error.code ?? "").toLowerCase();
    final raw = [error.message, error.details, error.hint]
        .whereType<String>()
        .join(" ")
        .toLowerCase();

    final isDuplicate =
        code == "23505" || raw.contains("duplicate key") || raw.contains("unique constraint");
    if (isDuplicate) {
      if (raw.contains("cedula")) {
        return Exception("La cedula ya existe.");
      }
      if (raw.contains("email")) {
        return Exception("El correo ya existe.");
      }
      if (raw.contains("username") || raw.contains("usuario")) {
        return Exception("El nombre de usuario ya existe.");
      }
      return Exception("Ya existe un registro con esos datos.");
    }

    final denied =
        code == "42501" ||
        code == "pgrst301" ||
        raw.contains("permission denied") ||
        raw.contains("row-level security") ||
        raw.contains("insufficient_privilege");
    if (denied) {
      return Exception("No tienes permisos de administrador para esta accion.");
    }

    if (error.message.trim().isNotEmpty) {
      return Exception(error.message.trim());
    }

    return Exception(fallback);
  }

  Future<List<Map<String, dynamic>>> fetchRoles() async {
    try {
      return await _fetchRolesViaBackend();
    } catch (_) {
      // Fall back to direct Supabase when backend is unavailable.
    }

    try {
      final response = await _client
          .schema("usuarios")
          .from("rol")
          .select("id,codigo,nombre")
          .inFilter("codigo", _allowedRoleCodes)
          .order("id");

      return _toRows(response);
    } on PostgrestException catch (error) {
      if (_isSchemaCacheUnavailable(error)) {
        return _fetchRolesViaBackend();
      }
      throw _mapPostgrestException(error, "No fue posible cargar roles");
    }
  }

  Future<List<Map<String, dynamic>>> fetchUsers({
    String? search,
    bool includeInactive = true,
  }) async {
    try {
      return await _fetchUsersViaBackend(
        search: search,
        includeInactive: includeInactive,
      );
    } catch (_) {
      // Fall back to direct Supabase when backend is unavailable.
    }

    try {
      final response = await _client.rpc(
        "admin_listar_cuentas_hu01",
        params: {
          "p_search": (search == null || search.trim().isEmpty) ? null : search.trim(),
          "p_include_inactive": includeInactive,
        },
      );

      return _toRows(response);
    } on PostgrestException catch (error) {
      if (_isSchemaCacheUnavailable(error)) {
        return _fetchUsersViaBackend(
          search: search,
          includeInactive: includeInactive,
        );
      }
      throw _mapPostgrestException(error, "No fue posible consultar cuentas");
    }
  }

  Future<void> createUser({
    required String cedula,
    required String username,
    required String email,
    required String nombreCompleto,
    required int idRol,
  }) async {
    try {
      await _dio.post(
        "crud/users",
        data: {
          "cedula": cedula.trim(),
          "username": username.trim().toLowerCase(),
          "email": email.trim().toLowerCase(),
          "nombre_completo": nombreCompleto.trim(),
          "id_rol": idRol,
        },
        options: _authorizedOptions(),
      );
      return;
    } on DioException catch (error) {
      throw _mapDioException(error, "No fue posible crear la cuenta");
    }
  }

  Future<void> updateUser({
    required String userId,
    String? cedula,
    String? username,
    String? email,
    String? nombreCompleto,
    int? idRol,
    bool? activo,
    String? deactivatedReason,
  }) async {
    final payload = <String, dynamic>{};

    if (cedula != null) {
      payload["cedula"] = cedula.trim();
    }
    if (username != null) {
      payload["username"] = username.trim().toLowerCase();
    }
    if (email != null) {
      payload["email"] = email.trim().toLowerCase();
    }
    if (nombreCompleto != null) {
      payload["nombre_completo"] = nombreCompleto.trim();
    }
    if (idRol != null) {
      payload["id_rol"] = idRol;
    }
    if (activo != null) {
      payload["activo"] = activo;
      payload["deactivated_reason"] = activo ? null : (deactivatedReason ?? "Desactivado por administrador");
    }

    if (payload.isEmpty) {
      return;
    }

    try {
      await _dio.put(
        "crud/users/$userId",
        data: {
          if (cedula != null) "cedula": cedula.trim(),
          if (username != null) "username": username.trim().toLowerCase(),
          if (email != null) "email": email.trim().toLowerCase(),
          if (nombreCompleto != null) "nombre_completo": nombreCompleto.trim(),
          if (idRol != null) "id_rol": idRol,
          if (activo != null) "activo": activo,
        },
        options: _authorizedOptions(),
      );
      return;
    } on DioException catch (_) {
      // Fall back to direct Supabase when backend is unavailable.
    }

    try {
      await _client.schema("usuarios").from("usuario").update(payload).eq("id", userId);
    } on PostgrestException catch (error) {
      if (_isSchemaCacheUnavailable(error)) {
        try {
          await _dio.put(
            "crud/users/$userId",
            data: {
              if (cedula != null) "cedula": cedula.trim(),
              if (username != null) "username": username.trim().toLowerCase(),
              if (email != null) "email": email.trim().toLowerCase(),
              if (nombreCompleto != null) "nombre_completo": nombreCompleto.trim(),
              if (idRol != null) "id_rol": idRol,
              if (activo != null) "activo": activo,
            },
            options: _authorizedOptions(),
          );
          return;
        } on DioException catch (dioError) {
          throw _mapDioException(dioError, "No fue posible actualizar la cuenta");
        }
      }
      throw _mapPostgrestException(error, "No fue posible actualizar la cuenta");
    }
  }

  Future<void> setUserActive({
    required String userId,
    required bool active,
    String? reason,
  }) async {
    return updateUser(
      userId: userId,
      activo: active,
      deactivatedReason: reason,
    );
  }

  Future<void> deleteUser({required String userId}) async {
    try {
      await _dio.delete(
        "crud/users/$userId",
        options: _authorizedOptions(),
      );
      return;
    } on DioException catch (_) {
      // Fall back to direct Supabase when backend is unavailable.
    }

    try {
      await _client.schema("usuarios").from("usuario").delete().eq("id", userId);
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error, "No fue posible eliminar la cuenta");
    }
  }
}
