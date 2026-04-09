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
  Map<String, dynamic>? _selectedTutor;
  Map<String, dynamic>? _selectedPaciente;
  int? _selectedParentesco;
  bool _esPrincipal = true;

  List<Map<String, dynamic>> _parentescos = [];
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

  Future<Iterable<Map<String, dynamic>>> _searchPacientes(String query) async {
    try {
      final response = await Supabase.instance.client
          .schema("usuarios")
          .from("paciente")
          .select("id, nombre_completo")
          .ilike("nombre_completo", "%$query%")
          .limit(10);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return const Iterable<Map<String, dynamic>>.empty();
    }
  }

  Future<void> _vincular() async {
    final idTutor = _selectedTutor?["id"]?.toString();
    final idPaciente = _selectedPaciente?["id"]?.toString();

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
        _selectedTutor = null;
        _selectedPaciente = null;
        _selectedParentesco = null;
        _esPrincipal = true;
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
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        _buildTutorAutocomplete(),
        const SizedBox(height: 12),
        _buildPacienteAutocomplete(),
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

  Widget _buildTutorAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option["nombre_completo"]?.toString() ?? "",
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        return _searchTutors(textEditingValue.text);
      },
      onSelected: (selection) {
        setState(() => _selectedTutor = selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: "Buscar Tutor (Nombre o Cédula)",
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) {
            if (_selectedTutor != null) {
              setState(() => _selectedTutor = null);
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 380),
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
    );
  }

  Widget _buildPacienteAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option["nombre_completo"]?.toString() ?? "",
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        return _searchPacientes(textEditingValue.text);
      },
      onSelected: (selection) {
        setState(() => _selectedPaciente = selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: "Buscar Paciente (Nombre)",
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) {
            if (_selectedPaciente != null) {
              setState(() => _selectedPaciente = null);
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 380),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option["nombre_completo"]?.toString() ?? ""),
                    subtitle: Text("ID: ${option["id"]?.toString() ?? "N/A"}"),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}