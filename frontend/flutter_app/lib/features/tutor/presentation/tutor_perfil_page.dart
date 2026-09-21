import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:shimmer/shimmer.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "../../../core/theme/app_sizes.dart";
import "../../../core/theme/app_responsive.dart";
import "../../../core/services/notification_service.dart";
import "../../../shared/widgets/error_conexion_widget.dart";
import "../../auth/login_page.dart";
import "widgets/cerrar_sesion_dialog.dart";

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
    _emailController.text = profile["email"]?.toString() ?? "";
    _cedulaController.text = profile["cedula"]?.toString() ?? "";
    _telefonoController.text = profile["telefono"]?.toString() ?? "";
    _direccionController.text = profile["direccion"]?.toString() ?? "";
    _initialized = true;
  }

  Future<void> _onRefreshPage() async {
    _initialized = false;
    ref.invalidate(miPerfilProvider);
    await ref.read(miPerfilProvider.future);
  }

  Widget _buildPerfilShimmer(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _onRefreshPage,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ResponsiveMaxConstraints(
          maxWidth: 800,
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFCBD5E1),
            highlightColor: const Color(0xFFF8FAFC),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 160,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 90,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.responsiveSpacing(AppSpacing.md),
                    vertical: context.responsiveSpacing(AppSpacing.xl),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 380,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        height: 52,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        height: 52,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final nombres = _nombresController.text.trim();
    final apellidos = _apellidosController.text.trim();
    final email = _emailController.text.trim();

    if (nombres.isEmpty || apellidos.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Por favor, completa los campos obligatorios")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.updateMyProfile(
        nombreCompleto: "$nombres $apellidos",
        email: email,
        cedula: _cedulaController.text.trim(),
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
      );

      if (!mounted) return;
      _initialized = false;
      ref.invalidate(miPerfilProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perfil actualizado con éxito")),
      );
    } catch (error) {
      if (mounted) {
        String errorMsg = error.toString();
        if (error is DioException && error.response?.data != null) {
          final data = error.response?.data;
          if (data is Map && data.containsKey("detail")) {
            errorMsg = data["detail"].toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error al guardar: $errorMsg"),
              backgroundColor: Colors.red),
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

    if (perfilAsync.isLoading && !perfilAsync.hasValue) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: _buildPerfilShimmer(context),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: perfilAsync.when(
        data: (profile) {
          _initializeFields(profile);
          final String parentesco =
              profile["parentesco"]?.toString() ?? "Tutor";
          final String iniciales = (_nombresController.text.isNotEmpty
                  ? _nombresController.text[0]
                  : "") +
              (_apellidosController.text.isNotEmpty
                  ? _apellidosController.text[0]
                  : "");

          return RefreshIndicator(
            onRefresh: _onRefreshPage,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ResponsiveMaxConstraints(
                maxWidth: 800,
                child: Column(
                  children: [
                    _buildProfileHeader(context, iniciales, parentesco),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.responsiveSpacing(AppSpacing.md),
                          vertical: context.responsiveSpacing(AppSpacing.xl)),
                      child: Column(
                        children: [
                          _buildFormCard(context),
                          const SizedBox(height: AppSpacing.lg),
                          _buildSaveButton(context),
                          const SizedBox(height: 36),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  color: Color(0xFFE2E8F0),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  "CUENTA Y SESIÓN",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: Color(0xFFE2E8F0),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildLogoutButton(context),
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => _buildPerfilShimmer(context),
        error: (e, _) => RefreshIndicator(
          onRefresh: _onRefreshPage,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              child: ErrorConexionWidget(
                error: e,
                onRetry: _onRefreshPage,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, String iniciales, String parentesco) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
          top: context.responsiveSpacing(40),
          bottom: context.responsiveSpacing(40)),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: context.responsiveValue(mobile: 50, tablet: 70),
            backgroundColor: colorScheme.primary,
            child: Text(
              iniciales.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: context.responsiveValue(mobile: 32, tablet: 48),
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "${_nombresController.text} ${_apellidosController.text}",
            style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: AppTextSizes.headline(context.screenWidth) * 0.8,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              parentesco.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  letterSpacing: 1,
                  fontSize: AppTextSizes.caption(context.screenWidth)),
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
            _buildField(context, "Nombres", _nombresController,
                Icons.person_outline_rounded),
            const SizedBox(height: 20),
            _buildField(context, "Apellidos", _apellidosController,
                Icons.person_outline_rounded),
            const SizedBox(height: 20),
            _buildField(
                context,
                "Cédula / ID (10 dígitos)",
                _cedulaController,
                Icons.badge_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]),
            const SizedBox(height: 20),
            _buildField(
                context,
                "Teléfono (10 dígitos)",
                _telefonoController,
                Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(height: 1),
            ),
            _buildSectionTitle(context, "Cuenta y Contacto"),
            const SizedBox(height: 24),
            _buildField(context, "Correo Electrónico", _emailController,
                Icons.alternate_email_rounded,
                enabled: false),
            const SizedBox(height: 20),
            _buildField(context, "Dirección", _direccionController,
                Icons.location_on_outlined,
                maxLines: 2),
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

  Widget _buildField(BuildContext context, String label,
      TextEditingController controller, IconData icon,
      {bool enabled = true,
      int maxLines = 1,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
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
      child: FilledButton.icon(
        onPressed: _saving ? null : _saveProfile,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.2),
              )
            : const Icon(Icons.check_circle_outline_rounded, size: 20),
        label: Text(
          _saving ? "GUARDANDO..." : "GUARDAR CAMBIOS",
          style: GoogleFonts.montserrat(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppTema.azulPrincipal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: AppTema.azulPrincipal.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleSignOut,
        icon:
            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
        label: Text(
          "CERRAR SESIÓN",
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          backgroundColor: const Color(0xFFFEF2F2),
          side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await showCerrarSesionDialog(context);

    if (confirm == true) {
      try {
        await ref.read(notificationServiceProvider).cancelarTodasLasNotificaciones();
      } catch (_) {}
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
