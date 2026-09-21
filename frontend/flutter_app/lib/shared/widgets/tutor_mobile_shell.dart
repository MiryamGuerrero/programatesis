import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/services/realtime_service.dart";
import "../../core/services/notification_service.dart";
import "../../core/state/app_providers.dart";
import "../../features/roles/role_module_registry.dart";
import "../../features/tutor/presentation/widgets/tutor_tutorial_modal.dart";
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(realtimeServiceProvider).init();
      final debeVerFuture = tutorDebeVerTutorial();
      final notifService = ref.read(notificationServiceProvider);
      await notifService.init();
      await notifService.solicitarPermisos();

      // Mostrar el tutorial de inmediato tras responder al permiso de notificaciones
      if (mounted) {
        final debeVer = await debeVerFuture;
        if (debeVer && mounted) {
          mostrarTutorialTutor(context, initialIndex: 0, guardarVisto: true);
        }
      }

      // La sincronización de comidas se procesa en segundo plano sin retrasar la guía
      notifService.sincronizarNotificacionesPlanHoy();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(misPacientesProvider, (previous, next) {
      next.whenData((pacientes) {
        ref.read(notificationServiceProvider).sincronizarNotificacionesPlanHoy(
          pacientesInput: pacientes,
        );
      });
    });

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
                color: Colors.black.withValues(alpha: 0.05),
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
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Tooltip(
                message: "Guía y Ayuda",
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // Mapeo contextual: si está en Mi Paciente (_index == 0) abre en el paso de Pacientes (1)
                      // Si está en Mi Perfil (_index == 1) abre en el paso de Alertas/Perfil (4)
                      final int targetSlide = _index == 1 ? 4 : 1;
                      mostrarTutorialTutor(
                        context,
                        initialIndex: targetSlide,
                        guardarVisto: true,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 17,
                            color: brandBlue,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Ayuda",
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: brandBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
