import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../core/state/app_providers.dart";
import "../../features/auth/login_page.dart";
import "../../features/roles/role_module_registry.dart";
import "../models/app_role.dart";

class TutorMobileShell extends ConsumerStatefulWidget {
  const TutorMobileShell({super.key});

  @override
  ConsumerState<TutorMobileShell> createState() => _TutorMobileShellState();
}

class _TutorMobileShellState extends ConsumerState<TutorMobileShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final modules = modulesForRole(AppRole.tutor);
    if (_index >= modules.length) _index = 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _index,
        children: [for (final m in modules) m.builder()],
      ),
      bottomNavigationBar: _buildBottomNav(modules),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    const Color brandBlue = Color(0xFF0068B7);
    const Color brandGreen = Color(0xFF58A932);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Image.asset("assets/images/logo sin.png", width: 32, height: 32),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              children: const [
                TextSpan(text: "Nutri", style: TextStyle(color: brandBlue)),
                TextSpan(text: "Reuma", style: TextStyle(color: brandGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(List<RoleModule> modules) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0068B7),
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w500, fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: modules.map((m) => BottomNavigationBarItem(
          icon: Icon(m.icon),
          label: m.title,
        )).toList(),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cerrar Sesión"),
        content: const Text("¿Estás seguro de que deseas salir?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("SÍ, SALIR")),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }
}
