import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/state/app_providers.dart";
import "../../features/auth/login_page.dart";
import "../../features/roles/role_module_registry.dart";
import "../models/app_role.dart";
import "../../core/services/realtime_service.dart";

final menuExpandedProvider = StateProvider<bool>((ref) => true);

class RoleShell extends ConsumerStatefulWidget {
  const RoleShell({super.key, required this.role});
  final AppRole role;

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends ConsumerState<RoleShell> {
  int _index = 0;
  bool _signingOut = false;
  
  final Map<String, Widget> _moduleCache = <String, Widget>{};
  final Map<String, bool> _categoryExpanded = {};
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realtimeServiceProvider).init();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RoleShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _index = 0;
      _moduleCache.clear();
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  String _cacheKeyFor(RoleModule module, int index) {
    return "${widget.role.name}:$index:${module.key}";
  }

  Widget _moduleFor(RoleModule module, int index) {
    return _moduleCache.putIfAbsent(
      _cacheKeyFor(module, index),
      module.builder,
    );
  }

  Widget _buildLazyModuleStack(List<RoleModule> modules) {
    if (modules.isEmpty) return const SizedBox.shrink();

    final safeIndex = _index.clamp(0, modules.length - 1).toInt();

    return PageView.builder(
      controller: _pageController,
      itemCount: modules.length,
      onPageChanged: (index) {
        if (_index != index) {
          setState(() {
            _index = index;
          });
        }
      },
      itemBuilder: (context, i) {
        final module = modules[i];
        final cacheKey = _cacheKeyFor(module, i);
        final shouldBuild = i == safeIndex || _moduleCache.containsKey(cacheKey);

        if (!shouldBuild) {
          return const SizedBox.expand();
        }

        return _KeepAliveWrapper(
          key: ValueKey(cacheKey),
          child: _moduleFor(module, i),
        );
      },
    );
  }

