import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/nutri_avatar.dart";
import "../../../../core/state/notification_provider.dart";

import "package:google_fonts/google_fonts.dart";

final rolesStaffProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final allRoles = await ref.watch(supabaseCrudRepositoryProvider).fetchCatalog("usuarios", "rol");
  final allowedRoles = ["médico", "nutricionista", "administrador", "médico/a", "medico", "admin"];
  return allRoles.where((r) {
    final nombre = r["nombre"].toString().toLowerCase();
    return allowedRoles.any((allowed) => nombre.contains(allowed));
  }).toList();
});

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});
  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  String _searchQuery = "";
  final Set<String> _selectedRoles = {};

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);
    final rolesAsync = ref.watch(rolesStaffProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Gestión de Equipo Médico", 
                      style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                    Text("Control institucional de accesos y perfiles profesionales.", 
                      style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.sync_rounded, color: AppTema.azulPrincipal), onPressed: () => ref.invalidate(usersListProvider)),
              ],
            ),
            const SizedBox(height: 32),
            usersAsync.when(
              data: (users) {
                final staff = users.where((u) {
                  final code = u["rol_codigo"]?.toString().toLowerCase() ?? "";
                  return code != "tutor";
                }).toList();
                int medicos = staff.where((u) => u["rol_codigo"].toString().toLowerCase().contains("med")).length;
                int nutris = staff.where((u) => u["rol_codigo"].toString().toLowerCase().contains("nutri")).length;
                return Row(
                  children: [
                    Expanded(child: NutriResumenCard(titulo: "TOTAL PERSONAL", valor: "${staff.length}", icon: Icons.people_alt_rounded)),
                    const SizedBox(width: 20),
                    Expanded(child: NutriResumenCard(titulo: "MÉDICOS", valor: "$medicos", colorValor: AppTema.verdeSalud, icon: Icons.medical_services_rounded)),
                    const SizedBox(width: 20),
                    Expanded(child: NutriResumenCard(titulo: "NUTRICIONISTAS", valor: "$nutris", colorValor: AppTema.azulOscuro, icon: Icons.restaurant_menu_rounded)),
                  ],
                );
              },
              loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "Buscar por nombre de profesional...",
                        hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppTema.azulPrincipal),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  height: 55,
                  child: FilledButton.icon(
                    onPressed: () => _dialogoUsuario(null),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTema.verdeSalud,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: Colors.white),
                    label: Text("NUEVO MIEMBRO", 
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            rolesAsync.when(
              data: (roles) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    Text("FILTRAR POR ROL:", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
                    const SizedBox(width: 16),
                    _filterChip("TODOS", _selectedRoles.isEmpty, () => setState(() => _selectedRoles.clear())),
                    const SizedBox(width: 12),
                    ...roles.map((r) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _filterChip(
                        r["nombre"].toString().toUpperCase(), 
                        _selectedRoles.contains(r["nombre"]),
                        () => setState(() => _selectedRoles.contains(r["nombre"]) ? _selectedRoles.remove(r["nombre"]) : _selectedRoles.add(r["nombre"]))
                      ),
                    )),
                  ],
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            NutriTableContainer(
              child: usersAsync.when(
                data: (users) {
                  final rolesData = rolesAsync.valueOrNull ?? [];
                  final nombresRolesPermitidos = rolesData.map((r) => r["nombre"].toString()).toSet();
                  final filtered = users.where((u) {
                    final nameMatches = u["nombre_completo"].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                    final roleName = u["rol_nombre"].toString();
                    return nameMatches && (_selectedRoles.isEmpty || _selectedRoles.contains(roleName)) && nombresRolesPermitidos.contains(roleName);
                  }).toList();

                  return Theme(
                    data: Theme.of(context).copyWith(
                      cardTheme: const CardThemeData(elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
                    ),
                    child: PaginatedDataTable(
                      header: null,
                      rowsPerPage: 5,
                      showFirstLastButtons: true,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      columns: [
                        DataColumn(label: Text("PROFESIONAL", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
                        DataColumn(label: Text("CÉDULA", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
                        DataColumn(label: Text("CORREO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
                        DataColumn(label: Text("ROL", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
                        DataColumn(label: Text("ACCIONES", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
                      ],
                      source: _UsersDataSource(
                        users: filtered,
                        onEdit: _dialogoUsuario,
                        onToggle: _toggle,
                      ),
                    ),
                  );
                },
                loading: () => const NutriLoading(mensaje: "Obteniendo lista de profesionales..."),
                error: (e, _) => Center(child: Text("Error: $e")),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dialogoUsuario(Map<String, dynamic>? user) {
    final bool isEdit = user != null;
    final formKey = GlobalKey<FormState>();
    
    String nombres = ""; String apellidos = "";
    if (isEdit && user["nombre_completo"] != null) {
      final partes = user["nombre_completo"].toString().trim().split(" ");
      int mid = (partes.length / 2).floor();
      if (partes.length == 3) mid = 1; 
      nombres = partes.sublist(0, mid).join(" ");
      apellidos = partes.sublist(mid).join(" ");
    }

    final nombresCtrl = TextEditingController(text: nombres);
    final apellidosCtrl = TextEditingController(text: apellidos);
    final emailCtrl = TextEditingController(text: user?["email"]?.toString() ?? "");
    final passCtrl = TextEditingController(); 
    final cedulaCtrl = TextEditingController(text: user?["cedula"]?.toString() ?? "");
    final telefonoCtrl = TextEditingController(text: user?["telefono"]?.toString() ?? "");
    final direccionCtrl = TextEditingController(text: user?["direccion"]?.toString() ?? "");
    int? rolId = user?["id_rol"];
    bool obscurePass = true;
    Map<String, String?> serverErrors = {};

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white, surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: EdgeInsets.zero, contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          title: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: const BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            child: Row(children: [
              Icon(isEdit ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(isEdit ? "Editar Miembro" : "Nuevo Miembro", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.cancel_rounded, color: Colors.white70, size: 22)),
            ]),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: 420,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _buildFieldSection("Datos Personales", [
                    Row(children: [
                      Expanded(child: _buildModalField(controller: nombresCtrl, label: "Nombres *", icon: Icons.person_outline, validator: (v) => v!.isEmpty ? "Obligatorio" : null)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildModalField(controller: apellidosCtrl, label: "Apellidos *", icon: Icons.person_outline, validator: (v) => v!.isEmpty ? "Obligatorio" : null)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _buildModalField(controller: cedulaCtrl, label: "Cédula/ID", icon: Icons.fingerprint)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildModalField(controller: telefonoCtrl, label: "Teléfono", icon: Icons.phone_android_outlined)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  _buildFieldSection("Acceso al Sistema", [
                    _buildModalField(
                      controller: emailCtrl, label: "Email *", icon: Icons.alternate_email, enabled: !isEdit,
                      errorText: serverErrors["email"],
                      validator: (v) => (v!.isEmpty || !v.contains("@")) ? "Email inválido" : null
                    ),
                    if (!isEdit) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl, obscureText: obscurePass,
                        style: GoogleFonts.lato(fontSize: 13),
                        validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
                        decoration: _modalInputDecoration("Contraseña Temporal *", Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(icon: Icon(obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppTema.azulPrincipal), onPressed: () => setDialogState(() => obscurePass = !obscurePass)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Consumer(builder: (context, ref, _) {
                      final roles = ref.watch(rolesStaffProvider).valueOrNull ?? [];
                      return DropdownButtonFormField<int>(
                        value: rolId, style: GoogleFonts.lato(color: Colors.black87, fontSize: 13),
                        validator: (v) => v == null ? "Seleccione un rol" : null,
                        decoration: _modalInputDecoration("Rol Profesional *", Icons.admin_panel_settings_outlined),
                        items: roles.map((r) => DropdownMenuItem<int>(value: r["id"], child: Text(r["nombre"].toString().toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) => setDialogState(() => rolId = v),
                      );
                    }),
                  ]),
                  const SizedBox(height: 16),
                  _buildFieldSection("Localización", [
                    _buildModalField(controller: direccionCtrl, label: "Dirección", icon: Icons.location_on_outlined, maxLines: 1),
                  ]),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16), side: const BorderSide(color: Colors.grey)), child: Text("CANCELAR", style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24)),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() => serverErrors = {});
                  final repo = ref.read(supabaseCrudRepositoryProvider);
                  try {
                    final full = "${nombresCtrl.text.trim()} ${apellidosCtrl.text.trim()}";
                    if (isEdit) {
                      await repo.updateUser(userId: user["id"], nombreCompleto: full, cedula: cedulaCtrl.text, telefono: telefonoCtrl.text, direccion: direccionCtrl.text, idRol: rolId);
                    } else {
                      await repo.createUser(email: emailCtrl.text, nombreCompleto: full, idRol: rolId!, password: passCtrl.text, cedula: cedulaCtrl.text, telefono: telefonoCtrl.text, direccion: direccionCtrl.text);
                      ref.read(notificationProvider.notifier).add("Seguridad", "Se requiere reseteo de clave para ${nombresCtrl.text}", type: NutriNotificationType.warning);
                    }
                    ref.invalidate(usersListProvider); ref.invalidate(miPerfilProvider);
                    if (mounted) { Navigator.pop(context); NutriSnack.show(context, isEdit ? "Actualizado correctamente" : "Registrado correctamente", ref: ref); }
                  } catch (e) {
                    final err = e.toString().toLowerCase();
                    if (err.contains("email")) setDialogState(() => serverErrors["email"] = "Este correo ya está en uso");
                    else NutriSnack.show(context, "Error en la operación", isError: true, ref: ref);
                  }
                },
                child: Text(isEdit ? "GUARDAR" : "CREAR", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 1.1)),
      const SizedBox(height: 8), ...children,
    ]);
  }

  Widget _buildModalField({required TextEditingController controller, required String label, required IconData icon, bool enabled = true, int maxLines = 1, FormFieldValidator<String>? validator, String? errorText}) {
    return TextFormField(controller: controller, enabled: enabled, maxLines: maxLines, validator: validator, style: GoogleFonts.lato(fontSize: 13), decoration: _modalInputDecoration(label, icon).copyWith(errorText: errorText));
  }

  InputDecoration _modalInputDecoration(String label, IconData icon) {
    bool isMandatory = label.contains("*");
    return InputDecoration(
      labelText: label, 
      labelStyle: TextStyle(fontSize: 12, color: isMandatory ? AppTema.azulPrincipal.withOpacity(0.8) : Colors.black54),
      prefixIcon: Icon(icon, size: 18, color: AppTema.azulPrincipal.withOpacity(0.6)), 
      floatingLabelStyle: const TextStyle(color: AppTema.azulPrincipal, fontWeight: FontWeight.bold), 
      filled: true, fillColor: AppTema.grisLienzo.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), 
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTema.azulPrincipal, width: 1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), errorStyle: const TextStyle(fontSize: 10),
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
          border: Border.all(color: isSelected ? AppTema.azulPrincipal : Colors.grey.shade300),
        ),
        child: Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Future<void> _toggle(Map<String, dynamic> u) async {
    try {
      final nuevo = !(u["activo"] ?? true);
      await ref.read(supabaseCrudRepositoryProvider).updateUser(userId: u["id"], activo: nuevo);
      ref.invalidate(usersListProvider);
      if (mounted) NutriSnack.show(context, nuevo ? "Acceso habilitado" : "Acceso restringido", ref: ref);
    } catch (e) {
      if (mounted) NutriSnack.show(context, "Error al cambiar estado", isError: true, ref: ref);
    }
  }
}

class _UsersDataSource extends DataTableSource {
  final List<Map<String, dynamic>> users;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onToggle;

  _UsersDataSource({
    required this.users,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= users.length) return null;
    final u = users[index];
    final nombre = u["nombre_completo"] ?? "Usuario";
    final activo = u["activo"] ?? true;

    return DataRow(cells: [
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NutriAvatar(nombreCompleto: nombre, radio: 14, colorTexto: AppTema.azulPrincipal),
          const SizedBox(width: 10),
          Text(nombre, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500)),
        ],
      )),
      DataCell(Text(u["cedula"] ?? "-", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500))),
      DataCell(Text(u["email"] ?? "-", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500))),
      DataCell(NutriBadge(label: u["rol_nombre"].toString().toUpperCase(), type: "info")),
      DataCell(Row(children: [
        Tooltip(message: "Editar Profesional", child: IconButton(icon: const Icon(Icons.edit_outlined, color: AppTema.azulPrincipal, size: 18), onPressed: () => onEdit(u))),
        Tooltip(message: "Gestionar Acceso", child: IconButton(icon: Icon(activo ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined, color: activo ? Colors.redAccent : Colors.green, size: 18), onPressed: () => onToggle(u))),
      ])),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => users.length;
  @override
  int get selectedRowCount => 0;
}
