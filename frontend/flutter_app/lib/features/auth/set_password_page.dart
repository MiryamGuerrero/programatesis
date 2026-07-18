import "dart:math" as math;
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../../core/theme/app_theme.dart";
import "../../core/theme/app_sizes.dart";
import "../../core/theme/app_responsive.dart";
import "../../core/state/app_providers.dart";

const String kLogoSinNombre = "assets/images/logo sin.webp";

class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key});

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  String? _successMessage;

  late AnimationController _animController;

  static const Color _azulOscuro = AppTema.azulOscuro;
  static const Color _verde = AppTema.verdeSalud;
  static const Color _grisTexto = Color(0xFF64748B);
  static const Color _grisFuerte = Color(0xFF334155);

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
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = "Por favor, completa ambos campos.");
      return;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = "La contraseña debe tener al menos 8 caracteres.");
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = "Las contraseñas no coinciden.");
      return;
    }

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;

      ref.read(authFlowIntentProvider.notifier).state = AuthFlowIntent.none;
      setState(() {
        _successMessage = "Contraseña configurada correctamente. Ya puedes usar tu cuenta.";
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = "No fue posible actualizar la contraseña. Intenta de nuevo.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      value: _animController.value),
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
                child: _buildPasswordCard(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard(BuildContext context) {
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
              Text("Configuración",
                  style: GoogleFonts.montserrat(
                      fontSize: AppTextSizes.headline(context.screenWidth) * 0.9,
                      fontWeight: FontWeight.w800,
                      color: _azulOscuro,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text("Define tu nueva contraseña segura",
                  style: GoogleFonts.lato(
                      fontSize: AppTextSizes.body(context.screenWidth),
                      color: _grisTexto)),
              const SizedBox(height: AppSpacing.md),
              Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                      color: _verde, borderRadius: BorderRadius.circular(2))),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
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

              if (_successMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: GoogleFonts.lato(
                              color: Colors.green.shade700,
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
                  controller: _passwordController,
                  label: "Nueva contraseña",
                  hint: "Mínimo 8 caracteres",
                  icon: Icons.lock_outline,
                  obscureState: _obscurePassword,
                  onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword)
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildField(
                  context: context,
                  controller: _confirmController,
                  label: "Confirmar contraseña",
                  hint: "Mínimo 8 caracteres",
                  icon: Icons.lock_outline,
                  obscureState: _obscureConfirm,
                  onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm)
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeightLarge,
                child: FilledButton(
                  onPressed: _loading || _successMessage != null ? null : _submit,
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
                          "Guardar contraseña",
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
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
            child: ClipOval(
                child: Image.asset(kLogoSinNombre, fit: BoxFit.contain)),
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
    required bool obscureState,
    required VoidCallback onToggleObscure,
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
          obscureText: obscureState,
          style: GoogleFonts.lato(
              fontSize: AppTextSizes.body(context.screenWidth),
              color: _grisFuerte,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.lato(
              color: _grisTexto.withOpacity(0.4),
              fontSize: AppTextSizes.body(context.screenWidth),
              fontWeight: FontWeight.w500,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            hintFadeDuration: Duration.zero,
            prefixIcon: Icon(icon, size: 22),
            suffixIcon: IconButton(
              icon: Icon(
                  obscureState
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20),
              onPressed: onToggleObscure,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
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

    final paintWhite = Paint()..color = const Color(0xFFF8FAFD);
    final pathWhite = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.6, 0)
      ..cubicTo(size.width * 0.5, size.height * 0.3, size.width * 0.7,
          size.height * 0.7, size.width * 0.5, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(pathWhite, paintWhite);

    final paintGreen = Paint()
      ..color = const Color(0xFF58A932).withOpacity(0.9);
    final pathGreen = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
          size.width * 0.1, size.height * 0.75, size.width * 0.3, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(pathGreen, paintGreen);

    final paintBlue = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF008BD2), Color(0xFF0068B7), Color(0xFF00579D)],
      ).createShader(
          Rect.fromLTWH(size.width * 0.45, 0, size.width * 0.55, size.height));

    final pathBlue = Path()
      ..moveTo(size.width * (0.45 + float * 0.01), 0)
      ..cubicTo(size.width * 0.6, size.height * 0.2, size.width * 0.4,
          size.height * 0.6, size.width * (0.5 + float * 0.02), size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(pathBlue, paintBlue);

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