  void _selectModule(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    if (_pageController.hasClients && _pageController.page?.round() != index) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _obtenerIniciales(String nombre) {
    try {
      List<String> partes = nombre.trim().split(" ");
      if (partes.length >= 2) {
        return (partes[0][0] + partes[1][0]).toUpperCase();
      }
      return (partes[0].isNotEmpty ? partes[0][0] : "U").toUpperCase();
    } catch (_) {
      return "U";
    }
  }

  @override
  Widget build(BuildContext context) {
    final modules = modulesForRole(widget.role);
    if (_index >= modules.length) _index = 0;

    final session = ref.watch(authSessionProvider).valueOrNull;
    final perfilAsync = ref.watch(miPerfilProvider);

    final String nombreUsuario = perfilAsync.maybeWhen(
      data: (d) {
        final username = d["username"]?.toString().trim() ?? "";
        if (username.isNotEmpty) return username;
        final email = d["email"]?.toString().trim() ?? "";
        if (email.isNotEmpty) return email.split("@").first;
        return d["nombre_completo"]?.toString() ?? "Usuario";
      },
      orElse: () =>
          session?.user.email?.split("@")[0] ??
          session?.user.userMetadata?["username"] ??
          "Usuario",
    );

    final String nombreRol = perfilAsync.maybeWhen(
      data: (d) => (d["titulo_profesional"]?.toString().isNotEmpty == true)
          ? d["titulo_profesional"].toString()
          : (d["rol_nombre"]?.toString() ?? widget.role.label),
      orElse: () => widget.role.label,
    );

    final List<dynamic> userRoles = perfilAsync.maybeWhen(
      data: (d) => d["roles"] as List<dynamic>? ?? [],
      orElse: () => [],
    );

    final int currentRolId = perfilAsync.maybeWhen(
      data: (d) => d["id_rol"] as int? ?? 0,
      orElse: () => 0,
    );

    final String iniciales = _obtenerIniciales(nombreUsuario);
    final isWide = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildGlobalHeader(nombreUsuario, nombreRol, iniciales, isWide, userRoles, currentRolId),
          Expanded(
            child: Row(
              children: [
                if (isWide) _buildSidebar(modules),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: _buildLazyModuleStack(modules),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: const Color(0xFF0171BB).withValues(alpha: 0.08),
                surfaceTintColor: Colors.transparent,
                height: 80,
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(
                        color: Color(0xFF0171BB), size: 24);
                  }
                  return const IconThemeData(
                      color: Color(0xFF64748B), size: 24);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final isSelected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF0171BB)
                        : const Color(0xFF64748B),
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                backgroundColor: Colors.white,
                elevation: 8,
                surfaceTintColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: _selectModule,
                destinations: [
                  for (final m in modules)
                    NavigationDestination(
                      icon: Icon(m.icon),
                      label: m.title,
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildGlobalHeader(
      String nombre,
      String nombreRol,
      String iniciales,
      bool isWide,
      List<dynamic> userRoles,
      int currentRolId) {
    const Color brandBlue = Color(0xFF0068B7);
    const Color brandGreen = Color(0xFF58A932);

    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: brandBlue.withValues(alpha: 0.1), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: isWide ? 280 : 260,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_rounded,
                      color: brandBlue, size: 28),
                  onPressed: () =>
                      ref.read(menuExpandedProvider.notifier).state = !ref.watch(menuExpandedProvider),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  "assets/images/logo_reuma_nutri.png",
                  width: 60,
                  height: 60,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    overflow: TextOverflow.clip,
                    text: TextSpan(
                      style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5),
                      children: const [
                        TextSpan(
                            text: "Nutri", style: TextStyle(color: brandBlue)),
                        TextSpan(
                            text: "Reuma", style: TextStyle(color: brandGreen)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const _NotificationBell(),
          const SizedBox(width: 24),
          _UserProfileDropdown(
            nombre: nombre,
            nombreRol: nombreRol,
            iniciales: iniciales,
            userRoles: userRoles,
            currentRolId: currentRolId,
          ),
          const SizedBox(width: 24),
          _HoverSignOutButton(
            onPressed: _signingOut ? null : _handleSignOut,
            isSigningOut: _signingOut,
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildSidebar(List<RoleModule> modules) {
    const Color companyBlue = Color(0xFF0068B7);
    const Color selectionGreen = Color(0xFF58A932);

    final Map<String, List<int>> categorizedModules = {};
    for (int i = 0; i < modules.length; i++) {
      final String cat = modules[i].category ?? "";
      categorizedModules.putIfAbsent(cat, () => []).add(i);
    }

    final List<Widget> listItems = [];
    
    categorizedModules.forEach((categoryName, indices) {
      if (categoryName.isNotEmpty && ref.watch(menuExpandedProvider)) {
        final isExpanded = _categoryExpanded[categoryName] ?? true;
        listItems.add(
          InkWell(
            onTap: () {
              setState(() {
                _categoryExpanded[categoryName] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      categoryName,
                      style: GoogleFonts.montserrat(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (categoryName.isNotEmpty && !ref.watch(menuExpandedProvider)) {
        listItems.add(const SizedBox(height: 24));
      }

      final isExpanded = _categoryExpanded[categoryName] ?? true;
      if (isExpanded || !ref.watch(menuExpandedProvider)) {
        for (final i in indices) {
          final active = i == _index;
          listItems.add(
            InkWell(
              onTap: () => _selectModule(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: active ? selectionGreen : Colors.transparent,
                  border: active
                      ? const Border(
                          left: BorderSide(color: Colors.white, width: 4))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(modules[i].icon, color: Colors.white, size: 24),
                    if (ref.watch(menuExpandedProvider)) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          modules[i].title,
                          style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13),
                          softWrap: false,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          );
        }
      }
    });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: ref.watch(menuExpandedProvider) ? 280 : 85,
      color: companyBlue,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: listItems,
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: ref.watch(menuExpandedProvider) ? 1.0 : 0.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: ref.watch(menuExpandedProvider)
                  ? Text(
                      "ReumaNutri v1.0",
                      style: GoogleFonts.montserrat(
                          color: Colors.white24,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    setState(() => _signingOut = true);
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }
}

class _NotificationBell extends ConsumerStatefulWidget {
  const _NotificationBell();

  @override
  ConsumerState<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<_NotificationBell> {
  final MenuController _menuController = MenuController();

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Justo ahora";
    if (diff.inMinutes < 60) return "hace ${diff.inMinutes} min";
    if (diff.inHours < 24) return "hace ${diff.inHours} h";
    return "hace ${diff.inDays} d";
  }

  @override
  Widget build(BuildContext context) {
    final notifs = ref.watch(notificationProvider);
    final unreadCount = notifs.where((n) => !n.read).length;
    final notifier = ref.read(notificationProvider.notifier);

    return MenuAnchor(
      controller: _menuController,
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      alignmentOffset: const Offset(-272, 8),
      menuChildren: [
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: const Color(0xFF0068B7),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 12), spreadRadius: 4)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text("Notificaciones",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(unreadCount.toString(),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    const Spacer(),
                    if (unreadCount > 0)
                      InkWell(
                        onTap: () {
                          for (final n in notifs) {
                            if (!n.read) notifier.markAsRead(n.id);
                          }
                          _menuController.close();
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text("Marcar leídas",
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(height: 1, width: 320, color: Colors.white.withOpacity(0.15)),
              // List
              if (notifs.isEmpty)
                SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text("Sin notificaciones nuevas",
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.white70)),
                    ),
                  ),
                )
              else
                Container(
                  width: 320,
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int index = 0; index < notifs.length; index++) ...[
                          Builder(builder: (context) {
                            final n = notifs[index];
                            Color iconColor;
                            Color bgColor;
                            IconData icon;
                            switch (n.type) {
                              case NutriNotificationType.success:
                                iconColor = const Color(0xFF10B981);
                                bgColor = const Color(0xFFD1FAE5);
                                icon = Icons.check_circle_outline;
                                break;
                              case NutriNotificationType.warning:
                                iconColor = const Color(0xFFF59E0B);
                                bgColor = const Color(0xFFFEF3C7);
                                icon = Icons.warning_amber_rounded;
                                break;
                              case NutriNotificationType.error:
                                iconColor = const Color(0xFFEF4444);
                                bgColor = const Color(0xFFFEE2E2);
                                icon = Icons.error_outline_rounded;
                                break;
                              default:
                                iconColor = const Color(0xFF3B82F6);
                                bgColor = const Color(0xFFDBEAFE);
                                icon = Icons.info_outline_rounded;
                            }

                            return InkWell(
                              onTap: () {
                                if (!n.read) notifier.markAsRead(n.id);
                              },
                              child: Container(
                                width: 320,
                                color: n.read ? Colors.transparent : Colors.white.withOpacity(0.08),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(icon, size: 18, color: iconColor),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 220,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(n.title,
                                              style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white)),
                                          const SizedBox(height: 4),
                                          Text(n.message,
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: Colors.white70)),
                                          const SizedBox(height: 6),
                                          Text(_timeAgo(n.timestamp),
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: Colors.white54)),
                                        ],
                                      ),
                                    ),
                                    if (!n.read)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                            color: Colors.white, shape: BoxShape.circle),
                                      )
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (index < notifs.length - 1)
                            Container(height: 1, width: 320, color: Colors.white.withOpacity(0.1)),
                        ]
                      ],
                    ),
                  ),
                ),
              Container(height: 1, width: 320, color: Colors.white.withOpacity(0.15)),
              // Footer
              SizedBox(
                width: 320,
                child: InkWell(
                  onTap: () => _menuController.close(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text("Ver todas las notificaciones",
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) {
        return IconButton(
          icon: unreadCount > 0
              ? Badge(
                  label: Text(unreadCount.toString()),
                  child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 26),
                )
              : const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 26),
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
    );
  }
}

class _UserProfileDropdown extends ConsumerStatefulWidget {
  final String nombre;
  final String nombreRol;
  final String iniciales;
  final List<dynamic> userRoles;
  final int currentRolId;

  const _UserProfileDropdown({
    required this.nombre,
    required this.nombreRol,
    required this.iniciales,
    required this.userRoles,
    required this.currentRolId,
  });

  @override
  ConsumerState<_UserProfileDropdown> createState() => _UserProfileDropdownState();
}

class _UserProfileDropdownState extends ConsumerState<_UserProfileDropdown> {
  final MenuController _menuController = MenuController();

  Future<void> _changeRole(int selectedRolId) async {
    if (selectedRolId == widget.currentRolId) return;

    // Cierra el menu
    _menuController.close();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF0068B7)),
      ),
    );

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.switchActiveRole(selectedRolId);

      final client = ref.read(supabaseClientProvider);
      await client.auth.refreshSession();

      ref.invalidate(appRoleProvider);
      ref.invalidate(miPerfilProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al cambiar de rol: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      alignmentOffset: const Offset(-85, 8),
      menuChildren: [
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: const Color(0xFF0068B7),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 12), spreadRadius: 4)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con info de usuario
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Text(widget.iniciales,
                          style: const TextStyle(
                              color: Color(0xFF0068B7),
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.nombre,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.white)),
                          Text(widget.nombreRol,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, width: 280, color: Colors.white.withOpacity(0.15)),
              
              // Roles list
              if (widget.userRoles.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text("Cambiar Rol",
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
                ...widget.userRoles.map((r) {
                  final bool isCurrent = r["id"] == widget.currentRolId;
                  final String roleName = r["nombre"]?.toString() ?? "";
                  IconData roleIcon = Icons.badge_outlined;
                  final String rnLower = roleName.toLowerCase();
                  if (rnLower.contains("admin")) {
                    roleIcon = Icons.admin_panel_settings_outlined;
                  } else if (rnLower.contains("medico") || rnLower.contains("médico")) {
                    roleIcon = Icons.medical_services_outlined;
                  } else if (rnLower.contains("tutor")) {
                    roleIcon = Icons.family_restroom_rounded;
                  } else if (rnLower.contains("nutri")) {
                    roleIcon = Icons.restaurant_menu_outlined;
                  }

                  return InkWell(
                    onTap: () => _changeRole(r["id"] as int),
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: isCurrent ? Colors.white.withOpacity(0.1) : Colors.transparent,
                      child: Row(
                        children: [
                          Icon(roleIcon, size: 18, color: Colors.white70),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 180,
                            child: Text(roleName,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                                    color: Colors.white)),
                          ),
                          if (isCurrent)
                            const Icon(Icons.check, size: 16, color: Colors.white)
                        ],
                      ),
                    ),
                  );
                }),
                Container(height: 1, width: 280, color: Colors.white.withOpacity(0.15)),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) {
        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(widget.nombre,
                        style: GoogleFonts.inter(
                            color: const Color(0xFF1E293B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(widget.nombreRol,
                        style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 11)),
                  ],
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF0068B7).withValues(alpha: 0.1),
                  child: Text(widget.iniciales,
                      style: const TextStyle(
                          color: Color(0xFF0068B7),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
              ],
            ),
          ),
        );
      },
    );
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
    const Color brandBlue = Color(0xFF0068B7);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _isHovered ? Colors.white : brandBlue,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: brandBlue, width: 2),
            ),
            child: widget.isSigningOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Cerrar sesión",
                          style: GoogleFonts.montserrat(
                            color: _isHovered ? brandBlue : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          )),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  const _KeepAliveWrapper({super.key, required this.child});
  final Widget child;

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
