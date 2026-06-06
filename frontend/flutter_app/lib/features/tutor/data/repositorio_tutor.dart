import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/state/app_providers.dart";

final repositorioTutorProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return RepositorioTutor(dio);
});

class RepositorioTutor {
  final Dio _dio;
  RepositorioTutor(this._dio);

  /// Obtiene el menú planificado para un día específico
  Future<List<Map<String, dynamic>>> obtenerPlanDiario(String idPaciente, String fecha) async {
    try {
      final response = await _dio.get("tutor/plan-diario/$idPaciente", queryParameters: {
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
      final response = await _dio.post("tutor/registrar-consumo", data: {
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
      final response = await _dio.get("tutor/adherencia/$idPaciente", queryParameters: {
        "dias": dias,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception("Error al cargar adherencia: ${e.message}");
    }
  }

  Future<Map<String, dynamic>> generarPlanAutomatico({
    required String idPaciente,
    required int dias,
    required DateTime fechaInicio,
    required List<int> momentosObligatorios,
    required List<int> momentosOpcionales,
  }) async {
    try {
      final response = await _dio.post("tutor/generar-plan-automatico", data: {
        "id_paciente": idPaciente,
        "dias": dias,
        "fecha_inicio": fechaInicio.toIsoformat(),
        "momentos_obligatorios": momentosObligatorios,
        "momentos_opcionales": momentosOpcionales,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception("Error al generar plan automático: ${e.message}");
    }
  }

  Future<Map<String, dynamic>> intercambiarRecetaPlan(int idPlanItem) async {
    try {
      final response = await _dio.post("tutor/intercambiar-receta-plan", data: {
        "id_plan_item": idPlanItem,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception("Error al intercambiar receta: ${e.message}");
    }
  }

  Future<Map<String, dynamic>> obtenerTipSaludable() async {
    try {
      final response = await _dio.get("tutor/tips-saludables");
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception("Error al cargar tip saludable: ${e.message}");
    }
  }
}

extension DateTimeExtension on DateTime {
  String toIsoformat() {
    return "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
  }
  }

