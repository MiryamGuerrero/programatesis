import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/state/app_providers.dart";

class CondicionesMedicasPage extends ConsumerStatefulWidget {
  const CondicionesMedicasPage({super.key});

  @override
  ConsumerState<CondicionesMedicasPage> createState() =>
      _CondicionesMedicasPageState();
}

class _CondicionesMedicasPageState
    extends ConsumerState<CondicionesMedicasPage> {
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
      final response = await _dio.get("catalogos/condiciones");
      setState(() {
        _conditions = response.data as List;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al cargar el catálogo médico")),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteCondition(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar condición"),
        content: const Text(
            "Si la condición ha sido asignada a pacientes, solo se desactivará. ¿Continuar?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Aceptar")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dio.delete("catalogos/condiciones/$id");
      _loadData();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Error al eliminar")));
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
            color: Colors.indigo.shade50,
            border: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medical_information_outlined,
                          color: Colors.indigo.shade800, size: 28),
                      const SizedBox(width: 12),
                      const Text("Catálogo de condiciones médicas",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Nueva condición médica"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                  "Gestione las condiciones clínicas y temporales que los médicos pueden diagnosticar.",
                  style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        Expanded(
          child: _conditions.isEmpty
              ? const Center(
                  child: Text("No hay condiciones médicas configuradas."))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: _conditions.length,
                  itemBuilder: (ctx, i) {
                    final c = _conditions[i] as Map<String, dynamic>;
                    final isTemporal = c['id_tipo_condicion'] == 2;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTemporal
                              ? Colors.orange.shade100
                              : Colors.blue.shade100,
                          child: Icon(
                              isTemporal
                                  ? Icons.timer_outlined
                                  : Icons.monitor_heart,
                              color: isTemporal
                                  ? Colors.orange.shade800
                                  : Colors.blue.shade800),
                        ),
                        title: Text(c['nombre']?.toString() ?? "Condición",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Tipo: ${c['tipo_nombre'] ?? '-'}",
                                style: TextStyle(
                                    color: isTemporal
                                        ? Colors.orange.shade900
                                        : Colors.blue.shade900,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                            Text(c['descripcion']?.toString() ??
                                'Sin descripción'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c['activa'] == false)
                              const Chip(
                                  label: Text("Inactiva",
                                      style: TextStyle(fontSize: 10))),
                            IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showForm(c)),
                            IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCondition(c["id"])),
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
  late int _idTipo;
  late bool _activa;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCondition;
    _nombreController = TextEditingController(text: c?["nombre"]);
    _descripcionController = TextEditingController(text: c?["descripcion"]);
    _idTipo =
        c?["id_tipo"] ?? c?["id_tipo_condicion"] ?? 1; // 1: CLINICA por defecto
    _activa = c?["activa"] ?? true;
  }

  Future<void> _save(WidgetRef ref) async {
    if (_nombreController.text.isEmpty) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);

      if (widget.initialCondition != null) {
        await repo.updateCondition(
          idCondicion: widget.initialCondition!['id'],
          nombre: _nombreController.text,
          idTipoCondicion: _idTipo,
          activa: _activa,
          descripcion: _descripcionController.text,
          codigo: widget.initialCondition!['codigo'],
        );
      } else {
        await repo.createCondition(
          nombre: _nombreController.text,
          idTipoCondicion: _idTipo,
          activa: _activa,
          descripcion: _descripcionController.text,
        );
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Error al guardar")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) => AlertDialog(
        title: Text(widget.initialCondition != null
            ? "Editar condición"
            : "Nueva condición médica"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreController,
                decoration:
                    const InputDecoration(labelText: "Nombre de la Condición"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _idTipo,
                decoration:
                    const InputDecoration(labelText: "Tipo de condición"),
                items: const [
                  DropdownMenuItem(
                      value: 1, child: Text("Clínica (Permanente)")),
                  DropdownMenuItem(
                      value: 2, child: Text("Temporal (Ej: Gripe, Embarazo)")),
                ],
                onChanged: (v) => setState(() => _idTipo = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcionController,
                decoration:
                    const InputDecoration(labelText: "Descripción / Detalles"),
                maxLines: 3,
              ),
              if (widget.initialCondition != null)
                SwitchListTile(
                  title: const Text("Condición activa"),
                  value: _activa,
                  onChanged: (v) => setState(() => _activa = v),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          FilledButton(
            onPressed: _saving ? null : () => _save(ref),
            child: _saving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Guardar"),
          ),
        ],
      ),
    );
  }
}
