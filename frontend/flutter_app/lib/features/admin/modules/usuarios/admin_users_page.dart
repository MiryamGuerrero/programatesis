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
                      style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                    Text("Control institucional de accesos y perfiles profesionales.", 
                      style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 13)),
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
                    Expanded(child: NutriResumenCard(titulo: "NUTRICIONISTAS", valor: "$nutris", colorValor: AppTema.cianLimpio, icon: Icons.restaurant_menu_rounded)),
                  ],
                );
              },
              loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            NutriTableToolbar(actionLabel: "Nuevo Miembro", onAction: () => _dialogoUsuario(null), onSearch: (v) => setState(() => _searchQuery = v)),
            const SizedBox(height: 16),
            rolesAsync.when(
              data: (roles) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Wrap(
                  spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text("FILTRAR POR ROL:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ChoiceChip(
                      label: Text("TODOS", style: GoogleFonts.lexend(fontSize: 11)), 
                      selected: _selectedRoles.isEmpty, onSelected: (_) => setState(() => _selectedRoles.clear()),
                    ),
                    ...roles.map((r) => FilterChip(
                      label: Text(r["nombre"].toString().toUpperCase(), style: GoogleFonts.lexend(fontSize: 11)),
                      selected: _selectedRoles.contains(r["nombre"]), onSelected: (v) => setState(() => v ? _selectedRoles.add(r["nombre"]) : _selectedRoles.remove(r["nombre"])),
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
                  return DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTema.pastelCeleste), 
                    columns: [
                      DataColumn(label: Text("PROFESIONAL", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal))),
                      DataColumn(label: Text("CÉDULA", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal))),
                      DataColumn(label: Text("CORREO", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal))),
                      DataColumn(label: Text("ROL", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal))),
                      DataColumn(label: Text("ACCIONES", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal))),
                    ],
                    rows: filtered.map((u) => _buildRow(u)).toList(),
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

  DataRow _buildRow(Map<String, dynamic> u) {
    final nombre = u["nombre_completo"] ?? "Usuario";
    final activo = u["activo"] ?? true;
    return DataRow(cells: [
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NutriAvatar(nombreCompleto: nombre, radio: 14, colorTexto: AppTema.azulPrincipal),
          const SizedBox(width: 10),
          Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      )),
      DataCell(Text(u["cedula"] ?? "-", style: const TextStyle(fontSize: 13))),
      DataCell(Text(u["email"] ?? "-", style: const TextStyle(fontSize: 13))),
      DataCell(NutriBadge(label: u["rol_nombre"].toString().toUpperCase(), type: "info")),
      DataCell(Row(children: [
        Tooltip(message: "Editar Profesional", child: IconButton(icon: const Icon(Icons.edit_outlined, color: AppTema.azulPrincipal, size: 18), onPressed: () => _dialogoUsuario(u))),
        Tooltip(message: "Gestionar Acceso", child: IconButton(icon: Icon(activo ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined, color: activo ? Colors.redAccent : Colors.green, size: 18), onPressed: () => _toggle(u))),
      ])),
    ]);
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
              Expanded(child: Text(isEdit ? "Editar Miembro" : "Nuevo Miembro", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))),
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
                        style: GoogleFonts.lexend(fontSize: 13),
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
                        value: rolId, style: GoogleFonts.lexend(color: Colors.black87, fontSize: 13),
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
              OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16), side: const BorderSide(color: Colors.grey)), child: Text("CANCELAR", style: GoogleFonts.lexend(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
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
                child: Text(isEdit ? "GUARDAR" : "CREAR", style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: GoogleFonts.quicksand(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 1.1)),
      const SizedBox(height: 8), ...children,
    ]);
  }

  Widget _buildModalField({required TextEditingController controller, required String label, required IconData icon, bool enabled = true, int maxLines = 1, FormFieldValidator<String>? validator, String? errorText}) {
    return TextFormField(controller: controller, enabled: enabled, maxLines: maxLines, validator: validator, style: GoogleFonts.lexend(fontSize: 13), decoration: _modalInputDecoration(label, icon).copyWith(errorText: errorText));
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
