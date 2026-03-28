import "package:supabase_flutter/supabase_flutter.dart";

class SupabaseCrudRepository {
  SupabaseCrudRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final data = await _client.schema("usuarios").from("usuario").select();
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> createUser({
    required String email,
    required String nombreCompleto,
    required int idRol,
  }) async {
    await _client.schema("usuarios").from("usuario").insert({
      "email": email,
      "nombre_completo": nombreCompleto,
      "id_rol": idRol,
    });
  }

  Future<List<Map<String, dynamic>>> fetchIngredientes() async {
    final data = await _client.schema("nutricion").from("ingrediente").select();
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> createIngrediente({
    required String nombre,
    int? idGrupoAlimentario,
  }) async {
    await _client.schema("nutricion").from("ingrediente").insert({
      "nombre": nombre,
      "id_grupo_alimentario": idGrupoAlimentario,
      "activo": true,
    });
  }

  Future<List<Map<String, dynamic>>> fetchRecetas() async {
    final data = await _client.schema("nutricion").from("receta").select();
    return List<Map<String, dynamic>>.from(data as List);
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
    await _client.schema("clinico").from("control_paciente").insert({
      "id_paciente": idPaciente,
      "peso_kg": pesoKg,
      "talla_cm": tallaCm,
      "edad_meses": edadMeses,
      "nivel_dolor_eva": dolor,
      "nivel_inflamacion": inflamacion,
      "imc_calculado": imc,
    });
  }

  Future<List<Map<String, dynamic>>> fetchPlanItemsByPaciente(String idPaciente) async {
    final plansData = await _client
        .schema("interaccion")
        .from("plan_nutricional")
        .select("id")
        .eq("id_paciente", idPaciente);

    final plans = List<Map<String, dynamic>>.from(plansData as List);
    final planIds = plans.map((e) => e["id"] as int).toList();

    if (planIds.isEmpty) {
      return [];
    }

    final data = await _client
        .schema("interaccion")
        .from("plan_item")
        .select()
        .inFilter("id_plan", planIds)
        .order("fecha_programada", ascending: true);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> registerConsumption({
    required int idPlanItem,
    required String estadoCodigo,
    int? idRecetaReemplazo,
    String? observacion,
  }) async {
    final estadoData = await _client
        .schema("interaccion")
        .from("catalogo_estado_consumo")
        .select("id")
        .eq("codigo", estadoCodigo)
        .maybeSingle();

    final idEstado = estadoData?["id"] as int?;
    if (idEstado == null) {
      throw Exception("No existe estado de consumo: $estadoCodigo");
    }

    await _client.schema("interaccion").from("seguimiento_plan_item").insert({
      "id_plan_item": idPlanItem,
      "id_estado_consumo": idEstado,
      "id_receta_reemplazo": idRecetaReemplazo,
      "observacion": observacion,
      "fecha_consumo": DateTime.now().toIso8601String(),
    });
  }

  Future<void> rateRecipe({
    required String idPaciente,
    required int idReceta,
    required int estrellas,
    String? comentario,
  }) async {
    await _client.schema("interaccion").from("evaluacion_receta").insert({
      "id_paciente": idPaciente,
      "id_receta": idReceta,
      "estrellas": estrellas,
      "comentario": comentario,
      "origen_evaluacion": "APP_TUTOR",
    });
  }

  Future<List<Map<String, dynamic>>> fetchCatalog(String schema, String table) async {
    final data = await _client.schema(schema).from(table).select();
    return List<Map<String, dynamic>>.from(data as List);
  }
}
