import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "package:supabase_flutter/supabase_flutter.dart";
import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";
import "../../../shared/widgets/shimmer_components.dart";
import "../data/repositorio_medico.dart";
import "../data/supervision_provider.dart";
import "_shared/medico_nav_providers.dart";
import "registro_paciente_page.dart";
import "actualizar_paciente_page.dart";
import "registro_mensual_page.dart";

class SupervisionPacientesPage extends ConsumerWidget {
  const SupervisionPacientesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(medicoNavProvider);
    final currentView = navState.currentView;
    final selectedPatient = navState.selectedPatient;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildBody(currentView, selectedPatient),
    );
  }

  Widget _buildBody(MedicoView view, Map<String, dynamic>? patient) {
    switch (view) {
      case MedicoView.register:
        return RegistroPacientePage(
            key: ValueKey(patient?['id'] ?? 'new'), initialData: patient);
      case MedicoView.fixedEdit:
        return ActualizarPacientePage(
            key: ValueKey('fixed_'),
            initialData: patient);
      case MedicoView.control:
        if (patient == null) return const _ListaPacientesView();
        return RegistroMensualPage(paciente: patient);
      case MedicoView.list:
        return const _ListaPacientesView();
    }
  }
}

class _ListaPacientesView extends ConsumerStatefulWidget {
  const _ListaPacientesView();
  @override
  ConsumerState<_ListaPacientesView> createState() =>
      _ListaPacientesViewState();
}

