import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class TutorReemplazoPage extends ConsumerStatefulWidget {
  const TutorReemplazoPage({super.key});

  @override
  ConsumerState<TutorReemplazoPage> createState() => _TutorReemplazoPageState();
}

class _TutorReemplazoPageState extends ConsumerState<TutorReemplazoPage> {
  final _ingredienteController = TextEditingController();
  final _cantidadController = TextEditingController();

  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _ingredienteController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    final idIngrediente = int.tryParse(_ingredienteController.text);
    if (idIngrediente == null) {
      setState(() => _error = "ID ingrediente invalido");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final api = ref.read(inteligenciaRepositoryProvider);
      final data = await api.reemplazoEquivalente(
        idIngredienteOriginal: idIngrediente,
        cantidadGramos: double.tryParse(_cantidadController.text),
      );
      if (!mounted) {
        return;
      }
      setState(() => _result = data);
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
        Text("Reemplazo por equivalentes",
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _ingredienteController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "ID ingrediente original",
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cantidadController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Cantidad en gramos (opcional)",
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _consultar,
          icon: const Icon(Icons.swap_horiz),
          label: const Text("Buscar reemplazos"),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                  const JsonEncoder.withIndent("  ").convert(_result)),
            ),
          ),
        ],
      ],
    );
  }
}

