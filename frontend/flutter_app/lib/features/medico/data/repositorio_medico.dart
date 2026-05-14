import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/state/app_providers.dart";

final repositorioMedicoProvider = Provider((ref) {
  return RepositorioMedico(ref.watch(dioProvider));
});

class RepositorioMedico {
  RepositorioMedico(this._dio);

  final Dio _dio;

  List<Map<String, dynamic>> _toRows(dynamic payload) {
    if (payload is! List) return const [];
    return payload.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listarPacientes() async {
    final response = await _dio.get("pacientes");
    return _toRows(response.data);
  }

  Future<List<Map<String, dynamic>>> buscarPacientes({
    required String query,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      "pacientes-buscar",
      queryParameters: {"q": query, "limit": limit},
    );
    return _toRows(response.data);
  }

  Future<Map<String, dynamic>> obtenerExpedienteCompleto(String idPaciente) async {
    final response = await _dio.get("pacientes/$idPaciente/expediente-completo");
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> registrarPacienteIntegral(Map<String, dynamic> payload) async {
    await _dio.post("registro/paciente-integral", data: payload);
  }

  Future<void> actualizarExpedienteMaestro(
    String idPaciente,
    Map<String, dynamic> payload,
  ) async {
    await _dio.put("pacientes/$idPaciente/expediente-maestro", data: payload);
  }

  Future<void> eliminarPaciente(String idPaciente) async {
    await _dio.delete("pacientes/$idPaciente");
  }

  Future<Map<String, dynamic>> buscarTutorPorCedula(String cedula) async {
    final response = await _dio.get("usuarios/tutor-by-cedula/$cedula");
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, List<Map<String, dynamic>>>> obtenerCatalogosRegistroPaciente() async {
    final response = await _dio.get("registro/paciente-integral/catalogos");
    final data = Map<String, dynamic>.from(response.data as Map);
    return data.map((key, value) => MapEntry(key, _toRows(value)));
  }

  Future<Map<String, dynamic>> preDiagnosticoNutricional(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post("pre-diagnostico-nutricional", data: payload);
    return Map<String, dynamic>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> obtenerSupervisionAdherencia() async {
    try {
      final response = await _dio.get("supervisar-adherencia-pacientes");
      return _toRows(response.data);
    } on DioException catch (e) {
      throw Exception("Error al cargar reporte medico: ${e.message}");
    }
  }
}