class _ListaPacientesViewState extends ConsumerState<_ListaPacientesView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _archiving = false;
  bool _archiveSuccess = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(medicalPatientsProvider.notifier).loadPage();
      _setupRealtime();
    });
  }

  void _setupRealtime() {
    try {
      final supabase = ref.read(supabaseClientProvider);
      _realtimeChannel = supabase
          .channel('medico_pacientes_rt_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'usuarios',
            table: 'paciente',
            callback: (_) {
              ref.read(medicalPatientsProvider.notifier).loadPageSilently();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'clinico',
            table: 'control_paciente',
            callback: (_) {
              ref.read(medicalPatientsProvider.notifier).loadPageSilently();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'interaccion',
            table: 'plan_nutricional',
            callback: (_) {
              ref.read(medicalPatientsProvider.notifier).loadPageSilently();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _limpiarFiltros() {
    _searchController.clear();
    ref.read(medicalPatientsProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(medicalPatientsProvider);

    return Scaffold(
      backgroundColor: AppTema.grisFondo,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(medicalPatientsProvider.notifier).loadPage();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildStatsRow(state),
                  const SizedBox(height: 24),
                  _buildSearchBarAndAddButton(state),
                  const SizedBox(height: 16),
                  _buildPatientsTable(state),
                ],
              ),
            ),
          ),
          if (_archiving) _buildArchivingOverlay(),
        ],
      ),
    );
  }

  Widget _buildArchivingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_archiveSuccess)
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 5),
                )
              else
                const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF4ADE80), size: 86),
              const SizedBox(height: 24),
              Text(
                _archiveSuccess
                    ? "Paciente archivado"
                    : "Archivando paciente...",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
        Text("Gestión de pacientes",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Registre pacientes, actualice expedientes clínicos y controle la evolución mensual bajo estándares OMS.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsRow(MedicalPatientsState state) {
    if (state.isLoading && state.patients.isEmpty) {
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

    final total = state.totalItems;
    final brotes = state.patients.where((p) {
      final s = p['severidad']?.toString().toLowerCase() ?? "";
      return p['brote_activo'] == true ||
          s.contains("brote") ||
          s.contains("grave");
    }).length;

    return Row(
      children: [
        Expanded(
          child: _KPICard(
            title: "Pacientes activos",
            value: "$total",
            color: AppTema.azulPrincipal,
            imagePath: "assets/images/kpi_total.webp",
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _KPICard(
            title: "Con brote activo",
            value: "$brotes",
            color: Colors.red,
            icon: Icons.notifications_none_rounded,
          ),
        ),
        const SizedBox(width: 20),
        const Expanded(
          child: _KPICard(
            title: "Control clínico",
            value: "Activo",
            color: Color(0xFF10B981),
            imagePath: "assets/images/kpi_joint.webp",
            isLargeValue: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBarAndAddButton(MedicalPatientsState state) {
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
              style:
                  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar por nombre o cédula del paciente...",
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
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  ref.read(medicalPatientsProvider.notifier).setSearchQuery(v);
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        if (state.activeFilters) ...[
          IconButton(
            onPressed: _limpiarFiltros,
            icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.grey),
            tooltip: "Limpiar filtros",
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () {
              ref.read(medicoNavProvider.notifier).setView(MedicoView.register, clearPatient: true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTema.verdeSalud,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: Text("Registrar paciente",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientsTable(MedicalPatientsState state) {
    if (!state.isLoading && state.patients.isEmpty) {
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
              "No se encontraron pacientes",
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
        final currentRowsPerPage = state.patients.isEmpty
            ? 5
            : (state.patients.length < MedicalPatientsNotifier.pageSize
                ? state.patients.length
                : MedicalPatientsNotifier.pageSize);

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
                ref.read(medicalPatientsProvider.notifier).loadPage(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 70,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("PACIENTE", width: usableWidth * 0.30),
              _col("CÉDULA", width: usableWidth * 0.15),
              _col("ENFERMEDAD", width: usableWidth * 0.20),
              _col("ESTADO", width: usableWidth * 0.15, center: true),
              _col("ACCIONES", width: usableWidth * 0.20, center: true),
            ],
            source: _MedicalPatientsDataSource(
              items: state.patients,
              totalRows: state.totalItems,
              offset: state.offset,
              isLoading: state.isLoading,
              onControl: (p) {
                ref.read(medicoNavProvider.notifier).setView(MedicoView.control, patient: p);
              },
              onEdit: (p) {
                ref.read(medicoNavProvider.notifier).setView(MedicoView.fixedEdit, patient: p);
              },
              onArchive: (p) => _confirmarArchivarPaciente(p),
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

  Future<void> _confirmarArchivarPaciente(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Archivar paciente",
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          "El paciente ${p['nombre_completo'] ?? ''} dejará de aparecer en la gestión activa. Su expediente e historial clínico se conservan.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text("Archivar"),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (confirm == true) await _archivarPaciente(p);
  }

  Future<void> _archivarPaciente(Map<String, dynamic> p) async {
    if (_archiving) return;
    setState(() {
      _archiving = true;
      _archiveSuccess = false;
    });

    try {
      await ref
          .read(repositorioMedicoProvider)
          .archivarPaciente(p["id"].toString());
      await ref.read(medicalPatientsProvider.notifier).loadPage();
      if (!mounted) return;
      setState(() => _archiveSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1200));
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al archivar", isError: true, ref: ref);
      }
    } finally {
      if (mounted) {
        setState(() {
          _archiving = false;
          _archiveSuccess = false;
        });
      }
    }
  }
}

class _MedicalPatientsDataSource extends DataTableSource {
  final List<Map<String, dynamic>> items;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Function(Map<String, dynamic>) onControl;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onArchive;
  final double totalWidth;
  final BuildContext context;

  _MedicalPatientsDataSource({
    required this.items,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.onControl,
    required this.onEdit,
    required this.onArchive,
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
          width: totalWidth * 0.30,
          child: Row(
            children: [
              const NutriShimmer(
                  width: 32,
                  height: 32,
                  borderRadius: BorderRadius.all(Radius.circular(16))),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NutriShimmer(width: 120, height: 12),
                  const SizedBox(height: 4),
                  NutriShimmer(
                      width: 150,
                      height: 10,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ],
          ),
        )),
        DataCell(SizedBox(
            width: totalWidth * 0.15,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 80, height: 10)))),
        DataCell(SizedBox(
            width: totalWidth * 0.20,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 100, height: 10)))),
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
      ]);
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= items.length) return null;
    final p = items[localIndex];

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
      DataCell(SizedBox(
        width: totalWidth * 0.30,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12),
          child: Row(
            children: [
              _buildAvatar(p["nombre_completo"]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(p["nombre_completo"] ?? "Sin nombre",
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppTema.azulOscuro)),
                        ),
                        if (p["tiene_tutor"] == false) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: "Sin tutor asignado",
                            child: Icon(Icons.person_off_rounded,
                                size: 14, color: Colors.red.shade400),
                          )
                        ]
                      ],
                    ),
                    Text("${p["edad_anios"] ?? 0} años",
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.blueGrey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.15,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(p["cedula"]?.toString() ?? "-",
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(p["enfermedad_principal"]?.toString() ?? "-",
              softWrap: true,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTema.azulPrincipal,
                  fontWeight: FontWeight.w600)),
        ),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.15,
        child: Center(child: _buildSeverityBadge(p["severidad"])),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.20,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HoverActionButton(
                  icon: Icons.calendar_month_outlined,
                  label: "Control",
                  color: AppTema.azulPrincipal,
                  onTap: () => onControl(p)),
              const SizedBox(width: 12),
              _HoverActionButton(
                  icon: Icons.edit_note_rounded,
                  label: "Editar",
                  color: Colors.orange,
                  onTap: () => onEdit(p)),
              const SizedBox(width: 12),
              _HoverActionButton(
                  icon: Icons.archive_outlined,
                  label: "Archivar",
                  color: Colors.redAccent,
                  onTap: () => onArchive(p)),
            ],
          ),
        ),
      )),
    ]);
  }

  Widget _buildAvatar(String? name) {
    final initials = name != null && name.isNotEmpty
        ? name.trim().split(' ').take(2).map((e) => e[0].toUpperCase()).join()
        : "P";
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTema.azulPrincipal.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initials,
            style: GoogleFonts.inter(
                color: AppTema.azulPrincipal,
                fontWeight: FontWeight.w800,
                fontSize: 11)),
      ),
    );
  }

  Widget _buildSeverityBadge(dynamic sev) {
    final s = sev?.toString().toLowerCase() ?? "";
    IconData icon = Icons.remove_circle_outline;
    Color color = Colors.orange;
    String label = "Moderada";

    if (s.contains("alta") || s.contains("brote") || s.contains("grave")) {
      icon = Icons.warning_amber_rounded;
      color = Colors.red;
      label = "Grave";
    } else if (s.contains("moderada")) {
      icon = Icons.remove_circle_outline;
      color = Colors.orange;
      label = "Moderada";
    } else {
      icon = Icons.check_circle_outline;
      color = Colors.green;
      label = "Estable";
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
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

class _KPICard extends StatelessWidget {
  const _KPICard({
    required this.title,
    required this.value,
    required this.color,
    this.icon,
    this.imagePath,
    this.isLargeValue = false,
  });

  final String title;
  final String value;
  final Color color;
  final IconData? icon;
  final String? imagePath;
  final bool isLargeValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Center(
              child: imagePath != null
                  ? Image.asset(imagePath!,
                      width: 42, height: 42, fit: BoxFit.contain)
                  : Icon(icon, size: 36, color: color),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: isLargeValue ? 14 : 24,
                    fontWeight: FontWeight.w800,
                    color: AppTema.azulOscuro,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                    height: 1.0)),
          ],
        ),
      ),
    );
  }
}
