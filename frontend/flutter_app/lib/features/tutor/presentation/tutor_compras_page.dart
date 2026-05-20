import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TutorComprasPage extends StatefulWidget {
  const TutorComprasPage({super.key});

  @override
  State<TutorComprasPage> createState() => _TutorComprasPageState();
}

class _TutorComprasPageState extends State<TutorComprasPage> {
  int _selectedTab = 0; // 0: Pendientes, 1: Comprados

  // Simulación de base de datos local para el estado de los items
  final List<Map<String, dynamic>> _items = [
    {"id": 1, "categoria": "PROTEÍNAS", "titulo": "Pechuga de Pollo", "subtitulo": "Para almuerzos de la semana", "cantidad": "500g", "comprado": false},
    {"id": 2, "categoria": "PROTEÍNAS", "titulo": "Huevos", "subtitulo": "Fuente principal de proteína", "cantidad": "12 unid.", "comprado": false},
    {"id": 3, "categoria": "VERDURAS", "titulo": "Espinaca Fresca", "subtitulo": "Para revueltos y ensaladas", "cantidad": "1 manojo", "comprado": false},
    {"id": 4, "categoria": "VERDURAS", "titulo": "Brócoli", "subtitulo": "Vapor o salteados", "cantidad": "1 unidad", "comprado": false},
    {"id": 5, "categoria": "LÁCTEOS Y OTROS", "titulo": "Yogur Griego", "subtitulo": "Sin azúcar añadida", "cantidad": "2 tarros", "comprado": false},
    {"id": 6, "categoria": "LÁCTEOS Y OTROS", "titulo": "Nueces", "subtitulo": "Mix de frutos secos", "cantidad": "100g", "comprado": false},
  ];

  void _toggleItem(int id) {
    setState(() {
      final index = _items.indexWhere((item) => item["id"] == id);
      if (index != -1) {
        _items[index]["comprado"] = !_items[index]["comprado"];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filtrar items según la pestaña seleccionada
    final displayItems = _items.where((item) => _selectedTab == 0 ? !item["comprado"] : item["comprado"]).toList();
    
    // Agrupar por categoría
    final Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (var item in displayItems) {
      if (!groupedItems.containsKey(item["categoria"])) {
        groupedItems[item["categoria"]] = [];
      }
      groupedItems[item["categoria"]]!.add(item);
    }

    return Stack(
      children: [
        // LISTA DE INGREDIENTES
        Positioned.fill(
          child: displayItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedTab == 0 ? Icons.shopping_basket_outlined : Icons.check_circle_outline,
                      size: 64,
                      color: colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedTab == 0 ? "¡Todo comprado!" : "No hay items comprados aún",
                      style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120), // Padding inferior extra para el FAB
                itemCount: groupedItems.keys.length,
                itemBuilder: (context, index) {
                  final categoria = groupedItems.keys.elementAt(index);
                  final itemsEnCategoria = groupedItems[categoria]!;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryHeader(context, categoria),
                      ...itemsEnCategoria.map((item) => _buildShoppingItem(
                        context, 
                        item["titulo"], 
                        item["subtitulo"], 
                        item["cantidad"],
                        item["id"],
                        item["comprado"],
                      )),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
        ),

        // FILTROS FLOTANTES (ESTILO FAB)
        Positioned(
          left: 0,
          right: 0,
          bottom: 30,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ColorFilter.mode(Colors.white.withOpacity(0.9), BlendMode.srcOver),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text("Pendientes"),
                        icon: Icon(Icons.list_alt_outlined, size: 20),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text("Comprados"),
                        icon: Icon(Icons.check_circle_outline, size: 20),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() => _selectedTab = newSelection.first);
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      selectedBackgroundColor: colorScheme.primary,
                      selectedForegroundColor: Colors.white,
                      side: BorderSide.none, // Eliminamos el borde del contenedor
                      visualDensity: VisualDensity.comfortable,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildShoppingItem(BuildContext context, String titulo, String subtitulo, String cantidad, int id, bool comprado) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _toggleItem(id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Checkbox(
                value: comprado,
                onChanged: (val) => _toggleItem(id),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: comprado ? TextDecoration.lineThrough : null,
                        color: comprado ? const Color(0xFF94A3B8) : null,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                cantidad,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
