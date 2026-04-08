import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();

  bool _loading = false;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  int? _selectedRoleId;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadUsers);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? "");
  }

  String _roleNameById(dynamic roleValue) {
    final roleId = _asInt(roleValue);
    if (roleId == null) {
      return "Sin rol";
    }

    for (final role in _roles) {
      final id = _asInt(role["id"]);
      if (id != roleId) {
        continue;
      }

      final nombre = role["nombre"]?.toString().trim();
      if (nombre != null && nombre.isNotEmpty) {
        return nombre;
      }
    }

    return "Rol $roleId";
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final usersFuture = repo.fetchUsers();
      final rolesFuture = repo.fetchCatalog("usuarios", "rol");

      final users = await usersFuture;
      final roles = await rolesFuture;

      if (!mounted) {
        return;
      }

      final availableRoleIds = roles
          .map((role) => _asInt(role["id"]))
          .whereType<int>()
          .toSet();

      var selectedRoleId = _selectedRoleId;
      if (selectedRoleId == null || !availableRoleIds.contains(selectedRoleId)) {
        selectedRoleId = availableRoleIds.isEmpty ? null : availableRoleIds.first;
      }

      setState(() {
        _users = users;
        _roles = roles;
        _selectedRoleId = selectedRoleId;
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

  Future<void> _createUser() async {
    final idRol = _selectedRoleId;
    if (idRol == null) {
      setState(() => _error = "Debes seleccionar un rol");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.createUser(
        email: _emailController.text.trim(),
        nombreCompleto: _nameController.text.trim(),
        idRol: idRol,
      );
      _emailController.clear();
      _nameController.clear();
      await _loadUsers();
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

  Future<void> _updateUser(String userId, String email, String nombre, int? idRol, bool activo) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      // Nota: Asume que agregarás el método updateUser a tu repositorio Flutter haciendo el llamado PUT
      await repo.updateUser(
        userId: userId,
        email: email,
        nombreCompleto: nombre,
        idRol: idRol,
        activo: activo,
      );
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    final editEmailController = TextEditingController(text: user["email"]?.toString() ?? "");
    final editNameController = TextEditingController(text: user["nombre_completo"]?.toString() ?? "");
    int? editSelectedRoleId = _asInt(user["id_rol"]);
    bool editActivo = user["activo"] == true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Editar usuario"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editEmailController,
                      decoration: const InputDecoration(labelText: "Email"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editNameController,
                      decoration: const InputDecoration(labelText: "Nombre completo"),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: editSelectedRoleId,
                      decoration: const InputDecoration(labelText: "Rol"),
                      items: [
                        for (final role in _roles)
                          if (_asInt(role["id"]) != null)
                            DropdownMenuItem<int>(
                              value: _asInt(role["id"]),
                              child: Text(
                                "${role["nombre"] ?? "Rol"} (${role["id"] ?? "-"})",
                              ),
                            ),
                      ],
                      onChanged: (value) {
                        setStateDialog(() => editSelectedRoleId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text("Activo"),
                      value: editActivo,
                      onChanged: (value) => setStateDialog(() => editActivo = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateUser(
                      user["id"].toString(),
                      editEmailController.text.trim(),
                      editNameController.text.trim(),
                      editSelectedRoleId,
                      editActivo,
                    );
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gestion de usuarios",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                ),
              ),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nombre completo",
                ),
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                initialValue: _selectedRoleId,
                decoration: const InputDecoration(
                  labelText: "Rol",
                ),
                items: [
                  for (final role in _roles)
                    if (_asInt(role["id"]) != null)
                      DropdownMenuItem<int>(
                        value: _asInt(role["id"]),
                        child: Text(
                          "${role["nombre"] ?? "Rol"} (${role["id"] ?? "-"})",
                        ),
                      ),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _selectedRoleId = value);
                      },
              ),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _createUser,
              icon: const Icon(Icons.add),
              label: const Text("Crear"),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadUsers,
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
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      child: ListTile(
                        title: Text(user["nombre_completo"]?.toString() ??
                            "Sin nombre"),
                        subtitle: Text(user["email"]?.toString() ?? ""),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_roleNameById(user["id_rol"])),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showEditDialog(user),
                            ),
                          ],
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
