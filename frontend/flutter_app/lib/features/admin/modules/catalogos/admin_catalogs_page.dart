import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class AdminCatalogsPage extends ConsumerStatefulWidget {
  const AdminCatalogsPage({super.key});

  @override
  ConsumerState<AdminCatalogsPage> createState() => _AdminCatalogsPageState();
}

class _AdminCatalogsPageState extends ConsumerState<AdminCatalogsPage> {
  static const _catalogs = [
    ("dom_identidad_catalogos", "rol"),
    ("dom_identidad_catalogos", "catalogo_sexo"),
    ("dom_reglas_catalogos", "catalogo_accion"),
    ("dom_reglas_catalogos", "catalogo_objetivo_regla"),
    ("dom_planes_catalogos_estado", "catalogo_estado_plan"),
    ("dom_planes_catalogos_tipo", "catalogo_tipo_plan"),
    ("dom_planes_catalogos_tipo", "catalogo_origen_plan"),
    ("dom_planes_catalogos_estado", "catalogo_estado_consumo"),
  ];

  String _schema = _catalogs.first.$1;
  String _table = _catalogs.first.$2;

  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCatalog);
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final rows = await repo.fetchCatalog(_schema, _table);
      if (!mounted) {
        return;
      }
      setState(() => _rows = rows);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Catalogos", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<String>(
                initialValue: "$_schema.$_table",
                decoration: const InputDecoration(
                  labelText: "Catalogo",
                ),
                items: [
                  for (final item in _catalogs)
                    DropdownMenuItem(
                      value: "${item.$1}.${item.$2}",
                      child: Text("${item.$1}.${item.$2}"),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  final parts = value.split(".");
                  setState(() {
                    _schema = parts[0];
                    _table = parts[1];
                  });
                  _loadCatalog();
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadCatalog,
              icon: const Icon(Icons.refresh),
              label: const Text("Recargar"),
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
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    return Card(
                      child: ListTile(
                        title: Text(row.toString()),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

