import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/error/api_exception.dart";
import "../../core/theme/app_theme.dart";

/// Widget visual para presentar estados de error de comunicación o red
/// de forma amigable, elegante y consistente con el diseño de la app,
/// proporcionando además un botón para recargar.
class ErrorConexionWidget extends StatelessWidget {
  final Object? error;
  final String? tituloPersonalizado;
  final String? mensajePersonalizado;
  final VoidCallback onRetry;
  final bool compact;

  const ErrorConexionWidget({
    super.key,
    this.error,
    this.tituloPersonalizado,
    this.mensajePersonalizado,
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = _parsearError(error);
    final titulo = tituloPersonalizado ?? parsed.titulo;
    final mensaje = mensajePersonalizado ?? parsed.mensaje;

    return Center(
      child: Container(
        padding: EdgeInsets.all(compact ? 16 : 24),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icono destacado con contenedor circular suave
            Container(
              width: compact ? 54 : 64,
              height: compact ? 54 : 64,
              decoration: BoxDecoration(
                color: parsed.colorFondo,
                shape: BoxShape.circle,
                border: Border.all(color: parsed.colorBorde, width: 2),
              ),
              child: Icon(
                parsed.icono,
                color: parsed.colorIcono,
                size: compact ? 26 : 32,
              ),
            ),
            SizedBox(height: compact ? 14 : 18),

            // Título
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Mensaje explicativo
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: compact ? 13 : 14,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            SizedBox(height: compact ? 18 : 24),

            // Botón de recarga
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  "REINTENTAR",
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.azulPrincipal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _DetalleError _parsearError(Object? err) {
    if (err == null) {
      return _DetalleError(
        titulo: "Inconveniente al cargar",
        mensaje:
            "No se pudieron obtener los datos. Por favor, pulsa el botón para recargar.",
        icono: Icons.refresh_rounded,
        colorIcono: AppTema.azulPrincipal,
        colorFondo: const Color(0xFFE0F2FE),
        colorBorde: const Color(0xFFBAE6FD),
      );
    }

    final errStr = err.toString().toLowerCase();

    // 1. Detección de error de conexión / red
    final bool esErrorConexion = err is NetworkException ||
        (err is DioException &&
            (err.type == DioExceptionType.connectionError ||
                err.type == DioExceptionType.connectionTimeout ||
                err.type == DioExceptionType.receiveTimeout ||
                err.type == DioExceptionType.sendTimeout)) ||
        errStr.contains("connection error") ||
        errStr.contains("conexion a internet") ||
        errStr.contains("conexión a internet") ||
        errStr.contains("socketexception") ||
        errStr.contains("network is unreachable") ||
        errStr.contains("failed host lookup");

    if (esErrorConexion) {
      return _DetalleError(
        titulo: "Sin conexión con el servidor",
        mensaje:
            "No fue posible comunicarse con el servicio. Verifica tu conexión a internet o si el servidor está activo e inténtalo de nuevo.",
        icono: Icons.wifi_off_rounded,
        colorIcono: const Color(0xFFDC2626),
        colorFondo: const Color(0xFFFEF2F2),
        colorBorde: const Color(0xFFFECACA),
      );
    }

    // 2. Error de servidor (500+)
    if (err is ServerException ||
        (err is DioException &&
            (err.response?.statusCode ?? 0) >= 500) ||
        errStr.contains("500") ||
        errStr.contains("502") ||
        errStr.contains("503")) {
      return _DetalleError(
        titulo: "Servidor en mantenimiento",
        mensaje:
            "El sistema está experimentando una interrupción temporal. Por favor, reintenta en unos instantes.",
        icono: Icons.cloud_off_rounded,
        colorIcono: const Color(0xFFD97706),
        colorFondo: const Color(0xFFFEF3C7),
        colorBorde: const Color(0xFFFDE68A),
      );
    }

    // 3. Error de sesión / 401
    if (err is UnauthorizedException ||
        (err is DioException && err.response?.statusCode == 401) ||
        errStr.contains("401") ||
        errStr.contains("no autorizada")) {
      return _DetalleError(
        titulo: "Sesión expirada",
        mensaje:
            "Tu sesión ha caducado. Por favor, reingresa a tu cuenta para continuar.",
        icono: Icons.lock_clock_rounded,
        colorIcono: const Color(0xFF0284C7),
        colorFondo: const Color(0xFFE0F2FE),
        colorBorde: const Color(0xFFBAE6FD),
      );
    }

    // 4. Otros errores con mensaje limpio
    String msg = "Ocurrió un imprevisto al cargar la información. Pulsa el botón para recargar.";
    if (err is ApiException) {
      msg = err.message;
    } else if (err is DioException && err.message != null && err.message!.isNotEmpty) {
      msg = err.message!;
    }

    return _DetalleError(
      titulo: "No se pudo cargar la información",
      mensaje: msg,
      icono: Icons.error_outline_rounded,
      colorIcono: const Color(0xFFE11D48),
      colorFondo: const Color(0xFFFFF1F2),
      colorBorde: const Color(0xFFFECDD3),
    );
  }
}

class _DetalleError {
  final String titulo;
  final String mensaje;
  final IconData icono;
  final Color colorIcono;
  final Color colorFondo;
  final Color colorBorde;

  _DetalleError({
    required this.titulo,
    required this.mensaje,
    required this.icono,
    required this.colorIcono,
    required this.colorFondo,
    required this.colorBorde,
  });
}
