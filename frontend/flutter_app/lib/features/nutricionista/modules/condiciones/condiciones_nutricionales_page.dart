import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/shimmer_components.dart";

class CondicionesNutricionalesPage extends ConsumerStatefulWidget {
  const CondicionesNutricionalesPage({super.key});

  @override
  ConsumerState<CondicionesNutricionalesPage> createState() =>
      _CondicionesNutricionalesPageState();
}

class _CondicionesNutricionalesPageState
    extends ConsumerState<CondicionesNutricionalesPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _loading = true;
  bool _loadingStats = true;
  List<dynamic> _condiciones = [];
  String _searchQuery = "";

  bool get _filtrosActivos => _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchData(updateStats: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _limpiarFiltros() {
    _searchController.clear();
    setState(() => _searchQuery = "");
  }

  Future<void> _fetchData({bool updateStats = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      if (updateStats) _loadingStats = true;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("condiciones-nutricionales");
      if (mounted) {
        setState(() {
          _condiciones = res.data as List;
          _loading = false;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingStats = false;
        });
      }
    }
  }

  List<dynamic> get _pesoItems => _condiciones
      .where((c) =>
          (c["indicador_codigo"]?.toString() ?? "").toUpperCase() != "HFA" &&
          c["nombre"]
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
      .toList();

  List<dynamic> get _tallaItems => _condiciones
      .where((c) =>
          (c["indicador_codigo"]?.toString() ?? "").toUpperCase() == "HFA" &&
          c["nombre"]
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
      .toList();

  String _truncateDescription(String? desc) {
    if (desc == null || desc.isEmpty) return "-";
    int dotIndex = desc.indexOf('.');
    if (dotIndex != -1) {
      return desc.substring(0, dotIndex + 1);
    }
    return desc;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildStatsRow(),
              const SizedBox(height: 32),
              _buildToolbar(),
              const SizedBox(height: 24),
              _buildTabs(),
              const SizedBox(height: 24),
              _buildMainContent(),
            ],
          ),
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
            Text("Catálogo de Condiciones",
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTema.azulPrincipal,
                    letterSpacing: -0.5)),
            Text(
                "Diccionario maestro de diagnósticos y eventos de salud para el sistema.",
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
          label: Text("NUEVA CONDICIÓN",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    if (_loadingStats) {
      return const Row(
        children: [
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
          Expanded(child: NutriResumenCardShimmer()),
        ],
      );
    }

    final pesoCount = _condiciones
        .where((c) =>
            (c["indicador_codigo"]?.toString() ?? "").toUpperCase() != "HFA")
        .length;
    final tallaCount = _condiciones
        .where((c) =>
            (c["indicador_codigo"]?.toString() ?? "").toUpperCase() == "HFA")
        .length;

    return Row(
      children: [
        Expanded(
          child: NutriResumenCard(
            titulo: 'CONDICIONES DE PESO',
            valor: '$pesoCount',
            icon: Icons.monitor_weight_rounded,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: NutriResumenCard(
            titulo: 'CONDICIONES DE TALLA',
            valor: '$tallaCount',
            icon: Icons.height_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
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
                onChanged: (v) => setState(() => _searchQuery = v),
                style:
                    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Buscar por nombre de condición...",
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
            onPressed: () => _fetchData(updateStats: true),
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
                Icon(Icons.monitor_weight_outlined, size: 18),
                SizedBox(width: 8),
                Text("CONDICIONES PARA PESO"),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.height_outlined, size: 18),
                SizedBox(width: 8),
                Text("CONDICIONES PARA TALLA"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final items = _tabController.index == 0 ? _pesoItems : _tallaItems;

    return Column(
      children: [
        NutriTableContainer(
          child: Theme(
            data: Theme.of(context).copyWith(
              cardTheme: const CardThemeData(
                  elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
            ),
            child: PaginatedDataTable(
              header: null,
              rowsPerPage: 10,
              showFirstLastButtons: true,
              availableRowsPerPage: const [10],
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: [
                _col("IDENTIDAD", flex: 5),
                _col("ESTADO", flex: 2, center: true),
                _col("ACCIONES", flex: 3, center: true),
              ],
              source: _CondicionesDataSource(
                items: items,
                isLoading: _loading,
                onVer: (c) => _verDetalle(c),
                onEdit: (c) => _abrirFormulario(condicion: c),
                onDelete: (c) => _eliminar(c),
                truncateDesc: _truncateDescription,
                context: context,
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataColumn _col(String label, {int flex = 1, bool center = false}) {
    return DataColumn(
      label: Expanded(
        flex: flex,
        child: Container(
          alignment: center ? Alignment.center : Alignment.centerLeft,
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
        builder: (context) => _DetalleCondicionModal(condicion: item));
  }

  void _abrirFormulario({Map<String, dynamic>? condicion}) {
    showDialog(
      context: context,
      barrierColor: AppTema.azulOscuro.withOpacity(0.4),
      builder: (context) =>
          _FormularioCondicion(condicion: condicion, onSuccess: () => _fetchData(updateStats: true)),
    );
  }

  Future<void> _eliminar(Map<String, dynamic> c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("¿Eliminar registro?",
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
            "¿Deseas eliminar '${c["nombre"]}'? Esta acción es irreversible.",
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("CANCELAR",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, color: Colors.grey))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("ELIMINAR")),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref
            .read(dioProvider)
            .delete("condiciones-nutricionales/${c["id"]}");
        _fetchData(updateStats: true);
        if (mounted) {
          NutriSnack.show(context, "Condición eliminada", ref: ref);
        }
      } catch (e) {
        if (mounted) {
          NutriSnack.show(context, "Error al eliminar: $e",
              isError: true, ref: ref);
        }
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTema.verdeSalud : Colors.redAccent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(isActive ? Icons.check_circle_outline : Icons.highlight_off,
            size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          isActive ? "Activa" : "Inactiva",
          style: GoogleFonts.inter(
              color: color, fontWeight: FontWeight.w700, fontSize: 11),
        ),
      ],
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

class _DetalleCondicionModal extends StatelessWidget {
  final Map<String, dynamic> condicion;
  const _DetalleCondicionModal({required this.condicion});

  @override
  Widget build(BuildContext context) {
    final int tipo = (condicion["indicador_codigo"]?.toString() ?? "").toUpperCase() == "HFA" ? 2 : 1;
    final bool isPeso = tipo == 1;
    final Color mainColor = isPeso ? AppTema.azulPrincipal : AppTema.verdeSalud;
    final Color lightBg =
        isPeso ? const Color(0xFFF8FAFF) : const Color(0xFFF7FDF9);
    final Color iconBoxBg =
        isPeso ? const Color(0xFFEBF5FF) : const Color(0xFFF0FDF4);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        width: 900,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CABECERA
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: iconBoxBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                        isPeso
                            ? Icons.monitor_weight_rounded
                            : Icons.height_rounded,
                        size: 38,
                        color: mainColor),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              condicion["nombre"].toString().toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTema.azulOscuro,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close,
                                color: Colors.grey, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _badge(
                              isPeso
                                  ? Icons.monitor_weight_outlined
                                  : Icons.height_outlined,
                              isPeso ? "CONDICIÓN PARA PESO" : "CONDICIÓN PARA TALLA",
                              mainColor),
                          const SizedBox(width: 10),
                          _badge(Icons.circle, "ACTIVA", AppTema.verdeSalud,
                              isDot: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // CONTENIDO PRINCIPAL (DOS COLUMNAS)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // COLUMNA IZQUIERDA: DESCRIPCIÓN
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 18,
                              color: AppTema.azulOscuro.withValues(alpha: 0.7)),
                          const SizedBox(width: 8),
                          Text(
                            "DESCRIPCIÓN TÉCNICA",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTema.azulOscuro.withValues(alpha: 0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                              child: Divider(
                                  thickness: 1, color: Color(0xFFF1F5F9))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: lightBg,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: mainColor.withValues(alpha: 0.05)),
                        ),
                        child: Text(
                          condicion["descripcion"] ??
                              "Información no disponible.",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF475569),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 32),

                // DIVIDER VERTICAL
                const IntrinsicHeight(
                  child:
                      VerticalDivider(thickness: 1, color: Color(0xFFF1F5F9)),
                ),

                const SizedBox(width: 32),

                // COLUMNA DERECHA: ASPECTOS RELACIONADOS
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ASPECTOS RELACIONADOS",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTema.azulOscuro.withValues(alpha: 0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _aspectItem(
                        icon: isPeso
                            ? Icons.scale_rounded
                            : Icons.straighten_rounded,
                        title: isPeso
                            ? "Control de peso"
                            : "Monitoreo de crecimiento",
                        desc: isPeso
                            ? "Evaluación constante del peso corporal."
                            : "Seguimiento de la estatura y desarrollo.",
                      ),
                      const SizedBox(height: 12),
                      _aspectItem(
                        icon: Icons.fact_check_outlined,
                        title: "Referencia OMS",
                        desc:
                            "Basado en los estándares internacionales de salud.",
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // FOOTER
            Center(
              child: SizedBox(
                width: 250,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.folder_open_rounded,
                      size: 18, color: mainColor),
                  label: Text(
                    "CERRAR FICHA",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: mainColor,
                      fontSize: 11,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: mainColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color,
      {bool isDot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isDot ? 6 : 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aspectItem(
      {required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child:
              Icon(icon, color: AppTema.azulOscuro.withValues(alpha: 0.7), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTema.azulOscuro,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.blueGrey,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
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
      _idTipo = (widget.condicion!["indicador_codigo"]?.toString() ?? "").toUpperCase() == "HFA" ? 2 : 1;
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
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  isEdit ? "Modificar Registro" : "Nueva Condición Nutricional",
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTema.azulOscuro,
                      letterSpacing: -0.8)),
              const SizedBox(height: 6),
              Text("Complete la ficha técnica de la condición para el sistema.",
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              _sectionTitle("CLASIFICACIÓN"),
              Row(
                children: [
                  _typeOption(1, "PESO", Icons.monitor_weight_rounded,
                      "Condición para peso"),
                  const SizedBox(width: 12),
                  _typeOption(
                      2, "TALLA", Icons.height_rounded, "Condición para talla"),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle("INFORMACIÓN GENERAL"),
              _minimalInput(
                  _nombreCtrl, "Nombre oficial", Icons.badge_outlined),
              const SizedBox(height: 24),
              _sectionTitle("DETALLE CLÍNICO"),
              _minimalInput(
                  _descCtrl,
                  "Descripción o criterios nutricionales...",
                  Icons.text_snippet_outlined,
                  lines: 3),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppTema.grisLienzo,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100)),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: _activa ? AppTema.verdeSalud : Colors.grey,
                        size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Estado de Disponibilidad",
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTema.azulOscuro)),
                          Text("Habilita esta condición para uso en pacientes.",
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: Colors.blueGrey)),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                          value: _activa,
                          activeColor: AppTema.verdeSalud,
                          onChanged: (v) => setState(() => _activa = v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("CANCELAR",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              color: Colors.grey,
                              fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTema.azulPrincipal,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                            _saving ? "PROCESANDO..." : "GUARDAR REGISTRO",
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)),
                      ),
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
        child: Text(t,
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppTema.azulPrincipal.withOpacity(0.5),
                letterSpacing: 1.5)),
      );

  Widget _minimalInput(TextEditingController c, String h, IconData i,
          {int lines = 1, bool isNum = false}) =>
      TextFormField(
        controller: c,
        maxLines: lines,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTema.azulOscuro),
        decoration: InputDecoration(
          hintText: h,
          prefixIcon: Icon(i, color: AppTema.azulPrincipal, size: 18),
          filled: true,
          fillColor: AppTema.grisLienzo,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          hintStyle: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500),
        ),
      );

  Widget _typeOption(int val, String title, IconData icon, String sub) {
    final sel = _idTipo == val;
    final color = sel ? AppTema.verdeSalud : Colors.grey.shade300;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _idTipo = val),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sel ? AppTema.verdeSalud.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: sel ? 2 : 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: sel ? AppTema.verdeSalud : Colors.grey.shade500)),
              Text(sub,
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
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
        "id_tipo": 3, // Forzar tipo nutricional
        "indicador_codigo": _idTipo == 2 ? "HFA" : "BMI", // Mapear a indicador
        "activa": _activa,
      };

      if (widget.condicion != null) {
        await dio.put("condiciones-nutricionales/${widget.condicion!['id']}",
            data: payload);
      } else {
        await dio.post("condiciones-nutricionales", data: payload);
      }

      widget.onSuccess();
      if (mounted) {
        NutriSnack.show(context, "Registro guardado correctamente", ref: ref);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        NutriSnack.show(context, "Error al procesar solicitud",
            isError: true, ref: ref);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CondicionesDataSource extends DataTableSource {
  final List<dynamic> items;
  final bool isLoading;
  final Function(Map<String, dynamic>) onVer;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;
  final String Function(String?) truncateDesc;
  final BuildContext context;

  _CondicionesDataSource({
    required this.items,
    required this.isLoading,
    required this.onVer,
    required this.onEdit,
    required this.onDelete,
    required this.truncateDesc,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    if (isLoading) {
      return DataRow(cells: [
        DataCell(Row(
          children: [
            const NutriShimmer(width: 24, height: 24, borderRadius: BorderRadius.all(Radius.circular(4))),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NutriShimmer(width: 150, height: 12),
                const SizedBox(height: 4),
                const NutriShimmer(width: 200, height: 10),
              ],
            ),
          ],
        )),
        const DataCell(Center(child: NutriShimmer(width: 60, height: 20, borderRadius: BorderRadius.all(Radius.circular(10))))),
        DataCell(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const NutriShimmer(width: 28, height: 28, borderRadius: BorderRadius.all(Radius.circular(14))),
            const SizedBox(width: 12),
            const NutriShimmer(width: 28, height: 28, borderRadius: BorderRadius.all(Radius.circular(14))),
            const SizedBox(width: 12),
            const NutriShimmer(width: 28, height: 28, borderRadius: BorderRadius.all(Radius.circular(14))),
          ],
        )),
      ]);
    }

    if (index >= items.length) return null;
    final c = items[index] as Map<String, dynamic>;
    final bool isTalla = (c["indicador_codigo"]?.toString() ?? "").toUpperCase() == "HFA";

    return DataRow(cells: [
      DataCell(Row(
        children: [
          Icon(
              isTalla
                  ? Icons.height_rounded
                  : Icons.monitor_weight_rounded,
              size: 24,
              color: AppTema.azulPrincipal.withOpacity(0.7)),
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
                Text(truncateDesc(c["descripcion"]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey)),
              ],
            ),
          ),
        ],
      )),
      DataCell(Center(child: _StatusBadge(isActive: c['activa'] == true))),
      DataCell(Row(
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
              label: "Edit",
              color: Colors.orange,
              onTap: () => onEdit(c)),
          const SizedBox(width: 12),
          _HoverActionButton(
              icon: Icons.delete_outline_rounded,
              label: "Borrar",
              color: Colors.red,
              onTap: () => onDelete(c)),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => (isLoading && items.isEmpty) ? 5 : items.length;
  @override
  int get selectedRowCount => 0;
}
