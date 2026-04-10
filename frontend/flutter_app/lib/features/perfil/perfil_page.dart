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

  Widget _profileField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE9F4FD),
                    Color(0xFFF5FAFF),
                    Color(0xFFEFFAF8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1D6AA7), Color(0xFF0D9488)],
                      ),
                    ),
                    child: const Icon(Icons.badge_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Mi Perfil Profesional",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Actualiza tus datos de contacto e identificacion.",
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Chip(
                  avatar: const Icon(Icons.verified_user, size: 18),
                  label: Text("Rol: ${_role.isEmpty ? "No definido" : _role}"),
                ),
                Chip(
                  avatar: Icon(_activo ? Icons.check_circle : Icons.block, size: 18),
                  label: Text("Estado: ${_activo ? "Activo" : "Inactivo"}"),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (isWide)
                      Row(
                        children: [
                          Expanded(
                            child: _profileField(
                              controller: _nombreController,
                              label: "Nombre completo",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _profileField(
                              controller: _emailController,
                              label: "Email",
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _profileField(
                        controller: _nombreController,
                        label: "Nombre completo",
                      ),
                      const SizedBox(height: 12),
                      _profileField(
                        controller: _emailController,
                        label: "Email",
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (isWide)
                      Row(
                        children: [
                          Expanded(
                            child: _profileField(
                              controller: _cedulaController,
                              label: "Cedula",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _profileField(
                              controller: _telefonoController,
                              label: "Telefono",
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _profileField(
                        controller: _cedulaController,
                        label: "Cedula",
                      ),
                      const SizedBox(height: 12),
                      _profileField(
                        controller: _telefonoController,
                        label: "Telefono",
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _profileField(
                      controller: _direccionController,
                      label: "Direccion",
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
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
      },
    );
  }
}
