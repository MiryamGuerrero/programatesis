import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class GestionTutoresPacientesPage extends ConsumerStatefulWidget {
  const GestionTutoresPacientesPage({super.key});

  @override
  ConsumerState<GestionTutoresPacientesPage> createState() => _GestionTutoresPacientesPageState();
}

class _GestionTutoresPacientesPageState extends ConsumerState<GestionTutoresPacientesPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tutores y Pacientes",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person_add_alt_1), text: "Tutor"),
              Tab(icon: Icon(Icons.child_care), text: "Paciente"),
              Tab(icon: Icon(Icons.link), text: "Vincular"),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _FormRegistroTutor(),
                _FormRegistroPaciente(),
                _FormVincularTutorPaciente(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormRegistroTutor extends ConsumerStatefulWidget {
  const _FormRegistroTutor();

  @override
  ConsumerState<_FormRegistroTutor> createState() => _FormRegistroTutorState();
}

class _FormRegistroTutorState extends ConsumerState<_FormRegistroTutor> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _registrarTutor() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || name.isEmpty) {
      setState(() => _error = "El email y el nombre son obligatorios");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);

      await repo.registerTutorOnly(
        email: email,
        nombreCompleto: name,
      );

      if (!mounted) return;

      setState(() {
        _resultado = "Tutor registrado correctamente. Ahora puedes vincularlo con uno o varios pacientes.";
        _emailController.clear();
        _nameController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        _text(_emailController, "Correo electrónico del tutor", email: true),
        const SizedBox(height: 12),
        _text(_nameController, "Nombre completo"),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _registrarTutor,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text("Registrar Tutor"),
        ),
        if (_resultado != null) ...[
          const SizedBox(height: 12),
          Text(_resultado!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  Widget _text(TextEditingController controller, String label, {bool number = false, bool email = false}) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : (email ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _FormRegistroPaciente extends ConsumerStatefulWidget {
  const _FormRegistroPaciente();

  @override
  ConsumerState<_FormRegistroPaciente> createState() => _FormRegistroPacienteState();
}

class _FormRegistroPacienteState extends ConsumerState<_FormRegistroPaciente> {
  final _nameController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();

  int? _selectedSexo;
  int? _selectedProvincia;

  List<Map<String, dynamic>> _sexos = [];
  List<Map<String, dynamic>> _provincias = [];

  DateTime? _fechaNacimiento;

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCatalogs);
  }

  Future<void> _loadCatalogs() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final sexos = await repo.fetchCatalog("usuarios", "catalogo_sexo");
      final provincias = await repo.fetchCatalog("usuarios", "provincia");
      if (mounted) {
        setState(() {
          _sexos = sexos;
          _provincias = provincias;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar catalogos: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fechaNacimientoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _fechaNacimiento = date;
        _fechaNacimientoController.text = date.toIso8601String().split("T").first;
      });
    }
  }

  Future<void> _registrarPaciente() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _fechaNacimiento == null || _selectedSexo == null) {
      setState(() => _error = "Nombre, fecha de nacimiento y sexo son obligatorios.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.registerPatientOnly(
        nombreCompleto: name,
        fechaNacimiento: _fechaNacimiento!,
        idSexo: _selectedSexo!,
        idProvincia: _selectedProvincia,
      );

      if (!mounted) return;

      setState(() {
        _resultado = "Paciente registrado correctamente. Ahora debes vincularlo a un tutor en la pestaña Vincular.";
        _nameController.clear();
        _fechaNacimientoController.clear();
        _fechaNacimiento = null;
        _selectedSexo = null;
        _selectedProvincia = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        _text(_nameController, "Nombre completo del paciente"),
        const SizedBox(height: 12),
        TextField(
          controller: _fechaNacimientoController,
          readOnly: true,
          onTap: _pickDate,
          decoration: const InputDecoration(
            labelText: "Fecha de nacimiento",
            prefixIcon: Icon(Icons.calendar_month),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _selectedSexo,
          decoration: const InputDecoration(labelText: "Sexo"),
          items: _sexos.map((s) => DropdownMenuItem<int>(
            value: s["id"] as int,
            child: Text(s["descripcion"]?.toString() ?? s["codigo"]?.toString() ?? ""),
          )).toList(),
          onChanged: (val) => setState(() => _selectedSexo = val),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _selectedProvincia,
          decoration: const InputDecoration(labelText: "Provincia (Opcional)"),
          items: _provincias.map((p) => DropdownMenuItem<int>(
            value: p["id"] as int,
            child: Text(p["nombre"]?.toString() ?? ""),
          )).toList(),
          onChanged: (val) => setState(() => _selectedProvincia = val),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _registrarPaciente,
          icon: const Icon(Icons.child_care),
          label: const Text("Registrar Paciente"),
        ),
        if (_resultado != null) ...[
          const SizedBox(height: 12),
          Text(_resultado!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  Widget _text(TextEditingController controller, String label, {bool number = false}) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _FormVincularTutorPaciente extends ConsumerStatefulWidget {
  const _FormVincularTutorPaciente();

  @override
  ConsumerState<_FormVincularTutorPaciente> createState() => _FormVincularTutorPacienteState();
}

class _FormVincularTutorPacienteState extends ConsumerState<_FormVincularTutorPaciente> {
  final _tutorSearchController = TextEditingController();
  final _pacienteSearchController = TextEditingController();

  List<Map<String, dynamic>> _tutoresEncontrados = [];
  List<Map<String, dynamic>> _pacientesEncontrados = [];

  String? _selectedTutorId;
  String? _selectedPacienteId;
  int? _selectedParentesco;
  bool _esPrincipal = true;

  List<Map<String, dynamic>> _parentescos = [];
  List<Map<String, dynamic>> _vinculos = [];
  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _tutorSearchController.dispose();
    _pacienteSearchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadCatalogs();
    await _loadVinculos();
  }

  Future<void> _loadCatalogs() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final parentescos = await repo.fetchCatalog("usuarios", "parentesco");
      if (!mounted) {
        return;
      }
      setState(() => _parentescos = parentescos);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  Future<void> _loadVinculos() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final vinculos = await repo.fetchTutorPatientLinks();
      if (!mounted) {
        return;
      }
      setState(() => _vinculos = vinculos);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  Future<List<Map<String, dynamic>>> _searchTutors(String query) async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      return repo.searchTutors(query: query, limit: 10);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchPacientes(String query) async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      return repo.searchPatients(query: query, limit: 10);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _buscarTutores() async {
    final query = _tutorSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _tutoresEncontrados = [];
        _selectedTutorId = null;
      });
      return;
    }

    final rows = await _searchTutors(query);
    if (!mounted) {
      return;
    }

    setState(() {
      _tutoresEncontrados = rows;
      _selectedTutorId = rows.isEmpty ? null : rows.first["id"]?.toString();
    });
  }

  Future<void> _buscarPacientes() async {
    final query = _pacienteSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _pacientesEncontrados = [];
        _selectedPacienteId = null;
      });
      return;
    }

    final rows = await _searchPacientes(query);
    if (!mounted) {
      return;
    }

    setState(() {
      _pacientesEncontrados = rows;
      _selectedPacienteId = rows.isEmpty ? null : rows.first["id"]?.toString();
    });
  }

  Future<void> _vincular() async {
    final idTutor = _selectedTutorId;
    final idPaciente = _selectedPacienteId;

    if (idTutor == null || idTutor.isEmpty || idPaciente == null || idPaciente.isEmpty) {
      setState(() => _error = "Debes seleccionar tutor y paciente.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.linkTutorToPatient(
        idUsuarioTutor: idTutor,
        idPaciente: idPaciente,
        idParentesco: _selectedParentesco,
        esPrincipal: _esPrincipal,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _resultado = "Tutor y paciente vinculados correctamente.";
        _tutorSearchController.clear();
        _pacienteSearchController.clear();
        _tutoresEncontrados = [];
        _pacientesEncontrados = [];
        _selectedTutorId = null;
        _selectedPacienteId = null;
        _selectedParentesco = null;
        _esPrincipal = true;
      });

      await _loadVinculos();
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

  Future<void> _editarVinculo(Map<String, dynamic> vinculo) async {
    int? parentesco = vinculo["id_parentesco"] as int?;
    bool esPrincipal = vinculo["es_principal"] == true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Editar vínculo"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: parentesco,
                    decoration: const InputDecoration(labelText: "Parentesco"),
                    items: _parentescos
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p["id"] as int,
                            child: Text(p["nombre"]?.toString() ?? ""),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setDialogState(() => parentesco = val),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: esPrincipal,
                    onChanged: (val) => setDialogState(() => esPrincipal = val),
                    title: const Text("Tutor principal"),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                FilledButton(
                  onPressed: () async {
                    final idVinculo = vinculo["id"] as int;
                    final repo = ref.read(supabaseCrudRepositoryProvider);
                    await repo.updateTutorPatientLink(
                      idVinculo: idVinculo,
                      idParentesco: parentesco,
                      esPrincipal: esPrincipal,
                    );
                    if (!mounted) {
                      return;
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    setState(() => _resultado = "Vínculo actualizado correctamente.");
                    await _loadVinculos();
                  },
                  child: const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _desvincular(Map<String, dynamic> vinculo) async {
    final idVinculo = vinculo["id"] as int;
    final repo = ref.read(supabaseCrudRepositoryProvider);
    await repo.unlinkTutorPatient(idVinculo: idVinculo);
    if (mounted) {
      setState(() => _resultado = "Vínculo eliminado correctamente.");
    }
    await _loadVinculos();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        _buildTutorSelector(),
        const SizedBox(height: 12),
        _buildPacienteSelector(),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _selectedParentesco,
          decoration: const InputDecoration(labelText: "Parentesco (Opcional)"),
          items: _parentescos
              .map(
                (p) => DropdownMenuItem<int>(
                  value: p["id"] as int,
                  child: Text(p["nombre"]?.toString() ?? ""),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedParentesco = val),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text("Tutor principal para este paciente"),
          value: _esPrincipal,
          onChanged: (val) => setState(() => _esPrincipal = val),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _vincular,
          icon: const Icon(Icons.link),
          label: const Text("Vincular Tutor y Paciente"),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              "Vínculos registrados",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadVinculos,
              icon: const Icon(Icons.refresh),
              tooltip: "Recargar vínculos",
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._vinculos.map(_buildVinculoCard),
        if (_vinculos.isEmpty)
          const Text("No hay vínculos activos registrados."),
        if (_resultado != null) ...[
          const SizedBox(height: 12),
          Text(
            _resultado!,
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

  Widget _buildTutorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tutorSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscarTutores(),
                decoration: const InputDecoration(
                  labelText: "Buscar tutor por nombre o cédula",
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _buscarTutores,
              child: const Text("Buscar"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedTutorId,
          decoration: const InputDecoration(labelText: "Seleccionar tutor"),
          items: _tutoresEncontrados
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t["id"]?.toString(),
                  child: Text(
                    "${t["nombre_completo"] ?? ""} - Cédula: ${t["cedula"] ?? "N/A"}",
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedTutorId = value),
        ),
      ],
    );
  }

  Widget _buildPacienteSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pacienteSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscarPacientes(),
                decoration: const InputDecoration(
                  labelText: "Buscar paciente por nombre",
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _buscarPacientes,
              child: const Text("Buscar"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedPacienteId,
          decoration: const InputDecoration(labelText: "Seleccionar paciente"),
          items: _pacientesEncontrados
              .map(
                (p) => DropdownMenuItem<String>(
                  value: p["id"]?.toString(),
                  child: Text("${p["nombre_completo"] ?? ""} - ID: ${p["id"] ?? "N/A"}"),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedPacienteId = value),
        ),
      ],
    );
  }

  Widget _buildVinculoCard(Map<String, dynamic> vinculo) {
    final parentescoNombre = vinculo["parentesco_nombre"]?.toString() ?? "Sin parentesco";
    final tutorNombre = vinculo["tutor_nombre"]?.toString() ?? "Tutor";
    final tutorCedula = vinculo["tutor_cedula"]?.toString() ?? "N/A";
    final pacienteNombre = vinculo["paciente_nombre"]?.toString() ?? "Paciente";
    final esPrincipal = vinculo["es_principal"] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tutor: $tutorNombre", style: const TextStyle(fontWeight: FontWeight.w700)),
            Text("Cédula tutor: $tutorCedula"),
            Text("Paciente: $pacienteNombre"),
            Text("Parentesco: $parentescoNombre"),
            Text("Principal: ${esPrincipal ? "Sí" : "No"}"),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _editarVinculo(vinculo),
                  icon: const Icon(Icons.edit),
                  label: const Text("Editar"),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _desvincular(vinculo),
                  icon: const Icon(Icons.link_off),
                  label: const Text("Desvincular"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}