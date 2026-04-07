import "package:dio/dio.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class SupabaseCrudRepository {
  SupabaseCrudRepository(this._client, this._dio);

  final SupabaseClient _client;
  final Dio _dio;

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

  Exception _toException(DioException error, String fallbackMessage) {
    final statusCode = error.response?.statusCode;

    if (statusCode == 401) {
      return Exception("Sesion expirada. Inicia sesion nuevamente.");
    }
    if (statusCode == 403) {
      return Exception("No tienes permisos para realizar esta accion.");
    }

    final payload = error.response?.data;
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);

      final detail = map["detail"];
      if (detail is String && detail.trim().isNotEmpty) {
        return Exception(detail);
      }
      if (detail is List && detail.isNotEmpty) {
        return Exception(detail.map((e) => e.toString()).join(" | "));
      }
      if (map["message"] is String && (map["message"] as String).trim().isNotEmpty) {
        return Exception(map["message"].toString());
      }
      if (map["error"] is String && (map["error"] as String).trim().isNotEmpty) {
        return Exception(map["error"].toString());
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return Exception("$fallbackMessage. Verifica la conexion con el backend.");
    }

    return Exception("$fallbackMessage (HTTP ${statusCode ?? "desconocido"})");
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final response = await _dio.get(
        "/crud/users",
        options: _authorizedOptions(),
      );
      return _toRows(response.data);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar usuarios");
    }
  }

  Future<void> createUser({
    required String email,
    required String nombreCompleto,
    required int idRol,
  }) async {
    try {
      await _dio.post(
        "/crud/users",
        data: {
          "email": email,
          "nombre_completo": nombreCompleto,
          "id_rol": idRol,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible crear el usuario");
    }
  }

  Future<List<Map<String, dynamic>>> fetchIngredientes() async {
    try {
      final response = await _dio.get(
        "/crud/ingredientes",
        options: _authorizedOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar ingredientes");
    }
  }

  Future<void> createIngrediente({
    required String nombre,
    int? idGrupoAlimentario,
  }) async {
    try {
      await _dio.post(
        "/crud/ingredientes",
        data: {
          "nombre": nombre,
          "id_grupo_alimentario": idGrupoAlimentario,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible crear el ingrediente");
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecetas() async {
    try {
      final response = await _dio.get(
        "/crud/recetas",
        options: _authorizedOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar recetas");
    }
  }

  Future<void> createClinicalControl({
    required String idPaciente,
    required double pesoKg,
    required double tallaCm,
    required int edadMeses,
    int? dolor,
    int? inflamacion,
    double? imc,
  }) async {
    try {
      await _dio.post(
        "/crud/controles",
        data: {
          "id_paciente": idPaciente,
          "peso_kg": pesoKg,
          "talla_cm": tallaCm,
          "edad_meses": edadMeses,
          "nivel_dolor_eva": dolor,
          "nivel_inflamacion": inflamacion,
          "imc_calculado": imc,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible guardar el control clinico");
    }
  }

  Future<List<Map<String, dynamic>>> fetchPlanItemsByPaciente(
      String idPaciente) async {
    try {
      final response = await _dio.get(
        "/crud/plan-items",
        queryParameters: {
          "id_paciente": idPaciente,
        },
        options: _authorizedOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar el plan del paciente");
    }
  }

  Future<void> registerConsumption({
    required int idPlanItem,
    required String estadoCodigo,
    int? idRecetaReemplazo,
    String? observacion,
  }) async {
    try {
      await _dio.post(
        "/crud/consumos",
        data: {
          "id_plan_item": idPlanItem,
          "estado_codigo": estadoCodigo,
          "id_receta_reemplazo": idRecetaReemplazo,
          "observacion": observacion,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible guardar el consumo");
    }
  }

  Future<void> rateRecipe({
    required String idPaciente,
    required int idReceta,
    required int estrellas,
    String? comentario,
  }) async {
    try {
      await _dio.post(
        "/crud/evaluaciones",
        data: {
          "id_paciente": idPaciente,
          "id_receta": idReceta,
          "estrellas": estrellas,
          "comentario": comentario,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible guardar la calificacion");
    }
  }

  Future<List<Map<String, dynamic>>> fetchCatalog(
      String schema, String table) async {
    try {
      final response = await _dio.get(
        "/crud/catalog",
        queryParameters: {
          "schema": schema,
          "table": table,
        },
        options: _authorizedOptions(),
      );
      return _toRows(response.data);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar el catalogo");
    }
  }
}
