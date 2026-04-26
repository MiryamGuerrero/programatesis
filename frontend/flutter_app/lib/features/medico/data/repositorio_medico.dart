import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/network/api_client.dart";

final repositorioMedicoProvider = Provider((ref) {
  final dio = buildApiClient();
  return RepositorioMedico(dio);
});

class RepositorioMedico {
  final Dio _dio;
  RepositorioMedico(this._dio);

  /// Obtiene el reporte de adherencia de todos los pacientes del médico
  Future<List<Map<String, dynamic>>> obtenerSupervisionAdherencia() async {
    try {
      final response = await _dio.get("/api/v1/medico/supervisar-adherencia-pacientes");
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw Exception("Error al cargar reporte médico: ${e.message}");
    }
  }
}
