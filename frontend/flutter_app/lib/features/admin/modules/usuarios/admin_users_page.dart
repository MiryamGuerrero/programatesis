import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _searchController = TextEditingController();

  bool _loading = false;
  bool _includeInactive = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  final Set<int> _selectedRoleIds = <int>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: Text(
          message,
          style: TextStyle(
            color: isError ? const Color(0xFF991B1B) : const Color(0xFF065F46),
            fontWeight: FontWeight.w700,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: isError ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
      ),
    );
  }

  String _humanizeError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith("Exception: ")) {
      return raw.replaceFirst("Exception: ", "");
    }
    return raw;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? "");
  }

  ({String nombres, String apellidos}) _splitNombreCompleto(String? raw) {
    final fullName = (raw ?? "").trim();
    if (fullName.isEmpty) {
      return (nombres: "", apellidos: "");
    }

    final parts = fullName.split(RegExp(r"\s+"));
    if (parts.length == 1) {
      return (nombres: parts.first, apellidos: "");
    }
    if (parts.length == 2) {
      return (nombres: parts[0], apellidos: parts[1]);
    }

    final nombres = parts.take(parts.length - 2).join(" ");
    final apellidos = parts.skip(parts.length - 2).join(" ");
    return (nombres: nombres, apellidos: apellidos);
  }

  String _buildNombreCompleto(String nombres, String apellidos) {
    final n = nombres.trim();
    final a = apellidos.trim();
    return [n, a].where((v) => v.isNotEmpty).join(" ");
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

  List<Map<String, dynamic>> _filteredUsers() {
    if (_selectedRoleIds.isEmpty) {
      return _users;
    }

    return _users.where((user) {
      final roleId = _asInt(user["id_rol"]);
      return roleId != null && _selectedRoleIds.contains(roleId);
    }).toList();
  }

  void _toggleRoleFilter(int roleId, bool selected) {
    setState(() {
      if (selected) {
        _selectedRoleIds.add(roleId);
      } else {
        _selectedRoleIds.remove(roleId);
      }
    });
  }

  List<Map<String, dynamic>> _distinctRoles() {
    final seen = <int>{};
    final output = <Map<String, dynamic>>[];

    for (final role in _roles) {
      final roleId = _asInt(role["id"]);
      if (roleId == null || seen.contains(roleId)) {
        continue;
      }
      seen.add(roleId);
      output.add(role);
    }

    return output;
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(adminAccountsRepositoryProvider);
      final results = await Future.wait<List<Map<String, dynamic>>>([
        repo.fetchUsers(
          search: _searchController.text.trim(),
          includeInactive: _includeInactive,
        ),
        repo.fetchRoles(),
      ]);
      final users = results[0];
      final roles = results[1];

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
        _roles = roles;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final msg = _humanizeError(error);
      setState(() => _error = msg);
      _snack(msg, isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveUser(_UserDraft draft, {String? userId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final nombreCompleto = _buildNombreCompleto(draft.nombres, draft.apellidos);
      final repo = ref.read(adminAccountsRepositoryProvider);

      if (userId == null) {
        await repo.createUser(
          cedula: draft.cedula,
          username: draft.username,
          email: draft.email,
          nombreCompleto: nombreCompleto,
          idRol: draft.idRol!,
        );
      } else {
        await repo.updateUser(
          userId: userId,
          cedula: draft.cedula,
          username: draft.username,
          email: draft.email,
          nombreCompleto: nombreCompleto,
          idRol: draft.idRol,
          activo: draft.activo,
        );
      }

      await _loadUsers();
      _snack(userId == null ? "Usuario creado correctamente" : "Usuario actualizado correctamente");
    } catch (error) {
      if (!mounted) {
        return;
      }
      final msg = _humanizeError(error);
      setState(() => _error = msg);
      _snack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final distinctRoles = _distinctRoles();
    final firstRoleId = distinctRoles
        .map((r) => _asInt(r["id"]))
        .whereType<int>()
        .cast<int?>()
        .firstWhere(
          (v) => v != null,
          orElse: () => null,
        );

    final payload = await showDialog<_UserDraft>(
      context: context,
      builder: (context) => _UserDialog(
        title: "Nuevo Usuario",
        submitLabel: "Guardar",
        roles: distinctRoles,
        initialValue: _UserDraft.empty(idRol: firstRoleId),
      ),
    );

    if (payload == null) {
      return;
    }

    await _saveUser(payload);
  }

  Future<void> _openEditDialog(Map<String, dynamic> user) async {
    final distinctRoles = _distinctRoles();
    final split = _splitNombreCompleto(user["nombre_completo"]?.toString());
    final payload = await showDialog<_UserDraft>(
      context: context,
      builder: (context) => _UserDialog(
        title: "Editar Usuario",
        submitLabel: "Actualizar",
        roles: distinctRoles,
        initialValue: _UserDraft(
          nombres: split.nombres,
          apellidos: split.apellidos,
          cedula: user["cedula"]?.toString() ?? "",
          email: user["email"]?.toString() ?? "",
          username: user["username"]?.toString() ?? "",
          idRol: _asInt(user["id_rol"]),
          activo: user["activo"] == true,
        ),
      ),
    );

    if (payload == null) {
      return;
    }

    await _saveUser(payload, userId: user["id"].toString());
  }

  Future<void> _openViewDialog(Map<String, dynamic> user) async {
    final split = _splitNombreCompleto(user["nombre_completo"]?.toString());
    final roleLabel = _roleNameById(user["id_rol"]);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Detalle del profesional"),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(label: "Nombres", value: split.nombres),
              _DetailLine(label: "Apellidos", value: split.apellidos),
              _DetailLine(label: "Cedula", value: user["cedula"]?.toString() ?? "-"),
              _DetailLine(label: "Correo", value: user["email"]?.toString() ?? "-"),
              _DetailLine(label: "Usuario", value: user["username"]?.toString() ?? "-"),
              _DetailLine(label: "Rol", value: roleLabel),
              _DetailLine(
                label: "Estado",
                value: user["activo"] == true ? "Activo" : "Inactivo",
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmToggle(Map<String, dynamic> user, bool nextValue) async {
    final currentActive = user["activo"] == true;
    if (currentActive == nextValue) {
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              title: Text(nextValue ? "Activar cuenta" : "Desactivar cuenta"),
              content: Text(
                nextValue
                    ? "La cuenta volvera a tener acceso al sistema."
                    : "La cuenta quedara inactiva para iniciar sesion.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancelar"),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: nextValue ? colorScheme.primary : colorScheme.error,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: Icon(nextValue ? Icons.lock_open : Icons.lock_outline),
                  label: Text(nextValue ? "Activar" : "Desactivar"),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await _toggleUserStatus(user["id"].toString(), nextValue);
  }

  Future<void> _toggleUserStatus(String userId, bool nuevoEstado) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminAccountsRepositoryProvider);
      await repo.setUserActive(
        userId: userId,
        active: nuevoEstado,
      );
      await _loadUsers();
      _snack(nuevoEstado ? "Cuenta activada" : "Cuenta desactivada");
    } catch (error) {
      if (!mounted) return;
      final msg = _humanizeError(error);
      setState(() => _error = msg);
      _snack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final visibleUsers = _filteredUsers();
        final distinctRoles = _distinctRoles();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFF4FAF9),
                    Color(0xFFFFFFFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 22,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Gestion de Personal Profesional",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Administra cuentas de admin, medico, nutricionista y tutor con auditoría.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _openCreateDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text("+ Nuevo Profesional"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: isWide ? 380 : 280,
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: "Buscar por nombre, cédula o correo",
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onSubmitted: (_) => _loadUsers(),
                          ),
                        ),
                        FilterChip(
                          label: const Text("Incluir inactivos"),
                          selected: _includeInactive,
                          onSelected: _loading
                              ? null
                              : (selected) {
                                  setState(() => _includeInactive = selected);
                                  _loadUsers();
                                },
                        ),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _loadUsers,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("Actualizar"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text("Todos los roles"),
                          selected: _selectedRoleIds.isEmpty,
                          onSelected: _loading
                              ? null
                              : (_) {
                                  setState(() => _selectedRoleIds.clear());
                                },
                        ),
                        for (final role in distinctRoles)
                          if (_asInt(role["id"]) != null)
                            FilterChip(
                              label: Text(role["nombre"]?.toString() ?? "Rol"),
                              selected: _selectedRoleIds.contains(_asInt(role["id"])),
                              onSelected: _loading
                                  ? null
                                  : (selected) =>
                                        _toggleRoleFilter(_asInt(role["id"])!, selected),
                            ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Mostrando ${visibleUsers.length} de ${_users.length} usuarios",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : visibleUsers.isEmpty
                        ? Center(
                            child: Text(
                              "No hay personal para mostrar",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                padding: const EdgeInsets.all(10),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: constraints.maxWidth - 20),
                                    child: DataTable(
                                      headingRowHeight: 54,
                                      dataRowMinHeight: 62,
                                      dataRowMaxHeight: 72,
                                      columnSpacing: 20,
                                      columns: const [
                                        DataColumn(label: Text("Nombres")),
                                        DataColumn(label: Text("Apellidos")),
                                        DataColumn(label: Text("Cédula")),
                                        DataColumn(label: Text("Correo")),
                                        DataColumn(label: Text("Rol")),
                                        DataColumn(label: Text("Estado")),
                                        DataColumn(label: Text("Acciones")),
                                      ],
                                      rows: [
                                        for (final user in visibleUsers)
                                          _buildDataRow(user),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        );
      },
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> user) {
    final split = _splitNombreCompleto(user["nombre_completo"]?.toString());

    return DataRow(
      cells: [
        DataCell(
          Text(
            split.nombres.isEmpty ? "-" : split.nombres,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(Text(split.apellidos.isEmpty ? "-" : split.apellidos)),
        DataCell(Text(user["cedula"]?.toString() ?? "")),
        DataCell(Text(user["email"]?.toString() ?? "")),
        DataCell(Text(_roleNameById(user["id_rol"]))),
        DataCell(_StatusPill(active: user["activo"] == true)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: "Editar",
                onPressed: () => _openEditDialog(user),
                icon: const Icon(Icons.edit_rounded, color: Color(0xFF64748B)),
              ),
              IconButton(
                tooltip: "Ver",
                onPressed: () => _openViewDialog(user),
                icon: const Icon(Icons.visibility_rounded, color: Color(0xFF64748B)),
              ),
              SizedBox(
                width: 56,
                child: Switch.adaptive(
                  value: user["activo"] == true,
                  activeColor: const Color(0xFF0D9488),
                  activeTrackColor: const Color(0xFFD1FAE5),
                  inactiveThumbColor: const Color(0xFF991B1B),
                  inactiveTrackColor: const Color(0xFFFEE2E2),
                  onChanged: (value) {
                    _confirmToggle(user, value);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: value.trim().isEmpty ? "-" : value,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final fg = active ? const Color(0xFF065F46) : const Color(0xFF991B1B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? "Activo" : "Inactivo",
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UserDraft {
  const _UserDraft({
    required this.nombres,
    required this.apellidos,
    required this.cedula,
    required this.email,
    required this.username,
    required this.idRol,
    required this.activo,
  });

  factory _UserDraft.empty({int? idRol}) {
    return _UserDraft(
      nombres: "",
      apellidos: "",
      cedula: "",
      email: "",
      username: "",
      idRol: idRol,
      activo: true,
    );
  }

  final String nombres;
  final String apellidos;
  final String cedula;
  final String email;
  final String username;
  final int? idRol;
  final bool activo;
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({
    required this.title,
    required this.submitLabel,
    required this.roles,
    required this.initialValue,
  });

  final String title;
  final String submitLabel;
  final List<Map<String, dynamic>> roles;
  final _UserDraft initialValue;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  static final RegExp _emailRegex =
      RegExp(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$");
  static final RegExp _usernameRegex = RegExp(r"^[a-z0-9._-]{3,32}$");
  static final RegExp _cedulaRegex = RegExp(r"^[0-9-]{6,20}$");

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombresController;
  late final TextEditingController _apellidosController;
  late final TextEditingController _cedulaController;
  late final TextEditingController _emailController;
  late final TextEditingController _usernameController;
  int? _selectedRoleId;
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    _nombresController = TextEditingController(text: widget.initialValue.nombres);
    _apellidosController = TextEditingController(text: widget.initialValue.apellidos);
    _cedulaController = TextEditingController(text: widget.initialValue.cedula);
    _emailController = TextEditingController(text: widget.initialValue.email);
    _usernameController = TextEditingController(text: widget.initialValue.username);
    _selectedRoleId = widget.initialValue.idRol;
    _activo = widget.initialValue.activo;
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _cedulaController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? "");
  }

  String? _requiredText(String? value, {String label = "Campo"}) {
    final text = (value ?? "").trim();
    if (text.isEmpty) {
      return "$label es obligatorio";
    }
    return null;
  }

  String? _validateCedula(String? value) {
    final base = _requiredText(value, label: "Cédula");
    if (base != null) {
      return base;
    }
    if (!_cedulaRegex.hasMatch(value!.trim())) {
      return "Formato inválido";
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final base = _requiredText(value, label: "Correo");
    if (base != null) {
      return base;
    }
    if (!_emailRegex.hasMatch(value!.trim().toLowerCase())) {
      return "Correo inválido";
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final base = _requiredText(value, label: "Usuario");
    if (base != null) {
      return base;
    }
    if (!_usernameRegex.hasMatch(value!.trim().toLowerCase())) {
      return "Usa 3-32 chars: a-z, 0-9, . _ -";
    }
    return null;
  }

  void _submit() {
    final validRoleIds = widget.roles
        .map((role) => _asInt(role["id"]))
        .whereType<int>()
        .toSet();

    if (!_formKey.currentState!.validate() ||
        _selectedRoleId == null ||
        !validRoleIds.contains(_selectedRoleId)) {
      setState(() {});
      return;
    }

    Navigator.of(context).pop(
      _UserDraft(
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        cedula: _cedulaController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        username: _usernameController.text.trim().toLowerCase(),
        idRol: _selectedRoleId,
        activo: _activo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleMap = <int, Map<String, dynamic>>{};
    for (final role in widget.roles) {
      final roleId = _asInt(role["id"]);
      if (roleId == null || roleMap.containsKey(roleId)) {
        continue;
      }
      roleMap[roleId] = role;
    }

    final availableRoleIds = roleMap.keys.toSet();
    final effectiveSelectedRoleId =
        availableRoleIds.contains(_selectedRoleId) ? _selectedRoleId : null;
    final roleError = effectiveSelectedRoleId == null ? "Debes elegir un rol" : null;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _nombresController,
                    decoration: const InputDecoration(labelText: "Nombres"),
                    validator: (value) => _requiredText(value, label: "Nombres"),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _apellidosController,
                    decoration: const InputDecoration(labelText: "Apellidos"),
                    validator: (value) => _requiredText(value, label: "Apellidos"),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _cedulaController,
                    decoration: const InputDecoration(labelText: "Cédula"),
                    validator: _validateCedula,
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: "Correo"),
                    validator: _validateEmail,
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: "Usuario"),
                    validator: _validateUsername,
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<int>(
                    initialValue: effectiveSelectedRoleId,
                    decoration: InputDecoration(
                      labelText: "Rol",
                      errorText: roleError,
                    ),
                    items: [
                      for (final entry in roleMap.entries)
                        DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value["nombre"]?.toString() ?? "Rol"),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedRoleId = value);
                    },
                  ),
                ),
                SwitchListTile.adaptive(
                  value: _activo,
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Cuenta activa"),
                  onChanged: (value) => setState(() => _activo = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancelar"),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded),
          label: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
