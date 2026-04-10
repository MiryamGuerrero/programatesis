import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class _SubetiquetaDraft {
  _SubetiquetaDraft({this.prioridad = 1})
      : prioridadController =
            TextEditingController(text: prioridad.toString());

  final TextEditingController codigoController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController prioridadController;
  final TextEditingController subsubController = TextEditingController();

  bool activa = true;
  String tipoEvaluacion = "FIRST_MATCH";

  int prioridad;

  void dispose() {
    codigoController.dispose();
    nombreController.dispose();
    descripcionController.dispose();
    prioridadController.dispose();
    subsubController.dispose();
  }
}

class EtiquetasAutomaticasPage extends ConsumerStatefulWidget {
  const EtiquetasAutomaticasPage({super.key});

  @override
  ConsumerState<EtiquetasAutomaticasPage> createState() =>
      _EtiquetasAutomaticasPageState();
}

class _EtiquetasAutomaticasPageState
    extends ConsumerState<EtiquetasAutomaticasPage> {
  final _configEtiquetaCodigoController = TextEditingController();
  final _configEtiquetaNombreController = TextEditingController();
  final _configEtiquetaDescripcionController = TextEditingController();

  final _auditSearchController = TextEditingController();
  final _auditEtiquetaController = TextEditingController();
  final _auditSubetiquetaController = TextEditingController();

  final _recalcEtiquetaController = TextEditingController();
  final _recalcReglaVersionController = TextEditingController();
  final _recalcIngredienteController = TextEditingController();
  final _recalcMaxIngredientesController = TextEditingController(text: "100");

  final _histEtiquetaController = TextEditingController();
  final _histReglaVersionController = TextEditingController();

  final List<_SubetiquetaDraft> _subetiquetaDrafts = [];

  bool _savingConfiguracion = false;
  bool _loadingAuditoria = false;
  bool _loadingDetalleAuditoria = false;
  bool _runningRecalculo = false;
  bool _loadingHistorial = false;
  bool _loadingHistorialDetalle = false;

  bool _configEtiquetaActiva = true;
  bool _configCrearReglaInicial = true;
  String _configEstadoReglaInicial = "BORRADOR";

  bool _recalcDryRun = true;
  bool _recalcSoloActivos = true;
  bool _recalcStopOnError = false;

  int _auditPage = 1;
  final int _auditPageSize = 25;
  int _auditTotal = 0;
  List<Map<String, dynamic>> _auditItems = const [];

  int _histPage = 1;
  final int _histPageSize = 10;
  int _histTotal = 0;
  List<Map<String, dynamic>> _histItems = const [];

  Map<String, dynamic>? _selectedAudit;
  Map<String, dynamic>? _auditDetalle;
  Map<String, dynamic>? _lastRecalcResult;
  Map<String, dynamic>? _historialDetalle;
  Map<String, dynamic>? _configCreacionResult;

  String? _statusConfiguracion;
  String? _statusAuditoria;
  String? _statusRecalculo;
  String? _statusHistorial;

  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    _addSubetiquetaDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAuditoria();
      await _loadHistorial();
    });
  }

  @override
  void dispose() {
    _configEtiquetaCodigoController.dispose();
    _configEtiquetaNombreController.dispose();
    _configEtiquetaDescripcionController.dispose();
    _auditSearchController.dispose();
    _auditEtiquetaController.dispose();
    _auditSubetiquetaController.dispose();
    _recalcEtiquetaController.dispose();
    _recalcReglaVersionController.dispose();
    _recalcIngredienteController.dispose();
    _recalcMaxIngredientesController.dispose();
    _histEtiquetaController.dispose();
    _histReglaVersionController.dispose();
    for (final draft in _subetiquetaDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addSubetiquetaDraft() {
    final draft = _SubetiquetaDraft(prioridad: _subetiquetaDrafts.length + 1);
    _subetiquetaDrafts.add(draft);
  }

  void _resetConfiguracionForm() {
    _configEtiquetaCodigoController.clear();
    _configEtiquetaNombreController.clear();
    _configEtiquetaDescripcionController.clear();
    _configEtiquetaActiva = true;
    _configCrearReglaInicial = true;
    _configEstadoReglaInicial = "BORRADOR";
    for (final draft in _subetiquetaDrafts) {
      draft.dispose();
    }
    _subetiquetaDrafts.clear();
    _addSubetiquetaDraft();
  }

  int? _parseInt(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
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
      final message = map["message"];
      if (message != null) {
        return message.toString();
      }
      return null;
    }
    if (payload is List) {
      return payload.map((e) => e.toString()).join(" | ");
    }
    return payload.toString();
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      final detail = _extractDetail(error.response?.data);
      if (detail != null && detail.trim().isNotEmpty) {
        return detail;
      }
      return "Error API ${code ?? "desconocido"}";
    }
    return error.toString();
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic data) {
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _loadAuditoria() async {
    setState(() {
      _loadingAuditoria = true;
      _statusAuditoria = null;
    });

    try {
      final response = await _dio.get(
        "/nutricionista/etiquetado/auditoria",
        queryParameters: {
          "page": _auditPage,
          "page_size": _auditPageSize,
          if (_auditSearchController.text.trim().isNotEmpty)
            "search": _auditSearchController.text.trim(),
          if (_parseInt(_auditEtiquetaController.text) != null)
            "id_etiqueta": _parseInt(_auditEtiquetaController.text),
          if (_parseInt(_auditSubetiquetaController.text) != null)
            "id_subetiqueta": _parseInt(_auditSubetiquetaController.text),
        },
      );

      final payload = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) {
        return;
      }

      setState(() {
        _auditTotal = (payload["total"] as num?)?.toInt() ?? 0;
        _auditItems = _asListOfMap(payload["items"]);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusAuditoria = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAuditoria = false;
        });
      }
    }
  }

  Future<void> _crearEtiquetaConSubetiquetas() async {
    final codigoEtiqueta = _configEtiquetaCodigoController.text.trim();
    final nombreEtiqueta = _configEtiquetaNombreController.text.trim();

    if (codigoEtiqueta.isEmpty || nombreEtiqueta.isEmpty) {
      setState(() {
        _statusConfiguracion = "Completa codigo y nombre visible de la etiqueta.";
      });
      return;
    }

    final subetiquetasPayload = <Map<String, dynamic>>[];
    for (final draft in _subetiquetaDrafts) {
      final codigo = draft.codigoController.text.trim();
      final nombre = draft.nombreController.text.trim();
      final prioridad = _parseInt(draft.prioridadController.text) ?? 1;

      if (codigo.isEmpty || nombre.isEmpty) {
        setState(() {
          _statusConfiguracion =
              "Cada subetiqueta requiere codigo y nombre visible.";
        });
        return;
      }

      final subsubetiquetasPayload = <Map<String, dynamic>>[];
      final lines = draft.subsubController.text
          .split("\n")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      for (var i = 0; i < lines.length; i++) {
        final parts = lines[i].split("|").map((e) => e.trim()).toList();
        final childCodigo = parts.isNotEmpty ? parts[0] : "";
        final childNombre = parts.length >= 2 ? parts[1] : childCodigo;
        final childPrioridad = parts.length >= 3
            ? (int.tryParse(parts[2]) ?? (i + 1))
            : (i + 1);

        if (childCodigo.isEmpty || childNombre.isEmpty) {
          setState(() {
            _statusConfiguracion =
                "Formato de subsubetiquetas invalido. Usa codigo|nombre|prioridad.";
          });
          return;
        }

        subsubetiquetasPayload.add({
          "codigo": childCodigo,
          "nombre_visible": childNombre,
          "prioridad_relativa": childPrioridad,
          "activa": draft.activa,
          "tipo_evaluacion": draft.tipoEvaluacion,
        });
      }

      subetiquetasPayload.add({
        "codigo": codigo,
        "nombre_visible": nombre,
        "prioridad": prioridad,
        "descripcion": draft.descripcionController.text.trim().isEmpty
            ? null
            : draft.descripcionController.text.trim(),
        "activa": draft.activa,
        "tipo_evaluacion": draft.tipoEvaluacion,
        "subsubetiquetas": subsubetiquetasPayload,
      });
    }

    setState(() {
      _savingConfiguracion = true;
      _statusConfiguracion = null;
    });

    try {
      final response = await _dio.post(
        "/nutricionista/etiquetado/config/etiquetas",
        data: {
          "codigo": codigoEtiqueta,
          "nombre_visible": nombreEtiqueta,
          "descripcion": _configEtiquetaDescripcionController.text.trim().isEmpty
              ? null
              : _configEtiquetaDescripcionController.text.trim(),
          "activa": _configEtiquetaActiva,
          "crear_regla_inicial": _configCrearReglaInicial,
          "estado_regla_inicial": _configEstadoReglaInicial,
          "subetiquetas": subetiquetasPayload,
        },
      );

      if (!mounted) {
        return;
      }

      final result = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _configCreacionResult = result;
        _statusConfiguracion = "Etiqueta creada correctamente.";
        final idEtiqueta = (result["id_etiqueta"] as num?)?.toInt();
        final idRegla = (result["id_regla_version_inicial"] as num?)?.toInt();
        if (idEtiqueta != null) {
          _recalcEtiquetaController.text = idEtiqueta.toString();
        }
        if (idRegla != null) {
          _recalcReglaVersionController.text = idRegla.toString();
        }
      });

      await _loadAuditoria();
      await _loadHistorial();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusConfiguracion = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingConfiguracion = false;
        });
      }
    }
  }

  Future<void> _loadAuditoriaDetalle(Map<String, dynamic> row) async {
    final ingredienteId = (row["ingrediente_id"] as num?)?.toInt();
    final etiquetaId = (row["etiqueta_id"] as num?)?.toInt();
    final reglaVersionId = (row["regla_version_id"] as num?)?.toInt();

    if (ingredienteId == null || etiquetaId == null) {
      return;
    }

    setState(() {
      _selectedAudit = row;
      _loadingDetalleAuditoria = true;
      _statusAuditoria = null;
    });

    try {
      final response = await _dio.get(
        "/nutricionista/etiquetado/auditoria/detalle",
        queryParameters: {
          "id_ingrediente": ingredienteId,
          "id_etiqueta": etiquetaId,
          if (reglaVersionId != null) "id_regla_version": reglaVersionId,
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _auditDetalle = Map<String, dynamic>.from(response.data as Map);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusAuditoria = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetalleAuditoria = false;
        });
      }
    }
  }

  Future<void> _runRecalculo() async {
    final payload = <String, dynamic>{
      "solo_activos": _recalcSoloActivos,
      "dry_run": _recalcDryRun,
      "stop_on_error": _recalcStopOnError,
    };

    final idEtiqueta = _parseInt(_recalcEtiquetaController.text);
    final idReglaVersion = _parseInt(_recalcReglaVersionController.text);
    final idIngrediente = _parseInt(_recalcIngredienteController.text);
    final maxIngredientes = _parseInt(_recalcMaxIngredientesController.text);

    if (idEtiqueta != null) {
      payload["id_etiqueta"] = idEtiqueta;
    }
    if (idReglaVersion != null) {
      payload["id_regla_version"] = idReglaVersion;
    }
    if (idIngrediente != null) {
      payload["id_ingrediente"] = idIngrediente;
    }
    if (maxIngredientes != null) {
      payload["max_ingredientes"] = maxIngredientes;
    }

    setState(() {
      _runningRecalculo = true;
      _statusRecalculo = null;
    });

    try {
      final response = await _dio.post(
        "/nutricionista/etiquetado/recalculo",
        data: payload,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastRecalcResult = Map<String, dynamic>.from(response.data as Map);
        _statusRecalculo = "Recalculo ejecutado correctamente.";
      });

      await _loadAuditoria();
      await _loadHistorial();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusRecalculo = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _runningRecalculo = false;
        });
      }
    }
  }

  Future<void> _loadHistorial() async {
    setState(() {
      _loadingHistorial = true;
      _statusHistorial = null;
    });

    try {
      final response = await _dio.get(
        "/nutricionista/etiquetado/recalculo/historial",
        queryParameters: {
          "page": _histPage,
          "page_size": _histPageSize,
          if (_parseInt(_histEtiquetaController.text) != null)
            "id_etiqueta": _parseInt(_histEtiquetaController.text),
          if (_parseInt(_histReglaVersionController.text) != null)
            "id_regla_version": _parseInt(_histReglaVersionController.text),
        },
      );

      final payload = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) {
        return;
      }

      setState(() {
        _histTotal = (payload["total"] as num?)?.toInt() ?? 0;
        _histItems = _asListOfMap(payload["items"]);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusHistorial = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistorial = false;
        });
      }
    }
  }

  Future<void> _loadHistorialDetalle(int idLog) async {
    setState(() {
      _loadingHistorialDetalle = true;
      _statusHistorial = null;
    });

    try {
      final response = await _dio.get(
        "/nutricionista/etiquetado/recalculo/historial/$idLog",
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _historialDetalle = Map<String, dynamic>.from(response.data as Map);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusHistorial = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistorialDetalle = false;
        });
      }
    }
  }

  Widget _buildAuditTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _auditSearchController,
                decoration: const InputDecoration(
                  labelText: "Buscar ingrediente",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _auditEtiquetaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "ID etiqueta",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _auditSubetiquetaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "ID subetiqueta",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _loadingAuditoria ? null : () {
                _auditPage = 1;
                _loadAuditoria();
              },
              icon: const Icon(Icons.filter_alt),
              label: const Text("Aplicar"),
            ),
            OutlinedButton.icon(
              onPressed: _loadingAuditoria ? null : _loadAuditoria,
              icon: const Icon(Icons.refresh),
              label: const Text("Recargar"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text("Total: $_auditTotal")),
            Chip(label: Text("Pagina: $_auditPage")),
            Chip(label: Text("Mostrando: ${_auditItems.length}")),
          ],
        ),
        if (_statusAuditoria != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusAuditoria!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _loadingAuditoria
                    ? const Center(child: CircularProgressIndicator())
                    : _auditItems.isEmpty
                        ? const Center(child: Text("Sin resultados de auditoria"))
                        : ListView.builder(
                            itemCount: _auditItems.length,
                            itemBuilder: (context, index) {
                              final row = _auditItems[index];
                              final selected =
                                  _selectedAudit?["ingrediente_id"] == row["ingrediente_id"] &&
                                      _selectedAudit?["etiqueta_id"] == row["etiqueta_id"];
                              return Card(
                                color: selected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.42)
                                    : null,
                                child: ListTile(
                                  onTap: () => _loadAuditoriaDetalle(row),
                                  title: Text(
                                    row["ingrediente_nombre"]?.toString() ??
                                        "Ingrediente",
                                  ),
                                  subtitle: Text(
                                    "${row["etiqueta_nombre"] ?? "Etiqueta"} -> ${row["subetiqueta_nombre"] ?? "Subetiqueta"}",
                                  ),
                                  trailing: Text(
                                    "v${row["regla_version_numero"] ?? "?"}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _loadingDetalleAuditoria
                        ? const Center(child: CircularProgressIndicator())
                        : _auditDetalle == null
                            ? const Text("Selecciona un resultado para ver detalle.")
                            : _buildAuditDetailContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton(
              onPressed: _loadingAuditoria || _auditPage <= 1
                  ? null
                  : () {
                      setState(() {
                        _auditPage -= 1;
                      });
                      _loadAuditoria();
                    },
              child: const Text("Pagina anterior"),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _loadingAuditoria || (_auditPage * _auditPageSize) >= _auditTotal
                  ? null
                  : () {
                      setState(() {
                        _auditPage += 1;
                      });
                      _loadAuditoria();
                    },
              child: const Text("Pagina siguiente"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfiguracionTab() {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Asistente de creacion",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text("1) Define la etiqueta principal."),
                Text("2) Agrega subetiquetas y prioridades."),
                Text(
                  "3) (Opcional) En cada subetiqueta escribe subsubetiquetas en lineas con formato: codigo|nombre|prioridad.",
                ),
                Text("4) Guarda y usa los IDs autocompletados en Recalculo."),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Etiqueta principal",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _configEtiquetaCodigoController,
                        decoration: const InputDecoration(
                          labelText: "Codigo",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _configEtiquetaNombreController,
                        decoration: const InputDecoration(
                          labelText: "Nombre visible",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _configEstadoReglaInicial,
                        decoration: const InputDecoration(
                          labelText: "Estado regla inicial",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: "BORRADOR",
                            child: Text("BORRADOR"),
                          ),
                          DropdownMenuItem(
                            value: "PUBLICADA",
                            child: Text("PUBLICADA"),
                          ),
                          DropdownMenuItem(
                            value: "INACTIVA",
                            child: Text("INACTIVA"),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _configEstadoReglaInicial = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _configEtiquetaDescripcionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Descripcion (opcional)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _configEtiquetaActiva,
                          onChanged: (value) =>
                              setState(() => _configEtiquetaActiva = value),
                        ),
                        const Text("Etiqueta activa"),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _configCrearReglaInicial,
                          onChanged: (value) =>
                              setState(() => _configCrearReglaInicial = value),
                        ),
                        const Text("Crear regla inicial"),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Subetiquetas",
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < _subetiquetaDrafts.length; index++)
          _buildSubetiquetaCard(index),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _savingConfiguracion
                  ? null
                  : () {
                      setState(() {
                        _addSubetiquetaDraft();
                      });
                    },
              icon: const Icon(Icons.add),
              label: const Text("Agregar subetiqueta"),
            ),
            OutlinedButton.icon(
              onPressed: _savingConfiguracion
                  ? null
                  : () {
                      setState(() {
                        _resetConfiguracionForm();
                        _configCreacionResult = null;
                        _statusConfiguracion = null;
                      });
                    },
              icon: const Icon(Icons.cleaning_services),
              label: const Text("Limpiar formulario"),
            ),
            FilledButton.icon(
              onPressed:
                  _savingConfiguracion ? null : _crearEtiquetaConSubetiquetas,
              icon: _savingConfiguracion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text("Guardar etiqueta"),
            ),
          ],
        ),
        if (_statusConfiguracion != null) ...[
          const SizedBox(height: 10),
          Text(
            _statusConfiguracion!,
            style: TextStyle(
              color: _statusConfiguracion!.contains("correctamente")
                  ? const Color(0xFF17642C)
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (_configCreacionResult != null) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Resultado de creacion",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          "id_etiqueta: ${_configCreacionResult!["id_etiqueta"] ?? "-"}",
                        ),
                      ),
                      Chip(
                        label: Text(
                          "id_regla: ${_configCreacionResult!["id_regla_version_inicial"] ?? "-"}",
                        ),
                      ),
                      Chip(
                        label: Text(
                          "subetiquetas: ${(_configCreacionResult!["subetiquetas_creadas"] as List?)?.length ?? 0}",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubetiquetaCard(int index) {
    final draft = _subetiquetaDrafts[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Subetiqueta ${index + 1}",
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  tooltip: "Eliminar",
                  onPressed: _savingConfiguracion || _subetiquetaDrafts.length <= 1
                      ? null
                      : () {
                          setState(() {
                            final removed = _subetiquetaDrafts.removeAt(index);
                            removed.dispose();
                          });
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: draft.codigoController,
                    decoration: const InputDecoration(
                      labelText: "Codigo",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: draft.nombreController,
                    decoration: const InputDecoration(
                      labelText: "Nombre visible",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: draft.prioridadController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Prioridad",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.tipoEvaluacion,
                    decoration: const InputDecoration(
                      labelText: "Tipo evaluacion",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "FIRST_MATCH",
                        child: Text("FIRST_MATCH"),
                      ),
                      DropdownMenuItem(
                        value: "ALL_TRUE",
                        child: Text("ALL_TRUE"),
                      ),
                      DropdownMenuItem(
                        value: "ANY_TRUE",
                        child: Text("ANY_TRUE"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        draft.tipoEvaluacion = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.descripcionController,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Descripcion (opcional)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: draft.activa,
                  onChanged: (value) {
                    setState(() {
                      draft.activa = value;
                    });
                  },
                ),
                const Text("Subetiqueta activa"),
              ],
            ),
            TextField(
              controller: draft.subsubController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Subsubetiquetas (una por linea: codigo|nombre|prioridad)",
                border: OutlineInputBorder(),
                helperText:
                    "Ejemplo: ALTO_AZU|Alto azucar|1. Se convertiran en subetiquetas hijas.",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditDetailContent() {
    final detalle = _auditDetalle ?? {};
    final ganador = detalle["resultado_ganador"] is Map
        ? Map<String, dynamic>.from(detalle["resultado_ganador"] as Map)
        : <String, dynamic>{};
    final candidatas = _asListOfMap(detalle["subetiquetas_candidatas"]);

    return ListView(
      children: [
        Text(
          "Ganadora: ${ganador["subetiqueta_nombre"] ?? "-"}",
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text("Ingrediente: ${ganador["ingrediente_nombre"] ?? "-"}"),
        Text("Etiqueta: ${ganador["etiqueta_nombre"] ?? "-"}"),
        Text("Version regla: ${ganador["regla_version_numero"] ?? "-"}"),
        Text("Valor disparador: ${ganador["valor_disparador"] ?? "-"}"),
        const Divider(height: 24),
        Text(
          "Subetiquetas candidatas",
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final row in candidatas)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(row["subetiqueta_nombre"]?.toString() ?? "Subetiqueta"),
              subtitle: Text(
                "prioridad=${row["prioridad_evaluacion"] ?? "-"} | tipo=${row["tipo_evaluacion"] ?? "-"}",
              ),
              trailing: (row["es_ganadora"] == true)
                  ? const Chip(label: Text("Ganadora"))
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildRecalculoTab() {
    return ListView(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _recalcEtiquetaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "ID etiqueta",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _recalcReglaVersionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "ID regla version",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _recalcIngredienteController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "ID ingrediente",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _recalcMaxIngredientesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Max ingredientes",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: _recalcDryRun,
                  onChanged: (value) => setState(() => _recalcDryRun = value),
                ),
                const Text("Dry run"),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: _recalcSoloActivos,
                  onChanged: (value) =>
                      setState(() => _recalcSoloActivos = value),
                ),
                const Text("Solo activos"),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: _recalcStopOnError,
                  onChanged: (value) =>
                      setState(() => _recalcStopOnError = value),
                ),
                const Text("Detener en error"),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _runningRecalculo ? null : _runRecalculo,
              icon: _runningRecalculo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text("Ejecutar recalculo"),
            ),
            OutlinedButton.icon(
              onPressed: _runningRecalculo
                  ? null
                  : () {
                      setState(() {
                        _recalcDryRun = true;
                      });
                      _runRecalculo();
                    },
              icon: const Icon(Icons.visibility),
              label: const Text("Probar en dry run"),
            ),
          ],
        ),
        if (_statusRecalculo != null) ...[
          const SizedBox(height: 10),
          Text(
            _statusRecalculo!,
            style: TextStyle(
              color: _statusRecalculo!.contains("correctamente")
                  ? const Color(0xFF17642C)
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_lastRecalcResult != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ultimo resultado",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text("scope: ${_lastRecalcResult!["scope"]}")),
                      Chip(label: Text("reglas: ${_lastRecalcResult!["reglas_procesadas"]}")),
                      Chip(label: Text("ingredientes: ${_lastRecalcResult!["ingredientes_en_alcance"]}")),
                      Chip(label: Text("ins: ${_lastRecalcResult!["insertados"]}")),
                      Chip(label: Text("upd: ${_lastRecalcResult!["actualizados"]}")),
                      Chip(label: Text("del: ${_lastRecalcResult!["eliminados"]}")),
                      Chip(label: Text("err: ${_lastRecalcResult!["errores"]}")),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistorialTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _histEtiquetaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Filtrar ID etiqueta",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: _histReglaVersionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Filtrar ID regla version",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _loadingHistorial
                  ? null
                  : () {
                      _histPage = 1;
                      _loadHistorial();
                    },
              icon: const Icon(Icons.filter_alt),
              label: const Text("Aplicar"),
            ),
            OutlinedButton.icon(
              onPressed: _loadingHistorial ? null : _loadHistorial,
              icon: const Icon(Icons.refresh),
              label: const Text("Recargar"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text("Total: $_histTotal")),
            Chip(label: Text("Pagina: $_histPage")),
            Chip(label: Text("Mostrando: ${_histItems.length}")),
          ],
        ),
        if (_statusHistorial != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusHistorial!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _loadingHistorial
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _histItems.length,
                        itemBuilder: (context, index) {
                          final row = _histItems[index];
                          final idLog = (row["id_log"] as num?)?.toInt() ?? 0;
                          return Card(
                            child: ListTile(
                              title: Text(
                                "Log #$idLog | scope ${row["scope"] ?? "-"}",
                              ),
                              subtitle: Text(
                                "${row["fecha_registro"] ?? ""} | err=${row["errores"] ?? 0}",
                              ),
                              trailing: TextButton(
                                onPressed: idLog <= 0
                                    ? null
                                    : () => _loadHistorialDetalle(idLog),
                                child: const Text("Ver detalle"),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _loadingHistorialDetalle
                        ? const Center(child: CircularProgressIndicator())
                        : _historialDetalle == null
                            ? const Text("Selecciona un log para ver su detalle completo.")
                            : _buildHistorialDetailContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton(
              onPressed: _loadingHistorial || _histPage <= 1
                  ? null
                  : () {
                      setState(() {
                        _histPage -= 1;
                      });
                      _loadHistorial();
                    },
              child: const Text("Pagina anterior"),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _loadingHistorial || (_histPage * _histPageSize) >= _histTotal
                  ? null
                  : () {
                      setState(() {
                        _histPage += 1;
                      });
                      _loadHistorial();
                    },
              child: const Text("Pagina siguiente"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistorialDetailContent() {
    final detalle = _historialDetalle ?? {};
    final item = detalle["item"] is Map
        ? Map<String, dynamic>.from(detalle["item"] as Map)
        : <String, dynamic>{};
    final requestPayload = detalle["request_payload"];
    final resultPayload = detalle["result_payload"];
    final metaPayload = detalle["meta_payload"];

    final encoder = const JsonEncoder.withIndent("  ");

    String encode(dynamic value) {
      try {
        return encoder.convert(value);
      } catch (_) {
        return value.toString();
      }
    }

    return ListView(
      children: [
        Text(
          "Log #${item["id_log"] ?? "-"}",
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text("Fecha: ${item["fecha_registro"] ?? "-"}"),
        Text("Scope: ${item["scope"] ?? "-"}"),
        Text("Errores: ${item["errores"] ?? 0}"),
        const SizedBox(height: 10),
        if (detalle["detalle"] != null)
          Text(
            "Resumen: ${detalle["detalle"]}",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: 10),
        ExpansionTile(
          initiallyExpanded: false,
          title: const Text("Request payload"),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF6F8FA),
              child: SelectableText(encode(requestPayload)),
            ),
          ],
        ),
        ExpansionTile(
          initiallyExpanded: false,
          title: const Text("Result payload"),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF6F8FA),
              child: SelectableText(encode(resultPayload)),
            ),
          ],
        ),
        ExpansionTile(
          initiallyExpanded: false,
          title: const Text("Meta payload"),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF6F8FA),
              child: SelectableText(encode(metaPayload)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Etiquetas Automaticas",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            "Configura etiquetas jerarquicas y controla auditoria, recalculo e historial.",
            style: TextStyle(
              color: Color(0xFF556170),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.account_tree_outlined), text: "Configurar"),
              Tab(icon: Icon(Icons.fact_check), text: "Auditoria"),
              Tab(icon: Icon(Icons.sync), text: "Recalculo"),
              Tab(icon: Icon(Icons.history), text: "Historial"),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _buildConfiguracionTab(),
                _buildAuditTab(),
                _buildRecalculoTab(),
                _buildHistorialTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
