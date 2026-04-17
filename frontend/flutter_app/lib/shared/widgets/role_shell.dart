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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _index = 0;
  bool _signingOut = false;
  bool _initializedFromRoute = false;
  bool _menuExpanded = true;

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
    final isWide = MediaQuery.of(context).size.width >= 980;

    if (_index >= modules.length) {
      _index = 0;
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: isWide ? null : _buildDrawerNavigation(context, modules),
      appBar: AppBar(
        toolbarHeight: 82,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.16),
                colors.tertiary.withValues(alpha: 0.1),
                const Color(0xFFF8FAFC),
              ],
            ),
          ),
        ),
        titleSpacing: 0,
        leadingWidth: 60,
        leading: IconButton(
          tooltip: isWide
              ? (_menuExpanded ? "Contraer menu" : "Expandir menu")
              : "Abrir menu",
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _toggleNavigation(isWide),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                ),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Clinica nutricional - ${widget.role.label}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    modules[_index].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
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
        decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
        child: Stack(
          children: [
            const Positioned.fill(child: _ShellBackdrop()),
            Row(
              children: [
                if (isWide)
                  _buildWideNavigation(
                    context,
                    modules,
                    isExpanded: _menuExpanded,
                  ),
                Expanded(
                  child: _buildModulePanel(context, modules, isWide),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleNavigation(bool isWide) {
    if (isWide) {
      setState(() => _menuExpanded = !_menuExpanded);
      return;
    }
    _scaffoldKey.currentState?.openDrawer();
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
      final signedOutUri = Uri(
        path: "/",
        queryParameters: {
          "signed_out": "1",
        },
      );

      SystemNavigator.routeInformationUpdated(
        uri: signedOutUri,
        replace: true,
      );

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

  Widget _buildWideNavigation(
    BuildContext context,
    List<RoleModule> modules, {
    required bool isExpanded,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1830414A),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationRail(
            minWidth: 78,
            minExtendedWidth: 252,
            extended: isExpanded,
            useIndicator: true,
            groupAlignment: -0.75,
            selectedIndex: _index,
            onDestinationSelected: (value) => _selectModule(value, modules),
            labelType: NavigationRailLabelType.none,
            selectedLabelTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
            unselectedLabelTextStyle:
                Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
            selectedIconTheme: const IconThemeData(size: 22),
            unselectedIconTheme: const IconThemeData(size: 21),
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
                child: isExpanded
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                const Icon(Icons.grid_view_rounded, color: Colors.white),
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
                      )
                    : Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.grid_view_rounded, color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerNavigation(BuildContext context, List<RoleModule> modules) {
    final colors = Theme.of(context).colorScheme;

    return Drawer(
      width: 312,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.grid_view_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sistema Nutricional",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          "Modulo ${widget.role.label}",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  final module = modules[index];
                  final selected = index == _index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: Icon(module.icon),
                      title: Text(
                        module.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                            ),
                      ),
                      selected: selected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _selectModule(index, modules);
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
          color: colors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outline.withValues(alpha: 0.24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x142A3D47),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
      ),
    );
  }

}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFF5F9F8),
                    Color(0xFFFFFFFF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            left: -120,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 420,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            right: -140,
            bottom: -28,
            child: Transform.rotate(
              angle: 0.1,
              child: Container(
                width: 460,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0x00FFFFFF),
                    Color(0x12FFFFFF),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

