import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "../../core/theme/app_theme.dart";
import "../../core/state/notification_provider.dart";

// 1. Tarjeta de Resumen (KPIs) - Refinada y más pequeña
class NutriResumenCard extends StatelessWidget {
  const NutriResumenCard(
      {super.key,
      required this.titulo,
      required this.valor,
      this.colorValor = AppTema.azulPrincipal,
      this.icon = Icons.analytics_outlined});
  final String titulo;
  final String valor;
  final Color colorValor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo.toUpperCase(),
            style: GoogleFonts.montserrat(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.8),
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colorValor,
                letterSpacing: -0.5),
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}

// 2. Barra de Búsqueda y Acciones - Rediseño Figma Standardizado
class NutriTableToolbar extends StatelessWidget {
  const NutriTableToolbar(
      {super.key,
      required this.onSearch,
      required this.onAction,
      required this.actionLabel});
  final ValueChanged<String> onSearch;
  final VoidCallback onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: onSearch,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Escriba para filtrar resultados...",
                  hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFF94A3B8), size: 20),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_circle, size: 20, color: Colors.white),
              label: Text(actionLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTema.verdeSalud,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 3. Contenedor de Tabla - Estética de Alta Gama
class NutriTableContainer extends StatelessWidget {
  const NutriTableContainer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// 4. Badge Corporativo - Moderno
class NutriBadge extends StatelessWidget {
  const NutriBadge({super.key, required this.label, required this.type});
  final String label;
  final String type;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color txt;
    if (type == 'success') {
      bg = const Color(0xFFDCFCE7);
      txt = const Color(0xFF166534);
    } else if (type == 'info') {
      bg = const Color(0xFFDBEAFE);
      txt = const Color(0xFF1E40AF);
    } else if (type == 'warning') {
      bg = const Color(0xFFFEF9C3);
      txt = const Color(0xFF854D0E);
    } else {
      bg = const Color(0xFFFEE2E2);
      txt = const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label.toUpperCase(),
          style: GoogleFonts.montserrat(
              color: txt,
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 0.5)),
    );
  }
}

// 5. Utilidad de Notificaciones
class NutriSnack {
  static void show(BuildContext context, String mensaje,
      {bool isError = false, WidgetRef? ref}) {
    if (ref != null) {
      ref.read(notificationProvider.notifier).add(
            isError ? "Atención" : "Operación Exitosa",
            mensaje,
            type: isError
                ? NutriNotificationType.error
                : NutriNotificationType.success,
          );
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    final Color bgColor =
        isError ? const Color(0xFF1E293B) : const Color(0xFF0F172A);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: isError ? Colors.redAccent : AppTema.verdeSalud,
                size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                mensaje,
                style: GoogleFonts.lato(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 6. Widget de Carga
class NutriLoading extends StatelessWidget {
  const NutriLoading({super.key, this.mensaje = "Cargando información..."});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTema.azulPrincipal),
            ),
          ),
          const SizedBox(height: 20),
          Text(mensaje,
              style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
