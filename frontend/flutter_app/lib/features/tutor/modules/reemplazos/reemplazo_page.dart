import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";
import "package:reuma_nutri_app/shared/widgets/module_ux.dart";

class TutorReemplazoPage extends ConsumerStatefulWidget {
  const TutorReemplazoPage({super.key});

  @override
  ConsumerState<TutorReemplazoPage> createState() => _TutorReemplazoPageState();
}

class _TutorReemplazoPageState extends ConsumerState<TutorReemplazoPage> {
  final _cantidadController = TextEditingController();

  List<Map<String, dynamic>> _ingredientes = [];
  int? _selectedIngredienteId;
  bool _loading = false;
  List<Map<String, dynamic>> _reemplazos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargarIngredientes();
      }
    });
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _cargarIngredientes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final ingredientes = await repo.fetchIngredientes();

      if (!mounted) {
        return;
      }

      setState(() {
        _ingredientes = ingredientes;
        if (_selectedIngredienteId != null &&
            !_ingredientes.any((i) =>
                (i["id"]?.toString() ?? "") ==
                _selectedIngredienteId.toString())) {
          _selectedIngredienteId = null;
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

  Future<void> _consultar() async {
    final idIngrediente = _selectedIngredienteId;
    if (idIngrediente == null) {
      setState(
          () => _error = "Selecciona un ingrediente para buscar equivalentes.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _reemplazos = [];
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
      final replacementsRaw = data["reemplazos"];
      final replacements = replacementsRaw is List
          ? replacementsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      setState(() => _reemplazos = replacements);
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
    final ingredientOptions = _ingredientes
        .map((item) {
          final id = int.tryParse((item["id"] ?? "").toString());
          if (id == null) {
            return null;
          }
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              (item["nombre"] ?? "Ingrediente $id").toString(),
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
            title: "Reemplazos equivalentes",
            subtitle:
                "Encuentra alternativas por ingrediente y gramos sugeridos para el paciente.",
            icon: Icons.swap_horiz_rounded,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey<int?>(_selectedIngredienteId),
                    initialValue: _selectedIngredienteId,
                    decoration: const InputDecoration(
                      labelText: "Ingrediente original",
                    ),
                    items: ingredientOptions,
                    onChanged: (value) =>
                        setState(() => _selectedIngredienteId = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cantidadController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Cantidad en gramos (opcional)",
              hintText: "Ejemplo: 120",
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _consultar,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text("Buscar reemplazos"),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _cargarIngredientes,
                icon: const Icon(Icons.refresh),
                label: const Text("Actualizar"),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ModuleNotice.error(_error!),
          ],
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ] else if (_reemplazos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              "Opciones disponibles (${_reemplazos.length})",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ..._reemplazos.map((item) {
              final ratio = (item["ratio_conversion"] ?? "-").toString();
              final grams = item["gramos_recomendados"];
              final aviso = (item["mensaje_aviso"] ?? "").toString().trim();

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    child: Icon(
                      Icons.restaurant,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text((item["nombre"] ?? "Sin nombre").toString()),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Ratio de conversion: $ratio"),
                      if (grams != null) Text("Gramos recomendados: $grams g"),
                      if (aviso.isNotEmpty)
                        Text(
                          aviso,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ] else if (_error == null) ...[
            const SizedBox(height: 12),
            Text(
              "Aun no hay resultados. Selecciona ingrediente y consulta.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
