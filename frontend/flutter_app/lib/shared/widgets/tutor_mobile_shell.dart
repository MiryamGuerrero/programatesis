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
  int _oldIndex = 0; // Tracker para la dirección

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modules = modulesForRole(AppRole.tutor);
    if (_index >= modules.length) _index = 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: _buildAppBar(context),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final int childIndex = (child.key as ValueKey<int>).value;
            final bool isForward = _index >= _oldIndex;

            Offset beginOffset;
            if (childIndex == _index) {
              // El que entra
              beginOffset =
                  isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
            } else {
              // El que sale
              beginOffset =
                  isForward ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
            }

            return SlideTransition(
              position: animation
                  .drive(Tween<Offset>(begin: beginOffset, end: Offset.zero)),
              child: child,
            );
          },
          child: Container(
            key: ValueKey<int>(_index),
            child: modules[_index].builder(),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            if (i != _index) {
              setState(() {
                _oldIndex = _index;
                _index = i;
              });
            }
          },
          destinations: modules
              .map((m) => NavigationDestination(
                    icon: Icon(m.icon),
                    label: m.title,
                  ))
              .toList(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    const Color brandGreen = Color(0xFF70A81C);

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          // Logo placeholder if image is missing
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: brandBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.health_and_safety_outlined,
                color: brandBlue, size: 20),
          ),
          const SizedBox(width: 12),
          RichText(
            text: TextSpan(
              style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
              children: [
                TextSpan(text: "Nutri", style: TextStyle(color: brandBlue)),
                const TextSpan(
                    text: "Reuma", style: TextStyle(color: brandGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
