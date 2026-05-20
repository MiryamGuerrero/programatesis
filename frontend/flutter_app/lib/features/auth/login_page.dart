import "dart:math" as math;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";


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

  static const Color _azul = Color(0xFF0068B7);
  static const Color _azulOscuro = Color(0xFF123D66);
  static const Color _verde = Color(0xFF58A932);
  static const Color _grisTexto = Color(0xFF64748B);
  static const Color _grisFuerte = Color(0xFF334155);
  static const Color _borde = Color(0xFFD7E1EA);
  static const Color _fondo = Color(0xFFF6FAFD);

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
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 1050;

    return Scaffold(
      backgroundColor: Colors.white, // Fondo base sólido
      body: Stack(
        children: [
          // 1. Pintor de Fondo (Capas superpuestas)
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
                  horizontal: isWide ? 60 : 24,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1300),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 10, child: _buildBrandPanel()),
                            const SizedBox(width: 40),
                            Expanded(
                              flex: 10, 
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildLoginCard(),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildMobileHeader(),
                            const SizedBox(height: 60),
                            _buildLoginCard(),
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

  Widget _buildBrandPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(kLogoSinNombre, width: 120, height: 120, fit: BoxFit.contain),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.montserrat(
                        fontSize: 48, fontWeight: FontWeight.w800, height: 1, letterSpacing: -1.5,
                      ),
                      children: const [
                        TextSpan(text: "Nutri", style: TextStyle(color: _azul)),
                        TextSpan(text: "Reuma", style: TextStyle(color: _verde)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Portal Profesional de Salud",
                    style: GoogleFonts.lato(fontSize: 22, color: _grisTexto, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          width: 80, height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(colors: [_azul, _verde]),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: 480,
          child: Text(
            "Plataforma avanzada para la evaluación nutricional y seguimiento clínico pediátrico en reumatología.",
            style: GoogleFonts.lato(fontSize: 20, color: _grisTexto, height: 1.4, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 48),
        Wrap(
          spacing: 16, runSpacing: 16,
          children: [
            _buildFeatureCard(Icons.analytics_outlined, "Evaluación\nEspecializada", _verde),
            _buildFeatureCard(Icons.monitor_heart_outlined, "Seguimiento\nClínico", _azul),
            _buildFeatureCard(Icons.security_outlined, "Acceso\nAutorizado", _verde),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, Color accent) {
    return Container(
      width: 140, height: 145,
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _azulOscuro, height: 1.2),
          ),
          const SizedBox(height: 12),
          Container(width: 30, height: 3, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        Image.asset(kLogoSinNombre, width: 110, fit: BoxFit.contain),
        const SizedBox(height: 20),
        RichText(
          text: TextSpan(
            style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w800),
            children: const [
              TextSpan(text: "Nutri", style: TextStyle(color: _azul)),
              TextSpan(text: "Reuma", style: TextStyle(color: _verde)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: 440,
          padding: const EdgeInsets.fromLTRB(40, 70, 40, 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Bienvenido/a", style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w800, color: _azulOscuro, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text("Acceso al Portal Profesional", style: GoogleFonts.lato(fontSize: 16, color: _grisTexto)),
              const SizedBox(height: 20),
              Container(width: 40, height: 3, decoration: BoxDecoration(color: _verde, borderRadius: BorderRadius.circular(2))),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.lato(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              _buildField(controller: _emailController, label: "CORREO ELECTRÓNICO", hint: "usuario@clinica.com", icon: Icons.mail_outline),
              const SizedBox(height: 24),
              _buildField(controller: _passwordController, label: "CONTRASEÑA", hint: "••••••••", icon: Icons.lock_outline, isPass: true),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _loading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          "INGRESAR",
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
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
            width: 100, height: 100,
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
            child: ClipOval(child: Image.asset(kLogoSinNombre, fit: BoxFit.contain)),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
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
          style: GoogleFonts.lato(fontSize: 16, color: _grisFuerte, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 22),
            suffixIcon: isPass 
                ? IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ) 
                : null,
            filled: true,
            fillColor: _fondo,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borde),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _azul, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
