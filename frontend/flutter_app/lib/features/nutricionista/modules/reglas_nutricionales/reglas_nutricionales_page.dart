import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class ReglasNutricionalesPage extends ConsumerStatefulWidget {
  const ReglasNutricionalesPage({super.key});

  @override
  ConsumerState<ReglasNutricionalesPage> createState() =>
      _ReglasNutricionalesPageState();
}

class _ReglasNutricionalesPageState
    extends ConsumerState<ReglasNutricionalesPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<dynamic> _rules = [];
  Map<String, List<dynamic>> _formData = {
    "acciones": [],
    "objetivos": [],
    "condiciones": [],
    "ingredientes": [],
    "grupos": [],
    "subgrupos": [],
    "etiquetas": []
  };

  String _searchQuery = "";
  final Set<String> _selectedObjetivos = {};
  int? _filtroCondicion;
  int? _filtroAccion;
  late TabController _tabController;

  Dio get _dio => ref.read(dioProvider);

  String _norm(dynamic value) {
    final s = (value ?? "").toString();
    return s
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã­', 'í')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ãº', 'ú')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã', 'Á')
        .replaceAll('Ã‰', 'É')
        .replaceAll('Ã', 'Í')
        .replaceAll('Ã“', 'Ó')
        .replaceAll('Ãš', 'Ú')
        .replaceAll('Ã‘', 'Ñ')
        .replaceAll('Â°', '°')
        .replaceAll('Â¿', '¿')
        .replaceAll('Â¡', '¡');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _filtroCondicion = null;
          _filtroAccion = null;
          _selectedObjetivos.clear();
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _dio.get("reglas-nutricionales"),
        _dio.get("reglas-nutricionales/form-data"),
      ]);
      if (mounted) {
        setState(() {
          _rules = results[0].data as List;
          _formData = Map<String, List<dynamic>>.from(results[1].data as Map);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al sincronizar motor de reglas",
            isError: true, ref: ref);
        setState(() => _loading = false);
      }
    }
  }

  List<dynamic> get _filtradas {
    final bool lookingForTalla = _tabController.index == 1;

    return _rules.where((r) {
      final listCondiciones = (r['id_condiciones'] as List? ?? []).cast<int>();

      // Filtro por Tab (Peso vs Talla)
      final bool matchTab = listCondiciones.any((idCond) {
        final cond =
            (_formData["condiciones"] ?? []).cast<dynamic>().firstWhere(
                  (c) => c["id"] == idCond,
                  orElse: () => null,
                );
        if (cond == null) return false;
        final bool isTalla =
            (cond["indicador_codigo"]?.toString() ?? "").toUpperCase() == "HFA";
        return isTalla == lookingForTalla;
      });

      if (!matchTab) return false;

      final targetName = _getTargetName(r).toLowerCase();
      final matchesSearch = targetName.contains(_searchQuery.toLowerCase());
      final matchesTipo = _selectedObjetivos.isEmpty ||
          _selectedObjetivos.contains(r["objetivo_codigo"]);

      final matchesCondicion = _filtroCondicion == null ||
          listCondiciones.contains(_filtroCondicion);
      final matchesAccion =
          _filtroAccion == null || r["id_accion"] == _filtroAccion;

      return matchesSearch && matchesTipo && matchesCondicion && matchesAccion;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: _loading
          ? const Center(
              child: NutriLoading(mensaje: "Consultando motor de reglas..."))
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 24),
                      _buildTabs(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(),
                        const SizedBox(height: 32),
                        _buildFilterBar(),
                        const SizedBox(height: 24),
                        _buildTable(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      labelColor: AppTema.azulPrincipal,
      unselectedLabelColor: Colors.blueGrey,
      indicatorColor: AppTema.azulPrincipal,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
      tabs: const [
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.monitor_weight_outlined, size: 20),
              SizedBox(width: 8),
              Text("Peso corporal"),
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.height_rounded, size: 20),
              SizedBox(width: 8),
              Text("Talla / Estatura"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión de reglas nutricionales",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Configuración de lógica experta basada en etiquetas y condiciones nutricionales.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: "Buscar por alimento o ingrediente objetivo...",
                    hintStyle: GoogleFonts.inter(
                        color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon:
                        const Icon(Icons.search, size: 20, color: Colors.grey),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _showForm(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                icon:
                    const Icon(Icons.add_circle, size: 20, color: Colors.white),
                label: Text("Nueva regla",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
            child: NutriResumenCard(
                titulo: "TOTAL REGLAS",
                valor: "${_rules.length}",
                icon: Icons.rule_rounded)),
        const SizedBox(width: 20),
        Expanded(
            child: NutriResumenCard(
                titulo: "ESTRICTAS",
                valor:
                    "${_rules.where((r) => r['es_estricta'] == true).length}",
                colorValor: Colors.redAccent,
                icon: Icons.gavel_rounded)),
        const SizedBox(width: 20),
        const Expanded(
            child: NutriResumenCard(
                titulo: "SISTEMA",
                valor: "SIA",
                colorValor: AppTema.azulOscuro,
                icon: Icons.auto_awesome_rounded)),
      ],
    );
  }

  Widget _buildFilterBar() {
    final int selectedIdx = _tabController.index;
    final bool lookingForTalla = selectedIdx == 1;

    final condicionesFiltradas = (_formData["condiciones"] ?? []).where((c) {
      final bool isTalla =
          (c["indicador_codigo"]?.toString() ?? "").toUpperCase() == "HFA";
      return isTalla == lookingForTalla;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Condición nutricional",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTema.azulOscuro)),
                    const SizedBox(height: 8),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              color: AppTema.verdeSalud, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: _filtroCondicion,
                                isExpanded: true,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                                items: [
                                  const DropdownMenuItem(
                                      value: null,
                                      child: Text("Todas las condiciones")),
                                  ...condicionesFiltradas.map((c) =>
                                      DropdownMenuItem<int>(
                                          value: c["id"],
                                          child: Text(_norm(c["nombre"]),
                                              overflow:
                                                  TextOverflow.ellipsis))),
                                ],
                                onChanged: (v) =>
                                    setState(() => _filtroCondicion = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _filtroCondicion = null;
                    _filtroAccion = null;
                    _selectedObjetivos.clear();
                    _searchQuery = "";
                  }),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text("Limpiar filtros",
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Acción nutricional",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTema.azulOscuro)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _actionBtn("Todos", null, Icons.list_alt_rounded,
                              Colors.blueGrey),
                          const SizedBox(width: 8),
                          _actionBtn("Priorizar", _accionId("PRIORIZAR"),
                              Icons.arrow_upward_rounded, AppTema.verdeSalud),
                          const SizedBox(width: 8),
                          _actionBtn("Disminuir", _accionId("DISMINUIR"),
                              Icons.arrow_downward_rounded, Colors.orange),
                          const SizedBox(width: 8),
                          _actionBtn("Eliminar", _accionId("ELIMINAR"),
                              Icons.delete_outline_rounded, Colors.redAccent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tipo de objetivo",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTema.azulOscuro)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _objectiveBtn("Todos", "TODOS", null),
                          const SizedBox(width: 8),
                          _objectiveBtn("Ingrediente", "INGREDIENTE",
                              Icons.egg_alt_outlined),
                          const SizedBox(width: 8),
                          _objectiveBtn(
                              "Grupo", "GRUPO", Icons.set_meal_outlined),
                          const SizedBox(width: 8),
                          _objectiveBtn(
                              "Subgrupo", "SUBGRUPO", Icons.layers_outlined),
                          const SizedBox(width: 8),
                          _objectiveBtn(
                              "Etiqueta", "ETIQUETA", Icons.sell_outlined),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int? _accionId(String nombre) {
    final a = _formData["acciones"]?.firstWhere(
        (a) => a["nombre"].toString().toUpperCase() == nombre,
        orElse: () => null);
    return a?["id"];
  }

  Widget _actionBtn(String label, int? val, IconData icon, Color color) {
    final bool isSelected = _filtroAccion == val;
    return InkWell(
      onTap: () => setState(() => _filtroAccion = val),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16, color: isSelected ? color : Colors.blueGrey.shade400),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : Colors.blueGrey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _objectiveBtn(String label, String code, IconData? icon) {
    final bool isSelected = code == "TODOS"
        ? _selectedObjetivos.isEmpty
        : _selectedObjetivos.contains(code);
    final Color color = AppTema.azulPrincipal;

    return InkWell(
      onTap: () => setState(() {
        if (code == "TODOS") {
          _selectedObjetivos.clear();
        } else if (_selectedObjetivos.contains(code)) {
          _selectedObjetivos.remove(code);
        } else {
          _selectedObjetivos.add(code);
        }
      }),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade200, width: 1.5),
        ),
        child: Column(
          children: [
            if (icon != null)
              Icon(icon,
                  size: 14,
                  color: isSelected ? color : Colors.blueGrey.shade400),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : Colors.blueGrey.shade600)),
          ],
        ),
      ),
    );
  }

  int? _accionIdPorNombre(String nombre) {
    final a = _formData["acciones"]?.firstWhere(
        (a) => a["nombre"].toString().toUpperCase() == nombre,
        orElse: () => null);
    return a?["id"];
  }

  Widget _buildTable() {
    final items = _filtradas;

    return NutriTableContainer(
      child: Column(
        children: [
          _buildTableHead(),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text("No se encontraron reglas.")),
            )
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final r = entry.value;
              return _buildTableRow(r, index);
            }),
        ],
      ),
    );
  }

  Widget _buildTableHead() {
    return Container(
      color: AppTema.azulPrincipal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: _tableHeaderLabel("Condicion")),
          Expanded(flex: 3, child: _tableHeaderLabel("Accion")),
          Expanded(flex: 4, child: _tableHeaderLabel("Objetivo")),
          Expanded(
              flex: 2, child: Center(child: _tableHeaderLabel("Estricta"))),
          Expanded(
              flex: 3, child: Center(child: _tableHeaderLabel("Acciones"))),
        ],
      ),
    );
  }

  Widget _tableHeaderLabel(String label) {
    return Text(label,
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white));
  }

  Widget _buildTableRow(Map<String, dynamic> r, int index) {
    final bool isEven = index % 2 == 0;
    final bool lookingForTalla = _tabController.index == 1;

    final condicionesIdsRaw = r["id_condiciones"];
    final List<int> condicionesIds =
        condicionesIdsRaw is List ? condicionesIdsRaw.cast<int>() : [];

    final condicionNombre =
        _singleConditionNameForTab(condicionesIds, lookingForTalla);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF1F5F9),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 4,
              child: Row(
                children: [
                  Icon(
                      lookingForTalla
                          ? Icons.height_rounded
                          : Icons.monitor_weight_rounded,
                      size: 18,
                      color: Colors.blueGrey.withOpacity(0.55)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(condicionNombre,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              )),
          Expanded(
              flex: 3,
              child: _accionBadge(r['accion_codigo']?.toString() ?? "-")),
          Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r["objetivo_codigo"]?.toString() ?? "Ingrediente",
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey)),
                  Text(_getTargetName(r),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B))),
                ],
              )),
          Expanded(
              flex: 2,
              child: Center(
                  child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      r["es_estricta"] == true
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      color: r["es_estricta"] == true
                          ? AppTema.verdeSalud
                          : Colors.grey.shade400,
                      size: 14),
                  const SizedBox(width: 4),
                  Text(r["es_estricta"] == true ? "Si" : "No",
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey)),
                ],
              ))),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    tooltip: "Editar",
                    icon: const Icon(Icons.edit_note_rounded,
                        color: Colors.orange, size: 22),
                    onPressed: () => _showForm(r)),
                IconButton(
                    tooltip: "Eliminar",
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 20),
                    onPressed: () => _deleteRule(r["id"])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _singleConditionNameForTab(
      List<int> condicionesIds, bool lookingForTalla) {
    final condiciones = (_formData["condiciones"] ?? []).cast<dynamic>();
    dynamic selected;

    for (final id in condicionesIds) {
      final c =
          condiciones.firstWhere((c) => c["id"] == id, orElse: () => null);
      if (c == null) continue;
      final codigo = (c["indicador_codigo"]?.toString() ?? "").toUpperCase();
      final isTalla = codigo == "HFA";
      if (isTalla == lookingForTalla) {
        selected = c;
        break;
      }
    }

    selected ??= condicionesIds.isNotEmpty
        ? condiciones.firstWhere((c) => c["id"] == condicionesIds.first,
            orElse: () => null)
        : null;

    if (selected == null) return "-";
    return _norm(selected["nombre"]);
  }

  Widget _accionBadge(String label) {
    Color bg = const Color(0xFFF1F5F9);
    Color tx = Colors.blueGrey;
    if (label == 'ELIMINAR') {
      bg = const Color(0xFFFEE2E2);
      tx = const Color(0xFFB91C1C);
    } else if (label == 'PRIORIZAR') {
      bg = const Color(0xFFDCFCE7);
      tx = const Color(0xFF15803D);
    } else if (label == 'DISMINUIR') {
      bg = const Color(0xFFFEF3C7);
      tx = const Color(0xFFB45309);
    }
    return UnconstrainedBox(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w800, color: tx)),
      ),
    );
  }

  String _getTargetName(Map<String, dynamic> r) =>
      r['ingrediente_nombre'] ??
      r['grupo_nombre'] ??
      r['subgrupo_nombre'] ??
      r['etiqueta_nombre'] ??
      "Objetivo";

  void _showForm([Map<String, dynamic>? rule]) {
    showDialog(
        context: context,
        builder: (ctx) => _NutritionalRuleFormDialog(
            formData: _formData, initialRule: rule, onSaved: _loadData));
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Eliminar Regla?",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content:
            const Text("Se eliminará la regla nutricional del motor experto."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("CANCELAR")),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("ELIMINAR")),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _dio.delete("reglas-nutricionales/$id");
        _loadData();
      } catch (e) {}
    }
  }
}

