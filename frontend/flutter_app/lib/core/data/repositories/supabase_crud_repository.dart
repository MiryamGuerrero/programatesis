import "package:dio/dio.dart";

class SupabaseCrudRepository {
  SupabaseCrudRepository(this._dio);

  final Dio _dio;
  final Map<String, List<Map<String, dynamic>>> _catalogCache = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _catalogRequests = {};

  List<Map<String, dynamic>> _toRows(dynamic payload) {
    if (payload is! List) return const [];
    return payload.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  // --- GESTIÓN DE USUARIOS Y PERFIL ---
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final response = await _dio.get("usuarios");
    return _toRows(response.data);
  }

  Future<({List<Map<String, dynamic>> items, int total})> fetchUsersPage({
    String query = "",
    List<int>? rolIds,
    int limit = 10,
    int offset = 0,
    bool? activo,
  }) async {
    final response = await _dio.get(
      "usuarios",
      queryParameters: {
        "q": query,
        if (rolIds != null && rolIds.isNotEmpty) "rol_ids": rolIds,
        "limit": limit,
        "offset": offset,
        "include_total": true,
        if (activo != null) "activo": activo,
      },
    );

    if (response.data is List) {
      final items = _toRows(response.data);
      return (items: items, total: items.length);
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    return (
      items: _toRows(data["items"]),
      total: (data["total"] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> createUser({
    required String email,
    required String nombreCompleto,
    required int idRol,
    String? password,
    String? username,
    String? cedula,
    String? telefono,
    String? direccion,
  }) async {
    await _dio.post(
      "usuarios",
      data: {
        "email": email,
        if (username != null && username.trim().isNotEmpty)
          "username": username.trim(),
        "nombre_completo": nombreCompleto,
        "id_rol": idRol,
        if (password != null && password.isNotEmpty) "password": password,
        "cedula": cedula,
        "telefono": telefono,
        "direccion": direccion,
      },
    );
  }

  Future<void> updateUser({
    required String userId,
    String? email,
    String? username,
    String? nombreCompleto,
    String? cedula,
    int? idRol,
    bool? activo,
    String? telefono,
    String? direccion,
  }) async {
    final payload = <String, dynamic>{};
    if (email != null) payload["email"] = email;
    if (username != null) payload["username"] = username;
    if (nombreCompleto != null) payload["nombre_completo"] = nombreCompleto;
    if (cedula != null) payload["cedula"] = cedula;
    if (idRol != null) payload["id_rol"] = idRol;
    if (activo != null) payload["activo"] = activo;
    if (telefono != null) payload["telefono"] = telefono;
    if (direccion != null) payload["direccion"] = direccion;
    await _dio.put("usuarios/$userId", data: payload);
  }

  Future<Map<String, dynamic>> fetchMyProfile() async {
    final response = await _dio.get("perfil/mi-perfil");
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> updateMyProfile({
    String? nombreCompleto,
    String? username,
    String? cedula,
    String? telefono,
    String? direccion,
    String? email,
  }) async {
    final data = <String, dynamic>{};
    if (nombreCompleto != null) data["nombre_completo"] = nombreCompleto;
    if (username != null) data["username"] = username;
    if (cedula != null) data["cedula"] = cedula;
    if (telefono != null) data["telefono"] = telefono;
    if (direccion != null) data["direccion"] = direccion;
    if (email != null) data["email"] = email;
    await _dio.put("perfil/mi-perfil", data: data);
  }

  // --- CLÍNICO: CONDICIONES Y CATÁLOGOS ---
  Future<void> createConditionType(
      {required String codigo, required String nombre}) async {
    await _dio.post("crud/condition-types",
        data: {"codigo": codigo, "nombre": nombre});
  }

  Future<void> updateConditionType(
      {required int idTipoCondicion, String? codigo, String? nombre}) async {
    final data = <String, dynamic>{};
    if (codigo != null) data["codigo"] = codigo;
    if (nombre != null) data["nombre"] = nombre;
    await _dio.put("crud/condition-types/$idTipoCondicion", data: data);
  }

  Future<void> createCondition({
    String? codigo,
    required String nombre,
    required int idTipoCondicion,
    String? descripcion,
    bool activa = true,
    int? duracionDiasSugerida,
  }) async {
    final Map<String, dynamic> data = {
      "nombre": nombre,
      "id_tipo": idTipoCondicion,
      "id_tipo_condicion": idTipoCondicion,
      "descripcion": descripcion,
      "activa": activa,
      "duracion_dias_sugerida":
          idTipoCondicion == 2 ? duracionDiasSugerida : null,
    };
    if (codigo != null) data["codigo"] = codigo;

    await _dio.post("catalogos/condiciones", data: data);
  }

  Future<void> updateCondition({
    required int idCondicion,
    String? codigo,
    required String nombre,
    required int idTipoCondicion,
    required bool activa,
    String? descripcion,
    int? duracionDiasSugerida,
  }) async {
    final Map<String, dynamic> data = {
      "nombre": nombre,
      "id_tipo": idTipoCondicion,
      "id_tipo_condicion": idTipoCondicion,
      "activa": activa,
      "descripcion": descripcion,
    };

    if (codigo != null) data["codigo"] = codigo;
    if (idTipoCondicion == 2) {
      data["duracion_dias_sugerida"] = duracionDiasSugerida;
    } else {
      data["duracion_dias_sugerida"] = null;
    }

    await _dio.put("catalogos/condiciones/$idCondicion", data: data);
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
    );
  }

  Future<void> rateRecipe(
      {required int idReceta,
      required int calificacion,
      String? comentario}) async {
    await _dio.post("recetas/$idReceta/calificar",
        data: {"calificacion": calificacion, "comentario": comentario});
  }

  Future<List<Map<String, dynamic>>> fetchPlanItemsByPaciente(String idPaciente,
      {DateTime? fecha}) async {
    final f = (fecha ?? DateTime.now()).toIso8601String().split("T").first;
    final response = await _dio
        .get("tutor/plan-diario/$idPaciente", queryParameters: {"fecha": f});
    return _toRows(response.data);
  }

  Future<void> registerConsumption(
      {required int idPlanItem,
      required int idEstadoConsumo,
      String? observacion}) async {
    await _dio.post("tutor/registrar-consumo", data: {
      "id_plan_item": idPlanItem,
      "id_estado_consumo": idEstadoConsumo,
      "observacion": observacion
    });
  }

  Future<List<Map<String, dynamic>>> fetchPatients() async {
    final response = await _dio.get("tutor/mis-pacientes");
    return _toRows(response.data);
  }

  Future<List<Map<String, dynamic>>> fetchMyPatients() async {
    final response = await _dio.get("tutor/mis-pacientes");
    return _toRows(response.data);
  }

  Future<Map<String, List<Map<String, dynamic>>>> fetchShoppingList(
      String idPaciente,
      {DateTime? start,
      DateTime? end}) async {
    final s = (start ?? DateTime.now()).toIso8601String().split("T").first;
    final e = (end ?? DateTime.now().add(const Duration(days: 7)))
        .toIso8601String()
        .split("T")
        .first;
    final response = await _dio.get("tutor/lista-compras/$idPaciente",
        queryParameters: {"fecha_inicio": s, "fecha_fin": e});

    final data = response.data as Map<String, dynamic>;
    return data.map(
        (key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)));
  }

  Future<void> archivePatient(String idPaciente) async {
    await _dio.patch("pacientes/$idPaciente/archivar");
  }

  Future<void> deletePatient(String idPaciente) async {
    await archivePatient(idPaciente);
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
    );
  }

  Future<void> registerIntegral(Map<String, dynamic> payload) async {
    await _dio.post(
      "registro/paciente-integral",
      data: payload,
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
    );
  }

  Future<Map<String, dynamic>?> findTutorByCedula(String cedula) async {
    final resp = await _dio.get("usuarios/tutor-by-cedula/$cedula");
    return resp.data != null ? Map<String, dynamic>.from(resp.data) : null;
  }

  Future<Map<String, dynamic>?> fetchCurrentClinicalControl(
      {required String idPaciente}) async {
    final resp = await _dio.get("pacientes/$idPaciente/control-actual");
    return resp.data != null ? Map<String, dynamic>.from(resp.data) : null;
  }

  Future<void> updateCurrentClinicalControl(
      {required String idPaciente,
      required Map<String, dynamic> controlClinico}) async {
    await _dio.put("pacientes/$idPaciente/control-actual",
        data: controlClinico);
  }

  // --- VÍNCULOS Y BÚSQUEDA ---
  Future<List<Map<String, dynamic>>> fetchTutorPatientLinks() async {
    final response = await _dio.get("registro/vinculos");
    return _toRows(response.data);
  }

  Future<List<Map<String, dynamic>>> searchTutors(
      {required String query, int limit = 10}) async {
    final resp = await _dio.get("usuarios/buscar-tutores",
        queryParameters: {"q": query, "limit": limit});
    return _toRows(resp.data);
  }

  Future<void> linkTutorToPatient(
      {required String idUsuarioTutor,
      required String idPaciente,
      required dynamic idParentesco,
      bool esPrincipal = false}) async {
    await _dio.post("registro/vincular", data: {
      "id_tutor": idUsuarioTutor,
      "id_paciente": idPaciente,
      "parentesco": idParentesco,
      "es_principal": esPrincipal
    });
  }

  Future<void> updateTutorPatientLink(
      {required int idVinculo,
      dynamic idParentesco,
      bool? activo,
      bool? esPrincipal}) async {
    final data = <String, dynamic>{};
    if (idParentesco != null) data["parentesco"] = idParentesco;
    if (activo != null) data["activo"] = activo;
    if (esPrincipal != null) data["es_principal"] = esPrincipal;
    await _dio.put("registro/vinculos/$idVinculo", data: data);
  }

  Future<void> unlinkTutorPatient({required int idVinculo}) async {
    await _dio.delete("registro/vinculos/$idVinculo");
  }

  // --- RECETAS, INGREDIENTES Y CATÁLOGOS ---
  Future<List<Map<String, dynamic>>> fetchRecetas(
      {int limit = 1000, int offset = 0}) async {
    // Paginación por página para evitar cargar todas las recetas en un solo request
    final response = await _dio.get(
      "crud/recetas",
      queryParameters: {"limit": limit, "offset": offset},
    );
    return _toRows(response.data);
  }

  Future<({List<Map<String, dynamic>> items, int total})> fetchRecetasPage({
    String query = "",
    int? idMomento,
    int? idTipoPlato,
    int limit = 12,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      "crud/recetas",
      queryParameters: {
        "q": query,
        "limit": limit,
        "offset": offset,
        "include_total": true,
        if (idMomento != null) "id_momento": idMomento,
        if (idTipoPlato != null) "id_tipo_plato": idTipoPlato,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (
      items: _toRows(data["items"]),
      total: (data["total"] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> fetchIngredientes() async {
    final response = await _dio.get("ingredientes");
    return _toRows(response.data);
  }

  Future<({List<Map<String, dynamic>> items, int total})> fetchLabelsPage({
    String query = "",
    int limit = 10,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      "nutricionista/etiquetas",
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

  Future<List<Map<String, dynamic>>> fetchCatalog(
    String schema,
    String table, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = "$schema.$table";
    if (!forceRefresh && _catalogCache.containsKey(cacheKey)) {
      return _catalogCache[cacheKey]!;
    }

    if (!forceRefresh && _catalogRequests.containsKey(cacheKey)) {
      return _catalogRequests[cacheKey]!;
    }

    final request = _dio.get("crud/catalog", queryParameters: {
      "schema": schema,
      "table": table,
    }).then((response) {
      final rows = _toRows(response.data);
      _catalogCache[cacheKey] = rows;
      return rows;
    }).whenComplete(() {
      _catalogRequests.remove(cacheKey);
    });

    _catalogRequests[cacheKey] = request;
    return request;
  }

  void invalidateCatalog(String schema, String table) {
    final cacheKey = "$schema.$table";
    _catalogCache.remove(cacheKey);
    _catalogRequests.remove(cacheKey);
  }

  void invalidateCatalogs() {
    _catalogCache.clear();
    _catalogRequests.clear();
  }

  Future<List<Map<String, dynamic>>> searchPatients(
      {required String query, int limit = 10}) async {
    final resp = await _dio
        .get("pacientes-buscar", queryParameters: {"q": query, "limit": limit});
    return _toRows(resp.data);
  }

  Future<List<Map<String, dynamic>>> fetchPatientEvolutionSummary(
      String idPaciente) async {
    final resp = await _dio.get("pacientes/$idPaciente/evolucion-resumen");
    return _toRows(resp.data);
  }

  Future<Map<String, dynamic>> fetchExpedienteCompleto(
      String idPaciente) async {
    final resp = await _dio.get("pacientes/$idPaciente/expediente-completo");
    return Map<String, dynamic>.from(resp.data);
  }
}
