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

  final List<Map<String, dynamic>> _pacientesEncontrados = [];
  final List<Map<String, dynamic>> _ingredientes = [];
  final List<Map<String, dynamic>> _grupos = [];
  final List<Map<String, dynamic>> _condicionesTemporalesCatalogo = [];

  List<Map<String, dynamic>> _alergiasIngredientes = [];
  List<Map<String, dynamic>> _alergiasGrupos = [];
  List<int> _condicionesTemporalesActivas = [];

  bool? _tieneAlergias;
  bool _esIntoleranteLactosa = false;
  static const Set<int> _subgruposLactosa = {98, 100, 101, 104, 105, 108, 111, 114, 117, 119};

  String? _selectedPacienteId;
  int? _selectedIngredienteId;
  int? _selectedGrupoId;

  final bool _loading = false;
  String? _resultado;
  String? _error;

  String _emojiSubgrupo(int id) {
    return {
      8: "🍄", 9: "🍄", 10: "🥔", 11: "🥦", 12: "🥫", 13: "🥬", 14: "🥤", 15: "🍓",
      16: "🍇", 17: "🍎", 18: "🥜", 19: "🍊", 24: "🥚", 25: "🍗", 26: "🐖", 27: "🐑",
      29: "🥩", 30: "🐄", 31: "🫀", 32: "🦐", 33: "🐟", 34: "🐠", 35: "🐟", 36: "🥫",
      37: "🧂", 38: "🫒", 41: "🧄", 43: "🍬", 47: "🍭", 48: "🍿", 49: "🥤", 50: "💧",
      51: "☕", 53: "🧃", 88: "🌾", 89: "🌾", 90: "🍞", 91: "🍞", 92: "🍝", 93: "🫘",
      94: "🌱", 95: "🫘", 96: "🥫", 97: "🥜", 98: "🥛", 99: "🥛", 100: "🍶", 101: "🥛",
      102: "🥛", 103: "🥥", 104: "🥛", 105: "🧀", 106: "🧀", 107: "🧀", 108: "🧀",
      109: "🥓", 110: "🌭", 111: "🧈", 112: "🧈", 113: "🥓", 114: "🥣", 115: "🥣",
      116: "🥢", 117: "🍫", 118: "🍫", 119: "🍮", 120: "🍬", 121: "🍪", 122: "🥛",
      123: "🥛", 124: "🥛",
    }[id] ?? "🍽️";
  }

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
    final seleccionados = _alergiasIngredientes.map((a) => a["id_ingrediente"] as int).toSet();
    
    // Subgrupos bloqueados por intolerancia a lactosa o selección manual
    final subBloqueados = <int>{};
    if (_esIntoleranteLactosa) subBloqueados.addAll(_subgruposLactosa);
    subBloqueados.addAll(_alergiasGrupos.map((g) => g["id_grupo_alimentario"] as int));

    return _ingredientes.where((item) {
      final id = (item["id"] as num).toInt();
      if (seleccionados.contains(id)) return false;
      
      // No mostrar ingredientes de subgrupos bloqueados
      final idSub = (item["id_subgrupo_alimentario"] as num?)?.toInt();
      if (idSub != null && subBloqueados.contains(idSub)) return false;
      
      if (query.isEmpty) return true;
      final nombre = item["nombre"]?.toString().toLowerCase() ?? "";
      final sinonimos = (item["sinonimos"] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
      return nombre.contains(query) || sinonimos.any((s) => s.contains(query));
    }).toList();
  }

  List<Map<String, dynamic>> get _gruposFiltrados {
    final query = _grupoSearchController.text.trim().toLowerCase();
    final seleccionados = _alergiasGrupos.map((a) => a["id_grupo_alimentario"] as int).toSet();

    return _grupos.where((item) {
      final id = (item["id"] as num).toInt();
      if (seleccionados.contains(id)) return false;
      // No mostrar subgrupos de lactosa si es intolerante (redundante)
      if (_esIntoleranteLactosa && _subgruposLactosa.contains(id)) return false;
      if (query.isEmpty) return true;
      return (item["nombre"]?.toString().toLowerCase() ?? "").contains(query);
    }).toList();
  }

  Widget _buildValidacionAlergias() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "¿El paciente presenta alergias o intolerancias?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("SÍ"),
                  selected: _tieneAlergias == true,
                  onSelected: (val) => setState(() => _tieneAlergias = val ? true : null),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text("NO"),
                  selected: _tieneAlergias == false,
                  onSelected: (val) => setState(() {
                    _tieneAlergias = val ? false : null;
                    if (val) {
                      _alergiasIngredientes = [];
                      _alergiasGrupos = [];
                      _esIntoleranteLactosa = false;
                    }
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntoleranciaLactosa() {
    return SwitchListTile(
      title: const Text("Intolerancia a la Lactosa", style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text("Oculta automáticamente lácteos y sus derivados (sin redundancia)"),
      value: _esIntoleranteLactosa,
      onChanged: (val) {
        setState(() => _esIntoleranteLactosa = val);
      },
    );
  }

  Future<void> _loadCatalogs() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final results = await Future.wait([
        repo.fetchCatalog("nutricion", "ingrediente"),
        repo.fetchCatalog("nutricion", "subgrupo_alimentario"),
        repo.fetchCatalog("heuristico", "condicion"),
      ]);
      if (mounted) {
        setState(() {
          _ingredientes.addAll(results[0].cast<Map<String, dynamic>>());
          _grupos.addAll(results[1].cast<Map<String, dynamic>>());
          _condicionesTemporalesCatalogo.addAll(
            results[2].where((c) => (c["id_tipo"] ?? c["id_tipo_condicion"]) == 2).cast<Map<String, dynamic>>()
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _agregarAlergiaIngrediente() async {
    if (_selectedIngredienteId == null || _selectedPacienteId == null) return;
    final ing = _ingredientes.firstWhere((i) => (i["id"] as num).toInt() == _selectedIngredienteId);
    setState(() {
      _alergiasIngredientes.add({
        "id_ingrediente": _selectedIngredienteId,
        "nombre_ingrediente": ing["nombre"],
        "observacion": _observacionIngredienteController.text,
      });
      _selectedIngredienteId = null;
      _observacionIngredienteController.clear();
    });
  }

  void _eliminarAlergiaIngrediente(int id) {
    setState(() {
      _alergiasIngredientes.removeWhere((a) => (a["id_ingrediente"] as num).toInt() == id);
    });
  }

  Future<void> _agregarAlergiaGrupo() async {
    if (_selectedGrupoId == null || _selectedPacienteId == null) return;
    final grupo = _grupos.firstWhere((g) => (g["id"] as num).toInt() == _selectedGrupoId);
    setState(() {
      _alergiasGrupos.add({
        "id_grupo_alimentario": _selectedGrupoId,
        "nombre_grupo": grupo["nombre"],
        "observacion": _observacionGrupoController.text,
      });
      _selectedGrupoId = null;
      _observacionGrupoController.clear();
    });
  }

  void _eliminarAlergiaGrupo(int id) {
    setState(() {
      _alergiasGrupos.removeWhere((g) => (g["id_grupo_alimentario"] as num).toInt() == id);
    });
  }

  Widget _statusBadge({required String label, required int count, required bool highlighted}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: $count",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: highlighted ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }

  String _label(Map<String, dynamic> c) => c["nombre"] ?? "Condición";

  Future<void> _guardarCondicionesTemporales() async {
    if (_selectedPacienteId == null) return;
    // Implementación mínima para que compile
  }

  Widget _buildPacienteSelector() {
    return Column(
      children: [
        TextField(
          controller: _pacienteSearchController,
          decoration: const InputDecoration(
            labelText: "Buscar paciente por nombre o cédula",
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (v) => _buscarPaciente(v),
        ),
      ],
    );
  }

  Future<void> _buscarPaciente(String query) async {
    if (query.isEmpty) return;
    // Implementación mínima
  }


  Widget _buildAlergiasTab() {
    if (_selectedPacienteId == null) {
      return const Center(child: Text("Selecciona un paciente primero"));
    }

    if (_tieneAlergias == null) {
      return _buildValidacionAlergias();
    }

    if (_tieneAlergias == false) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
            SizedBox(height: 12),
            Text("Paciente sin restricciones alimentarias reportadas"),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        Card(
          child: Column(
            children: [
              _buildIntoleranciaLactosa(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Alergia a ingredientes específicos", 
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _selectedIngredienteId,
                  decoration: const InputDecoration(
                    labelText: "Buscar e ingrediente a bloquear",
                    prefixIcon: Icon(Icons.search),
                  ),
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
                  decoration: const InputDecoration(labelText: "Observación"),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading || _selectedIngredienteId == null ? null : _agregarAlergiaIngrediente,
                    icon: const Icon(Icons.block),
                    label: const Text("Bloquear Ingrediente"),
                  ),
                ),
                const SizedBox(height: 12),
                if (_alergiasIngredientes.isNotEmpty) ...[
                  const Divider(),
                  ..._alergiasIngredientes.map(
                    (item) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.cancel, color: Colors.red),
                      title: Text(item["nombre_ingrediente"]?.toString() ?? "Ingrediente"),
                      subtitle: Text(item["observacion"]?.toString() ?? ""),
                      trailing: IconButton(
                        onPressed: () => _eliminarAlergiaIngrediente((item["id_ingrediente"] as num).toInt()),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                ],
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
                Text("Alergia a subgrupos alimentarios", 
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _selectedGrupoId,
                  decoration: const InputDecoration(
                    labelText: "Seleccionar subgrupo a eliminar",
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _gruposFiltrados
                      .map(
                        (g) => DropdownMenuItem<int>(
                          value: (g["id"] as num).toInt(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_emojiSubgrupo((g["id"] as num).toInt()), style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(g["nombre"]?.toString() ?? "Grupo")),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedGrupoId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _observacionGrupoController,
                  decoration: const InputDecoration(labelText: "Observación"),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading || _selectedGrupoId == null ? null : _agregarAlergiaGrupo,
                    icon: const Icon(Icons.layers_clear),
                    label: const Text("Eliminar Subgrupo"),
                  ),
                ),
                const SizedBox(height: 12),
                if (_alergiasGrupos.isNotEmpty) ...[
                  const Divider(),
                  ..._alergiasGrupos.map(
                    (item) => ListTile(
                      dense: true,
                      leading: Text(_emojiSubgrupo((item["id_grupo_alimentario"] as num).toInt()), style: const TextStyle(fontSize: 20)),
                      title: Text(item["nombre_grupo"]?.toString() ?? "Grupo"),
                      subtitle: Text(item["observacion"]?.toString() ?? ""),
                      trailing: IconButton(
                        onPressed: () => _eliminarAlergiaGrupo((item["id_grupo_alimentario"] as num).toInt()),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                ],
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
