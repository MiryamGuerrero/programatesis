import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class TutorConsumoPage extends ConsumerStatefulWidget {
  const TutorConsumoPage({super.key});

  @override
  ConsumerState<TutorConsumoPage> createState() => _TutorConsumoPageState();
}

class _TutorConsumoPageState extends ConsumerState<TutorConsumoPage> {
  final _planItemController = TextEditingController();
  final _recetaReemplazoController = TextEditingController();
  final _observacionController = TextEditingController();

  String _estadoCodigo = "CONSUMIDO_COMPLETO";
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _planItemController.dispose();
    _recetaReemplazoController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _guardarConsumo() async {
    final idPlanItem = int.tryParse(_planItemController.text);
    if (idPlanItem == null) {
      setState(() => _error = "ID de plan item invalido");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.registerConsumption(
        idPlanItem: idPlanItem,
        estadoCodigo: _estadoCodigo,
        idRecetaReemplazo: int.tryParse(_recetaReemplazoController.text),
        observacion: _observacionController.text.trim().isEmpty
            ? null
            : _observacionController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() => _result = "Consumo guardado correctamente");
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
        Text("Registro de consumo",
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _planItemController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "ID Plan Item",
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _estadoCodigo,
          decoration: const InputDecoration(
            labelText: "Estado de consumo",
          ),
          items: const [
            DropdownMenuItem(
              value: "NO_CONSUMIDO",
              child: Text("No consumido"),
            ),
            DropdownMenuItem(
              value: "CONSUMIDO_PARCIAL",
              child: Text("Consumido parcial"),
            ),
            DropdownMenuItem(
              value: "CONSUMIDO_COMPLETO",
              child: Text("Consumido completo"),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _estadoCodigo = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _recetaReemplazoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "ID receta reemplazo (opcional)",
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _observacionController,
          decoration: const InputDecoration(
            labelText: "Observacion",
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _guardarConsumo,
          icon: const Icon(Icons.save),
          label: const Text("Guardar"),
        ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          Text(
            _result!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      ],
    );
  }
}

