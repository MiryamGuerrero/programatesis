import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/nutri_avatar.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "admin_users_notifier.dart";

class AdminTutorsPage extends ConsumerStatefulWidget {
  const AdminTutorsPage({super.key});
  @override
  ConsumerState<AdminTutorsPage> createState() => _AdminTutorsPageState();
}

class _AdminTutorsPageState extends ConsumerState<AdminTutorsPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminTutorsProvider.notifier).loadPage();
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
    ref.read(adminTutorsProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminTutorsProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión de cuentas de tutores",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Supervisión de accesos para representantes y padres de familia.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
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
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: NutriResumenCard(
            titulo: 'Representantes registrados',
            valor: '${state.totalItems}',
            icon: Icons.family_restroom_rounded,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        const Expanded(
          child: NutriResumenCard(
            titulo: 'Estado del servicio',
            valor: 'Activo',
            icon: Icons.verified_user_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(AdminUsersState state) {
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
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar por nombre o correo de representante...",
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce =
                    Timer(const Duration(milliseconds: 350), () {
                  ref.read(adminTutorsProvider.notifier).setSearchQuery(v);
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => _dialogoTutor(null),
            style: FilledButton.styleFrom(
              backgroundColor: AppTema.verdeSalud,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: Text("Invitar tutor",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.5)),
          ),
        ),
      ],
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
              "No se encontraron representantes",
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
                ref.read(adminTutorsProvider.notifier).loadPage(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 70,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("REPRESENTANTE", width: usableWidth * 0.35),
              _col("IDENTIFICACIÓN", width: usableWidth * 0.15),
              _col("ESTADO", width: usableWidth * 0.15, center: true),
              _col("ACCIONES", width: usableWidth * 0.35, center: true),
            ],
            source: _AdminTutorsDataSource(
              items: state.users,
              totalRows: state.totalItems,
              offset: state.offset,
              isLoading: state.isLoading,
              onToggle: (u) => ref
                  .read(adminTutorsProvider.notifier)
                  .toggleUserStatus(u["id"].toString(), u["activo"] == true),
              onEdit: (u) => _dialogoTutor(u),
              onDelete: (u) => _eliminarTutor(u),
              onResend: (u) => _reenviarCorreo(u),
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

  Future<void> _eliminarTutor(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Eliminar tutor"),
        content: Text(
            "¿Estás seguro de eliminar a ${user['nombre_completo']}? Esta acción es irreversible."),
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
          .read(adminTutorsProvider.notifier)
          .deleteUser(user["id"].toString());
      if (mounted) {
        NutriSnack.show(context, "Representante eliminado con éxito");
      }
    }
  }

  Future<void> _reenviarCorreo(Map<String, dynamic> user) async {
    final res = await ref.read(adminTutorsProvider.notifier).resendInviteEmail(user["id"].toString());
    if (mounted) {
      if (res) {
        NutriSnack.show(context, "Correo de configuración enviado a ${user['email']}");
      } else {
        NutriSnack.show(context, "No se pudo reenviar el correo", isError: true);
      }
    }
  }


  void _dialogoTutor(Map<String, dynamic>? user) {
    showDialog(
      context: context,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
      builder: (_) => _FormularioTutor(
        user: user,
        onSuccess: () => ref.read(adminTutorsProvider.notifier).loadPage(),
      ),
    );
  }

  Widget _input(TextEditingController c, String h, IconData i) =>
      TextField(controller: c, decoration: _inputDecor(h, i));

  InputDecoration _inputDecor(String h, IconData i) => InputDecoration(
      labelText: h,
      prefixIcon: Icon(i, size: 20),
      filled: true,
      fillColor: AppTema.grisLienzo,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none));
}

class _AdminTutorsDataSource extends DataTableSource {
  final List<Map<String, dynamic>> items;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Function(Map<String, dynamic>) onToggle;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>) onResend;
  final double totalWidth;
  final BuildContext context;

  _AdminTutorsDataSource({
    required this.items,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onResend,
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
                  const NutriShimmer(width: 180, height: 10),
                ],
              ),
            ],
          ),
        )),
        DataCell(SizedBox(
            width: totalWidth * 0.15,
            child: const NutriShimmer(width: 80, height: 10))),
        DataCell(SizedBox(
            width: totalWidth * 0.15,
            child: const Center(child: NutriShimmer(width: 60, height: 20)))),
        DataCell(SizedBox(
          width: totalWidth * 0.35,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.all(Radius.circular(12))),
              const SizedBox(width: 12),
              const NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.all(Radius.circular(12))),
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
                            fontSize: 12,
                            color: AppTema.azulOscuro)),
                    Text(u["email"] ?? "",
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
          child: Text(u["cedula"]?.toString() ?? "N/A",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
        width: totalWidth * 0.35,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HoverActionButton(
                  icon: Icons.mark_email_unread_rounded,
                  label: "Reenviar",
                  color: AppTema.azulOscuro,
                  onTap: () => onResend(u)),
              const SizedBox(width: 8),
              _HoverActionButton(
                  icon: Icons.edit_note_rounded,
                  label: "Editar",
                  color: AppTema.azulPrincipal,
                  onTap: () => onEdit(u)),
              const SizedBox(width: 8),
              _HoverActionButton(
                  icon: u["activo"] == true
                      ? Icons.block_flipped
                      : Icons.check_circle_outline,
                  label: u["activo"] == true ? "Baja" : "Alta",
                  color: u["activo"] == true ? Colors.orange : Colors.green,
                  onTap: () => onToggle(u)),
              const SizedBox(width: 8),
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
                    color: widget.color,
                    height: 1.0)),
          ],
        ),
      ),
    );
  }
}

