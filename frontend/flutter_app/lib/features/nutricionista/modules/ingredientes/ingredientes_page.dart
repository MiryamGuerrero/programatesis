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
  List<dynamic> _categories = [];
  int _total = 0;
  bool _loading = true;
  String _query = '';
  int? _category;
  int _page = 0;
  final int _limit = 15;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadCategories();
      _fetch();
    });
  }

  Future<void> _loadCategories() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final cats = await repo.fetchCatalog('nutricion', 'grupo_alimentario');
      if (mounted) {
        setState(() {
          _categories = cats;
        });
      }
    } catch (e) {
      debugPrint('Error cargando categorias: $e');
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final data = await repo.ingredientesLista(
          q: _query, cat: _category, limit: _limit, offset: _page * _limit);
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

  Future<void> _deleteIngredient(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Ingrediente'),
        content: const Text('¿Estás seguro de que deseas eliminar este ingrediente? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final repo = ref.read(supabaseCrudRepositoryProvider);
        await repo.deleteIngrediente(id);
        _fetch();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildKPIs(),
                _buildToolbar(),
                if (_loading)
                  const LinearProgressIndicator(
                      color: Color(0xFF22C55E), minHeight: 2),
                Expanded(child: _buildMainTable()),
                _buildPagination(),
              ],
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
                        onBack: () {
                          setState(() {
                            _isEditing = false;
                          });
                          _fetch();
                        },
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catálogo Maestro',
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A))),
              Text('Base de datos nutricional centralizada',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF64748B))),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => setState(() {
              _selectedId = 0;
              _isEditing = true;
            }),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Añadir Ingrediente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _kpiCard('Total', '$_total', Icons.inventory_2_outlined, Colors.blue),
          const SizedBox(width: 12),
          _kpiCard('Activos', '${(_total * 0.9).floor()}',
              Icons.check_circle_outline, Colors.green),
          const SizedBox(width: 12),
          _kpiCard('Categorías', '${_categories.length}', Icons.category_outlined,
              Colors.purple),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF64748B))),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filtrar por nombre...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
              onChanged: (v) {
                _query = v;
                _fetch();
              },
            ),
          ),
          const SizedBox(width: 12),
          const Text('Filtrar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('Todos', null),
                  ..._categories.map((c) => _chip(c['nombre'], c['id'])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int? id) {
    bool sel = _category == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: sel ? Colors.white : const Color(0xFF64748B))),
        selected: sel,
        onSelected: (v) {
          setState(() => _category = v ? id : null);
          _fetch();
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildMainTable() {
    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                horizontalMargin: 20,
                showCheckboxColumn: false,
                headingRowHeight: 56,
                dataRowMaxHeight: 70,
                columnSpacing: 24,
                headingTextStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
                ),
                columns: const [
                  DataColumn(label: Text('INGREDIENTE')),
                  DataColumn(label: Text('CATEGORÍA')),
                  DataColumn(label: Text('ENERGÍA')),
                  DataColumn(label: Text('CARBOHIDRATOS')),
                  DataColumn(label: Text('ETIQUETAS')),
                  DataColumn(label: Text('ACCIONES')),
                ],
                rows: _items.map((ing) {
                  final List<dynamic> etiqs = ing['etiquetas'] ?? [];
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            ing['nombre'],
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(ing['categoria'] ?? '-',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)))),
                      DataCell(_badge('${ing['energia_kcal']} kcal', Colors.orange)),
                      DataCell(_badge('${ing['carbohidratos_g']} g', Colors.blue)),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: etiqs.map((e) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                              ),
                              child: Text(e.toString(), style: const TextStyle(fontSize: 9, color: Colors.teal, fontWeight: FontWeight.bold)),
                            )).toList(),
                          ),
                        ),
                      ),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blue),
                            onPressed: () => setState(() { _selectedId = ing['id']; _isEditing = false; }),
                            tooltip: 'Ver detalle',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.orange),
                            onPressed: () => setState(() { _selectedId = ing['id']; _isEditing = true; }),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            onPressed: () => _deleteIngredient(ing['id']),
                            tooltip: 'Eliminar',
                          ),
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
    });
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.8)),
      ),
    );
  }

  Widget _buildPagination() {
    int totalP = (_total / _limit).ceil();
    if (totalP == 0) totalP = 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Página ${_page + 1} de $totalP',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(width: 16),
          IconButton(
              onPressed: _page > 0
                  ? () {
                      setState(() => _page--);
                      _fetch();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left, size: 18)),
          IconButton(
              onPressed: (_page + 1) < totalP
                  ? () {
                      setState(() => _page++);
                      _fetch();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right, size: 18)),
        ],
      ),
    );
  }
}
