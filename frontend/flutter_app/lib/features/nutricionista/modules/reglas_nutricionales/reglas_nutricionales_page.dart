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
            NutriTableToolbar(
              actionLabel: "Nueva Regla",
              onAction: () => _showForm(),
              onSearch: (v) {}, // TODO: Implementar búsqueda local
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
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                Text("Configuración de lógica experta basada en etiquetas y condiciones clínicas.", 
                  style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 13)),
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
        const Expanded(child: NutriResumenCard(titulo: "SISTEMA", valor: "SIA", colorValor: AppTema.cianLimpio, icon: Icons.auto_awesome_rounded)),
      ],
    );
  }

  Widget _buildTableContainer() {
    return NutriTableContainer(
      child: _loading
        ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Consultando base de conocimientos..."))
        : _rules.isEmpty
          ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No se encontraron reglas configuradas.")))
          : DataTable(
              headingRowColor: WidgetStateProperty.all(AppTema.pastelCeleste),
              columns: [
                _col("REGLA / ACCIÓN"),
                _col("CONDICIONES ACTIVADORAS"),
                _col("ESTADO"),
                _col("ACCIONES"),
              ],
              rows: _rules.map((r) {
                final condicionesIds = r["id_condiciones"] as List;
                final nombresCondiciones = condicionesIds.map((id) {
                  final c = _formData["condiciones"]?.firstWhere((c) => c["id"] == id, orElse: () => null);
                  return c != null ? c["nombre"] : "Condición $id";
                }).join(", ");

                return DataRow(cells: [
                  DataCell(Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${r['etiqueta_nombre']} ➔ ${r['accion_codigo']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTema.azulPrincipal)),
                      if (r['mensaje_error'] != null)
                        Text(r['mensaje_error'], style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                    ],
                  )),
                  DataCell(SizedBox(width: 300, child: Text(nombresCondiciones, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                  DataCell(NutriBadge(label: r['es_estricta'] == true ? "ESTRICTA" : "RECOMENDACIÓN", type: r['es_estricta'] == true ? 'danger' : 'info')),
                  DataCell(Row(
                    children: [
                      IconButton(icon: const Icon(Icons.edit_note_rounded, color: AppTema.azulPrincipal, size: 20), onPressed: () => _showForm(r)),
                      IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _deleteRule(r["id"])),
                    ],
                  )),
                ]);
              }).toList(),
            ),
    );
  }

  DataColumn _col(String l) => DataColumn(label: Text(l, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal)));

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

  void _showForm([Map<String, dynamic>? rule]) {
    showDialog(
      context: context,
      builder: (ctx) => _RuleFormDialog(
        formData: _formData,
        initialRule: rule,
        onSaved: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }
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
      title: Text(widget.initialRule != null ? "Editar Regla Experta" : "Nueva Regla Experta", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
