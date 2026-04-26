import "dart:math" as math;
import "dart:ui";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../core/state/app_providers.dart";
import "../../core/theme/app_theme.dart";
import "../../shared/widgets/layout_components.dart";

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
    if (email.isEmpty || password.isEmpty) {
      NutriSnack.show(context, "Ingrese sus credenciales", isError: true, ref: ref);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      if (res.session != null && mounted) {
        // Notificamos el éxito para la transición rápida
        NutriSnack.show(context, "Sincronizando...", ref: ref);
      }
    } catch (e) {
      if (mounted) NutriSnack.show(context, "Error de acceso", isError: true, ref: ref);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      body: Stack(
        children: [
          // 1. FONDO BASE AZUL CORPORATIVO
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTema.azulOscuro, AppTema.azulPrincipal],
              ),
            ),
          ),

          // 2. CUADRADOS DINÁMICOS EN MOVIMIENTO (BIO-GRID)
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return CustomPaint(
                painter: _GeometricHealthPainter(_animController.value),
                child: Container(),
              );
            },
          ),

          // 3. LAYOUT HORIZONTAL
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isWide) ...[
                    _buildBrandPanel(),
                    const SizedBox(width: 50),
                  ],
                  _buildLoginCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandPanel() {
    return SizedBox(
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHexagonIcon(),
          const SizedBox(height: 32),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: "Nutri", style: GoogleFonts.lexend(fontSize: 78, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -4)),
                TextSpan(text: "Reuma", style: GoogleFonts.lexend(fontSize: 78, fontWeight: FontWeight.w900, color: AppTema.verdeLima, letterSpacing: -4)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text("Plataforma Inteligente de\nGestión Nutricional Pediátrica.", 
            style: GoogleFonts.poppins(fontSize: 22, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500, height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildHexagonIcon() {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTema.verdeSalud.withOpacity(0.5), blurRadius: 30)],
      ),
      child: const Icon(Icons.dashboard_customize_rounded, size: 40, color: AppTema.azulPrincipal),
    );
  }

  Widget _buildLoginCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(50),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Acceso Seguro", style: GoogleFonts.lexend(fontSize: 32, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -1)),
              const SizedBox(height: 40),
              _buildField(controller: _emailController, label: "EMAIL INSTITUCIONAL", icon: Icons.alternate_email_rounded),
              const SizedBox(height: 24),
              _buildField(controller: _passwordController, label: "CONTRASEÑA", icon: Icons.lock_person_rounded, isPass: true),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity, height: 62,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTema.verdeSalud,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: AppTema.verdeSalud.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _loading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("INICIAR SESIÓN", style: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required IconData icon, bool isPass = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.lexend(fontSize: 10, fontWeight: FontWeight.w900, color: AppTema.azulPrincipal.withOpacity(0.6), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppTema.grisLienzo, borderRadius: BorderRadius.circular(16)),
          child: TextField(
            controller: controller,
            obscureText: isPass && _obscurePassword,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppTema.azulPrincipal.withOpacity(0.4), size: 20),
              suffixIcon: isPass ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ),
      ],
    );
  }
}

class _GeometricHealthPainter extends CustomPainter {
  final double val;
  _GeometricHealthPainter(this.val);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42); 

    for (var i = 0; i < 15; i++) {
      final speed = 0.2 + random.nextDouble() * 0.5;
      final sizeSquare = 40.0 + random.nextDouble() * 120.0;
      final opacity = 0.05 + random.nextDouble() * 0.15;
      paint.color = AppTema.verdeSalud.withOpacity(opacity);
      double x = (size.width * random.nextDouble() + (val * size.width * speed)) % (size.width + 200) - 100;
      double y = (size.height * random.nextDouble() + (math.sin(val * 2 * math.pi + i) * 50)) % size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(val * 2 * math.pi * speed * (i % 2 == 0 ? 1 : -1));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: sizeSquare, height: sizeSquare), Radius.circular(sizeSquare * 0.2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
