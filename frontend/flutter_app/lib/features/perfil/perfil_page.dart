import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/state/app_providers.dart";

class PerfilPage extends ConsumerStatefulWidget {
  const PerfilPage({super.key});

  @override
  ConsumerState<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends ConsumerState<PerfilPage> {
  final _emailController = TextEditingController();
  final _nombreController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _success;
  String _role = "";
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProfile);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nombreController.dispose();
    _cedulaController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final profile = await repo.fetchMyProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _emailController.text = profile["email"]?.toString() ?? "";
        _nombreController.text = profile["nombre_completo"]?.toString() ?? "";
        _cedulaController.text = profile["cedula"]?.toString() ?? "";
        _telefonoController.text = profile["telefono"]?.toString() ?? "";
        _direccionController.text = profile["direccion"]?.toString() ?? "";
        _role = profile["role"]?.toString() ?? "";
        _activo = profile["activo"] == true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final nombre = _nombreController.text.trim();
    final email = _emailController.text.trim();

    if (nombre.isEmpty || email.isEmpty) {
      setState(() => _error = "Nombre completo y email son obligatorios.");
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.updateMyProfile(
        nombreCompleto: nombre,
        email: email,
        cedula: _cedulaController.text,
        telefono: _telefonoController.text,
        direccion: _direccionController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _success = "Perfil actualizado correctamente.";
      });

      await _loadProfile();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Mi perfil",
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          "Actualiza tus datos personales.",
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Chip(
              avatar: const Icon(Icons.verified_user, size: 18),
              label: Text("Rol: ${_role.isEmpty ? "No definido" : _role}"),
            ),
            Chip(
              avatar: Icon(
                _activo ? Icons.check_circle : Icons.block,
                size: 18,
              ),
              label: Text("Estado: ${_activo ? "Activo" : "Inactivo"}"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nombreController,
          decoration: const InputDecoration(labelText: "Nombre completo"),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: "Email"),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cedulaController,
          decoration: const InputDecoration(labelText: "Cedula"),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telefonoController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: "Telefono"),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _direccionController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: "Direccion"),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _saving ? null : _saveProfile,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? "Guardando..." : "Guardar cambios"),
            ),
            OutlinedButton.icon(
              onPressed: _saving ? null : _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text("Recargar"),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (_success != null) ...[
          const SizedBox(height: 12),
          Text(
            _success!,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
