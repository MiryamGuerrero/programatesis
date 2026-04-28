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
                            hintText: "Buscar por nombre o correo...",
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
                        onPressed: () => _dialogoInvitacion(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTema.verdeSalud,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: Colors.white),
                        label: Text("INVITAR TUTOR", 
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                      ),
                    ),
                  ],
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
                  style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                Text("Supervisión de accesos para representantes y padres.", 
                  style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
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
              Text("Invitar Nuevo Tutor", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
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
                  child: Text("CANCELAR", style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))
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
                  child: Text("ENVIAR ACCESO", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold)),
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
          DataColumn(label: Text("REPRESENTANTE", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
          DataColumn(label: Text("CORREO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
          DataColumn(label: Text("ESTADO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
          DataColumn(label: Text("GESTIÓN", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
        ],
        source: _TutorsDataSource(
          tutors: filtered,
          context: context,
          ref: ref,
        ),
      ),
    );
  }
}

class _TutorsDataSource extends DataTableSource {
  final List<Map<String, dynamic>> tutors;
  final BuildContext context;
  final WidgetRef ref;

  _TutorsDataSource({
    required this.tutors,
    required this.context,
    required this.ref,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= tutors.length) return null;
    final u = tutors[index];
    final nombre = u["nombre_completo"] ?? "-";
    return DataRow(cells: [
      DataCell(Row(
        children: [
          NutriAvatar(nombreCompleto: nombre, radio: 16),
          const SizedBox(width: 12),
          Text(nombre, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600)),
        ],
      )),
      DataCell(Text(u["email"] ?? "-", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600))),
      DataCell(NutriBadge(label: (u["activo"] ?? true) ? "ACTIVO" : "INACTIVO", type: (u["activo"] ?? true) ? "success" : "danger")),
      DataCell(Row(children: [
        Tooltip(message: "Enviar Reseteo de Contraseña", child: IconButton(icon: const Icon(Icons.lock_reset_rounded, size: 18, color: Colors.orange), onPressed: () => NutriSnack.show(context, "Correo de reseteo enviado", ref: ref))),
        Tooltip(message: "Suspender Cuenta", child: IconButton(
          icon: Icon((u["activo"] ?? true) ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined, size: 18, color: (u["activo"] ?? true) ? Colors.redAccent : Colors.green), 
          onPressed: () async {
            final nuevo = !(u["activo"] ?? true);
            await ref.read(supabaseCrudRepositoryProvider).updateUser(userId: u["id"], activo: nuevo);
            ref.invalidate(usersListProvider);
            if (context.mounted) NutriSnack.show(context, nuevo ? "Acceso habilitado" : "Acceso suspendido", ref: ref);
          }
        )),
      ])),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => tutors.length;
  @override
  int get selectedRowCount => 0;
}
