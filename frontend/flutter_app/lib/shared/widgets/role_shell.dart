import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/state/app_providers.dart";
import "../../features/auth/login_page.dart";
import "../../features/roles/role_module_registry.dart";
import "../models/app_role.dart";
import "../../core/services/realtime_service.dart";
import "../../core/state/notification_provider.dart";

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

    final String nombreUsuario = perfilAsync.maybeWhen(
      data: (d) {
        final username = d["username"]?.toString().trim() ?? "";
        if (username.isNotEmpty) return username;
        final email = d["email"]?.toString().trim() ?? "";
        if (email.isNotEmpty) return email.split("@").first;
        return d["nombre_completo"]?.toString() ?? "Usuario";
      },
      orElse: () => session?.user.email?.split("@")[0] ??
                     session?.user.userMetadata?["username"] ??
                     "Usuario",
    );

    final String nombreRol = perfilAsync.maybeWhen(
      data: (d) => d["rol_nombre"]?.toString() ?? widget.role.label,
      orElse: () => widget.role.label,
    );
    
    final String iniciales = _obtenerIniciales(nombreUsuario);
    final isWide = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Gris muy claro limpio
      body: Column(
        children: [
          // 1. TOP BAR GLOBAL (MARCA ESTÁTICA ESTILO LOGIN)
          _buildGlobalHeader(nombreUsuario, nombreRol, iniciales, isWide),
          
          // 2. CUERPO: SIDEBAR + CONTENIDO (SIN RECUADRO LIMITANTE)
          Expanded(
            child: Row(
              children: [
                if (isWide) _buildSidebar(modules),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0), // Margen sutil respecto al menú
                    child: IndexedStack(
                      index: _index,
                      children: [for (final m in modules) m.builder()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalHeader(String nombre, String nombreRol, String iniciales, bool isWide) {
    const Color brandBlue = Color(0xFF0068B7);
    const Color brandGreen = Color(0xFF58A932);

    return Container(
      height: 75,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // SECCIÓN DE MARCA ESTÁTICA (ESTILO LOGIN)
          Container(
            width: isWide ? 280 : 200,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: brandBlue, size: 28),
                  onPressed: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
                ),
                const SizedBox(width: 8),
                Image.asset("assets/images/logo sin.png", width: 32, height: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    overflow: TextOverflow.clip,
                    text: TextSpan(
                      style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      children: const [
                        TextSpan(text: "Nutri", style: TextStyle(color: brandBlue)),
                        TextSpan(text: "Reuma", style: TextStyle(color: brandGreen)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // ACCIONES DE USUARIO
          const _NotificationBell(),
          const SizedBox(width: 24),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(nombre, style: GoogleFonts.montserrat(color: const Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w700)),
              Text(nombreRol.toUpperCase(), style: GoogleFonts.montserrat(color: brandGreen, fontSize: 10, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 19,
            backgroundColor: brandBlue.withOpacity(0.08),
            child: Text(iniciales, style: const TextStyle(color: brandBlue, fontWeight: FontWeight.bold, fontSize: 12)),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isMenuExpanded ? 280 : 85,
      color: companyBlue,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: modules.length,
              itemBuilder: (context, i) {
                final active = i == _index;
                return InkWell(
                  onTap: () => setState(() => _index = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: active ? selectionGreen : Colors.transparent,
                      border: active ? const Border(left: BorderSide(color: Colors.white, width: 4)) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(modules[i].icon, color: Colors.white, size: 24),
                        if (_isMenuExpanded) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              modules[i].title, 
                              style: GoogleFonts.montserrat(color: Colors.white, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 13),
                              softWrap: false,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // INDICADOR DE VERSIÓN SUTIL ABAJO
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isMenuExpanded ? 1.0 : 0.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: _isMenuExpanded 
                ? Text(
                    "REUMANUTRI V1.0", 
                    style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1),
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
      icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 26),
      tooltip: "Notificaciones",
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Text("NOTIFICACIONES", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF0068B7))),
        ),
        ...notifications.take(3).map((n) => PopupMenuItem<void>(
          child: Text(n.title, style: const TextStyle(fontSize: 12)),
        )),
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
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.power_settings_new_rounded, color: _isHovered ? brandBlue : Colors.white, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      "CERRAR SESIÓN", 
                      style: GoogleFonts.montserrat(
                        color: _isHovered ? brandBlue : Colors.white, 
                        fontWeight: FontWeight.w800, 
                        fontSize: 11,
                        letterSpacing: 0.5,
                      )
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
