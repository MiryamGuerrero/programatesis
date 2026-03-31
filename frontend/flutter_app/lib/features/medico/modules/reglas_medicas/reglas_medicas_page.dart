import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class ReglasMedicasPage extends ConsumerStatefulWidget {
  const ReglasMedicasPage({super.key});

  @override
  ConsumerState<ReglasMedicasPage> createState() => _ReglasMedicasPageState();
}

class _ReglasMedicasPageState extends ConsumerState<ReglasMedicasPage> {
  final _condicionesController = TextEditingController();
  final _ingredientesController = TextEditingController();
  final _gruposController = TextEditingController();
  final _etiquetasController = TextEditingController();

  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _condicionesController.dispose();
    _ingredientesController.dispose();
    _gruposController.dispose();
    _etiquetasController.dispose();
    super.dispose();
  }

  List<int> _parseIds(String raw) {
    return raw
        .split(",")
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  Future<void> _evaluar() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final api = ref.read(inteligenciaRepositoryProvider);
      final result = await api.reglasEvaluacion(
        condiciones: _parseIds(_condicionesController.text),
        ingredientes: _parseIds(_ingredientesController.text),
        grupos: _parseIds(_gruposController.text),
        etiquetas: _parseIds(_etiquetasController.text),
      );

      if (!mounted) {
        return;
      }
      setState(() => _result = result);
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
        Text("Reglas medicas", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _text(
          _condicionesController,
          "IDs condiciones (ej. 1,3,7)",
        ),
        const SizedBox(height: 12),
        _text(_ingredientesController, "IDs ingredientes"),
        const SizedBox(height: 12),
        _text(_gruposController, "IDs grupos"),
        const SizedBox(height: 12),
        _text(_etiquetasController, "IDs etiquetas"),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _evaluar,
          icon: const Icon(Icons.rule),
          label: const Text("Evaluar reglas"),
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
        if (_result != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            const JsonEncoder.withIndent("  ").convert(_result),
            style: const TextStyle(fontFamily: "monospace"),
          ),
        ],
      ],
    );
  }

  Widget _text(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}

