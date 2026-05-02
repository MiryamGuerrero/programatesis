import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_theme.dart';

class EtiquetaCard extends StatelessWidget {
  final Map<String, dynamic> etiqueta;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const EtiquetaCard({
    super.key,
    required this.etiqueta,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final String nombre = etiqueta['nombre_visible'] ?? 'Sin nombre';
    final String descripcion = etiqueta['descripcion'] ?? 'Sin descripción disponible.';
    final String fechaRaw = etiqueta['created_at'] ?? '';
    
    String fechaFormateada = 'Fecha desconocida';
    if (fechaRaw.isNotEmpty) {
      try {
        final date = DateTime.parse(fechaRaw);
        fechaFormateada = DateFormat('dd MMM yyyy').format(date);
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      style: GoogleFonts.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTema.azulOscuro,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.label_outline_rounded, color: AppTema.azulPrincipal, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  descripcion,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Text(
                        fechaFormateada,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Material(
                    color: AppTema.azulPrincipal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.edit_note_rounded, size: 20, color: AppTema.azulPrincipal),
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
