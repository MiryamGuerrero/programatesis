import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/nutri_avatar.dart";
import "../../../../core/state/notification_provider.dart";

import "package:google_fonts/google_fonts.dart";

class AdminTutorsPage extends ConsumerStatefulWidget {
  const AdminTutorsPage({super.key});
  @override
  ConsumerState<AdminTutorsPage> createState() => _AdminTutorsPageState();
}

class _AdminTutorsPageState extends ConsumerState<AdminTutorsPage> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: usersAsync.when(
        data: (users) {
          final tutors = users.where((u) {
            final c = u["rol_codigo"]?.toString().toLowerCase().trim() ?? "";
            return c.contains("tutor");
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                NutriTableToolbar(
                  actionLabel: "Invitar Tutor",
                  onAction: () => _dialogoInvitacion(), 
                  onSearch: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 24),
                NutriTableContainer(child: _buildTutorTable(tutors)),
              ],
            ),
          );
        },
        loading: () => const NutriLoading(mensaje: "Cargando representantes..."),
        error: (e, _) => Center(child: Text("Error al cargar tutores: $e")),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Gestión de Cuentas: Tutores", 
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                Text("Supervisión de accesos para representantes y padres.", 
                  style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 13)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: AppTema.azulPrincipal), 
              onPressed: () => ref.invalidate(usersListProvider),
              tooltip: "Sincronizar",
            ),
          ],
        ),
      ],
    );
  }

  void _dialogoInvitacion() {
    final nombreCtrl = TextEditingController();
    final apellidosCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscurePass = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: const BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            child: Row(children: [
              const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text("Invitar Nuevo Tutor", style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombres", prefixIcon: Icon(Icons.person_outline, size: 18)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: apellidosCtrl, decoration: const InputDecoration(labelText: "Apellidos", prefixIcon: Icon(Icons.person_outline, size: 18)))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Correo Electrónico", prefixIcon: Icon(Icons.alternate_email, size: 18))),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl, 
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: "Contraseña Temporal", 
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppTema.azulPrincipal),
                      onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                    ),
                  )
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context), 
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16), side: const BorderSide(color: Colors.grey)),
                  child: Text("CANCELAR", style: GoogleFonts.lexend(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20)),
                  onPressed: () async {
                    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty || nombreCtrl.text.isEmpty) return;
                    try {
                      final repo = ref.read(supabaseCrudRepositoryProvider);
                      await repo.createUser(
                        email: emailCtrl.text,
                        nombreCompleto: "${nombreCtrl.text.trim()} ${apellidosCtrl.text.trim()}",
                        idRol: 4, 
                        password: passCtrl.text,
                      );
                      ref.invalidate(usersListProvider);
                      if (mounted) {
                        Navigator.pop(context);
                        NutriSnack.show(context, "Tutor invitado con éxito", ref: ref);
                      }
                    } catch (e) {
                      if (mounted) NutriSnack.show(context, "Error al invitar tutor", isError: true, ref: ref);
                    }
                  },
                  child: Text("ENVIAR ACCESO", style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorTable(List<Map<String, dynamic>> tutors) {
    final filtered = tutors.where((u) {
      final q = _searchQuery.toLowerCase().trim();
      return u["nombre_completo"].toString().toLowerCase().contains(q) || u["email"].toString().toLowerCase().contains(q);
    }).toList();

    return DataTable(
      headingRowColor: WidgetStateProperty.all(AppTema.pastelCeleste), 
      columns: [
        DataColumn(label: Text("REPRESENTANTE", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal))),
        DataColumn(label: Text("CORREO", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal))),
        DataColumn(label: Text("ESTADO", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal))),
        DataColumn(label: Text("GESTIÓN", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal))),
      ],
      rows: filtered.map((u) {
        final nombre = u["nombre_completo"] ?? "-";
        return DataRow(cells: [
          DataCell(Row(
            children: [
              NutriAvatar(nombreCompleto: nombre, radio: 16),
              const SizedBox(width: 12),
              Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          )),
          DataCell(Text(u["email"] ?? "-", style: const TextStyle(fontSize: 12))),
          DataCell(NutriBadge(label: (u["activo"] ?? true) ? "ACTIVO" : "INACTIVO", type: (u["activo"] ?? true) ? "success" : "danger")),
          DataCell(Row(children: [
            Tooltip(message: "Enviar Reseteo de Contraseña", child: IconButton(icon: const Icon(Icons.lock_reset_rounded, size: 18, color: Colors.orange), onPressed: () => NutriSnack.show(context, "Correo de reseteo enviado", ref: ref))),
            Tooltip(message: "Suspender Cuenta", child: IconButton(
              icon: Icon((u["activo"] ?? true) ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined, size: 18, color: (u["activo"] ?? true) ? Colors.redAccent : Colors.green), 
              onPressed: () async {
                final nuevo = !(u["activo"] ?? true);
                await ref.read(supabaseCrudRepositoryProvider).updateUser(userId: u["id"], activo: nuevo);
                ref.invalidate(usersListProvider);
                if (mounted) NutriSnack.show(context, nuevo ? "Acceso habilitado" : "Acceso suspendido", ref: ref);
              }
            )),
          ])),
        ]);
      }).toList(),
    );
  }
}
