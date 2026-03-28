import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/state/app_providers.dart";

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _rolController = TextEditingController(text: "1");

  bool _loading = false;
  List<Map<String, dynamic>> _users = [];
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
    _rolController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final users = await repo.fetchUsers();
      if (!mounted) {
        return;
      }
      setState(() => _users = users);
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
    final idRol = int.tryParse(_rolController.text.trim());
    if (idRol == null) {
      setState(() => _error = "id_rol debe ser numerico");
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
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nombre completo",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _rolController,
                decoration: const InputDecoration(
                  labelText: "id_rol",
                  border: OutlineInputBorder(),
                ),
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
          Text(_error!, style: const TextStyle(color: Colors.red)),
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
                        title: Text(user["nombre_completo"]?.toString() ?? "Sin nombre"),
                        subtitle: Text(user["email"]?.toString() ?? ""),
                        trailing: Text("rol: ${user["id_rol"] ?? "-"}"),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
