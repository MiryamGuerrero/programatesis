import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final perfilAsync = ref.watch(miPerfilProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: perfilAsync.when(
        data: (profile) {
          _initializeFields(profile);
          // Obtenemos el parentesco real desde el backend (ya configurado en el repositorio)
          final String parentesco = profile["parentesco"]?.toString() ?? "Tutor";
          final String iniciales = (_nombresController.text.isNotEmpty ? _nombresController.text[0] : "") + 
                                   (_apellidosController.text.isNotEmpty ? _apellidosController.text[0] : "");

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(context, iniciales, parentesco),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Column(
                    children: [
                      _buildFormCard(context),
                      const SizedBox(height: 32),
                      _buildSaveButton(context),
                      const SizedBox(height: 20),
                      _buildLogoutButton(context),
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

  Widget _buildProfileHeader(BuildContext context, String iniciales, String parentesco) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40, bottom: 40),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: colorScheme.primary,
            child: Text(
              iniciales.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "${_nombresController.text} ${_apellidosController.text}",
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              parentesco.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, "Información Personal"),
            const SizedBox(height: 24),
            _buildField(context, "Nombres", _nombresController, Icons.person_outline_rounded),
            const SizedBox(height: 20),
            _buildField(context, "Apellidos", _apellidosController, Icons.person_outline_rounded),
            const SizedBox(height: 20),
            _buildField(context, "Cédula / ID", _cedulaController, Icons.badge_outlined),
            const SizedBox(height: 20),
            _buildField(context, "Teléfono", _telefonoController, Icons.phone_android_rounded),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(height: 1),
            ),
            
            _buildSectionTitle(context, "Cuenta y Contacto"),
            const SizedBox(height: 24),
            _buildField(context, "Correo Electrónico", _emailController, Icons.alternate_email_rounded, enabled: false),
            const SizedBox(height: 20),
            _buildField(context, "Dirección", _direccionController, Icons.location_on_outlined, maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w900,
        color: theme.colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildField(BuildContext context, String label, TextEditingController controller, IconData icon, {bool enabled = true, int maxLines = 1}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            fillColor: enabled ? Colors.white : const Color(0xFFF1F5F9),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _saving ? null : _saveProfile,
        child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("GUARDAR CAMBIOS"),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleSignOut,
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
        label: const Text("CERRAR SESIÓN"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cerrar Sesión"),
        content: const Text("¿Estás seguro de que deseas salir?"),
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
}
