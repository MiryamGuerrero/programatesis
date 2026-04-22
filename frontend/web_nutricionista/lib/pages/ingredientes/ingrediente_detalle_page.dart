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

  String _capitalize(String? text) {
    if (text == null || text.isEmpty) return 'Sin categoría';
    String raw = text.trim();
    if (raw.isEmpty) return 'Sin categoría';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

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
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B))),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.08),
                      foregroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Desactivar', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text(_capitalize(data['categoria_nombre']),
                  style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 14)),
              
              const SizedBox(height: 32),

              // GRÁFICO NUTRICIONAL
              Container(
                height: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 50,
                    sections: [
                      PieChartSectionData(value: (comp['proteinas_g'] ?? 0).toDouble(), color: const Color(0xFF3B82F6), radius: 25, showTitle: false),
                      PieChartSectionData(value: (comp['grasa_total_g'] ?? 0).toDouble(), color: const Color(0xFFF59E0B), radius: 25, showTitle: false),
                      PieChartSectionData(value: (comp['hidratos_carbono_g'] ?? 0).toDouble(), color: const Color(0xFF10B981), radius: 25, showTitle: false),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // MACRONUTRIENTES
              Text('Composición Nutricional (100g)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E293B))),
              const SizedBox(height: 16),
              _macroRow('Proteínas', '${comp['proteinas_g'] ?? 0}g', const Color(0xFF3B82F6)),
              _macroRow('Grasas', '${comp['grasa_total_g'] ?? 0}g', const Color(0xFFF59E0B)),
              _macroRow('Carbohidratos', '${comp['hidratos_carbono_g'] ?? 0}g', const Color(0xFF10B981)),
              _macroRow('Energía Total', '${comp['energia_kcal'] ?? 0} kcal', const Color(0xFFEF4444)),

              const SizedBox(height: 32),

              // ETIQUETAS / TAGS
              Text('Etiquetas y Alergias', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E293B))),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: (data['tags'] as List? ?? []).map((tag) {
                  final isRestriccion = tag['tipo'] == 'RESTRICCION';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isRestriccion ? Colors.red.withOpacity(0.1) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isRestriccion ? Colors.red.withOpacity(0.2) : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      tag['nombre'],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900, // NEGRITA PARA ALERGIAS/ETIQUETAS
                        color: isRestriccion ? Colors.red.shade800 : const Color(0xFF475569),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
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
