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
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  bool _initialized = false;
  List<Map<String, dynamic>> _userRoles = [];
  Map<int, TextEditingController> _tituloCtrls = {};
  Map<int, TextEditingController> _instCtrls = {};

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _cedulaController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    for (final ctrl in _tituloCtrls.values) ctrl.dispose();
    for (final ctrl in _instCtrls.values) ctrl.dispose();
    super.dispose();
  }

  void _initializeFields(Map<String, dynamic> profile) {
    if (_initialized) return;

    final fullName = profile["nombre_completo"]?.toString() ?? "";
    List<String> partes = fullName.trim().split(" ");
    String nombres = "";
    String apellidos = "";

    if (partes.length >= 2) {
      int mid = (partes.length / 2).floor();
      if (partes.length == 3) mid = 1;
      nombres = partes.sublist(0, mid).join(" ");
      apellidos = partes.sublist(mid).join(" ");
    } else {
      nombres = fullName;
    }

    _nombresController.text = nombres;
    _apellidosController.text = apellidos;
    _usernameController.text = profile["username"]?.toString() ?? "";
    _emailController.text = profile["email"]?.toString() ?? "";
    _cedulaController.text = profile["cedula"]?.toString() ?? "";
    _telefonoController.text = profile["telefono"]?.toString() ?? "";
    _direccionController.text = profile["direccion"]?.toString() ?? "";
    _userRoles = List<Map<String, dynamic>>.from(profile["roles"] ?? []);
    for (final r in _userRoles) {
      final int idRol = r["id"];
      _tituloCtrls[idRol] = TextEditingController(text: r["titulo_profesional"]?.toString() ?? "");
      _instCtrls[idRol] = TextEditingController(text: r["institucion_titulo"]?.toString() ?? "");
    }
    _initialized = true;
  }

  Future<void> _saveProfile() async {
    final nombres = _nombresController.text.trim();
    final apellidos = _apellidosController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (nombres.isEmpty || apellidos.isEmpty || username.isEmpty || email.isEmpty) {
      NutriSnack.show(context, "Campos obligatorios incompletos", isError: true);
      return;
    }

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SaveProgressDialog(
        onSave: () async {
          final repo = ref.read(supabaseCrudRepositoryProvider);
          final rolesAsignados = _userRoles.map((r) {
            final int idRol = r["id"];
            return {
              "id_rol": idRol,
              "titulo_profesional": _tituloCtrls[idRol]?.text.trim(),
              "institucion_titulo": _instCtrls[idRol]?.text.trim(),
            };
          }).toList();

          await repo.updateMyProfile(
            nombreCompleto: "$nombres $apellidos",
            username: username,
            email: email,
            cedula: _cedulaController.text,
            telefono: _telefonoController.text,
            direccion: _direccionController.text,
            rolesAsignados: rolesAsignados.isNotEmpty ? rolesAsignados : null,
          );
        },
      ),
    );

    if (success == true && mounted) {
      ref.invalidate(miPerfilProvider);
      ref.invalidate(usersListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(miPerfilProvider);

    return perfilAsync.when(
      data: (profile) {
        _initializeFields(profile);
        final String role = (profile["titulo_profesional"]?.toString().isNotEmpty == true)
            ? profile["titulo_profesional"].toString()
            : (profile["rol_nombre"]?.toString() ?? "Usuario");
        final activo = profile["activo"] == true;

        return Scaffold(
          backgroundColor: AppTema.grisLienzo,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mi perfil",
                    style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTema.azulPrincipal,
                        letterSpacing: -0.5)),
                Text("Gestiona tu información personal y profesional.",
                    style: GoogleFonts.inter(
                        color: Colors.blueGrey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
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

  Widget _buildAvatarCard(
      Map<String, dynamic> profile, String role, bool activo) {
    final displayUsername = _usernameController.text.trim().isNotEmpty
        ? _usernameController.text.trim()
        : (_emailController.text.contains("@")
            ? _emailController.text.split("@").first
            : "usuario");

    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: AppTema.azulPrincipal.withOpacity(0.1),
            child: Text(
                (_nombresController.text.isNotEmpty
                        ? _nombresController.text[0]
                        : "") +
                    (_apellidosController.text.isNotEmpty
                        ? _apellidosController.text[0]
                        : ""),
                style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTema.azulPrincipal)),
          ),
          const SizedBox(height: 20),
          Text(displayUsername,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("${_nombresController.text} ${_apellidosController.text}",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTema.verdeSalud.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(role,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTema.verdeSalud))),
          if (profile["institucion_titulo"]?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              "Graduado(a) en:",
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500),
            ),
            const SizedBox(height: 2),
            Text(
              profile["institucion_titulo"].toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTema.azulOscuro),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _infoMiniItem(Icons.badge_outlined, "Usuario", displayUsername),
          const SizedBox(height: 12),
          _infoMiniItem(Icons.alternate_email, "Correo", _emailController.text),
          const SizedBox(height: 12),
          _infoMiniItem(Icons.verified_user_outlined, "Estado",
              activo ? "Activo" : "Inactivo"),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Datos personales"),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _buildTextField(
                    controller: _nombresController,
                    label: "Nombres",
                    icon: Icons.person_outline)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildTextField(
                    controller: _apellidosController,
                    label: "Apellidos",
                    icon: Icons.person_outline))
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _buildTextField(
                    controller: _cedulaController,
                    label: "Identificación",
                    icon: Icons.fingerprint)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildTextField(
                    controller: _telefonoController,
                    label: "Teléfono",
                    icon: Icons.phone_android_outlined))
          ]),
          const SizedBox(height: 32),
          _sectionTitle("Acceso"),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _buildTextField(
                    controller: _usernameController,
                    label: "Nombre de usuario",
                    icon: Icons.account_circle_outlined)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildTextField(
                    controller: _emailController,
                    label: "Correo electrónico",
                    icon: Icons.alternate_email))
          ]),
          const SizedBox(height: 32),
          _sectionTitle("Contacto y ubicación"),
          const SizedBox(height: 20),
          _buildTextField(
              controller: _direccionController,
              label: "Dirección",
              icon: Icons.location_on_outlined,
              maxLines: 2),
          if (_userRoles.isNotEmpty) ...[
            const SizedBox(height: 32),
            _sectionTitle("Información Profesional"),
            const SizedBox(height: 20),
            ..._userRoles.map((r) {
              final int idRol = r["id"];
              final String rolNombre = r["nombre"];
              
              IconData roleIcon = Icons.person_rounded;
              final nombreLC = rolNombre.toLowerCase();
              if (nombreLC.contains("admin")) roleIcon = Icons.admin_panel_settings_rounded;
              else if (nombreLC.contains("médico") || nombreLC.contains("medico")) roleIcon = Icons.medical_services_rounded;
              else if (nombreLC.contains("nutricionista")) roleIcon = Icons.restaurant_menu_rounded;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTema.grisLienzo.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTema.verdeSalud.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(roleIcon, size: 16, color: AppTema.verdeSalud),
                        ),
                        const SizedBox(width: 12),
                        Text(rolNombre.toUpperCase(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppTema.azulOscuro, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _tituloCtrls[idRol]!,
                          label: "Título Profesional",
                          icon: Icons.badge_outlined,
                          fillColor: Colors.white,
                        )
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _instCtrls[idRol]!,
                          label: "Institución",
                          icon: Icons.account_balance_outlined,
                          fillColor: Colors.white,
                        )
                      ),
                    ]),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTema.azulPrincipal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0),
            onPressed: _saveProfile,
            icon: const Icon(Icons.save_as_rounded),
            label: Text("Guardar cambios",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
          letterSpacing: 1.2));
  Widget _infoMiniItem(IconData icon, String label, String value) =>
      Row(children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text("$label: ",
            style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey)),
        Expanded(
            child: Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)))
      ]);
  Widget _buildTextField(
          {required TextEditingController controller,
          required String label,
          required IconData icon,
          int maxLines = 1,
          Color? fillColor}) =>
      TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon,
                  size: 20, color: AppTema.azulPrincipal.withOpacity(0.6)),
              labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
              floatingLabelStyle: GoogleFonts.inter(
                  color: AppTema.azulPrincipal, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: fillColor ?? AppTema.grisLienzo.withOpacity(0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTema.azulPrincipal, width: 1)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
}

class _SaveProgressDialog extends StatefulWidget {
  final Future<void> Function() onSave;

  const _SaveProgressDialog({required this.onSave});

  @override
  State<_SaveProgressDialog> createState() => _SaveProgressDialogState();
}

class _SaveProgressDialogState extends State<_SaveProgressDialog> {
  late String _statusText;
  bool _isCompleted = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _statusText = "Actualizando su perfil...";
    _ejecutarGuardado();
  }

  Future<void> _ejecutarGuardado() async {
    await Future.delayed(const Duration(milliseconds: 500));
    bool exito = false;
    try {
      await widget.onSave();
      exito = true;
    } catch (e) {
      exito = false;
    }
    
    if (mounted) {
      setState(() {
        _isCompleted = true;
        _isSuccess = exito;
        _statusText = exito ? "Perfil actualizado" : "Error al guardar";
      });
      
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pop(exito);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isCompleted)
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTema.azulPrincipal),
                  ),
                )
              else if (_isSuccess)
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppTema.verdeSalud,
                  size: 48,
                )
              else
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
              const SizedBox(height: 20),
              Text(
                _statusText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTema.azulOscuro,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
