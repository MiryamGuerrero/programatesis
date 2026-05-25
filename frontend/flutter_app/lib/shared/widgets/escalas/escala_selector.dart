import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EscalaEtiqueta {
  final String label;
  final int flex;
  EscalaEtiqueta(this.label, this.flex);
}

class EscalaSelector extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final int min;
  final int max;
  final int value;
  final List<IconData> icons; // Cambiado de String a IconData
  final List<EscalaEtiqueta>? etiquetas;
  final Color colorActivo;
  final Color colorFondoActivo;
  final ValueChanged<int> onChanged;
  final String? puntajeLabel;
  final Widget headerIcon; // El icono grande del cuadro izquierdo
  final Color backgroundColor;
  final EdgeInsetsGeometry margin;
  final bool showIdentityRow;

  const EscalaSelector({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.min,
    required this.max,
    required this.value,
    required this.icons,
    this.etiquetas,
    required this.colorActivo,
    required this.colorFondoActivo,
    required this.onChanged,
    this.puntajeLabel,
    required this.headerIcon,
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.margin = EdgeInsets.zero,
    this.showIdentityRow = true,
  });

  @override
  Widget build(BuildContext context) {
    final int count = max - min + 1;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titulo.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                if (puntajeLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorFondoActivo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      puntajeLabel!,
                      style: GoogleFonts.montserrat(
                        color: colorActivo,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (showIdentityRow) ...[
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(child: headerIcon),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: colorActivo,
                          ),
                        ),
                        Text(
                          descripcion,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ] else
              const SizedBox(height: 8),
            // Number Row
            Row(
              children: List.generate(count, (i) {
                final idx = min + i;
                final selected = idx == value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(idx),
                    child: Column(
                      children: [
                        Container(
                          height: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: selected ? colorActivo : const Color(0xFFF8FAFC),
                            borderRadius: _getBorderRadius(i, count),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Center(
                            child: Text(
                              idx.toString(),
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: selected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        // Pointer
                        Opacity(
                          opacity: selected ? 1.0 : 0.0,
                          child: CustomPaint(
                            size: const Size(12, 8),
                            painter: TrianglePainter(colorActivo),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Icon Row (Instead of Emojis)
            Row(
              children: List.generate(count, (i) {
                final idx = min + i;
                final selected = idx == value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(idx),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? colorActivo : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          icons.length > i ? icons[i] : Icons.help_outline,
                          size: 28,
                          color: selected ? colorActivo : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (etiquetas != null) ...[
              const SizedBox(height: 16),
              Row(
                children: etiquetas!.map((e) {
                  return Expanded(
                    flex: e.flex,
                    child: Column(
                      children: [
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.label,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BorderRadius _getBorderRadius(int i, int count) {
    if (i == 0) return const BorderRadius.horizontal(left: Radius.circular(12));
    if (i == count - 1) return const BorderRadius.horizontal(right: Radius.circular(12));
    return BorderRadius.zero;
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
