import "dart:async";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "../../data/medical_catalogs_notifier.dart";

class CatalogoCondicionesPage extends ConsumerStatefulWidget {
  const CatalogoCondicionesPage({super.key});

  @override
  ConsumerState<CatalogoCondicionesPage> createState() =>
      _CatalogoCondicionesPageState();
}

class _CatalogoCondicionesPageState
    extends ConsumerState<CatalogoCondicionesPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(medicalConditionsProvider.notifier).setTipo(1);
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
    ref.read(medicalConditionsProvider.notifier).setSearchQuery("");
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(medicalConditionsProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(state),
            const SizedBox(height: 32),
            _buildToolbar(state),
            const SizedBox(height: 24),
            _buildTabs(state),
            const SizedBox(height: 24),
            _buildMainContent(state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Catálogo de Condiciones Médicas",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Repositorio de diagnósticos clínicos y eventos temporales de salud.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsRow(MedicalConditionsState state) {
    if (state.isLoading && state.conditions.isEmpty) {
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
            titulo: 'TOTAL REGISTROS',
            valor: '${state.totalItems}',
            icon: Icons.folder_shared_outlined,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        const Expanded(
          child: NutriResumenCard(
            titulo: 'ESTADO BASE',
            valor: 'ESTÁNDAR OMS',
            icon: Icons.verified_user_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(MedicalConditionsState state) {
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
              controller: _searchController,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar por nombre de diagnóstico o evento...",
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  ref.read(medicalConditionsProvider.notifier).setSearchQuery(v);
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => _abrirFormulario(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTema.verdeSalud,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.add_circle, size: 20, color: Colors.white),
            label: Text("Nueva condición",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(MedicalConditionsState state) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              label: "Condiciones clínicas",
              isSelected: state.selectedTipo == 1,
              onTap: () {
                ref.read(medicalConditionsProvider.notifier).setTipo(1);
              },
            ),
          ),
          Expanded(
            child: _buildTabItem(
              label: "Síntomas temporales",
              isSelected: state.selectedTipo == 2,
              onTap: () {
                ref.read(medicalConditionsProvider.notifier).setTipo(2);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = AppTema.verdeSalud;
    final inactiveColor = Colors.blueGrey;

    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? activeColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(MedicalConditionsState state) {
    if (!state.isLoading && state.conditions.isEmpty) {
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
              "No se encontraron condiciones médicas",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTema.azulOscuro,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Prueba a ajustar la búsqueda o los filtros.",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.blueGrey.shade500,
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
        final currentRowsPerPage = state.conditions.isEmpty
            ? 5
            : (state.conditions.length < MedicalConditionsNotifier.pageSize
                ? state.conditions.length
                : MedicalConditionsNotifier.pageSize);

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
            onPageChanged: (idx) =>
                ref.read(medicalConditionsProvider.notifier).loadPage(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 65,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("DIAGNÓSTICO", width: usableWidth * 0.25),
              _col("DESCRIPCIÓN", width: usableWidth * 0.40),
              _col("ESTADO", width: usableWidth * 0.15, center: true),
              _col("ACCIONES", width: usableWidth * 0.20, center: true),
            ],
            source: _MedicalConditionsDataSource(
              items: state.conditions,
              totalRows: state.totalItems,
              offset: state.offset,
              isLoading: state.isLoading,
              onVer: (c) => _verDetalle(c),
              onEdit: (c) => _abrirFormulario(condicion: c),
              onDelete: (c) => _eliminar(c),
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

  void _verDetalle(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _DetalleCondicionModal(condicion: item),
    );
  }

  void _abrirFormulario({Map<String, dynamic>? condicion}) {
    showDialog(
      context: context,
      barrierColor: AppTema.azulOscuro.withValues(alpha: 0.4),
      builder: (context) => _FormularioCondicion(
        condicion: condicion,
        onSuccess: () => ref.read(medicalConditionsProvider.notifier).loadPage(),
      ),
    );
  }

  Future<void> _eliminar(Map<String, dynamic> c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("¿Eliminar registro?"),
        content: Text("¿Deseas eliminar '${c["nombre"]}'? Esta acción es irreversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCELAR"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("ELIMINAR"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete("catalogos/condiciones/${c["id"]}");
        ref.read(medicalConditionsProvider.notifier).loadPage();
        if (mounted) NutriSnack.show(context, "Registro eliminado");
      } catch (e) {
        if (mounted) NutriSnack.show(context, "Error al eliminar", isError: true);
      }
    }
  }
}

class _MedicalConditionsDataSource extends DataTableSource {
  final List<dynamic> items;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Function(Map<String, dynamic>) onVer;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;
  final double totalWidth;
  final BuildContext context;

  _MedicalConditionsDataSource({
    required this.items,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.onVer,
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
            width: totalWidth * 0.25,
            child: Row(
              children: [
                const NutriShimmer(
                    width: 32,
                    height: 32,
                    borderRadius: BorderRadius.all(Radius.circular(16))),
                const SizedBox(width: 12),
                Expanded(
                  child: NutriShimmer(
                      width: 100,
                      height: 12,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ],
            ),
          )),
          DataCell(SizedBox(
            width: totalWidth * 0.40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: NutriShimmer(
                  width: double.infinity,
                  height: 12,
                  borderRadius: BorderRadius.circular(4)),
            ),
          )),
          DataCell(SizedBox(
              width: totalWidth * 0.15,
              child: const Center(child: NutriShimmer(width: 60, height: 20)))),
          DataCell(SizedBox(
            width: totalWidth * 0.20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NutriShimmer(
                    width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 8),
                NutriShimmer(
                    width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 8),
                NutriShimmer(
                    width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
              ],
            ),
          )),
        ],
      );
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= items.length) return null;
    final c = items[localIndex] as Map<String, dynamic>;

    final int tipoCondicion = c["id_tipo_condicion"] ?? 1;
    final bool isClinica = tipoCondicion == 1;

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
        DataCell(SizedBox(
          width: totalWidth * 0.25,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isClinica ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      isClinica
                          ? "assets/images/clinica.png"
                          : "assets/images/temporal.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c["nombre"]?.toString() ?? "Condición",
                    softWrap: true,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.40,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
            child: Text(
              c["descripcion"]?.toString() ?? "-",
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey),
            ),
          ),
        )),
        DataCell(SizedBox(
            width: totalWidth * 0.15,
            child: Center(child: _StatusBadge(isActive: c['activa'] == true)))),
        DataCell(SizedBox(
          width: totalWidth * 0.20,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HoverActionButton(
                    icon: Icons.visibility_outlined,
                    label: "Ver",
                    color: AppTema.azulPrincipal,
                    onTap: () => onVer(c)),
                const SizedBox(width: 8),
                _HoverActionButton(
                    icon: Icons.edit_outlined,
                    label: "Editar",
                    color: AppTema.verdeSalud,
                    onTap: () => onEdit(c)),
                const SizedBox(width: 8),
                _HoverActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: "Eliminar",
                    color: Colors.redAccent,
                    onTap: () => onDelete(c)),
              ],
            ),
          ),
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => (isLoading && totalRows == 0) ? 5 : totalRows;
  @override
  int get selectedRowCount => 0;
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTema.verdeSalud : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(
        isActive ? "ACTIVO" : "INACTIVO",
        style: GoogleFonts.montserrat(
            color: color, fontWeight: FontWeight.w800, fontSize: 10),
      ),
    );
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
              Icon(widget.icon, color: widget.color, size: 20),
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

class _DetalleCondicionModal extends StatelessWidget {
  final Map<String, dynamic> condicion;
  const _DetalleCondicionModal({required this.condicion});

  @override
  Widget build(BuildContext context) {
    final int tipo = condicion["id_tipo_condicion"] ?? 1;
    final bool isCronica = tipo == 1;
    final Color mainColor = isCronica ? AppTema.azulPrincipal : Colors.orange;
    final Color iconBoxBg = mainColor.withValues(alpha: 0.1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: iconBoxBg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(isCronica ? Icons.auto_graph_rounded : Icons.history_toggle_off_rounded, size: 32, color: mainColor),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(condicion["nombre"]?.toString().toUpperCase() ?? "CONDICIÓN",
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
                      const SizedBox(height: 4),
                      Text(isCronica ? "PATOLOGÍA CRÓNICA" : "EVENTO TEMPORAL",
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: mainColor)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(condicion["descripcion"] ?? "Sin descripción detallada.",
                style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: const Color(0xFF475569))),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CERRAR VISTA"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormularioCondicion extends ConsumerStatefulWidget {
  final Map<String, dynamic>? condicion;
  final VoidCallback onSuccess;
  const _FormularioCondicion({this.condicion, required this.onSuccess});
  @override
  ConsumerState<_FormularioCondicion> createState() =>
      _FormularioCondicionState();
}

class _FormularioCondicionState extends ConsumerState<_FormularioCondicion> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _idTipo = 1;
  bool _activa = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.condicion != null) {
      _nombreCtrl.text = widget.condicion!["nombre"] ?? "";
      _descCtrl.text = widget.condicion!["descripcion"] ?? "";
      _idTipo = widget.condicion!["id_tipo_condicion"] ?? 1;
      _activa = widget.condicion!["activa"] ?? true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.condicion != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? "Modificar Registro" : "Nueva Condición Médica",
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppTema.azulOscuro)),
              const SizedBox(height: 24),
              _sectionTitle("CLASIFICACIÓN"),
              Row(
                children: [
                  _typeOption(1, "CRÓNICA", Icons.auto_graph_rounded, "Patología base"),
                  const SizedBox(width: 12),
                  _typeOption(2, "TEMPORAL", Icons.history_toggle_off_rounded, "Evento agudo"),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle("INFORMACIÓN GENERAL"),
              _minimalInput(_nombreCtrl, "Nombre del diagnóstico", Icons.badge_outlined),
              const SizedBox(height: 24),
              _sectionTitle("DETALLES CLÍNICOS"),
              _minimalInput(_descCtrl, "Descripción técnica...", Icons.text_snippet_outlined, lines: 3),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR"))),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? "GUARDANDO..." : "GUARDAR REGISTRO"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppTema.azulPrincipal, letterSpacing: 1.5)),
      );

  Widget _minimalInput(TextEditingController c, String h, IconData i, {int lines = 1}) =>
      TextFormField(
        controller: c, maxLines: lines,
        decoration: InputDecoration(
          hintText: h, prefixIcon: Icon(i, size: 18),
          filled: true, fillColor: AppTema.grisLienzo,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );

  Widget _typeOption(int val, String title, IconData icon, String sub) {
    final sel = _idTipo == val;
    final color = sel ? AppTema.azulPrincipal : Colors.grey.shade300;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _idTipo = val),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sel ? AppTema.azulPrincipal.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: sel ? 2 : 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: sel ? AppTema.azulPrincipal : Colors.grey.shade500)),
              Text(sub, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nombreCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        "nombre": _nombreCtrl.text,
        "descripcion": _descCtrl.text,
        "id_tipo": _idTipo,
        "activa": _activa,
      };

      if (widget.condicion != null) {
        await dio.put("catalogos/condiciones/${widget.condicion!['id']}", data: payload);
      } else {
        await dio.post("catalogos/condiciones", data: payload);
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) NutriSnack.show(context, "Error al guardar", isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
