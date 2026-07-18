import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "reglas_nutricionales_provider.dart";

class ReglasNutricionalesPage extends ConsumerStatefulWidget {
  const ReglasNutricionalesPage({super.key});

  @override
  ConsumerState<ReglasNutricionalesPage> createState() =>
      _ReglasNutricionalesPageState();
}

class _ReglasNutricionalesPageState extends ConsumerState<ReglasNutricionalesPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reglasNutricionalesProvider.notifier).loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _limpiarFiltros() {
    _searchController.clear();
    ref.read(reglasNutricionalesProvider.notifier).clearAllFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reglasNutricionalesProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: state.errorMessage != null
          ? _buildErrorView(state.errorMessage!)
          : SingleChildScrollView(
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
                  _buildObjetivoFilter(state),
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
            Text("Gestión de Reglas Nutricionales",
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
          label: Text("NUEVA REGLA",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.read(reglasNutricionalesProvider.notifier).loadData(),
            child: const Text("REINTENTAR"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ReglasNutricionalesState state) {
    if (state.isLoading && state.rules.isEmpty) {
      return const Row(
        children: [
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
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
                titulo: "TOTAL REGLAS",
                valor: "${state.totalItems}",
                icon: Icons.rule_rounded)),
        const SizedBox(width: 20),
        Expanded(
            child: NutriResumenCard(
                titulo: "ESTRICTAS",
                valor: "${state.strictCount}",
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

  Widget _buildToolbar(ReglasNutricionalesState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTema.grisLienzo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                    ref
                        .read(reglasNutricionalesProvider.notifier)
                        .setSearchQuery(v);
                  });
                },
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Buscar por alimento o ingrediente objetivo...",
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppTema.azulPrincipal),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSimpleFilterDropdown(
              label: "CONDICIÓN",
              value: state.filtroCondicion,
              items: (state.formData["condiciones"] ?? []),
              onChanged: (v) => ref
                  .read(reglasNutricionalesProvider.notifier)
                  .setFiltroCondicion(v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSimpleFilterDropdown(
              label: "ACCIÓN",
              value: state.filtroAccion,
              items: (state.formData["acciones"] ?? []),
              onChanged: (v) => ref
                  .read(reglasNutricionalesProvider.notifier)
                  .setFiltroAccion(v),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: state.activeFilters ? _limpiarFiltros : null,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
              label: Text(
                "LIMPIAR",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                size: 22, color: AppTema.azulPrincipal),
            onPressed: () =>
                ref.read(reglasNutricionalesProvider.notifier).loadData(),
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

  Widget _buildSimpleFilterDropdown({
    required String label,
    required int? value,
    required List<dynamic> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: AppTema.grisLienzo.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTema.azulPrincipal, size: 20),
          hint: Text(
            label,
            style: GoogleFonts.montserrat(
              color: Colors.grey.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                "TODAS LAS ${label}ES",
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...items.map((item) {
              return DropdownMenuItem<int?>(
                value: item["id"],
                child: Text(
                  item["nombre"]?.toString().toUpperCase() ?? "SIN NOMBRE",
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildObjetivoFilter(ReglasNutricionalesState state) {
    final tipos = ["INGREDIENTE", "GRUPO", "SUBGRUPO", "ETIQUETA"];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("OBJETIVO:",
                style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.blueGrey,
                    letterSpacing: 1)),
            const SizedBox(width: 16),
            _filterChip("TODOS", state.selectedObjetivos.isEmpty,
                () => ref.read(reglasNutricionalesProvider.notifier).clearObjetivos()),
            const SizedBox(width: 12),
            ...tipos.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _filterChip(
                      t,
                      state.selectedObjetivos.contains(t),
                      () => ref
                          .read(reglasNutricionalesProvider.notifier)
                          .toggleObjetivo(t)),
                )),
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
          border: Border.all(
              color: isSelected ? AppTema.azulPrincipal : Colors.grey.shade300),
        ),
        child: Text(label,
            style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildTable(ReglasNutricionalesState state) {
    if (!state.isLoading && state.rules.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.find_in_page_outlined, size: 48, color: Colors.blueGrey.shade300),
            const SizedBox(height: 16),
            Text(
              "No se encontraron reglas nutricionales",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTema.azulOscuro,
              ),
            ),
          ],
        ),
      );
    }

    return NutriTableContainer(
      child: LayoutBuilder(builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final usableWidth = totalWidth - 20;
        final currentRowsPerPage = state.rules.isEmpty
            ? 5
            : (state.rules.length < ReglasNutricionalesNotifier.pageSize
                ? state.rules.length
                : ReglasNutricionalesNotifier.pageSize);

        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(
                elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
            dividerColor: Colors.transparent,
          ),
          child: PaginatedDataTable(
            header: null,
            rowsPerPage: currentRowsPerPage,
            showFirstLastButtons: true,
            availableRowsPerPage: [currentRowsPerPage],
            onPageChanged: (idx) => ref
                .read(reglasNutricionalesProvider.notifier)
                .loadData(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 65,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("ACCIÓN", width: usableWidth * 0.15),
              _col("OBJETIVO", width: usableWidth * 0.20),
              _col("CONDICIONES", width: usableWidth * 0.35),
              _col("TIPO", width: usableWidth * 0.15),
              _col("ACCIONES", width: usableWidth * 0.15, center: true),
            ],
            source: _ReglasNutricionalesDataSource(
              rules: state.rules,
              totalRows: state.totalItems,
              offset: state.offset,
              formData: state.formData,
              isLoading: state.isLoading,
              onEdit: _showForm,
              onDelete: _deleteRule,
              totalWidth: usableWidth,
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  void _showForm([Map<String, dynamic>? rule]) {
    final state = ref.read(reglasNutricionalesProvider);
    showDialog(
      context: context,
      builder: (ctx) => _NutritionalRuleFormDialog(
        formData: state.formData,
        initialRule: rule,
        onSaved: () => ref.read(reglasNutricionalesProvider.notifier).loadData(),
      ),
    );
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Eliminar Regla?",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
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
      await ref.read(reglasNutricionalesProvider.notifier).deleteRule(id);
    }
  }
}

class _ReglasNutricionalesDataSource extends DataTableSource {
  final List<dynamic> rules;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Map<String, List<dynamic>> formData;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;
  final double totalWidth;
  final BuildContext context;

  _ReglasNutricionalesDataSource({
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
    final rowColor = index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC);

    if (isLoading) {
      return DataRow(
        color: WidgetStateProperty.all(rowColor),
        cells: [
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
                  width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 8),
              NutriShimmer(
                  width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
            ],
          ),
        )),
      ]);
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= rules.length) return null;
    final r = rules[localIndex];

    final condicionesIdsRaw = r["id_condiciones"];
    final List<dynamic> condicionesIds =
        condicionesIdsRaw is List ? condicionesIdsRaw : [];

    final nombresCondiciones = condicionesIds.map((id) {
      final c = formData["condiciones"]
          ?.firstWhere((c) => c["id"] == id, orElse: () => null);
      return c != null ? c["nombre"] : "C-$id";
    }).join(", ");

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
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
          child: Text(reglasNutricionalesTargetName(r),
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
            child: Text(
                nombresCondiciones.isEmpty
                    ? "SIN CONDICIONES"
                    : nombresCondiciones,
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
          child: NutriBadge(
              label: r['es_estricta'] == true ? "ESTRICTA" : "RECOMENDACIÓN",
              type: r['es_estricta'] == true ? 'danger' : 'info'),
        ),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.15,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HoverActionButton(
                  icon: Icons.edit_note_rounded,
                  label: "Editar",
                  color: Colors.orange,
                  onTap: () => onEdit(r)),
              const SizedBox(width: 12),
              _HoverActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: "Borrar",
                  color: Colors.redAccent,
                  onTap: () => onDelete(r["id"])),
            ],
          ),
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
      child: Text(label,
          style: GoogleFonts.montserrat(
              fontSize: 10, fontWeight: FontWeight.w800, color: tx)),
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
          Text(isEdit ? "EDITAR REGLA NUTRICIONAL" : "NUEVA REGLA NUTRICIONAL",
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
              _buildFieldSection("OBJETIVO", [
                  DropdownButtonFormField<int>(
                    value: _idObjetivo,
                  decoration:
                      _modalDecor("Tipo de Objetivo*", Icons.track_changes),
                  items: (widget.formData["objetivos"] ?? [])
                      .map((o) => DropdownMenuItem<int>(
                          value: o["id"],
                          child: Text(o["nombre"].toString().toUpperCase(),
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
                      value: _idTarget,
                    decoration:
                        _modalDecor("Seleccionar Item*", Icons.ads_click),
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
              _buildFieldSection("ACCIÓN", [
                DropdownButtonFormField<int>(
                  value: _idAccion,
                  decoration:
                      _modalDecor("Acción Sugerida*", Icons.lightbulb_outline),
                  items: (widget.formData["acciones"] ?? [])
                      .map((a) => DropdownMenuItem<int>(
                          value: a["id"],
                          child: Text(a["nombre"].toString().toUpperCase(),
                              style: GoogleFonts.montserrat(
                                  fontSize: 12, fontWeight: FontWeight.w600))))
                      .toList(),
                  onChanged: (v) => setState(() => _idAccion = v),
                ),
                SwitchListTile(
                    title: Text("Restricción Estricta",
                        style: GoogleFonts.montserrat(
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
                      "Mensaje para el paciente", Icons.chat_bubble_outline)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCELAR",
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold, color: Colors.grey))),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? "..." : "GUARDAR REGLA",
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
        splashColor: widget.color.withValues(alpha: 0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _isHovered
                    ? widget.color.withValues(alpha: 0.2)
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
