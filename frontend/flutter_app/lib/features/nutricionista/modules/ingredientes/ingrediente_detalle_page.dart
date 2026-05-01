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
              Text(_data!['nombre'] ?? '-', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              Text(_data!['categoria_nombre'] ?? '-', style: GoogleFonts.lato(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 32),
              
              // Contenedor de la gráfica con la energía en el centro
              _buildChartSection(comp),
              
              const SizedBox(height: 32),
              Text("Desglose Nutricional (por 100g)", style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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

    bool hasData = total > 0;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0, // Eliminar espacio para un look más limpio
                centerSpaceRadius: 70,
                startDegreeOffset: -90,
                sections: hasData ? [
                  PieChartSectionData(
                    value: prot, 
                    color: const Color(0xFF3B82F6), 
                    radius: 12, // Radio más delgado
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: fat, 
                    color: const Color(0xFFF59E0B), 
                    radius: 12,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: carb, 
                    color: const Color(0xFF10B981), 
                    radius: 12,
                    showTitle: false,
                  ),
                ] : [
                  PieChartSectionData(value: 1, color: Colors.grey.shade100, radius: 10, showTitle: false),
                ],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                energy.toStringAsFixed(0),
                style: GoogleFonts.lato(fontSize: 40, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -1),
              ),
              Text(
                'KCAL / 100g',
                style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade300, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroGrid(Map comp) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _macroCard('Proteínas', '${comp['proteinas_g'] ?? 0}g', const Color(0xFF3B82F6))),
            const SizedBox(width: 12),
            Expanded(child: _macroCard('Grasas', '${comp['grasa_total_g'] ?? 0}g', const Color(0xFFF59E0B))),
            const SizedBox(width: 12),
            Expanded(child: _macroCard('Carbs', '${comp['hidratos_carbono_g'] ?? 0}g', const Color(0xFF10B981))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _macroCard('Fibra', '${comp['fibra_g'] ?? 0}g', Colors.brown.shade300)),
            const SizedBox(width: 12),
            Expanded(child: _macroCard('Sodio', '${comp['sodio_mg'] ?? 0}mg', Colors.blueGrey.shade400)),
          ],
        ),
      ],
    );
  }

  Widget _macroCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.lato(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        ],
      ),
    );
  }

  Widget _buildTags() {
    final tags = _data!['tags'] as List? ?? [];
    if (tags.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.security_rounded, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text("SEGURIDAD ALIMENTARIA", style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              t['nombre'].toString().toUpperCase(), 
              style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF334155))
            ),
          )).toList(),
        ),
      ],
    );
  }
}
