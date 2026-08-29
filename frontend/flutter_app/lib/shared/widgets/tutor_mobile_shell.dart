import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../features/roles/role_module_registry.dart";
import "../models/app_role.dart";

class TutorMobileShell extends ConsumerStatefulWidget {
  const TutorMobileShell({super.key});

  @override
  ConsumerState<TutorMobileShell> createState() => _TutorMobileShellState();
}

class _TutorMobileShellState extends ConsumerState<TutorMobileShell> {
  int _index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
        body: PageView.builder(
          controller: _pageController,
          itemCount: modules.length,
          onPageChanged: (i) {
            if (i != _index) {
              setState(() {
                _index = i;
              });
            }
          },
          itemBuilder: (context, i) {
            return _KeepAliveWrapper(
              key: ValueKey(modules[i].key),
              child: modules[i].builder(),
            );
          },
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
            border: const Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              if (i != _index) {
                setState(() {
                  _index = i;
                });
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(i);
                }
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
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    const Color brandGreen = Color(0xFF70A81C);

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: Row(
            children: [
              Image.asset(
                "assets/images/logo_reuma_nutri.png",
                width: 32,
                height: 32,
                filterQuality: FilterQuality.high,
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
