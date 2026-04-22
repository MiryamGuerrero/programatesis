import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/nutricionista_providers.dart';
import 'ingrediente_detalle_page.dart';
import 'ingrediente_form_page.dart';

class IngredientesPage extends ConsumerStatefulWidget {
  const IngredientesPage({super.key});
  @override
  ConsumerState<IngredientesPage> createState() => _IngredientesPageState();
}

class _IngredientesPageState extends ConsumerState<IngredientesPage> {
  String _searchQuery = '';
  int? _selectedCategory;
  int _offset = 0;
  final int _limit = 15;

  // ESTADO LOCAL PARA NAVEGACIÓN "IN-PLACE"
  int? _viewingIngredientId;
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(ingredientesListaProvider(
      query: _searchQuery,
      categoryId: _selectedCategory,
      limit: _limit,
      offset: _offset,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // LADO IZQUIERDO: LISTADO Y FILTROS
          Expanded(
            flex: _viewingIngredientId != null ? 3 : 5,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStats(),
                  _buildFilters(),
                  Expanded(
                    child: listAsync.when(
                      data: (data) => _buildTable(data['items'] ?? []),
                      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E))),
                      error: (e, __) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                    ),
                  ),
                  _buildPagination(),
                ],
              ),
            ),
          ),

          // LADO DERECHO: DETALLE O FORMULARIO (IN-PLACE)
          if (_viewingIngredientId != null)
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.white,
                child: _isEditing
                    ? IngredienteFormPage(
                        id: _viewingIngredientId!,
                        onClose: () => setState(() { _isEditing = false; }),
                        onSaved: () {
                          setState(() { _isEditing = false; });
                          ref.invalidate(ingredientesListaProvider);
                        },
                      )
                    : IngredienteDetallePage(
                        id: _viewingIngredientId!,
                        onClose: () => setState(() { _viewingIngredientId = null; }),
                        onEdit: () => setState(() { _isEditing = true; }),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: MainAxisAlignment.start,
            children: [
              Text('Catálogo de Ingredientes',
                  style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              Text('Gestiona la base nutricional del sistema',
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () { /* TODO: Nuevo Ingrediente */ },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo Ingrediente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _statCard('Total', '842', Icons.inventory_2, Colors.blue),
          const SizedBox(width: 16),
          _statCard('Activos', '790', Icons.check_circle, Colors.green),
          const SizedBox(width: 16),
          _statCard('Críticos', '12', Icons.warning, Colors.orange),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 16),
          _categoryFilter(1, 'Cereales'),
          const SizedBox(width: 8),
          _categoryFilter(4, 'Frutas'),
          const SizedBox(width: 8),
          _categoryFilter(7, 'Carnes'),
        ],
      ),
    );
  }

  Widget _categoryFilter(int id, String label) {
    bool isSelected = _selectedCategory == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedCategory = val ? id : null),
      selectedColor: const Color(0xFF22C55E).withOpacity(0.2),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF15803D) : const Color(0xFF64748B)),
    );
  }

  Widget _buildTable(List items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
            dataRowMaxHeight: 60,
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Categoría')),
              DataColumn(label: Text('Energía (100g)')),
              DataColumn(label: Text('Proteína')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: items.map<DataRow>((item) {
              final comp = item['composicion'] ?? {};
              return DataRow(
                onSelectChanged: (_) => setState(() { _viewingIngredientId = item['id_ingrediente']; _isEditing = false; }),
                cells: [
                  DataCell(Text(item['nombre'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(item['categoria_nombre'] ?? '-')),
                  DataCell(Text('${comp['energia_kcal'] ?? 0} kcal')),
                  DataCell(Text('${comp['proteinas_g'] ?? 0} g')),
                  DataCell(IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {})),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Página ${(_offset / _limit).floor() + 1}', style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _offset > 0 ? () => setState(() => _offset -= _limit) : null,
            icon: const Icon(Icons.arrow_back_ios, size: 16),
          ),
          IconButton(
            onPressed: () => setState(() => _offset += _limit),
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ],
      ),
    );
  }
}
