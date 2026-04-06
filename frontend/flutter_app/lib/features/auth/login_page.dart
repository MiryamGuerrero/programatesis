import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _mintStrong = Color(0xFF4CAF50);
  static const Color _mintSoft = Color(0xFF81C784);
  static const Color _coral = Color(0xFFFF7043);
  static const Color _turquoise = Color(0xFF4DD0E1);
  static const Color _backgroundCream = Color(0xFFFFFDF7);
  static const Color _slateText = Color(0xFF37474F);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
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
          final bool isWide = constraints.maxWidth >= 920;

          return Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF5FFF8),
                        Color(0xFFE7F8FB),
                        Color(0xFFFFFBF5),
                      ],
                    ),
                  ),
                ),
              ),
              const _DecorativeBlob(
                top: -90,
                right: -70,
                size: 260,
                colors: [
                  Color(0xFF81C784),
                  Color(0xFF4DD0E1),
                ],
              ),
              const _DecorativeBlob(
                bottom: -100,
                left: -60,
                size: 290,
                colors: [
                  Color(0xFFFFA284),
                  Color(0xFFFF7043),
                ],
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 28 : 16,
                      vertical: 24,
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 16),
                            child: child,
                          ),
                        );
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 980 : 470,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _backgroundCream.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x292A3D47),
                                blurRadius: 36,
                                offset: Offset(0, 16),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                          child: isWide
                              ? Row(
                                  children: [
                                    Expanded(
                                        child: _buildShowcasePanel(context)),
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBrandHeader(context),
          const SizedBox(height: 22),
          _buildLoginForm(context, includeTitle: false),
        ],
      ),
    );
  }

  Widget _buildShowcasePanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 34, 30, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildBrandHeader(context),
          const SizedBox(height: 28),
          const _FeatureBullet(
            icon: Icons.eco_rounded,
            title: "Recetas antiinflamatorias",
            description:
                "Combinaciones saludables pensadas para bienestar diario.",
            iconColor: _mintStrong,
          ),
          const SizedBox(height: 14),
          const _FeatureBullet(
            icon: Icons.favorite_rounded,
            title: "Seguimiento facil",
            description: "Controla avances nutricionales en un solo lugar.",
            iconColor: _coral,
          ),
          const SizedBox(height: 14),
          const _FeatureBullet(
            icon: Icons.water_drop_rounded,
            title: "Experiencia clara",
            description: "Visualizacion simple para familias y especialistas.",
            iconColor: _turquoise,
          ),
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
        border: Border.all(color: _mintSoft.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF81C784),
                  Color(0xFF4CAF50),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.spa_rounded, color: Colors.white, size: 28),
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
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Nutricion inteligente para crecer mejor",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _slateText.withValues(alpha: 0.75),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, {bool includeTitle = true}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
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
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              "Accede para gestionar planes, recetas y seguimiento nutricional.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _slateText.withValues(alpha: 0.74),
                  ),
            ),
            const SizedBox(height: 20),
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _loading ? null : _signIn,
              style: FilledButton.styleFrom(
                backgroundColor: _mintStrong,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _loading
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
                _loading ? "Ingresando..." : "Ingresar",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _coral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _coral.withValues(alpha: 0.4)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFB4452D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _slateText.withValues(alpha: 0.75)),
      prefixIcon: Icon(icon, color: _turquoise.withValues(alpha: 0.95)),
      filled: true,
      fillColor: const Color(0xFFF9F9F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: _mintSoft.withValues(alpha: 0.45), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _mintStrong, width: 1.8),
      ),
    );
  }
}

class _DecorativeBlob extends StatelessWidget {
  const _DecorativeBlob({
    required this.size,
    required this.colors,
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  final double size;
  final List<Color> colors;
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
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
          ),
        ),
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
                      color: const Color(0xFF37474F),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF37474F).withValues(alpha: 0.8),
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
