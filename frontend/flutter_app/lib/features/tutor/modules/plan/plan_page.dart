import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class TutorPlanPage extends ConsumerStatefulWidget {
  const TutorPlanPage({super.key});

  @override
  ConsumerState<TutorPlanPage> createState() => _TutorPlanPageState();
}

class _TutorPlanPageState extends ConsumerState<TutorPlanPage> {
  final _pacienteController = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  Map<int, String> _recetasById = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    final selectedPaciente = ref.read(selectedPatientIdProvider);
    if (selectedPaciente != null && selectedPaciente.trim().isNotEmpty) {
      _pacienteController.text = selectedPaciente.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _cargarPlan();
        }
      });
    }
  }

  @override
  void dispose() {
    _pacienteController.dispose();
    super.dispose();
  }

  Future<void> _cargarPlan() async {
    final idPaciente = _pacienteController.text.trim();
    if (idPaciente.isEmpty) {
      setState(() {
        _error = "Ingresa el ID del paciente para ver su plan.";
        _items = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final responses = await Future.wait([
        repo.fetchPlanItemsByPaciente(idPaciente),
        repo.fetchRecetas(),
      ]);

      final items = responses[0];
      final recetas = responses[1];
      final recetasById = <int, String>{};
      for (final receta in recetas) {
        final id = int.tryParse((receta["id"] ?? "").toString());
        if (id != null) {
          recetasById[id] = (receta["nombre"] ?? "Receta $id").toString();
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _recetasById = recetasById;
      });
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
    final dateFormat = DateFormat("yyyy-MM-dd");
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Plan del paciente", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  "Consulta las comidas programadas y usa el ID de item para registrar consumo.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pacienteController,
                        decoration: const InputDecoration(
                          labelText: "ID del paciente",
                          hintText: "Ejemplo: 8f3c...",
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _loading ? null : _cargarPlan,
                      icon: const Icon(Icons.search),
                      label: const Text("Ver plan"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.calendar_month, size: 18),
                      label: Text("Items: ${_items.length}"),
                    ),
                    Chip(
                      avatar: const Icon(Icons.person, size: 18),
                      label: Text(
                        "Paciente: ${_pacienteController.text.trim().isEmpty ? "No seleccionado" : _pacienteController.text.trim()}",
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        "No hay items para mostrar. Selecciona un paciente y carga su plan.",
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final fecha = DateTime.tryParse(
                          item["fecha_programada"]?.toString() ?? "",
                        );
                        final idReceta = int.tryParse((item["id_receta"] ?? "").toString());
                        final recetaLabel = idReceta == null
                            ? "Receta sin ID"
                            : (_recetasById[idReceta] ?? "Receta $idReceta");
                        final idMomento = int.tryParse((item["id_momento"] ?? "").toString());

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colors.primary.withValues(alpha: 0.12),
                              child: Icon(Icons.restaurant_menu, color: colors.primary),
                            ),
                            title: Text(recetaLabel),
                            subtitle: Text(
                              "Item ${item["id"]} | ${_momentoLabel(idMomento)} | ${fecha != null ? dateFormat.format(fecha) : (item["fecha_programada"] ?? "Sin fecha")}",
                            ),
                            trailing: Text(
                              "#${item["id"]}",
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
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

  String _momentoLabel(int? idMomento) {
    switch (idMomento) {
      case 1:
        return "Desayuno";
      case 2:
        return "Merienda AM";
      case 3:
        return "Almuerzo";
      case 4:
        return "Merienda PM";
      case 5:
        return "Cena";
      default:
        return "Momento ${idMomento ?? "-"}";
    }
  }
}

