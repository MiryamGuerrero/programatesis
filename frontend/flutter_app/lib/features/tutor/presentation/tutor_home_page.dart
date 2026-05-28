import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import 'tutor_calendario_page.dart';
import 'tutor_recetas_page.dart';
import 'tutor_compras_page.dart';
import 'tutor_gustos_page.dart';
import 'onboarding_gustos_page.dart';
import 'tutor_receta_detalle_page.dart';

class TutorHomePage extends ConsumerStatefulWidget {
  const TutorHomePage({super.key});

  @override
  ConsumerState<TutorHomePage> createState() => _TutorHomePageState();
}

class _TutorHomePageState extends ConsumerState<TutorHomePage> with TickerProviderStateMixin {
  int _bottomNavIndex = 0;
  int _oldBottomNavIndex = 0; 
  bool _showOnboarding = false;
  bool _checkingOnboarding = true;
  
  late AnimationController _selectorController;
  late Animation<double> _selectorAnimation;
  
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _selectorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _selectorAnimation = CurvedAnimation(
      parent: _selectorController,
      curve: Curves.easeOutBack, 
    );
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

    final List<Widget> _vistas = [
      _DashboardView(idPaciente: idPaciente),
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
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              _appBarData[_bottomNavIndex]["subtitulo"]!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          _buildPatientSelector(context, nombrePaciente, patientsAsync),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final childKey = child.key;
          int childKeyIndex = (childKey is ValueKey<int>) ? childKey.value : -1;
          final bool isForward = _bottomNavIndex >= _oldBottomNavIndex;
          Offset beginOffset = (childKeyIndex == _bottomNavIndex) 
              ? (isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0))
              : (isForward ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0));
          return SlideTransition(
            position: animation.drive(Tween<Offset>(begin: beginOffset, end: Offset.zero)),
            child: child,
          );
        },
        child: SizedBox.expand(
          key: ValueKey<int>(_bottomNavIndex), 
          child: _vistas[_bottomNavIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (index) {
          if (index != _bottomNavIndex) {
            setState(() {
              _oldBottomNavIndex = _bottomNavIndex;
              _bottomNavIndex = index;
            });
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "Hoy"),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: "Calendario"),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: "Recetas"),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: "Compras"),
          NavigationDestination(icon: Icon(Icons.favorite_outline_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: "Gustos"),
        ],
      ),
    );
  }

  Widget _buildPatientSelector(BuildContext context, String nombre, AsyncValue<List<Map<String, dynamic>>> patientsAsync) {
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
                  GestureDetector(onTap: _toggleSelector, child: FadeTransition(opacity: _selectorController, child: Container(color: Colors.black.withOpacity(0.1)))),
                  Positioned(
                    width: 280,
                    child: CompositedTransformFollower(
                      link: _layerLink, targetAnchor: Alignment.bottomRight, followerAnchor: Alignment.topRight, offset: const Offset(0, 8),
                      child: ScaleTransition(
                        scale: _selectorAnimation, alignment: Alignment.topRight,
                        child: FadeTransition(
                          opacity: _selectorController,
                          child: Card(
                            elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: patientsAsync.when(
                                data: (list) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Padding(padding: EdgeInsets.all(16), child: Text("CAMBIAR PACIENTE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                    ...list.map((p) => ListTile(
                                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                                      title: Text(p["nombre_completo"]!),
                                      onTap: () {
                                        ref.read(selectedPatientIdProvider.notifier).state = p["id"].toString();
                                        _toggleSelector();
                                        _checkOnboardingStatus(); 
                                      },
                                    )),
                                  ],
                                ),
                                loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                                error: (err, _) => Padding(padding: const EdgeInsets.all(16), child: Text("Error: $err")),
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
              onTap: _toggleSelector, borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(24)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle), child: const Icon(Icons.person_outline, color: Colors.white, size: 14)),
                    const SizedBox(width: 8),
                    Text(nombre, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                    const Icon(Icons.keyboard_arrow_down_outlined, color: Color(0xFF64748B), size: 18),
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

class _DashboardView extends ConsumerStatefulWidget {
  final String? idPaciente;
  const _DashboardView({required this.idPaciente});

  @override
  ConsumerState<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<_DashboardView> {
  final GlobalKey _activeKey = GlobalKey();
  bool _hasScrolled = false;

  Future<void> _toggleConsumida(int idPlanItem, bool currentStatus) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('tutor/marcar-consumida', data: {
        "id_plan_item": idPlanItem,
        "consumida": !currentStatus,
      });
      ref.invalidate(planDiarioProvider);
    } catch (e) {
      debugPrint("Error marcando consumo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final planAsync = widget.idPaciente != null
        ? ref.watch(planDiarioProvider((idPaciente: widget.idPaciente!, fecha: today)))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return planAsync.when(
      data: (meals) {
        if (meals.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No hay plan nutricional para hoy")));
        }

        final Map<int, List<Map<String, dynamic>>> grouped = {};
        final List<int> momentOrder = [];
        for (var m in meals) {
          final idMom = m["id_momento"] as int;
          if (!grouped.containsKey(idMom)) {
            grouped[idMom] = [];
            momentOrder.add(idMom);
          }
          grouped[idMom]!.add(m);
        }

        int? featuredMomentId;
        final currentTimeInMinutes = now.hour * 60 + now.minute;

        for (var momId in momentOrder) {
          final firstMeal = grouped[momId]!.first;
          final startStr = firstMeal["momento_hora_inicio"]?.toString();
          final endStr = firstMeal["momento_hora_fin"]?.toString();
          if (startStr != null && endStr != null) {
            final startParts = startStr.split(':');
            final endParts = endStr.split(':');
            final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
            final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

            if (currentTimeInMinutes >= startMin && currentTimeInMinutes <= endMin) {
              featuredMomentId = momId;
              break;
            }
          }
        }

        if (featuredMomentId == null) {
          for (var momId in momentOrder) {
            final firstMeal = grouped[momId]!.first;
            final startStr = firstMeal["momento_hora_inicio"]?.toString();
            if (startStr != null) {
              final startParts = startStr.split(':');
              final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
              if (currentTimeInMinutes < startMin) {
                featuredMomentId = momId;
                break;
              }
            }
          }
        }

        featuredMomentId ??= momentOrder.first;

        if (!_hasScrolled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_activeKey.currentContext != null) {
              Scrollable.ensureVisible(_activeKey.currentContext!, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic, alignment: 0.05);
              if (mounted) setState(() => _hasScrolled = true);
            }
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: momentOrder.map((momId) {
              final isFeatured = momId == featuredMomentId;
              final momentMeals = grouped[momId]!;
              return Container(
                key: isFeatured ? _activeKey : null,
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isFeatured ? Icons.stars : Icons.access_time_filled_rounded, color: isFeatured ? colorScheme.primary : Colors.grey.shade400, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          momentMeals.first["momento_nombre"].toString().toUpperCase(),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: isFeatured ? colorScheme.primary : Colors.grey.shade700),
                        ),
                        const Spacer(),
                        _buildStatusBadge(momentMeals, currentTimeInMinutes),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...momentMeals.map((m) {
                      final bool isConsumida = m["consumida"] == true;
                      
                      // Lógica de visibilidad del check verde
                      final String? startStr = m["momento_hora_inicio"]?.toString();
                      bool isPastOrCurrent = true;
                      if (startStr != null) {
                        final parts = startStr.split(':');
                        final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                        if (currentTimeInMinutes < startMin) {
                          isPastOrCurrent = false;
                        }
                      }

                      return Padding(
                        padding: EdgeInsets.only(bottom: isFeatured ? 20 : 12),
                        child: (isFeatured && !isConsumida) 
                            ? _FeaturedMealCard(
                                meal: m, 
                                onConsumida: () => _toggleConsumida(m["id_plan_item"], isConsumida)
                              ) 
                            : _UpcomingMealCard(
                                meal: m, 
                                isConsumida: isConsumida,
                                showCheckButton: isPastOrCurrent,
                                onToggleConsumida: isPastOrCurrent ? () => _toggleConsumida(m["id_plan_item"], isConsumida) : null,
                              ),
                      );
                    }),
                    if (!isFeatured && momId != momentOrder.last)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Divider(color: Colors.grey.shade200)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text("Error: $err")),
    );
  }

  Widget _buildStatusBadge(List<Map<String, dynamic>> meals, int currentMin) {
    final first = meals.first;
    final startStr = first["momento_hora_inicio"]?.toString();
    final endStr = first["momento_hora_fin"]?.toString();
    if (startStr == null || endStr == null) return const SizedBox();

    final startMin = int.parse(startStr.split(':')[0]) * 60 + int.parse(startStr.split(':')[1]);
    final endMin = int.parse(endStr.split(':')[0]) * 60 + int.parse(endStr.split(':')[1]);

    final allConsumida = meals.every((m) => m["consumida"] == true);
    
    String label = "";
    Color color = Colors.grey;

    if (currentMin >= startMin && currentMin <= endMin) {
      label = allConsumida ? "COMPLETADO" : "AHORA";
      color = allConsumida ? AppTema.verdeSalud : AppTema.azulPrincipal;
    } else if (currentMin < startMin) {
      label = "SIGUIENTE";
      color = Colors.blueGrey;
    } else {
      label = allConsumida ? "FINALIZADO" : "PENDIENTE";
      color = allConsumida ? Colors.grey : Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _FeaturedMealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final VoidCallback onConsumida;
  const _FeaturedMealCard({required this.meal, required this.onConsumida});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final String url = meal["receta_url_imagen"] ?? "";

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 200,
            color: const Color(0xFFE2E8F0),
            child: url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.restaurant, size: 48, color: Colors.white))
                : const Icon(Icons.restaurant, size: 64, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal["receta_nombre"] ?? "Sin nombre", 
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24, 
                    color: colorScheme.onSurface,
                  ),
                ),
                if (meal["receta_descripcion"] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      meal["receta_descripcion"],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double btnWidth = (constraints.maxWidth - 12) / 2;
                    final double fontSize = btnWidth < 140 ? 11 : 13;
                    
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              final idReceta = meal["id_receta"];
                              if (idReceta != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TutorRecetaDetallePage(idReceta: idReceta as int),
                                  ),
                                );
                              }
                            },
                            child: const Text("Ver Receta Completa"),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: btnWidth,
                              child: FilledButton.tonal(
                                onPressed: onConsumida,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTema.verdeSalud,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check, size: 16),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        "Consumida",
                                        style: TextStyle(fontSize: fontSize),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: btnWidth,
                              child: OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.autorenew, size: 16),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        "Cambiar",
                                        style: TextStyle(fontSize: fontSize),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingMealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final bool isConsumida;
  final bool showCheckButton;
  final VoidCallback? onToggleConsumida;
  
  const _UpcomingMealCard({
    required this.meal, 
    this.isConsumida = false, 
    this.showCheckButton = true,
    this.onToggleConsumida
  });

  @override
  Widget build(BuildContext context) {
    final String url = meal["receta_url_imagen"] ?? "";
    final theme = Theme.of(context);
    
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isConsumida ? BorderSide(color: AppTema.verdeSalud.withOpacity(0.5), width: 1.5) : BorderSide.none,
      ),
      elevation: isConsumida ? 0 : 1,
      color: isConsumida ? Colors.grey.shade50 : Colors.white,
      child: ListTile(
        onTap: () {
          final idReceta = meal["id_receta"];
          if (idReceta != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => TutorRecetaDetallePage(idReceta: idReceta as int)));
          }
        },
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            Container(
              width: 54, height: 54, 
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.fastfood, color: Colors.grey))
                  : const Icon(Icons.fastfood, color: Colors.grey),
            ),
            if (isConsumida)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: AppTema.verdeSalud, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          meal["receta_nombre"] ?? "Sin nombre",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isConsumida ? Colors.grey : null,
            decoration: isConsumida ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: isConsumida 
            ? const Text("Consumida", style: TextStyle(color: AppTema.verdeSalud, fontWeight: FontWeight.bold, fontSize: 12))
            : (meal["receta_descripcion"] != null 
                ? Text(meal["receta_descripcion"], maxLines: 1, overflow: TextOverflow.ellipsis)
                : null),
        trailing: isConsumida 
            ? IconButton(
                icon: const Icon(Icons.undo_rounded, size: 20, color: Colors.grey),
                tooltip: "Desmarcar",
                onPressed: onToggleConsumida,
              )
            : (showCheckButton 
                ? IconButton(
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 24, color: AppTema.verdeSalud),
                    tooltip: "Marcar como consumida",
                    onPressed: onToggleConsumida,
                  )
                : const SizedBox(width: 48)), // Empty space to keep layout balanced
      ),
    );
  }
}
