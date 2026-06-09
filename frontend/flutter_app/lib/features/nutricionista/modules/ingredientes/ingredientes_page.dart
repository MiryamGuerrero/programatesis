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

enum IngredienteView { list, detail, form }

class _IngredientesPageState extends ConsumerState<IngredientesPage> {
  IngredienteView _currentView = IngredienteView.list;
  int? _activeId;

  List<dynamic> _items = [];
  List<dynamic> _groups = [];
  List<dynamic> _subgroups = [];
  List<dynamic> _subgroupsFiltrados = [];
  int _total = 0;
  bool _loading = true;
  String _query = '';
  int? _groupId;
  int? _subgroupId;
  final int _limit = 1000;

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
      final sg = await repo.fetchCatalog('nutricion', 'subgrupo_alimentario');
      if (mounted) {
        setState(() {
          _groups = g;
          _subgroups = sg;
          _subgroupsFiltrados = sg;
        });
      }
    } catch (_) {}
  }

  void _onGroupChanged(int? id) {
    setState(() {
      _groupId = id;
      _subgroupId = null; // Reset subgroup when group changes
      if (id == null) {
        _subgroupsFiltrados = _subgroups;
      } else {
        _subgroupsFiltrados =
            _subgroups.where((s) => s['id_grupo_alimentario'] == id).toList();
      }
      _fetch();
    });
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final data = await repo.ingredientesLista(
          q: _query,
          cat: _groupId,
          subcat: _subgroupId,
          limit: _limit,
          offset: 0);
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

  void _showDetail(int id) {
    if (id == -1) {
      _fetch();
      return;
    }
    setState(() {
      _activeId = id;
      _currentView = IngredienteView.detail;
    });
  }

  void _showForm([int? id]) {
    setState(() {
      _activeId = id;
      _currentView = IngredienteView.form;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentView) {
      case IngredienteView.detail:
        return IngredienteDetallePage(
          idIngrediente: _activeId!,
          onBack: () => setState(() => _currentView = IngredienteView.list),
          onEdit: () => setState(() => _currentView = IngredienteView.form),
        );
      case IngredienteView.form:
        return IngredienteFormPage(
          idIngrediente: _activeId,
          onBack: () {
            setState(() => _currentView = IngredienteView.list);
            _fetch();
          },
        );
      default:
        return _buildList();
    }
  }

  Widget _buildList() {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
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
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Catálogo Maestro de Alimentos",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Gestión de base nutricional, grupos alimentarios y composición química.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
            child: NutriResumenCard(
                titulo: "TOTAL ALIMENTOS",
                valor: "$_total",
                icon: Icons.restaurant_menu_rounded)),
        const SizedBox(width: 20),
        Expanded(
            child: NutriResumenCard(
                titulo: "GRUPOS",
                valor: "${_groups.length}",
                colorValor: AppTema.verdeSalud,
                icon: Icons.category_rounded)),
        const SizedBox(width: 20),
        Expanded(
            child: NutriResumenCard(
                titulo: "SUBGRUPOS",
                valor: "${_subgroups.length}",
                colorValor: AppTema.azulOscuro,
                icon: Icons.layers_rounded)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: "Buscar alimento...",
                      hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) {
                      _query = v;
                      _fetch();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => _showForm(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTema.verdeSalud,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  icon: const Icon(Icons.add_circle,
                      size: 20, color: Colors.white),
                  label: Text("NUEVO INGREDIENTE",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text("FILTRAR POR:",
                  style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueGrey,
                      letterSpacing: 1)),
              const SizedBox(width: 16),
              _buildFilterDropdown("GRUPO", _groups, _groupId, _onGroupChanged),
              const SizedBox(width: 12),
              _buildFilterDropdown(
                  "SUBGRUPO",
                  _subgroupsFiltrados,
                  _subgroupId,
                  (v) => setState(() {
                        _subgroupId = v;
                        _fetch();
                      })),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    size: 22, color: AppTema.azulPrincipal),
                onPressed: _fetch,
                tooltip: "Actualizar catálogo",
                style: IconButton.styleFrom(
                  backgroundColor: AppTema.azulPrincipal.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
      String label, List<dynamic> items, int? value, Function(int?) onChanged) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: AppTema.grisLienzo.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          hint: Text(label,
              style: GoogleFonts.montserrat(
                  fontSize: 10, fontWeight: FontWeight.w700)),
          items: [
            DropdownMenuItem(
                value: null,
                child: Text("TODOS LOS ${label}S",
                    style: GoogleFonts.montserrat(
                        fontSize: 10, fontWeight: FontWeight.w700))),
            ...items.map((e) => DropdownMenuItem(
                value: e['id'],
                child: Text(
                    e['nombre']?.toString().toUpperCase() ?? "INGREDIENTE",
                    style: GoogleFonts.montserrat(
                        fontSize: 10, fontWeight: FontWeight.w600)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTableContainer() {
    return NutriTableContainer(
      child: _loading && _items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(100),
              child: NutriLoading(mensaje: "Sincronizando catálogo..."))
          : Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                dividerTheme: const DividerThemeData(
                  thickness: 0,
                  space: 0,
                  color: Colors.transparent,
                ),
                cardTheme: const CardThemeData(
                    elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
              ),
              child: PaginatedDataTable(
                header: null,
                rowsPerPage: 5,
                showFirstLastButtons: true,
                headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
                dividerThickness: 0,
                columns: [
                  _col("Alimento"),
                  _col("Categoría"),
                  _col("Subgrupo"),
                  _col("Kcal/100g"),
                  _col("Acciones"),
                ],
                source: _IngredientesDataSource(
                  items: _items,
                  onView: (id) => _showDetail(id),
                  onEdit: (id) => _showForm(id),
                  context: context,
                ),
              ),
            ),
    );
  }

  DataColumn _col(String l) => DataColumn(
      label: Text(l,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white)));
}

class _IngredientesDataSource extends DataTableSource {
  final List<dynamic> items;
  final Function(int) onView;
  final Function(int) onEdit;
  final BuildContext context;

  _IngredientesDataSource({
    required this.items,
    required this.onView,
    required this.onEdit,
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
    double val =
        (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val == val.toInt().toDouble()) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  @override
  DataRow? getRow(int index) {
    if (index >= items.length) return null;
    final ing = items[index];
    final bool isEven = index % 2 == 0;
    return DataRow(
        color: WidgetStateProperty.all(
            isEven ? Colors.white : const Color(0xFFF1F5F9)),
        cells: [
          DataCell(Text(ing['nombre']?.toString() ?? "Ingrediente",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w700))),
          DataCell(Text(_capitalize(ing['categoria']),
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w500))),
          DataCell(_subgroupBadge(ing['subgrupo'] ?? '-')),
          DataCell(Text("${_fmt(ing['energia_kcal'])} kcal",
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w500))),
          DataCell(Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.visibility_outlined,
                      size: 18, color: AppTema.azulPrincipal),
                  onPressed: () => onView(ing['id'])),
              IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.blueGrey),
                  onPressed: () => onEdit(ing['id'])),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Colors.redAccent),
                onPressed: () => _confirmDelete(ing['id'], ing['nombre']),
              ),
            ],
          )),
        ]);
  }

  Future<void> _confirmDelete(int id, String nombre) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar ingrediente?"),
        content: Text('¿Estás seguro de eliminar "$nombre" del catálogo?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCELAR")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text("ELIMINAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final repo = ProviderScope.containerOf(context)
            .read(inteligenciaRepositoryProvider);
        await repo.eliminarIngrediente(id);
        if (context.mounted) {
          NutriSnack.show(context, "Ingrediente eliminado correctamente");
        }
        onView(-1); // Recargar
      } catch (e) {
        if (context.mounted) {
          NutriSnack.show(context, "Error al eliminar: $e", isError: true);
        }
      }
    }
  }

  Widget _subgroupBadge(String text) {
    if (text == '-')
      return const Text('-', style: TextStyle(color: Colors.grey));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: AppTema.azulOscuro.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(_capitalize(text),
          style: const TextStyle(
              color: AppTema.azulOscuro,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => items.length;
  @override
  int get selectedRowCount => 0;
}
