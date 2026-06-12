import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_theme.dart';

class RecetaCard extends StatelessWidget {
  final Map<String, dynamic> receta;
  final bool isLoading;
  final VoidCallback? onVer;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;
  final ValueChanged<bool>? onToggleActive;

  const RecetaCard({
    super.key,
    required this.receta,
    this.isLoading = false,
    this.onVer,
    this.onEditar,
    this.onEliminar,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final momentos = _textoLista(receta['momentos_nombres']);
    final tiposPlato = _textoLista(receta['tipos_plato_nombres']);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección 1: Cabecera Visual (40% aprox)
          _buildHeader(),

          // Sección 2: Cuerpo de Información
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila 1: Título y Dificultad
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          receta['nombre'] ?? 'Sin nombre',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTema.azulOscuro,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildDificultadBadge(receta['dificultad'] ?? 'Media'),
                    ],
                  ),

                  // Fila 2: Categoría
                  const SizedBox(height: 2),
                  Text(
                    (momentos.isNotEmpty
                            ? momentos
                            : (receta['categoria'] ?? 'General').toString())
                        .toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tiposPlato.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tiposPlato,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTema.azulPrincipal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Fila 3: Descripción
                  const SizedBox(height: 6),
                  Text(
                    receta['descripcion'] ?? 'Sin descripción disponible.',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Fila 5: Datos Nutricionales
                  Row(
                    children: [
                      _buildMacroColumn(
                          'CALORÍAS', '${receta['calorias_totales'] ?? 0}'),
                      _buildMacroColumn(
                          'PROTEÍNAS', '${receta['proteinas_totales'] ?? 0}g'),
                      _buildMacroColumn(
                          'CARBOS', '${receta['carbohidratos_totales'] ?? 0}g'),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Fila 4: Metadatos de Preparación
                  Row(
                    children: [
                      _buildMetadataBlock(
                        Icons.people_outline_rounded,
                        '${receta['porciones'] ?? 0} porción(es)',
                      ),
                      const SizedBox(width: 20),
                      _buildMetadataBlock(
                        Icons.access_time_rounded,
                        '${receta['tiempo_total_min'] ?? ((receta['tiempo_preparacion_min'] ?? receta['tiempo_preparacion'] ?? 0) + (receta['tiempo_coccion_min'] ?? receta['tiempo_coccion'] ?? 0))} min',
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ),
            ),
          ),

          // Sección 3: Pie de Tarjeta
          _buildFooter(),
        ],
      ),
    );
  }

  String _textoLista(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    return value.toString().trim();
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 170,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: (receta['imagen_url'] != null &&
                      receta['imagen_url'].toString().isNotEmpty)
                  ? Image.network(
                      receta['imagen_url'],
                      fit: BoxFit.cover,
                      key: ValueKey(receta[
                          'imagen_url']), // Forzar rebuild si cambia la URL
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
          // Toggle de Activación (Fácil Acceso)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    receta['activa'] == true ? 'ACTIVA' : 'INACTIVA',
                    style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: receta['activa'] == true
                            ? AppTema.verdeSalud
                            : Colors.grey),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 20,
                    width: 32,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: Switch(
                        value: receta['activa'] == true,
                        onChanged: (v) => onToggleActive?.call(v),
                        activeColor: AppTema.verdeSalud,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildDificultadBadge(String dificultad) {
    Color color;
    switch (dificultad.toLowerCase()) {
      case 'fácil':
        color = AppTema.verdeSalud;
        break;
      case 'media':
        color = Colors.orange;
        break;
      case 'difícil':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        dificultad.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetadataBlock(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroColumn(String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTema.azulOscuro,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(left: 18, right: 18, bottom: 16),
      child: Row(
        children: [
          // Botón Principal
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: isLoading ? null : onVer,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.azulPrincipal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.visibility_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'VER',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Botones Secundarios
          _buildSecondaryButton(Icons.edit_rounded, onEditar),
          const SizedBox(width: 8),
          _buildSecondaryButton(Icons.delete_outline_rounded, onEliminar,
              isDanger: true),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton(IconData icon, VoidCallback? onPressed,
      {bool isDanger = false}) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 18,
          color: isDanger ? Colors.redAccent : Colors.blueGrey.shade400,
        ),
      ),
    );
  }
}
