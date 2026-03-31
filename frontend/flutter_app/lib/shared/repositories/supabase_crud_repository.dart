import "package:dio/dio.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class SupabaseCrudRepository {
  SupabaseCrudRepository(this._client, this._dio);

  final SupabaseClient _client;
  final Dio _dio;

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
    final payload = error.response?.data;
    if (payload is Map && payload["detail"] != null) {
      return Exception(payload["detail"].toString());
    }

    final statusCode = error.response?.statusCode;
    return Exception("$fallbackMessage (HTTP ${statusCode ?? "desconocido"})");
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final response = await _dio.get(
        "/crud/users",
        options: _authorizedOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data as List);
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
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar el catalogo");
    }
  }
}
