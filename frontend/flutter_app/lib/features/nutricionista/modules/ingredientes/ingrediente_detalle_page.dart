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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      decoration: const BoxDecoration(
        color: AppTema.azulPrincipal,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Text(
            "Detalle del Ingrediente",
            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
            tooltip: "Editar ingrediente",
          ),
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Padding(padding: EdgeInsets.all(40), child: NutriLoading(mensaje: "Cargando ficha..."));
    if (_error != null || _data == null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text("Error al cargar detalle", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? "No se encontraron datos", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    final nombre = _data!['nombre'] ?? '-';
    final categoria = _data!['grupo_nombre'] ?? 'Sin categoría';
    final subgrupo = _data!['subgrupo_nombre'] ?? 'Sin subgrupo';
    
    // El backend devuelve una estructura plana y a veces strings formateados
    final double kcal = _parse(_data!['energia_kcal']);
    final double prot = _parse(_data!['proteinas_g']);
    final double gras = _parse(_data!['grasa_total_g']);
    final double carb = _parse(_data!['hidratos_carbono_g']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(nombre, categoria, subgrupo),
          const SizedBox(height: 32),
          _buildNutritionSummary(kcal, prot, gras, carb),
          const SizedBox(height: 32),
          _buildExtraInfo(),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String nombre, String categoria, String subgrupo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nombre.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: AppTema.azulOscuro, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildSmallTag(categoria, AppTema.azulPrincipal),
            const SizedBox(width: 8),
            _buildSmallTag(subgrupo, AppTema.verdeSalud),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
    );
  }

  Widget _buildNutritionSummary(double kcal, double prot, double gras, double carb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("VALORES POR 100G", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
        const SizedBox(height: 16),
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
    );
  }

  Widget _buildNutriItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        Text(label, style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey)),
      ],
    );
  }

  Widget _buildExtraInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTema.grisLienzo.withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Row(
        children: [
          const Icon(Icons.help_outline_rounded, color: AppTema.azulPrincipal, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Esta información es de carácter referencial basada en el catálogo maestro.",
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: _buildBody(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
