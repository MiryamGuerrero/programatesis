import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';

class EtiquetaCard extends StatelessWidget {
  final Map<String, dynamic> etiqueta;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const EtiquetaCard({
    super.key,
    required this.etiqueta,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  IconData _getIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('veget')) {
      return Icons.eco_outlined;
    }
    if (n.contains('sulfito')) {
      return Icons.science_outlined;
    }
    if (n.contains('gluten')) {
      return Icons.grass_outlined;
    }
    if (n.contains('lactosa')) {
      return Icons.local_drink_outlined;
    }
    if (n.contains('vegan')) {
      return Icons.spa_outlined;
    }
    if (n.contains('sodio')) {
      return Icons.water_drop_outlined;
    }
    if (n.contains('azucar') || n.contains('azúcar')) {
      return Icons.layers_outlined;
    }
    if (n.contains('caloria') || n.contains('caloría')) {
      return Icons.local_fire_department_outlined;
    }
    return Icons.label_outline_rounded;
  }

  Color _getColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('veget')) {
      return Colors.green.shade400;
    }
    if (n.contains('sulfito')) {
      return Colors.orange.shade400;
    }
    if (n.contains('gluten')) {
      return Colors.amber.shade600;
    }
    if (n.contains('lactosa')) {
      return Colors.deepPurple.shade300;
    }
    if (n.contains('vegan')) {
      return Colors.lightGreen.shade400;
    }
    if (n.contains('sodio')) {
      return Colors.blue.shade400;
    }
    if (n.contains('azucar') || n.contains('azúcar')) {
      return Colors.pink.shade300;
    }
    if (n.contains('caloria') || n.contains('caloría')) {
      return Colors.teal.shade300;
    }
    return AppTema.azulPrincipal;
  }

  @override
  Widget build(BuildContext context) {
    final String nombre = etiqueta['nombre_visible'] ?? 'Sin nombre';
    final String descripcion =
        etiqueta['descripcion'] ?? 'Sin descripción disponible.';
    final String fechaRaw = etiqueta['created_at'] ?? '';
    final bool activa = etiqueta['activa'] != false;

    String fechaFormateada = 'Fecha desconocida';
    if (fechaRaw.isNotEmpty) {
      try {
        final date = DateTime.parse(fechaRaw);
        fechaFormateada = DateFormat('dd MMM yyyy').format(date);
      } catch (_) {}
    }

    final Color mainColor = _getColor(nombre);
    final IconData icon = _getIcon(nombre);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: mainColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTema.azulOscuro,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _StatusPill(activa: activa),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  descripcion,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fechaFormateada,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.edit_note_rounded,
                    color: AppTema.azulPrincipal,
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 8),
                  if (onDelete != null)
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      onPressed: onDelete!,
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

class _StatusPill extends StatelessWidget {
  final bool activa;

  const _StatusPill({required this.activa});

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppTema.verdeSalud : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        activa ? 'Activa' : 'Inactiva',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
