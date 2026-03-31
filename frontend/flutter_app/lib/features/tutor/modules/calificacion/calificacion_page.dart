import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class TutorCalificacionPage extends ConsumerStatefulWidget {
  const TutorCalificacionPage({super.key});

  @override
  ConsumerState<TutorCalificacionPage> createState() =>
      _TutorCalificacionPageState();
}

class _TutorCalificacionPageState extends ConsumerState<TutorCalificacionPage> {
  final _pacienteController = TextEditingController();
  final _recetaController = TextEditingController();
  final _comentarioController = TextEditingController();

  int _stars = 5;
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _pacienteController.dispose();
    _recetaController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final recetaId = int.tryParse(_recetaController.text);
    if (recetaId == null) {
      setState(() => _error = "ID receta invalido");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.rateRecipe(
        idPaciente: _pacienteController.text.trim(),
        idReceta: recetaId,
        estrellas: _stars,
        comentario: _comentarioController.text.trim().isEmpty
            ? null
            : _comentarioController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() => _result = "Calificacion guardada");
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
        Text("Calificacion de recetas",
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _pacienteController,
          decoration: const InputDecoration(
            labelText: "ID Paciente",
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _recetaController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "ID Receta",
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _stars,
          decoration: const InputDecoration(
            labelText: "Estrellas",
          ),
          items: [
            for (int i = 1; i <= 5; i++)
              DropdownMenuItem(value: i, child: Text("$i")),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _stars = value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _comentarioController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: "Comentario",
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _guardar,
          icon: const Icon(Icons.star),
          label: const Text("Guardar calificacion"),
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

