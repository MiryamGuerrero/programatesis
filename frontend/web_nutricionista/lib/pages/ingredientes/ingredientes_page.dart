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
  int? _selectedSubgroup;
  String? _selectedTag;
  int _offset = 0;
  final int _limit = 10;

  // ESTADO LOCAL PARA NAVEGACIÓN "IN-PLACE"
  int? _viewingIngredientId;
  bool _isEditing = false;

  String _capitalize(String? text) {
    if (text == null || text.isEmpty) return '-';
    String raw = text.trim();
    if (raw.isEmpty) return '-';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  _buildPagination(listAsync.asData?.value['total'] ?? 0),
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
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ingredientes',
                  style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
              Text('Gestiona la base nutricional y reglas de seguridad',
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () { /* TODO: Nuevo Ingrediente */ },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Nuevo Ingrediente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _statCard('Total Ingred.', '156', Icons.bar_chart_rounded, const Color(0xFF6366F1)),
          const SizedBox(width: 16),
          _statCard('Categorías', '12', Icons.restaurant_menu_rounded, const Color(0xFF10B981)),
          const SizedBox(width: 16),
          _statCard('Activos', '142', Icons.check_circle_rounded, const Color(0xFF22C55E)),
          const SizedBox(width: 16),
          _statCard('Inactivos', '14', Icons.cancel_rounded, const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
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
            flex: 2,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 16),
          _dropdownFilter('Categoría', ['Todas', 'Cereales', 'Proteínas', 'Lácteos', 'Frutas', 'Verduras'], (v) {}),
          const SizedBox(width: 12),
          _dropdownFilter('Subgrupo', ['Todos', 'Grupo A', 'Grupo B', 'Grupo C'], (v) {}),
          const SizedBox(width: 12),
          _dropdownFilter('Etiquetas', ['Todas', 'Vegano', 'Sin Gluten', 'Alto Proteína'], (v) {}),
        ],
      ),
    );
  }

  Widget _dropdownFilter(String label, List<String> options, Function(String?) onChanged) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.first,
          isExpanded: true,
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTable(List items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                    dataRowMaxHeight: 64,
                    columnSpacing: 24,
                    horizontalMargin: 20,
                    columns: [
                      _tableHeader('Nombre'),
                      _tableHeader('Categoría'),
                      _tableHeader('Subgrupo'),
                      _tableHeader('Etiquetas'),
                      _tableHeader('Kcal (100g)', true),
                      _tableHeader('Prot', true),
                      _tableHeader('Acciones'),
                    ],
                    rows: items.map<DataRow>((item) {
                      final comp = item['composicion'] ?? {};
                      final tags = (item['tags'] as List? ?? []).map((t) => t['nombre'].toString()).toList();
                      
                      return DataRow(
                        cells: [
                          DataCell(Text(item['nombre'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)))),
                          DataCell(Text(_capitalize(item['categoria_nombre']))),
                          DataCell(_subgroupBadge('Grupo A')), // Mock subgrupo
                          DataCell(_tagsBadges(tags)),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text('${comp['energia_kcal'] ?? 0}'))),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text('${comp['proteinas_g'] ?? 0}g'))),
                          DataCell(_buildActions(item)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  DataColumn _tableHeader(String label, [bool numeric = false]) {
    return DataColumn(
      numeric: numeric,
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
    );
  }

  Widget _subgroupBadge(String label) {
    Color bg = const Color(0xFFDBEAFE);
    Color fg = const Color(0xFF1D4ED8);
    if (label.contains('B')) { bg = const Color(0xFFF3E8FF); fg = const Color(0xFF7E22CE); }
    if (label.contains('C')) { bg = const Color(0xFFFCE7F3); fg = const Color(0xFFBE185D); }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _tagsBadges(List<String> tags) {
    if (tags.isEmpty) return const Text('-', style: TextStyle(color: Colors.grey));
    
    final visible = tags.take(2).toList();
    final remaining = tags.length - 2;

    return Wrap(
      spacing: 4,
      children: [
        ...visible.map((t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
          child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        )),
        if (remaining > 0)
          Tooltip(
            message: tags.skip(2).join(', '),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
              child: Text('+$remaining', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            ),
          ),
      ],
    );
  }

  Widget _buildActions(Map<String, dynamic> item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF2563EB)),
          onPressed: () => setState(() { _viewingIngredientId = item['id_ingrediente']; _isEditing = false; }),
          tooltip: 'Ver detalle',
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF64748B)),
          onPressed: () => setState(() { _viewingIngredientId = item['id_ingrediente']; _isEditing = true; }),
          tooltip: 'Editar',
        ),
        const SizedBox(width: 4),
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildPagination(int total) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Mostrando ${_offset + 1}-${(_offset + _limit) > total ? total : _offset + _limit} de $total ingredientes', 
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          Row(
            children: [
              IconButton(
                onPressed: _offset > 0 ? () => setState(() => _offset -= _limit) : null,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
              ),
              const SizedBox(width: 8),
              Text('Página ${(_offset / _limit).floor() + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: (_offset + _limit) < total ? () => setState(() => _offset += _limit) : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
