import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class CatalogoCondicionesPage extends ConsumerStatefulWidget {
  const CatalogoCondicionesPage({super.key});

  @override
  ConsumerState<CatalogoCondicionesPage> createState() => _CatalogoCondicionesPageState();
}

class _CatalogoCondicionesPageState extends ConsumerState<CatalogoCondicionesPage> {
  bool _loading = true;
  List<dynamic> _condiciones = [];
  List<dynamic> _tipos = [];
  String _searchQuery = "";
  final Set<int> _selectedTipos = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await Future.wait([
        dio.get("catalogos/condiciones"),
        dio.get("catalogos/tipos-condicion"),
      ]);
      if (mounted) {
        setState(() {
          final allowedTypeIds = [1, 2];
          _tipos = (res[1].data as List).where((t) => allowedTypeIds.contains(t["id"])).toList();
          _condiciones = (res[0].data as List).where((c) => allowedTypeIds.contains(c["id_tipo_condicion"])).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<dynamic> get _filtradas {
    return _condiciones.where((c) {
      final matchesSearch = c["nombre"].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTipo = _selectedTipos.isEmpty || _selectedTipos.contains(c["id_tipo_condicion"]);
      return matchesSearch && matchesTipo;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildToolbar(),
                const SizedBox(height: 24),
                _buildChipsFilters(),
                const SizedBox(height: 24),
                _buildTable(),
              ],
            ),
          ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Catálogo de Condiciones", 
          style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text("Administración de patologías y estados clínicos pediátricos.", 
          style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
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
                hintText: "Buscar por nombre de patología...",
                hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTema.azulPrincipal),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          height: 55,
          child: FilledButton.icon(
            onPressed: () => _abrirFormulario(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTema.verdeSalud,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white),
            label: Text("NUEVA CONDICIÓN", 
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildChipsFilters() {
    return Row(
      children: [
        Text("FILTRAR POR:", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
        const SizedBox(width: 16),
        _filterChip("TODAS", _selectedTipos.isEmpty, () => setState(() => _selectedTipos.clear())),
        const SizedBox(width: 12),
        ..._tipos.map((t) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _filterChip(
            t["nombre"].toString().toUpperCase(), 
            _selectedTipos.contains(t["id"]),
            () => setState(() => _selectedTipos.contains(t["id"]) ? _selectedTipos.remove(t["id"]) : _selectedTipos.add(t["id"] as int))
          ),
        )),
      ],
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTema.azulPrincipal : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTema.azulPrincipal : Colors.grey.shade300),
        ),
        child: Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildTable() {
    return NutriTableContainer(
      child: Theme(
        data: Theme.of(context).copyWith(
          cardTheme: const CardThemeData(elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
        ),
        child: PaginatedDataTable(
          header: null,
          rowsPerPage: 5,
          showFirstLastButtons: true,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
          columns: [
            _col("NOMBRE"),
            _col("CLASIFICACIÓN"),
            _col("ESTADO"),
            _col("ACCIONES"),
          ],
          source: _CondicionesDataSource(
            condiciones: _filtradas,
            tipos: _tipos,
            onEdit: _abrirFormulario,
            onDelete: _eliminar,
            context: context,
          ),
        ),
      ),
    );
  }

  DataColumn _col(String l) => DataColumn(
    label: Text(l, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))
  );

  void _abrirFormulario({Map<String, dynamic>? condicion}) {
    showDialog(context: context, builder: (context) => _FormularioCondicion(condicion: condicion, tipos: _tipos, onSuccess: _fetchData));
  }

  Future<void> _eliminar(Map<String, dynamic> c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Eliminar registro?", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text("Desea eliminar '${c["nombre"]}' del catálogo.", style: GoogleFonts.montserrat(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(context, true), child: const Text("ELIMINAR")),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete("catalogos/condiciones/${c["id"]}");
        _fetchData();
      } catch (e) {}
    }
  }
}

class _CondicionesDataSource extends DataTableSource {
  final List<dynamic> condiciones;
  final List<dynamic> tipos;
  final Function({Map<String, dynamic>? condicion}) onEdit;
  final Function(Map<String, dynamic>) onDelete;
  final BuildContext context;

  _CondicionesDataSource({
    required this.condiciones,
    required this.tipos,
    required this.onEdit,
    required this.onDelete,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= condiciones.length) return null;
    final c = condiciones[index];
    final tipo = tipos.firstWhere((t) => t["id"] == c["id_tipo_condicion"], orElse: () => {"nombre": "Médica"});
    
    return DataRow(cells: [
      DataCell(Text(c["nombre"], style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w700))),
      DataCell(_tipoBadge(tipo["nombre"].toString().toUpperCase(), c["id_tipo_condicion"] == 1)),
      DataCell(_statusIcon(c["activa"] == true)),
      DataCell(Row(
        children: [
          IconButton(tooltip: "Editar", icon: const Icon(Icons.edit_rounded, color: Colors.orange, size: 20), onPressed: () => onEdit(condicion: c)),
          IconButton(tooltip: "Eliminar", icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => onDelete(c)),
        ],
      )),
    ]);
  }

  Widget _tipoBadge(String label, bool isCronica) {
    final bg = isCronica ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7);
    final tx = isCronica ? const Color(0xFF0369A1) : const Color(0xFF92400E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: tx)),
    );
  }

