import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/// Muestra el modal pop-up de confirmación de cerrar sesión con el diseño
/// establecido para la aplicación móvil Android de NutriReuma.
Future<bool?> showCerrarSesionDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const CerrarSesionDialog(),
  );
}

/// Ventana pop-up para confirmación de cierre de sesión con el sistema
/// de diseño de la app móvil (bordes suaves de 28px, contenedor de icono destacado,
/// tipografías Montserrat/Lato y botones estilizados de acción).
class CerrarSesionDialog extends StatelessWidget {
  const CerrarSesionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono distintivo con contenedor circular estilizado
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFECACA),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFDC2626),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              // Título con tipografía Montserrat corporativa
              Text(
                "¿Cerrar sesión?",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              // Descripción explicativa
              Text(
                "¿Estás seguro de que deseas salir? Tendrás que volver a ingresar tus credenciales para acceder a la gestión de tus pacientes.",
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 14.5,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(
                          color: Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      child: Text(
                        "Cancelar",
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Sí, salir",
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
