import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";
import "package:reuma_nutri_app/shared/widgets/module_ux.dart";

class TutorConsumoPage extends ConsumerStatefulWidget {
  const TutorConsumoPage({super.key});

  @override
  ConsumerState<TutorConsumoPage> createState() => _TutorConsumoPageState();
}

class _TutorConsumoPageState extends ConsumerState<TutorConsumoPage> {
  final _pacienteController = TextEditingController();
  final _planItemController = TextEditingController();
  final _observacionController = TextEditingController();

  String _estadoCodigo = "CONSUMIDO_COMPLETO";
  List<Map<String, dynamic>> _planItems = [];
  List<Map<String, dynamic>> _recetas = [];
  int? _selectedPlanItem;
  int? _selectedRecetaReemplazo;
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    final selectedPaciente = ref.read(selectedPatientIdProvider);
    if (selectedPaciente != null && selectedPaciente.trim().isNotEmpty) {
      _pacienteController.text = selectedPaciente.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _cargarDatosPaciente();
        }
      });
    }
  }

  @override
  void dispose() {
    _pacienteController.dispose();
    _planItemController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosPaciente() async {
    final idPaciente = _pacienteController.text.trim();
    if (idPaciente.isEmpty) {
      setState(() => _error = "Ingresa el ID del paciente para continuar.");
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

      final planItems = responses[0];
      final recetas = responses[1];

      if (!mounted) {
        return;
      }

      setState(() {
        _planItems = planItems;
        _recetas = recetas;
        if (_selectedPlanItem != null &&
            !_planItems.any((e) =>
                (e["id"]?.toString() ?? "") == _selectedPlanItem.toString())) {
          _selectedPlanItem = null;
        }
        if (_selectedRecetaReemplazo != null &&
            !_recetas.any((e) =>
                (e["id"]?.toString() ?? "") ==
                _selectedRecetaReemplazo.toString())) {
          _selectedRecetaReemplazo = null;
        }
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

  Future<void> _guardarConsumo() async {
    final idPlanItem =
        _selectedPlanItem ?? int.tryParse(_planItemController.text);
    if (idPlanItem == null) {
      setState(
          () => _error = "Selecciona un item del plan para registrar consumo.");
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
        idRecetaReemplazo: _selectedRecetaReemplazo,
        observacion: _observacionController.text.trim().isEmpty
            ? null
            : _observacionController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = "Consumo guardado correctamente.";
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

  @override
  Widget build(BuildContext context) {
    final planOptions = _planItems
        .map(
          (item) => DropdownMenuItem<int>(
            value: int.tryParse((item["id"] ?? "").toString()),
            child: Text(
              "Item ${item["id"]} - Receta ${item["id_receta"]} (${item["fecha_programada"] ?? "sin fecha"})",
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .where((element) => element.value != null)
        .cast<DropdownMenuItem<int>>()
        .toList();

    final recetaOptions = _recetas
        .map(
          (receta) {
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
          },
        )
        .whereType<DropdownMenuItem<int>>()
        .toList();

    return ModuleViewport(
      child: ListView(
        children: [
          const ModuleHeaderCard(
            title: "Registrar consumo",
            subtitle:
                "Registra si la comida fue consumida completa, parcial o no consumida.",
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 340,
                        child: TextField(
                          controller: _pacienteController,
                          decoration: const InputDecoration(
                            labelText: "ID del paciente",
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _loading ? null : _cargarDatosPaciente,
                        icon: const Icon(Icons.sync),
                        label: const Text("Cargar"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _planItemController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "ID plan item (manual opcional)",
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<int?>(_selectedPlanItem),
            initialValue: _selectedPlanItem,
            decoration: const InputDecoration(
              labelText: "Item del plan",
            ),
            items: planOptions,
            onChanged: (value) {
              setState(() {
                _selectedPlanItem = value;
                if (value != null) {
                  _planItemController.text = value.toString();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_estadoCodigo),
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
          DropdownButtonFormField<int>(
            key: ValueKey<int?>(_selectedRecetaReemplazo),
            initialValue: _selectedRecetaReemplazo,
            decoration: const InputDecoration(
              labelText: "Receta de reemplazo (opcional)",
            ),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text("Sin reemplazo"),
              ),
              ...recetaOptions,
            ],
            onChanged: (value) =>
                setState(() => _selectedRecetaReemplazo = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observacionController,
            decoration: const InputDecoration(
              labelText: "Observacion",
              hintText: "Ejemplo: rechazo por sabor o malestar",
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _guardarConsumo,
            icon: const Icon(Icons.save),
            label: const Text("Guardar consumo"),
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
