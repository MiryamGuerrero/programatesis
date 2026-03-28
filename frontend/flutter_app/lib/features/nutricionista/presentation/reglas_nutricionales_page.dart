import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/state/app_providers.dart";

class ReglasNutricionalesPage extends ConsumerStatefulWidget {
  const ReglasNutricionalesPage({super.key});

  @override
  ConsumerState<ReglasNutricionalesPage> createState() => _ReglasNutricionalesPageState();
}

class _ReglasNutricionalesPageState extends ConsumerState<ReglasNutricionalesPage> {
  final _condicionesController = TextEditingController();
  final _ingredientesController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _response;
  String? _error;

  @override
  void dispose() {
    _condicionesController.dispose();
    _ingredientesController.dispose();
    super.dispose();
  }

  List<int> _parseIds(String text) {
    return text
        .split(",")
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  Future<void> _simularReglas() async {
    setState(() {
      _loading = true;
      _error = null;
      _response = null;
    });

    try {
      final api = ref.read(inteligenciaRepositoryProvider);
      final data = await api.reglasEvaluacion(
        condiciones: _parseIds(_condicionesController.text),
        ingredientes: _parseIds(_ingredientesController.text),
      );
      if (!mounted) {
        return;
      }
      setState(() => _response = data);
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
        Text("Reglas nutricionales", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _condicionesController,
          decoration: const InputDecoration(
            labelText: "IDs condiciones",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ingredientesController,
          decoration: const InputDecoration(
            labelText: "IDs ingredientes",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _simularReglas,
          icon: const Icon(Icons.policy),
          label: const Text("Simular efecto de reglas"),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_response != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                const JsonEncoder.withIndent("  ").convert(_response),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
