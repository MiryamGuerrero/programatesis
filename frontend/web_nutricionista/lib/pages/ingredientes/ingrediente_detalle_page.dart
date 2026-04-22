import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/nutricionista_providers.dart';

class IngredienteDetallePage extends ConsumerWidget {
  final int id;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  const IngredienteDetallePage({
    super.key,
    required this.id,
    required this.onClose,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(ingredienteDetalleProvider(id));

    return detalleAsync.when(
      data: (data) => _buildContent(context, data),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text('Error al cargar detalle: $e')),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final comp = data['composicion'] ?? {};
    
    return Column(
      children: [
        // CABECERA DETALLE
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), foregroundColor: Colors.red),
                    child: const Text('Desactivar'),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              // NOMBRE Y CATEGORIA
              Text(data['nombre'] ?? 'Sin nombre',
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(data['categoria_nombre'] ?? 'Sin categoría',
                  style: GoogleFonts.inter(color: Colors.blue, fontWeight: FontWeight.w600)),
              
              const SizedBox(height: 32),

              // GRÁFICO NUTRICIONAL
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(value: (comp['proteinas_g'] ?? 0).toDouble(), color: Colors.blue, radius: 20, showTitle: false),
                      PieChartSectionData(value: (comp['grasa_total_g'] ?? 0).toDouble(), color: Colors.orange, radius: 20, showTitle: false),
                      PieChartSectionData(value: (comp['hidratos_carbono_g'] ?? 0).toDouble(), color: Colors.green, radius: 20, showTitle: false),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // MACRONUTRIENTES
              _macroRow('Proteínas', '${comp['proteinas_g'] ?? 0}g', Colors.blue),
              _macroRow('Grasas', '${comp['grasa_total_g'] ?? 0}g', Colors.orange),
              _macroRow('Carbohidratos', '${comp['hidratos_carbono_g'] ?? 0}g', Colors.green),
              _macroRow('Energía', '${comp['energia_kcal'] ?? 0} kcal', Colors.red),

              const SizedBox(height: 32),

              // ETIQUETAS / TAGS
              Text('Etiquetas de Seguridad', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: (data['tags'] as List? ?? []).map((tag) => Chip(
                  label: Text(tag['nombre'], style: const TextStyle(fontSize: 12)),
                  backgroundColor: tag['tipo'] == 'RESTRICCION' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                )).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _macroRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
