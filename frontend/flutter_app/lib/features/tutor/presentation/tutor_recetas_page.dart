import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class TutorRecetasPage extends StatelessWidget {
  const TutorRecetasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color colorTitulo = const Color(0xFF1E293B);
    final Color colorSubtitulo = const Color(0xFF64748B);
    final Color colorAcento = AppTema.azulPrincipal;
    final Color colorVerde = AppTema.verdeSalud;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          
          // TÍTULO DE SECCIÓN
          Text(
            "Recetas seguras",
            style: GoogleFonts.lato(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorTitulo,
            ),
          ),
          const SizedBox(height: 20),
          
          // CAMPO DE BÚSQUEDA (Search Input)
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26), // Píldora
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF94A3B8), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar recetas o ingredientes...",
                      hintStyle: GoogleFonts.lato(color: const Color(0xFF94A3B8), fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // FILA DE CHIPS DE FILTRO (Filter Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("Todas", isSelected: true, colorAcento: colorAcento),
                _buildFilterChip("Desayunos"),
                _buildFilterChip("Almuerzos"),
                _buildFilterChip("Snacks"),
                _buildFilterChip("Cenas"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // LISTA DE TARJETAS DE RECETA
          _RecipeCard(
            titulo: "Huevos con Espinaca",
            categoria: "Desayuno Nutritivo",
            tiempo: "15 min",
            calorias: "320 kcal",
            macronutriente: "Proteína",
            colorTitulo: colorTitulo,
            colorSubtitulo: colorSubtitulo,
            colorVerde: colorVerde,
            colorAcento: colorAcento,
          ),
          const SizedBox(height: 16),
          _RecipeCard(
            titulo: "Batido de Arándanos",
            categoria: "Snack Saludable",
            tiempo: "5 min",
            calorias: "180 kcal",
            macronutriente: "Fibra",
            colorTitulo: colorTitulo,
            colorSubtitulo: colorSubtitulo,
            colorVerde: colorVerde,
            colorAcento: colorAcento,
          ),
          const SizedBox(height: 16),
          _RecipeCard(
            titulo: "Ensalada de Pollo",
            categoria: "Almuerzo Ligero",
            tiempo: "25 min",
            calorias: "450 kcal",
            macronutriente: "Proteína",
            colorTitulo: colorTitulo,
            colorSubtitulo: colorSubtitulo,
            colorVerde: colorVerde,
            colorAcento: colorAcento,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false, Color? colorAcento}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {},
        backgroundColor: Colors.white,
        selectedColor: colorAcento?.withOpacity(0.1) ?? Colors.blue.withOpacity(0.1),
        checkmarkColor: colorAcento,
        labelStyle: GoogleFonts.lato(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? colorAcento : const Color(0xFF64748B),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? (colorAcento ?? Colors.blue) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final String titulo;
  final String categoria;
  final String tiempo;
  final String calorias;
  final String macronutriente;
  final Color colorTitulo;
  final Color colorSubtitulo;
  final Color colorVerde;
  final Color colorAcento;

  const _RecipeCard({
    required this.titulo,
    required this.categoria,
    required this.tiempo,
    required this.calorias,
    required this.macronutriente,
    required this.colorTitulo,
    required this.colorSubtitulo,
    required this.colorVerde,
    required this.colorAcento,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Icon(Icons.restaurant, color: Colors.grey.shade300, size: 48),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorTitulo,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorVerde.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: colorVerde, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "Segura",
                            style: GoogleFonts.lato(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorVerde,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  categoria,
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: colorSubtitulo,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaInfo(Icons.schedule_outlined, tiempo, colorSubtitulo, colorAcento),
                    _buildMetaInfo(Icons.local_fire_department_outlined, calorias, colorSubtitulo, colorAcento),
                    _buildMetaInfo(Icons.donut_large_outlined, macronutriente, colorSubtitulo, colorAcento),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(IconData icon, String label, Color colorText, Color colorIcon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colorIcon.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 12,
            color: colorText,
          ),
        ),
      ],
    );
  }
}
