import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/state/app_providers.dart";
import "../../features/auth/login_page.dart";
import "../../features/roles/role_module_registry.dart";
import "../models/app_role.dart";
import "../../core/services/realtime_service.dart";

class RoleShell extends ConsumerStatefulWidget {
  const RoleShell({super.key, required this.role});
  final AppRole role;

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends ConsumerState<RoleShell> {
  int _index = 0;
  bool _signingOut = false;
  bool _isMenuExpanded = true;
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
      decoration: const BoxDecoration(
        color: Colors.white,
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
                      setState(() => _isMenuExpanded = !_isMenuExpanded),
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(nombre,
                  style: GoogleFonts.montserrat(
                      color: const Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              if (userRoles.length > 1)
                PopupMenuButton<int>(
                  tooltip: "Cambiar de rol",
                  offset: const Offset(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.1), width: 1),
                  ),
                  color: Colors.white,
                  surfaceTintColor: Colors.white,
                  elevation: 12,
                  onSelected: (int selectedRolId) async {
                    if (selectedRolId == currentRolId) return;

                    // Mostrar un diálogo de carga rápido
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const Center(
                        child: CircularProgressIndicator(color: brandBlue),
                      ),
                    );

                    try {
                      final repo = ref.read(supabaseCrudRepositoryProvider);
                      await repo.switchActiveRole(selectedRolId);

                      // Refrescar sesión de Supabase
                      final client = ref.read(supabaseClientProvider);
                      await client.auth.refreshSession();

                      // Invalidar proveedores globales
                      ref.invalidate(appRoleProvider);
                      ref.invalidate(miPerfilProvider);

                      if (mounted) {
                        Navigator.of(context).pop(); // Cerrar diálogo de carga
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop(); // Cerrar diálogo de carga
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Error al cambiar de rol: ${e.toString()}",
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) {
                    return userRoles.map<PopupMenuEntry<int>>((r) {
                      final bool isCurrent = r["id"] == currentRolId;
                      final String roleName = r["nombre"]?.toString() ?? "";
                      
                      IconData roleIcon = Icons.badge_outlined;
                      final lowerName = roleName.toLowerCase();
                      if (lowerName.contains("admin")) roleIcon = Icons.admin_panel_settings_outlined;
                      else if (lowerName.contains("médico") || lowerName.contains("medico")) roleIcon = Icons.medical_services_outlined;
                      else if (lowerName.contains("nutricionista")) roleIcon = Icons.restaurant_menu_outlined;
                      else if (lowerName.contains("paciente")) roleIcon = Icons.person_outline_rounded;

                      return PopupMenuItem<int>(
                        value: r["id"] as int,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCurrent ? brandBlue.withValues(alpha: 0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isCurrent ? brandBlue.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  roleIcon,
                                  size: 16,
                                  color: isCurrent ? brandBlue : Colors.blueGrey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                roleName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                  color: isCurrent ? brandBlue : const Color(0xFF1E293B),
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 16),
                                const Icon(Icons.check_circle_rounded, color: brandBlue, size: 18)
                              ] else ...[
                                const SizedBox(width: 34),
                              ]
                            ],
                          ),
                        ),
                      );
                    }).toList();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(nombreRol,
                            style: GoogleFonts.montserrat(
                                color: brandGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: brandGreen, size: 16),
                      ],
                    ),
                  ),
                )
              else
                Text(nombreRol,
                    style: GoogleFonts.montserrat(
                        color: brandGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 19,
            backgroundColor: brandBlue.withValues(alpha: 0.08),
            child: Text(iniciales,
                style: const TextStyle(
                    color: brandBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
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
      if (categoryName.isNotEmpty && _isMenuExpanded) {
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
      } else if (categoryName.isNotEmpty && !_isMenuExpanded) {
        listItems.add(const SizedBox(height: 24));
      }

      final isExpanded = _categoryExpanded[categoryName] ?? true;
      if (isExpanded || !_isMenuExpanded) {
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
                    if (_isMenuExpanded) ...[
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
      width: _isMenuExpanded ? 280 : 85,
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
            opacity: _isMenuExpanded ? 1.0 : 0.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: _isMenuExpanded
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

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationProvider);
    final unreadCount = ref.read(notificationProvider.notifier).unreadCount;

    return unreadCount > 0
        ? Badge(
            label: Text(unreadCount.toString()),
            child: _buildBellIcon(),
          )
        : _buildBellIcon();
  }

  Widget _buildBellIcon() {
    return PopupMenuButton<void>(
      offset: const Offset(0, 50),
      icon: const Icon(Icons.notifications_none_rounded,
          color: Color(0xFF64748B), size: 26),
      tooltip: "Notificaciones",
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Text("Notificaciones",
              style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: const Color(0xFF0068B7))),
        ),
      ],
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
                      Icon(Icons.power_settings_new_rounded,
                          color: _isHovered ? brandBlue : Colors.white,
                          size: 16),
                      const SizedBox(width: 10),
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
