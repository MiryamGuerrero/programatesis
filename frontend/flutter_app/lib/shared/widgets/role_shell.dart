import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/auth/login_page.dart";
import "../../features/roles/role_module.dart";
import "../../features/roles/role_module_registry.dart";
import "../models/app_role.dart";

class RoleShell extends StatefulWidget {
  const RoleShell({required this.role, super.key});

  final AppRole role;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;
  bool _signingOut = false;
  bool _initializedFromRoute = false;

  List<RoleModule> get _modules => modulesForRole(widget.role);

  RoleModule get _currentModule {
    if (_modules.isEmpty) {
      return RoleModule(
        key: "empty",
        title: "Sin modulos",
        icon: Icons.block,
        builder: () => const _EmptyModuleState(),
      );
    }
    final safeIndex = _index.clamp(0, _modules.length - 1);
    return _modules[safeIndex];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_modules.isEmpty) {
      _index = 0;
      return;
    }

    if (_index >= _modules.length) {
      _index = 0;
    }

    _applyInitialModuleFromRoute();
  }

  void _applyInitialModuleFromRoute() {
    if (_initializedFromRoute || _modules.isEmpty) {
      return;
    }
    final moduleKey = Uri.base.queryParameters["module"];
    if (moduleKey != null && moduleKey.trim().isNotEmpty) {
      final routeIndex = _modules.indexWhere((module) => module.key == moduleKey.trim());
      if (routeIndex >= 0) {
        _index = routeIndex;
      }
    }
    _initializedFromRoute = true;
  }

  void _selectModule(int value) {
    if (value < 0 || value >= _modules.length) {
      return;
    }
    if (value == _index) {
      return;
    }
    setState(() => _index = value);
  }

  Future<void> _handleSignOut() async {
    if (_signingOut) {
      return;
    }

    setState(() => _signingOut = true);
    var success = true;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      success = false;
    }

    if (!mounted) {
      return;
    }

    setState(() => _signingOut = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo cerrar sesion. Intenta nuevamente."),
        ),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final module = _currentModule;

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.role.label} · ${module.title}"),
        actions: [
          IconButton(
            onPressed: _signingOut ? null : _handleSignOut,
            icon: _signingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            tooltip: "Cerrar sesion",
          ),
        ],
      ),
      drawer: isWide ? null : _buildDrawer(),
      body: isWide ? _buildWideLayout() : module.builder(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _index.clamp(0, (_modules.isEmpty ? 1 : _modules.length) - 1),
          onDestinationSelected: _selectModule,
          labelType: NavigationRailLabelType.all,
          destinations: [
            for (final module in _modules)
              NavigationRailDestination(
                icon: Icon(module.icon),
                label: Text(module.title),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _currentModule.builder()),
      ],
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text("Secciones"),
              subtitle: Text(widget.role.label),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _modules.length,
                itemBuilder: (context, index) {
                  final module = _modules[index];
                  return ListTile(
                    selected: index == _index,
                    leading: Icon(module.icon),
                    title: Text(module.title),
                    onTap: () {
                      Navigator.of(context).pop();
                      _selectModule(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyModuleState extends StatelessWidget {
  const _EmptyModuleState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_off_rounded, size: 42, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(
            "No hay modulos disponibles",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
