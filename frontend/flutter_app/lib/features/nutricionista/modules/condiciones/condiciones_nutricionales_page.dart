import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

class CondicionesNutricionalesPage extends ConsumerStatefulWidget {
  const CondicionesNutricionalesPage({super.key});

  @override
  ConsumerState<CondicionesNutricionalesPage> createState() =>
      _CondicionesNutricionalesPageState();
}

class _CondicionesNutricionalesPageState
    extends ConsumerState<CondicionesNutricionalesPage> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al cargar el catálogo")),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteCondition(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Condición"),
        content: const Text("Si la condición ha sido usada en pacientes, solo se desactivará. ¿Deseas continuar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Aceptar")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dio.delete("condiciones-nutricionales/$id");
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al eliminar")));
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            border: Border(bottom: BorderSide(color: Colors.teal.shade100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, color: Colors.teal.shade800, size: 28),
                      const SizedBox(width: 12),
                      const Text("Catálogo de Condiciones Nutricionales", 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.add),
                    label: const Text("Nueva Condición"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text("Gestione los diagnósticos nutricionales que el sistema puede asignar a los pacientes.",
                style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        Expanded(
          child: _conditions.isEmpty 
          ? const Center(child: Text("No hay condiciones configuradas."))
          : ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: _conditions.length,
            itemBuilder: (ctx, i) {
              final c = _conditions[i] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: c['activa'] == true ? Colors.green.shade100 : Colors.grey.shade200,
                    child: Icon(Icons.medical_services, color: c['activa'] == true ? Colors.green : Colors.grey),
                  ),
                  title: Text(c['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(c['descripcion'] ?? 'Sin descripción'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c['activa'] == false)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Chip(label: Text("Inactiva", style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                        ),
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(c)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteCondition(c["id"])),
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

  Future<void> _save(WidgetRef ref) async {
    if (_nombreController.text.isEmpty) return;
    
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        "nombre": _nombreController.text,
        "descripcion": _descripcionController.text,
        "activa": _activa,
      };

      if (widget.initialCondition != null) {
        await dio.put("condiciones-nutricionales/${widget.initialCondition!['id']}", data: payload);
      } else {
        await dio.post("condiciones-nutricionales", data: payload);
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al guardar")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) => AlertDialog(
        title: Text(widget.initialCondition != null ? "Editar Condición" : "Nueva Condición Nutricional"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: "Nombre de la Condición"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcionController,
              decoration: const InputDecoration(labelText: "Descripción / Observaciones"),
              maxLines: 3,
            ),
            if (widget.initialCondition != null)
              SwitchListTile(
                title: const Text("Condición Activa"),
                value: _activa,
                onChanged: (v) => setState(() => _activa = v),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          FilledButton(
            onPressed: _saving ? null : () => _save(ref),
            child: _saving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Guardar"),
          ),
        ],
      ),
    );
  }
}
