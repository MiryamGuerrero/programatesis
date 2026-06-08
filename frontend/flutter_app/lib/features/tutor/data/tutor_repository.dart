import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/network/api_client.dart";

final tutorRepositoryProvider = Provider((ref) {
  final dio =
      buildApiClient(); // En una app real, vendría de un provider de dio
  return TutorRepository(dio);
});

class TutorRepository {
  final Dio _dio;
  TutorRepository(this._dio);

  Future<Map<String, dynamic>> evaluarReglasPaciente(String idPaciente) async {
    try {
      final response = await _dio
          .get("/api/v1/nutricionista/paciente/$idPaciente/evaluar-reglas");
      return response.data;
    } on DioException catch (e) {
      throw Exception("Error al evaluar reglas: ${e.message}");
    }
  }
}
