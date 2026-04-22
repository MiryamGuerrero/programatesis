import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

class ReglasMedicasPage extends ConsumerStatefulWidget {
  const ReglasMedicasPage({super.key});

  @override
  ConsumerState<ReglasMedicasPage> createState() => _ReglasMedicasPageState();
}

class _ReglasMedicasPageState extends ConsumerState<ReglasMedicasPage> {
  bool _loading = true;
  List<dynamic> _rules = [];
  Map<String, List<dynamic>> _formData = {
    "acciones": [], "objetivos": [], "condiciones": [],
    "ingredientes": [], "grupos": [], "subgrupos": [], "etiquetas": []
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
        _dio.get("reglas-medicas"),
        _dio.get("reglas-medicas/form-data"),
      ]);
      setState(() {
        _rules = results[0].data as List;
        _formData = Map<String, List<dynamic>>.from(results[1].data as Map);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al cargar reglas médicas")));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Regla"),
        content: const Text("¿Estás seguro de eliminar esta regla médica?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar")),
        ],
      ),
    );
    if (confirm == true) {
      await _dio.delete("reglas-medicas/$id");
      _loadData();
    }
  }

  void _showForm([Map<String, dynamic>? rule]) {
    showDialog(
      context: context,
      builder: (ctx) => _MedicalRuleFormDialog(
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
            color: Colors.blueGrey.shade50,
            border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Reglas de Recomendación Médica", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Defina qué alimentos se deben restringir o priorizar según diagnósticos médicos.", style: TextStyle(color: Colors.black54)),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add_moderator),
                label: const Text("Nueva Regla Médica"),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
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
                child: ListTile(
                  leading: Icon(_getTargetIcon(r['objetivo_codigo']), color: Colors.blueGrey),
                  title: Text("${r['accion_codigo']} ➔ ${_getTargetName(r)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r["es_estricta"] == true) const Text("🚫 RESTRICCIÓN ABSOLUTA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                      Text("Para: $nombresCondiciones", style: const TextStyle(fontSize: 12)),
                      Text("Guía: ${r['mensaje_error'] ?? '-'}", style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(r)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteRule(r["id"])),
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

  String _getTargetName(Map<String, dynamic> r) {
    return r['ingrediente_nombre'] ?? r['grupo_nombre'] ?? r['subgrupo_nombre'] ?? r['etiqueta_nombre'] ?? "Objetivo";
  }

  IconData _getTargetIcon(String? obj) {
    switch (obj) {
      case 'INGREDIENTE': return Icons.apple;
      case 'GRUPO': return Icons.category;
      case 'ETIQUETA': return Icons.label;
      default: return Icons.adjust;
    }
  }
}

class _MedicalRuleFormDialog extends StatefulWidget {
  final Map<String, List<dynamic>> formData;
  final Map<String, dynamic>? initialRule;
  final VoidCallback onSaved;

  const _MedicalRuleFormDialog({required this.formData, this.initialRule, required this.onSaved});

  @override
  State<_MedicalRuleFormDialog> createState() => _MedicalRuleFormDialogState();
}

class _MedicalRuleFormDialogState extends State<_MedicalRuleFormDialog> {
  int? _idAccion, _idObjetivo, _idTarget;
  late TextEditingController _mensajeController;
  late List<int> _selectedCondiciones;
  late bool _esEstricta;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRule;
    _idAccion = r?["id_accion"];
    _idObjetivo = r?["id_tipo_objetivo"];
    _idTarget = r?["id_ingrediente"] ?? r?["id_grupo_alimentario"] ?? r?["id_subgrupo_alimentario"] ?? r?["id_etiqueta"];
    _mensajeController = TextEditingController(text: r?["mensaje_error"]);
    _selectedCondiciones = List<int>.from(r?["id_condiciones"] ?? []);
    _esEstricta = r?["es_estricta"] ?? false;
  }

  Future<void> _save(WidgetRef ref) async {
    if (_idAccion == null || _idObjetivo == null || _idTarget == null || _selectedCondiciones.isEmpty) return;
    setState(() => _saving = true);
    try {
      final payload = {
        "id_accion": _idAccion,
        "id_tipo_objetivo": _idObjetivo,
        "mensaje_error": _mensajeController.text,
        "id_condiciones": _selectedCondiciones,
        "es_estricta": _esEstricta,
        "id_ingrediente": _idObjetivo == 1 ? _idTarget : null,
        "id_grupo_alimentario": _idObjetivo == 2 ? _idTarget : null,
        "id_etiqueta": _idObjetivo == 3 ? _idTarget : null,
        "id_subgrupo_alimentario": _idObjetivo == 4 ? _idTarget : null,
      };
      final dio = ref.read(dioProvider);
      if (widget.initialRule != null) {
        await dio.put("reglas-medicas/${widget.initialRule!['id']}", data: payload);
      } else {
        await dio.post("reglas-medicas", data: payload);
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> targetList = [];
    if (_idObjetivo == 1) targetList = widget.formData["ingredientes"]!;
    else if (_idObjetivo == 2) targetList = widget.formData["grupos"]!;
    else if (_idObjetivo == 3) targetList = widget.formData["etiquetas"]!;
    else if (_idObjetivo == 4) targetList = widget.formData["subgrupos"]!;

    return Consumer(
      builder: (context, ref, child) => AlertDialog(
        title: Text(widget.initialRule != null ? "Editar Regla Médica" : "Nueva Regla Médica"),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: _idObjetivo,
                  decoration: const InputDecoration(labelText: "Tipo de Objetivo"),
                  items: widget.formData["objetivos"]?.map((o) => DropdownMenuItem<int>(value: o["id"], child: Text(o["nombre"]))).toList(),
                  onChanged: (v) => setState(() { _idObjetivo = v; _idTarget = null; }),
                ),
                if (_idObjetivo != null)
                  DropdownButtonFormField<int>(
                    value: _idTarget,
                    decoration: const InputDecoration(labelText: "Seleccionar Item"),
                    items: targetList.map((t) => DropdownMenuItem<int>(value: t["id"], child: Text(t["nombre"]))).toList(),
                    onChanged: (v) => setState(() => _idTarget = v),
                  ),
                DropdownButtonFormField<int>(
                  value: _idAccion,
                  decoration: const InputDecoration(labelText: "Acción Médica"),
                  items: widget.formData["acciones"]?.map((a) => DropdownMenuItem<int>(value: a["id"], child: Text(a["nombre"]))).toList(),
                  onChanged: (v) => setState(() => _idAccion = v),
                ),
                const SizedBox(height: 16),
                const Text("Se activa en diagnósticos:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...widget.formData["condiciones"]!.map((c) => CheckboxListTile(
                  title: Text(c["nombre"]),
                  value: _selectedCondiciones.contains(c["id"]),
                  onChanged: (v) {
                    setState(() { if (v == true) _selectedCondiciones.add(c["id"]); else _selectedCondiciones.remove(c["id"]); });
                  },
                  dense: true,
                )),
                TextField(controller: _mensajeController, decoration: const InputDecoration(labelText: "Justificación Médica")),
                SwitchListTile(title: const Text("¿Restricción Absoluta?"), value: _esEstricta, onChanged: (v) => setState(() => _esEstricta = v)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          FilledButton(onPressed: _saving ? null : () => _save(ref), child: const Text("Guardar Regla")),
        ],
      ),
    );
  }
}
