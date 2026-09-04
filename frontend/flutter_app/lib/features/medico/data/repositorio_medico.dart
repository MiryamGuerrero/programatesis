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

  Future<({List<Map<String, dynamic>> items, int total})> fetchPatientsPage({
    String query = "",
    int limit = 10,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      "pacientes",
      queryParameters: {
        "q": query,
        "limit": limit,
        "offset": offset,
        "include_total": true,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (
      items: _toRows(data["items"]),
      total: (data["total"] as num?)?.toInt() ?? 0,
    );
  }

  Future<({List<Map<String, dynamic>> items, int total})> fetchMedicalRulesPage({
    String query = "",
    int limit = 10,
    int offset = 0,
    String? origen,
    int? idCondicion,
    int? idAccion,
    int? idTipoObjetivo,
    int? idObjetivo,
  }) async {
    final response = await _dio.get(
      "reglas-medicas",
      queryParameters: {
        "q": query,
        "limit": limit,
        "offset": offset,
        "include_total": true,
        "q": query,
        if (origen != null) "origen": origen,
        if (idCondicion != null) "id_condicion": idCondicion,
        if (idAccion != null) "id_accion": idAccion,
        if (idTipoObjetivo != null) "id_tipo_objetivo": idTipoObjetivo,
        if (idObjetivo != null) "id_objetivo": idObjetivo,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (
      items: _toRows(data["items"]),
      total: (data["total"] as num?)?.toInt() ?? 0,
    );
  }

  Future<({List<Map<String, dynamic>> items, int total})>
      fetchMedicalConditionsPage({
    String query = "",
    int? tipo,
    int limit = 10,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      "catalogos/condiciones",
      queryParameters: {
        "q": query,
        if (tipo != null) "tipo": tipo,
        "limit": limit,
        "offset": offset,
        "include_total": true,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (
      items: _toRows(data["items"]),
      total: (data["total"] as num?)?.toInt() ?? 0,
    );
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

  final Map<String, Map<String, dynamic>> _expedienteCache = {};
  Map<String, List<Map<String, dynamic>>>? _catalogosCache;
  List<dynamic>? _condicionesCache;
  List<dynamic>? _ingredientesSimpleCache;
  List<dynamic>? _subgruposSimpleCache;

  bool hasCachedExpediente(String idPaciente) => _expedienteCache.containsKey(idPaciente);

  Map<String, dynamic>? getCachedExpediente(String idPaciente) => _expedienteCache[idPaciente];

  void invalidateExpediente(String idPaciente) {
    _expedienteCache.remove(idPaciente);
  }

  void invalidateAllExpedientes() {
    _expedienteCache.clear();
  }

  void invalidateCatalogos() {
    _catalogosCache = null;
    _condicionesCache = null;
    _ingredientesSimpleCache = null;
    _subgruposSimpleCache = null;
  }

  Future<Map<String, dynamic>> obtenerExpedienteCompleto(
      String idPaciente, {bool forceReload = false}) async {
    if (!forceReload && _expedienteCache.containsKey(idPaciente)) {
      return _expedienteCache[idPaciente]!;
    }
    final response =
        await _dio.get("pacientes/$idPaciente/expediente-completo");
    final data = Map<String, dynamic>.from(response.data);
    _expedienteCache[idPaciente] = data;
    return data;
  }

  Future<List<dynamic>> obtenerCondicionesCatalogo({bool forceReload = false}) async {
    if (!forceReload && _condicionesCache != null) {
      return _condicionesCache!;
    }
    final response = await _dio.get("catalogos/condiciones");
    final data = response.data as List? ?? [];
    _condicionesCache = data;
    return data;
  }

  Future<List<dynamic>> obtenerIngredientesCatalogoSimple({bool forceReload = false}) async {
    if (!forceReload && _ingredientesSimpleCache != null) {
      return _ingredientesSimpleCache!;
    }
    final response = await _dio.get("nutricionista/ingredientes/catalogo-simple");
    final data = response.data as List? ?? [];
    _ingredientesSimpleCache = data;
    return data;
  }

  Future<List<dynamic>> obtenerSubgruposCatalogoSimple({bool forceReload = false}) async {
    if (!forceReload && _subgruposSimpleCache != null) {
      return _subgruposSimpleCache!;
    }
    final response = await _dio.get("nutricionista/subgrupos/catalogo-simple");
    final data = response.data as List? ?? [];
    _subgruposSimpleCache = data;
    return data;
  }

  Future<Map<String, dynamic>> obtenerEvolucionMensual(
    String idPaciente, {
    String? fechaInicio,
    String? fechaFin,
    String? estadoEnfermedad,
    bool? enBrote,
    String? estadoNutricional,
    bool soloAlterados = false,
  }) async {
    final response = await _dio.get(
      "pacientes/$idPaciente/evolucion-mensual",
      queryParameters: {
        if (fechaInicio != null) "fecha_inicio": fechaInicio,
        if (fechaFin != null) "fecha_fin": fechaFin,
        if (estadoEnfermedad != null && estadoEnfermedad.isNotEmpty)
          "estado_enfermedad": estadoEnfermedad,
        if (enBrote != null) "en_brote": enBrote,
        if (estadoNutricional != null && estadoNutricional.isNotEmpty)
          "estado_nutricional": estadoNutricional,
        "solo_alterados": soloAlterados,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> obtenerConsumoAlimentario(
    String idPaciente, {
    int dias = 180,
  }) async {
    final response = await _dio.get(
      "pacientes/$idPaciente/consumo-alimentario",
      queryParameters: {"dias": dias},
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> registrarPacienteIntegral(Map<String, dynamic> payload) async {
    await _dio.post("registro/paciente-integral", data: payload);
    invalidateAllExpedientes();
  }

  Future<void> actualizarExpedienteMaestro(
    String idPaciente,
    Map<String, dynamic> payload,
  ) async {
    await _dio.put("pacientes/$idPaciente/expediente-maestro", data: payload);
    invalidateExpediente(idPaciente);
  }

  Future<void> archivarPaciente(String idPaciente) async {
    await _dio.patch("pacientes/$idPaciente/archivar");
    invalidateExpediente(idPaciente);
  }

  Future<void> eliminarPaciente(String idPaciente) async {
    await archivarPaciente(idPaciente);
  }

  Future<Map<String, dynamic>> buscarTutorPorCedula(String cedula) async {
    final response = await _dio.get("usuarios/tutor-by-cedula/$cedula");
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> verificarPacientePorCedula(String cedula) async {
    final response = await _dio.get("pacientes/cedula/$cedula/existe");
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      obtenerCatalogosRegistroPaciente({bool forceReload = false}) async {
    if (!forceReload && _catalogosCache != null) {
      return _catalogosCache!;
    }
    final response = await _dio.get("registro/paciente-integral/catalogos");
    final data = Map<String, dynamic>.from(response.data as Map);
    final mapped = data.map((key, value) => MapEntry(key, _toRows(value)));
    _catalogosCache = mapped;
    return mapped;
  }

  Future<Map<String, dynamic>> preDiagnosticoNutricional(
    Map<String, dynamic> payload,
  ) async {
    final response =
        await _dio.post("pre-diagnostico-nutricional", data: payload);
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
