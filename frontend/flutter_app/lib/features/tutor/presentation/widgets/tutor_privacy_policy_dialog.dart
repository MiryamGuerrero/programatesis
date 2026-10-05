import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../core/theme/app_theme.dart";

import "../politica_privacidad_page.dart";

/// Clave de almacenamiento local para registrar la aceptación de la política de privacidad.
const String kPrefPoliticaPrivacidadAceptada = "politica_privacidad_aceptada_v1";

/// URL pública institucional de la política de privacidad alojada en Cloudflare Pages
const String kUrlPoliticaPrivacidad = "https://nutrireuma-web1.pages.dev/politica-privacidad";

/// Comprueba si el usuario tutor ya aceptó las políticas de privacidad.
Future<bool> tutorDebeAceptarPoliticaPrivacidad() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(kPrefPoliticaPrivacidadAceptada) ?? false);
  } catch (_) {
    return false;
  }
}

/// Muestra el modal flotante obligatorio de Política de Privacidad y Términos.
///
/// Si el usuario acepta, retorna `true` y guarda el estado en persistencia local.
/// Si el usuario presiona "Rechazar y Salir", cierra la sesión en Supabase y
/// retorna `false`, impidiendo el uso continuo de la app según requerimientos de Play Store.
Future<bool> mostrarModalPoliticaPrivacidad(
  BuildContext context, {
  bool forceInteractive = false,
}) async {
  if (!forceInteractive) {
    final debeAceptar = await tutorDebeAceptarPoliticaPrivacidad();
    if (!debeAceptar) return true;
  }

  if (!context.mounted) return false;

  final resultado = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Obligatorio: debe decidir aceptar o salir
    builder: (ctx) => const TutorPrivacyPolicyDialog(),
  );

  return resultado ?? false;
}

/// Abre la URL pública de la política de privacidad en el navegador del dispositivo.
///
/// Se ejecuta con un timeout estricto para evitar bloqueos del hilo de la interfaz
/// en modo debug. Si no se puede abrir externamente (por ejemplo, en un emulador
/// sin navegador predeterminado), recurre a la pantalla interna de la app.
Future<void> abrirUrlPoliticaPrivacidad([BuildContext? context]) async {
  final uri = Uri.parse(kUrlPoliticaPrivacidad);
  bool lanzado = false;

  try {
    lanzado = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).timeout(
      const Duration(seconds: 2),
      onTimeout: () => false,
    );
  } catch (e) {
    debugPrint("Error lanzando URL con externalApplication: $e");
    lanzado = false;
  }

  if (!lanzado) {
    try {
      lanzado = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint("Error lanzando URL con platformDefault: $e");
      lanzado = false;
    }
  }

  // Fallback seguro: si el navegador externo no abrió y tenemos contexto,
  // mostramos la página de privacidad nativa de la app sin bloquear al usuario
  if (!lanzado && context != null && context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PoliticaPrivacidadPage(),
      ),
    );
  }
}

class TutorPrivacyPolicyDialog extends StatefulWidget {
  const TutorPrivacyPolicyDialog({super.key});

  @override
  State<TutorPrivacyPolicyDialog> createState() => _TutorPrivacyPolicyDialogState();
}

class _TutorPrivacyPolicyDialogState extends State<TutorPrivacyPolicyDialog> {
  bool _procesando = false;

  Future<void> _abrirNavegadorPolitica() => abrirUrlPoliticaPrivacidad(context);

  Future<void> _aceptarPolitica() async {
    setState(() => _procesando = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefPoliticaPrivacidadAceptada, true);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint("Error guardando aceptación de política: $e");
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _rechazarYSalir() async {
    setState(() => _procesando = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint("Error cerrando sesión tras rechazar privacidad: $e");
    } finally {
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Impide cerrar la ventana con el botón atrás de Android sin responder
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de cabecera decorativa
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTema.verdeSalud.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppTema.verdeSalud,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "POLÍTICA DE PRIVACIDAD",
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTema.verdeSalud,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Términos y Tratamiento de Datos",
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Cuerpo con contenido resumido y enlace
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bienvenido a NutriReuma",
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTema.azulOscuro,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Para brindarte soporte en la nutrición pediátrica de los pacientes a tu cargo, NutriReuma trata la información clínica y dietética de forma segura y confidencial.",
                        style: GoogleFonts.lato(
                          fontSize: 13.5,
                          color: const Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tarjeta de puntos clave sobre privacidad
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildBulletPoint(
                              icon: Icons.shield_rounded,
                              color: AppTema.azulPrincipal,
                              text: "Tus datos y los de tus pacientes se usan exclusivamente para la planificación nutricional y seguimiento médico.",
                            ),
                            const SizedBox(height: 10),
                            _buildBulletPoint(
                              icon: Icons.lock_outline_rounded,
                              color: AppTema.verdeSalud,
                              text: "No compartimos, vendemos ni cedemos datos sensibles con fines publicitarios o comerciales a terceros.",
                            ),
                            const SizedBox(height: 10),
                            _buildBulletPoint(
                              icon: Icons.notifications_active_outlined,
                              color: const Color(0xFFD97706),
                              text: "Las notificaciones locales son programadas en tu dispositivo únicamente para recordar los momentos de comida.",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Botón para leer la política completa en Cloudflare Pages
                      InkWell(
                        onTap: _abrirNavegadorPolitica,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                                color: AppTema.azulPrincipal,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Leer Política de Privacidad completa",
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTema.azulPrincipal,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      Text(
                        "Para continuar usando la aplicación NutriReuma, es necesario leer y aceptar los términos de la política.",
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Botones de decisión
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(
                  children: [
                    // Opción: Rechazar y salir
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: _procesando ? null : _rechazarYSalir,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        child: Text(
                          "Rechazar",
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Opción: Aceptar y continuar
                    Expanded(
                      flex: 6,
                      child: FilledButton.icon(
                        onPressed: _procesando ? null : _aceptarPolitica,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTema.verdeSalud,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: _procesando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          _procesando ? "Guardando..." : "Aceptar y continuar",
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
