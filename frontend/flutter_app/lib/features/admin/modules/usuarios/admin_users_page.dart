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
                        trailing: Text(_roleNameById(user["id_rol"])),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

