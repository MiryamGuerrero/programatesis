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
      final repo = ref.read(inteligenciaRepositoryProvider);
      final res = await repo.obtenerIngredienteDetalle(widget.idIngrediente);
      if (mounted) setState(() { _data = res; _loading = false; });
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
              Text(_data!['nombre'] ?? '-', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(_data!['categoria_nombre'] ?? '-', style: GoogleFonts.inter(color: Colors.blue, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              _buildChart(comp),
              const SizedBox(height: 32),
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
          IconButton(onPressed: widget.onBack, icon: const Icon(Icons.close_rounded)),
          Row(
            children: [
              OutlinedButton.icon(onPressed: widget.onEdit, icon: const Icon(Icons.edit, size: 14), label: const Text("Editar")),
              const SizedBox(width: 8),
              IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline, color: Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChart(Map comp) {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 50,
          sections: [
            PieChartSectionData(value: (comp['proteinas_g'] ?? 0).toDouble(), color: Colors.blue, radius: 15, showTitle: false),
            PieChartSectionData(value: (comp['grasa_total_g'] ?? 0).toDouble(), color: Colors.orange, radius: 15, showTitle: false),
            PieChartSectionData(value: (comp['hidratos_carbono_g'] ?? 0).toDouble(), color: Colors.green, radius: 15, showTitle: false),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroGrid(Map comp) {
    return Column(
      children: [
        _macroTile('Proteínas', '${comp['proteinas_g'] ?? 0}g', Colors.blue),
        _macroTile('Grasas', '${comp['grasa_total_g'] ?? 0}g', Colors.orange),
        _macroTile('Carbohidratos', '${comp['hidratos_carbono_g'] ?? 0}g', Colors.green),
        _macroTile('Energía', '${comp['energia_kcal'] ?? 0} kcal', Colors.red),
      ],
    );
  }

  Widget _macroTile(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTags() {
    final tags = _data!['tags'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Etiquetas de Seguridad", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: tags.map((t) => Chip(
            label: Text(t['nombre'], style: const TextStyle(fontSize: 10)),
            backgroundColor: t['tipo'] == 'RESTRICCION' ? Colors.red.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
            side: BorderSide.none,
          )).toList(),
        ),
      ],
    );
  }
}
