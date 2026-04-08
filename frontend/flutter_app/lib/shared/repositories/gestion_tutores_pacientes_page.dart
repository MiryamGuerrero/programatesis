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
        _text(_pacienteController, "ID del Paciente a vincular (UUID)"),
        const SizedBox(height: 12),
        _text(_parentescoController, "ID de Parentesco (Opcional, Ej: 1)", number: true),
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
  final _sexoController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _tutorController = TextEditingController();
  final _parentescoController = TextEditingController();
  bool _esPrincipal = true;
  DateTime? _fechaNacimiento;

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _sexoController.dispose();
    _provinciaController.dispose();
    _tutorController.dispose();
    _parentescoController.dispose();
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
      setState(() => _fechaNacimiento = date);
    }
  }

  Future<void> _registrarPaciente() async {
    final name = _nameController.text.trim();
    final idSexo = int.tryParse(_sexoController.text.trim());
    final idProvincia = int.tryParse(_provinciaController.text.trim());
    final idTutor = _tutorController.text.trim();
    final idParentesco = int.tryParse(_parentescoController.text.trim());

    if (name.isEmpty || _fechaNacimiento == null || idSexo == null || idTutor.isEmpty) {
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
        idSexo: idSexo,
        idProvincia: idProvincia,
        idUsuarioTutor: idTutor,
        idParentesco: idParentesco,
        esPrincipal: _esPrincipal,
      );

      if (!mounted) return;

      setState(() {
        _resultado = "El paciente fue registrado y vinculado correctamente al tutor.";
        _nameController.clear();
        _sexoController.clear();
        _provinciaController.clear();
        _tutorController.clear();
        _parentescoController.clear();
        _fechaNacimiento = null;
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
        Row(
          children: [
            Expanded(
              child: Text(
                _fechaNacimiento == null
                    ? "Fecha de nacimiento no seleccionada"
                    : "Nacimiento: ${_fechaNacimiento!.toIso8601String().split('T').first}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: const Text("Seleccionar"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _text(_sexoController, "ID de Sexo (Ej: 1=M, 2=F)", number: true),
        const SizedBox(height: 12),
        _text(_provinciaController, "ID de Provincia (Opcional)", number: true),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),
        _text(_tutorController, "ID del Usuario Tutor (UUID) a vincular"),
        const SizedBox(height: 12),
        _text(_parentescoController, "ID de Parentesco (Opcional)", number: true),
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