class _FormularioTutor extends ConsumerStatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onSuccess;
  const _FormularioTutor({this.user, required this.onSuccess});
  @override
  ConsumerState<_FormularioTutor> createState() => _FormularioTutorState();
}

class _FormularioTutorState extends ConsumerState<_FormularioTutor> {
  final _emailCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _emailCtrl.text = widget.user!["email"] ?? "";
      _nombreCtrl.text = widget.user!["nombre_completo"] ?? "";
      _cedulaCtrl.text = widget.user!["cedula"] ?? "";
      _telefonoCtrl.text = widget.user!["telefono"] ?? "";
      _direccionCtrl.text = widget.user!["direccion"] ?? "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 580),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppTema.azulPrincipal,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isEdit ? "Editar Tutor" : "Nuevo Tutor",
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTema.azulOscuro,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF64748B),
                  iconSize: 22,
                  tooltip: "Cerrar",
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Columna Izquierda: Datos Personales
                  Expanded(
                    flex: 10,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 12),
                              child: Text(
                                "Datos Personales",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTema.azulOscuro,
                                ),
                              ),
                            ),
                            _input(
                              _nombreCtrl,
                              "Nombre completo",
                              "Ingresar nombre completo",
                              Icons.badge_outlined,
                            ),
                            const SizedBox(height: 16),
                            _input(
                              _cedulaCtrl,
                              "Cédula",
                              "Número de cédula",
                              Icons.person_outline_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _input(
                              _emailCtrl,
                              "Correo electrónico",
                              "usuario@nutrireuma.com",
                              Icons.mail_outline,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Divisor vertical sutil
                  Container(
                    width: 1.2,
                    color: const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  
                  // Columna Derecha: Datos de Contacto
                  Expanded(
                    flex: 12,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 12),
                              child: Text(
                                "Datos de Contacto",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTema.azulOscuro,
                                ),
                              ),
                            ),
                            _input(
                              _telefonoCtrl,
                              "Teléfono",
                              "Ingresar teléfono",
                              Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _input(
                              _direccionCtrl,
                              "Dirección",
                              "Ingresar dirección",
                              Icons.location_on_outlined,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTema.pastelCeleste,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTema.azulPrincipal.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_rounded,
                    color: AppTema.azulPrincipal,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit
                          ? "Actualiza todos los datos del tutor."
                          : "Al guardar, se enviará una invitación por correo para que configure su contraseña. Asegúrate de llenar todos los campos.",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
                  width: 148,
                  height: 46,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTema.azulPrincipal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTema.azulOscuro,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF334155),
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecor(hint, icon),
        ),
      ],
    );
  }

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.grey.shade400,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTema.azulPrincipal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  Future<void> _save() async {
    if (_nombreCtrl.text.trim().isEmpty || 
        _emailCtrl.text.trim().isEmpty || 
        _cedulaCtrl.text.trim().isEmpty || 
        _telefonoCtrl.text.trim().isEmpty || 
        _direccionCtrl.text.trim().isEmpty) {
      NutriSnack.show(context, "Por favor complete todos los datos obligatorios",
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      if (widget.user != null) {
        await repo.updateUser(
          userId: widget.user!["id"].toString(),
          nombreCompleto: _nombreCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          cedula: _cedulaCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
          idRol: 4, // Rol Tutor Fijo
        );
      } else {
        await repo.createUser(
          email: _emailCtrl.text.trim(),
          nombreCompleto: _nombreCtrl.text.trim(),
          idRol: 4, // Rol Tutor Fijo
          cedula: _cedulaCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
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

