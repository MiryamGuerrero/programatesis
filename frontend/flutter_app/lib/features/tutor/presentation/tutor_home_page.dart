import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_responsive.dart';
import 'tutor_calendario_page.dart';
import 'tutor_recetas_page.dart';
import 'tutor_compras_page.dart';
import 'tutor_gustos_page.dart';
import 'onboarding_gustos_page.dart';
import 'widgets/generar_plan_automatico_modal.dart';
import 'widgets/tutor_home_widgets.dart';

class TutorHomePage extends ConsumerStatefulWidget {
  const TutorHomePage({super.key});

  @override
  ConsumerState<TutorHomePage> createState() => _TutorHomePageState();
}

class _TutorHomePageState extends ConsumerState<TutorHomePage>
    with TickerProviderStateMixin {
  int _bottomNavIndex = 0;
  int _oldBottomNavIndex = 0;
  bool _showOnboarding = false;
  bool _checkingOnboarding = true;

  late final AnimationController _selectorController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );

  late final Animation<double> _selectorScaleAnimation = Tween<double>(
    begin: 0.82,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _selectorController,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  ));

  late final Animation<Offset> _selectorSlideAnimation = Tween<Offset>(
    begin: const Offset(0.04, -0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _selectorController,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  ));

  late final Animation<double> _selectorFadeAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _selectorController,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  ));

  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    if (idPaciente == null) {
      setState(() => _checkingOnboarding = false);
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('tutor/verificar-onboarding/$idPaciente');
      if (mounted) {
        setState(() {
          _showOnboarding = !(resp.data['configuradas'] ?? false);
          _checkingOnboarding = false;
        });
      }
    } catch (e) {
      debugPrint("Error verificando onboarding: $e");
      if (mounted) setState(() => _checkingOnboarding = false);
    }
  }

  @override
  void dispose() {
    _selectorController.dispose();
    super.dispose();
  }

  void _toggleSelector() {
    if (_overlayController.isShowing) {
      _selectorController.reverse().then((_) => _overlayController.hide());
    } else {
      _overlayController.show();
      _selectorController.forward();
    }
  }

  final List<Map<String, String>> _appBarData = [
    {"titulo": "Hoy", "subtitulo": "Plan de alimentación"},
    {"titulo": "Calendario", "subtitulo": "Agenda de alimentación"},
    {"titulo": "Recetas", "subtitulo": "Explora opciones seguras"},
    {"titulo": "Compras", "subtitulo": "Próxima semana"},
    {"titulo": "Gustos", "subtitulo": "Preferencias del paciente"},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final idPaciente = ref.watch(selectedPatientIdProvider);
    final patientsAsync = ref.watch(misPacientesProvider);

    if (_checkingOnboarding) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_showOnboarding && idPaciente != null) {
      return OnboardingGustosPage(
        idPaciente: idPaciente,
        onCompletado: () => setState(() => _showOnboarding = false),
      );
    }

    String nombrePaciente = "Seleccionar";
    if (idPaciente != null) {
      patientsAsync.whenData((list) {
        try {
          final p = list.firstWhere((p) => p["id"].toString() == idPaciente);
          nombrePaciente = (p["nombre_completo"] as String).split(' ').first;
        } catch (_) {}
      });
    }

    final List<Widget> vistas = [
      DashboardView(idPaciente: idPaciente),
      const TutorCalendarioPage(),
      const TutorRecetasPage(),
      const TutorComprasPage(),
      const TutorGustosPage(),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _appBarData[_bottomNavIndex]["titulo"]!,
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: AppTextSizes.title(context.screenWidth)),
            ),
            Text(
              _appBarData[_bottomNavIndex]["subtitulo"]!,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: AppTextSizes.caption(context.screenWidth)),
            ),
          ],
        ),
        actions: [
          _buildPatientSelector(context, nombrePaciente, patientsAsync),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final currentIdPaciente = ref.read(selectedPatientIdProvider);
          final now = DateTime.now();

          ref.invalidate(planDiarioProvider);
          ref.invalidate(misPacientesProvider);
          ref.invalidate(listaComprasProvider);

          if (currentIdPaciente != null) {
            ref.invalidate(diasConPlanProvider((
              idPaciente: currentIdPaciente,
              mes: now.month,
              anio: now.year
            )));
          }

          await Future.delayed(const Duration(milliseconds: 800));
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final childKey = child.key;
            int childKeyIndex =
                (childKey is ValueKey<int>) ? childKey.value : -1;
            final bool isForward = _bottomNavIndex >= _oldBottomNavIndex;
            Offset beginOffset = (childKeyIndex == _bottomNavIndex)
                ? (isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0))
                : (isForward
                    ? const Offset(-1.0, 0.0)
                    : const Offset(1.0, 0.0));
            return SlideTransition(
              position: animation
                  .drive(Tween<Offset>(begin: beginOffset, end: Offset.zero)),
              child: child,
            );
          },
          child: SizedBox.expand(
            key: ValueKey<int>(_bottomNavIndex),
            child: ResponsiveMaxConstraints(child: vistas[_bottomNavIndex]),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF0171BB).withOpacity(0.08),
          surfaceTintColor: Colors.transparent,
          height: context.responsiveValue(mobile: 80, tablet: 90),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF0171BB), size: 24);
            }
            return const IconThemeData(color: Color(0xFF64748B), size: 24);
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
          selectedIndex: _bottomNavIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            if (index != _bottomNavIndex) {
              if (index == 0) {
                ref.invalidate(tipSaludableProvider);
              }
              setState(() {
                _oldBottomNavIndex = _bottomNavIndex;
                _bottomNavIndex = index;
              });
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: "Hoy"),
            NavigationDestination(
                icon: Icon(Icons.calendar_month_rounded), label: "Calendario"),
            NavigationDestination(
                icon: Icon(Icons.menu_book_rounded), label: "Recetas"),
            NavigationDestination(
                icon: Icon(Icons.shopping_cart_rounded), label: "Compras"),
            NavigationDestination(
                icon: Icon(Icons.favorite_rounded), label: "Gustos"),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSelector(BuildContext context, String nombre,
      AsyncValue<List<Map<String, dynamic>>> patientsAsync) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Center(
        child: CompositedTransformTarget(
          link: _layerLink,
          child: OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: (context) {
              return Stack(
                children: [
                  GestureDetector(
                      onTap: _toggleSelector,
                      child: FadeTransition(
                          opacity: _selectorController,
                          child:
                              Container(color: Colors.black.withOpacity(0.1)))),
                  Positioned(
                    width: 280,
                    child: CompositedTransformFollower(
                      link: _layerLink,
                      targetAnchor: Alignment.bottomRight,
                      followerAnchor: Alignment.topRight,
                      offset: const Offset(0, 8),
                      child: SlideTransition(
                        position: _selectorSlideAnimation,
                        child: ScaleTransition(
                          scale: _selectorScaleAnimation,
                          alignment: Alignment.topRight,
                          child: FadeTransition(
                            opacity: _selectorFadeAnimation,
                            child: Card(
                              elevation: 12,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(
                                    color: Color(0xFFE2E8F0), width: 1),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: patientsAsync.when(
                                  data: (list) {
                                    final idPaciente =
                                        ref.watch(selectedPatientIdProvider);
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 10, 16, 6),
                                          child: Row(
                                            children: [
                                              Icon(Icons.swap_horiz_rounded,
                                                  size: 16,
                                                  color: colorScheme.primary),
                                              const SizedBox(width: 8),
                                              Text(
                                                "CAMBIAR PACIENTE",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      const Color(0xFF64748B),
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(
                                            height: 10,
                                            thickness: 1,
                                            color: Color(0xFFF1F5F9)),
                                        ...list.map((p) {
                                          final isSelected =
                                              p["id"].toString() == idPaciente;
                                          return ListTile(
                                            dense: true,
                                            visualDensity:
                                                VisualDensity.compact,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 2),
                                            leading: CircleAvatar(
                                              radius: 14,
                                              backgroundColor: isSelected
                                                  ? colorScheme.primary
                                                  : const Color(0xFFF1F5F9),
                                              child: Icon(
                                                Icons.person_rounded,
                                                size: 16,
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                            title: Text(
                                              p["nombre_completo"]!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? colorScheme.primary
                                                    : AppTema.azulOscuro,
                                              ),
                                            ),
                                            trailing: isSelected
                                                ? Icon(
                                                    Icons.check_circle_rounded,
                                                    color: colorScheme.primary,
                                                    size: 18)
                                                : null,
                                            onTap: () {
                                              ref
                                                  .read(
                                                      selectedPatientIdProvider
                                                          .notifier)
                                                  .state = p["id"].toString();
                                              _toggleSelector();
                                              _checkOnboardingStatus();
                                            },
                                          );
                                        }),
                                      ],
                                    );
                                  },
                                  loading: () => const SizedBox(
                                      height: 100,
                                      child: Center(
                                          child: CircularProgressIndicator())),
                                  error: (err, _) => Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text("Error: $err")),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            child: InkWell(
              onTap: _toggleSelector,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: colorScheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.person_outline,
                            color: Colors.white, size: 14)),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(nombre,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontSize: 14),
                            overflow: TextOverflow.visible)),
                    const Icon(Icons.keyboard_arrow_down_outlined,
                        color: Color(0xFF64748B), size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
