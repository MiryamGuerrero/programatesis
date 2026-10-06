import 'package:flutter/material.dart';

/// Indicador visual tipo foquito de semáforo para las recetas.
/// Sustituye textos repetitivos por un elemento visual limpio y clínico.
class FoquitoSemaforo extends StatelessWidget {
  final String? semaforo;
  final bool? esPotenciada;
  final bool? esDisminuida;
  final double size;
  final String? customTooltip;

  const FoquitoSemaforo({
    super.key,
    this.semaforo,
    this.esPotenciada,
    this.esDisminuida,
    this.size = 15.0,
    this.customTooltip,
  });

  @override
  Widget build(BuildContext context) {
    String sem = (semaforo ?? '').toLowerCase();
    if (sem.isEmpty || sem == 'null') {
      if (esPotenciada == true) {
        sem = 'verde';
      } else if (esDisminuida == true) {
        sem = 'amarillo';
      } else {
        sem = 'neutral';
      }
    }

    final Color color;
    final String defaultTooltip;
    final IconData icon;

    switch (sem) {
      case 'verde':
        color = const Color(0xFF16A34A);
        defaultTooltip = 'Semáforo Verde: Receta recomendada / potenciada para el paciente';
        icon = Icons.lightbulb_rounded;
        break;
      case 'amarillo':
        color = const Color(0xFFD97706);
        defaultTooltip = 'Semáforo Amarillo: Consumo moderado (máx. 2 veces por semana, días alternos)';
        icon = Icons.lightbulb_rounded;
        break;
      default:
        color = const Color(0xFF94A3B8);
        defaultTooltip = 'Semáforo Neutro: Receta segura y balanceada';
        icon = Icons.lightbulb_outline_rounded;
        break;
    }

    return Tooltip(
      message: customTooltip ?? defaultTooltip,
      waitDuration: const Duration(milliseconds: 200),
      child: Container(
        padding: EdgeInsets.all(size * 0.22),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
        ),
        child: Icon(
          icon,
          size: size,
          color: color,
        ),
      ),
    );
  }
}
