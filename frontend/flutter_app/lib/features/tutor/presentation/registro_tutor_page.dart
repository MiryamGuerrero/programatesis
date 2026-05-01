import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class RegistroTutorPage extends ConsumerStatefulWidget {
  const RegistroTutorPage({super.key});

  @override
  ConsumerState<RegistroTutorPage> createState() => _RegistroTutorPageState();
}

class _RegistroTutorPageState extends ConsumerState<RegistroTutorPage> {
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

      // 1. Registrar tutor (Si ya existe, el backend lo manejará)
      await repo.registerTutor(
        email: email,
        nombreCompleto: name,
      );
      
      // 2. Vincular con paciente
      await repo.linkTutorToPatient(
        idUsuarioTutor: email, // El backend suele usar email o cedula como lookup si no tiene UUID aun
        idPaciente: idPaciente,
        idParentesco: idParentesco ?? 1,
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
      children: [
        Text(
          "Registro de Tutores",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _text(_emailController, "Correo electrónico", email: true),
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

  Widget _text(TextEditingController controller, String label, {bool number = false, bool email = false}) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : (email ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      ),
      style: TextStyle(fontSize: 16),
    );
  }
}
