import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

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
      length: 2,
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
              Tab(icon: Icon(Icons.person_add_alt_1), text: "Registrar Tutor"),
              Tab(icon: Icon(Icons.child_care), text: "Registrar Paciente"),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _FormRegistroTutor(),
                _FormRegistroPaciente(),
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
  final _pacienteController = TextEditingController();
  final _parentescoController = TextEditingController();
  bool _esPrincipal = true;

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _pacienteController.dispose();
    _parentescoController.dispose();
    super.dispose();
  }

  Future<void> _registrarTutor() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final idPaciente = _pacienteController.text.trim();
    final idParentesco = int.tryParse(_parentescoController.text.trim());

    if (email.isEmpty || name.isEmpty || idPaciente.isEmpty) {
      setState(() => _error = "El email, nombre e ID de paciente son obligatorios");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);

      await repo.registerTutor(
        email: email,
        nombreCompleto: name,
        idPaciente: idPaciente,
        idParentesco: idParentesco,
        esPrincipal: _esPrincipal,
      );

      if (!mounted) return;

      setState(() {
        _resultado = "El usuario tutor fue registrado y vinculado correctamente.";
        _emailController.clear();
        _nameController.clear();
        _pacienteController.clear();
        _parentescoController.clear();
        _esPrincipal = true;
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
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text("Es el tutor principal"),
          value: _esPrincipal,
          onChanged: (val) => setState(() => _esPrincipal = val),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _registrarTutor,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text("Registrar y Vincular Tutor"),
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

  Map<String, dynamic>? _selectedTutor;
  int? _selectedSexo;
  int? _selectedProvincia;
  int? _selectedParentesco;

  List<Map<String, dynamic>> _sexos = [];
  List<Map<String, dynamic>> _provincias = [];
  List<Map<String, dynamic>> _parentescos = [];

  bool _esPrincipal = true;
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
      final parentescos = await repo.fetchCatalog("usuarios", "parentesco");
      if (mounted) {
        setState(() {
          _sexos = sexos;
          _provincias = provincias;
          _parentescos = parentescos;
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

  Future<Iterable<Map<String, dynamic>>> _searchTutors(String query) async {
    try {
      final response = await Supabase.instance.client
          .schema("usuarios")
          .from("usuario")
          .select("id, nombre_completo, cedula")
          .or("nombre_completo.ilike.%$query%,cedula.ilike.%$query%")
          .limit(10);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return const Iterable<Map<String, dynamic>>.empty();
    }
  }

  Future<void> _registrarPaciente() async {
    final name = _nameController.text.trim();
    final idTutor = _selectedTutor?["id"]?.toString();

    if (name.isEmpty || _fechaNacimiento == null || _selectedSexo == null || idTutor == null || idTutor.isEmpty) {
      setState(() => _error = "Nombre, fecha de nacimiento, sexo e ID del tutor son obligatorios.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.registerPatientAndLinkTutor(
        nombreCompleto: name,
        fechaNacimiento: _fechaNacimiento!,
        idSexo: _selectedSexo!,
        idProvincia: _selectedProvincia,
        idUsuarioTutor: idTutor,
        idParentesco: _selectedParentesco,
        esPrincipal: _esPrincipal,
      );

      if (!mounted) return;

      setState(() {
        _resultado = "El paciente fue registrado y vinculado correctamente al tutor.";
        _nameController.clear();
        _fechaNacimientoController.clear();
        _fechaNacimiento = null;
        _selectedSexo = null;
        _selectedProvincia = null;
        _selectedParentesco = null;
        _selectedTutor = null;
        _esPrincipal = true;
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
          value: _selectedSexo,
          decoration: const InputDecoration(labelText: "Sexo"),
          items: _sexos.map((s) => DropdownMenuItem<int>(
            value: s["id"] as int,
            child: Text(s["descripcion"]?.toString() ?? s["codigo"]?.toString() ?? ""),
          )).toList(),
          onChanged: (val) => setState(() => _selectedSexo = val),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _selectedProvincia,
          decoration: const InputDecoration(labelText: "Provincia (Opcional)"),
          items: _provincias.map((p) => DropdownMenuItem<int>(
            value: p["id"] as int,
            child: Text(p["nombre"]?.toString() ?? ""),
          )).toList(),
          onChanged: (val) => setState(() => _selectedProvincia = val),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (option) => option["nombre_completo"]?.toString() ?? "",
          optionsBuilder: (textEditingValue) async {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Map<String, dynamic>>.empty();
            }
            return await _searchTutors(textEditingValue.text);
          },
          onSelected: (selection) {
            setState(() => _selectedTutor = selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (val) {
                // Limpiar la seleccion si el usuario edita el texto
                if (_selectedTutor != null && val != _selectedTutor?["nombre_completo"]) {
                  setState(() => _selectedTutor = null);
                }
              },
              decoration: const InputDecoration(
                labelText: "Buscar Tutor a vincular (Nombre o Cédula)",
                prefixIcon: Icon(Icons.search),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250, maxWidth: 350),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        title: Text(option["nombre_completo"]?.toString() ?? ""),
                        subtitle: Text("Cédula: ${option["cedula"]?.toString() ?? "N/A"}"),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _selectedParentesco,
          decoration: const InputDecoration(labelText: "Parentesco (Opcional)"),
          items: _parentescos.map((p) => DropdownMenuItem<int>(
            value: p["id"] as int,
            child: Text(p["nombre"]?.toString() ?? ""),
          )).toList(),
          onChanged: (val) => setState(() => _selectedParentesco = val),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text("Tutor es principal para este paciente"),
          value: _esPrincipal,
          onChanged: (val) => setState(() => _esPrincipal = val),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _registrarPaciente,
          icon: const Icon(Icons.child_care),
          label: const Text("Registrar y Vincular Paciente"),
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