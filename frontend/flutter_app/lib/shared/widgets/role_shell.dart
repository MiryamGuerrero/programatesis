import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/auth/login_page.dart";
import "../../features/roles/role_module.dart";
import "../../features/roles/role_module_registry.dart";
import "../models/app_role.dart";

class RoleShell extends StatefulWidget {
  const RoleShell({super.key, required this.role});

  final AppRole role;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;
  bool _signingOut = false;
  bool _initializedFromRoute = false;

  @override
  void initState() {
    super.initState();
    _index = _defaultIndexForRole(widget.role);
  }

  @override
  void didUpdateWidget(covariant RoleShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _index = _defaultIndexForRole(widget.role);
      _initializedFromRoute = false;
    }
  }

  int _defaultIndexForRole(AppRole role) {
    return defaultModuleIndexForRole(role);
  }

  @override
  Widget build(BuildContext context) {
    final modules = modulesForRole(widget.role);
    _applyInitialModuleFromRoute(modules);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 960;

    if (_index >= modules.length) {
      _index = 0;
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.18),
                colors.secondary.withValues(alpha: 0.12),
                const Color(0xFFFFF8F3),
              ],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.role.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              modules[_index].title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: _signingOut ? null : _handleSignOut,
              icon: _signingOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(_signingOut ? "Saliendo..." : "Cerrar sesion"),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7FFF8),
              Color(0xFFEFFAFD),
              Color(0xFFFFFDF7),
            ],
          ),
        ),
        child: Row(
          children: [
            if (isWide) _buildWideNavigation(context, modules),
            Expanded(
              child: _buildModulePanel(context, modules, isWide),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          isWide ? null : _buildMobileNavigation(context, modules),
    );
  }

  Future<void> _handleSignOut() async {
    setState(() => _signingOut = true);

    var remoteFailed = false;
    var localFailed = false;

    try {
      await Supabase.instance.client.auth
          .signOut()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      remoteFailed = true;
    }

    try {
      await Supabase.instance.client.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      localFailed = true;
    }

    if (mounted && remoteFailed && localFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No se pudo cerrar sesion. Intenta nuevamente en unos segundos.",
          ),
        ),
      );
    }

    if (mounted && remoteFailed && !localFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sesion local cerrada. Se omitio cierre remoto."),
        ),
      );
    }

    if (mounted && (!remoteFailed || !localFailed)) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
        ),
        (_) => false,
      );
    }

    if (mounted) {
      setState(() => _signingOut = false);
    }
  }

  void _applyInitialModuleFromRoute(List<RoleModule> modules) {
    if (_initializedFromRoute || modules.isEmpty) {
      return;
    }

    final moduleKey = Uri.base.queryParameters["module"];
    if (moduleKey != null && moduleKey.trim().isNotEmpty) {
      final routeIndex = modules.indexWhere((module) => module.key == moduleKey.trim());
      if (routeIndex >= 0) {
        _index = routeIndex;
      }
    }

    _initializedFromRoute = true;
    _syncRouteForModule(modules[_index].key);
  }

  void _selectModule(int value, List<RoleModule> modules) {
    setState(() => _index = value);
    _syncRouteForModule(modules[value].key);
  }

  void _syncRouteForModule(String moduleKey) {
    final encodedRole = Uri.encodeComponent(widget.role.name);
    final encodedModule = Uri.encodeComponent(moduleKey);
    final location = "/?role=$encodedRole&module=$encodedModule";
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(location),
    );
  }

  Widget _buildWideNavigation(BuildContext context, List<RoleModule> modules) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outline.withValues(alpha: 0.24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A30414A),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationRail(
            minWidth: 84,
            minExtendedWidth: 240,
            extended: true,
            useIndicator: true,
            groupAlignment: -0.75,
            selectedIndex: _index,
            onDestinationSelected: (value) => _selectModule(value, modules),
            labelType: NavigationRailLabelType.none,
            backgroundColor: Colors.transparent,
            destinations: [
              for (final module in modules)
                NavigationRailDestination(
                  icon: Icon(module.icon),
                  label: Text(module.title),
                ),
            ],
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF81C784), Color(0xFF4CAF50)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.spa_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 140,
                      child: Text(
                        "Reuma Nutri",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModulePanel(
    BuildContext context,
    List<RoleModule> modules,
    bool isWide,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 8 : 16, 16, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2A3D47),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isWide ? 20 : 14),
          child: IndexedStack(
            index: _index,
            children: [
              for (final module in modules) module.builder(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavigation(
      BuildContext context, List<RoleModule> modules) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outline.withValues(alpha: 0.24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A30414A),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: _index,
          onDestinationSelected: (value) => _selectModule(value, modules),
          destinations: [
            for (final module in modules)
              NavigationDestination(
                icon: Icon(module.icon),
                label: module.title,
              ),
          ],
        ),
      ),
    );
  }

}

