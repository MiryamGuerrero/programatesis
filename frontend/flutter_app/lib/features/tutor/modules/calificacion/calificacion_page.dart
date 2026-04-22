import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";
import "package:reuma_nutri_app/shared/widgets/module_ux.dart";

class TutorCalificacionPage extends ConsumerStatefulWidget {
  const TutorCalificacionPage({super.key});

  @override
  ConsumerState<TutorCalificacionPage> createState() =>
      _TutorCalificacionPageState();
}

class _TutorCalificacionPageState extends ConsumerState<TutorCalificacionPage> {
  final _pacienteController = TextEditingController();
  final _comentarioController = TextEditingController();

  List<Map<String, dynamic>> _recetas = [];
  int? _selectedReceta;
  int _stars = 5;
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    final selectedPaciente = ref.read(selectedPatientIdProvider);
    if (selectedPaciente != null && selectedPaciente.trim().isNotEmpty) {
      _pacienteController.text = selectedPaciente.trim();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargarRecetas();
      }
    });
  }

  @override
  void dispose() {
    _pacienteController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _cargarRecetas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final recetas = await repo.fetchRecetas();

      if (!mounted) {
        return;
      }

      setState(() {
        _recetas = recetas;
        if (_selectedReceta != null &&
            !_recetas.any((r) =>
                (r["id"]?.toString() ?? "") == _selectedReceta.toString())) {
          _selectedReceta = null;
        }
      });
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

  Future<void> _guardar() async {
    final idPaciente = _pacienteController.text.trim();
    if (idPaciente.isEmpty) {
      setState(() => _error = "Ingresa el ID del paciente.");
      return;
    }

    final recetaId = _selectedReceta;
    if (recetaId == null) {
      setState(() => _error = "Selecciona una receta para calificar.");
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
        idPaciente: idPaciente,
        idReceta: recetaId,
        estrellas: _stars,
        comentario: _comentarioController.text.trim().isEmpty
            ? null
            : _comentarioController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() => _result = "Calificacion guardada correctamente.");
      ref.read(selectedPatientIdProvider.notifier).state = idPaciente;
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
    final recetaOptions = _recetas
        .map((receta) {
          final id = int.tryParse((receta["id"] ?? "").toString());
          if (id == null) {
            return null;
          }
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              (receta["nombre"] ?? "Receta $id").toString(),
              overflow: TextOverflow.ellipsis,
            ),
          );
        })
        .whereType<DropdownMenuItem<int>>()
        .toList();

    return ModuleViewport(
      child: ListView(
        children: [
          const ModuleHeaderCard(
            title: "Valorar recetas",
            subtitle:
                "Tu retroalimentacion mejora recomendaciones futuras para el paciente.",
            icon: Icons.star_rounded,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _pacienteController,
                    decoration: const InputDecoration(
                      labelText: "ID del paciente",
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<int?>(_selectedReceta),
            initialValue: _selectedReceta,
            decoration: const InputDecoration(
              labelText: "Receta",
            ),
            items: recetaOptions,
            onChanged: (value) => setState(() => _selectedReceta = value),
          ),
          const SizedBox(height: 12),
          Text(
            "Puntuacion",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 1; i <= 5; i++)
                ChoiceChip(
                  selected: _stars == i,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 16),
                      const SizedBox(width: 4),
                      Text("$i"),
                    ],
                  ),
                  onSelected: (_) => setState(() => _stars = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comentarioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Comentario (opcional)",
              hintText: "Que te gusto o que no funciono bien",
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _guardar,
                  icon: const Icon(Icons.star),
                  label: const Text("Guardar calificacion"),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _cargarRecetas,
                icon: const Icon(Icons.refresh),
                label: const Text("Actualizar recetas"),
              ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            ModuleNotice.success(_result!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ModuleNotice.error(_error!),
          ],
        ],
      ),
    );
  }
}
