import "dart:math" as math;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../../core/theme/app_theme.dart";
import "../../core/theme/app_sizes.dart";
import "../../core/theme/app_responsive.dart";
import "../../core/state/app_providers.dart";

const String kLogoSinNombre = "assets/images/logo_reuma_nutri.png";

class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key});

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  String? _successMessage;

  static const Color _azulOscuro = AppTema.azulOscuro;
  static const Color _verde = AppTema.verdeSalud;
  static const Color _grisTexto = Color(0xFF64748B);
  static const Color _grisFuerte = Color(0xFF334155);

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      _passwordController.text.contains(RegExp(r'[^a-zA-Z0-9\s]'));

  bool get _isPasswordSecure =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialChar;

  bool get _passwordsMatch =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;

  int get _strengthScore {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasNumber) score++;
    if (_hasSpecialChar) score++;
    return score;
  }

  String get _strengthLabel {
    if (_passwordController.text.isEmpty) return "Sin ingresar";
    switch (_strengthScore) {
      case 1:
        return "Muy débil";
      case 2:
        return "Débil";
      case 3:
        return "Regular";
      case 4:
        return "Buena";
      case 5:
        return "Muy segura";
      default:
        return "Muy débil";
    }
  }

  Color get _strengthColor {
    if (_passwordController.text.isEmpty) return Colors.grey.shade300;
    switch (_strengthScore) {
      case 1:
        return Colors.red.shade600;
      case 2:
        return Colors.orange.shade700;
      case 3:
        return Colors.amber.shade700;
      case 4:
        return AppTema.azulPrincipal;
      case 5:
        return AppTema.verdeSalud;
      default:
        return Colors.red.shade600;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = "Por favor, completa ambos campos.");
      return;
    }

    if (!_isPasswordSecure) {
      setState(() => _errorMessage =
          "La contraseña debe cumplir con todos los estándares de seguridad solicitados.");
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

      // Mostrar feedback de exito y cerrar sesión para forzar el reingreso manual
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Contraseña configurada correctamente. Por favor, inicia sesión de nuevo."),
          backgroundColor: AppTema.verdeSalud,
        ));
      }

      await Supabase.instance.client.auth.signOut();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage =
          "No fue posible actualizar la contraseña. Intenta de nuevo.");
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
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ProfessionalBackgroundPainter(),
              ),
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
    final isWide = MediaQuery.sizeOf(context).width >= 768;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: isWide ? 820.0 : AppSizes.maxFormWidth,
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
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Configuración",
                  style: GoogleFonts.montserrat(
                      fontSize:
                          AppTextSizes.headline(context.screenWidth) * 0.9,
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
              if (_successMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: Colors.green.shade700, size: 20),
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
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna Izquierda: Campos y Botón de Acción
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField(
                            context: context,
                            controller: _passwordController,
                            label: "Nueva contraseña",
                            hint: "Ingresa tu contraseña",
                            icon: Icons.lock_outline_rounded,
                            obscureState: _obscurePassword,
                            onToggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildField(
                            context: context,
                            controller: _confirmController,
                            label: "Confirmar contraseña",
                            hint: "Repite tu nueva contraseña",
                            icon: Icons.lock_reset_rounded,
                            obscureState: _obscureConfirm,
                            onToggleObscure: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            onChanged: (_) => setState(() {}),
                          ),
                          if (_confirmController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildMatchIndicator(),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    // Columna Derecha: Panel Integrado de Requisitos y Fortaleza
                    Expanded(
                      flex: 10,
                      child: _buildSecurityPanel(),
                    ),
                  ],
                )
              else
                // Disposición vertical en pantallas móviles
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      context: context,
                      controller: _passwordController,
                      label: "Nueva contraseña",
                      hint: "Ingresa tu contraseña",
                      icon: Icons.lock_outline_rounded,
                      obscureState: _obscurePassword,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildSecurityPanel(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildField(
                      context: context,
                      controller: _confirmController,
                      label: "Confirmar contraseña",
                      hint: "Repite tu nueva contraseña",
                      icon: Icons.lock_reset_rounded,
                      obscureState: _obscureConfirm,
                      onToggleObscure: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_confirmController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildMatchIndicator(),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _buildSubmitButton(),
                  ],
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
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
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

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool obscureState,
    required VoidCallback onToggleObscure,
    ValueChanged<String>? onChanged,
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
          onChanged: onChanged,
          style: GoogleFonts.inter(
              fontSize: AppTextSizes.body(context.screenWidth),
              color: _grisFuerte,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: _grisTexto.withValues(alpha: 0.45),
              fontSize: AppTextSizes.body(context.screenWidth),
              fontWeight: FontWeight.w500,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            hintFadeDuration: Duration.zero,
            prefixIcon: Icon(icon, size: 22, color: AppTema.azulPrincipal),
            suffixIcon: IconButton(
              icon: Icon(
                  obscureState
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.blueGrey.shade400),
              onPressed: onToggleObscure,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
              borderSide:
                  const BorderSide(color: AppTema.azulPrincipal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.blueGrey.shade100.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (_isPasswordSecure
                          ? AppTema.verdeSalud
                          : AppTema.azulPrincipal)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPasswordSecure
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
                  size: 18,
                  color: _isPasswordSecure
                      ? AppTema.verdeSalud
                      : AppTema.azulPrincipal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Requisitos de seguridad",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _azulOscuro,
                      ),
                    ),
                    Text(
                      "Estándar de la industria (OWASP)",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _grisTexto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStrengthMeter(),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          _buildRequirementItem(
            label: "Mínimo 8 caracteres",
            isMet: _hasMinLength,
          ),
          const SizedBox(height: 8),
          _buildRequirementItem(
            label: "Al menos una letra mayúscula (A-Z)",
            isMet: _hasUppercase,
          ),
          const SizedBox(height: 8),
          _buildRequirementItem(
            label: "Al menos una letra minúscula (a-z)",
            isMet: _hasLowercase,
          ),
          const SizedBox(height: 8),
          _buildRequirementItem(
            label: "Al menos un número (0-9)",
            isMet: _hasNumber,
          ),
          const SizedBox(height: 8),
          _buildRequirementItem(
            label: "Al menos un carácter especial (!@#\$%...)",
            isMet: _hasSpecialChar,
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthMeter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Fortaleza:",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _grisTexto,
              ),
            ),
            Text(
              _strengthLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (index) {
            final isFilled = index < _strengthScore;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                margin: EdgeInsets.only(right: index < 4 ? 6 : 0),
                decoration: BoxDecoration(
                  color: isFilled ? _strengthColor : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRequirementItem({
    required String label,
    required bool isMet,
  }) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isMet
                ? AppTema.verdeSalud.withValues(alpha: 0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isMet
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: isMet ? AppTema.verdeSalud : Colors.grey.shade400,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w500,
              color: isMet ? AppTema.azulOscuro : Colors.blueGrey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(
            _passwordsMatch
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color:
                _passwordsMatch ? AppTema.verdeSalud : Colors.amber.shade800,
          ),
          const SizedBox(width: 6),
          Text(
            _passwordsMatch
                ? "Las contraseñas coinciden"
                : "Las contraseñas no coinciden aún",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _passwordsMatch
                  ? AppTema.verdeSalud
                  : Colors.amber.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool canSubmit = !_loading &&
        _successMessage == null &&
        _isPasswordSecure &&
        _passwordsMatch;

    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeightLarge,
      child: FilledButton.icon(
        onPressed: canSubmit ? _submit : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppTema.verdeSalud,
          disabledBackgroundColor: Colors.grey.shade200,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
        ),
        icon: _loading
            ? const SizedBox.shrink()
            : Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: canSubmit ? Colors.white : Colors.grey.shade500,
              ),
        label: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                "Guardar contraseña",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: canSubmit ? Colors.white : Colors.grey.shade500,
                ),
              ),
      ),
    );
  }
}

class _ProfessionalBackgroundPainter extends CustomPainter {
  const _ProfessionalBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const float = 0.0;

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
      ..color = const Color(0xFF58A932).withValues(alpha: 0.9);
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
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final random = math.Random(42);

    for (int i = 0; i < 20; i++) {
      double baseX = size.width * (0.52 + random.nextDouble() * 0.43);
      double baseY = size.height * random.nextDouble();

      double x = baseX + math.sin(i.toDouble()) * 10;
      double y = baseY + math.cos(i.toDouble()) * 12;
      double rotation = (i % 2 == 0 ? 1 : -1) * 0.1;

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
