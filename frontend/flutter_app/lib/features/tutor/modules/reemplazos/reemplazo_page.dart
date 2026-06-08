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
  final _ingSearchCtrl = TextEditingController();
  final _ingFocus = FocusNode();

  List<Map<String, dynamic>> _ingredientes = [];
  int? _selectedIngredienteId;
  String? _selectedIngredienteNombre;
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
    _ingFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _ingSearchCtrl.dispose();
    _ingFocus.dispose();
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
                  StatefulBuilder(
                    builder: (context, setInternalState) {
                      final q = _ingSearchCtrl.text.toLowerCase().trim();

                      final matches = _ingredientes.where((e) {
                        if (q.isEmpty) return true;

                        final name =
                            (e['nombre'] ?? "").toString().toLowerCase();
                        final syns = (e['sinonimos'] as List? ?? [])
                            .map((s) => s.toString().toLowerCase())
                            .toList();

                        // Lógica de palabras completas (igual que en registro)
                        final stopWords = {
                          'de',
                          'con',
                          'en',
                          'el',
                          'la',
                          'los',
                          'las',
                          'un',
                          'una',
                          'para',
                          'sin',
                          'y',
                          'del'
                        };
                        final words = q
                            .split(' ')
                            .where(
                                (w) => w.length > 2 && !stopWords.contains(w))
                            .toList();
                        if (words.isEmpty) words.add(q);

                        bool match(String source) {
                          if (source.isEmpty) return false;
                          final sourceWords = source.split(' ');
                          return words.any((w) => sourceWords.contains(w)) ||
                              sourceWords.any((sw) => words.contains(sw));
                        }

                        return match(name) || syns.any((s) => match(s));
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _ingSearchCtrl,
                            focusNode: _ingFocus,
                            onChanged: (v) => setInternalState(() {}),
                            decoration: InputDecoration(
                              labelText: _selectedIngredienteNombre ??
                                  "Seleccionar ingrediente original",
                              hintText: "Ej: Pollo, papa, leche...",
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _ingSearchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _ingSearchCtrl.clear();
                                        setInternalState(() {});
                                      })
                                  : (_selectedIngredienteId != null
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.green)
                                      : null),
                            ),
                          ),
                          if (_ingFocus.hasFocus ||
                              _ingSearchCtrl.text.isNotEmpty)
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10)
                                  ]),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount:
                                    matches.length > 50 ? 50 : matches.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = matches[i];
                                  final isSel =
                                      _selectedIngredienteId == item['id'];
                                  return ListTile(
                                    dense: true,
                                    title: Text(item['nombre'] ?? "",
                                        style: TextStyle(
                                            fontWeight: isSel
                                                ? FontWeight.bold
                                                : FontWeight.normal)),
                                    trailing: isSel
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.green, size: 18)
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedIngredienteId =
                                            (item['id'] as num).toInt();
                                        _selectedIngredienteNombre =
                                            item['nombre'];
                                        _ingSearchCtrl.clear();
                                        _ingFocus.unfocus();
                                      });
                                      setInternalState(() {});
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
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
