import "dart:math" as math;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../../core/theme/app_theme.dart";
import "../../core/theme/app_sizes.dart";
import "../../core/theme/app_responsive.dart";


// Ruta de los logos
const String kLogoConNombre = "assets/images/logo 1.png";
const String kLogoSinNombre = "assets/images/logo sin.png";

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
        email: email, password: password,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Credenciales incorrectas o error de acceso");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  painter: _ProfessionalBackgroundPainter(value: _animController.value),
                );
              },
            ),
          ),

          // 2. Contenido
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveSpacing(AppSpacing.lg),
                  vertical: context.responsiveSpacing(AppSpacing.xl),
                ),
                child: ResponsiveMaxConstraints(
                  maxWidth: 1300,
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 10, child: _buildBrandPanel(context)),
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
                            const SizedBox(height: AppSpacing.xxl),
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

  Widget _buildBrandPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.montserrat(
              fontSize: context.responsiveValue(mobile: 32, tablet: 40, desktop: 48),
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -1.5,
            ),
            children: const [
              TextSpan(text: "Nutri", style: TextStyle(color: _azul)),
              TextSpan(text: "Reuma", style: TextStyle(color: _verde)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "Portal Profesional de Salud",
          style: GoogleFonts.lato(
              fontSize: AppTextSizes.headline(context.screenWidth) * 0.7, 
              color: _grisTexto, 
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: 80,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(colors: [_azul, _verde]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: 480,
          child: Text(
            "Plataforma avanzada para la evaluación nutricional y seguimiento clínico pediátrico en reumatología.",
            style: GoogleFonts.lato(
                fontSize: AppTextSizes.bodyLarge(context.screenWidth),
                color: _grisTexto,
                height: 1.4,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _buildFeatureCard(context, Icons.analytics_outlined, "Evaluación\nEspecializada", _verde),
            _buildFeatureCard(context, Icons.monitor_heart_outlined, "Seguimiento\nClínico", _azul),
            _buildFeatureCard(context, Icons.security_outlined, "Acceso\nAutorizado", _verde),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, IconData icon, String title, Color accent) {
    return Container(
      width: context.responsiveValue(mobile: 130, tablet: 140),
      height: context.responsiveValue(mobile: 135, tablet: 145),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _azulOscuro, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: AppTextSizes.caption(context.screenWidth) * 1.2, 
              fontWeight: FontWeight.w700, 
              color: _azulOscuro, 
              height: 1.2
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(width: 30, height: 3, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.montserrat(
              fontSize: AppTextSizes.headline(context.screenWidth), 
              fontWeight: FontWeight.w800
            ),
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
          width: AppSizes.maxFormWidth,
          padding: EdgeInsets.fromLTRB(
            context.responsiveSpacing(AppSpacing.xl),
            context.responsiveSpacing(AppSpacing.xxl + 10),
            context.responsiveSpacing(AppSpacing.xl),
            context.responsiveSpacing(AppSpacing.xl),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius + 8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Bienvenido/a",
                  style: GoogleFonts.montserrat(
                      fontSize: AppTextSizes.headline(context.screenWidth) * 0.9,
                      fontWeight: FontWeight.w800,
                      color: _azulOscuro,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text("Acceso al Portal Profesional",
                  style: GoogleFonts.lato(
                    fontSize: AppTextSizes.body(context.screenWidth), 
                    color: _grisTexto
                  )),
              const SizedBox(height: AppSpacing.md),
              Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                      color: _verde, borderRadius: BorderRadius.circular(2))),
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
                          style: GoogleFonts.lato(
                              color: Colors.red.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _buildField(
                  context: context,
                  controller: _emailController,
                  label: "CORREO ELECTRÓNICO",
                  hint: "usuario@clinica.com",
                  icon: Icons.mail_outline),
              const SizedBox(height: AppSpacing.lg),
              _buildField(
                  context: context,
                  controller: _passwordController,
                  label: "CONTRASEÑA",
                  hint: "••••••••",
                  icon: Icons.lock_outline,
                  isPass: true),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeightLarge,
                child: FilledButton(
                  onPressed: _loading ? null : _handleLogin,
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
                          "INGRESAR",
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {},
                child: Text(
                  "¿Olvidó su contraseña?",
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: _azul,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -55,
          child: Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child:
                ClipOval(child: Image.asset(kLogoSinNombre, fit: BoxFit.contain)),
          ),
        ),
      ],
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
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _azulOscuro,
              letterSpacing: 0.5,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPass && _obscurePassword,
          style: GoogleFonts.lato(
            fontSize: AppTextSizes.body(context.screenWidth), 
            color: _grisFuerte, 
            fontWeight: FontWeight.w600
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 22),
            suffixIcon: isPass 
                ? IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ) 
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
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
      ..cubicTo(size.width * 0.5, size.height * 0.3, size.width * 0.7, size.height * 0.7, size.width * 0.5, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(pathWhite, paintWhite);

    // 2. DETALLE VERDE (FONDO)
    final paintGreen = Paint()..color = const Color(0xFF58A932).withOpacity(0.9);
    final pathGreen = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.1, size.height * 0.75, size.width * 0.3, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(pathGreen, paintGreen);

    // 3. CAPA AZUL (ENCIMA DE TODO - DIBUJADA AL FINAL)
    final paintBlue = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF008BD2), Color(0xFF0068B7), Color(0xFF00579D)],
      ).createShader(Rect.fromLTWH(size.width * 0.45, 0, size.width * 0.55, size.height));

    final pathBlue = Path()
      ..moveTo(size.width * (0.45 + float * 0.01), 0) // Inicia sobre la capa blanca
      ..cubicTo(size.width * 0.6, size.height * 0.2, size.width * 0.4, size.height * 0.6, size.width * (0.5 + float * 0.02), size.height)
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
      
      double pSize = (i % 3 == 0) ? (30.0 + random.nextDouble() * 10.0) : (10.0 + random.nextDouble() * 5.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: pSize, height: pSize), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ProfessionalBackgroundPainter oldDelegate) => true;
}
