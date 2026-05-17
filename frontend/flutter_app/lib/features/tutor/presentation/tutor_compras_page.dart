import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class TutorComprasPage extends StatefulWidget {
  const TutorComprasPage({super.key});

  @override
  State<TutorComprasPage> createState() => _TutorComprasPageState();
}

class _TutorComprasPageState extends State<TutorComprasPage> {
  int _selectedTab = 0; // 0: Pendientes, 1: Comprados

  @override
  Widget build(BuildContext context) {
    final Color colorTitulo = const Color(0xFF1E293B);
    final Color colorSubtitulo = const Color(0xFF64748B);
    final Color colorAcento = AppTema.azulPrincipal;
    final Color colorVerde = AppTema.verdeSalud;

    return Column(
      children: [
        // CONTROL DE SEGMENTACIÓN (Navigational Tabs)
        _buildSegmentedControl(colorAcento),
        
        // CUERPO DESPLAZABLE (Scrollable List)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              _buildCategoryHeader("PROTEÍNAS", colorSubtitulo),
              _buildShoppingItem("Pechuga de Pollo", "Para almuerzos de la semana", "500g", colorTitulo, colorSubtitulo, colorAcento),
              _buildShoppingItem("Huevos", "Fuente principal de proteína", "12 unid.", colorTitulo, colorSubtitulo, colorAcento),
              const SizedBox(height: 24),
              
              _buildCategoryHeader("VERDURAS", colorSubtitulo),
              _buildShoppingItem("Espinaca Fresca", "Para revueltos y ensaladas", "1 manojo", colorTitulo, colorSubtitulo, colorAcento),
              _buildShoppingItem("Brócoli", "Vapor o salteados", "1 unidad", colorTitulo, colorSubtitulo, colorAcento),
              const SizedBox(height: 24),
              
              _buildCategoryHeader("LÁCTEOS Y OTROS", colorSubtitulo),
              _buildShoppingItem("Yogur Griego", "Sin azúcar añadida", "2 tarros", colorTitulo, colorSubtitulo, colorAcento),
              _buildShoppingItem("Nueces", "Mix de frutos secos", "100g", colorTitulo, colorSubtitulo, colorAcento),
              
              const SizedBox(height: 100), // Espacio para el pie de página fijo
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl(Color colorAcento) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedTab == 0 ? colorAcento : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "Pendientes",
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _selectedTab == 0 ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedTab == 1 ? colorAcento : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "Comprados",
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _selectedTab == 1 ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String label, Color colorSubtitulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: colorSubtitulo,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildShoppingItem(String titulo, String subtitulo, String cantidad, Color colorTitulo, Color colorSubtitulo, Color colorAcento) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorTitulo,
                  ),
                ),
                Text(
                  subtitulo,
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: colorSubtitulo,
                  ),
                ),
              ],
            ),
          ),
          Text(
            cantidad,
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorAcento,
            ),
          ),
        ],
      ),
    );
  }
}
