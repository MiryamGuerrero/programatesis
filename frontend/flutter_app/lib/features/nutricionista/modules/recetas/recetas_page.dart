import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class RecetasPage extends ConsumerStatefulWidget {
  const RecetasPage({super.key});

  @override
  ConsumerState<RecetasPage> createState() => _RecetasPageState();
}

class _RecetasPageState extends ConsumerState<RecetasPage> {
  String _query = "";

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _recetas = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadRecetas);
  }

  Future<void> _loadRecetas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final data = await repo.fetchRecetas();
      if (!mounted) return;
      setState(() => _recetas = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _query.isEmpty
        ? _recetas
        : _recetas.where((row) {
            final nombre = row["nombre"]?.toString().toLowerCase() ?? "";
            return nombre.contains(_query.toLowerCase());
          }).toList();

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(visible.length),
            const SizedBox(height: 32),
            NutriTableToolbar(
              actionLabel: "Nueva Receta",
              onAction: () => NutriSnack.show(context, "Módulo de creación en desarrollo"),
              onSearch: (v) => setState(() => _query = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 24),
            _buildTableContainer(visible),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Recetario Terapéutico", 
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                Text("Administración de preparaciones y composición nutricional por plato.", 
                  style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 13)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: AppTema.azulPrincipal), 
              onPressed: _loadRecetas,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int visibles) {
    return Row(
      children: [
        Expanded(child: NutriResumenCard(titulo: "TOTAL RECETAS", valor: "${_recetas.length}", icon: Icons.menu_book_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "FILTRADAS", valor: "$visibles", colorValor: AppTema.verdeSalud, icon: Icons.filter_list_rounded)),
        const SizedBox(width: 20),
        const Expanded(child: NutriResumenCard(titulo: "ESTADO", valor: "ACTIVO", colorValor: AppTema.cianLimpio, icon: Icons.check_circle_outline)),
      ],
    );
  }

  Widget _buildTableContainer(List<Map<String, dynamic>> visible) {
    return NutriTableContainer(
      child: _loading
        ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Consultando recetario..."))
        : visible.isEmpty
          ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No se encontraron recetas.")))
          : DataTable(
              headingRowColor: WidgetStateProperty.all(AppTema.pastelCeleste),
              columns: [
                _col("RECETA"),
                _col("CALORÍAS"),
                _col("PROTEÍNAS"),
                _col("TIPO"),
                _col("ACCIONES"),
              ],
              rows: visible.map((r) => DataRow(
                cells: [
                  DataCell(Text(r["nombre"]?.toString() ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTema.azulPrincipal))),
                  DataCell(Text("${r["calorias_totales"] ?? 0} kcal", style: const TextStyle(fontSize: 12))),
                  DataCell(Text("${r["proteinas_totales"] ?? 0} g", style: const TextStyle(fontSize: 12))),
                  DataCell(NutriBadge(label: (r["tipo_comida"] ?? "PLATO").toString().toUpperCase(), type: "info")),
                  DataCell(Row(
                    children: [
                      IconButton(icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTema.azulPrincipal), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey), onPressed: () {}),
                    ],
                  )),
                ],
              )).toList(),
            ),
    );
  }

  DataColumn _col(String l) => DataColumn(label: Text(l, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal)));
}
