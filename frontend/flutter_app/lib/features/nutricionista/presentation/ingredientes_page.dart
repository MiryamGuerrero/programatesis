import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/state/app_providers.dart";

class IngredientesPage extends ConsumerStatefulWidget {
  const IngredientesPage({super.key});

  @override
  ConsumerState<IngredientesPage> createState() => _IngredientesPageState();
}

class _IngredientesPageState extends ConsumerState<IngredientesPage> {
  final _nombreController = TextEditingController();
  final _grupoController = TextEditingController();

  bool _loading = false;
  List<Map<String, dynamic>> _ingredientes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _grupoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final data = await repo.fetchIngredientes();
      if (!mounted) {
        return;
      }
      setState(() => _ingredientes = data);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createIngrediente() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.createIngrediente(
        nombre: _nombreController.text.trim(),
        idGrupoAlimentario: int.tryParse(_grupoController.text),
      );
      _nombreController.clear();
      _grupoController.clear();
      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestion de ingredientes", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre ingrediente",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _grupoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "ID Grupo",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _createIngrediente,
              icon: const Icon(Icons.add),
              label: const Text("Agregar"),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text("Recargar"),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _ingredientes.length,
                  itemBuilder: (context, index) {
                    final item = _ingredientes[index];
                    return Card(
                      child: ListTile(
                        title: Text(item["nombre"]?.toString() ?? ""),
                        subtitle: Text("id=${item["id"]}, grupo=${item["id_grupo_alimentario"]}"),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
