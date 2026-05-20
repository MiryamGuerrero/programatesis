import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TutorRecetasPage extends StatefulWidget {
  const TutorRecetasPage({super.key});

  @override
  State<TutorRecetasPage> createState() => _TutorRecetasPageState();
}

class _TutorRecetasPageState extends State<TutorRecetasPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16), // Espaciado estándar inicial
          
          // SEARCH M3 STYLE
          SearchBar(
            controller: _searchController,
            hintText: "Buscar recetas o ingredientes...",
            leading: const Icon(Icons.search),
            trailing: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _searchController.clear());
                  },
                ),
            ],
            onChanged: (val) => setState(() {}),
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest.withOpacity(0.3)),
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
          ),
          const SizedBox(height: 24),
          
          // FILTER CHIPS M3
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, "Todas", isSelected: true),
                _buildFilterChip(context, "Desayunos"),
                _buildFilterChip(context, "Almuerzos"),
                _buildFilterChip(context, "Snacks"),
                _buildFilterChip(context, "Cenas"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          const _RecipeCard(
            titulo: "Huevos con Espinaca",
            categoria: "Desayuno Nutritivo",
            tiempo: "15 min",
            calorias: "320 kcal",
            macronutriente: "Proteína",
          ),
          const SizedBox(height: 16),
          const _RecipeCard(
            titulo: "Batido de Arándanos",
            categoria: "Snack Saludable",
            tiempo: "5 min",
            calorias: "180 kcal",
            macronutriente: "Fibra",
          ),
          const SizedBox(height: 16),
          const _RecipeCard(
            titulo: "Ensalada de Pollo",
            categoria: "Almuerzo Ligero",
            tiempo: "25 min",
            calorias: "450 kcal",
            macronutriente: "Proteína",
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {},
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

  const _RecipeCard({
    required this.titulo,
    required this.categoria,
    required this.tiempo,
    required this.calorias,
    required this.macronutriente,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Icon(Icons.restaurant, color: colorScheme.onSurfaceVariant.withOpacity(0.3), size: 48),
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
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTema.verdeSalud.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTema.verdeSalud, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "Segura",
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTema.verdeSalud,
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
                  style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaInfo(context, Icons.schedule_outlined, tiempo),
                    _buildMetaInfo(context, Icons.local_fire_department_outlined, calorias),
                    _buildMetaInfo(context, Icons.donut_large_outlined, macronutriente),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: const Color(0xFF64748B)),
        ),
      ],
    );
  }
}
