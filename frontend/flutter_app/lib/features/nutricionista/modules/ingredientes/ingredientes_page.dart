import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class IngredientesPage extends ConsumerStatefulWidget {
  const IngredientesPage({super.key});

  @override
  ConsumerState<IngredientesPage> createState() => _IngredientesPageState();
}

class _IngredientesPageState extends ConsumerState<IngredientesPage> {
  final _nombreController = TextEditingController();
  final _searchController = TextEditingController();

  bool _loading = false;
  List<Map<String, dynamic>> _ingredientes = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _searchController.dispose();
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
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      setState(() {
        _error = "Escribe el nombre del ingrediente.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.createIngrediente(
        nombre: nombre,
        idGrupoAlimentario: null,
      );

      _nombreController.clear();
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
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? _ingredientes
        : _ingredientes
            .where((row) =>
                (row["nombre"]?.toString().toLowerCase() ?? "").contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gestion de ingredientes",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          "Carga simple directa desde API CRUD. Sin captura manual de IDs.",
          style: TextStyle(color: Color(0xFF5B6978), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nuevo ingrediente",
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
        const SizedBox(height: 10),
        SizedBox(
          width: 360,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: "Buscar por nombre",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text("Total: ${_ingredientes.length}")),
            Chip(label: Text("Visibles: ${visible.length}")),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    final activo = item["activo"] == true;
                    return Card(
                      child: ListTile(
                        title: Text(item["nombre"]?.toString() ?? ""),
                        subtitle: Text(
                          activo ? "Activo" : "Inactivo",
                          style: TextStyle(
                            color: activo
                                ? const Color(0xFF16683B)
                                : const Color(0xFF9A5C11),
                            fontWeight: FontWeight.w700,
                          ),
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
