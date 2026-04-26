import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class CondicionesNutricionalesPage extends ConsumerStatefulWidget {
  const CondicionesNutricionalesPage({super.key});

  @override
  ConsumerState<CondicionesNutricionalesPage> createState() => _CondicionesNutricionalesPageState();
}

class _CondicionesNutricionalesPageState extends ConsumerState<CondicionesNutricionalesPage> {
  bool _loading = true;
  List<dynamic> _conditions = [];

  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final response = await _dio.get("condiciones-nutricionales");
      setState(() {
        _conditions = response.data as List;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al cargar catálogo de condiciones", isError: true, ref: ref);
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
              actionLabel: "Nueva Condición",
              onAction: () => _showForm(),
              onSearch: (v) {},
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
                Text("Catálogo de Condiciones Nutricionales", 
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                Text("Administración de estados clínicos y diagnósticos nutricionales del sistema.", 
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
        Expanded(child: NutriResumenCard(titulo: "TOTAL CONDICIONES", valor: "${_conditions.length}", icon: Icons.assignment_turned_in_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "ACTIVAS", valor: "${_conditions.where((c) => c['activa'] == true).length}", colorValor: AppTema.verdeSalud, icon: Icons.check_circle_rounded)),
        const SizedBox(width: 20),
        const Expanded(child: NutriResumenCard(titulo: "ESTADO", valor: "OPERATIVO", colorValor: AppTema.cianLimpio, icon: Icons.verified_user_rounded)),
      ],
    );
  }

  Widget _buildTableContainer() {
    return NutriTableContainer(
      child: _loading
        ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Sincronizando diagnósticos..."))
        : _conditions.isEmpty
          ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No hay condiciones registradas.")))
          : DataTable(
              headingRowColor: WidgetStateProperty.all(AppTema.pastelCeleste),
              columns: [
                _col("NOMBRE DE CONDICIÓN"),
                _col("DESCRIPCIÓN"),
                _col("ESTADO"),
                _col("ACCIONES"),
              ],
              rows: _conditions.map((c) => DataRow(cells: [
                DataCell(Text(c['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTema.azulPrincipal))),
                DataCell(SizedBox(width: 400, child: Text(c['descripcion'] ?? 'Sin descripción', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                DataCell(NutriBadge(label: c['activa'] == true ? "ACTIVA" : "INACTIVA", type: c['activa'] == true ? 'success' : 'danger')),
                DataCell(Row(
                  children: [
                    IconButton(icon: const Icon(Icons.edit_note_rounded, color: AppTema.azulPrincipal, size: 20), onPressed: () => _showForm(c)),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _deleteCondition(c["id"])),
                  ],
                )),
              ])).toList(),
            ),
    );
  }

  DataColumn _col(String l) => DataColumn(label: Text(l, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal)));

  Future<void> _deleteCondition(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar desactivación"),
        content: const Text("¿Deseas eliminar/desactivar esta condición del catálogo maestro?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text("SÍ, ELIMINAR")),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _dio.delete("condiciones-nutricionales/$id");
      _loadData();
      if (mounted) NutriSnack.show(context, "Condición actualizada", ref: ref);
    } catch (_) {
      if (mounted) NutriSnack.show(context, "Error en la operación", isError: true, ref: ref);
    }
  }

  void _showForm([Map<String, dynamic>? condition]) {
    showDialog(
      context: context,
      builder: (ctx) => _ConditionFormDialog(
        initialCondition: condition,
        onSaved: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }
}

class _ConditionFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialCondition;
  final VoidCallback onSaved;
  const _ConditionFormDialog({this.initialCondition, required this.onSaved});
  @override
  State<_ConditionFormDialog> createState() => _ConditionFormDialogState();
}

class _ConditionFormDialogState extends State<_ConditionFormDialog> {
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  late bool _activa;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.initialCondition?["nombre"]);
    _descripcionController = TextEditingController(text: widget.initialCondition?["descripcion"]);
    _activa = widget.initialCondition?["activa"] ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.initialCondition != null ? "Editar Diagnóstico" : "Nuevo Diagnóstico", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nombreController, decoration: const InputDecoration(labelText: "Nombre de la Condición", filled: true)),
          const SizedBox(height: 12),
          TextField(controller: _descripcionController, decoration: const InputDecoration(labelText: "Descripción Detallada", filled: true), maxLines: 3),
          const SizedBox(height: 12),
          SwitchListTile(title: const Text("Condición Activa"), value: _activa, onChanged: (v) => setState(() => _activa = v)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
        ElevatedButton(onPressed: () => _save(ref), style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white), child: const Text("GUARDAR")),
      ],
    ));
  }

  Future<void> _save(WidgetRef ref) async {
    if (_nombreController.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final payload = { "nombre": _nombreController.text, "descripcion": _descripcionController.text, "activa": _activa };
      if (widget.initialCondition != null) await ref.read(dioProvider).put("condiciones-nutricionales/${widget.initialCondition!['id']}", data: payload);
      else await ref.read(dioProvider).post("condiciones-nutricionales", data: payload);
      widget.onSaved();
    } catch (_) {}
  }
}
