import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/state/app_providers.dart';

class IngredienteDetallePage extends ConsumerStatefulWidget {
  final int idIngrediente;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  const IngredienteDetallePage({
    super.key,
    required this.idIngrediente,
    required this.onBack,
    required this.onEdit,
  });

  @override
  ConsumerState<IngredienteDetallePage> createState() => _IngredienteDetallePageState();
}

class _IngredienteDetallePageState extends ConsumerState<IngredienteDetallePage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("ingredientes/${widget.idIngrediente}");
      if (mounted) setState(() { _data = res.data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Colors.indigo));
    if (_data == null) return const Center(child: Text("Error al cargar detalle"));

    final comp = _data!['composicion'] ?? {};

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(_data!['nombre'] ?? '-', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              Text(_data!['categoria_nombre'] ?? '-', style: GoogleFonts.inter(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 32),
              
              // Contenedor de la gráfica con la energía en el centro
              _buildChartSection(comp),
              
              const SizedBox(height: 32),
              Text("Desglose Nutricional (por 100g)", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 16),
              _buildMacroGrid(comp),
              
              const SizedBox(height: 32),
              _buildTags(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: widget.onBack, icon: const Icon(Icons.close_rounded, color: Colors.blueGrey)),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onEdit, 
                icon: const Icon(Icons.edit_outlined, size: 14), 
                label: const Text("Editar Ficha"),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.blue.shade200), foregroundColor: Colors.blue.shade700),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {}, 
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: "Eliminar ingrediente",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(Map comp) {
    double prot = (comp['proteinas_g'] ?? 0).toDouble();
    double fat = (comp['grasa_total_g'] ?? 0).toDouble();
    double carb = (comp['hidratos_carbono_g'] ?? 0).toDouble();
    double energy = (comp['energia_kcal'] ?? 0).toDouble();
    double total = prot + fat + carb;

    // Si todo es cero, mostramos un círculo gris
    bool hasData = total > 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 65,
              startDegreeOffset: -90,
              sections: hasData ? [
                PieChartSectionData(
                  value: prot, 
                  color: const Color(0xFF3B82F6), 
                  radius: 20, 
                  title: '${((prot/total)*100).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  showTitle: total > 5
                ),
                PieChartSectionData(
                  value: fat, 
                  color: const Color(0xFFF59E0B), 
                  radius: 20, 
                  title: '${((fat/total)*100).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  showTitle: total > 5
                ),
                PieChartSectionData(
                  value: carb, 
                  color: const Color(0xFF10B981), 
                  radius: 20, 
                  title: '${((carb/total)*100).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  showTitle: total > 5
                ),
              ] : [
                PieChartSectionData(value: 1, color: Colors.grey.shade200, radius: 20, showTitle: false),
              ],
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${energy.toStringAsFixed(0)}',
              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
            ),
            Text(
              'KCAL',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade400, letterSpacing: 1.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroGrid(Map comp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9))
      ),
      child: Column(
        children: [
          _macroRow('Proteínas', '${comp['proteinas_g'] ?? 0} g', const Color(0xFF3B82F6)),
          const Divider(height: 24),
          _macroRow('Grasas Totales', '${comp['grasa_total_g'] ?? 0} g', const Color(0xFFF59E0B)),
          const Divider(height: 24),
          _macroRow('Carbohidratos', '${comp['hidratos_carbono_g'] ?? 0} g', const Color(0xFF10B981)),
          const Divider(height: 24),
          _macroRow('Fibra Vegetal', '${comp['fibra_g'] ?? 0} g', Colors.brown.shade300),
          const Divider(height: 24),
          _macroRow('Sodio', '${comp['sodio_mg'] ?? 0} mg', Colors.blueGrey),
        ],
      ),
    );
  }

  Widget _macroRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildTags() {
    final tags = _data!['tags'] as List? ?? [];
    if (tags.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Etiquetas de Seguridad Alimentaria", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100)
            ),
            child: Text(
              t['nombre'], 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800)
            ),
          )).toList(),
        ),
      ],
    );
  }
}
