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
  final int _limit = 5;

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
    return val.toStringAsFixed(3).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
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
    if (_loading && _items.isEmpty) {
      return Scaffold(backgroundColor: Colors.white, body: _buildFullScreenFruitLoader());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(
            flex: _selectedId != null ? 3 : 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMinimalHeader(),
                _buildMicroStats(),
                _buildFilterBar(),
                Expanded(
                  child: Stack(
                    children: [
                      _buildMainTable(),
                      if (_loading) 
                        Container(color: Colors.white.withOpacity(0.6), child: _buildFullScreenFruitLoader()),
                    ],
                  ),
                ),
                _buildPagination(),
              ],
            ),
          ),
          if (_selectedId != null)
            Expanded(
              flex: 2,
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: Color(0xFFF1F5F9)))),
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

  Widget _buildMinimalHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Catálogo Maestro', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          ElevatedButton.icon(
            onPressed: () => setState(() { _selectedId = 0; _isEditing = true; }),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nuevo', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Wrap(
        spacing: 20,
        children: [
          _microStat("Total", "$_total", Colors.blue),
          _microStat("Grupos", "${_groups.length}", Colors.teal),
          _microStat("Activos", "$_total", Colors.green),
        ],
      ),
    );
  }

  Widget _microStat(String l, String v, Color c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text("$l: ", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c)),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar alimento...', hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  contentPadding: EdgeInsets.zero, fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  filled: true,
                ),
                onChanged: (v) { _query = v; _fetch(); },
              ),
            ),
          ),
          const SizedBox(width: 24),
          _label("Categoría:"),
          _drop(_groups, _groupId, (v) => setState(() { _groupId = v; _fetch(); })),
          const SizedBox(width: 16),
          _label("Subgrupo:"),
          _drop(_subgroups, _subgroupId, (v) => setState(() { _subgroupId = v; })),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)));

  Widget _drop(List<dynamic> items, int? val, Function(int?) onC) {
    return Container(
      width: 150, height: 34,
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: val, isExpanded: true, style: const TextStyle(fontSize: 11, color: Colors.black),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
            ...items.map((e) => DropdownMenuItem<int?>(value: e['id'], child: Text(_capitalize(e['nombre'])))),
          ],
          onChanged: onC,
        ),
      ),
    );
  }

  Widget _buildFullScreenFruitLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("🥗", style: TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AnimatedFruit(fruit: "🍎", delay: 0),
              _AnimatedFruit(fruit: "🥦", delay: 150),
              _AnimatedFruit(fruit: "🥕", delay: 300),
              _AnimatedFruit(fruit: "🥑", delay: 450),
            ],
          ),
          const SizedBox(height: 16),
          Text("CARGANDO CATÁLOGO", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildMainTable() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFF1F5F9)), borderRadius: BorderRadius.circular(8)),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(const Color(0xFFF9FAFB)),
        headingRowHeight: 45,
        dataRowHeight: 52,
        columnSpacing: 10,
        columns: [
          _h('NOMBRE', false), 
          _h('CATEGORÍA', false), 
          _h('SUBGRUPO', false), 
          _h('ETIQUETAS', false), 
          _h('ENERGIA (KCAL)', true), 
          _h('PROTEINAS (G)', true), 
          _h('ACCIONES', true),
        ],
        rows: [
          ..._items.map((ing) {
            final List<dynamic> tags = ing['etiquetas'] ?? [];
            return DataRow(
              cells: [
                DataCell(SizedBox(width: 140, child: Text(ing['nombre'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 12)))),
                DataCell(Text(_capitalize(ing['categoria']), style: const TextStyle(fontSize: 11))),
                DataCell(_subgroupBadge(ing['subgrupo'] ?? '-')),
                DataCell(_tagsCell(tags)),
                DataCell(Center(child: Text('${_fmt(ing['energia_kcal'])} kcal', style: const TextStyle(fontSize: 11)))),
                DataCell(Center(child: Text('${_fmt(ing['proteinas_g'])} g', style: const TextStyle(fontSize: 11)))),
                DataCell(Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.visibility, size: 14, color: Colors.blue), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() { _selectedId = ing['id']; _isEditing = false; })),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.edit, size: 14, color: Colors.grey), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() { _selectedId = ing['id']; _isEditing = true; })),
                ]))),
              ],
            );
          }),
          if (_items.length < _limit)
            ...List.generate(_limit - _items.length, (_) => const DataRow(cells: [
              DataCell(SizedBox.shrink()), DataCell(SizedBox.shrink()), DataCell(SizedBox.shrink()),
              DataCell(SizedBox.shrink()), DataCell(SizedBox.shrink()), DataCell(SizedBox.shrink()),
              DataCell(SizedBox.shrink()),
            ])),
        ],
      ),
    );
  }

  DataColumn _h(String l, bool center) => DataColumn(
    label: Expanded(
      child: Text(
        l, 
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8))
      )
    )
  );

  Widget _subgroupBadge(String text) {
    if (text == '-') return const Text('-', style: TextStyle(color: Colors.grey));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(_capitalize(text), style: const TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _tagsCell(List<dynamic> tags) {
    if (tags.isEmpty) return const Text('-', style: TextStyle(color: Colors.grey, fontSize: 11));
    final visible = tags.take(1).toList();
    final remaining = tags.length - 1;
    return Wrap(
      spacing: 4,
      children: [
        ...visible.map((t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
          child: Text(t.toString(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        )),
        if (remaining > 0)
          Tooltip(
            message: tags.skip(1).join(', '),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
              child: Text('+$remaining', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue.shade700)),
            ),
          ),
      ],
    );
  }

  Widget _buildPagination() {
    int totalP = (_total / _limit).ceil();
    if (totalP == 0) totalP = 1;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$_total registros', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left, size: 18), onPressed: _page > 0 ? () { setState(() => _page--); _fetch(); } : null),
              Text('PÁG ${_page + 1} / $totalP', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
              IconButton(icon: const Icon(Icons.chevron_right, size: 18), onPressed: (_page + 1) < totalP ? () { setState(() => _page++); _fetch(); } : null),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedFruit extends StatefulWidget {
  final String fruit;
  final int delay;
  const _AnimatedFruit({required this.fruit, required this.delay});
  @override
  State<_AnimatedFruit> createState() => _AnimatedFruitState();
}

class _AnimatedFruitState extends State<_AnimatedFruit> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _animation = Tween<double>(begin: 0, end: -15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _controller.repeat(reverse: true); });
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _animation, builder: (context, child) => Transform.translate(offset: Offset(0, _animation.value), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text(widget.fruit, style: const TextStyle(fontSize: 24)))));
  }
}
