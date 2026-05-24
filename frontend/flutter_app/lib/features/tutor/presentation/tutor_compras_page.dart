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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final idPaciente = ref.watch(selectedPatientIdProvider);
    
    // NORMALIZAR FECHAS: Evita bucles infinitos por cambio de milisegundos
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));
    
    final comprasAsync = idPaciente != null
        ? ref.watch(listaComprasProvider((
            idPaciente: idPaciente, 
            start: today, 
            end: nextWeek
          )))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return Stack(
      children: [
        Positioned.fill(
          child: comprasAsync.when(
            data: (items) {
              final processedItems = items.map((item) {
                final id = item["id"].toString();
                return {
                  ...item,
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
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
                        item["titulo"] ?? "Ingrediente", 
                        "", 
                        item["cantidad"] ?? "1 unid.",
                        item["id"].toString(),
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
