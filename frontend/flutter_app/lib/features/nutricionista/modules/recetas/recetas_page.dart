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
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "Buscar por nombre de receta...",
                        hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppTema.azulPrincipal),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  height: 55,
                  child: FilledButton.icon(
                    onPressed: () => NutriSnack.show(context, "Módulo de creación en desarrollo"),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTema.verdeSalud,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white),
                    label: Text("NUEVA RECETA", 
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                  ),
                ),
              ],
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
                  style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                Text("Administración de preparaciones y composición nutricional por plato.", 
                  style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
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
        const Expanded(child: NutriResumenCard(titulo: "ESTADO", valor: "ACTIVO", colorValor: AppTema.azulOscuro, icon: Icons.check_circle_outline)),
      ],
    );
  }

  Widget _buildTableContainer(List<Map<String, dynamic>> visible) {
    return NutriTableContainer(
      child: _loading
        ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Consultando recetario..."))
        : visible.isEmpty
          ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No se encontraron recetas.")))
          : Theme(
              data: Theme.of(context).copyWith(
                cardTheme: const CardThemeData(elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
              ),
              child: PaginatedDataTable(
                header: null,
                rowsPerPage: 5,
                showFirstLastButtons: true,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                columns: [
                  _col("RECETA"),
                  _col("CALORÍAS"),
                  _col("PROTEÍNAS"),
                  _col("TIPO"),
                  _col("ACCIONES"),
                ],
                source: _RecetasDataSource(
                  recetas: visible,
                  context: context,
                ),
              ),
            ),
    );
  }

  DataColumn _col(String l) => DataColumn(
    label: Text(l, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))
  );
}

class _RecetasDataSource extends DataTableSource {
  final List<Map<String, dynamic>> recetas;
  final BuildContext context;

  _RecetasDataSource({
    required this.recetas,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= recetas.length) return null;
    final r = recetas[index];
    return DataRow(cells: [
      DataCell(Text(r["nombre"]?.toString() ?? "-", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600))),
      DataCell(Text("${r["calorias_totales"] ?? 0} kcal", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600))),
      DataCell(Text("${r["proteinas_totales"] ?? 0} g", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600))),
      DataCell(NutriBadge(label: (r["tipo_comida"] ?? "PLATO").toString().toUpperCase(), type: "info")),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 20, color: AppTema.azulPrincipal), 
            onPressed: () {},
            tooltip: "Ver detalles",
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)), 
            onPressed: () {},
            tooltip: "Editar",
          ),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => recetas.length;
  @override
  int get selectedRowCount => 0;
}
