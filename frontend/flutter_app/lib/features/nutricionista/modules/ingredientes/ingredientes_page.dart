import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class IngredientesPage extends ConsumerStatefulWidget {
  const IngredientesPage({super.key});

  @override
  ConsumerState<IngredientesPage> createState() => _IngredientesPageState();
}

class _IngredientesPageState extends ConsumerState<IngredientesPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = false;
  bool _loadingMore = false;
  String _searchQuery = "";
  static const int _pageSize = 20;
  int _totalIngredientes = 0;
  List<Map<String, dynamic>> _ingredientes = const [];
  List<Map<String, dynamic>> _grupos = const [];
  List<Map<String, dynamic>> _subgrupos = const [];
  int? _selectedGrupoId;
  int? _selectedSubgrupoId;
  bool _includeInactive = false;
  List<Map<String, dynamic>> _catalogoEtiquetas = const [];
  final Map<int, List<Map<String, dynamic>>> _etiquetasPorIngrediente = {};
  final Set<int> _loadingEtiquetasIngredientes = <int>{};
  String? _error;

  List<Map<String, dynamic>> get _subgruposFiltrados {
    if (_selectedGrupoId == null) {
      return _subgrupos;
    }
    return _subgrupos.where((row) {
      final idGrupo = (row["id_grupo_alimentario"] as num?)?.toInt();
      return idGrupo == _selectedGrupoId;
    }).toList();
  }

  int? _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value.trim().replaceAll(",", "."));
    }
    return null;
  }

  String _composicionLabel(String codigo) {
    final clean = codigo.trim();
    if (clean.isEmpty) {
      return "Variable";
    }
    final normalized = clean.replaceAll("_", " ");
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  bool _isComposicionMacro(String codigo) {
    final token = codigo.toLowerCase();
    const macroTokens = [
      "energia",
      "agua",
      "alcohol",
      "prote",
      "hidrato",
      "almidon",
      "azucar",
      "fibra",
      "grasa",
      "ags",
      "agm",
      "agp",
      "colesterol",
      "omega",
      "trans",
    ];
    return macroTokens.any(token.contains);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final querySnapshot = _searchQuery;
    final grupoSnapshot = _selectedGrupoId;
    final subgrupoSnapshot = _selectedSubgrupoId;
    final includeInactiveSnapshot = _includeInactive;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final page = await repo.fetchIngredientesPaged(
        query: querySnapshot.isEmpty ? null : querySnapshot,
        idGrupoAlimentario: grupoSnapshot,
        idSubgrupoAlimentario: subgrupoSnapshot,
        includeInactive: includeInactiveSnapshot,
        limit: _pageSize,
        offset: 0,
      );
      final data = List<Map<String, dynamic>>.from(page["items"] as List);
      final total = (page["total"] as num?)?.toInt() ?? data.length;
      final etiquetas = await repo.fetchEtiquetas();
      final grupos = await repo.fetchCatalog("nutricion", "grupo_alimentario");
      final subgrupos = await repo.fetchCatalog("nutricion", "subgrupo_alimentario");
      final ingredientIds = data
          .map((row) => (row["id"] as num?)?.toInt())
          .whereType<int>()
          .toSet();
      if (!mounted ||
          querySnapshot != _searchQuery ||
          grupoSnapshot != _selectedGrupoId ||
          subgrupoSnapshot != _selectedSubgrupoId ||
          includeInactiveSnapshot != _includeInactive) {
        return;
      }
      setState(() {
        _ingredientes = data;
        _totalIngredientes = total;
        _grupos = grupos;
        _subgrupos = subgrupos;
        _catalogoEtiquetas = etiquetas;
        _loadingMore = false;
        _etiquetasPorIngrediente.removeWhere((id, _) => !ingredientIds.contains(id));
        _loadingEtiquetasIngredientes.removeWhere((id) => !ingredientIds.contains(id));
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadEtiquetasIngrediente(int idIngrediente) async {
    if (!_loadingEtiquetasIngredientes.contains(idIngrediente)) {
      _loadingEtiquetasIngredientes.add(idIngrediente);
      if (mounted) {
        setState(() {});
      }
    }

    final repo = ref.read(supabaseCrudRepositoryProvider);
    try {
      final etiquetas = await repo.fetchEtiquetasByIngrediente(idIngrediente);
      if (!mounted) {
        return;
      }
      setState(() {
        _etiquetasPorIngrediente[idIngrediente] = etiquetas;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingEtiquetasIngredientes.remove(idIngrediente);
        });
      } else {
        _loadingEtiquetasIngredientes.remove(idIngrediente);
      }
    }
  }

  Future<void> _ensureEtiquetasIngredienteLoaded(int idIngrediente) async {
    if (_etiquetasPorIngrediente.containsKey(idIngrediente) ||
        _loadingEtiquetasIngredientes.contains(idIngrediente)) {
      return;
    }

    _loadingEtiquetasIngredientes.add(idIngrediente);
    if (mounted) {
      setState(() {});
    }

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final etiquetas = await repo.fetchEtiquetasByIngrediente(idIngrediente);
      if (!mounted) {
        return;
      }
      setState(() {
        _etiquetasPorIngrediente[idIngrediente] = etiquetas;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _etiquetasPorIngrediente[idIngrediente] = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingEtiquetasIngredientes.remove(idIngrediente);
        });
      } else {
        _loadingEtiquetasIngredientes.remove(idIngrediente);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      final normalized = value.trim().toLowerCase();
      if (normalized == _searchQuery) {
        return;
      }
      setState(() {
        _searchQuery = normalized;
      });
      _loadData();
    });
  }

  void _onGrupoFilterChanged(int? value) {
    final sameValue = value == _selectedGrupoId;
    final keepSubgrupo = _selectedSubgrupoId != null &&
        _subgrupos.any((row) {
          final id = _asInt(row["id"]);
          final idGrupo = _asInt(row["id_grupo_alimentario"]);
          return id == _selectedSubgrupoId && (value == null || idGrupo == value);
        });

    setState(() {
      _selectedGrupoId = value;
      if (!keepSubgrupo) {
        _selectedSubgrupoId = null;
      }
    });

    if (!sameValue) {
      _loadData();
    }
  }

  void _onSubgrupoFilterChanged(int? value) {
    if (value == _selectedSubgrupoId) {
      return;
    }
    setState(() {
      _selectedSubgrupoId = value;
    });
    _loadData();
  }

  void _onIncludeInactiveChanged(bool value) {
    if (value == _includeInactive) {
      return;
    }
    setState(() {
      _includeInactive = value;
    });
    _loadData();
  }

  void _clearFiltros() {
    if (_searchQuery.isEmpty &&
        _selectedGrupoId == null &&
        _selectedSubgrupoId == null &&
        !_includeInactive) {
      return;
    }
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = "";
      _selectedGrupoId = null;
      _selectedSubgrupoId = null;
      _includeInactive = false;
    });
    _loadData();
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _ingredientes.length >= _totalIngredientes) {
      return;
    }

    final querySnapshot = _searchQuery;
    final grupoSnapshot = _selectedGrupoId;
    final subgrupoSnapshot = _selectedSubgrupoId;
    final includeInactiveSnapshot = _includeInactive;

    setState(() {
      _loadingMore = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final page = await repo.fetchIngredientesPaged(
        query: querySnapshot.isEmpty ? null : querySnapshot,
        idGrupoAlimentario: grupoSnapshot,
        idSubgrupoAlimentario: subgrupoSnapshot,
        includeInactive: includeInactiveSnapshot,
        limit: _pageSize,
        offset: _ingredientes.length,
      );
      final data = List<Map<String, dynamic>>.from(page["items"] as List);
      final total = (page["total"] as num?)?.toInt() ?? _ingredientes.length;
      final currentIds = _ingredientes
          .map((row) => (row["id"] as num?)?.toInt())
          .whereType<int>()
          .toSet();
      final newRows = data.where((row) {
        final id = (row["id"] as num?)?.toInt();
        if (id == null || currentIds.contains(id)) {
          return false;
        }
        currentIds.add(id);
        return true;
      }).toList();

      if (!mounted ||
          querySnapshot != _searchQuery ||
          grupoSnapshot != _selectedGrupoId ||
          subgrupoSnapshot != _selectedSubgrupoId ||
          includeInactiveSnapshot != _includeInactive) {
        return;
      }

      setState(() {
        _ingredientes = [..._ingredientes, ...newRows];
        _totalIngredientes = total;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
      _showMessage("No fue posible cargar mas ingredientes.", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshCatalogoEtiquetas() async {
    final repo = ref.read(supabaseCrudRepositoryProvider);
    final etiquetas = await repo.fetchEtiquetas();
    if (!mounted) {
      return;
    }
    setState(() {
      _catalogoEtiquetas = etiquetas;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : const Color(0xFF16683B),
      ),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    String confirmLabel = "Confirmar",
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _openNuevoIngredientePage() async {
    final payload = await Navigator.of(context).push<_NuevoIngredientePayload>(
      MaterialPageRoute<_NuevoIngredientePayload>(
        builder: (_) => _NuevoIngredientePage(
          grupos: _grupos,
          subgrupos: _subgrupos,
          asInt: _asInt,
        ),
      ),
    );

    if (payload == null) {
      return;
    }

    await _createIngredienteFromPayload(payload);
  }

  Future<void> _createIngredienteFromPayload(_NuevoIngredientePayload payload) async {
    if (payload.nombre.trim().isEmpty) {
      setState(() {
        _error = "Escribe el nombre del ingrediente.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final createdId = await repo.createIngrediente(
        nombre: payload.nombre.trim(),
        idGrupoAlimentario: payload.idGrupoAlimentario,
        idSubgrupoAlimentario: payload.idSubgrupoAlimentario,
        precioLibra: payload.precioLibra,
        factorParteComestible: payload.factorParteComestible,
        imagenReferencia: payload.imagenReferencia,
      );

      if (createdId != null && payload.composicionInicial.isNotEmpty) {
        await repo.upsertIngredienteComposicion(
          idIngrediente: createdId,
          valores: payload.composicionInicial,
        );
      }

      await _loadData();
      _showMessage("Ingrediente creado correctamente.");
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
      _showMessage("No fue posible crear el ingrediente.", isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showEditarIngredienteDialog(Map<String, dynamic> ingrediente) async {
    final idIngrediente = (ingrediente["id"] as num?)?.toInt();
    if (idIngrediente == null) {
      return;
    }

    final grupoInicial = _asInt(ingrediente["id_grupo_alimentario"]);
    final subgrupoInicial = _asInt(ingrediente["id_subgrupo_alimentario"]);
    final precioInicial = _asDouble(ingrediente["precio_libra"]) ?? 0;
    final factorInicial = _asDouble(ingrediente["factor_parte_comestible"]) ?? 1;

    final nombreController = TextEditingController(
      text: ingrediente["nombre"]?.toString() ?? "",
    );
    final precioController = TextEditingController(text: precioInicial.toString());
    final factorController = TextEditingController(text: factorInicial.toString());
    final imagenController = TextEditingController(
      text: ingrediente["imagen_referencia"]?.toString() ?? "",
    );

    int? selectedGrupoId =
        grupoInicial ?? (_grupos.isNotEmpty ? _asInt(_grupos.first["id"]) : null);
    int? selectedSubgrupoId = subgrupoInicial;
    bool activo = ingrediente["activo"] == true;
    String? dialogError;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void safeSetDialogState(VoidCallback fn) {
              if (!dialogContext.mounted) {
                return;
              }
              setDialogState(fn);
            }

            final subgruposDisponibles = _subgrupos.where((row) {
              final idGrupo = _asInt(row["id_grupo_alimentario"]);
              return selectedGrupoId == null || idGrupo == selectedGrupoId;
            }).toList();

            if (selectedSubgrupoId != null &&
                subgruposDisponibles.every(
                    (row) => _asInt(row["id"]) != selectedSubgrupoId)) {
              selectedSubgrupoId = null;
            }

            return AlertDialog(
              title: const Text("Editar ingrediente"),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nombreController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: "Nombre",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedGrupoId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Grupo alimentario",
                          border: OutlineInputBorder(),
                        ),
                        items: _grupos
                            .map(
                              (row) => DropdownMenuItem<int>(
                                value: _asInt(row["id"]),
                                child: Text(row["nombre"]?.toString() ?? "Grupo"),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                safeSetDialogState(() {
                                  selectedGrupoId = value;
                                  selectedSubgrupoId = null;
                                });
                              },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: selectedSubgrupoId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Subgrupo alimentario",
                          border: OutlineInputBorder(),
                        ),
                        items: subgruposDisponibles
                            .map(
                              (row) => DropdownMenuItem<int>(
                                value: _asInt(row["id"]),
                                child: Text(row["nombre"]?.toString() ?? "Subgrupo"),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                safeSetDialogState(() {
                                  selectedSubgrupoId = value;
                                });
                              },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: precioController,
                              enabled: !saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Precio por libra",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: factorController,
                              enabled: !saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Factor parte comestible",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: imagenController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: "Imagen (texto URL/ruta)",
                          border: OutlineInputBorder(),
                          hintText: "https://... o ruta textual",
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: activo,
                        onChanged: saving
                            ? null
                            : (value) {
                                safeSetDialogState(() {
                                  activo = value;
                                });
                              },
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Ingrediente activo"),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          dialogError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancelar"),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final nombre = nombreController.text.trim();
                          final precio =
                              double.tryParse(precioController.text.trim().replaceAll(",", "."));
                          final factor =
                              double.tryParse(factorController.text.trim().replaceAll(",", "."));

                          if (nombre.isEmpty) {
                            safeSetDialogState(() {
                              dialogError = "El nombre es obligatorio.";
                            });
                            return;
                          }
                          if (selectedGrupoId == null) {
                            safeSetDialogState(() {
                              dialogError = "Selecciona un grupo alimentario.";
                            });
                            return;
                          }
                          if (selectedSubgrupoId == null) {
                            safeSetDialogState(() {
                              dialogError = "Selecciona un subgrupo alimentario.";
                            });
                            return;
                          }
                          if (precio == null || precio < 0) {
                            safeSetDialogState(() {
                              dialogError = "Precio por libra no valido.";
                            });
                            return;
                          }
                          if (factor == null || factor <= 0) {
                            safeSetDialogState(() {
                              dialogError =
                                  "Factor de parte comestible debe ser mayor a 0.";
                            });
                            return;
                          }

                          safeSetDialogState(() {
                            saving = true;
                            dialogError = null;
                          });

                          try {
                            final repo = ref.read(supabaseCrudRepositoryProvider);
                            await repo.updateIngrediente(
                              idIngrediente: idIngrediente,
                              nombre: nombre,
                              idGrupoAlimentario: selectedGrupoId,
                              idSubgrupoAlimentario: selectedSubgrupoId,
                              precioLibra: precio,
                              factorParteComestible: factor,
                              imagenReferencia: imagenController.text.trim(),
                              activo: activo,
                            );
                            await _loadData();

                            if (!mounted || !dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop();
                            _showMessage("Ingrediente actualizado correctamente.");
                          } catch (error) {
                            safeSetDialogState(() {
                              dialogError = error.toString();
                              saving = false;
                            });
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );

    nombreController.dispose();
    precioController.dispose();
    factorController.dispose();
    imagenController.dispose();
  }

  Future<void> _showEditarComposicionDialog(Map<String, dynamic> ingrediente) async {
    final idIngrediente = (ingrediente["id"] as num?)?.toInt();
    if (idIngrediente == null) {
      return;
    }

    List<Map<String, dynamic>> columnas;
    Map<String, dynamic> valores;

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final payload = await repo.fetchIngredienteComposicion(idIngrediente);
      columnas = (payload["columnas"] is List)
          ? List<Map<String, dynamic>>.from(payload["columnas"] as List)
          : <Map<String, dynamic>>[];
      valores = (payload["valores"] is Map)
          ? Map<String, dynamic>.from(payload["valores"] as Map)
          : <String, dynamic>{};
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(
        "No fue posible cargar la composicion nutricional: $error",
        isError: true,
      );
      return;
    }

    if (columnas.isEmpty) {
      _showMessage("No hay variables de composicion configuradas.", isError: true);
      return;
    }

    final controllers = <String, TextEditingController>{};
    for (final column in columnas) {
      final codigo = column["codigo"]?.toString() ?? "";
      if (codigo.isEmpty) {
        continue;
      }
      final value = valores[codigo];
      controllers[codigo] = TextEditingController(
        text: value == null ? "" : value.toString(),
      );
    }

    bool saving = false;
    String? dialogError;
    String search = "";

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void safeSetDialogState(VoidCallback fn) {
              if (!dialogContext.mounted) {
                return;
              }
              setDialogState(fn);
            }

            final normalizedSearch = search.trim().toLowerCase();
            final visibleColumns = normalizedSearch.isEmpty
                ? columnas
                : columnas.where((column) {
                    final codigo = column["codigo"]?.toString().toLowerCase() ?? "";
                    final label = _composicionLabel(column["codigo"]?.toString() ?? "")
                        .toLowerCase();
                    return codigo.contains(normalizedSearch) ||
                        label.contains(normalizedSearch);
                  }).toList();

            final macroColumns = visibleColumns
                .where((column) =>
                    _isComposicionMacro(column["codigo"]?.toString() ?? ""))
                .toList();
            final microColumns = visibleColumns
                .where((column) =>
                    !_isComposicionMacro(column["codigo"]?.toString() ?? ""))
                .toList();

            Widget buildField(Map<String, dynamic> column) {
              final codigo = column["codigo"]?.toString() ?? "";
              final controller = controllers[codigo];
              if (codigo.isEmpty || controller == null) {
                return const SizedBox.shrink();
              }
              final tipo = column["tipo"]?.toString().toLowerCase() ?? "numeric";
              final isText = tipo.contains("character") || tipo == "text";
              return SizedBox(
                width: 250,
                child: TextField(
                  controller: controller,
                  enabled: !saving,
                  keyboardType: isText
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _composicionLabel(codigo),
                    border: const OutlineInputBorder(),
                    helperText: isText ? "Texto" : "Numero",
                  ),
                ),
              );
            }

            return AlertDialog(
              title: Text(
                "Composicion nutricional: ${ingrediente["nombre"] ?? "ingrediente"}",
              ),
              content: SizedBox(
                width: 920,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        enabled: !saving,
                        onChanged: (value) {
                          safeSetDialogState(() {
                            search = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: "Buscar variable",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Macronutrientes",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (macroColumns.isEmpty)
                        const Text(
                          "Sin variables macro para mostrar.",
                          style: TextStyle(color: Color(0xFF5B6978)),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: macroColumns.map(buildField).toList(),
                        ),
                      const SizedBox(height: 14),
                      const Text(
                        "Micronutrientes y otros",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (microColumns.isEmpty)
                        const Text(
                          "Sin variables micro para mostrar.",
                          style: TextStyle(color: Color(0xFF5B6978)),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: microColumns.map(buildField).toList(),
                        ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          dialogError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancelar"),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final payload = <String, dynamic>{};
                          for (final column in columnas) {
                            final codigo = column["codigo"]?.toString() ?? "";
                            if (codigo.isEmpty || !controllers.containsKey(codigo)) {
                              continue;
                            }

                            final tipo =
                                column["tipo"]?.toString().toLowerCase() ?? "numeric";
                            final isText =
                                tipo.contains("character") || tipo == "text";
                            final raw = controllers[codigo]!.text.trim();

                            if (isText) {
                              payload[codigo] = raw;
                              continue;
                            }

                            if (raw.isEmpty) {
                              payload[codigo] = 0;
                              continue;
                            }

                            final parsed =
                                double.tryParse(raw.replaceAll(",", "."));
                            if (parsed == null) {
                              safeSetDialogState(() {
                                dialogError =
                                    "Valor invalido para ${_composicionLabel(codigo)}";
                              });
                              return;
                            }
                            payload[codigo] = parsed;
                          }

                          safeSetDialogState(() {
                            saving = true;
                            dialogError = null;
                          });

                          try {
                            final repo = ref.read(supabaseCrudRepositoryProvider);
                            await repo.upsertIngredienteComposicion(
                              idIngrediente: idIngrediente,
                              valores: payload,
                            );
                            if (!mounted || !dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop();
                            _showMessage("Composicion nutricional actualizada.");
                          } catch (error) {
                            safeSetDialogState(() {
                              dialogError = error.toString();
                              saving = false;
                            });
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: const Text("Guardar composicion"),
                ),
              ],
            );
          },
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Future<void> _deleteIngrediente(Map<String, dynamic> ingrediente) async {
    final idIngrediente = (ingrediente["id"] as num?)?.toInt();
    final nombre = ingrediente["nombre"]?.toString() ?? "ingrediente";
    if (idIngrediente == null) {
      return;
    }

    final confirmed = await _confirmAction(
      title: "Eliminar ingrediente",
      message:
          "Se eliminara $nombre y sus relaciones manuales de etiquetas. Esta accion no se puede deshacer.",
      confirmLabel: "Eliminar",
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.deleteIngrediente(idIngrediente);
      await _loadData();
      _showMessage("Ingrediente eliminado correctamente.");
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
      _showMessage("No fue posible eliminar el ingrediente.", isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showGestionCatalogoEtiquetasDialog() async {
    final nuevaEtiquetaController = TextEditingController();
    bool saving = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void safeSetDialogState(VoidCallback fn) {
              if (!dialogContext.mounted) {
                return;
              }
              setDialogState(fn);
            }

            return AlertDialog(
              title: const Text("Catalogo de etiquetas"),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nuevaEtiquetaController,
                              enabled: !saving,
                              decoration: const InputDecoration(
                                labelText: "Nueva etiqueta",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    final nombre = nuevaEtiquetaController.text.trim();
                                    if (nombre.isEmpty) {
                                      safeSetDialogState(() {
                                        dialogError =
                                            "Escribe el nombre de la etiqueta.";
                                      });
                                      return;
                                    }

                                    safeSetDialogState(() {
                                      saving = true;
                                      dialogError = null;
                                    });

                                    try {
                                      final repo =
                                          ref.read(supabaseCrudRepositoryProvider);
                                      await repo.createEtiqueta(nombreVisible: nombre);
                                      await _refreshCatalogoEtiquetas();
                                      nuevaEtiquetaController.clear();
                                      if (mounted) {
                                        _showMessage(
                                          "Etiqueta creada correctamente.",
                                        );
                                      }
                                    } catch (error) {
                                      safeSetDialogState(() {
                                        dialogError = error.toString();
                                      });
                                    } finally {
                                      safeSetDialogState(() {
                                        saving = false;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text("Crear"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (dialogError != null)
                        Text(
                          dialogError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (_catalogoEtiquetas.isEmpty)
                        const Text(
                          "No hay etiquetas creadas.",
                          style: TextStyle(
                            color: Color(0xFF5B6978),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        ..._catalogoEtiquetas.map(
                          (etiqueta) {
                            final idEtiqueta = (etiqueta["id"] as num?)?.toInt();
                            final nombre =
                                etiqueta["nombre_visible"]?.toString() ?? "Etiqueta";
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                title: Text(nombre),
                                subtitle: Text(
                                  "Codigo: ${etiqueta["codigo"]?.toString() ?? "sin codigo"}",
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: "Editar etiqueta",
                                      icon: const Icon(Icons.edit),
                                      onPressed: saving || idEtiqueta == null
                                          ? null
                                          : () async {
                                              await _showEditarEtiquetaDialog(
                                                idEtiqueta: idEtiqueta,
                                                nombreActual: nombre,
                                                codigoActual:
                                                    etiqueta["codigo"]?.toString(),
                                              );
                                              if (mounted && dialogContext.mounted) {
                                                safeSetDialogState(() {});
                                              }
                                            },
                                    ),
                                    IconButton(
                                      tooltip: "Eliminar etiqueta",
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: saving || idEtiqueta == null
                                          ? null
                                          : () async {
                                              final confirmed = await _confirmAction(
                                                title: "Eliminar etiqueta",
                                                message:
                                                    "Se eliminara la etiqueta $nombre y se quitaran sus asignaciones. Esta accion no se puede deshacer.",
                                                confirmLabel: "Eliminar",
                                              );
                                              if (!confirmed) {
                                                return;
                                              }

                                              safeSetDialogState(() {
                                                saving = true;
                                                dialogError = null;
                                              });

                                              try {
                                                final repo = ref.read(
                                                  supabaseCrudRepositoryProvider,
                                                );
                                                await repo.deleteEtiqueta(idEtiqueta);
                                                await _refreshCatalogoEtiquetas();
                                                await _loadData();
                                                _showMessage(
                                                  "Etiqueta eliminada correctamente.",
                                                );
                                              } catch (error) {
                                                safeSetDialogState(() {
                                                  dialogError = error.toString();
                                                });
                                              } finally {
                                                safeSetDialogState(() {
                                                  saving = false;
                                                });
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cerrar"),
                ),
              ],
            );
          },
        );
      },
    );

    nuevaEtiquetaController.dispose();
  }

  Future<void> _showEditarEtiquetaDialog({
    required int idEtiqueta,
    required String nombreActual,
    String? codigoActual,
  }) async {
    final nombreController = TextEditingController(text: nombreActual);
    final codigoController = TextEditingController(text: codigoActual ?? "");
    bool saving = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void safeSetDialogState(VoidCallback fn) {
              if (!dialogContext.mounted) {
                return;
              }
              setDialogState(fn);
            }

            return AlertDialog(
              title: const Text("Editar etiqueta"),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: "Nombre visible",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: codigoController,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: "Codigo (opcional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancelar"),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final nombre = nombreController.text.trim();
                          final codigo = codigoController.text.trim();

                          if (nombre.isEmpty) {
                            safeSetDialogState(() {
                              dialogError = "El nombre visible es obligatorio.";
                            });
                            return;
                          }

                          safeSetDialogState(() {
                            saving = true;
                            dialogError = null;
                          });

                          try {
                            final repo = ref.read(supabaseCrudRepositoryProvider);
                            await repo.updateEtiqueta(
                              idEtiqueta: idEtiqueta,
                              nombreVisible: nombre,
                              codigo: codigo.isEmpty ? null : codigo,
                            );
                            await _refreshCatalogoEtiquetas();
                            await _loadData();

                            if (!mounted || !dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop();
                            _showMessage("Etiqueta actualizada correctamente.");
                          } catch (error) {
                            safeSetDialogState(() {
                              dialogError = error.toString();
                              saving = false;
                            });
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );

    nombreController.dispose();
    codigoController.dispose();
  }

  Future<void> _showGestionEtiquetasDialog(Map<String, dynamic> ingrediente) async {
    final idIngrediente = (ingrediente["id"] as num?)?.toInt();
    if (idIngrediente == null) {
      return;
    }

    int? selectedEtiquetaId =
        (_catalogoEtiquetas.isNotEmpty ? (_catalogoEtiquetas.first["id"] as num?)?.toInt() : null);
    final nuevaEtiquetaController = TextEditingController();
    String? dialogError;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void safeSetDialogState(VoidCallback fn) {
              if (!dialogContext.mounted) {
                return;
              }
              setDialogState(fn);
            }

            return AlertDialog(
              title: Text("Etiquetas de ${ingrediente["nombre"] ?? "ingrediente"}"),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedEtiquetaId,
                        items: _catalogoEtiquetas
                            .map(
                              (row) => DropdownMenuItem<int>(
                                value: (row["id"] as num?)?.toInt(),
                                child: Text(row["nombre_visible"]?.toString() ?? "Etiqueta"),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                safeSetDialogState(() {
                                  selectedEtiquetaId = value;
                                });
                              },
                        decoration: const InputDecoration(
                          labelText: "Seleccionar etiqueta existente",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "o crear una nueva etiqueta escribiendo su nombre",
                        style: TextStyle(
                          color: Color(0xFF5B6978),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nuevaEtiquetaController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: "Nombre de nueva etiqueta",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          dialogError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cerrar"),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final nuevaEtiqueta = nuevaEtiquetaController.text.trim();
                          if (selectedEtiquetaId == null && nuevaEtiqueta.isEmpty) {
                            safeSetDialogState(() {
                              dialogError = "Selecciona una etiqueta o escribe un nombre nuevo.";
                            });
                            return;
                          }

                          safeSetDialogState(() {
                            saving = true;
                            dialogError = null;
                          });

                          try {
                            final repo = ref.read(supabaseCrudRepositoryProvider);
                            await repo.asignarEtiquetaIngrediente(
                              idIngrediente: idIngrediente,
                              idEtiqueta: nuevaEtiqueta.isEmpty ? selectedEtiquetaId : null,
                              nombreEtiqueta: nuevaEtiqueta.isEmpty ? null : nuevaEtiqueta,
                            );

                            await _refreshCatalogoEtiquetas();
                            await _loadEtiquetasIngrediente(idIngrediente);

                            if (!mounted || !dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop();
                            _showMessage("Etiqueta asignada correctamente.");
                          } catch (error) {
                            safeSetDialogState(() {
                              dialogError = error.toString();
                              saving = false;
                            });
                          }
                        },
                  icon: const Icon(Icons.label),
                  label: const Text("Asignar"),
                ),
              ],
            );
          },
        );
      },
    );

    nuevaEtiquetaController.dispose();
  }

  Future<void> _removeEtiqueta(int idIngrediente, int idEtiqueta) async {
    final confirmed = await _confirmAction(
      title: "Remover etiqueta",
      message: "Se removera la etiqueta del ingrediente seleccionado.",
      confirmLabel: "Remover",
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.removerEtiquetaIngrediente(
        idIngrediente: idIngrediente,
        idEtiqueta: idEtiqueta,
      );
      await _loadEtiquetasIngrediente(idIngrediente);
      _showMessage("Etiqueta removida correctamente.");
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
      _showMessage("No fue posible remover la etiqueta.", isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _ingredientes;
    final canLoadMore = _ingredientes.length < _totalIngredientes;
    final subgruposFiltrados = _subgruposFiltrados;
    final selectedGrupoValido = _grupos.any(
      (row) => _asInt(row["id"]) == _selectedGrupoId,
    )
        ? _selectedGrupoId
        : null;
    final selectedSubgrupoValido = subgruposFiltrados.any(
      (row) => _asInt(row["id"]) == _selectedSubgrupoId,
    )
        ? _selectedSubgrupoId
        : null;

    final activosCount = visible.where((row) => row["activo"] == true).length;
    final etiquetadosCount = visible.where((row) {
      final idIngrediente = (row["id"] as num?)?.toInt();
      if (idIngrediente == null) {
        return false;
      }
      final etiquetas = _etiquetasPorIngrediente[idIngrediente];
      return etiquetas != null && etiquetas.isNotEmpty;
    }).length;
    final sinEtiquetasCount = visible.isEmpty ? 0 : (visible.length - etiquetadosCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ingredientes",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Gestiona la base de datos de ingredientes y su composicion nutricional.",
                    style: TextStyle(
                      color: Color(0xFF5B6978),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _loading || _loadingMore ? null : _openNuevoIngredientePage,
              icon: const Icon(Icons.add),
              label: const Text("Nuevo ingrediente"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ResumenStatCard(
              label: "Total ingredientes",
              value: "$_totalIngredientes",
              color: const Color(0xFF1D4ED8),
            ),
            _ResumenStatCard(
              label: "Activos",
              value: "$activosCount",
              color: const Color(0xFF0F766E),
            ),
            _ResumenStatCard(
              label: "Con etiquetas",
              value: "$etiquetadosCount",
              color: const Color(0xFF0D9488),
            ),
            _ResumenStatCard(
              label: "Sin etiquetas",
              value: "$sinEtiquetasCount",
              color: const Color(0xFFEA580C),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          labelText: "Buscar por nombre o sinonimo",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: "Recargar",
                      onPressed: _loading || _loadingMore ? null : _loadData,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: "Catalogo etiquetas",
                      onPressed: _loading || _loadingMore
                          ? null
                          : _showGestionCatalogoEtiquetasDialog,
                      icon: const Icon(Icons.sell_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedGrupoValido,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Todos los grupos",
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text("Todos los grupos"),
                          ),
                          ..._grupos.map(
                            (row) => DropdownMenuItem<int>(
                              value: _asInt(row["id"]),
                              child: Text(row["nombre"]?.toString() ?? "Grupo"),
                            ),
                          ),
                        ],
                        onChanged: _loading ? null : _onGrupoFilterChanged,
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedSubgrupoValido,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Todos los subgrupos",
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text("Todos los subgrupos"),
                          ),
                          ...subgruposFiltrados.map(
                            (row) => DropdownMenuItem<int>(
                              value: _asInt(row["id"]),
                              child: Text(row["nombre"]?.toString() ?? "Subgrupo"),
                            ),
                          ),
                        ],
                        onChanged: _loading ? null : _onSubgrupoFilterChanged,
                      ),
                    ),
                    FilterChip(
                      selected: _includeInactive,
                      onSelected: _loading ? null : _onIncludeInactiveChanged,
                      label: const Text("Incluir inactivos"),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _clearFiltros,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text("Limpiar"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text("Total consulta: $_totalIngredientes")),
            Chip(label: Text("Cargados: ${_ingredientes.length}")),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : visible.isEmpty
                  ? const Center(
                      child: Text(
                        "No hay ingredientes para mostrar.",
                        style: TextStyle(
                          color: Color(0xFF5B6978),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 42,
                      dataRowMinHeight: 74,
                      dataRowMaxHeight: 120,
                      columns: const [
                        DataColumn(label: Text("INGREDIENTE")),
                        DataColumn(label: Text("GRUPO")),
                        DataColumn(label: Text("SUBGRUPO")),
                        DataColumn(label: Text("PRECIO/FACTOR")),
                        DataColumn(label: Text("ETIQUETAS")),
                        DataColumn(label: Text("ESTADO")),
                        DataColumn(label: Text("ACCIONES")),
                      ],
                      rows: visible.map((item) {
                    final idIngrediente = (item["id"] as num?)?.toInt();
                    if (idIngrediente != null) {
                      Future.microtask(() {
                        _ensureEtiquetasIngredienteLoaded(idIngrediente);
                      });
                    }

                    final etiquetas =
                        _etiquetasPorIngrediente[idIngrediente ?? -1] ?? const [];
                    final etiquetasLoading = idIngrediente != null &&
                        _loadingEtiquetasIngredientes.contains(idIngrediente);
                    final activo = item["activo"] == true;
                    final grupo = item["grupo_nombre"]?.toString() ?? "Sin grupo";
                    final subgrupo =
                      item["subgrupo_nombre"]?.toString() ?? "Sin subgrupo";
                    final precio = _asDouble(item["precio_libra"]);
                    final factor = _asDouble(item["factor_parte_comestible"]);
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item["nombre"]?.toString() ?? "",
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "ID ${item["id"]?.toString() ?? "-"}",
                                  style: const TextStyle(
                                    color: Color(0xFF5B6978),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(SizedBox(width: 140, child: Text(grupo))),
                        DataCell(SizedBox(width: 160, child: Text(subgrupo))),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Text(
                              "\$${precio?.toStringAsFixed(2) ?? "-"} / ${factor?.toStringAsFixed(2) ?? "-"}",
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 270,
                            child: etiquetasLoading
                                ? const Text("Cargando etiquetas...")
                                : etiquetas.isEmpty
                                    ? const Text("Sin etiquetas")
                                    : Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: etiquetas
                                            .map(
                                              (et) => InputChip(
                                                label: Text(
                                                  et["nombre_visible"]?.toString() ?? "Etiqueta",
                                                ),
                                                onDeleted: _loading
                                                    ? null
                                                    : () async {
                                                        final idEtiqueta =
                                                            (et["id_etiqueta"] as num?)?.toInt();
                                                        if (idIngrediente == null ||
                                                            idEtiqueta == null) {
                                                          return;
                                                        }
                                                        await _removeEtiqueta(
                                                          idIngrediente,
                                                          idEtiqueta,
                                                        );
                                                      },
                                              ),
                                            )
                                            .toList(),
                                      ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (activo
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEF3C7))
                                  .withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              activo ? "Activo" : "Inactivo",
                              style: TextStyle(
                                color: activo
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF92400E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: "Editar ingrediente",
                                onPressed: _loading
                                    ? null
                                    : () => _showEditarIngredienteDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.monitor_heart_outlined),
                                tooltip: "Editar composicion",
                                onPressed: _loading
                                    ? null
                                    : () => _showEditarComposicionDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.sell_outlined),
                                tooltip: "Gestionar etiquetas",
                                onPressed: _loading
                                    ? null
                                    : () => _showGestionEtiquetasDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: "Eliminar ingrediente",
                                onPressed:
                                    _loading ? null : () => _deleteIngrediente(item),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                    ),
                  ),
                ),
        ),
        if (!_loading && canLoadMore) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(
                _loadingMore
                    ? "Cargando..."
                    : "Cargar mas (${_totalIngredientes - _ingredientes.length} restantes)",
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResumenStatCard extends StatelessWidget {
  const _ResumenStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NuevoIngredientePayload {
  const _NuevoIngredientePayload({
    required this.nombre,
    required this.idGrupoAlimentario,
    required this.idSubgrupoAlimentario,
    required this.precioLibra,
    required this.factorParteComestible,
    required this.imagenReferencia,
    required this.composicionInicial,
  });

  final String nombre;
  final int? idGrupoAlimentario;
  final int? idSubgrupoAlimentario;
  final double? precioLibra;
  final double? factorParteComestible;
  final String? imagenReferencia;
  final Map<String, dynamic> composicionInicial;
}

class _NuevoIngredientePage extends StatefulWidget {
  const _NuevoIngredientePage({
    required this.grupos,
    required this.subgrupos,
    required this.asInt,
  });

  final List<Map<String, dynamic>> grupos;
  final List<Map<String, dynamic>> subgrupos;
  final int? Function(dynamic) asInt;

  @override
  State<_NuevoIngredientePage> createState() => _NuevoIngredientePageState();
}

class _NuevoIngredientePageState extends State<_NuevoIngredientePage> {
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  final _factorController = TextEditingController(text: "1");
  final _imagenController = TextEditingController();
  final _energiaController = TextEditingController();
  final _proteinaController = TextEditingController();
  final _grasaController = TextEditingController();
  final _carbohidratoController = TextEditingController();
  final _fibraController = TextEditingController();

  int? _selectedGrupoId;
  int? _selectedSubgrupoId;
  String? _error;

  List<Map<String, dynamic>> get _subgruposDisponibles {
    if (_selectedGrupoId == null) {
      return widget.subgrupos;
    }
    return widget.subgrupos.where((row) {
      return widget.asInt(row["id_grupo_alimentario"]) == _selectedGrupoId;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedGrupoId = widget.grupos.isEmpty ? null : widget.asInt(widget.grupos.first["id"]);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    _factorController.dispose();
    _imagenController.dispose();
    _energiaController.dispose();
    _proteinaController.dispose();
    _grasaController.dispose();
    _carbohidratoController.dispose();
    _fibraController.dispose();
    super.dispose();
  }

  double? _parseDouble(String value) {
    final normalized = value.trim().replaceAll(",", ".");
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  void _save() {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = "El nombre del ingrediente es obligatorio.");
      return;
    }

    final precio = _parseDouble(_precioController.text);
    final factor = _parseDouble(_factorController.text);

    if (_precioController.text.trim().isNotEmpty && (precio == null || precio < 0)) {
      setState(() => _error = "Precio por libra no valido.");
      return;
    }
    if (_factorController.text.trim().isNotEmpty && (factor == null || factor <= 0)) {
      setState(() => _error = "Factor de parte comestible debe ser mayor a 0.");
      return;
    }

    final composicionInicial = <String, dynamic>{};
    final energia = _parseDouble(_energiaController.text);
    final proteina = _parseDouble(_proteinaController.text);
    final grasa = _parseDouble(_grasaController.text);
    final carbohidrato = _parseDouble(_carbohidratoController.text);
    final fibra = _parseDouble(_fibraController.text);

    if (energia != null) composicionInicial["energia_kcal"] = energia;
    if (proteina != null) composicionInicial["proteinas_g"] = proteina;
    if (grasa != null) composicionInicial["grasa_total_g"] = grasa;
    if (carbohidrato != null) composicionInicial["hc_g"] = carbohidrato;
    if (fibra != null) composicionInicial["fibra_vegetal_g"] = fibra;

    Navigator.of(context).pop(
      _NuevoIngredientePayload(
        nombre: nombre,
        idGrupoAlimentario: _selectedGrupoId,
        idSubgrupoAlimentario: _selectedSubgrupoId,
        precioLibra: precio,
        factorParteComestible: factor,
        imagenReferencia: _imagenController.text.trim().isEmpty
            ? null
            : _imagenController.text.trim(),
        composicionInicial: composicionInicial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subgruposDisponibles = _subgruposDisponibles;
    final selectedSubgrupoValido = subgruposDisponibles.any(
      (row) => widget.asInt(row["id"]) == _selectedSubgrupoId,
    )
        ? _selectedSubgrupoId
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuevo ingrediente"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text("Guardar"),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                "Configura el nuevo ingrediente con estructura similar al panel de detalle.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _ResumenStatCard(
                    label: "Estado inicial",
                    value: "Activo",
                    color: Color(0xFF0F766E),
                  ),
                  _ResumenStatCard(
                    label: "Composicion",
                    value: "Opcional",
                    color: Color(0xFF1D4ED8),
                  ),
                  _ResumenStatCard(
                    label: "Etiquetas",
                    value: "Manual",
                    color: Color(0xFF0D9488),
                  ),
                  _ResumenStatCard(
                    label: "Sinonimos",
                    value: "Post-crear",
                    color: Color(0xFFEA580C),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Informacion general",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: "Nombre del ingrediente",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedGrupoId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: "Grupo alimentario",
                                border: OutlineInputBorder(),
                              ),
                              items: widget.grupos
                                  .map(
                                    (row) => DropdownMenuItem<int>(
                                      value: widget.asInt(row["id"]),
                                      child: Text(row["nombre"]?.toString() ?? "Grupo"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedGrupoId = value;
                                  _selectedSubgrupoId = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedSubgrupoValido,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: "Subgrupo alimentario",
                                border: OutlineInputBorder(),
                              ),
                              items: subgruposDisponibles
                                  .map(
                                    (row) => DropdownMenuItem<int>(
                                      value: widget.asInt(row["id"]),
                                      child: Text(row["nombre"]?.toString() ?? "Subgrupo"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSubgrupoId = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _precioController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Precio por libra",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _factorController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Factor parte comestible",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _imagenController,
                        decoration: const InputDecoration(
                          labelText: "Imagen de referencia (URL o ruta)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Composicion inicial por 100g (opcional)",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _energiaController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Energia (kcal)",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _proteinaController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Proteinas (g)",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _grasaController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Grasa total (g)",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _carbohidratoController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Carbohidratos (g)",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _fibraController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Fibra (g)",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
