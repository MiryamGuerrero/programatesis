import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class ReglasNutricionalesPage extends ConsumerStatefulWidget {
  const ReglasNutricionalesPage({super.key});

  @override
  ConsumerState<ReglasNutricionalesPage> createState() => _ReglasNutricionalesPageState();
}

class _ReglasNutricionalesPageState extends ConsumerState<ReglasNutricionalesPage> {
  bool _loading = true;
  List<dynamic> _rules = [];
  Map<String, List<dynamic>> _formData = {
    "acciones": [],
    "etiquetas": [],
    "condiciones": [],
    "objetivos": []
  };

  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _dio.get("reglas-nutricionales"),
        _dio.get("reglas-nutricionales/form-data"),
      ]);
      setState(() {
        _rules = results[0].data as List;
        _formData = Map<String, List<dynamic>>.from(results[1].data as Map);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al sincronizar motor de reglas", isError: true, ref: ref);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(),
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
                        hintText: "Buscar por nombre de regla...",
                        hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppTema.azulPrincipal),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onChanged: (v) {}, // TODO: Implementar búsqueda local
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  height: 55,
                  child: FilledButton.icon(
                    onPressed: () => _showForm(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTema.verdeSalud,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white),
                    label: Text("NUEVA REGLA", 
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                  ),
                ),
              ],
            ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Motor de Reglas Nutricionales", 
                  style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                Text("Configuración de lógica experta basada en etiquetas y condiciones clínicas.", 
                  style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            IconButton(icon: const Icon(Icons.sync_rounded, color: AppTema.azulPrincipal), onPressed: _loadData),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: NutriResumenCard(titulo: "TOTAL REGLAS", valor: "${_rules.length}", icon: Icons.rule_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "ESTRICTAS", valor: "${_rules.where((r) => r['es_estricta'] == true).length}", colorValor: Colors.redAccent, icon: Icons.gavel_rounded)),
        const SizedBox(width: 20),
        const Expanded(child: NutriResumenCard(titulo: "SISTEMA", valor: "SIA", colorValor: AppTema.azulOscuro, icon: Icons.auto_awesome_rounded)),
      ],
    );
  }

  Widget _buildTableContainer() {
    return NutriTableContainer(
      child: _loading
        ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Consultando base de conocimientos..."))
        : _rules.isEmpty
          ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No se encontraron reglas configuradas.")))
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
                  _col("REGLA / ACCIÓN"),
                  _col("CONDICIONES ACTIVADORAS"),
                  _col("ESTADO"),
                  _col("ACCIONES"),
                ],
                source: _RulesDataSource(
                  rules: _rules,
                  formData: _formData,
                  onEdit: _showForm,
                  onDelete: _deleteRule,
                  context: context,
                ),
              ),
            ),
    );
  }

  DataColumn _col(String l) => DataColumn(
    label: Text(l, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))
  );


  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: const Text("¿Deseas eliminar esta regla del motor heurístico?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text("SÍ, ELIMINAR")),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _dio.delete("reglas-nutricionales/$id");
      _loadData();
      if (mounted) NutriSnack.show(context, "Regla eliminada", ref: ref);
    } catch (_) {
      if (mounted) NutriSnack.show(context, "Error al eliminar", isError: true, ref: ref);
    }
  }

  void _showForm([dynamic rule]) {
    showDialog(
      context: context,
      builder: (ctx) => _RuleFormDialog(
        formData: _formData,
        initialRule: rule as Map<String, dynamic>?,
        onSaved: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }
}

class _RulesDataSource extends DataTableSource {
  final List<dynamic> rules;
  final Map<String, List<dynamic>> formData;
  final Function(dynamic) onEdit;
  final Function(int) onDelete;
  final BuildContext context;

  _RulesDataSource({
    required this.rules,
    required this.formData,
    required this.onEdit,
    required this.onDelete,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= rules.length) return null;
    final r = rules[index] as Map<String, dynamic>;
    final condicionesIds = r["id_condiciones"] as List;
    final nombresCondiciones = condicionesIds.map((id) {
      final c = formData["condiciones"]?.firstWhere((c) => c["id"] == id, orElse: () => null);
      return c != null ? c["nombre"] : "Condición $id";
    }).join(", ");

    return DataRow(cells: [
      DataCell(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${r['etiqueta_nombre']} ➔ ${r['accion_codigo']}", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w700)),
            if (r['mensaje_error'] != null)
              Text(r['mensaje_error'], style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
          ],
        ),
      )),
      DataCell(SizedBox(width: 300, child: Text(nombresCondiciones, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis))),
      DataCell(NutriBadge(label: r['es_estricta'] == true ? "ESTRICTA" : "RECOMENDACIÓN", type: r['es_estricta'] == true ? 'danger' : 'info')),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppTema.azulPrincipal, size: 22),
            onPressed: () => onEdit(r),
            tooltip: "Editar",
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
            onPressed: () => onDelete(r["id"]),
            tooltip: "Eliminar",
          ),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => rules.length;
  @override
  int get selectedRowCount => 0;
}

