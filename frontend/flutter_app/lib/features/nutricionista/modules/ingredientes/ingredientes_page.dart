import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import 'ingrediente_detalle_page.dart';
import 'ingrediente_form_page.dart';

class IngredientesPage extends ConsumerStatefulWidget {
  const IngredientesPage({super.key});
  @override
  ConsumerState<IngredientesPage> createState() => _IngredientesPageState();
}

class _IngredientesPageState extends ConsumerState<IngredientesPage> {
  int? _selectedId;
  bool _isEditing = false;

  List<dynamic> _items = [];
  List<dynamic> _groups = [];
  List<dynamic> _subgroups = [];
  int _total = 0;
  bool _loading = true;
  String _query = '';
  int? _groupId;
  int? _subgroupId;
  int _page = 0;
  final int _limit = 1000; // Aumentado para PaginatedDataTable

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadFilters();
      _fetch();
    });
  }

  Future<void> _loadFilters() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final g = await repo.fetchCatalog('nutricion', 'grupo_alimentario');
      List<dynamic> sg = [];
      try { sg = await repo.fetchCatalog('nutricion', 'subgrupo_alimentario'); } catch(_) {}
      if (mounted) setState(() { _groups = g; _subgroups = sg; });
    } catch (_) {}
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final data = await repo.ingredientesLista(
          q: _query, cat: _groupId, limit: _limit, offset: 0);
      if (mounted) {
        setState(() {
          _items = data['items'] ?? [];
          _total = data['total'] ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: Row(
        children: [
          Expanded(
            flex: _selectedId != null ? 3 : 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatsRow(),
                  const SizedBox(height: 32),
                  _buildToolbar(),
                  const SizedBox(height: 24),
                  _buildTableContainer(),
                ],
              ),
            ),
          ),
          if (_selectedId != null)
            Expanded(
              flex: 2,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white, 
                  border: Border(left: BorderSide(color: Color(0xFFEEEEEE))),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(-5, 0))],
                ),
                child: _isEditing
                    ? IngredienteFormPage(
                        idIngrediente: _selectedId == 0 ? null : _selectedId,
                        onBack: () { setState(() => _isEditing = false); _fetch(); },
                      )
                    : IngredienteDetallePage(
                        idIngrediente: _selectedId!,
                        onBack: () => setState(() { _selectedId = null; }),
                        onEdit: () => setState(() => _isEditing = true),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Catálogo Maestro de Alimentos", 
          style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text("Gestión de base nutricional, grupos alimentarios y composición química.", 
          style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: NutriResumenCard(titulo: "TOTAL ALIMENTOS", valor: "$_total", icon: Icons.restaurant_menu_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "GRUPOS", valor: "${_groups.length}", colorValor: AppTema.verdeSalud, icon: Icons.category_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "SUBGRUPOS", valor: "${_subgroups.length}", colorValor: AppTema.azulOscuro, icon: Icons.layers_rounded)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Column(
        children: [
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
                      hintText: "Buscar alimento...",
                      hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTema.azulPrincipal),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onChanged: (v) { _query = v; _fetch(); },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                height: 55,
                child: FilledButton.icon(
                  onPressed: () => setState(() { _selectedId = 0; _isEditing = true; }),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTema.verdeSalud,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white),
                  label: Text("NUEVO ALIMENTO", 
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text("FILTRAR POR:", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
              const SizedBox(width: 16),
              _buildFilterDropdown("GRUPO", _groups, _groupId, (v) => setState(() { _groupId = v; _fetch(); })),
              const SizedBox(width: 12),
              _buildFilterDropdown("SUBGRUPO", _subgroups, _subgroupId, (v) => setState(() { _subgroupId = v; _fetch(); })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, List<dynamic> items, int? value, Function(int?) onChanged) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppTema.grisLienzo.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          hint: Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700)),
          items: [
            DropdownMenuItem(value: null, child: Text("TODOS LOS ${label}S", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700))),
            ...items.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['nombre'].toString().toUpperCase(), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTableContainer() {
    return NutriTableContainer(
      child: _loading && _items.isEmpty
        ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Sincronizando catálogo..."))
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
                _col("ALIMENTO"),
                _col("CATEGORÍA"),
                _col("SUBGRUPO"),
                _col("KCAL/100G"),
                _col("PROT/100G"),
                _col("ACCIONES"),
              ],
              source: _IngredientesDataSource(
                items: _items,
                onAction: (id, edit) => setState(() { _selectedId = id; _isEditing = edit; }),
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

class _IngredientesDataSource extends DataTableSource {
  final List<dynamic> items;
  final Function(int, bool) onAction;
  final BuildContext context;

  _IngredientesDataSource({
    required this.items,
    required this.onAction,
    required this.context,
  });

  String _capitalize(String? text) {
    if (text == null || text.isEmpty) return '-';
    String raw = text.trim();
    if (raw.isEmpty) return '-';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    double val = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val == val.toInt().toDouble()) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  @override
  DataRow? getRow(int index) {
    if (index >= items.length) return null;
    final ing = items[index];
    return DataRow(cells: [
      DataCell(Text(ing['nombre'], style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600))),
      DataCell(Text(_capitalize(ing['categoria']), style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600))),
      DataCell(_subgroupBadge(ing['subgrupo'] ?? '-')),
      DataCell(Text("${_fmt(ing['energia_kcal'])} kcal", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600))),
      DataCell(Text("${_fmt(ing['proteinas_g'])} g", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600))),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTema.azulPrincipal), 
            onPressed: () => onAction(ing['id'], false)
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey), 
            onPressed: () => onAction(ing['id'], true)
          ),
        ],
      )),
    ]);
  }

  Widget _subgroupBadge(String text) {
    if (text == '-') return const Text('-', style: TextStyle(color: Colors.grey));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppTema.cianLimpio.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(_capitalize(text), style: const TextStyle(color: AppTema.cianLimpio, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => items.length;
  @override
  int get selectedRowCount => 0;
}
