import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  double _parse(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Future<void> _fetch() async {
    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final res = await repo.obtenerIngredienteDetalle(widget.idIngrediente);
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTema.azulPrincipal, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text(
          "Ficha Técnica del Alimento",
          style: GoogleFonts.montserrat(color: AppTema.azulOscuro, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: IconButton(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_note_rounded, color: AppTema.azulPrincipal, size: 28),
                tooltip: "Editar ingrediente",
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: NutriLoading(mensaje: "Consultando base nutricional..."));
    
    if (_error != null || _data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 24),
            Text("Error al cargar la información", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(_error ?? "No se encontraron datos", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            FilledButton(onPressed: widget.onBack, child: const Text("REGRESAR")),
          ],
        ),
      );
    }

    final nombre = _data!['nombre'] ?? '-';
    final categoria = _data!['grupo_nombre'] ?? 'Sin categoría';
    final subgrupo = _data!['subgrupo_nombre'] ?? 'Sin subgrupo';
    
    final double kcal = _parse(_data!['energia_kcal']);
    final double prot = _parse(_data!['proteinas_g']);
    final double gras = _parse(_data!['grasa_total_g']);
    final double carb = _parse(_data!['hidratos_carbono_g']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(nombre, categoria, subgrupo),
          const SizedBox(height: 40),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildNutritionSummary(kcal, prot, gras, carb),
                    const SizedBox(height: 40),
                    _buildDetailedComponents(),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildMacroChart(prot, gras, carb),
                    const SizedBox(height: 40),
                    _buildDeleteAction(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChart(double prot, double gras, double carb) {
    final total = prot + gras + carb;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("DISTRIBUCIÓN DE MACROS", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(color: Colors.blue, value: prot, title: '${(prot*100/total).toStringAsFixed(1)}%', radius: 40, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: Colors.amber, value: gras, title: '${(gras*100/total).toStringAsFixed(1)}%', radius: 40, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: Colors.green, value: carb, title: '${(carb*100/total).toStringAsFixed(1)}%', radius: 40, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _chartLegend("Prot", Colors.blue),
              _chartLegend("Gras", Colors.amber),
              _chartLegend("Carb", Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
      ],
    );
  }

  Widget _buildDetailedComponents() {
    final Map<String, String> nombresFormateados = {
      'agua_g': 'Agua (g)',
      'alcohol_g': 'Alcohol (g)',
      'almidon_g': 'Almidón (g)',
      'azucares_sencillos_g': 'Azúcares Sencillos (g)',
      'azucares_libres_g': 'Azúcares Libres (g)',
      'fibra_vegetal_g': 'Fibra Vegetal (g)',
      'ags_g': 'AG Saturados (g)',
      'agm_g': 'AG Monoinsaturados (g)',
      'agp_g': 'AG Poliinsaturados (g)',
      'colesterol_mg': 'Colesterol (mg)',
      'vitamina_a_eq_retinol_ug': 'Vit A (ug)',
      'retinol_ug': 'Retinol (ug)',
      'carotenoides_eq_beta_caroteno_ug': 'Carotenoides (ug)',
      'vit_d_ug': 'Vit D (ug)',
      'vit_e_eq_alpha_tocoferol_mg': 'Vit E (mg)',
      'vit_k_ug': 'Vit K (ug)',
      'vitamina_b1_mg': 'Vit B1 (mg)',
      'vitamina_b2_mg': 'Vit B2 (mg)',
      'eq_niacina_mg': 'Niacina (mg)',
      'vit_b6_mg': 'Vit B6 (mg)',
      'eq_folato_dietetico_ug': 'Folato (ug)',
      'vit_b12_ug': 'Vit B12 (ug)',
      'pantotenico_mg': 'Pantoténico (mg)',
      'biotina_ug': 'Biotina (ug)',
      'vit_c_mg': 'Vit C (mg)',
      'calcio_mg': 'Calcio (mg)',
      'fosforo_mg': 'Fósforo (mg)',
      'hierro_mg': 'Hierro (mg)',
      'iodo_ug': 'Iodo (ug)',
      'cinc_mg': 'Cinc (mg)',
      'magnesio_mg': 'Magnesio (mg)',
      'sodio_mg': 'Sodio (mg)',
      'potasio_mg': 'Potasio (mg)',
      'manganeso_mg': 'Manganeso (mg)',
      'cobre_mg': 'Cobre (mg)',
      'selenio_ug': 'Selenio (ug)',
      'omega3_g': 'Omega 3 (g)',
      'grasas_trans_g': 'Grasas Trans (g)',
      'polifenoles_mg': 'Polifenoles (mg)',
      'probioticos_billones_ufc': 'Probióticos (B ufc)',
    };

    final items = _data!.entries
        .where((e) => nombresFormateados.containsKey(e.key))
        .where((e) => _parse(e.value) > 0)
        .toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("OTROS COMPONENTES RELEVANTES", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.05))),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100, indent: 24, endIndent: 24),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(nombresFormateados[item.key]!, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700)),
                    Text(_fmt(item.value), style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: AppTema.azulOscuro)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _fmt(dynamic v) {
    double val = _parse(v);
    if (val == val.toInt().toDouble()) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  Widget _buildDeleteAction() {
    return Center(
      child: TextButton.icon(
        onPressed: _confirmDelete,
        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
        label: Text("ELIMINAR ALIMENTO", style: GoogleFonts.montserrat(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
        style: TextButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.05), 
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar ingrediente?"),
        content: const Text("Esta acción eliminará permanentemente el ingrediente del catálogo nutricional."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("ELIMINAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final repo = ref.read(inteligenciaRepositoryProvider);
        await repo.eliminarIngrediente(widget.idIngrediente);
        widget.onBack();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildInfoSection(String nombre, String categoria, String subgrupo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nombre.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, color: AppTema.azulOscuro, letterSpacing: -0.8)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildSmallTag(categoria, AppTema.azulPrincipal),
            const SizedBox(width: 12),
            _buildSmallTag(subgrupo, AppTema.verdeSalud),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8)),
    );
  }

  Widget _buildNutritionSummary(double kcal, double prot, double gras, double carb) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("VALORES NUTRICIONALES (POR 100G)", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNutriItem("ENERGÍA", "${kcal.toStringAsFixed(0)} kcal", Icons.bolt_rounded, Colors.orange),
              _buildNutriItem("PROTEÍNA", "${prot.toStringAsFixed(1)} g", Icons.fitness_center_rounded, Colors.blue),
              _buildNutriItem("GRASAS", "${gras.toStringAsFixed(1)} g", Icons.water_drop_rounded, Colors.amber),
              _buildNutriItem("CARBS", "${carb.toStringAsFixed(1)} g", Icons.bakery_dining_rounded, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutriItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(value, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
      ],
    );
  }
}
