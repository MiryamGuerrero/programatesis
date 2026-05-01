import "package:dio/dio.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class SupabaseCrudRepository {
  SupabaseCrudRepository(this._client, this._dio);

  final SupabaseClient _client;
  final Dio _dio;

  List<Map<String, dynamic>> _toRows(dynamic payload) {
    if (payload is! List) return const [];
    return payload.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Options _authorizedOptions() {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) throw Exception("Sesión expirada");
    return Options(headers: {"Authorization": "Bearer $token"});
  }

  // --- GESTIÓN DE USUARIOS Y PERFIL ---
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final response = await _dio.get("usuarios", options: _authorizedOptions());
    return _toRows(response.data);
  }

  Future<void> createUser({
    required String email, 
    required String nombreCompleto, 
    required int idRol, 
    required String password,
    String? cedula,
    String? telefono,
    String? direccion,
  }) async {
    await _dio.post(
      "usuarios",
      data: {
        "email": email, 
        "nombre_completo": nombreCompleto, 
        "id_rol": idRol, 
        "password": password,
        "cedula": cedula,
        "telefono": telefono,
        "direccion": direccion,
      },
      options: _authorizedOptions(),
    );
  }

  Future<void> updateUser({
    required String userId, 
    String? email, 
    String? nombreCompleto, 
    String? cedula, 
    int? idRol, 
    bool? activo,
    String? telefono,
    String? direccion,
  }) async {
    final payload = <String, dynamic>{};
    if (email != null) payload["email"] = email;
    if (nombreCompleto != null) payload["nombre_completo"] = nombreCompleto;
    if (cedula != null) payload["cedula"] = cedula;
    if (idRol != null) payload["id_rol"] = idRol;
    if (activo != null) payload["activo"] = activo;
    if (telefono != null) payload["telefono"] = telefono;
    if (direccion != null) payload["direccion"] = direccion;
    await _dio.put("usuarios/$userId", data: payload, options: _authorizedOptions());
  }

  Future<Map<String, dynamic>> fetchMyProfile() async {
    final response = await _dio.get("mi-perfil", options: _authorizedOptions());
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> updateMyProfile({
    String? nombreCompleto,
    String? cedula,
    String? telefono,
    String? direccion,
    String? email,
  }) async {
    final data = <String, dynamic>{};
    if (nombreCompleto != null) data["nombre_completo"] = nombreCompleto;
    if (cedula != null) data["cedula"] = cedula;
    if (telefono != null) data["telefono"] = telefono;
    if (direccion != null) data["direccion"] = direccion;
    if (email != null) data["email"] = email;
    await _dio.put("mi-perfil", data: data, options: _authorizedOptions());
  }

  // --- CLÍNICO: CONDICIONES Y CATÁLOGOS ---
  Future<void> createConditionType({required String codigo, required String nombre}) async {
    await _dio.post("crud/condition-types", data: {"codigo": codigo, "nombre": nombre}, options: _authorizedOptions());
  }

  Future<void> updateConditionType({required int idTipoCondicion, String? codigo, String? nombre}) async {
    final data = <String, dynamic>{};
    if (codigo != null) data["codigo"] = codigo;
    if (nombre != null) data["nombre"] = nombre;
    await _dio.put("crud/condition-types/$idTipoCondicion", data: data, options: _authorizedOptions());
  }

  Future<void> createCondition({String? codigo, required String nombre, required int idTipoCondicion, String? descripcion, bool activa = true}) async {
    await _dio.post("crud/conditions", data: {"codigo": codigo, "nombre": nombre, "id_tipo": idTipoCondicion, "descripcion": descripcion, "activa": activa}, options: _authorizedOptions());
  }

  Future<void> updateCondition({required int idCondicion, String? codigo, String? nombre, int? idTipoCondicion, bool? activa, String? descripcion}) async {
    final data = <String, dynamic>{};
    if (codigo != null) data["codigo"] = codigo;
    if (nombre != null) data["nombre"] = nombre;
    if (idTipoCondicion != null) data["id_tipo"] = idTipoCondicion;
    if (activa != null) data["activa"] = activa;
    if (descripcion != null) data["descripcion"] = descripcion;
    await _dio.put("crud/conditions/$idCondicion", data: data, options: _authorizedOptions());
  }

  // --- CLÍNICO: PACIENTES Y TUTORES ---
  Future<void> registerTutorOnly({
    required String email,
    required String nombreCompleto,
    String? cedula,
    String? fono,
    String? direccion,
  }) async {
    await _dio.post(
      "registro/tutor-solo",
      data: {
        "email": email,
        "nombre_completo": nombreCompleto,
        "cedula": cedula,
        "telefono": fono,
        "direccion": direccion,
      },
      options: _authorizedOptions(),
    );
  }

  Future<void> rateRecipe({required int idReceta, required int calificacion, String? comentario}) async {
    await _dio.post("recetas/$idReceta/calificar", data: {"calificacion": calificacion, "comentario": comentario}, options: _authorizedOptions());
  }

  Future<List<Map<String, dynamic>>> fetchPlanItemsByPaciente(String idPaciente, {DateTime? fecha}) async {
    final f = (fecha ?? DateTime.now()).toIso8601String().split("T").first;
    final response = await _dio.get("plan-diario/$idPaciente", queryParameters: {"fecha": f}, options: _authorizedOptions());
    return _toRows(response.data);
  }

  Future<void> registerConsumption({required int idPlanItem, required int idEstadoConsumo, String? observacion}) async {
    await _dio.post("registrar-consumo", data: {"id_plan_item": idPlanItem, "id_estado_consumo": idEstadoConsumo, "observacion": observacion}, options: _authorizedOptions());
  }

  Future<List<Map<String, dynamic>>> fetchPatients() async {
    final response = await _dio.get("pacientes", options: _authorizedOptions());
    return _toRows(response.data);
  }

  Future<void> deletePatient(String idPaciente) async {
    await _dio.delete("pacientes/$idPaciente", options: _authorizedOptions());
  }

  Future<void> registerPatientOnly({
    required String nombreCompleto,
    required DateTime fechaNacimiento,
    required int idSexo,
    int? idCanton,
    int? idParroquia,
    String? cedula,
    String? fono,
    String? direccion,
    Map<String, dynamic>? controlClinicoInicial,
  }) async {
    await _dio.post(
      "pacientes",
      data: {
        "nombre_completo": nombreCompleto,
        "fecha_nacimiento": fechaNacimiento.toIso8601String().split("T").first,
        "id_sexo": idSexo,
        "id_canton": idCanton,
        "id_parroquia": idParroquia,
        "cedula": cedula,
        "telefono": fono,
        "direccion": direccion,
        "control_clinico_inicial": controlClinicoInicial,
      },
      options: _authorizedOptions(),
    );
  }

  Future<void> registerIntegral(Map<String, dynamic> payload) async {
    await _dio.post(
      "registro/paciente-integral",
      data: payload,
      options: _authorizedOptions(),
    );
  }

  Future<void> registerFullPatient({
    required Map<String, dynamic> identidad,
    required Map<String, dynamic> clinica,
    required List<int> alergias,
    required Map<String, dynamic> tutor,
    required int idCondicionPrincipal,
    List<int>? condicionesTemporales,
  }) async {
    // 1. Llamada al endpoint maestro del backend
    await _dio.post(
      "registro/paciente-integral",
      data: {
        "identidad": identidad,
        "clinica": clinica,
        "alergias": alergias,
        "tutor": tutor,
        "id_condicion_principal": idCondicionPrincipal,
        "condiciones_temporales": condicionesTemporales ?? [],
      },
      options: _authorizedOptions(),
    );
  }

  Future<Map<String, dynamic>?> findTutorByCedula(String cedula) async {
    final resp = await _dio.get("usuarios/tutor-by-cedula/$cedula", options: _authorizedOptions());
    return resp.data != null ? Map<String, dynamic>.from(resp.data) : null;
  }

  Future<Map<String, dynamic>?> fetchCurrentClinicalControl({required String idPaciente}) async {
    final resp = await _dio.get("pacientes/$idPaciente/control-actual", options: _authorizedOptions());
    return resp.data != null ? Map<String, dynamic>.from(resp.data) : null;
  }

  Future<void> updateCurrentClinicalControl({required String idPaciente, required Map<String, dynamic> controlClinico}) async {
    await _dio.put("pacientes/$idPaciente/control-actual", data: controlClinico, options: _authorizedOptions());
  }

  // --- VÍNCULOS Y BÚSQUEDA ---
  Future<List<Map<String, dynamic>>> fetchTutorPatientLinks() async {
    final response = await _dio.get("registro/vinculos", options: _authorizedOptions());
    return _toRows(response.data);
  }

  Future<List<Map<String, dynamic>>> searchTutors({required String query, int limit = 10}) async {
    final resp = await _dio.get("usuarios/buscar-tutores", queryParameters: {"q": query, "limit": limit}, options: _authorizedOptions());
    return _toRows(resp.data);
  }

  Future<void> linkTutorToPatient({required String idUsuarioTutor, required String idPaciente, required dynamic idParentesco, bool esPrincipal = false}) async {
    await _dio.post("registro/vincular", data: {"id_tutor": idUsuarioTutor, "id_paciente": idPaciente, "parentesco": idParentesco, "es_principal": esPrincipal}, options: _authorizedOptions());
  }

  Future<void> updateTutorPatientLink({required int idVinculo, dynamic idParentesco, bool? activo, bool? esPrincipal}) async {
    final data = <String, dynamic>{};
    if (idParentesco != null) data["parentesco"] = idParentesco;
    if (activo != null) data["activo"] = activo;
    if (esPrincipal != null) data["es_principal"] = esPrincipal;
    await _dio.put("registro/vinculos/$idVinculo", data: data, options: _authorizedOptions());
  }

  Future<void> unlinkTutorPatient({required int idVinculo}) async {
    await _dio.delete("registro/vinculos/$idVinculo", options: _authorizedOptions());
  }

  // --- RECETAS, INGREDIENTES Y CATÁLOGOS ---
  Future<List<Map<String, dynamic>>> fetchRecetas() async {
    final response = await _dio.get("crud/recetas", options: _authorizedOptions());
    return _toRows(response.data);
  }

  Future<List<Map<String, dynamic>>> fetchIngredientes() async {
    final response = await _dio.get("ingredientes", options: _authorizedOptions());
    return _toRows(response.data);
  }

  Future<List<Map<String, dynamic>>> fetchCatalog(String schema, String table) async {
    final response = await _dio.get("crud/catalog", queryParameters: {"schema": schema, "table": table}, options: _authorizedOptions());
    return _toRows(response.data);
  }

  Future<List<Map<String, dynamic>>> searchPatients({required String query, int limit = 10}) async {
    final resp = await _dio.get("pacientes-buscar", queryParameters: {"q": query, "limit": limit}, options: _authorizedOptions());
    return _toRows(resp.data);
  }
}
