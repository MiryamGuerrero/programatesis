import "dart:math" as math;
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:http/http.dart" as http;
import "package:supabase_flutter/supabase_flutter.dart";

import "../../core/config/app_config.dart";
import "../../core/state/app_providers.dart";
import "../../shared/models/app_role.dart";
import "../../shared/widgets/role_shell.dart";

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  static const Color _mintStrong = Color(0xFF0D9488);
  static const Color _mintDeep = Color(0xFF0F766E);
  static const Color _mintSoft = Color(0xFFA7D8D1);
  static const Color _coral = Color(0xFF991B1B);
  static const Color _turquoise = Color(0xFFFB923C);
  static const Color _backgroundCream = Color(0xFFF8FAFC);
  static const Color _slateText = Color(0xFF334155);
  static const Color _slateMuted = Color(0xFF64748B);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _ambientController;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = "Ingresa tu correo y contrasena para continuar.";
      });
      return;
    }

    ref.read(authErrorProvider.notifier).state = null;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final signedSession = Supabase.instance.client.auth.currentSession;
      if (signedSession == null) {
        setState(() {
          _error = "Sesion iniciada, pero no se pudo obtener contexto de acceso.";
        });
        return;
      }

      await _openRoleShellAfterSignIn(signedSession);
    } on AuthException catch (error) {
      setState(() {
        _error = _friendlyAuthMessage(error.message);
      });
    } catch (_) {
      setState(() {
        _error =
            "No fue posible iniciar sesion en este momento. Intenta de nuevo.";
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openRoleShellAfterSignIn(Session session) async {
    final role = await _resolveRoleForSession(session);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => RoleShell(role: role),
      ),
      (_) => false,
    );
  }

  Future<AppRole> _resolveRoleForSession(Session session) async {
    final metadataCandidates = <dynamic>[
      session.user.appMetadata["role"],
      session.user.appMetadata["rol"],
      session.user.appMetadata["id_rol"],
      session.user.userMetadata?["role"],
      session.user.userMetadata?["rol"],
      session.user.userMetadata?["id_rol"],
    ];

    for (final candidate in metadataCandidates) {
      final parsed = tryParseRole(candidate);
      if (parsed != null) {
        return parsed;
      }
    }

    try {
      final response = await http.get(
        Uri.parse("${AppConfig.fastApiBaseUrl}/auth-context"),
        headers: {
          "Authorization": "Bearer ${session.accessToken}",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final parsed = tryParseRole(data["role"]);
          if (parsed != null) {
            return parsed;
          }
        }
      }
    } catch (_) {
      // Fall back to default role if backend context is temporarily unavailable.
    }

    return AppRole.tutor;
  }

  String _friendlyAuthMessage(String rawMessage) {
    final normalized = rawMessage.toLowerCase();

    if (normalized.contains("invalid login credentials") ||
        normalized.contains("invalid credentials") ||
        normalized.contains("wrong password") ||
        normalized.contains("user not found") ||
        normalized.contains("password")) {
      return "Usuario o contrasena incorrectos. Verifica tus datos e intenta de nuevo.";
    }

    if (normalized.contains("email not confirmed")) {
      return "Tu correo aun no esta confirmado. Revisa tu bandeja de entrada.";
    }

    if (normalized.contains("network") || normalized.contains("timeout")) {
      return "No hay conexion con el servidor. Revisa internet e intenta otra vez.";
    }

    return "No se pudo iniciar sesion. Intenta nuevamente.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundCream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 980;
          final bool denseVertical = constraints.maxHeight < 760;
          final availableHeight = constraints.maxHeight - 32;
          final panelHeight =
              availableHeight.clamp(500.0, isWide ? 640.0 : 680.0);

          return Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF8FAFC),
                        Color(0xFFF4FAF9),
                        Color(0xFFFFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _ambientController,
                builder: (context, _) {
                  final wave = math.sin(_ambientController.value * 2 * math.pi);
                  return _BackdropRibbon(
                    top: -46 + (wave * 12),
                    left: -120,
                    width: 420,
                    height: 120,
                    angle: -0.08 + (wave * 0.015),
                    color: const Color(0x200D9488),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _ambientController,
                builder: (context, _) {
                  final wave = math.cos(_ambientController.value * 2 * math.pi);
                  return _BackdropRibbon(
                    bottom: -54 + (wave * 10),
                    right: -160,
                    width: 500,
                    height: 140,
                    angle: 0.1 + (wave * 0.012),
                    color: const Color(0x1FFB923C),
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 28 : 16,
                    vertical: 16,
                  ),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 18),
                            child: child,
                          ),
                        );
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 1020 : 470,
                        ),
                        child: SizedBox(
                          height: panelHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDFEFF).withValues(alpha: 0.97),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1E0F2D46),
                                  blurRadius: 44,
                                  offset: Offset(0, 22),
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: isWide
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: _buildShowcasePanel(
                                          context,
                                          dense: denseVertical,
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        color: _slateText.withValues(alpha: 0.08),
                                      ),
                                      SizedBox(
                                        width: 420,
                                        child: _buildLoginForm(context),
                                      ),
                                    ],
                                  )
                                : _buildCompactLayout(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBrandHeader(context),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _mintSoft.withValues(alpha: 0.45)),
              ),
              child: Text(
                "Nutricion clinica pediatrica con seguimiento continuo y coordinacion por roles.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _slateMuted,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            _buildLoginForm(context, includeTitle: false, compact: true),
          ],
        ),
      ),
    );
  }

  Widget _buildShowcasePanel(BuildContext context, {required bool dense}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        dense ? 28 : 34,
        dense ? 26 : 34,
        dense ? 24 : 30,
        dense ? 24 : 34,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildBrandHeader(context),
          SizedBox(height: dense ? 16 : 22),
          Container(
            padding: EdgeInsets.all(dense ? 14 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _mintSoft.withValues(alpha: 0.38)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Entorno profesional sin friccion",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _slateText,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Evaluacion alimentaria, control antropometrico y planes de intervencion en un flujo unico.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _slateMuted,
                        height: 1.3,
                      ),
                ),
                SizedBox(height: dense ? 10 : 14),
                const Row(
                  children: [
                    Expanded(
                      child: _MetricChip(
                        value: "RLS",
                        label: "Seguridad activa",
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _MetricChip(
                        value: "24/7",
                        label: "Acceso web",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: dense ? 12 : 16),
          const _FeatureBullet(
            icon: Icons.restaurant_rounded,
            title: "Protocolos nutricionales",
            description:
                "Planes alimentarios y registro dietetico con criterio profesional.",
            iconColor: _mintStrong,
          ),
          SizedBox(height: dense ? 10 : 14),
          const _FeatureBullet(
            icon: Icons.straighten_rounded,
            title: "Control antropometrico",
            description:
                "Seguimiento de evolucion para decisiones nutricionales mas precisas.",
            iconColor: _turquoise,
          ),
          if (!dense) ...[
            const SizedBox(height: 14),
            const _FeatureBullet(
              icon: Icons.groups_2_rounded,
              title: "Equipo multidisciplinario",
              description:
                  "Admin, medico, nutricionista y tutor coordinados por paciente.",
              iconColor: _mintStrong,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _mintSoft.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E3554),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F766E),
                  Color(0xFF0D9488),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Reuma Nutri",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _slateText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Gestion nutricional pediatrica",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _slateMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(
    BuildContext context, {
    bool includeTitle = true,
    bool compact = false,
  }) {
    final globalError = ref.watch(authErrorProvider);
    final displayError = _error ?? globalError;
    final isProcessing = _loading;

    final formContent = Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(8, 6, 8, 0)
          : const EdgeInsets.fromLTRB(28, 28, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (includeTitle) ...[
            Text(
              "Iniciar sesion",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _slateText,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              "Accede al sistema de clinica nutricional.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _slateMuted,
                    height: 1.35,
                  ),
            ),
            SizedBox(height: compact ? 14 : 20),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style:
                const TextStyle(color: _slateText, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(
              label: "Correo",
              icon: Icons.alternate_email_rounded,
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style:
                const TextStyle(color: _slateText, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(
              label: "Contrasena",
              icon: Icons.lock_outline_rounded,
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
          SizedBox(
            height: compact ? 50 : 54,
            child: FilledButton.icon(
              onPressed: isProcessing ? null : _signIn,
              style: FilledButton.styleFrom(
                backgroundColor: _mintDeep,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
                icon: isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                isProcessing ? "Ingresando..." : "Ingresar",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (displayError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _coral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _coral.withValues(alpha: 0.4)),
              ),
              child: Text(
                displayError,
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (compact) {
      return formContent;
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: formContent,
    );
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _slateMuted),
      prefixIcon: Icon(icon, color: _mintStrong.withValues(alpha: 0.95)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: _mintSoft.withValues(alpha: 0.7), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _mintDeep, width: 1.8),
      ),
    );
  }
}

class _BackdropRibbon extends StatelessWidget {
  const _BackdropRibbon({
    required this.width,
    required this.height,
    required this.angle,
    required this.color,
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  final double width;
  final double height;
  final double angle;
  final Color color;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: angle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.all(Radius.circular(28)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140C3652),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: SizedBox(width: width, height: height),
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF0D9488),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF1E2F3D),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF1E2F3D).withValues(alpha: 0.8),
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
