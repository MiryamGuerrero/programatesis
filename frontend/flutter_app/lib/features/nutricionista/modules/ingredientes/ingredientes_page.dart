import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
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
  final int _limit = 10; // Reducido a 10 para evitar scroll vertical

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
      
      if (mounted) {
        setState(() {
          _groups = g;
          _subgroups = sg;
        });
      }
    } catch (e) {
      debugPrint('Error cargando filtros: $e');
    }
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          Expanded(
            flex: _selectedId != null ? 3 : 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildToolbar(),
                  const SizedBox(height: 24),
                  if (_loading) const LinearProgressIndicator(color: Colors.blue, minHeight: 1),
                  _buildMainTable(),
                  const Spacer(),
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
                  border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: _isEditing
                    ? IngredienteFormPage(
                        idIngrediente: _selectedId == 0 ? null : _selectedId,
                        onBack: () { setState(() => _isEditing = false); _fetch(); },
                      )
                    : IngredienteDetallePage(
                        idIngrediente: _selectedId!,
                        onBack: () => setState(() => _selectedId = null),
                        onEdit: () => setState(() => _isEditing = true),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 32, left: 16, right: 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catálogo Maestro', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
              Text('Gestión centralizada de ingredientes y composición', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => setState(() { _selectedId = 0; _isEditing = true; }),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Nuevo Ingrediente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Búsqueda más ancha
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 48,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
                ),
                onChanged: (v) { _query = v; _fetch(); },
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Dropdown Grupo
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: DropdownButtonFormField<int?>(
                value: _groupId,
                decoration: _inputDecoration('Grupo'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los grupos', style: TextStyle(fontSize: 13))),
                  ..._groups.map((g) => DropdownMenuItem(value: g['id'], child: Text(g['nombre'], style: const TextStyle(fontSize: 13)))),
                ],
                onChanged: (v) { setState(() => _groupId = v); _fetch(); },
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Dropdown Subgrupo
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: DropdownButtonFormField<int?>(
                value: _subgroupId,
                decoration: _inputDecoration('Subgrupo'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los subgrupos', style: TextStyle(fontSize: 13))),
                  ..._subgroups.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['nombre'], style: const TextStyle(fontSize: 13)))),
                ],
                onChanged: (v) { setState(() => _subgroupId = v); },
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildMainTable() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.6),
            child: DataTable(
              headingRowHeight: 52,
              dataRowMaxHeight: 58,
              columnSpacing: 32,
              headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              columns: const [
                DataColumn(label: Text('INGREDIENTE')),
                DataColumn(label: Text('CATEGORÍA')),
                DataColumn(label: Text('ENERGÍA')),
                DataColumn(label: Text('CARBOS')),
                DataColumn(label: Text('ETIQUETAS')),
                DataColumn(label: Text('ACCIONES')),
              ],
              rows: _items.map((ing) {
                final List<dynamic> allEtiqs = ing['etiquetas'] ?? [];
                final etiqs = allEtiqs.length > 3 ? allEtiqs.sublist(0, 3) : allEtiqs;
                
                return DataRow(
                  cells: [
                    DataCell(Text(ing['nombre'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                    DataCell(Text(ing['categoria'] ?? '-', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                    DataCell(Text('${ing['energia_kcal'].toStringAsFixed(0)} kcal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(Text('${ing['carbohidratos_g'].toStringAsFixed(1)} g', style: const TextStyle(fontSize: 12))),
                    DataCell(Wrap(
                      spacing: 6,
                      children: etiqs.map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.withOpacity(0.1))),
                        child: Text(e.toString(), style: const TextStyle(fontSize: 9, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold)),
                      )).toList(),
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blue), onPressed: () => setState(() { _selectedId = ing['id']; _isEditing = false; }), tooltip: 'Ver'),
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.orange), onPressed: () => setState(() { _selectedId = ing['id']; _isEditing = true; }), tooltip: 'Editar'),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    int totalP = (_total / _limit).ceil();
    if (totalP == 0) totalP = 1;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total: $_total ingredientes', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          Row(
            children: [
              Text('Página ${_page + 1} de $totalP', style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _page > 0 ? () { setState(() => _page--); _fetch(); } : null,
                child: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: (_page + 1) < totalP ? () { setState(() => _page++); _fetch(); } : null,
                child: const Icon(Icons.chevron_right),
              ),
            ],
          )
        ],
      ),
    );
  }
}
