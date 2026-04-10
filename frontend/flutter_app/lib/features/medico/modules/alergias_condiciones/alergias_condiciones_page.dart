import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class AlergiasCondicionesPage extends ConsumerStatefulWidget {
  const AlergiasCondicionesPage({super.key});

  @override
  ConsumerState<AlergiasCondicionesPage> createState() => _AlergiasCondicionesPageState();
}

class _AlergiasCondicionesPageState extends ConsumerState<AlergiasCondicionesPage> {
  final _pacienteSearchController = TextEditingController();
  final _ingredienteSearchController = TextEditingController();
  final _grupoSearchController = TextEditingController();
  final _observacionIngredienteController = TextEditingController();
  final _observacionGrupoController = TextEditingController();

  List<Map<String, dynamic>> _pacientesEncontrados = [];
  List<Map<String, dynamic>> _ingredientes = [];
  List<Map<String, dynamic>> _grupos = [];
  List<Map<String, dynamic>> _condicionesTemporalesCatalogo = [];

  List<Map<String, dynamic>> _alergiasIngredientes = [];
  List<Map<String, dynamic>> _alergiasGrupos = [];
  List<int> _condicionesTemporalesActivas = [];

  String? _selectedPacienteId;
  int? _selectedIngredienteId;
  int? _selectedGrupoId;

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCatalogs);
  }

  @override
  void dispose() {
    _pacienteSearchController.dispose();
    _ingredienteSearchController.dispose();
    _grupoSearchController.dispose();
    _observacionIngredienteController.dispose();
    _observacionGrupoController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _ingredientesFiltrados {
    final query = _ingredienteSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _ingredientes;
    }

    return _ingredientes
        .where(
          (item) => (item["nombre"]?.toString().toLowerCase() ?? "").contains(query),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _gruposFiltrados {
    final query = _grupoSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _grupos;
    }

    return _grupos
        .where(
          (item) => (item["nombre"]?.toString().toLowerCase() ?? "").contains(query),
        )
        .toList();
  }

  Future<void> _loadCatalogs() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final ingredientes = await repo.fetchIngredientes();
      final grupos = await repo.fetchCatalog("nutricion", "grupo_alimentario");
      final condiciones = await repo.fetchCatalog("heuristico", "condicion");
      final tipos = await repo.fetchCatalog("heuristico", "catalogo_tipo_condicion");

      final tiposTemporales = tipos
          .where((t) => (t["codigo"]?.toString().toLowerCase().trim() ?? "") == "temporal")
          .map((t) => (t["id"] as num).toInt())
          .toSet();

      final temporales = condiciones
          .where((c) {
            final idTipo = c["id_tipo_condicion"];
            if (idTipo is! num) {
              return false;
            }
            final activa = c["activa"];
            if (activa is bool && !activa) {
              return false;
            }
            return tiposTemporales.contains(idTipo.toInt());
          })
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _ingredientes = ingredientes;
        _grupos = grupos;
        _condicionesTemporalesCatalogo = temporales;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = "No fue posible cargar catálogos para alergias y condiciones: $error");
    }
  }

  Future<void> _buscarPacientes() async {
    final query = _pacienteSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _pacientesEncontrados = [];
        _selectedPacienteId = null;
      });
      return;
    }

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final rows = await repo.searchPatients(query: query, limit: 10);
      if (!mounted) {
        return;
      }
      setState(() {
        _pacientesEncontrados = rows;
        _selectedPacienteId = rows.isEmpty ? null : rows.first["id"]?.toString();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  String _label(Map<String, dynamic> item) {
    final nombre = item["nombre"]?.toString().trim();
    if (nombre != null && nombre.isNotEmpty) {
      return nombre;
    }
    final descripcion = item["descripcion"]?.toString().trim();
    if (descripcion != null && descripcion.isNotEmpty) {
      return descripcion;
    }
    return "Elemento";
  }

  Future<void> _cargarPaciente() async {
    final idPaciente = _selectedPacienteId;
    if (idPaciente == null || idPaciente.isEmpty) {
      setState(() => _error = "Selecciona un paciente para cargar alergias y condiciones.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final alergias = await repo.fetchPatientAllergies(idPaciente: idPaciente);
      final condiciones = await repo.fetchPatientTemporaryConditions(idPaciente: idPaciente);

      if (!mounted) {
        return;
      }

      final ingredientes = (alergias["ingredientes"] is List)
          ? List<Map<String, dynamic>>.from(alergias["ingredientes"] as List)
          : <Map<String, dynamic>>[];
      final grupos = (alergias["grupos"] is List)
          ? List<Map<String, dynamic>>.from(alergias["grupos"] as List)
          : <Map<String, dynamic>>[];
      final ids = (condiciones["id_condiciones_temporales"] is List)
          ? (condiciones["id_condiciones_temporales"] as List).whereType<num>().map((n) => n.toInt()).toList()
          : <int>[];

      setState(() {
        _alergiasIngredientes = ingredientes;
        _alergiasGrupos = grupos;
        _condicionesTemporalesActivas = ids;
        _resultado = "Datos del paciente cargados correctamente.";
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

  Future<void> _agregarAlergiaIngrediente() async {
    final idPaciente = _selectedPacienteId;
    final idIngrediente = _selectedIngredienteId;
    if (idPaciente == null || idPaciente.isEmpty) {
      setState(() => _error = "Selecciona un paciente para registrar alergia por ingrediente.");
      return;
    }
    if (idIngrediente == null) {
      setState(() => _error = "Selecciona un ingrediente.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.addPatientIngredientAllergy(
        idPaciente: idPaciente,
        idIngrediente: idIngrediente,
        observacion: _observacionIngredienteController.text.trim().isEmpty
            ? null
            : _observacionIngredienteController.text.trim(),
      );
      _observacionIngredienteController.clear();
      await _cargarPaciente();
      if (!mounted) {
        return;
      }
      setState(() => _resultado = "Alergia por ingrediente registrada.");
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

  Future<void> _eliminarAlergiaIngrediente(int idIngrediente) async {
    final idPaciente = _selectedPacienteId;
    if (idPaciente == null || idPaciente.isEmpty) {
      return;
    }

    final confirmed = await _confirmDeletion(
      title: "Quitar alergia por ingrediente",
      message: "¿Deseas quitar esta alergia por ingrediente del paciente?",
    );
    if (!confirmed) {
      return;
    }

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.removePatientIngredientAllergy(
        idPaciente: idPaciente,
        idIngrediente: idIngrediente,
      );
      await _cargarPaciente();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  Future<void> _agregarAlergiaGrupo() async {
    final idPaciente = _selectedPacienteId;
    final idGrupo = _selectedGrupoId;
    if (idPaciente == null || idPaciente.isEmpty) {
      setState(() => _error = "Selecciona un paciente para registrar alergia por grupo.");
      return;
    }
    if (idGrupo == null) {
      setState(() => _error = "Selecciona un grupo alimentario.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.addPatientGroupAllergy(
        idPaciente: idPaciente,
        idGrupoAlimentario: idGrupo,
        observacion: _observacionGrupoController.text.trim().isEmpty
            ? null
            : _observacionGrupoController.text.trim(),
      );
      _observacionGrupoController.clear();
      await _cargarPaciente();
      if (!mounted) {
        return;
      }
      setState(() => _resultado = "Alergia por grupo alimentario registrada.");
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

  Future<void> _eliminarAlergiaGrupo(int idGrupo) async {
    final idPaciente = _selectedPacienteId;
    if (idPaciente == null || idPaciente.isEmpty) {
      return;
    }

    final confirmed = await _confirmDeletion(
      title: "Quitar alergia por grupo",
      message: "¿Deseas quitar esta alergia por grupo alimentario del paciente?",
    );
    if (!confirmed) {
      return;
    }

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.removePatientGroupAllergy(
        idPaciente: idPaciente,
        idGrupoAlimentario: idGrupo,
      );
      await _cargarPaciente();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  Future<void> _guardarCondicionesTemporales() async {
    final idPaciente = _selectedPacienteId;
    if (idPaciente == null || idPaciente.isEmpty) {
      setState(() => _error = "Selecciona un paciente antes de guardar condiciones temporales.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.updatePatientTemporaryConditions(
        idPaciente: idPaciente,
        idCondicionesTemporales: _condicionesTemporalesActivas,
      );
      if (!mounted) {
        return;
      }
      setState(() => _resultado = "Condiciones temporales actualizadas correctamente.");
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

  Future<bool> _confirmDeletion({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancelar"),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Quitar"),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Widget _statusBadge({
    required String label,
    required int count,
    required bool highlighted,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        "$label: $count",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: highlighted ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildPacienteSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Paciente",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pacienteSearchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscarPacientes(),
                    decoration: const InputDecoration(
                      labelText: "Buscar paciente por nombre",
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _buscarPacientes,
                  child: const Text("Buscar"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedPacienteId,
              decoration: const InputDecoration(labelText: "Seleccionar paciente"),
              items: _pacientesEncontrados
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p["id"]?.toString(),
                      child: Text("${p["nombre_completo"] ?? ""} - ID: ${p["id"] ?? "N/A"}"),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedPacienteId = value),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _loading ? null : _cargarPaciente,
              icon: const Icon(Icons.download),
              label: Text(_loading ? "Cargando..." : "Cargar alergias y condiciones"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlergiasTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Alergias por ingrediente", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                TextField(
                  controller: _ingredienteSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Filtrar ingredientes por nombre",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _ingredienteSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: "Limpiar",
                            onPressed: () {
                              _ingredienteSearchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _selectedIngredienteId,
                  decoration: const InputDecoration(labelText: "Ingrediente"),
                  items: _ingredientesFiltrados
                      .map(
                        (i) => DropdownMenuItem<int>(
                          value: (i["id"] as num).toInt(),
                          child: Text(i["nombre"]?.toString() ?? "Ingrediente"),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedIngredienteId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _observacionIngredienteController,
                  decoration: const InputDecoration(labelText: "Observación (opcional)"),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _loading ? null : _agregarAlergiaIngrediente,
                  icon: const Icon(Icons.add),
                  label: const Text("Agregar alergia de ingrediente"),
                ),
                const SizedBox(height: 12),
                ..._alergiasIngredientes.map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item["nombre_ingrediente"]?.toString() ?? "Ingrediente"),
                    subtitle: Text(item["observacion"]?.toString() ?? "Sin observación"),
                    trailing: IconButton(
                      tooltip: "Quitar alergia",
                      onPressed: () => _eliminarAlergiaIngrediente((item["id_ingrediente"] as num).toInt()),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
                if (_alergiasIngredientes.isEmpty)
                  const Text("No hay alergias por ingrediente registradas."),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Alergias por grupo alimentario", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                TextField(
                  controller: _grupoSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Filtrar grupos por nombre",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _grupoSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: "Limpiar",
                            onPressed: () {
                              _grupoSearchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _selectedGrupoId,
                  decoration: const InputDecoration(labelText: "Grupo alimentario"),
                  items: _gruposFiltrados
                      .map(
                        (g) => DropdownMenuItem<int>(
                          value: (g["id"] as num).toInt(),
                          child: Text(g["nombre"]?.toString() ?? "Grupo"),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedGrupoId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _observacionGrupoController,
                  decoration: const InputDecoration(labelText: "Observación (opcional)"),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _loading ? null : _agregarAlergiaGrupo,
                  icon: const Icon(Icons.add),
                  label: const Text("Agregar alergia de grupo"),
                ),
                const SizedBox(height: 12),
                ..._alergiasGrupos.map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item["nombre_grupo"]?.toString() ?? "Grupo"),
                    subtitle: Text(item["observacion"]?.toString() ?? "Sin observación"),
                    trailing: IconButton(
                      tooltip: "Quitar alergia",
                      onPressed: () => _eliminarAlergiaGrupo((item["id_grupo_alimentario"] as num).toInt()),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
                if (_alergiasGrupos.isEmpty)
                  const Text("No hay alergias por grupo registradas."),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCondicionesTab() {
    final totalTemporales = _condicionesTemporalesCatalogo.length;
    final activas = _condicionesTemporalesActivas.length;
    final inactivas = (totalTemporales - activas).clamp(0, totalTemporales);

    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Condiciones temporales activas", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  "Selecciona las condiciones temporales vigentes del control actual del paciente.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusBadge(label: "Activas", count: activas, highlighted: true),
                    _statusBadge(label: "Inactivas", count: inactivas, highlighted: false),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _condicionesTemporalesCatalogo
                      .map(
                        (c) {
                          final idCondicion = (c["id"] as num).toInt();
                          final selected = _condicionesTemporalesActivas.contains(idCondicion);
                          return FilterChip(
                            selected: selected,
                            label: Text(_label(c)),
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _condicionesTemporalesActivas = [..._condicionesTemporalesActivas, idCondicion];
                                } else {
                                  _condicionesTemporalesActivas =
                                      _condicionesTemporalesActivas.where((id) => id != idCondicion).toList();
                                }
                              });
                            },
                          );
                        },
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _guardarCondicionesTemporales,
                  icon: const Icon(Icons.save),
                  label: const Text("Guardar condiciones temporales"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Alergias y Condiciones",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildPacienteSelector(),
          const SizedBox(height: 12),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.warning_amber), text: "Alergias"),
              Tab(icon: Icon(Icons.healing), text: "Condiciones temporales"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAlergiasTab(),
                _buildCondicionesTab(),
              ],
            ),
          ),
          if (_resultado != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _resultado!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
