import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

class ReglasNutricionalesPage extends ConsumerStatefulWidget {
  const ReglasNutricionalesPage({super.key});

  @override
  ConsumerState<ReglasNutricionalesPage> createState() =>
      _ReglasNutricionalesPageState();
}

class _ReglasNutricionalesPageState
    extends ConsumerState<ReglasNutricionalesPage> {
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
      debugPrint("Error loading rules: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al cargar datos")),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Regla"),
        content: const Text("¿Estás seguro de eliminar esta regla nutricional?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dio.delete("reglas-nutricionales/$id");
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al eliminar")));
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu, color: Colors.blue.shade800, size: 28),
                      const SizedBox(width: 12),
                      const Text("Reglas de Condición Nutricional", 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.add),
                    label: const Text("Nueva Regla Nutricional"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text("Configure cómo las etiquetas de los alimentos afectan las recomendaciones basándose exclusivamente en condiciones de tipo nutricional.",
                style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        Expanded(
          child: _rules.isEmpty 
          ? const Center(child: Text("No hay reglas nutricionales configuradas."))
          : ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: _rules.length,
            itemBuilder: (ctx, i) {
              final r = _rules[i] as Map<String, dynamic>;
              final condicionesIds = r["id_condiciones"] as List;
              final nombresCondiciones = condicionesIds.map((id) {
                final c = _formData["condiciones"]?.firstWhere((c) => c["id"] == id, orElse: () => null);
                return c != null ? c["nombre"] : "Condición $id";
              }).join(", ");

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 1,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getActionColor(r['accion_codigo']).withOpacity(0.1),
                    child: Icon(_getActionIcon(r['accion_codigo']), color: _getActionColor(r['accion_codigo'])),
                  ),
                  title: Text("${r['etiqueta_nombre']} ➔ ${r['accion_codigo']}", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (r["es_estricta"] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                          child: const Text("⚠️ REGLA ESTRICTA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      const SizedBox(height: 4),
                      RichText(text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                        children: [
                          const TextSpan(text: "Se aplica en: ", style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: nombresCondiciones),
                        ]
                      )),
                      Text("Mensaje: ${r['mensaje_error'] ?? 'Sin mensaje'}", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_note, color: Colors.blue), onPressed: () => _showForm(r), tooltip: "Editar"),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteRule(r["id"]), tooltip: "Eliminar"),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getActionColor(String? action) {
    switch (action) {
      case 'ELIMINAR': return Colors.red;
      case 'DISMINUIR': return Colors.orange;
      case 'PRIORIZAR': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getActionIcon(String? action) {
    switch (action) {
      case 'ELIMINAR': return Icons.block;
      case 'DISMINUIR': return Icons.trending_down;
      case 'PRIORIZAR': return Icons.star;
      default: return Icons.rule;
    }
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

  Future<void> _save(WidgetRef ref) async {
    if (_idEtiqueta == null || _idAccion == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete etiqueta y acción")));
      return;
    }
    if (_selectedCondiciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seleccione al menos una condición")));
      return;
    }
    
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        "id_etiqueta": _idEtiqueta,
        "id_accion": _idAccion,
        "id_tipo_objetivo": 3,
        "mensaje_error": _mensajeController.text,
        "id_condiciones": _selectedCondiciones,
        "es_estricta": _esEstricta,
      };

      if (widget.initialRule != null) {
        await dio.put("reglas-nutricionales/${widget.initialRule!['id']}", data: payload);
      } else {
        await dio.post("reglas-nutricionales", data: payload);
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al guardar regla")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) => AlertDialog(
        title: Row(
          children: [
            Icon(widget.initialRule != null ? Icons.edit_calendar : Icons.add_moderator, color: Colors.blue),
            const SizedBox(width: 10),
            Text(widget.initialRule != null ? "Editar Regla Nutricional" : "Nueva Regla Nutricional"),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  value: _idEtiqueta,
                  decoration: const InputDecoration(labelText: "Etiqueta Alimentaria", prefixIcon: Icon(Icons.label)),
                  items: widget.formData["etiquetas"]?.map((e) => DropdownMenuItem<int>(
                    value: e["id"], child: Text(e["nombre"]))).toList(),
                  onChanged: (v) => setState(() => _idEtiqueta = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _idAccion,
                  decoration: const InputDecoration(labelText: "Acción Recomendada", prefixIcon: Icon(Icons.settings_suggest)),
                  items: widget.formData["acciones"]?.map((a) => DropdownMenuItem<int>(
                    value: a["id"], child: Text(a["nombre"]))).toList(),
                  onChanged: (v) => setState(() => _idAccion = v),
                ),
                const SizedBox(height: 20),
                const Text("Condiciones Nutricionales activadoras:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50
                  ),
                  height: 200,
                  child: ListView(
                    children: widget.formData["condiciones"]!.map((c) => CheckboxListTile(
                      title: Text(c["nombre"], style: const TextStyle(fontSize: 14)),
                      value: _selectedCondiciones.contains(c["id"]),
                      activeColor: Colors.blue,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) _selectedCondiciones.add(c["id"]);
                          else _selectedCondiciones.remove(c["id"]);
                        });
                      },
                      dense: true,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _mensajeController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Mensaje de Guía", 
                    hintText: "Ej: Disminuir por exceso de sodio...",
                    prefixIcon: Icon(Icons.comment)
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text("¿Regla Estricta?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  subtitle: const Text("Si se marca, el sistema prohibirá el alimento."),
                  value: _esEstricta,
                  activeColor: Colors.red,
                  onChanged: (v) => setState(() => _esEstricta = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          FilledButton(
            onPressed: _saving ? null : () => _save(ref),
            child: _saving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Guardar Regla"),
          ),
        ],
      ),
    );
  }
}
