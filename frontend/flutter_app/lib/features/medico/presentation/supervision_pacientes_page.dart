import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";
import "../../../core/state/app_providers.dart";
import "../data/repositorio_medico.dart";
import "../data/supervision_provider.dart";
import "registro_paciente_page.dart";
import "registro_mensual_page.dart";

class SupervisionPacientesPage extends ConsumerWidget {
  const SupervisionPacientesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(medicoNavProvider);
    final selectedPatient = ref.watch(selectedPatientProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildBody(currentView, selectedPatient),
    );
  }

  Widget _buildBody(MedicoView view, Map<String, dynamic>? patient) {
    switch (view) {
      case MedicoView.register:
        return RegistroPacientePage(key: ValueKey(patient?['id'] ?? 'new'), initialData: patient);
      case MedicoView.fixedEdit:
        return RegistroPacientePage(key: ValueKey('fixed_${patient?['id']}'), initialData: patient, fixedOnly: true);
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
  ConsumerState<_ListaPacientesView> createState() => _ListaPacientesViewState();
}

class _ListaPacientesViewState extends ConsumerState<_ListaPacientesView> {
  String _searchQuery = "";
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  bool _archiving = false;
  bool _archiveSuccess = false;

  String _formatName(String fullName) {
    if (fullName.isEmpty) return "-";
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      return "${parts[0]} ${parts[parts.length > 2 ? 2 : 1]}";
    } else if (parts.length == 2) {
      return "${parts[0]} ${parts[1]}";
    }
    return fullName;
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(medicoPatientsProvider);

    return Scaffold(
      backgroundColor: AppTema.grisFondo,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatsRow(patientsAsync.valueOrNull ?? []),
                const SizedBox(height: 24),
                _buildSearchBarAndAddButton(),
                const SizedBox(height: 16),
                _buildPatientsTable(patientsAsync),
              ],
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
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 5),
                )
              else
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4ADE80), size: 86),
              const SizedBox(height: 24),
              Text(
                _archiveSuccess ? "Paciente archivado" : "Archivando paciente...",
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
          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text("Registre pacientes, actualice expedientes clínicos y controle la evolución mensual bajo estándares OMS.", 
          style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsRow(List<Map<String, dynamic>> patients) {
    final int total = patients.length;
    final int brotes = patients.where((p) {
      final s = p['severidad'].toString().toLowerCase();
      return p['brote_activo'] == true || s.contains("brote") || s.contains("grave");
    }).length;
    
    final Map<String, int> counts = {};
    for (var p in patients) {
      final name = p['enfermedad_principal'] ?? "OTRA";
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final principal = sorted.isNotEmpty ? sorted.first.key : "N/A";

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 20.0;
        return Row(
          children: [
            Expanded(
              child: _KPICard(
                title: "Pacientes activos",
                value: "$total",
                color: AppTema.azulPrincipal,
                imagePath: "assets/images/kpi_total.png",
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: _KPICard(
                title: "Con brote activo",
                value: "$brotes",
                color: Colors.red,
                icon: Icons.notifications_none_rounded,
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: _KPICard(
                title: "Patología más frecuente",
                value: principal,
                color: const Color(0xFF10B981),
                imagePath: "assets/images/kpi_joint.png",
                isLargeValue: true,
              ),
            ),
          ],
        );
      },
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
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar por nombre o cédula del paciente...",
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
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
            onPressed: () {
              ref.read(selectedPatientProvider.notifier).state = null;
              ref.read(medicoNavProvider.notifier).state = MedicoView.register;
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTema.verdeSalud,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.add_circle, size: 20, color: Colors.white),
            label: Text("Registrar paciente", 
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientsTable(AsyncValue<List<Map<String, dynamic>>> patientsAsync) {
    return patientsAsync.when(
      data: (patients) {
        final filtered = patients.where((p) {
          final term = _searchQuery.toLowerCase();
          return p["nombre_completo"].toString().toLowerCase().contains(term) ||
                 p["cedula"].toString().toLowerCase().contains(term);
        }).toList();

        if (filtered.isEmpty) return const NutriTableContainer(child: Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No se encontraron pacientes activos."))));

        final totalItems = filtered.length;
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex = startIndex + _itemsPerPage > totalItems ? totalItems : startIndex + _itemsPerPage;
        final currentItems = filtered.sublist(startIndex, endIndex);

        return Column(
          children: [
            NutriTableContainer(
              child: Column(
                children: [
                  _buildTableHead(),
                  ...currentItems.map((p) => _buildTableRow(p)),
                ],
              ),
            ),
            if (totalItems > 0) ...[
              const SizedBox(height: 16),
              _buildPagination(totalItems, startIndex + 1, endIndex),
            ],
          ],
        );
      },
      loading: () => const NutriLoading(mensaje: "Sincronizando expedientes..."),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildTableHead() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: _tableHeaderLabel("Nombre del paciente")),
          Expanded(flex: 2, child: _tableHeaderLabel("Cédula")),
          Expanded(flex: 2, child: _tableHeaderLabel("Enfermedad principal")),
          Expanded(flex: 2, child: _tableHeaderLabel("Severidad actual")),
          Expanded(flex: 1, child: _tableHeaderLabel("Edad")),
          Expanded(flex: 2, child: _tableHeaderLabel("Último registro")),
          Expanded(flex: 5, child: Center(child: _tableHeaderLabel("Acciones"))),
        ],
      ),
    );
  }

  Widget _tableHeaderLabel(String label) {
    return Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: AppTema.azulOscuro));
  }

  Widget _buildTableRow(Map<String, dynamic> p) {
    final bool isSelected = ref.watch(selectedPatientProvider)?['id'] == p['id'];

    return InkWell(
      onTap: () => ref.read(selectedPatientProvider.notifier).state = p,
      hoverColor: AppTema.azulPrincipal.withValues(alpha: 0.02),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTema.azulPrincipal.withValues(alpha: 0.08) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100),
            left: BorderSide(color: isSelected ? AppTema.azulPrincipal : Colors.transparent, width: 4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _buildAvatar(p["nombre_completo"]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatName(p["nombre_completo"] ?? ""), 
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(p["cedula"]?.toString() ?? "-", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500))),
            Expanded(flex: 2, child: Text(p["enfermedad_principal"]?.toString() ?? "-", style: GoogleFonts.inter(fontSize: 11, color: AppTema.azulPrincipal, fontWeight: FontWeight.w600))),
            Expanded(flex: 2, child: _buildSeverityBadge(p["severidad"])),
            Expanded(flex: 1, child: Text("${p["edad_anios"] ?? 0} años", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500))),
            Expanded(flex: 2, child: Text(_formatDate(p["ultimo_registro"]), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700))),
            Expanded(
              flex: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionButton(
                    icon: Icons.calendar_month_outlined, 
                    label: "Registro mensual", 
                    color: AppTema.azulPrincipal,
                    onTap: () {
                      ref.read(selectedPatientProvider.notifier).state = p;
                      ref.read(medicoNavProvider.notifier).state = MedicoView.control;
                    }
                  ),
                  const SizedBox(width: 16),
                  _actionButton(
                    icon: Icons.edit_outlined, 
                    label: "Editar expediente", 
                    color: Colors.orange,
                    onTap: () {
                      ref.read(selectedPatientProvider.notifier).state = p;
                      ref.read(medicoNavProvider.notifier).state = MedicoView.fixedEdit;
                    }
                  ),
                  const SizedBox(width: 16),
                  _actionButton(
                    icon: Icons.archive_outlined, 
                    label: "Archivar", 
                    color: Colors.red,
                    onTap: () => _confirmarArchivarPaciente(p)
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        child: Text(initials, style: GoogleFonts.inter(color: AppTema.azulPrincipal, fontWeight: FontWeight.w800, fontSize: 11)),
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
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return _HoverActionButton(icon: icon, label: label, color: color, onTap: onTap);
  }

  String _formatDate(dynamic raw) {
    final text = raw?.toString();
    if (text == null || text.isEmpty) return "Sin registro";
    try {
      final date = DateTime.parse(text);
      final day = date.day.toString().padLeft(2, "0");
      final month = date.month.toString().padLeft(2, "0");
      return "$day/$month/${date.year}";
    } catch (_) {
      return text.length >= 10 ? text.substring(0, 10) : text;
    }
  }

  Widget _buildPagination(int total, int start, int end) {
    final totalPages = (total / _itemsPerPage).ceil();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Mostrando $start a $end de $total pacientes", 
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        Row(
          children: [
            _pageButton(Icons.chevron_left, _currentPage > 1 ? () => setState(() => _currentPage--) : null),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTema.azulPrincipal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text("$_currentPage", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            _pageButton(Icons.chevron_right, _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
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
        child: Icon(icon, size: 20, color: onTap == null ? Colors.grey.shade300 : Colors.black),
      ),
    );
  }

  Future<void> _confirmarArchivarPaciente(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Archivar paciente", style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          "El paciente ${p['nombre_completo'] ?? ''} dejará de aparecer en la gestión activa. Su expediente e historial clínico se conservan.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
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
      await ref.read(repositorioMedicoProvider).archivarPaciente(p["id"].toString());
      ref.invalidate(medicoPatientsProvider);
      if (!mounted) return;
      setState(() => _archiveSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1200));
    } catch (e) {
      if (mounted) NutriSnack.show(context, "Error al archivar", isError: true, ref: ref);
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

class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HoverActionButton({required this.icon, required this.label, required this.color, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isHovered ? widget.color.withValues(alpha: 0.2) : Colors.transparent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.color, size: 20),
              const SizedBox(height: 4),
              Text(widget.label, 
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: widget.color, height: 1.0)),
            ],
          ),
        ),
      ),
    );
  }
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Center(
              child: imagePath != null 
                ? Image.asset(imagePath!, width: 42, height: 42, fit: BoxFit.contain)
                : Icon(icon, size: 36, color: color),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, 
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                ),
                const SizedBox(height: 4),
                Text(value, 
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
