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
    extends ConsumerState<CatalogoCondicionesPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) {
        // Tipo 1: Crónica (Médico), Tipo 2: Temporal
        ref.read(medicalConditionsProvider.notifier).setTipo(_tabController.index + 1);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(medicalConditionsProvider.notifier).setTipo(1);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
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
            _buildTabs(),
            const SizedBox(height: 24),
            _buildMainContent(state),
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
            Text("Catálogo de condiciones médicas",
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
        ),
        FilledButton.icon(
          onPressed: () => _abrirFormulario(),
          style: FilledButton.styleFrom(
            backgroundColor: AppTema.verdeSalud,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          label: Text("Nueva condición",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 13)),
        ),
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
            titulo: 'Total de registros',
            valor: '${state.totalItems}',
            icon: Icons.folder_shared_outlined,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        const Expanded(
          child: NutriResumenCard(
            titulo: 'Estado de la base',
            valor: 'Estándar OMS',
            icon: Icons.verified_user_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(MedicalConditionsState state) {
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
                    ref.read(medicalConditionsProvider.notifier).setSearchQuery(v);
                  });
                },
                style:
                    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Buscar por nombre de diagnóstico...",
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppTema.azulPrincipal),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                size: 22, color: AppTema.azulPrincipal),
            onPressed: () => ref.read(medicalConditionsProvider.notifier).loadPage(),
            tooltip: "Actualizar catálogo",
            style: IconButton.styleFrom(
              backgroundColor:
                  AppTema.azulPrincipal.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
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
        indicatorColor: AppTema.azulPrincipal,
        indicatorWeight: 3,
        labelColor: AppTema.azulPrincipal,
        unselectedLabelColor: Colors.blueGrey,
        labelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_graph_rounded, size: 18),
                SizedBox(width: 8),
                Text("Patologías crónicas"),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 18),
                SizedBox(width: 8),
                Text("Eventos temporales"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(MedicalConditionsState state) {
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
            rowsPerPage: MedicalConditionsNotifier.pageSize,
            showFirstLastButtons: true,
            availableRowsPerPage: const [MedicalConditionsNotifier.pageSize],
            onPageChanged: (idx) =>
                ref.read(medicalConditionsProvider.notifier).loadPage(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dataRowMinHeight: 65,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
            columns: [
              _col("Diagnóstico", width: totalWidth * 0.50),
              _col("Estado", width: totalWidth * 0.15, center: true),
              _col("Acciones", width: totalWidth * 0.35, center: true),
            ],
            source: _MedicalConditionsDataSource(
              items: state.conditions,
              totalRows: state.totalItems,
              offset: state.offset,
              isLoading: state.isLoading,
              onVer: (c) => _verDetalle(c),
              onEdit: (c) => _abrirFormulario(condicion: c),
              onDelete: (c) => _eliminar(c),
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTema.azulOscuro),
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
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Eliminar"),
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
    if (isLoading) {
      return DataRow(cells: [
        DataCell(SizedBox(
          width: totalWidth * 0.50,
          child: Row(
            children: [
              const NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.all(Radius.circular(4))),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NutriShimmer(width: 150, height: 12),
                  const SizedBox(height: 4),
                  NutriShimmer(
                      width: 200,
                      height: 10,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ],
          ),
        )),
        DataCell(SizedBox(
            width: totalWidth * 0.15,
            child: const Center(child: NutriShimmer(width: 60, height: 20)))),
        DataCell(SizedBox(
          width: totalWidth * 0.35,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NutriShimmer(
                  width: 28, height: 28, borderRadius: BorderRadius.circular(14)),
              const SizedBox(width: 12),
              NutriShimmer(
                  width: 28, height: 28, borderRadius: BorderRadius.circular(14)),
              const SizedBox(width: 12),
              NutriShimmer(
                  width: 28, height: 28, borderRadius: BorderRadius.circular(14)),
            ],
          ),
        )),
      ]);
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= items.length) return null;
    final c = items[localIndex] as Map<String, dynamic>;

    return DataRow(cells: [
      DataCell(SizedBox(
        width: totalWidth * 0.50,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.medical_information_outlined,
                  size: 24, color: AppTema.azulPrincipal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c["nombre"]?.toString() ?? "Condición",
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B))),
                    Text(c["descripcion"]?.toString() ?? "-",
                        softWrap: true,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.blueGrey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
      DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: Center(child: _StatusBadge(isActive: c['activa'] == true)))),
      DataCell(SizedBox(
        width: totalWidth * 0.35,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _HoverActionButton(
                icon: Icons.visibility_outlined,
                label: "Ver",
                color: AppTema.azulPrincipal,
                onTap: () => onVer(c)),
            const SizedBox(width: 12),
            _HoverActionButton(
                icon: Icons.edit_outlined,
                label: "Editar",
                color: Colors.orange,
                onTap: () => onEdit(c)),
            const SizedBox(width: 12),
            _HoverActionButton(
                icon: Icons.delete_outline_rounded,
                label: "Borrar",
                color: Colors.red,
                onTap: () => onDelete(c)),
          ],
        ),
      )),
    ]);
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
        isActive ? "Activo" : "Inactivo",
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
                      Text(condicion["nombre"]?.toString() ?? "Condición",
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
                      const SizedBox(height: 4),
                      Text(isCronica ? "Patología crónica" : "Evento temporal",
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
                child: const Text("Cerrar vista"),
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
              Text(isEdit ? "Modificar registro" : "Nueva condición médica",
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppTema.azulOscuro)),
              const SizedBox(height: 24),
              _sectionTitle("Clasificación"),
              Row(
                children: [
                  _typeOption(1, "Crónica", Icons.auto_graph_rounded, "Patología base"),
                  const SizedBox(width: 12),
                  _typeOption(2, "Temporal", Icons.history_toggle_off_rounded, "Evento agudo"),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle("Información general"),
              _minimalInput(_nombreCtrl, "Nombre del diagnóstico", Icons.badge_outlined),
              const SizedBox(height: 24),
              _sectionTitle("Detalles clínicos"),
              _minimalInput(_descCtrl, "Descripción técnica...", Icons.text_snippet_outlined, lines: 3),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar"))),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? "Guardando..." : "Guardar registro"),
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
