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
  String? _error;

  @override
  void dispose() {
    _pacienteController.dispose();
    super.dispose();
  }

  Future<void> _cargarPlan() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final items =
          await repo.fetchPlanItemsByPaciente(_pacienteController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() => _items = items);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Mi plan", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _pacienteController,
                decoration: const InputDecoration(
                  labelText: "ID Paciente",
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _cargarPlan,
              icon: const Icon(Icons.refresh),
              label: const Text("Cargar"),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final date = DateTime.tryParse(
                        item["fecha_programada"]?.toString() ?? "");
                    return Card(
                      child: ListTile(
                        title: Text("Receta ${item["id_receta"]}"),
                        subtitle: Text(
                          "Item ${item["id"]} | ${date != null ? dateFormat.format(date) : item["fecha_programada"]}",
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

