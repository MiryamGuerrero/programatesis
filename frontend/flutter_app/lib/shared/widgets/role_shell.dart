import "package:flutter/material.dart";
<<<<<<< HEAD
import "package:flutter_riverpod/flutter_riverpod.dart";
=======
>>>>>>> e54989a7111bb99b09583ca9eeb1fd4ff7e397ec
import "package:supabase_flutter/supabase_flutter.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";

import "../../core/state/app_providers.dart";
import "../../core/theme/app_theme.dart";
import "../../features/auth/login_page.dart";
import "../../features/roles/role_module_registry.dart";
import "../models/app_role.dart";
import "../../core/services/realtime_service.dart";
import "../../core/state/notification_provider.dart";

<<<<<<< HEAD
class RoleShell extends ConsumerStatefulWidget {
  const RoleShell({super.key, required this.role});
=======
class RoleShell extends StatefulWidget {
  const RoleShell({required this.role, super.key});

>>>>>>> e54989a7111bb99b09583ca9eeb1fd4ff7e397ec
  final AppRole role;

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

<<<<<<< HEAD
class _RoleShellState extends ConsumerState<RoleShell> {
  int _index = 0;
  bool _signingOut = false;
  bool _isMenuExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realtimeServiceProvider).init();
    });
  }

  String _obtenerIniciales(String nombre) {
    try {
      List<String> partes = nombre.trim().split(" ");
      if (partes.length >= 2) return (partes[0][0] + partes[1][0]).toUpperCase();
      return (partes[0].isNotEmpty ? partes[0][0] : "U").toUpperCase();
    } catch (_) { return "U"; }
  }

  @override
  Widget build(BuildContext context) {
    final modules = modulesForRole(widget.role);
    if (_index >= modules.length) _index = 0;

    final session = ref.watch(authSessionProvider).valueOrNull;
    final perfilAsync = ref.watch(miPerfilProvider);

    // Prioridad: 1. DB (nombre_completo), 2. Metadata (full_name), 3. Email
    final String nombreUsuario = perfilAsync.maybeWhen(
      data: (d) => d["nombre_completo"]?.toString() ?? "Usuario",
      orElse: () => session?.user.userMetadata?["full_name"] ?? 
                     session?.user.userMetadata?["nombre_completo"] ??
                     session?.user.email?.split("@")[0] ?? "Usuario",
    );

    // Obtener el nombre del rol descriptivo del perfil
    final String nombreRol = perfilAsync.maybeWhen(
      data: (d) => d["rol_nombre"]?.toString() ?? widget.role.label,
      orElse: () => widget.role.label,
    );
    
    final String iniciales = _obtenerIniciales(nombreUsuario);
    final isWide = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      appBar: _buildTopBar(nombreUsuario, nombreRol, iniciales, isWide),
      body: Row(
        children: [
          if (isWide) _buildSidebar(modules),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IndexedStack(
                index: _index,
                children: [for (final m in modules) m.builder()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(String nombre, String nombreRol, String iniciales, bool isWide) {
    return AppBar(
      elevation: 2,
      toolbarHeight: 75,
      backgroundColor: AppTema.azulPrincipal,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          IconButton(
            icon: Icon(_isMenuExpanded ? Icons.menu_open_rounded : Icons.menu_rounded, color: Colors.white, size: 28),
            onPressed: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
          ),
          const SizedBox(width: 8),
          Text("NutriReuma", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
        ],
      ),
      actions: [
        const _NotificationBell(),
        const SizedBox(width: 24),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(nombreRol.toUpperCase(), style: const TextStyle(color: AppTema.verdeLima, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white)),
          child: Center(child: Text(iniciales, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _HoverSignOutButton(
            onPressed: _signingOut ? null : _handleSignOut,
            isSigningOut: _signingOut,
          ),
        ),
=======
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
>>>>>>> e54989a7111bb99b09583ca9eeb1fd4ff7e397ec
      ],
    );
  }

<<<<<<< HEAD
  Widget _buildSidebar(List<RoleModule> modules) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isMenuExpanded ? 240 : 75,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 20),
        itemCount: modules.length,
        itemBuilder: (context, i) {
          final active = i == _index;
          return ListTile(
            onTap: () => setState(() => _index = i),
            selected: active,
            leading: Icon(modules[i].icon, color: active ? AppTema.azulPrincipal : Colors.grey[400]),
            title: _isMenuExpanded 
                ? Text(modules[i].title, style: TextStyle(color: active ? AppTema.azulPrincipal : Colors.black87, fontWeight: active ? FontWeight.bold : FontWeight.normal))
                : null,
            tileColor: active ? AppTema.cianLimpio.withOpacity(0.5) : Colors.transparent,
          );
        },
      ),
    );
  }

  Future<void> _handleSignOut() async {
    setState(() => _signingOut = true);
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final unreadCount = ref.read(notificationProvider.notifier).unreadCount;

    return PopupMenuButton<void>(
      offset: const Offset(0, 50),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
          if (unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 9 ? "+9" : unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      tooltip: "Notificaciones",
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Notificaciones", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppTema.azulPrincipal)),
                    if (notifications.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          ref.read(notificationProvider.notifier).markAllAsRead();
                          Navigator.pop(context);
                        },
                        child: const Text("Leer todas", style: TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
                const Divider(),
              ],
            ),
          ),
        ),
        if (notifications.isEmpty)
          const PopupMenuItem<void>(
            enabled: false,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("No tienes notificaciones", style: TextStyle(color: Colors.grey, fontSize: 13))),
            ),
          )
        else
          ...notifications.take(5).map((n) => PopupMenuItem<void>(
            onTap: () => ref.read(notificationProvider.notifier).markAsRead(n.id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _getIcon(n.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold, fontSize: 13)),
                        Text(n.message, style: const TextStyle(fontSize: 11, color: Colors.blueGrey), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(DateFormat("HH:mm").format(n.timestamp), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (!n.read)
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTema.azulPrincipal, shape: BoxShape.circle)),
                ],
              ),
            ),
          )),
        if (notifications.isNotEmpty)
          PopupMenuItem<void>(
            onTap: () => ref.read(notificationProvider.notifier).clearAll(),
            child: const Center(child: Text("Limpiar historial", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
          ),
      ],
    );
  }

  Widget _getIcon(NutriNotificationType type) {
    IconData icon; Color color;
    switch (type) {
      case NutriNotificationType.success: icon = Icons.check_circle_rounded; color = const Color(0xFF4DB6AC); break;
      case NutriNotificationType.error: icon = Icons.error_rounded; color = Colors.redAccent; break;
      case NutriNotificationType.warning: icon = Icons.warning_rounded; color = Colors.orange; break;
      default: icon = Icons.info_rounded; color = AppTema.azulPrincipal;
    }
    return Icon(icon, color: color, size: 20);
  }
}

class _HoverSignOutButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isSigningOut;
  const _HoverSignOutButton({this.onPressed, required this.isSigningOut});

  @override
  State<_HoverSignOutButton> createState() => _HoverSignOutButtonState();
}

class _HoverSignOutButtonState extends State<_HoverSignOutButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: OutlinedButton.icon(
        onPressed: widget.onPressed,
        icon: widget.isSigningOut 
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(Icons.power_settings_new_rounded, color: _isHovered ? AppTema.azulPrincipal : Colors.white, size: 16),
        label: Text(widget.isSigningOut ? "..." : "Cerrar Sesión", 
          style: TextStyle(color: _isHovered ? AppTema.azulPrincipal : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          backgroundColor: _isHovered ? Colors.white : Colors.transparent,
          side: const BorderSide(color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
=======
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
>>>>>>> e54989a7111bb99b09583ca9eeb1fd4ff7e397ec
      ),
    );
  }
}
