import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/nutri_avatar.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "admin_users_notifier.dart";

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});
  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminUsersProvider.notifier).loadPage();
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
    ref.read(adminUsersProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersProvider);
    final rolesAsync = ref.watch(rolesStaffProvider);

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
            _buildRolesFilter(rolesAsync, state),
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
            Text("Gestión del equipo médico",
                style: GoogleFonts.montserrat(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTema.azulPrincipal,
                    letterSpacing: -0.5)),
            Text(
                "Control institucional de accesos y perfiles profesionales del centro.",
                style: GoogleFonts.montserrat(
                    color: Colors.blueGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        FilledButton.icon(
          onPressed: () => _dialogoUsuario(null),
          style: FilledButton.styleFrom(
            backgroundColor: AppTema.verdeSalud,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: Text("Nuevo miembro",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildStatsRow(AdminUsersState state) {
    if (state.isLoading && state.users.isEmpty) {
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
            titulo: 'ADMINISTRADORES',
            valor: '${state.roleCounts[1] ?? 0}',
            icon: Icons.admin_panel_settings_rounded,
            colorValor: AppTema.azulOscuro,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: NutriResumenCard(
            titulo: 'MEDICOS',
            valor: '${state.roleCounts[2] ?? 0}',
            icon: Icons.medical_services_rounded,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: NutriResumenCard(
            titulo: 'NUTRIOLOGOS',
            valor: '${state.roleCounts[3] ?? 0}',
            icon: Icons.restaurant_menu_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(AdminUsersState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          Expanded(
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
                  _searchDebounce =
                      Timer(const Duration(milliseconds: 350), () {
                    ref.read(adminUsersProvider.notifier).setSearchQuery(v);
                  });
                },
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Buscar por nombre de profesional...",
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppTema.azulPrincipal),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
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
                "Limpiar",
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
            onPressed: () => ref.read(adminUsersProvider.notifier).loadPage(),
            tooltip: "Actualizar lista",
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

  Widget _buildRolesFilter(AsyncValue<List<Map<String, dynamic>>> rolesAsync,
      AdminUsersState state) {
    return rolesAsync.maybeWhen(
      data: (roles) => Row(
        children: [
          Text("Filtrar por rol:",
              style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.blueGrey,
                  letterSpacing: 1)),
          const SizedBox(width: 16),
          _filterChip("Todos", state.selectedRolIds.isEmpty,
              () => ref.read(adminUsersProvider.notifier).clearFilters()),
          const SizedBox(width: 12),
          ...roles.map((r) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _filterChip(
                    r["nombre"].toString(),
                    state.selectedRolIds.contains(r["id"]),
                    () => ref
                        .read(adminUsersProvider.notifier)
                        .toggleRol(r["id"])),
              )),
        ],
      ),
      orElse: () => const SizedBox.shrink(),
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

  Widget _buildTable(AdminUsersState state) {
    if (!state.isLoading && state.users.isEmpty) {
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
              "No se encontraron profesionales de salud",
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
        final currentRowsPerPage = state.users.isEmpty
            ? 5
            : (state.users.length < AdminUsersNotifier.pageSize
                ? state.users.length
                : AdminUsersNotifier.pageSize);

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
                ref.read(adminUsersProvider.notifier).loadPage(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 70,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("PROFESIONAL", width: usableWidth * 0.35),
              _col("ROL / CARGO", width: usableWidth * 0.25),
              _col("ESTADO", width: usableWidth * 0.15, center: true),
              _col("ACCIONES", width: usableWidth * 0.25, center: true),
            ],
            source: _AdminUsersDataSource(
              items: state.users,
              totalRows: state.totalItems,
              offset: state.offset,
              isLoading: state.isLoading,
              onEdit: _dialogoUsuario,
              onToggle: (u) => ref
                  .read(adminUsersProvider.notifier)
                  .toggleUserStatus(u["id"].toString(), u["activo"] == true),
              onDelete: (u) => _eliminarUsuario(u),
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

  Future<void> _eliminarUsuario(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Eliminar acceso"),
        content: Text(
            "¿Estás seguro de eliminar a ${user['nombre_completo']}? Esta acción revocará todos los accesos al sistema."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("Eliminar")),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(adminUsersProvider.notifier)
          .deleteUser(user["id"].toString());
      if (mounted) {
        NutriSnack.show(context, "Profesional eliminado con éxito");
      }
    }
  }

  void _dialogoUsuario(Map<String, dynamic>? user) {
    showDialog(
      context: context,
      builder: (ctx) => _FormularioUsuario(
        user: user,
        onSuccess: () => ref.read(adminUsersProvider.notifier).loadPage(),
      ),
    );
  }
}

class _AdminUsersDataSource extends DataTableSource {
  final List<Map<String, dynamic>> items;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onToggle;
  final Function(Map<String, dynamic>) onDelete;
  final double totalWidth;
  final BuildContext context;

  _AdminUsersDataSource({
    required this.items,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.onEdit,
    required this.onToggle,
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
          width: totalWidth * 0.35,
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
                      width: 180,
                      height: 10,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ],
          ),
        )),
        DataCell(SizedBox(
            width: totalWidth * 0.25,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 80, height: 10)))),
        DataCell(SizedBox(
            width: totalWidth * 0.15,
            child: const Center(child: NutriShimmer(width: 60, height: 20)))),
        DataCell(SizedBox(
          width: totalWidth * 0.25,
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
    if (localIndex < 0 || localIndex >= items.length) return null;
    final u = items[localIndex];

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
      DataCell(SizedBox(
        width: totalWidth * 0.35,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12),
          child: Row(
            children: [
              NutriAvatar(
                  nombreCompleto: u["nombre_completo"] ?? "?", radio: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u["nombre_completo"] ?? "Sin nombre",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppTema.azulOscuro)),
                    Text(u["email"] ?? "",
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.blueGrey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.25,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(u["rol_nombre"]?.toString() ?? "Personal",
              style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTema.azulPrincipal)),
        ),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.15,
        child: Center(
          child: _StatusBadge(isActive: u["activo"] == true),
        ),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.25,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HoverActionButton(
                  icon: Icons.edit_note_rounded,
                  label: "Editar",
                  color: Colors.blueGrey,
                  onTap: () => onEdit(u)),
              const SizedBox(width: 12),
              _HoverActionButton(
                  icon: u["activo"] == true
                      ? Icons.block_flipped
                      : Icons.check_circle_outline,
                  label: u["activo"] == true ? "Baja" : "Alta",
                  color: u["activo"] == true ? Colors.orange : Colors.green,
                  onTap: () => onToggle(u)),
              const SizedBox(width: 12),
              _HoverActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: "Borrar",
                  color: Colors.redAccent,
                  onTap: () => onDelete(u)),
            ],
          ),
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

class _FormularioUsuario extends ConsumerStatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onSuccess;
  const _FormularioUsuario({this.user, required this.onSuccess});
  @override
  ConsumerState<_FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends ConsumerState<_FormularioUsuario> {
  final _emailCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  int? _idRol;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _emailCtrl.text = widget.user!["email"] ?? "";
      _nombreCtrl.text = widget.user!["nombre_completo"] ?? "";
      _cedulaCtrl.text = widget.user!["cedula"] ?? "";
      _idRol = widget.user!["id_rol"];
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesStaffProvider);
    final isEdit = widget.user != null;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 356,
        constraints: const BoxConstraints(maxWidth: 356),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EAF2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                color: const Color(0xFF64748B),
                iconSize: 22,
                tooltip: "Cerrar",
                splashRadius: 20,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 2),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppTema.azulPrincipal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isEdit
                      ? "Editar Miembro\ndel Equipo"
                      : "Nuevo Miembro\ndel Equipo",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    color: AppTema.azulOscuro,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isEdit
                      ? "Actualiza los datos de acceso y perfil profesional."
                      : "Al guardar, se enviará una invitación por correo para que configure su contraseña.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8A97AD),
                  ),
                ),
                const SizedBox(height: 24),
                _input(_nombreCtrl, "Nombre completo", Icons.badge_outlined),
                const SizedBox(height: 12),
                _input(_emailCtrl, "Correo electrónico", Icons.mail_outline),
                const SizedBox(height: 12),
                _input(_cedulaCtrl, "Cédula", Icons.person_outline_rounded),
                const SizedBox(height: 12),
                rolesAsync.when(
                  data: (roles) => DropdownButtonFormField<int>(
                    initialValue: _idRol,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    decoration:
                        _inputDecor("Rol asignado", Icons.work_outline_rounded),
                    dropdownColor: Colors.white,
                    items: roles
                        .map((r) => DropdownMenuItem<int>(
                              value: r["id"],
                              child: Text(
                                r["nombre"].toString().toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTema.azulOscuro,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _idRol = v),
                  ),
                  loading: () => const SizedBox(
                    height: 48,
                    child: Center(child: LinearProgressIndicator()),
                  ),
                  error: (_, __) => Text(
                    "Error al cargar roles",
                    style: GoogleFonts.inter(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 44),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTema.azulPrincipal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      child: const Text("Cancelar"),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 128,
                      height: 46,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTema.azulPrincipal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        child: Text(_saving ? "Guardando..." : "Guardar"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTema.azulOscuro,
        ),
        decoration: _inputDecor(hint, icon),
      ),
    );
  }

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF98A2B3),
        ),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE1E7F0), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppTema.azulPrincipal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      );

  Future<void> _save() async {
    if (_nombreCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _idRol == null) {
      NutriSnack.show(context, "Por favor complete los campos obligatorios",
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      if (widget.user != null) {
        await repo.updateUser(
          userId: widget.user!["id"].toString(),
          nombreCompleto: _nombreCtrl.text,
          email: _emailCtrl.text,
          cedula: _cedulaCtrl.text,
          idRol: _idRol,
        );
      } else {
        await repo.createUser(
          email: _emailCtrl.text,
          nombreCompleto: _nombreCtrl.text,
          idRol: _idRol!,
          cedula: _cedulaCtrl.text,
        );
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al guardar: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

final rolesStaffProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final allRoles = await ref
      .watch(supabaseCrudRepositoryProvider)
      .fetchCatalog("usuarios", "rol");
  final allowedRoles = [
    "médico",
    "nutricionista",
    "administrador",
    "médico/a",
    "medico",
    "admin"
  ];
  return allRoles.where((r) {
    final nombre = r["nombre"].toString().toLowerCase();
    return allowedRoles.any((allowed) => nombre.contains(allowed));
  }).toList();
});
