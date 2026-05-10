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

class _ReglasMedicasPageState extends ConsumerState<ReglasMedicasPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<dynamic> _rules = [];
  Map<String, List<dynamic>> _formData = {
    "acciones": [], "objetivos": [], "condiciones": [],
    "ingredientes": [], "grupos": [], "subgrupos": [], "etiquetas": []
  };
  
  String _searchQuery = "";
  final Set<String> _selectedObjetivos = {};
  int? _filtroCondicion;
  int? _filtroAccion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _filtroCondicion = null;
        _filtroAccion = null;
        _selectedObjetivos.clear();
      });
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
    
    return _rules.where((r) {
      final tipos = (r['tipos_condicion'] as List? ?? []);
      bool matchType = false;
      if (selectedTab == 0) matchType = tipos.contains("Clínica");
      else if (selectedTab == 1) matchType = tipos.contains("Temporal");
      else matchType = tipos.contains("Nutricional");

      if (!matchType) return false;

      final targetName = _getTargetName(r).toLowerCase();
      final matchesSearch = targetName.contains(_searchQuery.toLowerCase());
      final matchesTipo = _selectedObjetivos.isEmpty || _selectedObjetivos.contains(r["objetivo_codigo"]);
      final condicionesIds = (r["id_condiciones"] as List).cast<int>();
      final matchesCondicion = _filtroCondicion == null || condicionesIds.contains(_filtroCondicion);
      final matchesAccion = _filtroAccion == null || r["id_accion"] == _filtroAccion;
      
      return matchesSearch && matchesTipo && matchesCondicion && matchesAccion;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
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
                    _buildTabBar(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión de Reglas Médicas", 
          style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text("Configuración de restricciones nutricionales según diagnóstico médico.", 
          style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 55,
                decoration: BoxDecoration(
                  color: AppTema.grisLienzo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: "Buscar por alimento o ingrediente objetivo...",
                    hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTema.azulPrincipal),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              height: 55,
              child: FilledButton.icon(
                onPressed: () => _showForm(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                icon: const Icon(Icons.add_moderator_rounded, size: 20, color: Colors.white),
                label: Text("NUEVA REGLA", 
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppTema.azulPrincipal,
      unselectedLabelColor: Colors.blueGrey,
      indicatorColor: AppTema.verdeSalud,
      indicatorWeight: 4,
      labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
      unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13),
      tabs: const [
        Tab(text: "REGLAS CLÍNICAS"),
        Tab(text: "SÍNTOMAS TEMPORALES"),
        Tab(text: "REGLAS NUTRICIONALES"),
      ],
    );
  }

  Widget _buildFilterBar() {
    final tipos = ["INGREDIENTE", "GRUPO", "SUBGRUPO", "ETIQUETA"];
    
    // Filtrar condiciones según el Tab activo
    final int selectedIdx = _tabController.index;
    final int tipoEsperado = selectedIdx == 0 ? 1 : (selectedIdx == 1 ? 2 : 3);
    
    final condicionesFiltradas = (_formData["condiciones"] ?? [])
        .where((c) => (c['id_tipo_condicion'] ?? c['id_tipo']) == tipoEsperado)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("OBJETIVO:", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
            const SizedBox(width: 16),
            _filterChip("TODOS", _selectedObjetivos.isEmpty, () => setState(() => _selectedObjetivos.clear())),
            const SizedBox(width: 12),
            ...tipos.map((t) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _filterChip(t, _selectedObjetivos.contains(t), () => setState(() => _selectedObjetivos.contains(t) ? _selectedObjetivos.remove(t) : _selectedObjetivos.add(t))),
            )),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("DIAGNÓSTICO:", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: ValueKey("tab_${_tabController.index}"),
                    isExpanded: true,
                    initialValue: _filtroCondicion,
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    decoration: InputDecoration(
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("TODOS LOS DIAGNÓSTICOS")),
                      ...condicionesFiltradas.map((c) => DropdownMenuItem<int>(value: c["id"], child: Text(c["nombre"].toString().toUpperCase(), overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _filtroCondicion = v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ACCIÓN MÉDICA:", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _filtroAccion,
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    decoration: InputDecoration(
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("TODAS LAS ACCIONES")),
                      ...(_formData["acciones"] ?? []).map((a) => DropdownMenuItem<int>(value: a["id"], child: Text(a["nombre"].toString().toUpperCase(), overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _filtroAccion = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTema.azulPrincipal : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTema.azulPrincipal : Colors.grey.shade300),
        ),
        child: Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildTable() {
    return NutriTableContainer(
      child: Theme(
        data: Theme.of(context).copyWith(
          cardTheme: const CardThemeData(elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
        ),
        child: PaginatedDataTable(
          header: null,
          rowsPerPage: 5,
          showFirstLastButtons: true,
          availableRowsPerPage: const [5],
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
          columns: [
            _col("ACCIÓN"),
            _col("TIPO"),
            _col("OBJETIVO"),
            _col("DIAGNÓSTICOS"),
            _col("ESTRICTA"),
            _col("ACCIONES"),
          ],
          source: _ReglasMedicasDataSource(
            rules: _filtradas,
            formData: _formData,
            onEdit: _showForm,
            onDelete: _deleteRule,
            context: context,
          ),
        ),
      ),
    );
  }

  DataColumn _col(String l) => DataColumn(
    label: Text(l, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))
  );

  String _getTargetName(Map<String, dynamic> r) => r['ingrediente_nombre'] ?? r['grupo_nombre'] ?? r['subgrupo_nombre'] ?? r['etiqueta_nombre'] ?? "Objetivo";

  void _showForm([Map<String, dynamic>? rule]) {
    showDialog(context: context, builder: (ctx) => _MedicalRuleFormDialog(formData: _formData, initialRule: rule, onSaved: _loadData));
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Eliminar Regla?", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: const Text("Se eliminará la restricción clínica del sistema."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(ctx, true), child: const Text("ELIMINAR")),
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

class _ReglasMedicasDataSource extends DataTableSource {
  final List<dynamic> rules;
  final Map<String, List<dynamic>> formData;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;
  final BuildContext context;

  _ReglasMedicasDataSource({
    required this.rules,
    required this.formData,
    required this.onEdit,
    required this.onDelete,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= rules.length) return null;
    final r = rules[index];
    
    final condicionesIds = r["id_condiciones"] as List;
    final nombresCondiciones = condicionesIds.map((id) {
      final c = formData["condiciones"]?.firstWhere((c) => c["id"] == id, orElse: () => null);
      return c != null ? c["nombre"] : "C-$id";
    }).join(", ");

    final tipos = (r['tipos_condicion'] as List? ?? []);
    final tipoPrincipal = tipos.contains("Clínica") ? "Clínica" : (tipos.isNotEmpty ? tipos.first : "Clínica");

    return DataRow(cells: [
      DataCell(_accionBadge(r['accion_codigo'])),
      DataCell(_tipoBadge(tipoPrincipal)),
      DataCell(Text(_getTargetName(r), style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w700))),
      DataCell(SizedBox(width: 250, child: Text(nombresCondiciones, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey), overflow: TextOverflow.ellipsis))),
      DataCell(Icon(r["es_estricta"] == true ? Icons.lock_rounded : Icons.lock_open_rounded, color: r["es_estricta"] == true ? Colors.redAccent : Colors.grey.shade400, size: 18)),
      DataCell(Row(
        children: [
          IconButton(tooltip: "Editar", icon: const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 22), onPressed: () => onEdit(r)),
          IconButton(tooltip: "Eliminar", icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => onDelete(r["id"])),
        ],
      )),
    ]);
  }

  Widget _tipoBadge(String label) {
    Color bg = const Color(0xFFE0F2FE); Color tx = const Color(0xFF0369A1);
    if (label == 'Temporal') { bg = const Color(0xFFF3E8FF); tx = const Color(0xFF7E22CE); }
    if (label == 'Nutricional') { bg = const Color(0xFFDCFCE7); tx = const Color(0xFF15803D); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: tx)),
    );
  }

  Widget _accionBadge(String label) {
    Color bg = const Color(0xFFF1F5F9); Color tx = Colors.blueGrey;
    if (label == 'ELIMINAR') { bg = const Color(0xFFFEE2E2); tx = const Color(0xFFB91C1C); }
    else if (label == 'PRIORIZAR') { bg = const Color(0xFFDCFCE7); tx = const Color(0xFF15803D); }
    else if (label == 'DISMINUIR') { bg = const Color(0xFFFEF3C7); tx = const Color(0xFFB45309); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: tx)),
    );
  }

  String _getTargetName(Map<String, dynamic> r) => r['ingrediente_nombre'] ?? r['grupo_nombre'] ?? r['subgrupo_nombre'] ?? r['etiqueta_nombre'] ?? "Objetivo";

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => rules.length;
  @override
  int get selectedRowCount => 0;
}

class _MedicalRuleFormDialog extends ConsumerStatefulWidget {
  final Map<String, List<dynamic>> formData;
  final Map<String, dynamic>? initialRule;
  final VoidCallback onSaved;
  const _MedicalRuleFormDialog({required this.formData, this.initialRule, required this.onSaved});
  @override
  ConsumerState<_MedicalRuleFormDialog> createState() => _MedicalRuleFormDialogState();
}

class _MedicalRuleFormDialogState extends ConsumerState<_MedicalRuleFormDialog> {
  int? _idAccion, _idObjetivo, _idTarget;
  late TextEditingController _mensajeController;
  late List<int> _selectedCondiciones;
  late bool _esEstricta;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRule;
    _idAccion = r?["id_accion"]; _idObjetivo = r?["id_tipo_objetivo"];
    _idTarget = r?["id_ingrediente"] ?? r?["id_grupo_alimentario"] ?? r?["id_subgrupo_alimentario"] ?? r?["id_etiqueta"];
    _mensajeController = TextEditingController(text: r?["mensaje_error"]);
    _selectedCondiciones = List<int>.from(r?["id_condiciones"] ?? []);
    _esEstricta = r?["es_estricta"] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialRule != null;
    List<dynamic> targetList = [];
    if (_idObjetivo == 1) {
      targetList = widget.formData["ingredientes"]!;
    } else if (_idObjetivo == 2) targetList = widget.formData["grupos"]!;
    else if (_idObjetivo == 3) targetList = widget.formData["etiquetas"]!;
    else if (_idObjetivo == 4) targetList = widget.formData["subgroups"] ?? widget.formData["subgrupos"] ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
        child: Row(children: [
          const Icon(Icons.rule_folder_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Text(isEdit ? "EDITAR REGLA CLÍNICA" : "NUEVA REGLA CLÍNICA", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                  initialValue: _idObjetivo,
                  decoration: _modalDecor("Tipo de Objetivo*", Icons.track_changes),
                  items: widget.formData["objetivos"]?.map((o) => DropdownMenuItem<int>(value: o["id"], child: Text(o["nombre"].toString().toUpperCase(), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
                  onChanged: (v) => setState(() { _idObjetivo = v; _idTarget = null; }),
                ),
                if (_idObjetivo != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _idTarget,
                    decoration: _modalDecor("Seleccionar Item*", Icons.ads_click),
                    items: targetList.map((t) => DropdownMenuItem<int>(value: t["id"], child: Text(t["nombre"].toString().toUpperCase(), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
                    onChanged: (v) => setState(() => _idTarget = v),
                  ),
                ],
              ]),
              const SizedBox(height: 16),
              _buildFieldSection("ACCIÓN", [
                DropdownButtonFormField<int>(
                  initialValue: _idAccion,
                  decoration: _modalDecor("Acción Médica*", Icons.gavel),
                  items: widget.formData["acciones"]?.map((a) => DropdownMenuItem<int>(value: a["id"], child: Text(a["nombre"].toString().toUpperCase(), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
                  onChanged: (v) => setState(() => _idAccion = v),
                ),
                SwitchListTile(title: Text("Restricción Estricta", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600)), value: _esEstricta, onChanged: (v) => setState(() => _esEstricta = v)),
              ]),
              const SizedBox(height: 16),
              _buildFieldSection("APLICABILIDAD", [
                Container(
                  height: 120, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                  child: ListView(children: widget.formData["condiciones"]!.map((c) => CheckboxListTile(title: Text(c["nombre"], style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)), value: _selectedCondiciones.contains(c["id"]), activeColor: AppTema.azulPrincipal, onChanged: (v) => setState(() { if(v!) {
                    _selectedCondiciones.add(c["id"]);
                  } else {
                    _selectedCondiciones.remove(c["id"]);
                  } }), dense: true)).toList()),
                ),
              ]),
              const SizedBox(height: 16),
              TextFormField(controller: _mensajeController, maxLines: 2, style: GoogleFonts.montserrat(fontSize: 13), decoration: _modalDecor("Observación / Justificación", Icons.chat_bubble_outline)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey))),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? "..." : "GUARDAR REGLA", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildFieldSection(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)), const SizedBox(height: 8), ...children]);
  InputDecoration _modalDecor(String l, IconData i) => InputDecoration(labelText: l, prefixIcon: Icon(i, size: 18), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));

  Future<void> _save() async {
    if (_idAccion == null || _idObjetivo == null || _idTarget == null || _selectedCondiciones.isEmpty) return;
    setState(() => _saving = true);
    try {
      final payload = {"id_accion": _idAccion, "id_tipo_objetivo": _idObjetivo, "mensaje_error": _mensajeController.text, "id_condiciones": _selectedCondiciones, "es_estricta": _esEstricta, "id_ingrediente": _idObjetivo == 1 ? _idTarget : null, "id_grupo_alimentario": _idObjetivo == 2 ? _idTarget : null, "id_etiqueta": _idObjetivo == 3 ? _idTarget : null, "id_subgrupo_alimentario": _idObjetivo == 4 ? _idTarget : null};
      if (widget.initialRule != null) {
        await ref.read(dioProvider).put("reglas-medicas/${widget.initialRule!['id']}", data: payload);
      } else {
        await ref.read(dioProvider).post("reglas-medicas", data: payload);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } finally { if (mounted) setState(() => _saving = false); }
  }
}
