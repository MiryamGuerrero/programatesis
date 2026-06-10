import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class ReglasMedicasPage extends ConsumerStatefulWidget {
  const ReglasMedicasPage({super.key});

  @override
  ConsumerState<ReglasMedicasPage> createState() => _ReglasMedicasPageState();
}

class _ReglasMedicasPageState extends ConsumerState<ReglasMedicasPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
  int _currentPage = 1;
  int _itemsPerPage = 5; // Paginación de 5 registros

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  int? _accionIdPorNombre(String nombre) {
    final buscado = nombre.trim().toUpperCase();
    for (final a in (_formData["acciones"] ?? [])) {
      final actual = (a["nombre"] ?? "").toString().trim().toUpperCase();
      if (actual == buscado) return _toInt(a["id"]);
    }
    return null;
  }

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
          _currentPage = 1;
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
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get("reglas-medicas"),
        dio.get("reglas-medicas/form-data"),
      ]);
      if (mounted) {
        setState(() {
          _rules = results[0].data as List;
          _formData = Map<String, List<dynamic>>.from(results[1].data as Map);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtradas {
    final int selectedTab = _tabController.index;
    final int tipoEsperado = selectedTab == 0 ? 1 : 2;

    final filtered = _rules.where((r) {
      final listCondiciones = (r['id_condiciones'] as List? ?? []).cast<int>();
      final bool matchTab = listCondiciones.any((idCond) {
        final cond =
            (_formData["condiciones"] ?? []).cast<dynamic>().firstWhere(
                  (c) => _toInt(c["id"]) == idCond,
                  orElse: () => null,
                );
        if (cond == null) return false;
        final idTipo = _toInt(cond["id_tipo_condicion"] ?? cond["id_tipo"]);
        return idTipo == tipoEsperado;
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

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisFondo,
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSearchBarAndAddButton(),
              const SizedBox(height: 24),
              _buildTabs(),
              const SizedBox(height: 24),
              _buildFilterBar(),
              const SizedBox(height: 24),
              _buildMainContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión de Reglas Médicas",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Configuración de restricciones nutricionales según diagnóstico médico.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSearchBarAndAddButton() {
    return Row(
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
              style:
                  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
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
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 1;
              }),
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
            icon: const Icon(Icons.add_circle, size: 20, color: Colors.white),
            label: Text("Nueva regla",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicatorColor: AppTema.verdeSalud,
        indicatorWeight: 3,
        labelColor: AppTema.verdeSalud,
        unselectedLabelColor: Colors.blueGrey,
        labelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 18),
                SizedBox(width: 8),
                Text("Enfermedades Reumáticas"),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_outlined, size: 18),
                SizedBox(width: 8),
                Text("Síntomas temporales"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final int selectedIdx = _tabController.index;
    final int tipoEsperado = selectedIdx == 0 ? 1 : 2;

    final condicionesFiltradas = (_formData["condiciones"] ?? [])
        .where((c) =>
            _toInt(c['id_tipo_condicion'] ?? c['id_tipo']) == tipoEsperado)
        .toList();
    final idsCondicionValidos = condicionesFiltradas
        .map<int?>((c) => _toInt(c["id"]))
        .whereType<int>()
        .toSet();
    final int? valueCondicionSeguro = (_filtroCondicion != null &&
            idsCondicionValidos.contains(_filtroCondicion))
        ? _filtroCondicion
        : null;
    final int? accionPriorizar = _accionIdPorNombre("PRIORIZAR");
    final int? accionDisminuir = _accionIdPorNombre("DISMINUIR");
    final int? accionEliminar = _accionIdPorNombre("ELIMINAR");

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // FILA 1: TIPO DE ENFERMEDAD Y LIMPIAR
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tipo de enfermedad",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTema.azulOscuro)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: ValueKey("tab_${_tabController.index}"),
                      isExpanded: true,
                      value: valueCondicionSeguro,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTema.grisLienzo,
                        prefixIcon: const Icon(Icons.health_and_safety_outlined,
                            color: AppTema.verdeSalud, size: 20),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: Text("Todos los tipos de enfermedad")),
                        ...condicionesFiltradas.map((c) =>
                            DropdownMenuItem<int>(
                                value: c["id"],
                                child: Text(_norm(c["nombre"]),
                                    overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() {
                        _filtroCondicion = v;
                        _currentPage = 1;
                      }),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _filtroCondicion = null;
                    _filtroAccion = null;
                    _selectedObjetivos.clear();
                    _searchQuery = "";
                    _currentPage = 1;
                  }),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text("Limpiar filtros",
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey,
                    side: BorderSide(color: Colors.grey.shade200),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // FILA 2: ACCIÓN MÉDICA Y TIPO DE OBJETIVO
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Acción médica",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTema.azulOscuro)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _actionChip(
                            "Todos", null, Icons.list_rounded, Colors.grey),
                        const SizedBox(width: 8),
                        _actionChip("Priorizar", accionPriorizar,
                            Icons.arrow_upward_rounded, AppTema.verdeSalud),
                        const SizedBox(width: 8),
                        _actionChip("Disminuir", accionDisminuir,
                            Icons.arrow_downward_rounded, Colors.orange),
                        const SizedBox(width: 8),
                        _actionChip("Eliminar", accionEliminar,
                            Icons.delete_outline_rounded, Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _objectiveChip("Todos", "TODOS", null),
                        const SizedBox(width: 6),
                        _objectiveChip("Ingrediente", "INGREDIENTE",
                            Icons.egg_alt_outlined),
                        const SizedBox(width: 6),
                        _objectiveChip(
                            "Grupo", "GRUPO", Icons.set_meal_outlined),
                        const SizedBox(width: 6),
                        _objectiveChip(
                            "Subgrupo", "SUBGRUPO", Icons.layers_outlined),
                        const SizedBox(width: 6),
                        _objectiveChip(
                            "Etiqueta", "ETIQUETA", Icons.sell_outlined),
                      ],
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

  Widget _actionChip(String label, int? val, IconData icon, Color color) {
    final bool sel = _filtroAccion == val;
    // Si está seleccionado se torna gris, si no, usa su color de identidad
    final Color activeColor = sel ? Colors.blueGrey : color;
    final Color bgColor =
        sel ? Colors.blueGrey.withOpacity(0.1) : color.withOpacity(0.05);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _filtroAccion = val;
          _currentPage = 1;
        }),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: activeColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: activeColor),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: activeColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _objectiveChip(String label, String code, IconData? icon) {
    final bool sel = code == "TODOS"
        ? _selectedObjetivos.isEmpty
        : _selectedObjetivos.contains(code);
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          if (code == "TODOS") {
            _selectedObjetivos.clear();
          } else {
            if (_selectedObjetivos.contains(code))
              _selectedObjetivos.remove(code);
            else
              _selectedObjetivos.add(code);
          }
          _currentPage = 1;
        }),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: sel ? AppTema.azulPrincipal.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? AppTema.azulPrincipal : Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon,
                    size: 14,
                    color: sel ? AppTema.azulPrincipal : Colors.blueGrey),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: sel ? AppTema.azulPrincipal : Colors.blueGrey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(100),
          child: NutriLoading(mensaje: "Sincronizando reglas..."));
    }

    final filtered = _filtradas;
    final totalItems = filtered.length;
    final totalPages =
        totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
    final safePage = _currentPage > totalPages
        ? totalPages
        : (_currentPage < 1 ? 1 : _currentPage);
    final startIndex = (safePage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage > totalItems
        ? totalItems
        : startIndex + _itemsPerPage;
    final currentItems =
        (totalItems > 0) ? filtered.sublist(startIndex, endIndex) : [];

    return Column(
      children: [
        NutriTableContainer(
          child: Column(
            children: [
              _buildTableHead(),
              if (currentItems.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child: Text("No se encontraron reglas configuradas.")))
              else
                ...currentItems.map((r) => _buildTableRow(r)),
            ],
          ),
        ),
        if (totalItems > 0) ...[
          const SizedBox(height: 24),
          _buildPagination(totalItems, startIndex + 1, endIndex, safePage),
        ],
      ],
    );
  }

  Widget _buildTableHead() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: _tableHeaderLabel("Diagnóstico")),
          Expanded(flex: 3, child: _tableHeaderLabel("Acción")),
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
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: AppTema.azulOscuro));
  }

  Widget _buildTableRow(Map<String, dynamic> r) {
    final condicionesIds = r["id_condiciones"] as List;
    final nombresCondiciones = condicionesIds.map((id) {
      final c = _formData["condiciones"]
          ?.firstWhere((c) => c["id"] == id, orElse: () => null);
      return c != null ? _norm(c["nombre"]) : "C-$id";
    }).join(", ");

    final bool isTemporalTab = _tabController.index == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // DIAGNÓSTICO
          Expanded(
              flex: 4,
              child: Row(
                children: [
                  Image.asset(
                      isTemporalTab
                          ? "assets/images/rule_temporal_icon.webp"
                          : "assets/images/rule_joint_icon.webp",
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(nombresCondiciones,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis)),
                ],
              )),

          // ACCIÓN
          Expanded(
              flex: 3,
              child: _accionBadgeMock(r['accion_codigo']?.toString() ?? "-")),

          // OBJETIVO
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B))),
                ],
              )),

          // ESTRICTA
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
                  Text(r["es_estricta"] == true ? "Sí" : "No",
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey)),
                ],
              ))),

          // ACCIONES
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                    icon: Icons.edit_outlined,
                    label: "Editar",
                    color: Colors.orange,
                    onTap: () => _showForm(r)),
                const SizedBox(width: 16),
                _actionButton(
                    icon: Icons.delete_outline_rounded,
                    label: "Eliminar",
                    color: Colors.red,
                    onTap: () => _deleteRule(r["id"])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accionBadgeMock(String label) {
    final normalized = _norm(label).trim().toUpperCase();
    Color color = AppTema.verdeSalud;
    IconData icon = Icons.arrow_upward_rounded;
    String text = "Priorizar";

    if (normalized == 'ELIMINAR') {
      color = Colors.redAccent;
      icon = Icons.delete_outline_rounded;
      text = "Eliminar";
    } else if (normalized == 'DISMINUIR') {
      color = Colors.orange;
      icon = Icons.arrow_downward_rounded;
      text = "Disminuir";
    } else if (normalized == 'PRIORIZAR') {
      color = AppTema.verdeSalud;
      icon = Icons.arrow_upward_rounded;
      text = "Priorizar";
    } else {
      // fallback defensivo para valores no estandarizados
      text = _norm(label).isEmpty ? "Priorizar" : _norm(label);
    }

    return UnconstrainedBox(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(text,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return _HoverActionButton(
        icon: icon, label: label, color: color, onTap: onTap);
  }

  Widget _buildPagination(int total, int start, int end, int safePage) {
    final totalPages = (total / _itemsPerPage).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Mostrando $start a $end de $total reglas",
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey)),
        Row(
          children: [
            _pageButton(
                Icons.chevron_left,
                safePage > 1
                    ? () => setState(() => _currentPage = safePage - 1)
                    : null),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTema.azulPrincipal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text("$safePage",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            _pageButton(
                Icons.chevron_right,
                safePage < totalPages
                    ? () => setState(() => _currentPage = safePage + 1)
                    : null),
          ],
        ),
      ],
    );
  }

  Widget _pageButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(icon,
            size: 20,
            color: onTap == null ? Colors.grey.shade300 : Colors.black),
      ),
    );
  }

  String _getTargetName(Map<String, dynamic> r) =>
      _norm(r['ingrediente_nombre'] ??
          r['grupo_nombre'] ??
          r['subgrupo_nombre'] ??
          r['etiqueta_nombre'] ??
          "Objetivo");

  void _showForm([Map<String, dynamic>? rule]) {
    showDialog(
        context: context,
        builder: (ctx) => _MedicalRuleFormDialog(
            formData: _formData, initialRule: rule, onSaved: _loadData));
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Eliminar Regla?",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: const Text("Se eliminará la restricción clínica del sistema."),
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
        await ref.read(dioProvider).delete("reglas-medicas/$id");
        _loadData();
      } catch (e) {}
    }
  }
}

