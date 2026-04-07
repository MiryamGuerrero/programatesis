import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class RecetasPage extends ConsumerStatefulWidget {
  const RecetasPage({super.key});

  @override
  ConsumerState<RecetasPage> createState() => _RecetasPageState();
}

class _RecetasPageState extends ConsumerState<RecetasPage> {
  final _searchController = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _recetas = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadRecetas);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecetas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final data = await repo.fetchRecetas();
      if (!mounted) {
        return;
      }
      setState(() => _recetas = data);
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
        ? _recetas
        : _recetas.where((row) {
            final nombre = row["nombre"]?.toString().toLowerCase() ?? "";
            return nombre.contains(query);
          }).toList();

    return ListView(
      children: [
        Text("Recetas", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          "Extraccion directa desde CRUD. Sin flujo de IDs manuales para consulta basica.",
          style: TextStyle(color: Color(0xFF5B6978), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: "Buscar receta",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadRecetas,
              icon: const Icon(Icons.refresh),
              label: const Text("Recargar"),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text("Total: ${_recetas.length}")),
            Chip(label: Text("Visibles: ${visible.length}")),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("No hay recetas para el filtro actual."),
          )
        else
          ...visible.map(
            (receta) {
              final kcalRaw = receta["calorias_totales"];
              final kcalText = kcalRaw == null ? "Sin dato" : kcalRaw.toString();

              return Card(
                child: ListTile(
                  title: Text(receta["nombre"]?.toString() ?? "Receta"),
                  subtitle: Text("Calorias totales: $kcalText"),
                ),
              );
            },
          ),
      ],
    );
  }
}
