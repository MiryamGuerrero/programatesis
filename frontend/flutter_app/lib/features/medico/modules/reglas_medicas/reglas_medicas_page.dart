import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "../../data/medical_catalogs_notifier.dart";

class ReglasMedicasPage extends ConsumerStatefulWidget {
  const ReglasMedicasPage({super.key});

  @override
  ConsumerState<ReglasMedicasPage> createState() => _ReglasMedicasPageState();
}

class _ReglasMedicasPageState extends ConsumerState<ReglasMedicasPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(medicalRulesProvider.notifier).loadPage();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(medicalRulesProvider.notifier).setSearchQuery(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(medicalRulesProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(state),
            const SizedBox(height: 32),
            _buildToolbar(state),
            const SizedBox(height: 24),
            _buildTable(state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Motor de reglas clínicas",
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTema.azulPrincipal,
                    letterSpacing: -0.5)),
            Text(
                "Configuración de lógica médica estricta y recomendaciones basadas en diagnósticos.",
                style: GoogleFonts.inter(
                    color: Colors.blueGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        FilledButton.icon(
          onPressed: () => _showForm(),
          style: FilledButton.styleFrom(
            backgroundColor: AppTema.verdeSalud,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          label: Text("Nueva regla",
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildStatsRow(MedicalRulesState state) {
    if (state.isLoading && state.rules.isEmpty) {
      return const Row(
        children: [
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
          Expanded(child: NutriResumenCardShimmer()),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: NutriResumenCard(
            titulo: 'Reglas médicas',
            valor: '${state.totalItems}',
            icon: Icons.gavel_rounded,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        const Expanded(
          child: NutriResumenCard(
            titulo: 'Estado del motor',
            valor: 'Activo',
            icon: Icons.bolt_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(MedicalRulesState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Buscar por acción, objetivo o diagnóstico...",
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: "Limpiar búsqueda",
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                          ref
                              .read(medicalRulesProvider.notifier)
                              .setSearchQuery("");
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                size: 22, color: AppTema.azulPrincipal),
            onPressed: () => ref.read(medicalRulesProvider.notifier).loadPage(),
            tooltip: "Actualizar motor",
            style: IconButton.styleFrom(
              backgroundColor: AppTema.azulPrincipal.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(MedicalRulesState state) {
    return NutriTableContainer(
      child: LayoutBuilder(builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(
                elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
          ),
          child: PaginatedDataTable(
            header: null,
            rowsPerPage: MedicalRulesNotifier.pageSize,
            showFirstLastButtons: true,
            availableRowsPerPage: const [MedicalRulesNotifier.pageSize],
            onPageChanged: (idx) =>
                ref.read(medicalRulesProvider.notifier).loadPage(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dataRowMinHeight: 65,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
            columns: [
              _col("Acción", width: totalWidth * 0.15),
              _col("Objetivo", width: totalWidth * 0.20),
              _col("Aplica a diagnósticos", width: totalWidth * 0.35),
              _col("Tipo", width: totalWidth * 0.15),
              _col("Acciones", width: totalWidth * 0.15, center: true),
            ],
            source: _MedicalRulesDataSource(
              rules: state.rules,
              totalRows: state.totalItems,
              offset: state.offset,
              isLoading: state.isLoading,
              formData: state.formData,
              onEdit: _showForm,
              onDelete: (id) => _eliminarRegla(id),
              totalWidth: totalWidth,
              context: context,
            ),
          ),
        );
      }),
    );
  }

  DataColumn _col(String label, {required double width, bool center = false}) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Container(
          alignment: center ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppTema.azulOscuro),
          ),
        ),
      ),
    );
  }

  Future<void> _showForm([Map<String, dynamic>? rule]) async {
    var state = ref.read(medicalRulesProvider);
    if (state.formData.isEmpty) {
      await ref.read(medicalRulesProvider.notifier).loadFormData();
      if (!mounted) return;
      state = ref.read(medicalRulesProvider);
      if (state.formData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudieron cargar los datos del formulario."),
          ),
        );
        return;
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => _NutritionalRuleFormDialog(
        formData: state.formData,
        initialRule: rule,
        onSaved: () => ref.read(medicalRulesProvider.notifier).loadPage(),
      ),
    );
  }

  Future<void> _eliminarRegla(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Eliminar regla médica?"),
        content:
            const Text("Esta acción eliminará la lógica del motor experto."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(medicalRulesProvider.notifier).deleteRule(id);
    }
  }
}

class _MedicalRulesDataSource extends DataTableSource {
  final List<dynamic> rules;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Map<String, List<dynamic>> formData;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;
  final double totalWidth;
  final BuildContext context;

  _MedicalRulesDataSource({
    required this.rules,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.formData,
    required this.onEdit,
    required this.onDelete,
    required this.totalWidth,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    if (isLoading) {
      return DataRow(cells: [
        DataCell(SizedBox(
            width: totalWidth * 0.15,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: NutriShimmer(width: 80, height: 20),
                )))),
        DataCell(SizedBox(
            width: totalWidth * 0.20,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: NutriShimmer(width: double.infinity, height: 12)))),
        DataCell(SizedBox(
            width: totalWidth * 0.35,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: NutriShimmer(width: double.infinity, height: 12)))),
        DataCell(SizedBox(
            width: totalWidth * 0.15,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: NutriShimmer(width: 100, height: 20)))),
        DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 8),
              NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.circular(12)),
            ],
          ),
        )),
      ]);
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= rules.length) return null;
    final r = rules[localIndex];

    final nombresCondiciones =
        (r["condiciones_nombres"] ?? "Sin diagnósticos").toString();

    return DataRow(cells: [
      DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _accionBadge(r['accion_codigo'] ?? 'N/A'),
            ),
          ))),
      DataCell(SizedBox(
        width: totalWidth * 0.20,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
          child: Text(r["objetivo_nombre"] ?? "-",
              softWrap: true,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w700)),
        ),
      )),
      DataCell(SizedBox(
          width: totalWidth * 0.35,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
            child: Text(nombresCondiciones,
                softWrap: true,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey)),
          ))),
      DataCell(SizedBox(
        width: totalWidth * 0.15,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _tipoBadge(r['es_estricta'] == true),
        ),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.15,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
                tooltip: "Editar regla",
                icon: const Icon(Icons.edit_note_rounded,
                    color: Colors.orange, size: 22),
                onPressed: () => onEdit(r)),
            IconButton(
                tooltip: "Eliminar regla",
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 20),
                onPressed: () => onDelete(r["id"])),
          ],
        ),
      )),
    ]);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(_sentenceCase(label),
          style: GoogleFonts.montserrat(
              fontSize: 10, fontWeight: FontWeight.w800, color: tx)),
    );
  }

  String _sentenceCase(String value) {
    final text = value.trim().toLowerCase();
    return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
  }

  Widget _tipoBadge(bool isEstricta) {
    final color = isEstricta ? Colors.redAccent : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(
        isEstricta ? "Estricta" : "Recomendación",
        style: GoogleFonts.montserrat(
            color: color, fontWeight: FontWeight.w800, fontSize: 9),
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => (isLoading && totalRows == 0) ? 5 : totalRows;
  @override
  int get selectedRowCount => 0;
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
    } else if (_idObjetivo == 2) {
      targetList = widget.formData["grupos"] ?? [];
    } else if (_idObjetivo == 3) {
      targetList = widget.formData["etiquetas"] ?? [];
    } else if (_idObjetivo == 4) {
      targetList = widget.formData["subgrupos"] ?? [];
    }

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
          Text(isEdit ? "Editar regla clínica" : "Nueva regla clínica",
              style: GoogleFonts.montserrat(
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
              _buildFieldSection("Objetivo", [
                DropdownButtonFormField<int>(
                  initialValue: _idObjetivo,
                  decoration:
                      _modalDecor("Tipo de objetivo*", Icons.track_changes),
                  items: (widget.formData["objetivos"] ?? [])
                      .map((o) => DropdownMenuItem<int>(
                          value: o["id"],
                          child: Text(o["nombre"].toString(),
                              style: GoogleFonts.montserrat(
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
                    initialValue: _idTarget,
                    decoration:
                        _modalDecor("Seleccionar elemento*", Icons.ads_click),
                    items: targetList
                        .map((t) => DropdownMenuItem<int>(
                            value: t["id"],
                            child: Text(
                                t["nombre"] ?? t["nombre_visible"] ?? "-",
                                style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))))
                        .toList(),
                    onChanged: (v) => setState(() => _idTarget = v),
                  ),
                ],
              ]),
              const SizedBox(height: 16),
              _buildFieldSection("Acción", [
                DropdownButtonFormField<int>(
                  initialValue: _idAccion,
                  decoration:
                      _modalDecor("Acción sugerida*", Icons.lightbulb_outline),
                  items: (widget.formData["acciones"] ?? [])
                      .map((a) => DropdownMenuItem<int>(
                          value: a["id"],
                          child: Text(a["nombre"].toString(),
                              style: GoogleFonts.montserrat(
                                  fontSize: 12, fontWeight: FontWeight.w600))))
                      .toList(),
                  onChanged: (v) => setState(() => _idAccion = v),
                ),
                SwitchListTile(
                    title: Text("Restricción estricta",
                        style: GoogleFonts.montserrat(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    value: _esEstricta,
                    onChanged: (v) => setState(() => _esEstricta = v)),
              ]),
              const SizedBox(height: 16),
              _buildFieldSection("Aplicabilidad del diagnóstico", [
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
                                  style: GoogleFonts.montserrat(
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
                  style: GoogleFonts.montserrat(fontSize: 13),
                  decoration: _modalDecor(
                      "Mensaje clínico", Icons.chat_bubble_outline)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar",
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold, color: Colors.grey))),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? "..." : "Guardar regla",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildFieldSection(String title, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.montserrat(
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
        _selectedCondiciones.isEmpty) {
      return;
    }
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
