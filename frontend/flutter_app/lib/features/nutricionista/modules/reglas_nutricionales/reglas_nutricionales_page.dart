import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

class ReglasNutricionalesPage extends ConsumerStatefulWidget {
  const ReglasNutricionalesPage({super.key});

  @override
  ConsumerState<ReglasNutricionalesPage> createState() =>
      _ReglasNutricionalesPageState();
}

class _ReglasNutricionalesPageState
    extends ConsumerState<ReglasNutricionalesPage> {
  final _filterQController = TextEditingController();
  final _createNombreController = TextEditingController();
  final _createValorController = TextEditingController();
  final _validateSubcategoriaController = TextEditingController();

  static const Map<String, String> _allowedConditions = {
    "contiene": "Contiene palabra",
    "mayor_que": "Mayor que",
    "menor_que": "Menor que",
    "igual_a": "Igual a",
    "diferente": "Diferente",
    "mayor_igual": "Mayor o igual",
    "menor_igual": "Menor o igual",
    "nulo": "Es nulo",
    "no_nulo": "No es nulo",
  };

  bool _bootstrapping = false;
  bool _loadingRules = false;
  bool _creatingRule = false;
  bool _validating = false;

  String? _statusGeneral;
  String? _statusRules;
  String? _statusCreate;
  String? _statusValidate;

  String _selectedEstado = "";
  bool _soloActivas = true;
  int? _filterLabelId;

  int? _createLabelId;
  String? _createFieldCode;
  String _selectedCondition = "mayor_que";
  bool _createRecalcImmediate = true;

  int? _validateRuleId;
  int _validateLimit = 1;

  List<Map<String, dynamic>> _labels = const [];
  List<Map<String, dynamic>> _fields = const [];
  List<Map<String, dynamic>> _rules = const [];
  Map<String, dynamic>? _validationData;

  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _filterQController.dispose();
    _createNombreController.dispose();
    _createValorController.dispose();
    _validateSubcategoriaController.dispose();
    super.dispose();
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {"raw": value};
  }

  String _toFriendlyApiError(DioException error) {
    final code = error.response?.statusCode;
    final payload = error.response?.data;

    if (code == 401) {
      return "Sesion expirada. Inicia sesion nuevamente.";
    }
    if (code == 403) {
      return "Tu rol no tiene permiso para esta accion.";
    }

    final detail = _extractDetail(payload);
    if (detail != null && detail.trim().isNotEmpty) {
      return detail;
    }

    return "Error API ${code ?? "desconocido"}";
  }

  String? _extractDetail(dynamic payload) {
    if (payload == null) {
      return null;
    }

    if (payload is String) {
      return payload;
    }

    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final detail = map["detail"];
      if (detail is String) {
        return detail;
      }
      if (detail is List) {
        return detail.map((e) => e.toString()).join(" | ");
      }
      if (detail != null) {
        return detail.toString();
      }

      if (map["message"] != null) {
        return map["message"].toString();
      }
      return null;
    }

    if (payload is List) {
      return payload.map((e) => e.toString()).join(" | ");
    }

    return payload.toString();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootstrapping = true;
      _statusGeneral = "Cargando etiquetas y campos...";
    });

    try {
      await Future.wait([
        _loadLabels(),
        _loadFields(),
      ]);
      await _loadRules();

      if (!mounted) {
        return;
      }

      setState(() {
        _statusGeneral = "Modulo listo.";
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusGeneral = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _bootstrapping = false;
        });
      }
    }
  }

  Future<void> _loadLabels() async {
    try {
      final response = await _dio.get(
        "/nutricionista/etiquetas-config/etiquetas",
        queryParameters: {
          "solo_activas": false,
          "limit": 2000,
        },
      );

      final payload = _toMap(response.data);
      final rawItems = payload["items"] is List ? payload["items"] as List : const [];
      final items = rawItems
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _labels = items;
        if (_createLabelId == null && items.isNotEmpty) {
          _createLabelId = _asInt(items.first["id"]);
        }
      });
    } on DioException catch (error) {
      throw Exception(_toFriendlyApiError(error));
    }
  }

  Future<void> _loadFields() async {
    try {
      final response = await _dio.get(
        "/nutricionista/etiquetas-config/campos",
      );

      final payload = _toMap(response.data);
      final rawVariables = payload["variables_fijas"] is List
          ? payload["variables_fijas"] as List
          : const [];
      final rawCalculated = payload["campos_calculados"] is List
          ? payload["campos_calculados"] as List
          : const [];

      final byCode = <String, Map<String, dynamic>>{};

      for (final row in rawVariables) {
        final item = Map<String, dynamic>.from(row as Map);
        final code = item["codigo"]?.toString().trim();
        if (code == null || code.isEmpty) {
          continue;
        }
        byCode[code] = {
          "codigo": code,
          "nombre_visible": item["nombre_visible"]?.toString() ?? code,
          "origen": "variable",
        };
      }

      for (final row in rawCalculated) {
        final item = Map<String, dynamic>.from(row as Map);
        final code = item["codigo"]?.toString().trim();
        if (code == null || code.isEmpty) {
          continue;
        }
        byCode[code] = {
          "codigo": code,
          "nombre_visible": item["nombre_visible"]?.toString() ?? code,
          "origen": "calculado",
        };
      }

      final items = byCode.values.toList()
        ..sort((a, b) {
          final an = a["nombre_visible"]?.toString() ?? "";
          final bn = b["nombre_visible"]?.toString() ?? "";
          return an.toLowerCase().compareTo(bn.toLowerCase());
        });

      if (!mounted) {
        return;
      }

      setState(() {
        _fields = items;
        if (_createFieldCode == null && items.isNotEmpty) {
          _createFieldCode = items.first["codigo"]?.toString();
        }
      });
    } on DioException catch (error) {
      throw Exception(_toFriendlyApiError(error));
    }
  }

  Future<void> _loadRules() async {
    setState(() {
      _loadingRules = true;
      _statusRules = "Cargando reglas...";
    });

    try {
      final query = <String, dynamic>{
        "solo_activas": _soloActivas,
        "limit": 400,
      };

      final q = _filterQController.text.trim();
      if (q.isNotEmpty) {
        query["q"] = q;
      }
      if (_selectedEstado.isNotEmpty) {
        query["estado"] = _selectedEstado;
      }
      if (_filterLabelId != null) {
        query["id_etiqueta"] = _filterLabelId;
      }

      final response = await _dio.get(
        "/nutricionista/etiquetas-config/reglas",
        queryParameters: query,
      );

      final payload = _toMap(response.data);
      final rawItems = payload["items"] is List ? payload["items"] as List : const [];
      final items = rawItems
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _rules = items;

        final selectedRuleStillExists =
            _validateRuleId != null &&
                items.any((r) => _asInt(r["id"]) == _validateRuleId);
        if (!selectedRuleStillExists) {
          _validateRuleId = null;
        }

        final total = _asInt(payload["total"]) ?? items.length;
        _statusRules = "Reglas cargadas: $total";
      });
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusRules = _toFriendlyApiError(error);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusRules = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRules = false;
        });
      }
    }
  }

  dynamic _parseCreateValue() {
    final raw = _createValorController.text.trim();
    if (raw.isEmpty) {
      return null;
    }

    const numericConditions = {
      "mayor_que",
      "menor_que",
      "mayor_igual",
      "menor_igual",
    };

    if (numericConditions.contains(_selectedCondition)) {
      final number = double.tryParse(raw);
      if (number == null) {
        throw Exception("Para esta condicion, el valor debe ser numerico.");
      }
      return number;
    }

    final maybeNumber = double.tryParse(raw);
    return maybeNumber ?? raw;
  }

  String _labelNameById(int? id) {
    if (id == null) {
      return "";
    }
    for (final label in _labels) {
      if (_asInt(label["id"]) == id) {
        return label["nombre_visible"]?.toString() ?? "Etiqueta";
      }
    }
    return "Etiqueta";
  }

  String _fieldNameByCode(String? code) {
    if (code == null || code.isEmpty) {
      return "";
    }
    for (final field in _fields) {
      if (field["codigo"]?.toString() == code) {
        return field["nombre_visible"]?.toString() ?? code;
      }
    }
    return code;
  }

  String _autoRuleName() {
    final label = _labelNameById(_createLabelId);
    final field = _fieldNameByCode(_createFieldCode);
    final conditionText = _allowedConditions[_selectedCondition] ?? _selectedCondition;

    final pieces = <String>[];
    if (label.isNotEmpty) {
      pieces.add(label);
    }
    if (field.isNotEmpty) {
      pieces.add(field);
    }
    pieces.add(conditionText);

    return "Regla ${pieces.join(" - ")}";
  }

  Future<void> _createQuickRule() async {
    final etiquetaId = _createLabelId;
    final campo = _createFieldCode;

    if (etiquetaId == null) {
      setState(() {
        _statusCreate = "Selecciona una etiqueta.";
      });
      return;
    }
    if (campo == null || campo.isEmpty) {
      setState(() {
        _statusCreate = "Selecciona un campo para evaluar.";
      });
      return;
    }

    final customName = _createNombreController.text.trim();
    final nombreRegla = customName.isEmpty ? _autoRuleName() : customName;

    setState(() {
      _creatingRule = true;
      _statusCreate = "Creando regla...";
    });

    try {
      final payload = {
        "id_etiqueta": etiquetaId,
        "nombre_regla": nombreRegla,
        "prioridad": 100,
        "formula_excel_original": null,
        "condiciones": [
          {
            "campo": campo,
            "condicion": _selectedCondition,
            "valor": _parseCreateValue(),
            "valor_min": null,
            "valor_max": null,
            "conector": "AND",
            "negado": false,
          }
        ],
        "procesar_recalculo_inmediato": _createRecalcImmediate,
      };

      final response = await _dio.post(
        "/nutricionista/etiquetas-config/reglas/guiada",
        data: payload,
      );

      if (!mounted) {
        return;
      }

      final created = _toMap(response.data);
      setState(() {
        _statusCreate =
            "Regla creada correctamente (ID ${created["id_regla_version"] ?? "-"}).";
      });

      _createNombreController.clear();
      _createValorController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Regla creada y recalculo solicitado.")),
      );

      await _loadRules();
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusCreate = _toFriendlyApiError(error);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusCreate = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingRule = false;
        });
      }
    }
  }

  Future<void> _archiveRule(int idRegla) async {
    try {
      await _dio.delete(
        "/nutricionista/etiquetas-config/reglas/$idRegla",
        queryParameters: {
          "hard_delete": false,
          "procesar_recalculo_inmediato": true,
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Regla $idRegla archivada.")),
      );

      await _loadRules();
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_toFriendlyApiError(error))),
      );
    }
  }

  Future<void> _validateResults() async {
    final subcategoria = _validateSubcategoriaController.text.trim();
    if (_validateRuleId == null && subcategoria.isEmpty) {
      setState(() {
        _statusValidate = "Selecciona una regla o escribe una subcategoria.";
      });
      return;
    }

    setState(() {
      _validating = true;
      _statusValidate = "Validando resultados...";
      _validationData = null;
    });

    try {
      final response = await _dio.post(
        "/nutricionista/etiquetas-config/validacion/resultados",
        data: {
          "id_regla_version": _validateRuleId,
          "subcategoria": subcategoria.isEmpty ? null : subcategoria,
          "limite_por_resultado": _validateLimit,
        },
      );

      final payload = _toMap(response.data);

      if (!mounted) {
        return;
      }

      setState(() {
        _validationData = payload;
        _statusValidate =
            "Resultados: ${payload["total_resultados"] ?? 0} | Con ejemplo: ${payload["resultados_con_ejemplo"] ?? 0}";
      });
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusValidate = _toFriendlyApiError(error);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusValidate = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _validating = false;
        });
      }
    }
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFFDF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5DCCF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF5A6777),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _statusLine(String? text) {
    if (text == null || text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4D5E70),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final total = _rules.length;
    final activas = _rules
        .where((r) => (r["estado"]?.toString().toLowerCase() ?? "") == "activa")
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D8C7)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF6EA),
            Color(0xFFF4FBF8),
            Color(0xFFEFF8FD),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Etiquetas Nutricionales Configurables",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Gestiona reglas por nombre de etiqueta y campo. Sin IDs manuales.",
            style: TextStyle(color: Color(0xFF4E6072)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text("Reglas: $total")),
              Chip(label: Text("Activas: $activas")),
              Chip(label: Text("Etiquetas: ${_labels.length}")),
              Chip(label: Text("Campos: ${_fields.length}")),
            ],
          ),
          _statusLine(_statusGeneral),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    if (_loadingRules) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_rules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text("No hay reglas para los filtros actuales."),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = _rules[index];
        final id = _asInt(row["id"]);
        final estado = row["estado"]?.toString() ?? "desconocido";
        final condiciones = row["condiciones"] is List
            ? (row["condiciones"] as List)
            : const [];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3D8C7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row["nombre_regla"]?.toString() ?? "Regla sin nombre",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: estado.toLowerCase() == "activa"
                          ? const Color(0xFFE8F8EF)
                          : const Color(0xFFFFF3E5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      estado,
                      style: TextStyle(
                        color: estado.toLowerCase() == "activa"
                            ? const Color(0xFF16683B)
                            : const Color(0xFF9A5C11),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Etiqueta: ${row["etiqueta_nombre"] ?? "-"} | Tipo: ${row["tipo_regla"] ?? "-"} | Prioridad: ${row["prioridad"] ?? "-"}",
                style: const TextStyle(
                  color: Color(0xFF506173),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (condiciones.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  "Condiciones",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final cond in condiciones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      "- ${(cond as Map)["campo_objetivo"] ?? cond["variable_codigo"] ?? "campo"} ${cond["operador"] ?? ""} ${cond["valor_numero"] ?? cond["valor_texto"] ?? ""}",
                      style: const TextStyle(color: Color(0xFF4F6073)),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: id == null
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Archivar regla"),
                              content: const Text(
                                "Se desactivara la regla y se solicitara recalc de etiquetas.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancelar"),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Archivar"),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await _archiveRule(id);
                          }
                        },
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text("Archivar"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildValidationResults() {
    final data = _validationData;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final items = data["items"] is List ? data["items"] as List : const [];
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text("No hay resultados para los criterios enviados."),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Resultados de validacion",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final row in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4D9C8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${(row as Map)["resultado"] ?? "Resultado"}",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Subcategoria: ${row["subcategoria"] ?? "-"} | Regla: ${row["id_regla_version"] ?? "-"}",
                    style: const TextStyle(color: Color(0xFF536476)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Ejemplos: ${(row["ejemplos"] is List) ? (row["ejemplos"] as List).length : 0}",
                    style: const TextStyle(color: Color(0xFF536476)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FFF9),
            Color(0xFFF1FAFD),
            Color(0xFFFFFCF6),
          ],
        ),
      ),
      child: _bootstrapping
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _sectionCard(
                    title: "Listado de reglas",
                    subtitle:
                        "Filtra por texto, estado o etiqueta. Todo por nombre, sin IDs manuales.",
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: 250,
                              child: TextField(
                                controller: _filterQController,
                                decoration: const InputDecoration(
                                  labelText: "Buscar regla",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 190,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedEstado,
                                decoration: const InputDecoration(
                                  labelText: "Estado",
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: "", child: Text("Todos")),
                                  DropdownMenuItem(value: "activa", child: Text("Activa")),
                                  DropdownMenuItem(value: "borrador", child: Text("Borrador")),
                                  DropdownMenuItem(value: "inactiva", child: Text("Inactiva")),
                                  DropdownMenuItem(value: "archivada", child: Text("Archivada")),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedEstado = value ?? "";
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 300,
                              child: DropdownButtonFormField<int?>(
                                initialValue: _filterLabelId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: "Etiqueta",
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text("Todas las etiquetas"),
                                  ),
                                  ..._labels.map(
                                    (label) => DropdownMenuItem<int?>(
                                      value: _asInt(label["id"]),
                                      child: Text(
                                        label["nombre_visible"]?.toString() ?? "Etiqueta",
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _filterLabelId = value;
                                  });
                                },
                              ),
                            ),
                            FilterChip(
                              label: const Text("Solo activas"),
                              selected: _soloActivas,
                              onSelected: (value) {
                                setState(() {
                                  _soloActivas = value;
                                });
                              },
                            ),
                            FilledButton.icon(
                              onPressed: _loadRules,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Actualizar"),
                            ),
                            OutlinedButton.icon(
                              onPressed: _bootstrap,
                              icon: const Icon(Icons.sync),
                              label: const Text("Recargar catalogos"),
                            ),
                          ],
                        ),
                        _statusLine(_statusRules),
                        const SizedBox(height: 10),
                        _buildRulesList(),
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: "Crear regla guiada",
                    subtitle:
                        "Selecciona etiqueta y campo desde listas automaticas. Sin escribir IDs.",
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: 300,
                              child: DropdownButtonFormField<int>(
                                initialValue: _createLabelId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: "Etiqueta destino",
                                  border: OutlineInputBorder(),
                                ),
                                items: _labels
                                    .map(
                                      (label) => DropdownMenuItem<int>(
                                        value: _asInt(label["id"]),
                                        child: Text(
                                          label["nombre_visible"]?.toString() ?? "Etiqueta",
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .where((item) => item.value != null)
                                    .cast<DropdownMenuItem<int>>()
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _createLabelId = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 320,
                              child: DropdownButtonFormField<String>(
                                initialValue: _createFieldCode,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: "Campo a evaluar",
                                  border: OutlineInputBorder(),
                                ),
                                items: _fields
                                    .map(
                                      (field) => DropdownMenuItem<String>(
                                        value: field["codigo"]?.toString(),
                                        child: Text(
                                          "${field["nombre_visible"]} (${field["codigo"]})",
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _createFieldCode = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 210,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCondition,
                                decoration: const InputDecoration(
                                  labelText: "Condicion",
                                  border: OutlineInputBorder(),
                                ),
                                items: _allowedConditions.entries
                                    .map(
                                      (entry) => DropdownMenuItem<String>(
                                        value: entry.key,
                                        child: Text(entry.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedCondition = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: TextField(
                                controller: _createValorController,
                                decoration: const InputDecoration(
                                  labelText: "Valor",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 340,
                              child: TextField(
                                controller: _createNombreController,
                                decoration: InputDecoration(
                                  labelText: "Nombre regla (opcional)",
                                  hintText: _autoRuleName(),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Switch(
                              value: _createRecalcImmediate,
                              onChanged: (value) {
                                setState(() {
                                  _createRecalcImmediate = value;
                                });
                              },
                            ),
                            const Text("Recalculo inmediato"),
                            const SizedBox(width: 16),
                            FilledButton.icon(
                              onPressed: _creatingRule ? null : _createQuickRule,
                              icon: _creatingRule
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.add_task),
                              label: Text(_creatingRule ? "Creando..." : "Crear regla"),
                            ),
                          ],
                        ),
                        _statusLine(_statusCreate),
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: "Validacion por resultados",
                    subtitle:
                        "Selecciona una regla del listado o usa subcategoria para revisar ejemplos.",
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: 380,
                              child: DropdownButtonFormField<int?>(
                                initialValue: _validateRuleId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: "Regla (opcional)",
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text("Sin regla seleccionada"),
                                  ),
                                  ..._rules.map(
                                    (rule) => DropdownMenuItem<int?>(
                                      value: _asInt(rule["id"]),
                                      child: Text(
                                        rule["nombre_regla"]?.toString() ?? "Regla",
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _validateRuleId = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 300,
                              child: TextField(
                                controller: _validateSubcategoriaController,
                                decoration: const InputDecoration(
                                  labelText: "Subcategoria (opcional)",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: DropdownButtonFormField<int>(
                                initialValue: _validateLimit,
                                decoration: const InputDecoration(
                                  labelText: "Ejemplos",
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text("1")),
                                  DropdownMenuItem(value: 2, child: Text("2")),
                                  DropdownMenuItem(value: 3, child: Text("3")),
                                  DropdownMenuItem(value: 4, child: Text("4")),
                                  DropdownMenuItem(value: 5, child: Text("5")),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _validateLimit = value;
                                  });
                                },
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _validating ? null : _validateResults,
                              icon: _validating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.rule_folder),
                              label: Text(_validating ? "Validando..." : "Validar"),
                            ),
                          ],
                        ),
                        _statusLine(_statusValidate),
                        _buildValidationResults(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
