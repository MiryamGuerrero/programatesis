import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';

class TutorComprasPage extends ConsumerStatefulWidget {
  const TutorComprasPage({super.key});

  @override
  ConsumerState<TutorComprasPage> createState() => _TutorComprasPageState();
}

class _TutorComprasPageState extends ConsumerState<TutorComprasPage> {
  int _selectedTab = 0; // 0: Pendientes, 1: Comprados
  int _selectedDateRange = 1; // 0: 3 días, 1: Esta Semana (7 días), 2: Próxima Semana
  final Set<String> _localComprados = {}; // Manejo visual temporal

  void _toggleItem(String id) {
    setState(() {
      if (_localComprados.contains(id)) {
        _localComprados.remove(id);
      } else {
        _localComprados.add(id);
      }
    });
  }

  ({DateTime start, DateTime end}) _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_selectedDateRange) {
      case 0:
        return (start: today, end: today.add(const Duration(days: 3)));
      case 2:
        final nextWeekStart = today.add(const Duration(days: 7));
        return (start: nextWeekStart, end: nextWeekStart.add(const Duration(days: 7)));
      case 1:
      default:
        return (start: today, end: today.add(const Duration(days: 7)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final idPaciente = ref.watch(selectedPatientIdProvider);
    final dateRange = _getDateRange();
    
    final comprasAsync = idPaciente != null
        ? ref.watch(listaComprasProvider((
            idPaciente: idPaciente, 
            start: dateRange.start, 
            end: dateRange.end
          )))
        : const AsyncValue<Map<String, List<Map<String, dynamic>>>>.data({});

    return Column(
      children: [
        // Filtros de fecha
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              _buildDateChip("Próximos 3 días", 0),
              const SizedBox(width: 8),
              _buildDateChip("Esta Semana", 1),
              const SizedBox(width: 8),
              _buildDateChip("Próxima Semana", 2),
            ],
          ),
        ),
        
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: comprasAsync.when(
                  data: (groupedData) {
                    // Aplanar los items para procesarlos
                    final List<Map<String, dynamic>> allItems = [];
                    groupedData.forEach((categoria, items) {
                      for (var item in items) {
                        allItems.add({
                          ...item,
                          "categoria": categoria,
                        });
                      }
                    });

                    final processedItems = allItems.map((item) {
                      final id = "${item['categoria']}_${item['nombre']}";
                      return {
                        ...item,
                        "id_virtual": id,
                        "comprado": _localComprados.contains(id),
                      };
                    }).toList();

                    final displayItems = processedItems.where((item) => 
                      _selectedTab == 0 ? !(item["comprado"] as bool) : (item["comprado"] as bool)
                    ).toList();

                    if (displayItems.isEmpty) {
                      return Center(
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
                      );
                    }

                    final Map<String, List<Map<String, dynamic>>> groupedItems = {};
                    for (var item in displayItems) {
                      final cat = item["categoria"] ?? "OTROS";
                      if (!groupedItems.containsKey(cat)) groupedItems[cat] = [];
                      groupedItems[cat]!.add(item);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
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
                              item["nombre"] ?? "Ingrediente", 
                              "", 
                              "${item["cantidad"]} ${item["unidad"]}",
                              item["id_virtual"],
                              item["comprado"] as bool,
                            )),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text("Error: $err")),
                ),
              ),

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
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: Colors.white.withOpacity(0.7),
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
                              side: BorderSide.none,
                              visualDensity: VisualDensity.comfortable,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateChip(String label, int index) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedDateRange == index,
      onSelected: (selected) {
        if (selected) setState(() => _selectedDateRange = index);
      },
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

  Widget _buildShoppingItem(BuildContext context, String titulo, String subtitulo, String cantidad, String id, bool comprado) {
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
