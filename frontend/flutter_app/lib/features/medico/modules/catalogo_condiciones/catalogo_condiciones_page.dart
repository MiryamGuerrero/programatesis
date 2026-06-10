import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:dio/dio.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class CatalogoCondicionesPage extends ConsumerStatefulWidget {
  const CatalogoCondicionesPage({super.key});

  @override
  ConsumerState<CatalogoCondicionesPage> createState() =>
      _CatalogoCondicionesPageState();
}

class _CatalogoCondicionesPageState
    extends ConsumerState<CatalogoCondicionesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<dynamic> _condiciones = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("catalogos/condiciones");
      if (mounted) {
        setState(() {
          _condiciones = res.data as List;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _clinicas => _condiciones
      .where((c) =>
          (c["id_tipo"] ?? c["id_tipo_condicion"]) == 1 &&
          c["nombre"]
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
      .toList();

  List<dynamic> get _temporales => _condiciones
      .where((c) =>
          (c["id_tipo"] ?? c["id_tipo_condicion"]) == 2 &&
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
              const SizedBox(height: 16),
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
                hintText: "Buscar por nombre o palabra clave...",
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade400, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                if (v.isNotEmpty) {
                  final hasClinicas = _clinicas.isNotEmpty;
                  final hasTemporales = _temporales.isNotEmpty;
                  if (_tabController.index == 0 &&
                      !hasClinicas &&
                      hasTemporales) {
                    _tabController.animateTo(1);
                  } else if (_tabController.index == 1 &&
                      !hasTemporales &&
                      hasClinicas) {
                    _tabController.animateTo(0);
                  }
                }
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

  Widget _buildMainContent() {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(100),
          child: NutriLoading(mensaje: "Sincronizando catálogo..."));
    }

    final items = _tabController.index == 0 ? _clinicas : _temporales;

    return Column(
      children: [
        NutriTableContainer(
          child: Column(
            children: [
              _buildTableHead(),
              if (items.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(40),
                    child:
                        Center(child: Text("No se encontraron condiciones.")))
              else
                ...items.map((c) => _buildTableRow(c)),
            ],
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPagination(items.length),
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
          Expanded(flex: 5, child: _tableHeaderLabel("Identidad")),
          Expanded(flex: 2, child: Center(child: _tableHeaderLabel("Estado"))),
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
            fontSize: 13,
            color: AppTema.azulOscuro));
  }

  Widget _buildTableRow(Map<String, dynamic> c) {
    final bool isTemporal = (c["id_tipo"] ?? c["id_tipo_condicion"]) == 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Image.asset(
                    isTemporal
                        ? "assets/images/rule_temporal_icon.webp"
                        : "assets/images/rule_joint_icon.webp",
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c["nombre"]?.toString() ?? "Condición",
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B))),
                      Text(_truncateDescription(c["descripcion"]),
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
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(child: _StatusBadge(isActive: c['activa'] == true)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                    icon: Icons.visibility_outlined,
                    label: "Ver detalle",
                    color: AppTema.azulPrincipal,
                    onTap: () => _verDetalle(c)),
                const SizedBox(width: 16),
                _actionButton(
                    icon: Icons.edit_outlined,
                    label: "Editar",
                    color: Colors.orange,
                    onTap: () => _abrirFormulario(condicion: c)),
                const SizedBox(width: 16),
                _actionButton(
                    icon: Icons.delete_outline_rounded,
                    label: "Eliminar",
                    color: Colors.red,
                    onTap: () => _eliminar(c)),
              ],
            ),
          ),
        ],
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

  Widget _buildPagination(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Mostrando 1 a $total de $total condiciones",
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey)),
        Row(
          children: [
            _pageButton(Icons.chevron_left, null),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTema.azulPrincipal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text("1",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            _pageButton(Icons.chevron_right, null),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No se encontraron condiciones",
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400)),
        ],
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
          _FormularioCondicion(condicion: condicion, onSuccess: _fetchData),
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
        await ref.read(dioProvider).delete("catalogos/condiciones/${c["id"]}");
        _fetchData();
        if (mounted) NutriSnack.show(context, "Condición eliminada", ref: ref);
      } catch (e) {
        if (mounted)
          NutriSnack.show(context, "Error al eliminar: $e",
              isError: true, ref: ref);
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

class _DetalleCondicionModal extends StatelessWidget {
  final Map<String, dynamic> condicion;
  const _DetalleCondicionModal({required this.condicion});

  @override
  Widget build(BuildContext context) {
    final int tipo =
        condicion["id_tipo"] ?? condicion["id_tipo_condicion"] ?? 1;
    final bool isClinica = tipo == 1;
    final Color mainColor =
        isClinica ? AppTema.azulPrincipal : AppTema.verdeSalud;
    final Color lightBg =
        isClinica ? const Color(0xFFF8FAFF) : const Color(0xFFF7FDF9);
    final Color iconBoxBg =
        isClinica ? const Color(0xFFEBF5FF) : const Color(0xFFF0FDF4);

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
                    child: isClinica
                        ? Image.asset("assets/images/modal_icon_mi.webp",
                            width: 45, height: 45, fit: BoxFit.contain)
                        : const Icon(Icons.flash_on_rounded,
                            size: 38, color: AppTema.verdeSalud),
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
                              isClinica
                                  ? Icons.medical_services_outlined
                                  : Icons.access_time_outlined,
                              isClinica
                                  ? "DIAGNÓSTICO CLÍNICO"
                                  : "SÍNTOMA TEMPORAL",
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
                          Icon(
                              isClinica
                                  ? Icons.menu_book_outlined
                                  : Icons.menu_book_rounded,
                              size: 18,
                              color: AppTema.azulOscuro.withOpacity(0.7)),
                          const SizedBox(width: 8),
                          Text(
                            "DESCRIPCIÓN TÉCNICA",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTema.azulOscuro.withOpacity(0.8),
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
                              Border.all(color: mainColor.withOpacity(0.05)),
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
                      if (!isClinica) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 18, color: AppTema.azulOscuro),
                            const SizedBox(width: 8),
                            Text(
                              "VENTANA DE TIEMPO SUGERIDA",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTema.azulOscuro.withOpacity(0.8),
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
                                Border.all(color: mainColor.withOpacity(0.05)),
                          ),
                          child: Text(
                            "${condicion["duracion_dias_sugerida"] ?? '5'} días de seguimiento recomendado.",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF475569),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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
                          color: AppTema.azulOscuro.withOpacity(0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (isClinica) ...[
                        _aspectItem(
                          icon: Icons.accessibility_new_rounded,
                          title: "Inflamación articular",
                          desc:
                              "Frecuente presencia de inflamación y sensibilidad.",
                        ),
                        const SizedBox(height: 12),
                        _aspectItem(
                          icon: Icons.person_search_rounded,
                          title: "Dolor y rigidez",
                          desc:
                              "Puede generar rigidez, especialmente matutina.",
                        ),
                        const SizedBox(height: 12),
                        _aspectItem(
                          icon: Icons.fact_check_outlined,
                          title: "Seguimiento clínico",
                          desc:
                              "Requiere evaluación periódica y ajuste terapéutico.",
                        ),
                      ] else ...[
                        _aspectItem(
                          icon: Icons.set_meal_outlined,
                          title: "Malestar digestivo",
                          desc:
                              "Puede presentarse acidez, ardor o retorno del contenido gástrico.",
                        ),
                        const SizedBox(height: 12),
                        _aspectItem(
                          icon: Icons.calendar_today_outlined,
                          title: "Duración temporal",
                          desc:
                              "Generalmente de corta duración. Se sugiere seguimiento breve.",
                        ),
                        const SizedBox(height: 12),
                        _aspectItem(
                          icon: Icons.verified_user_outlined,
                          title: "Cuidados y recomendaciones",
                          desc:
                              "Evitar alimentos grasosos, irritantes y muy abundantes. Seguir indicaciones médicas.",
                        ),
                      ],
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
                    "CERRAR EXPEDIENTE",
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
        color: color.withOpacity(0.06),
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
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child:
              Icon(icon, color: AppTema.azulOscuro.withOpacity(0.7), size: 20),
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
  final _duracionCtrl = TextEditingController();
  int _idTipo = 1;
  bool _activa = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.condicion != null) {
      _nombreCtrl.text = widget.condicion!["nombre"] ?? "";
      _descCtrl.text = widget.condicion!["descripcion"] ?? "";
      _duracionCtrl.text =
          widget.condicion!["duracion_dias_sugerida"]?.toString() ?? "";
      _idTipo = widget.condicion!["id_tipo"] ??
          widget.condicion!["id_tipo_condicion"] ??
          1;
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
              Text(isEdit ? "Modificar Registro" : "Alta de Nueva Condición",
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
                  _typeOption(1, "CLÍNICA", Icons.health_and_safety_rounded,
                      "Diagnóstico crónico"),
                  const SizedBox(width: 12),
                  _typeOption(2, "TEMPORAL", Icons.shutter_speed_rounded,
                      "Evento agudo"),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle("INFORMACIÓN GENERAL"),
              _minimalInput(
                  _nombreCtrl, "Nombre oficial", Icons.badge_outlined),
              if (_idTipo == 2) ...[
                const SizedBox(height: 12),
                _minimalInput(
                    _duracionCtrl, "Días sugeridos", Icons.av_timer_rounded,
                    isNum: true),
              ],
              const SizedBox(height: 24),
              _sectionTitle("DETALLE CLÍNICO"),
              _minimalInput(_descCtrl, "Descripción o criterios médicos...",
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
        "id_tipo": _idTipo,
        "activa": _activa,
        "duracion_dias_sugerida":
            (_idTipo == 2 && _duracionCtrl.text.isNotEmpty)
                ? int.tryParse(_duracionCtrl.text)
                : null,
      };

      if (widget.condicion != null) {
        await dio.put("catalogos/condiciones/${widget.condicion!['id']}",
            data: payload);
      } else {
        await dio.post("catalogos/condiciones", data: payload);
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
