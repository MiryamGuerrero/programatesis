import '../../shared/widgets/layout_components.dart';
import "dart:math" as math;
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../../core/theme/app_theme.dart";
import "../../core/theme/app_sizes.dart";
import "../../core/theme/app_responsive.dart";

// Ruta de los logos
const String kLogoConNombre = "assets/images/logo_reuma_nutri.png";
const String kLogoSinNombre = "assets/images/logo_reuma_nutri.png";

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _animController;

  static const Color _azul = AppTema.azulPrincipal;
  static const Color _azulOscuro = AppTema.azulOscuro;
  static const Color _verde = AppTema.verdeSalud;
  static const Color _grisTexto = Color(0xFF64748B);
  static const Color _grisFuerte = Color(0xFF334155);
  static const Color _borde = Color(0xFFD7E1EA);
  static const Color _fondo = AppTema.grisFondo;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _errorMessage = null);

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Ingrese sus credenciales");
      return;
    }

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = "Credenciales incorrectas o error de acceso");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroidApp =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroidApp) return _buildAndroidLogin(context);

    final bool isWide = !context.isMobile && !context.isMobileSmall;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Pintor de Fondo
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (_, __) {
                return CustomPaint(
                  painter: _ProfessionalBackgroundPainter(
                      value: _animController.value),
                );
              },
            ),
          ),

          // 2. Contenido
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.responsiveSpacing(AppSpacing.lg),
                  context.responsiveSpacing(AppSpacing.xxl) + 60.0,
                  context.responsiveSpacing(AppSpacing.lg),
                  context.responsiveSpacing(AppSpacing.xxl),
                ),
                child: ResponsiveMaxConstraints(
                  maxWidth: 1300,
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                                flex: 10, child: _buildBrandPanel(context)),
                            const SizedBox(width: AppSpacing.xl),
                            Expanded(
                              flex: 10,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildLoginCard(context),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildMobileHeader(context),
                            const SizedBox(height: 140.0),
                            _buildLoginCard(context),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (_, __) {
                return CustomPaint(
                  painter: _ProfessionalBackgroundPainter(
                    value: _animController.value,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveSpacing(AppSpacing.lg),
                  vertical: context.responsiveSpacing(AppSpacing.xl),
                ),
                child: Column(
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: _buildMobileHeader(
                        context,
                        emphasized: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildLoginCard(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize:
                  context.responsiveValue(mobile: 32, tablet: 40, desktop: 48),
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.5,
            ),
            children: const [
              TextSpan(text: "Nutri", style: TextStyle(color: _azul)),
              TextSpan(text: "Reuma", style: TextStyle(color: _verde)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Portal profesional de salud",
          style: GoogleFonts.inter(
              fontSize: 18,
              color: _grisTexto,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 30,
              height: 4,
              decoration: const BoxDecoration(
                color: _azul,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                ),
              ),
            ),
            Container(
              width: 30,
              height: 4,
              decoration: const BoxDecoration(
                color: _verde,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 480,
          child: Text(
            "Plataforma avanzada para la evaluación nutricional y seguimiento clínico pediátrico en reumatología.",
            style: GoogleFonts.inter(
                fontSize: 16,
                color: _grisTexto,
                height: 1.5,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 48),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildFeatureCard(context, Icons.insert_chart_outlined_rounded,
                "Evaluación especializada", _verde),
            _buildFeatureCard(context, Icons.monitor_heart_outlined,
                "Seguimiento clínico", _azul),
            _buildFeatureCard(
                context, Icons.shield_outlined, "Acceso autorizado", _verde),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, IconData icon, String title, Color accent) {
    return Container(
      width: 140,
      height: 130,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _azulOscuro, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _azulOscuro,
                height: 1.2),
          ),
          const SizedBox(height: 12),
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context, {
    bool emphasized = false,
  }) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.montserrat(
                fontSize: emphasized
                    ? 38
                    : AppTextSizes.headline(context.screenWidth),
                fontWeight: FontWeight.w800),
            children: const [
              TextSpan(text: "Nutri", style: TextStyle(color: _azul)),
              TextSpan(text: "Reuma", style: TextStyle(color: _verde)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: 440,
          constraints: const BoxConstraints(maxWidth: 440),
          padding: EdgeInsets.fromLTRB(
            28,
            context.responsiveValue(mobile: 80, tablet: 85, desktop: 90),
            28,
            28,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 35,
                  offset: const Offset(0, 15)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Bienvenido/a",
                  style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _azulOscuro,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text("Acceso al portal profesional",
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _grisTexto)),
              const SizedBox(height: 16),
              Container(
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                      color: _verde, borderRadius: BorderRadius.circular(1.5))),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                              color: Colors.red.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _buildField(
                  context: context,
                  controller: _emailController,
                  label: "Correo electrónico",
                  hint: "usuario@nutrireuma.com",
                  icon: Icons.mail_outline),
              const SizedBox(height: 20),
              _buildField(
                  context: context,
                  controller: _passwordController,
                  label: "Contraseña",
                  hint: "Ingresar su contraseña",
                  icon: Icons.lock_outline,
                  isPass: true),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: _azul,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          "Ingresar",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _olvidoContrasena,
                child: Text(
                  "¿Olvidó su contraseña?",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -85,
          child: Container(
            width: 150,
            height: 150,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Image.asset(
              kLogoSinNombre,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _olvidoContrasena() async {
    final emailCtrl = TextEditingController();
    bool enviando = false;

    await showDialog(
      context: context,
      barrierColor: const Color(0xFF0F172A).withOpacity(0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 356,
            constraints: const BoxConstraints(maxWidth: 356),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5EAF2)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF64748B),
                    iconSize: 22,
                    tooltip: "Cerrar",
                    splashRadius: 20,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 2),
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTema.azulPrincipal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          color: AppTema.azulPrincipal,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Recuperar contraseña",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        color: AppTema.azulOscuro,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Ingresa tu correo electrónico y te enviaremos un enlace para configurar tu nueva contraseña.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8A97AD),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: emailCtrl,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTema.azulOscuro,
                        ),
                        decoration: InputDecoration(
                          hintText: "Correo electrónico",
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF98A2B3),
                          ),
                          prefixIcon: const Icon(Icons.mail_outline,
                              size: 19, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFFE1E7F0), width: 1.4),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AppTema.azulPrincipal, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: enviando
                            ? null
                            : () async {
                                final correo = emailCtrl.text.trim();
                                if (correo.isEmpty) return;
                                setDialogState(() => enviando = true);
                                try {
                                  await Supabase.instance.client.auth
                                      .resetPasswordForEmail(
                                    correo,
                                    redirectTo: kIsWeb
                                        ? Uri.base.origin
                                        : 'reumanutri://auth/set-password',
                                  );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    NutriSnack.show(context,
                                        "Se ha enviado un correo con las instrucciones.");
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    NutriSnack.show(context,
                                        "Error: No se pudo enviar el correo.",
                                        isError: true);
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setDialogState(() => enviando = false);
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTema.azulPrincipal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        child: Text(enviando ? "Enviando..." : "Enviar enlace"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPass = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _azulOscuro,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPass && _obscurePassword,
          style: GoogleFonts.inter(
              fontSize: 14,
              color: _grisFuerte,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey.shade400),
            suffixIcon: isPass
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.blueGrey.shade400,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _azul, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _ProfessionalBackgroundPainter extends CustomPainter {
  final double value;
  _ProfessionalBackgroundPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final float = math.sin(value * 2 * math.pi);

    // 1. CAPA BLANCA (FONDO - DIBUJADA PRIMERO)
    final paintWhite = Paint()..color = const Color(0xFFF8FAFD);
    final pathWhite = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.6, 0)
      ..cubicTo(size.width * 0.5, size.height * 0.3, size.width * 0.7,
          size.height * 0.7, size.width * 0.5, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(pathWhite, paintWhite);

    // 2. DETALLE VERDE (FONDO)
    final paintGreen = Paint()
      ..color = const Color(0xFF58A932).withOpacity(0.9);
    final pathGreen = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
          size.width * 0.1, size.height * 0.75, size.width * 0.3, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(pathGreen, paintGreen);

    // 3. CAPA AZUL (ENCIMA DE TODO - DIBUJADA AL FINAL)
    final paintBlue = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF008BD2), Color(0xFF0068B7), Color(0xFF00579D)],
      ).createShader(
          Rect.fromLTWH(size.width * 0.45, 0, size.width * 0.55, size.height));

    final pathBlue = Path()
      ..moveTo(
          size.width * (0.45 + float * 0.01), 0) // Inicia sobre la capa blanca
      ..cubicTo(size.width * 0.6, size.height * 0.2, size.width * 0.4,
          size.height * 0.6, size.width * (0.5 + float * 0.02), size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(pathBlue, paintBlue);

    // 4. CUADRITOS DINÁMICOS (POR ENCIMA DEL AZUL)
    _drawFloatingSquares(canvas, size);
  }

  void _drawFloatingSquares(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final random = math.Random(42);

    for (int i = 0; i < 20; i++) {
      double baseX = size.width * (0.52 + random.nextDouble() * 0.43);
      double baseY = size.height * random.nextDouble();

      double x = baseX + math.sin(value * 2 * math.pi + i) * 10;
      double y = baseY + math.cos(value * 2 * math.pi + i) * 12;
      double rotation = value * 2 * math.pi * (i % 2 == 0 ? 1 : -1) * 0.1;

      double pSize = (i % 3 == 0)
          ? (30.0 + random.nextDouble() * 10.0)
          : (10.0 + random.nextDouble() * 5.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: pSize, height: pSize),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ProfessionalBackgroundPainter oldDelegate) =>
      true;
}