class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HoverActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: Colors.transparent,
        splashColor: widget.color.withOpacity(0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _isHovered
                    ? widget.color.withOpacity(0.2)
                    : Colors.transparent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.color, size: 18),
              const SizedBox(height: 4),
              Text(widget.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: widget.color,
                      height: 1.0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicalRuleFormDialog extends ConsumerStatefulWidget {
  final Map<String, List<dynamic>> formData;
  final Map<String, dynamic>? initialRule;
  final VoidCallback onSaved;
  const _MedicalRuleFormDialog(
      {required this.formData, this.initialRule, required this.onSaved});
  @override
  ConsumerState<_MedicalRuleFormDialog> createState() =>
      _MedicalRuleFormDialogState();
}

class _MedicalRuleFormDialogState
    extends ConsumerState<_MedicalRuleFormDialog> {
  int? _idAccion, _idObjetivo, _idTarget;
  late TextEditingController _mensajeController;
  late List<int> _selectedCondiciones;
  late bool _esEstricta;
  bool _saving = false;

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
    final r = widget.initialRule;
    _idAccion = r?["id_accion"];
    _idObjetivo = r?["id_tipo_objetivo"];
    _idTarget = r?["id_ingrediente"] ??
        r?["id_grupo_alimentario"] ??
        r?["id_subgrupo_alimentario"] ??
        r?["id_etiqueta"];
    _mensajeController =
        TextEditingController(text: r?["mensaje_error"]?.toString());
    _selectedCondiciones = List<int>.from(r?["id_condiciones"] ?? []);
    _esEstricta = r?["es_estricta"] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialRule != null;
    List<dynamic> targetList = [];
    if (_idObjetivo == 1) {
      targetList = widget.formData["ingredientes"]!;
    } else if (_idObjetivo == 2)
      targetList = widget.formData["grupos"]!;
    else if (_idObjetivo == 3)
      targetList = widget.formData["etiquetas"]!;
    else if (_idObjetivo == 4)
      targetList =
          widget.formData["subgroups"] ?? widget.formData["subgrupos"] ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 1000,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              color: AppTema.azulPrincipal,
              child: Row(
                children: [
                  const Icon(Icons.settings_suggest_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(isEdit ? "EDITAR REGLA CLÍNICA" : "NUEVA REGLA CLÍNICA",
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // COLUMNA IZQUIERDA
                      Expanded(
                        child: Column(
                          children: [
                            _formCard(
                              icon: Icons.track_changes_rounded,
                              title: "Objetivo",
                              children: [
                                _fieldLabel("Tipo de objetivo*"),
                                DropdownButtonFormField<int>(
                                  value: _idObjetivo,
                                  decoration:
                                      _inputDecor(Icons.pentagon_outlined),
                                  items: widget.formData["objetivos"]
                                      ?.map((o) => DropdownMenuItem<int>(
                                          value: o["id"],
                                          child: Text(
                                              _norm(o["nombre"]).toUpperCase(),
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600))))
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _idObjetivo = v;
                                    _idTarget = null;
                                  }),
                                ),
                                const SizedBox(height: 20),
                                _fieldLabel("Seleccionar item*"),
                                DropdownButtonFormField<int>(
                                  value: _idTarget,
                                  isExpanded: true,
                                  decoration:
                                      _inputDecor(Icons.opacity_rounded),
                                  items: targetList
                                      .map((t) => DropdownMenuItem<int>(
                                          value: t["id"],
                                          child: Text(
                                              _norm(t["nombre"]).toUpperCase(),
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600))))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _idTarget = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _formCard(
                              icon: Icons.gavel_rounded,
                              title: "Acción médica",
                              children: [
                                _fieldLabel("Acción médica*"),
                                DropdownButtonFormField<int>(
                                  value: _idAccion,
                                  decoration: _inputDecor(
                                      Icons.delete_outline_rounded,
                                      iconColor: Colors.green),
                                  items: widget.formData["acciones"]
                                      ?.map((a) => DropdownMenuItem<int>(
                                          value: a["id"],
                                          child: Text(
                                              _norm(a["nombre"]).toUpperCase(),
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600))))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _idAccion = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // COLUMNA DERECHA
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_user_outlined,
                                      color: AppTema.verdeSalud, size: 22),
                                  const SizedBox(width: 12),
                                  Text("Restricción estricta",
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppTema.azulOscuro)),
                                  const Spacer(),
                                  Switch.adaptive(
                                    value: _esEstricta,
                                    activeColor: AppTema.verdeSalud,
                                    onChanged: (v) =>
                                        setState(() => _esEstricta = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _formCard(
                              icon: Icons.assignment_turned_in_outlined,
                              title: "Aplicabilidad por condición médica",
                              customHeader: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.assignment_ind_outlined,
                                          color: AppTema.azulPrincipal,
                                          size: 22),
                                      const SizedBox(width: 12),
                                      Text("Aplicabilidad por condición médica",
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTema.azulOscuro)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 34),
                                    child: Text(
                                        "Seleccione las condiciones médicas para las que se aplicará esta regla clínica.",
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.blueGrey,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  height: 200,
                                  child: ListView(
                                    children:
                                        (widget.formData["condiciones"] ?? [])
                                            .map((c) {
                                      final bool isSel = _selectedCondiciones
                                          .contains(c["id"]);
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          decoration: BoxDecoration(
                                            color: isSel
                                                ? AppTema.azulPrincipal
                                                    .withOpacity(0.02)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: isSel
                                                    ? AppTema.azulPrincipal
                                                    : Colors.grey.shade200),
                                          ),
                                          child: CheckboxListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16),
                                            title: Text(
                                                _norm(c["nombre"]).isEmpty
                                                    ? "Condición"
                                                    : _norm(c["nombre"]),
                                                style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSel
                                                        ? AppTema.azulPrincipal
                                                        : Colors.blueGrey)),
                                            value: isSel,
                                            activeColor: AppTema.azulPrincipal,
                                            onChanged: (v) => setState(() {
                                              if (v!) {
                                                _selectedCondiciones
                                                    .add(c["id"]);
                                              } else {
                                                _selectedCondiciones
                                                    .remove(c["id"]);
                                              }
                                            }),
                                            dense: true,
                                            controlAffinity:
                                                ListTileControlAffinity
                                                    .trailing,
                                            checkboxShape:
                                                RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // OBSERVACION
                  _formCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: "Observación / Justificación",
                    children: [
                      TextFormField(
                        controller: _mensajeController,
                        maxLines: 3,
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTema.grisLienzo,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // FOOTER BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancelar",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blueGrey,
                                  fontSize: 13))),
                      const SizedBox(width: 24),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTema.azulPrincipal,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            icon: const Icon(Icons.save_outlined, size: 20),
                            label: Text(
                                _saving ? "GUARDANDO..." : "Guardar regla",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formCard(
      {required IconData icon,
      required String title,
      Widget? customHeader,
      required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          customHeader ??
              Row(
                children: [
                  Icon(icon, color: AppTema.azulPrincipal, size: 22),
                  const SizedBox(width: 12),
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTema.azulOscuro)),
                ],
              ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String l) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(l,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey)),
      );

  InputDecoration _inputDecor(IconData i, {Color? iconColor}) =>
      InputDecoration(
        prefixIcon: Icon(i, size: 18, color: iconColor ?? Colors.blueGrey),
        filled: true,
        fillColor: AppTema.grisLienzo,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );

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
        await ref
            .read(dioProvider)
            .put("reglas-medicas/${widget.initialRule!['id']}", data: payload);
      } else {
        await ref.read(dioProvider).post("reglas-medicas", data: payload);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
