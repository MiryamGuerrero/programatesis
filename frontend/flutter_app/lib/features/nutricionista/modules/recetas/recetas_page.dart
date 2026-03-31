import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class RecetasPage extends ConsumerStatefulWidget {
  const RecetasPage({super.key});

  @override
  ConsumerState<RecetasPage> createState() => _RecetasPageState();
}

class _RecetasPageState extends ConsumerState<RecetasPage> {
  final _pacienteController = TextEditingController();
  final _momentoController = TextEditingController();

  bool _loading = false;
  List<Map<String, dynamic>> _recetas = [];
  Map<String, dynamic>? _permitidas;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadRecetas);
  }

  @override
  void dispose() {
    _pacienteController.dispose();
    _momentoController.dispose();
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

  Future<void> _consultarPermitidas() async {
    setState(() {
      _loading = true;
      _error = null;
      _permitidas = null;
    });

    try {
      final api = ref.read(inteligenciaRepositoryProvider);
      final data = await api.recetasPermitidas(
        idPaciente: _pacienteController.text.trim(),
        idMomento: int.tryParse(_momentoController.text),
      );
      if (!mounted) {
        return;
      }
      setState(() => _permitidas = data);
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
    return ListView(
      children: [
        Text("Recetas", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _pacienteController,
                decoration: const InputDecoration(
                  labelText: "ID Paciente para filtrar permitidas",
                ),
              ),
            ),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _momentoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "ID Momento",
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _consultarPermitidas,
              icon: const Icon(Icons.filter_alt),
              label: const Text("Recetas permitidas"),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadRecetas,
              icon: const Icon(Icons.refresh),
              label: const Text("Listado base"),
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
        const SizedBox(height: 12),
        if (_permitidas != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                  const JsonEncoder.withIndent("  ").convert(_permitidas)),
            ),
          ),
        const SizedBox(height: 8),
        Text("Repositorio de recetas",
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final receta in _recetas)
          Card(
            child: ListTile(
              title: Text(receta["nombre"]?.toString() ?? ""),
              subtitle: Text(
                  "id=${receta["id"]} | kcal=${receta["calorias_totales"]}"),
            ),
          ),
      ],
    );
  }
}