class _NutritionalRuleFormDialog extends ConsumerStatefulWidget {
  final Map<String, List<dynamic>> formData;
  final Map<String, dynamic>? initialRule;
  final VoidCallback onSaved;
  const _NutritionalRuleFormDialog(
      {required this.formData, this.initialRule, required this.onSaved});
  @override
  ConsumerState<_NutritionalRuleFormDialog> createState() =>
      _NutritionalRuleFormDialogState();
}

class _NutritionalRuleFormDialogState
    extends ConsumerState<_NutritionalRuleFormDialog> {
  int? _idAccion, _idObjetivo, _idTarget;
  late TextEditingController _mensajeController;
  late List<int> _selectedCondiciones;
  late bool _esEstricta;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRule;
    _idAccion = r?["id_accion"];
    _idObjetivo = r?["id_tipo_objetivo"];
    _idTarget = r?["id_ingrediente"] ??
        r?["id_grupo_alimentario"] ??
        r?["id_subgrupo_alimentario"] ??
        r?["id_etiqueta"];
    _mensajeController = TextEditingController(text: r?["mensaje_error"]);
    _selectedCondiciones = List<int>.from(r?["id_condiciones"] ?? []);
    _esEstricta = r?["es_estricta"] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialRule != null;
    List<dynamic> targetList = [];
    if (_idObjetivo == 1) {
      targetList = widget.formData["ingredientes"] ?? [];
    } else if (_idObjetivo == 2)
      targetList = widget.formData["grupos"] ?? [];
    else if (_idObjetivo == 3)
      targetList = widget.formData["etiquetas"] ?? [];
    else if (_idObjetivo == 4) targetList = widget.formData["subgrupos"] ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppTema.azulPrincipal,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24))),
        child: Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Text(isEdit ? "EDITAR REGLA NUTRICIONAL" : "NUEVA REGLA NUTRICIONAL",
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFieldSection("OBJETIVO", [
                DropdownButtonFormField<int>(
                  value: _idObjetivo,
                  decoration:
                      _modalDecor("Tipo de Objetivo*", Icons.track_changes),
                  items: widget.formData["objetivos"]
                      ?.map((o) => DropdownMenuItem<int>(
                          value: o["id"],
                          child: Text(o["nombre"].toString().toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _idObjetivo = v;
                    _idTarget = null;
                  }),
                ),
                if (_idObjetivo != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _idTarget,
                    decoration:
                        _modalDecor("Seleccionar Item*", Icons.ads_click),
                    items: targetList
                        .map((t) => DropdownMenuItem<int>(
                            value: t["id"],
                            child: Text(
                                t["nombre"] ?? t["nombre_visible"] ?? "-",
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))))
                        .toList(),
                    onChanged: (v) => setState(() => _idTarget = v),
                  ),
                ],
              ]),
              const SizedBox(height: 16),
              _buildFieldSection("ACCIÓN", [
                DropdownButtonFormField<int>(
                  value: _idAccion,
                  decoration:
                      _modalDecor("Acción Sugerida*", Icons.lightbulb_outline),
                  items: widget.formData["acciones"]
                      ?.map((a) => DropdownMenuItem<int>(
                          value: a["id"],
                          child: Text(a["nombre"].toString().toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600))))
                      .toList(),
                  onChanged: (v) => setState(() => _idAccion = v),
                ),
                SwitchListTile(
                    title: Text("Restricción Estricta",
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    value: _esEstricta,
                    onChanged: (v) => setState(() => _esEstricta = v)),
              ]),
              const SizedBox(height: 16),
              _buildFieldSection("APLICABILIDAD (CONDICIÓN)", [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12)),
                  child: ListView(
                      children: (widget.formData["condiciones"] ?? [])
                          .map((c) => CheckboxListTile(
                              title: Text(
                                  c["nombre"]?.toString() ?? "Condición",
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              value: _selectedCondiciones.contains(c["id"]),
                              activeColor: AppTema.azulPrincipal,
                              onChanged: (v) => setState(() {
                                    if (v!) {
                                      _selectedCondiciones.add(c["id"]);
                                    } else {
                                      _selectedCondiciones.remove(c["id"]);
                                    }
                                  }),
                              dense: true))
                          .toList()),
                ),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _mensajeController,
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: _modalDecor(
                      "Mensaje para el paciente", Icons.chat_bubble_outline)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCELAR",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, color: Colors.grey))),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? "..." : "GUARDAR REGLA",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildFieldSection(String title, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        ...children
      ]);
  InputDecoration _modalDecor(String l, IconData i) => InputDecoration(
      labelText: l,
      prefixIcon: Icon(i, size: 18),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none));

  Future<void> _save() async {
    if (_idAccion == null ||
        _idObjetivo == null ||
        _idTarget == null ||
        _selectedCondiciones.isEmpty) return;
    setState(() => _saving = true);
    try {
      final payload = {
        "id_accion": _idAccion,
        "id_tipo_objetivo": _idObjetivo,
        "mensaje_error": _mensajeController.text,
        "id_condiciones": _selectedCondiciones,
        "es_estricta": _esEstricta,
        "id_ingrediente": _idObjetivo == 1 ? _idTarget : null,
        "id_grupo_alimentario": _idObjetivo == 2 ? _idTarget : null,
        "id_etiqueta": _idObjetivo == 3 ? _idTarget : null,
        "id_subgrupo_alimentario": _idObjetivo == 4 ? _idTarget : null
      };
      if (widget.initialRule != null) {
        await ref.read(dioProvider).put(
            "reglas-nutricionales/${widget.initialRule!['id']}",
            data: payload);
      } else {
        await ref.read(dioProvider).post("reglas-nutricionales", data: payload);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