class _RuleFormDialog extends StatefulWidget {
  final Map<String, List<dynamic>> formData;
  final Map<String, dynamic>? initialRule;
  final VoidCallback onSaved;
  const _RuleFormDialog({required this.formData, this.initialRule, required this.onSaved});
  @override
  State<_RuleFormDialog> createState() => _RuleFormDialogState();
}

class _RuleFormDialogState extends State<_RuleFormDialog> {
  late int? _idEtiqueta;
  late int? _idAccion;
  late TextEditingController _mensajeController;
  late List<int> _selectedCondiciones;
  late bool _esEstricta;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRule;
    _idEtiqueta = r?["id_etiqueta"];
    _idAccion = r?["id_accion"];
    _mensajeController = TextEditingController(text: r?["mensaje_error"]);
    _selectedCondiciones = List<int>.from(r?["id_condiciones"] ?? []);
    _esEstricta = r?["es_estricta"] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.initialRule != null ? "Editar Regla Experta" : "Nueva Regla Experta", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _idEtiqueta,
                decoration: const InputDecoration(labelText: "Etiqueta", filled: true),
                items: widget.formData["etiquetas"]?.map((e) => DropdownMenuItem<int>(value: e["id"], child: Text(e["nombre"]))).toList(),
                onChanged: (v) => setState(() => _idEtiqueta = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _idAccion,
                decoration: const InputDecoration(labelText: "Acción", filled: true),
                items: widget.formData["acciones"]?.map((a) => DropdownMenuItem<int>(value: a["id"], child: Text(a["nombre"]))).toList(),
                onChanged: (v) => setState(() => _idAccion = v),
              ),
              const SizedBox(height: 20),
              Container(
                height: 180,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: ListView(
                  children: widget.formData["condiciones"]!.map((c) => CheckboxListTile(
                    title: Text(c["nombre"], style: const TextStyle(fontSize: 13)),
                    value: _selectedCondiciones.contains(c["id"]),
                    onChanged: (v) => setState(() => v == true ? _selectedCondiciones.add(c["id"]) : _selectedCondiciones.remove(c["id"])),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _mensajeController, decoration: const InputDecoration(labelText: "Mensaje Guía", filled: true)),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text("¿Regla Estricta?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                value: _esEstricta,
                onChanged: (v) => setState(() => _esEstricta = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
        ElevatedButton(onPressed: () => _save(ref), style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white), child: const Text("GUARDAR REGLA")),
      ],
    ));
  }

  Future<void> _save(WidgetRef ref) async {
    if (_idEtiqueta == null || _idAccion == null || _selectedCondiciones.isEmpty) return;
    setState(() => _saving = true);
    try {
      final payload = { "id_etiqueta": _idEtiqueta, "id_accion": _idAccion, "id_tipo_objetivo": 3, "mensaje_error": _mensajeController.text, "id_condiciones": _selectedCondiciones, "es_estricta": _esEstricta };
      if (widget.initialRule != null) await ref.read(dioProvider).put("reglas-nutricionales/${widget.initialRule!['id']}", data: payload);
      else await ref.read(dioProvider).post("reglas-nutricionales", data: payload);
      widget.onSaved();
    } catch (_) {}
  }
}
