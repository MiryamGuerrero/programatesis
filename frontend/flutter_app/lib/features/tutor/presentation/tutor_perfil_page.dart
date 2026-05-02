import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";
import "../../auth/login_page.dart";

class TutorPerfilPage extends ConsumerStatefulWidget {
  const TutorPerfilPage({super.key});

  @override
  ConsumerState<TutorPerfilPage> createState() => _TutorPerfilPageState();
}

class _TutorPerfilPageState extends ConsumerState<TutorPerfilPage> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, completa los campos obligatorios")),
      );
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
      ref.invalidate(miPerfilProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perfil actualizado con éxito")),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar: $error"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(miPerfilProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: perfilAsync.when(
        data: (profile) {
          _initializeFields(profile);
          final String role = profile["rol_nombre"]?.toString() ?? "Tutor";
          final String iniciales = (_nombresController.text.isNotEmpty ? _nombresController.text[0] : "") + 
                                   (_apellidosController.text.isNotEmpty ? _apellidosController.text[0] : "");

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(iniciales, role),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildFormCard(),
                      const SizedBox(height: 32),
                      _buildSaveButton(),
                      const SizedBox(height: 20),
                      _buildLogoutButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error al cargar perfil: $e")),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleSignOut,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
        label: Text(
          "CERRAR SESIÓN",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.redAccent,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cerrar Sesión"),
        content: const Text("¿Estás seguro de que deseas salir de tu cuenta?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("SÍ, SALIR")),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }

  Widget _buildProfileHeader(String iniciales, String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTema.azulPrincipal, AppTema.azulOscuro],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              iniciales.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "${_nombresController.text} ${_apellidosController.text}",
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Información Personal"),
          const SizedBox(height: 20),
          _buildField("Nombres", _nombresController, Icons.person_outline_rounded),
          const SizedBox(height: 16),
          _buildField("Apellidos", _apellidosController, Icons.person_outline_rounded),
          const SizedBox(height: 16),
          _buildField("Cédula / ID", _cedulaController, Icons.badge_outlined),
          const SizedBox(height: 16),
          _buildField("Teléfono", _telefonoController, Icons.phone_android_rounded),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(),
          ),
          
          _buildSectionTitle("Cuenta y Contacto"),
          const SizedBox(height: 20),
          _buildField("Correo Electrónico", _emailController, Icons.alternate_email_rounded, enabled: false),
          const SizedBox(height: 16),
          _buildField("Dirección de Domicilio", _direccionController, Icons.location_on_outlined, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.montserrat(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppTema.azulPrincipal,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool enabled = true, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: enabled ? AppTema.azulPrincipal : Colors.grey),
            filled: true,
            fillColor: enabled ? const Color(0xFFF1F5F9).withOpacity(0.5) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _saving ? null : _saveProfile,
        style: FilledButton.styleFrom(
          backgroundColor: AppTema.azulPrincipal,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: AppTema.azulPrincipal.withOpacity(0.4),
        ),
        child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                "GUARDAR CAMBIOS",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1),
              ),
      ),
    );
  }
}
