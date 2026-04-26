import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/network/api_client.dart";

final repositorioTutorProvider = Provider((ref) {
  final dio = buildApiClient();
  return RepositorioTutor(dio);
});

class RepositorioTutor {
  final Dio _dio;
  RepositorioTutor(this._dio);

  /// Obtiene el menú planificado para un día específico
  Future<List<Map<String, dynamic>>> obtenerPlanDiario(String idPaciente, String fecha) async {
    try {
      final response = await _dio.get("/api/v1/tutor/plan-diario/$idPaciente", queryParameters: {
        "fecha": fecha,
      });
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw Exception("Error al cargar plan diario: ${e.message}");
    }
  }

  /// Registra si una comida fue consumida o no
  Future<bool> registrarConsumo(int idPlanItem, int idEstadoConsumo, {String? observacion}) async {
    try {
      final response = await _dio.post("/api/v1/tutor/registrar-consumo", data: {
        "id_plan_item": idPlanItem,
        "id_estado_consumo": idEstadoConsumo,
        "observacion": observacion,
      });
      return response.data["success"] ?? false;
    } on DioException catch (e) {
      throw Exception("Error al registrar consumo: ${e.message}");
    }
  }

  /// Obtiene las estadísticas de cumplimiento
  Future<Map<String, dynamic>> obtenerEstadisticasAdherencia(String idPaciente, {int dias = 7}) async {
    try {
      final response = await _dio.get("/api/v1/tutor/adherencia/$idPaciente", queryParameters: {
        "dias": dias,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception("Error al cargar adherencia: ${e.message}");
    }
  }
}
