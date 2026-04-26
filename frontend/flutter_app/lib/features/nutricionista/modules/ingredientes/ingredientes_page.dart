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
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadFilters();
      _fetch();
    });
  }

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
          q: _query, cat: _groupId, limit: _limit, offset: _page * _limit);
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
                  const SizedBox(height: 24),
                  _buildPagination(),
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
          style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text("Gestión de base nutricional, grupos alimentarios y composición química.", 
          style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 13)),
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
        Expanded(child: NutriResumenCard(titulo: "SUBGRUPOS", valor: "${_subgroups.length}", colorValor: AppTema.cianLimpio, icon: Icons.layers_rounded)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Column(
        children: [
          NutriTableToolbar(
            actionLabel: "Nuevo Alimento",
            onAction: () => setState(() { _selectedId = 0; _isEditing = true; }),
            onSearch: (v) { _query = v; _page = 0; _fetch(); },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text("FILTRAR POR:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(width: 16),
              _buildFilterDropdown("GRUPO", _groups, _groupId, (v) => setState(() { _groupId = v; _page = 0; _fetch(); })),
              const SizedBox(width: 12),
              _buildFilterDropdown("SUBGRUPO", _subgroups, _subgroupId, (v) => setState(() { _subgroupId = v; _page = 0; _fetch(); })),
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
          hint: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          items: [
            DropdownMenuItem(value: null, child: Text("TODOS LOS ${label}S", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ...items.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['nombre'].toString().toUpperCase(), style: const TextStyle(fontSize: 10)))),
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
        : DataTable(
            headingRowColor: WidgetStateProperty.all(AppTema.pastelCeleste),
            columns: [
              _col("ALIMENTO"),
              _col("CATEGORÍA"),
              _col("SUBGRUPO"),
              _col("KCAL/100G"),
              _col("PROT/100G"),
              _col("ACCIONES"),
            ],
            rows: _items.map((ing) => DataRow(
              cells: [
                DataCell(Text(ing['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTema.azulPrincipal))),
                DataCell(Text(_capitalize(ing['categoria']), style: const TextStyle(fontSize: 12))),
                DataCell(_subgroupBadge(ing['subgrupo'] ?? '-')),
                DataCell(Text("${_fmt(ing['energia_kcal'])} kcal", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataCell(Text("${_fmt(ing['proteinas_g'])} g", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTema.azulPrincipal), 
                      onPressed: () => setState(() { _selectedId = ing['id']; _isEditing = false; })
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey), 
                      onPressed: () => setState(() { _selectedId = ing['id']; _isEditing = true; })
                    ),
                  ],
                )),
              ],
            )).toList(),
          ),
    );
  }

  DataColumn _col(String l) => DataColumn(label: Text(l, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal)));

  Widget _subgroupBadge(String text) {
    if (text == '-') return const Text('-', style: TextStyle(color: Colors.grey));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppTema.cianLimpio.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(_capitalize(text), style: const TextStyle(color: AppTema.cianLimpio, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPagination() {
    int totalP = (_total / _limit).ceil();
    if (totalP == 0) totalP = 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Mostrando ${(_page * _limit) + 1} - ${((_page + 1) * _limit).clamp(0, _total)} de $_total registros', 
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.chevron_left),
              label: const Text("ANTERIOR"),
              onPressed: _page > 0 ? () { setState(() => _page--); _fetch(); } : null,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEEEEEE))),
              child: Text("${_page + 1} / $totalP", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.chevron_right),
              label: const Text("SIGUIENTE"),
              onPressed: (_page + 1) < totalP ? () { setState(() => _page++); _fetch(); } : null,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            ),
          ],
        ),
      ],
    );
  }
}
