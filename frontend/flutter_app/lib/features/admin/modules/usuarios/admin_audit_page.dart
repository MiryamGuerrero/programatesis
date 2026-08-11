import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";

import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "admin_audit_notifier.dart";

class AdminAuditPage extends ConsumerStatefulWidget {
  const AdminAuditPage({super.key});

  @override
  ConsumerState<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends ConsumerState<AdminAuditPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminAuditProvider.notifier).loadPage(offset: 0);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(adminAuditProvider.notifier).setQuery(val);
    });
  }

  void _limpiarFiltros() {
    _searchController.clear();
    ref.read(adminAuditProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAuditProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildToolbar(state),
            const SizedBox(height: 24),
            _buildFilterCards(state),
            const SizedBox(height: 24),
            _buildTable(state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Auditoría de Atenciones Médicas",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(
            "Registro histórico global de atenciones y controles clínicos de pacientes del centro.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildToolbar(AdminAuditState state) {
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
                hintText: "Buscar por paciente o especialista...",
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => ref.read(adminAuditProvider.notifier).loadPage(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTema.azulPrincipal,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text("Refrescar", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCards(AdminAuditState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                color: AppTema.azulPrincipal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Filtros de Auditoría",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTema.azulPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección 1: Filtrar por estado del especialista
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Filtrar por estado del especialista",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _filterCard(
                          "Todos",
                          state.selectedActivo == null,
                          () => ref.read(adminAuditProvider.notifier).setActivoFilter(null),
                          icon: Icons.all_inclusive_rounded,
                        ),
                        _filterCard(
                          "Activos",
                          state.selectedActivo == true,
                          () => ref.read(adminAuditProvider.notifier).setActivoFilter(true),
                          icon: Icons.check_circle_rounded,
                        ),
                        _filterCard(
                          "Inactivos/Borrados",
                          state.selectedActivo == false,
                          () => ref.read(adminAuditProvider.notifier).setActivoFilter(false),
                          icon: Icons.cancel_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Separador vertical
              const SizedBox(width: 24),
              Container(
                width: 1,
                height: 90,
                color: const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 24),

              // Sección 2: Filtrar por brote
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Filtrar por brote de inflamación",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _filterCard(
                          "Todos",
                          state.selectedBrote == null,
                          () => ref.read(adminAuditProvider.notifier).setBroteFilter(null),
                          icon: Icons.all_inclusive_rounded,
                        ),
                        _filterCard(
                          "Con brote",
                          state.selectedBrote == true,
                          () => ref.read(adminAuditProvider.notifier).setBroteFilter(true),
                          icon: Icons.error_outline_rounded,
                        ),
                        _filterCard(
                          "Sin brote",
                          state.selectedBrote == false,
                          () => ref.read(adminAuditProvider.notifier).setBroteFilter(false),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.activeFilters) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _limpiarFiltros,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTema.azulPrincipal,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text("Limpiar filtros"),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterCard(String label, bool isSelected, VoidCallback onTap, {required IconData icon}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTema.pastelCeleste : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTema.azulPrincipal : const Color(0xFFE5EAF2),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTema.azulPrincipal.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTema.azulPrincipal : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTema.azulOscuro : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(AdminAuditState state) {
    if (!state.isLoading && state.controls.isEmpty) {
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
              "No se encontraron registros de controles",
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
        final currentRowsPerPage = state.controls.isEmpty
            ? 5
            : (state.controls.length < AdminAuditNotifier.pageSize
                ? state.controls.length
                : AdminAuditNotifier.pageSize);

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
                ref.read(adminAuditProvider.notifier).loadPage(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 70,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("FECHA", width: usableWidth * 0.15),
              _col("PACIENTE", width: usableWidth * 0.25),
              _col("ESPECIALISTA", width: usableWidth * 0.30),
              _col("ESTADO", width: usableWidth * 0.20, center: true),
              _col("ACCIONES", width: usableWidth * 0.10, center: true),
            ],
            source: _AdminAuditDataSource(
              items: state.controls,
              totalRows: state.totalItems,
              offset: state.offset,
              isLoading: state.isLoading,
              onView: (ctrl) => _mostrarDetalleControl(ctrl),
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
                fontSize: 12,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleControl(Map<String, dynamic> ctrl) {
    final dateStr = ctrl['fecha_control'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(ctrl['fecha_control']))
        : '-';

    final String? name = ctrl['especialista_nombre'];
    final String? rol = ctrl['especialista_rol'];
    final bool isActive = ctrl['especialista_activo'] != false;
    final String specialistInfo = name != null
        ? "$name${rol != null ? ' ($rol)' : ''}${isActive ? '' : ' - Inactivo/Borrado'}"
        : "Sin Especialista";

    showDialog(
      context: context,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 850,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTema.pastelCeleste,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.assignment_turned_in_outlined,
                              color: AppTema.azulPrincipal, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Auditoría del Control",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  color: AppTema.azulOscuro,
                                  fontSize: 18),
                            ),
                            Text(
                              "Fecha: $dateStr",
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.blueGrey),
                      onPressed: () => Navigator.pop(ctx),
                      splashRadius: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 24),
                
                // Diseño Horizontal (2 columnas)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda (Información General y Evolución)
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoTile("Paciente", ctrl['paciente_nombre'] ?? '-', Icons.person_outline),
                          const SizedBox(height: 12),
                          _infoTile("Especialista que Atendió", specialistInfo, Icons.medical_services_outlined),
                          const SizedBox(height: 24),
                          
                          Text("Nota de Evolución",
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.format_quote_rounded, color: Color(0xFFCBD5E1), size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    ctrl['nota_evolucion']?.toString() ?? "Sin observaciones registradas en esta sesión.",
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        height: 1.5,
                                        color: AppTema.azulOscuro,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 32),
                    
                    // Columna Derecha (Métricas Clínicas con Tarjetas Premium)
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Métricas Clínicas",
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTema.azulOscuro)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _metricCard("Peso", "${ctrl['peso_kg'] ?? '-'} kg", Icons.monitor_weight_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _metricCard("Talla", "${ctrl['talla_cm'] ?? '-'} cm", Icons.height_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _metricCard("IMC", "${ctrl['imc_calculado'] ?? '-'}", Icons.calculate_outlined),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _metricCard("Puntos de Dolor", "${ctrl['puntos_dolor'] ?? '-'} / 10", Icons.sick_outlined, isAlert: (ctrl['puntos_dolor'] ?? 0) > 6),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _metricCard("Fatiga", "${ctrl['nivel_fatiga'] ?? '-'} / 10", Icons.battery_alert_outlined),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _metricCard("Inflamación", "${ctrl['escala_inflamacion'] ?? '-'} / 3", Icons.local_fire_department_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _metricCard("Brote Activo", ctrl['en_brote'] == true ? "SÍ" : "NO", Icons.warning_amber_rounded, isHighlight: ctrl['en_brote'] == true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTema.azulPrincipal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      "Cerrar Auditoría",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTema.azulOscuro)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, {bool isHighlight = false, bool isAlert = false}) {
    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE2E8F0);
    Color iconColor = AppTema.azulPrincipal;
    Color valueColor = AppTema.azulOscuro;

    if (isHighlight) {
      bgColor = AppTema.verdeSalud.withValues(alpha: 0.08);
      borderColor = AppTema.verdeSalud.withValues(alpha: 0.3);
      iconColor = AppTema.verdeSalud;
      valueColor = AppTema.verdeSalud;
    } else if (isAlert) {
      bgColor = Colors.redAccent.withValues(alpha: 0.05);
      borderColor = Colors.redAccent.withValues(alpha: 0.3);
      iconColor = Colors.redAccent;
      valueColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAuditDataSource extends DataTableSource {
  final List<Map<String, dynamic>> items;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Function(Map<String, dynamic>) onView;
  final double totalWidth;
  final BuildContext context;

  _AdminAuditDataSource({
    required this.items,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.onView,
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
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: NutriShimmer(width: 60, height: 12),
              ))),
          DataCell(SizedBox(
              width: totalWidth * 0.25,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: NutriShimmer(width: 120, height: 12),
              ))),
          DataCell(SizedBox(
              width: totalWidth * 0.30,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: NutriShimmer(width: 150, height: 12),
              ))),
          DataCell(SizedBox(
              width: totalWidth * 0.20,
              child: const Center(child: NutriShimmer(width: 70, height: 20)))),
          DataCell(SizedBox(
              width: totalWidth * 0.10,
              child: const Center(child: NutriShimmer(width: 40, height: 24)))),
        ],
      );
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= items.length) return null;
    final ctrl = items[localIndex];

    final dateStr = ctrl['fecha_control'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(ctrl['fecha_control']))
        : '-';

    final bool isActive = ctrl['especialista_activo'] != false;

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
        DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(dateStr,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500, fontSize: 13, color: AppTema.azulOscuro)),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.25,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(ctrl['paciente_nombre'] ?? '-',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTema.azulPrincipal)),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _buildSpecialistCell(ctrl),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.20,
          child: Center(
            child: _StatusBadge(isActive: isActive),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.10,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _HoverActionButton(
                icon: Icons.visibility_outlined,
                label: "Detalles",
                color: AppTema.azulPrincipal,
                onTap: () => onView(ctrl),
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildSpecialistCell(Map<String, dynamic> ctrl) {
    final String? name = ctrl['especialista_nombre'];
    final String? rol = ctrl['especialista_rol'];

    if (name == null) {
      return Text("-", style: GoogleFonts.inter(color: Colors.grey));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 13, color: AppTema.azulOscuro)),
        if (rol != null)
          Text(rol,
              style: GoogleFonts.inter(
                  color: Colors.blueGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => totalRows;

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Text(
        isActive ? "ACTIVO" : "INACTIVO",
        style: GoogleFonts.inter(
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
    return InkWell(
      onHover: (hovered) {
        setState(() {
          _isHovered = hovered;
        });
      },
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
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.color)),
          ],
        ),
      ),
    );
  }
}
