import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/state/app_providers.dart";
import "../../core/theme/app_theme.dart";
import "../../shared/widgets/layout_components.dart";

class PerfilPage extends ConsumerStatefulWidget {
  const PerfilPage({super.key});

  @override
  ConsumerState<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends ConsumerState<PerfilPage> {
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _cedulaController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  void _initializeFields(Map<String, dynamic> profile) {
    if (_initialized) return;
    
    final fullName = profile["nombre_completo"]?.toString() ?? "";
    List<String> partes = fullName.trim().split(" ");
    String nombres = ""; String apellidos = "";
    
    if (partes.length >= 2) {
      int mid = (partes.length / 2).floor();
      if (partes.length == 3) mid = 1;
      nombres = partes.sublist(0, mid).join(" ");
      apellidos = partes.sublist(mid).join(" ");
    } else { nombres = fullName; }

    _nombresController.text = nombres;
    _apellidosController.text = apellidos;
    _emailController.text = profile["email"]?.toString() ?? "";
    _cedulaController.text = profile["cedula"]?.toString() ?? "";
    _telefonoController.text = profile["telefono"]?.toString() ?? "";
    _direccionController.text = profile["direccion"]?.toString() ?? "";
    _initialized = true;
  }

  Future<void> _saveProfile() async {
    final nombres = _nombresController.text.trim();
    final apellidos = _apellidosController.text.trim();
    final email = _emailController.text.trim();

    if (nombres.isEmpty || apellidos.isEmpty || email.isEmpty) {
      NutriSnack.show(context, "Campos obligatorios incompletos", isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.updateMyProfile(
        nombreCompleto: "$nombres $apellidos",
        email: email,
        cedula: _cedulaController.text,
        telefono: _telefonoController.text,
        direccion: _direccionController.text,
      );

      if (!mounted) return;
      ref.invalidate(miPerfilProvider); // Actualizar globalmente el usuario actual
      ref.invalidate(usersListProvider); // Actualizar la tabla de equipo médico
      NutriSnack.show(context, "Perfil actualizado correctamente", ref: ref);
    } catch (error) {
      if (mounted) NutriSnack.show(context, "Error al guardar cambios", isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(miPerfilProvider);

    return perfilAsync.when(
      data: (profile) {
        _initializeFields(profile);
        final role = profile["rol_nombre"]?.toString() ?? "Usuario";
        final activo = profile["activo"] == true;

        return Scaffold(
          backgroundColor: AppTema.grisLienzo,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mi Perfil", 
                  style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                Text("Gestiona tu información personal y profesional.", 
                  style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarCard(profile, role, activo),
                    const SizedBox(width: 32),
                    Expanded(child: _buildFormCard()),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppTema.grisLienzo,
        body: NutriLoading(mensaje: "Sincronizando perfil..."),
      ),
      error: (e, _) => Center(child: Text("Error al cargar perfil: $e")),
    );
  }

  Widget _buildAvatarCard(Map<String, dynamic> profile, String role, bool activo) {
    return Container(
      width: 280, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60, backgroundColor: AppTema.azulPrincipal.withOpacity(0.1),
            child: Text((_nombresController.text.isNotEmpty ? _nombresController.text[0] : "") + (_apellidosController.text.isNotEmpty ? _apellidosController.text[0] : ""), style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal)),
          ),
          const SizedBox(height: 20),
          Text("${_nombresController.text} ${_apellidosController.text}", textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppTema.verdeSalud.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(role.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: AppTema.verdeSalud))),
          const SizedBox(height: 24), const Divider(), const SizedBox(height: 16),
          _infoMiniItem(Icons.verified_user_outlined, "Estado", activo ? "Activo" : "Inactivo"),
          const SizedBox(height: 12), _infoMiniItem(Icons.calendar_today_outlined, "Sistema", "NutriReuma v1.0"),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Datos Personales"), const SizedBox(height: 20),
          Row(children: [Expanded(child: _buildTextField(controller: _nombresController, label: "Nombres", icon: Icons.person_outline)), const SizedBox(width: 16), Expanded(child: _buildTextField(controller: _apellidosController, label: "Apellidos", icon: Icons.person_outline))]),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _buildTextField(controller: _cedulaController, label: "Identificación", icon: Icons.fingerprint)), const SizedBox(width: 16), Expanded(child: _buildTextField(controller: _telefonoController, label: "Teléfono", icon: Icons.phone_android_outlined))]),
          const SizedBox(height: 32), _sectionTitle("Contacto y Ubicación"), const SizedBox(height: 20),
          _buildTextField(controller: _emailController, label: "Email", icon: Icons.alternate_email), const SizedBox(height: 16),
          _buildTextField(controller: _direccionController, label: "Dirección", icon: Icons.location_on_outlined, maxLines: 2),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            onPressed: _saving ? null : _saveProfile,
            icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_as_rounded),
            label: Text("GUARDAR CAMBIOS", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 1.2));
  Widget _infoMiniItem(IconData icon, String label, String value) => Row(children: [Icon(icon, size: 16, color: Colors.blueGrey), const SizedBox(width: 8), Text("$label: ", style: GoogleFonts.lato(fontSize: 12, color: Colors.blueGrey)), Text(value, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87))]);
  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, int maxLines = 1}) => TextFormField(controller: controller, maxLines: maxLines, style: GoogleFonts.lato(fontSize: 14), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20, color: AppTema.azulPrincipal.withOpacity(0.6)), labelStyle: const TextStyle(fontSize: 13, color: Colors.black54), floatingLabelStyle: const TextStyle(color: AppTema.azulPrincipal, fontWeight: FontWeight.bold), filled: true, fillColor: AppTema.grisLienzo.withOpacity(0.5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTema.azulPrincipal, width: 1)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
}