  Widget _statusIcon(bool active) {
    return Icon(
      active ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
      color: active ? const Color(0xFF10B981) : Colors.grey.shade400,
      size: 20,
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => condiciones.length;
  @override
  int get selectedRowCount => 0;
}

class _FormularioCondicion extends ConsumerStatefulWidget {
  final Map<String, dynamic>? condicion;
  final List<dynamic> tipos;
  final VoidCallback onSuccess;
  const _FormularioCondicion({this.condicion, required this.tipos, required this.onSuccess});
  @override
  ConsumerState<_FormularioCondicion> createState() => _FormularioCondicionState();
}

class _FormularioCondicionState extends ConsumerState<_FormularioCondicion> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int? _idTipo;
  bool _activa = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.condicion != null) {
      _nombreCtrl.text = widget.condicion!["nombre"];
      _descCtrl.text = widget.condicion!["descripcion"] ?? "";
      _idTipo = widget.condicion!["id_tipo_condicion"];
      _activa = widget.condicion!["activa"] ?? true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.condicion != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
        child: Row(children: [
          const Icon(Icons.medical_services_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Text(isEdit ? "EDITAR CONDICIÓN" : "NUEVA CONDICIÓN", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _modalField(_nombreCtrl, "Nombre de la Condición*", Icons.title),
            const SizedBox(height: 16),
            _modalField(_descCtrl, "Descripción", Icons.description, maxLines: 2),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _idTipo,
              decoration: _modalInputDecor("Tipo de Condición*", Icons.category),
              items: widget.tipos.map((t) => DropdownMenuItem<int>(value: t["id"], child: Text(t["nombre"].toString().toUpperCase(), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
              onChanged: (v) => setState(() => _idTipo = v),
            ),
            const SizedBox(height: 12),
            SwitchListTile(title: Text("Estado Activo", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600)), value: _activa, onChanged: (v) => setState(() => _activa = v)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey))),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? "..." : "GUARDAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _modalField(TextEditingController c, String l, IconData i, {int maxLines = 1}) => TextFormField(controller: c, maxLines: maxLines, style: GoogleFonts.montserrat(fontSize: 14), decoration: _modalInputDecor(l, i));

  InputDecoration _modalInputDecor(String l, IconData i) => InputDecoration(labelText: l, prefixIcon: Icon(i, size: 18), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));

  Future<void> _save() async {
    if (_nombreCtrl.text.isEmpty || _idTipo == null) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {"nombre": _nombreCtrl.text, "descripcion": _descCtrl.text, "id_tipo_condicion": _idTipo, "activa": _activa};
      if (widget.condicion != null) {
        await dio.put("catalogos/condiciones/${widget.condicion!["id"]}", data: payload);
      } else {
        await dio.post("catalogos/condiciones", data: payload);
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } finally { if (mounted) setState(() => _saving = false); }
  }
}
