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
    try {
      // Rutas relativas para que Dio use el BaseUrl /api/v1 correctamente
      final response = await _dio.post(path, data: payload);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (exc) {
      final code = exc.response?.statusCode;
      final data = exc.response?.data;
      String msg = "Error API $code";
      if (data is Map && data["detail"] != null) msg = data["detail"].toString();
      throw Exception(msg);
    }
  }

  // --- MÉTODOS COMPARTIDOS ---
  
  Future<Map<String, dynamic>> calcularImc({required double pesoKg, required double tallaCm}) {
    return _post("imc-calculo", {"peso_kg": pesoKg, "talla_cm": tallaCm});
  }

  Future<Map<String, dynamic>> diagnosticoOms({required String indicadorCodigo, required int idSexo, required int edadMeses, required double valor}) {
    return _post("diagnostico-oms", {"indicador_codigo": indicadorCodigo, "id_sexo": idSexo, "edad_meses": edadMeses, "valor": valor});
  }

  Future<Map<String, dynamic>> reglasEvaluacion({required List<int> condiciones, List<int> ingredientes = const [], List<int> grupos = const [], List<int> etiquetas = const []}) {
    return _post("reglas-evaluacion", {"id_condiciones": condiciones, "ingrediente_ids": ingredientes, "grupo_ids": grupos, "etiqueta_ids": etiquetas});
  }

  Future<Map<String, dynamic>> ingredientesPermitidos(String idPaciente) {
    return _post("ingredientes-permitidos", {"id_paciente": idPaciente});
  }

  Future<Map<String, dynamic>> recetasPermitidas({required String idPaciente, int? idMomento}) {
    return _post("recetas-permitidas", {"id_paciente": idPaciente, "id_momento": idMomento});
  }

  Future<Map<String, dynamic>> planAutomatico({required String idPaciente, required DateTime fechaInicio, int dias = 7, int comidasPorDia = 4}) {
    return _post("plan-automatico", {"id_paciente": idPaciente, "fecha_inicio": fechaInicio.toIso8601String().split("T").first, "dias": dias, "comidas_por_dia": comidasPorDia});
  }

  Future<Map<String, dynamic>> reemplazoEquivalente({required int idIngredienteOriginal, double? cantidadGramos}) {
    return _post("reemplazo-equivalente", {"id_ingrediente_original": idIngredienteOriginal, "cantidad_gramos": cantidadGramos});
  }

  Future<Map<String, dynamic>> adherenciaCalculo({required int idPlan}) {
    return _post("adherencia-calculo", {"id_plan": idPlan});
  }

  // --- MÉTODOS DEL NUTRICIONISTA ---

  Future<List<Map<String, dynamic>>> buscarPacientes(String query) async {
    final response = await _dio.get("buscar-pacientes", queryParameters: {"q": query});
    return List<Map<String, dynamic>>.from(response.data as List);
  }

  Future<Map<String, dynamic>> obtenerPacientePerfil(String idPaciente) async {
    final response = await _dio.get("paciente-perfil/$idPaciente");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> ingredientesLista({String q = "", int? cat, int? subcat, bool? active, int limit = 10, int offset = 0}) async {
    final response = await _dio.get("ingredientes-lista", queryParameters: {
      "q": q, 
      if (cat != null) "cat": cat, 
      if (subcat != null) "subcat": subcat,
      if (active != null) "active": active, 
      "limit": limit, 
      "offset": offset
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> obtenerIngredienteDetalle(int id) async {
    final response = await _dio.get("nutricionista/ingredientes/$id");
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> guardarIngrediente(int id, Map<String, dynamic> data) async {
    if (id > 0) {
      await _dio.put("nutricionista/ingredientes/$id", data: data);
    } else {
      await _dio.post("nutricionista/ingredientes", data: data);
    }
  }

  Future<void> eliminarIngrediente(int id) async {
    await _dio.delete("nutricionista/ingredientes/$id");
  }

  Future<Map<String, dynamic>> guardarPlanManual({required String idPaciente, required Map<String, dynamic> plan, bool replicate = true}) {
    return _post("plan-manual", {"id_paciente": idPaciente, "plan": plan, "replicate": replicate});
  }
}
