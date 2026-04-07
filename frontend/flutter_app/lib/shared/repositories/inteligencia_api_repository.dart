import "package:dio/dio.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class InteligenciaApiRepository {
  InteligenciaApiRepository({
    required Dio dio,
    required SupabaseClient supabaseClient,
  })  : _dio = dio,
        _supabaseClient = supabaseClient;

  final Dio _dio;
  final SupabaseClient _supabaseClient;

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    final token = _supabaseClient.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception("Sesion expirada. Inicia sesion nuevamente.");
    }

    try {
      final response = await _dio.post(
        path,
        data: payload,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
          },
        ),
      );

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (exc) {
      final code = exc.response?.statusCode;
      if (code == 401) {
        throw Exception("Sesion expirada. Inicia sesion nuevamente.");
      }
      if (code == 403) {
        throw Exception("No tienes permisos para ejecutar esta accion.");
      }

      final data = exc.response?.data;
      if (data is Map && data["detail"] != null) {
        throw Exception(data["detail"].toString());
      }

      if (data is Map && data["message"] != null) {
        throw Exception(data["message"].toString());
      }

      if (exc.type == DioExceptionType.connectionTimeout ||
          exc.type == DioExceptionType.sendTimeout ||
          exc.type == DioExceptionType.receiveTimeout ||
          exc.type == DioExceptionType.connectionError) {
        throw Exception("No hay conexion con backend para $path");
      }

      throw Exception("Error API ${code ?? "desconocido"} en $path");
    }
  }

  Future<Map<String, dynamic>> calcularImc({
    required double pesoKg,
    required double tallaCm,
  }) {
    return _post("/imc-calculo", {
      "peso_kg": pesoKg,
      "talla_cm": tallaCm,
    });
  }

  Future<Map<String, dynamic>> diagnosticoOms({
    required String indicadorCodigo,
    required int idSexo,
    required int edadMeses,
    required double valor,
  }) {
    return _post("/diagnostico-oms", {
      "indicador_codigo": indicadorCodigo,
      "id_sexo": idSexo,
      "edad_meses": edadMeses,
      "valor": valor,
    });
  }

  Future<Map<String, dynamic>> reglasEvaluacion({
    required List<int> condiciones,
    List<int> ingredientes = const [],
    List<int> grupos = const [],
    List<int> etiquetas = const [],
  }) {
    return _post("/reglas-evaluacion", {
      "id_condiciones": condiciones,
      "ingrediente_ids": ingredientes,
      "grupo_ids": grupos,
      "etiqueta_ids": etiquetas,
    });
  }

  Future<Map<String, dynamic>> ingredientesPermitidos(String idPaciente) {
    return _post("/ingredientes-permitidos", {
      "id_paciente": idPaciente,
    });
  }

  Future<Map<String, dynamic>> recetasPermitidas({
    required String idPaciente,
    int? idMomento,
  }) {
    return _post("/recetas-permitidas", {
      "id_paciente": idPaciente,
      "id_momento": idMomento,
    });
  }

  Future<Map<String, dynamic>> planAutomatico({
    required String idPaciente,
    required DateTime fechaInicio,
    int dias = 7,
    int comidasPorDia = 4,
  }) {
    return _post("/plan-automatico", {
      "id_paciente": idPaciente,
      "fecha_inicio": fechaInicio.toIso8601String().split("T").first,
      "dias": dias,
      "comidas_por_dia": comidasPorDia,
    });
  }

  Future<Map<String, dynamic>> reemplazoEquivalente({
    required int idIngredienteOriginal,
    double? cantidadGramos,
  }) {
    return _post("/reemplazo-equivalente", {
      "id_ingrediente_original": idIngredienteOriginal,
      "cantidad_gramos": cantidadGramos,
    });
  }

  Future<Map<String, dynamic>> adherenciaCalculo({required int idPlan}) {
    return _post("/adherencia-calculo", {
      "id_plan": idPlan,
    });
  }

  Future<Map<String, dynamic>> preferenciasAprendidas({
    required String idPaciente,
    bool persistir = false,
  }) {
    return _post("/preferencias-aprendidas", {
      "id_paciente": idPaciente,
      "persistir": persistir,
    });
  }
}
