import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class CatalogoCondicionesPage extends ConsumerStatefulWidget {
  const CatalogoCondicionesPage({super.key});

  @override
  ConsumerState<CatalogoCondicionesPage> createState() => _CatalogoCondicionesPageState();
}

class _CatalogoCondicionesPageState extends ConsumerState<CatalogoCondicionesPage> {
  final _tipoCodigoController = TextEditingController();
  final _tipoNombreController = TextEditingController();
  final _condicionNombreController = TextEditingController();
  final _condicionDescripcionController = TextEditingController();
  final _filtroController = TextEditingController();

  List<Map<String, dynamic>> _tipos = [];
  List<Map<String, dynamic>> _condiciones = [];

  int? _selectedTipoCondicion;
  bool _condicionActiva = true;
  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _tipoCodigoController.dispose();
    _tipoNombreController.dispose();
    _condicionNombreController.dispose();
    _condicionDescripcionController.dispose();
    _filtroController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final tipos = await repo.fetchCatalog("heuristico", "catalogo_tipo_condicion");
      final condiciones = await repo.fetchCatalog("heuristico", "condicion");

      if (!mounted) {
        return;
      }
      setState(() {
        _tipos = tipos;
        _condiciones = condiciones;
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

  String _tipoNombreById(int? idTipo) {
    if (idTipo == null) {
      return "Sin tipo";
    }
    Map<String, dynamic>? tipo;
    for (final item in _tipos) {
      final value = item["id"];
      if (value is num && value.toInt() == idTipo) {
        tipo = item;
        break;
      }
    }
    if (tipo == null) {
      return "Tipo $idTipo";
    }
    return tipo["nombre"]?.toString() ?? "Tipo $idTipo";
  }

  Future<void> _crearTipo() async {
    final codigo = _tipoCodigoController.text.trim();
    final nombre = _tipoNombreController.text.trim();

    if (codigo.isEmpty || nombre.isEmpty) {
      setState(() => _error = "Código y nombre son obligatorios para crear tipo de condición.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.createConditionType(codigo: codigo, nombre: nombre);
      _tipoCodigoController.clear();
      _tipoNombreController.clear();
      await _loadData();
      if (!mounted) {
        return;
      }
      setState(() => _resultado = "Tipo de condición creado correctamente.");
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

  Future<void> _crearCondicion() async {
    final nombre = _condicionNombreController.text.trim();
    if (nombre.isEmpty || _selectedTipoCondicion == null) {
      setState(() => _error = "Nombre y tipo son obligatorios para crear la condición.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.createCondition(
        nombre: nombre,
        idTipoCondicion: _selectedTipoCondicion!,
        descripcion: _condicionDescripcionController.text.trim().isEmpty
            ? null
            : _condicionDescripcionController.text.trim(),
        activa: _condicionActiva,
      );
      _condicionNombreController.clear();
      _condicionDescripcionController.clear();
      _selectedTipoCondicion = null;
      _condicionActiva = true;
      await _loadData();
      if (!mounted) {
        return;
      }
      setState(() => _resultado = "Condición creada correctamente.");
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

  Future<void> _editarTipo(Map<String, dynamic> tipo) async {
    final idTipo = (tipo["id"] as num?)?.toInt();
    if (idTipo == null) {
      return;
    }

    final codigoController = TextEditingController(text: tipo["codigo"]?.toString() ?? "");
    final nombreController = TextEditingController(text: tipo["nombre"]?.toString() ?? "");

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar tipo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codigoController,
              decoration: const InputDecoration(labelText: "Código"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );

    if (updated != true) {
      return;
    }

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.updateConditionType(
        idTipoCondicion: idTipo,
        codigo: codigoController.text.trim(),
        nombre: nombreController.text.trim(),
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      setState(() => _resultado = "Tipo actualizado correctamente.");
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  Future<void> _editarCondicion(Map<String, dynamic> condicion) async {
    final idCondicion = (condicion["id"] as num?)?.toInt();
    if (idCondicion == null) {
      return;
    }

    final nombreController = TextEditingController(text: condicion["nombre"]?.toString() ?? "");
    final descripcionController = TextEditingController(text: condicion["descripcion"]?.toString() ?? "");
    int? idTipo = (condicion["id_tipo_condicion"] as num?)?.toInt();
    bool activa = condicion["activa"] == true;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Editar condición"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: "Nombre"),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: idTipo,
                  decoration: const InputDecoration(labelText: "Tipo"),
                  items: _tipos
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: (t["id"] as num).toInt(),
                          child: Text(t["nombre"]?.toString() ?? "Tipo"),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => idTipo = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descripcionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: "Descripción"),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: activa,
                  onChanged: (value) => setDialogState(() => activa = value),
                  title: const Text("Activa"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );

    if (updated != true) {
      return;
    }

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.updateCondition(
        idCondicion: idCondicion,
        nombre: nombreController.text.trim(),
        idTipoCondicion: idTipo,
        descripcion: descripcionController.text.trim(),
        activa: activa,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      setState(() => _resultado = "Condición actualizada correctamente.");
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  Future<void> _toggleCondicionActiva(Map<String, dynamic> condicion, bool activa) async {
    final idCondicion = (condicion["id"] as num).toInt();

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.updateCondition(idCondicion: idCondicion, activa: activa);
      await _loadData();
      if (!mounted) {
        return;
      }
      setState(() => _resultado = "Estado de la condición actualizado.");
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  List<Map<String, dynamic>> get _condicionesFiltradas {
    final query = _filtroController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _condiciones;
    }

    return _condiciones.where((c) {
      final nombre = c["nombre"]?.toString().toLowerCase() ?? "";
      final descripcion = c["descripcion"]?.toString().toLowerCase() ?? "";
      return nombre.contains(query) || descripcion.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Catálogo de Condiciones",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tipos de condición", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                TextField(
                  controller: _tipoCodigoController,
                  decoration: const InputDecoration(labelText: "Código (ej. CLINICA, TEMPORAL, NUTRICIONAL)"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tipoNombreController,
                  decoration: const InputDecoration(labelText: "Nombre visible"),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _loading ? null : _crearTipo,
                  icon: const Icon(Icons.add),
                  label: const Text("Crear tipo"),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Condiciones", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                TextField(
                  controller: _condicionNombreController,
                  decoration: const InputDecoration(labelText: "Nombre de condición"),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _selectedTipoCondicion,
                  decoration: const InputDecoration(labelText: "Tipo de condición"),
                  items: _tipos
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: (t["id"] as num).toInt(),
                          child: Text("${t["nombre"] ?? ""} (${t["codigo"] ?? ""})"),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedTipoCondicion = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _condicionDescripcionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: "Descripción (opcional)"),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _condicionActiva,
                  onChanged: (value) => setState(() => _condicionActiva = value),
                  title: const Text("Activa"),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _crearCondicion,
                  icon: const Icon(Icons.add),
                  label: const Text("Crear condición"),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tipos existentes", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_tipos.isEmpty) const Text("No hay tipos registrados."),
                ..._tipos.map(
                  (tipo) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(tipo["nombre"]?.toString() ?? "Tipo"),
                    subtitle: Text("Código: ${tipo["codigo"] ?? "-"}"),
                    trailing: IconButton(
                      onPressed: () => _editarTipo(tipo),
                      icon: const Icon(Icons.edit),
                      tooltip: "Editar tipo",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _filtroController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: "Filtrar condiciones por nombre o descripción",
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const LinearProgressIndicator(),
        const SizedBox(height: 8),
        ..._condicionesFiltradas.map(
          (condicion) {
            final idTipo = (condicion["id_tipo_condicion"] as num?)?.toInt();
            final activa = condicion["activa"] == true;
            return Card(
              child: ListTile(
                title: Text(condicion["nombre"]?.toString() ?? "Condición"),
                subtitle: Text(
                  "Tipo: ${_tipoNombreById(idTipo)}\n${condicion["descripcion"]?.toString() ?? "Sin descripción"}",
                ),
                isThreeLine: true,
                trailing: Switch(
                  value: activa,
                  onChanged: (value) => _toggleCondicionActiva(condicion, value),
                ),
                onTap: () => _editarCondicion(condicion),
              ),
            );
          },
        ),
        if (_condicionesFiltradas.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text("No hay condiciones que mostrar."),
          ),
        if (_resultado != null) ...[
          const SizedBox(height: 10),
          Text(
            _resultado!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      ],
    );
  }
}
