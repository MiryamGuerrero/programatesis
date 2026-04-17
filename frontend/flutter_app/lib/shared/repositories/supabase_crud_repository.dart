import "package:dio/dio.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class SupabaseCrudRepository {
  SupabaseCrudRepository(this._client, this._dio);

  final SupabaseClient _client;
  final Dio _dio;

  List<Map<String, dynamic>> _toRows(dynamic payload) {
    if (payload is! List) {
      return const [];
    }

    return payload
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Options _authorizedOptions() {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception("Sesion expirada. Inicia sesion nuevamente.");
    }

    return Options(
      headers: {
        "Authorization": "Bearer $token",
      },
    );
  }

  Exception _toException(DioException error, String fallbackMessage) {
    final statusCode = error.response?.statusCode;

    if (statusCode == 401) {
      return Exception("Sesion expirada. Inicia sesion nuevamente.");
    }
    if (statusCode == 403) {
      return Exception("No tienes permisos para realizar esta accion.");
    }

    final payload = error.response?.data;
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);

      final detail = map["detail"];
      if (detail is String && detail.trim().isNotEmpty) {
        return Exception(detail);
      }
      if (detail is List && detail.isNotEmpty) {
        return Exception(detail.map((e) => e.toString()).join(" | "));
      }
      if (map["message"] is String && (map["message"] as String).trim().isNotEmpty) {
        return Exception(map["message"].toString());
      }
      if (map["error"] is String && (map["error"] as String).trim().isNotEmpty) {
        return Exception(map["error"].toString());
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return Exception("$fallbackMessage. Verifica la conexion con el backend.");
    }

    return Exception("$fallbackMessage (HTTP ${statusCode ?? "desconocido"})");
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final response = await _dio.get(
        "/crud/users",
        options: _authorizedOptions(),
      );
      return _toRows(response.data);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar usuarios");
    }
  }

  Future<void> createUser({
    required String email,
    required String nombreCompleto,
    required int idRol,
  }) async {
    try {
      await _dio.post(
        "/crud/users",
        data: {
          "email": email,
          "nombre_completo": nombreCompleto,
          "id_rol": idRol,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible crear el usuario");
    }
  }

  Future<void> updateUser({
    required String userId,
    String? email,
    String? nombreCompleto,
    int? idRol,
    bool? activo,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (email != null) payload["email"] = email;
      if (nombreCompleto != null) payload["nombre_completo"] = nombreCompleto;
      if (idRol != null) payload["id_rol"] = idRol;
      if (activo != null) payload["activo"] = activo;

      await _dio.put(
        "/crud/users/$userId",
        data: payload,
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible actualizar el usuario");
    }
  }

  Future<List<Map<String, dynamic>>> fetchIngredientes() async {
    try {
      final response = await _dio.get(
        "/crud/ingredientes",
        options: _authorizedOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar ingredientes");
    }
  }

  Future<Map<String, dynamic>> fetchIngredientesPaged({
    String? query,
    int? idGrupoAlimentario,
    int? idSubgrupoAlimentario,
    bool includeInactive = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{
        "include_inactive": includeInactive,
        "limit": limit,
        "offset": offset,
      };
      final normalizedQuery = query?.trim();
      if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
        params["q"] = normalizedQuery;
      }
      if (idGrupoAlimentario != null) {
        params["id_grupo_alimentario"] = idGrupoAlimentario;
      }
      if (idSubgrupoAlimentario != null) {
        params["id_subgrupo_alimentario"] = idSubgrupoAlimentario;
      }

      final response = await _dio.get(
        "/crud/ingredientes/paged",
        queryParameters: params,
        options: _authorizedOptions(),
      );

      final payload = response.data;
      if (payload is! Map) {
        throw Exception("Formato de respuesta no valido");
      }

      final map = Map<String, dynamic>.from(payload);
      final items = _toRows(map["items"]);
      final total = (map["total"] as num?)?.toInt() ?? items.length;
      return {
        "items": items,
        "total": total,
      };
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar ingredientes");
    }
  }

  Future<int?> createIngrediente({
    required String nombre,
    int? idGrupoAlimentario,
    int? idSubgrupoAlimentario,
    double? precioLibra,
    double? factorParteComestible,
    String? imagenReferencia,
  }) async {
    try {
      final payload = <String, dynamic>{
        "nombre": nombre,
      };
      if (idGrupoAlimentario != null) {
        payload["id_grupo_alimentario"] = idGrupoAlimentario;
      }
      if (idSubgrupoAlimentario != null) {
        payload["id_subgrupo_alimentario"] = idSubgrupoAlimentario;
      }
      if (precioLibra != null) {
        payload["precio_libra"] = precioLibra;
      }
      if (factorParteComestible != null) {
        payload["factor_parte_comestible"] = factorParteComestible;
      }
      if (imagenReferencia != null) {
        payload["imagen_referencia"] = imagenReferencia;
      }

      final response = await _dio.post(
        "/crud/ingredientes",
        data: payload,
        options: _authorizedOptions(),
      );

      final data = response.data;
      if (data is Map) {
        return (data["id"] as num?)?.toInt();
      }

      return null;
    } on DioException catch (error) {
      throw _toException(error, "No fue posible crear el ingrediente");
    }
  }

  Future<void> updateIngrediente({
    required int idIngrediente,
    String? nombre,
    int? idGrupoAlimentario,
    int? idSubgrupoAlimentario,
    double? precioLibra,
    double? factorParteComestible,
    String? imagenReferencia,
    bool? activo,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (nombre != null) payload["nombre"] = nombre;
      if (idGrupoAlimentario != null) {
        payload["id_grupo_alimentario"] = idGrupoAlimentario;
      }
      if (idSubgrupoAlimentario != null) {
        payload["id_subgrupo_alimentario"] = idSubgrupoAlimentario;
      }
      if (precioLibra != null) payload["precio_libra"] = precioLibra;
      if (factorParteComestible != null) {
        payload["factor_parte_comestible"] = factorParteComestible;
      }
      if (imagenReferencia != null) {
        payload["imagen_referencia"] = imagenReferencia;
      }
      if (activo != null) payload["activo"] = activo;

      await _dio.put(
        "/crud/ingredientes/$idIngrediente",
        data: payload,
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible actualizar el ingrediente");
    }
  }

  Future<void> deleteIngrediente(int idIngrediente) async {
    try {
      await _dio.delete(
        "/crud/ingredientes/$idIngrediente",
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible eliminar el ingrediente");
    }
  }

  Future<Map<String, dynamic>> fetchIngredienteComposicion(
      int idIngrediente) async {
    try {
      final response = await _dio.get(
        "/crud/ingredientes/$idIngrediente/composicion",
        options: _authorizedOptions(),
      );
      final payload = response.data;
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
      throw Exception("Formato de respuesta no valido");
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        try {
          final fallbackResponse = await _dio.get(
            "/nutricionista/ingredientes/$idIngrediente/composicion",
            options: _authorizedOptions(),
          );
          final payload = fallbackResponse.data;
          if (payload is Map) {
            return Map<String, dynamic>.from(payload);
          }
        } on DioException {
          // If fallback also fails, preserve the original /crud error below.
        }
      }
      throw _toException(error, "No fue posible cargar la composicion nutricional");
    }
  }

  Future<void> upsertIngredienteComposicion({
    required int idIngrediente,
    required Map<String, dynamic> valores,
  }) async {
    try {
      await _dio.put(
        "/crud/ingredientes/$idIngrediente/composicion",
        data: {
          "valores": valores,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        try {
          await _dio.put(
            "/nutricionista/ingredientes/$idIngrediente/composicion",
            data: {
              "valores": valores,
            },
            options: _authorizedOptions(),
          );
          return;
        } on DioException {
          // Keep original error message from /crud endpoint.
        }
      }
      throw _toException(error, "No fue posible actualizar la composicion nutricional");
    }
  }

  Future<List<Map<String, dynamic>>> fetchEtiquetas() async {
    try {
      final response = await _dio.get(
        "/crud/etiquetas",
        options: _authorizedOptions(),
      );
      return _toRows(response.data);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar etiquetas");
    }
  }

  Future<Map<String, dynamic>> createEtiqueta({
    required String nombreVisible,
    String? codigo,
  }) async {
    try {
      final response = await _dio.post(
        "/crud/etiquetas",
        data: {
          "nombre_visible": nombreVisible,
          "codigo": codigo,
        },
        options: _authorizedOptions(),
      );

      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception("Formato de respuesta no valido");
    } on DioException catch (error) {
      throw _toException(error, "No fue posible crear la etiqueta");
    }
  }

  Future<void> updateEtiqueta({
    required int idEtiqueta,
    String? nombreVisible,
    String? codigo,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (nombreVisible != null) payload["nombre_visible"] = nombreVisible;
      if (codigo != null) payload["codigo"] = codigo;

      await _dio.put(
        "/crud/etiquetas/$idEtiqueta",
        data: payload,
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible actualizar la etiqueta");
    }
  }

  Future<void> deleteEtiqueta(int idEtiqueta) async {
    try {
      await _dio.delete(
        "/crud/etiquetas/$idEtiqueta",
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible eliminar la etiqueta");
    }
  }

  Future<List<Map<String, dynamic>>> fetchEtiquetasByIngrediente(
      int idIngrediente) async {
    try {
      final response = await _dio.get(
        "/crud/ingredientes/$idIngrediente/etiquetas",
        options: _authorizedOptions(),
      );
      return _toRows(response.data);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar etiquetas del ingrediente");
    }
  }

  Future<Map<String, dynamic>> asignarEtiquetaIngrediente({
    required int idIngrediente,
    int? idEtiqueta,
    String? nombreEtiqueta,
  }) async {
    try {
      final response = await _dio.post(
        "/crud/ingredientes/$idIngrediente/etiquetas",
        data: {
          "id_etiqueta": idEtiqueta,
          "nombre_etiqueta": nombreEtiqueta,
        },
        options: _authorizedOptions(),
      );

      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception("Formato de respuesta no valido");
    } on DioException catch (error) {
      throw _toException(error, "No fue posible asignar la etiqueta");
    }
  }

  Future<void> removerEtiquetaIngrediente({
    required int idIngrediente,
    required int idEtiqueta,
  }) async {
    try {
      await _dio.delete(
        "/crud/ingredientes/$idIngrediente/etiquetas/$idEtiqueta",
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible remover la etiqueta");
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecetas() async {
    try {
      final response = await _dio.get(
        "/crud/recetas",
        options: _authorizedOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar recetas");
    }
  }

  Future<void> createClinicalControl({
    required String idPaciente,
    required double pesoKg,
    required double tallaCm,
    required int edadMeses,
    int? dolor,
    int? inflamacion,
    double? imc,
  }) async {
    try {
      await _dio.post(
        "/crud/controles",
        data: {
          "id_paciente": idPaciente,
          "peso_kg": pesoKg,
          "talla_cm": tallaCm,
          "edad_meses": edadMeses,
          "nivel_dolor_eva": dolor,
          "nivel_inflamacion": inflamacion,
          "imc_calculado": imc,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible guardar el control clinico");
    }
  }

  Future<List<Map<String, dynamic>>> fetchPlanItemsByPaciente(
      String idPaciente) async {
    try {
      final response = await _dio.get(
        "/crud/plan-items",
        queryParameters: {
          "id_paciente": idPaciente,
        },
        options: _authorizedOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar el plan del paciente");
    }
  }

  Future<void> registerConsumption({
    required int idPlanItem,
    required String estadoCodigo,
    int? idRecetaReemplazo,
    String? observacion,
  }) async {
    try {
      await _dio.post(
        "/crud/consumos",
        data: {
          "id_plan_item": idPlanItem,
          "estado_codigo": estadoCodigo,
          "id_receta_reemplazo": idRecetaReemplazo,
          "observacion": observacion,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible guardar el consumo");
    }
  }

  Future<void> rateRecipe({
    required String idPaciente,
    required int idReceta,
    required int estrellas,
    String? comentario,
  }) async {
    try {
      await _dio.post(
        "/crud/evaluaciones",
        data: {
          "id_paciente": idPaciente,
          "id_receta": idReceta,
          "estrellas": estrellas,
          "comentario": comentario,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible guardar la calificacion");
    }
  }

  Future<List<Map<String, dynamic>>> fetchCatalog(
      String schema, String table) async {
    try {
      final response = await _dio.get(
        "/crud/catalog",
        queryParameters: {
          "schema": schema,
          "table": table,
        },
        options: _authorizedOptions(),
      );
      return _toRows(response.data);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar el catalogo");
    }
  }

  Future<Map<String, dynamic>> fetchMyProfile() async {
    try {
      final response = await _dio.get(
        "/profile/me",
        options: _authorizedOptions(),
      );

      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      throw Exception("Formato de perfil no valido");
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar el perfil");
    }
  }

  Future<void> updateMyProfile({
    String? nombreCompleto,
    String? cedula,
    String? telefono,
    String? direccion,
    String? email,
  }) async {
    try {
      await _dio.put(
        "/profile/me",
        data: {
          "nombre_completo": nombreCompleto,
          "cedula": cedula,
          "telefono": telefono,
          "direccion": direccion,
          "email": email,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible actualizar el perfil");
    }
  }

  Future<void> registerTutor({
    required String email,
    required String nombreCompleto,
    required String idPaciente,
    int? idParentesco,
    bool esPrincipal = true,
  }) async {
    try {
      await _dio.post(
        "/tutores-registro",
        data: {
          "email": email,
          "nombre_completo": nombreCompleto,
          "id_paciente": idPaciente,
          "id_parentesco": idParentesco,
          "es_principal": esPrincipal,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible registrar al tutor");
    }
  }

  Future<void> registerTutorOnly({
    required String email,
    required String nombreCompleto,
  }) async {
    try {
      await _dio.post(
        "/tutores",
        data: {
          "email": email,
          "nombre_completo": nombreCompleto,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible registrar al tutor");
    }
  }

  Future<List<Map<String, dynamic>>> searchTutors({
    required String query,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        "/tutores-buscar",
        queryParameters: {
          "q": query,
          "limit": limit,
        },
        options: _authorizedOptions(),
      );
      return _toRows(response.data);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible buscar tutores");
    }
  }

  Future<List<Map<String, dynamic>>> searchPatients({
    required String query,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        "/pacientes-buscar",
        queryParameters: {
          "q": query,
          "limit": limit,
        },
        options: _authorizedOptions(),
      );
      return _toRows(response.data);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible buscar pacientes");
    }
  }

  Future<Map<String, dynamic>> fetchPatientAllergies({
    required String idPaciente,
  }) async {
    try {
      final response = await _dio.get(
        "/pacientes/$idPaciente/alergias",
        options: _authorizedOptions(),
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception("Formato de alergias no válido");
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar alergias del paciente");
    }
  }

  Future<void> addPatientIngredientAllergy({
    required String idPaciente,
    required int idIngrediente,
    String? observacion,
  }) async {
    try {
      await _dio.post(
        "/pacientes/$idPaciente/alergias/ingredientes",
        data: {
          "id_ingrediente": idIngrediente,
          "observacion": observacion,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible registrar alergia por ingrediente");
    }
  }

  Future<void> removePatientIngredientAllergy({
    required String idPaciente,
    required int idIngrediente,
  }) async {
    try {
      await _dio.delete(
        "/pacientes/$idPaciente/alergias/ingredientes/$idIngrediente",
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible eliminar alergia por ingrediente");
    }
  }

  Future<void> addPatientGroupAllergy({
    required String idPaciente,
    required int idGrupoAlimentario,
    String? observacion,
  }) async {
    try {
      await _dio.post(
        "/pacientes/$idPaciente/alergias/grupos",
        data: {
          "id_grupo_alimentario": idGrupoAlimentario,
          "observacion": observacion,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible registrar alergia por grupo alimentario");
    }
  }

  Future<void> removePatientGroupAllergy({
    required String idPaciente,
    required int idGrupoAlimentario,
  }) async {
    try {
      await _dio.delete(
        "/pacientes/$idPaciente/alergias/grupos/$idGrupoAlimentario",
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible eliminar alergia por grupo alimentario");
    }
  }

  Future<Map<String, dynamic>> fetchPatientTemporaryConditions({
    required String idPaciente,
  }) async {
    try {
      final response = await _dio.get(
        "/pacientes/$idPaciente/condiciones-temporales",
        options: _authorizedOptions(),
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception("Formato de condiciones temporales no válido");
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar condiciones temporales");
    }
  }

  Future<void> updatePatientTemporaryConditions({
    required String idPaciente,
    required List<int> idCondicionesTemporales,
  }) async {
    try {
      await _dio.put(
        "/pacientes/$idPaciente/condiciones-temporales",
        data: {
          "id_condiciones_temporales": idCondicionesTemporales,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible actualizar condiciones temporales");
    }
  }

  Future<Map<String, dynamic>> createConditionType({
    required String codigo,
    required String nombre,
  }) async {
    try {
      final response = await _dio.post(
        "/catalogo-condiciones/tipos",
        data: {
          "codigo": codigo,
          "nombre": nombre,
        },
        options: _authorizedOptions(),
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible crear el tipo de condición");
    }
  }

  Future<void> updateConditionType({
    required int idTipoCondicion,
    String? codigo,
    String? nombre,
  }) async {
    try {
      await _dio.put(
        "/catalogo-condiciones/tipos/$idTipoCondicion",
        data: {
          "codigo": codigo,
          "nombre": nombre,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible actualizar el tipo de condición");
    }
  }

  Future<Map<String, dynamic>> createCondition({
    required String nombre,
    required int idTipoCondicion,
    String? descripcion,
    bool activa = true,
  }) async {
    try {
      final response = await _dio.post(
        "/catalogo-condiciones/condiciones",
        data: {
          "nombre": nombre,
          "id_tipo_condicion": idTipoCondicion,
          "descripcion": descripcion,
          "activa": activa,
        },
        options: _authorizedOptions(),
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible crear la condición");
    }
  }

  Future<void> updateCondition({
    required int idCondicion,
    String? nombre,
    int? idTipoCondicion,
    String? descripcion,
    bool? activa,
  }) async {
    try {
      await _dio.put(
        "/catalogo-condiciones/condiciones/$idCondicion",
        data: {
          "nombre": nombre,
          "id_tipo_condicion": idTipoCondicion,
          "descripcion": descripcion,
          "activa": activa,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible actualizar la condición");
    }
  }

  Future<Map<String, dynamic>> fetchPatientEvolutionSummary({
    required String idPaciente,
  }) async {
    try {
      final response = await _dio.get(
        "/pacientes/$idPaciente/evolucion-resumen",
        options: _authorizedOptions(),
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception("Formato de evolución no válido");
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar el resumen de evolución");
    }
  }

  Future<Map<String, dynamic>> fetchCurrentClinicalControl({
    required String idPaciente,
  }) async {
    try {
      final response = await _dio.get(
        "/pacientes/$idPaciente/control-clinico-actual",
        options: _authorizedOptions(),
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception("Formato de control clínico no válido");
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar el control clínico del paciente");
    }
  }

  Future<void> updateCurrentClinicalControl({
    required String idPaciente,
    required Map<String, dynamic> controlClinico,
  }) async {
    try {
      await _dio.put(
        "/pacientes/$idPaciente/control-clinico-actual",
        data: controlClinico,
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible actualizar el control clínico del paciente");
    }
  }

  Future<void> registerPatientOnly({
    required String nombreCompleto,
    required DateTime fechaNacimiento,
    required int idSexo,
    int? idProvincia,
    Map<String, dynamic>? controlClinicoInicial,
  }) async {
    try {
      await _dio.post(
        "/pacientes",
        data: {
          "nombre_completo": nombreCompleto,
          "fecha_nacimiento": fechaNacimiento.toIso8601String().split("T").first,
          "id_sexo": idSexo,
          "id_provincia": idProvincia,
          "control_clinico_inicial": controlClinicoInicial,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible registrar al paciente");
    }
  }

  Future<void> linkTutorToPatient({
    required String idUsuarioTutor,
    required String idPaciente,
    int? idParentesco,
    bool esPrincipal = true,
  }) async {
    try {
      await _dio.post(
        "/tutor-paciente-vinculo",
        data: {
          "id_usuario_tutor": idUsuarioTutor,
          "id_paciente": idPaciente,
          "id_parentesco": idParentesco,
          "es_principal": esPrincipal,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible vincular tutor y paciente");
    }
  }

  Future<List<Map<String, dynamic>>> fetchTutorPatientLinks() async {
    try {
      final response = await _dio.get(
        "/tutor-paciente-vinculo",
        options: _authorizedOptions(),
      );
      return _toRows(response.data);
    } on DioException catch (error) {
      throw _toException(error, "No fue posible cargar los vinculos");
    }
  }

  Future<void> updateTutorPatientLink({
    required int idVinculo,
    int? idParentesco,
    bool esPrincipal = true,
  }) async {
    try {
      await _dio.put(
        "/tutor-paciente-vinculo/$idVinculo",
        data: {
          "id_parentesco": idParentesco,
          "es_principal": esPrincipal,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible actualizar el vinculo");
    }
  }

  Future<void> unlinkTutorPatient({
    required int idVinculo,
  }) async {
    try {
      await _dio.delete(
        "/tutor-paciente-vinculo/$idVinculo",
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible desvincular tutor y paciente");
    }
  }

  Future<void> registerPatientAndLinkTutor({
    required String nombreCompleto,
    required DateTime fechaNacimiento,
    required int idSexo,
    int? idProvincia,
    Map<String, dynamic>? controlClinicoInicial,
    required String idUsuarioTutor,
    int? idParentesco,
    bool esPrincipal = true,
  }) async {
    try {
      await _dio.post(
        "/pacientes-registro",
        data: {
          "nombre_completo": nombreCompleto,
          "fecha_nacimiento": fechaNacimiento.toIso8601String().split("T").first,
          "id_sexo": idSexo,
          "id_provincia": idProvincia,
          "control_clinico_inicial": controlClinicoInicial,
          "id_usuario_tutor": idUsuarioTutor,
          "id_parentesco": idParentesco,
          "es_principal": esPrincipal,
        },
        options: _authorizedOptions(),
      );
    } on DioException catch (error) {
      throw _toException(error, "No fue posible registrar al paciente");
    }
  }
}
