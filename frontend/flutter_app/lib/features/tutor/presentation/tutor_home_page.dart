import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import 'tutor_calendario_page.dart';
import 'tutor_recetas_page.dart';
import 'tutor_compras_page.dart';

class TutorHomePage extends ConsumerStatefulWidget {
  const TutorHomePage({super.key});

  @override
  ConsumerState<TutorHomePage> createState() => _TutorHomePageState();
}

class _TutorHomePageState extends ConsumerState<TutorHomePage> with TickerProviderStateMixin {
  int _bottomNavIndex = 0;
  int _oldBottomNavIndex = 0; 
  
  late final AnimationController _selectorController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _selectorAnimation = CurvedAnimation(
    parent: _selectorController,
    curve: Curves.easeOutBack, 
  );
  
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();

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
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final idPaciente = ref.watch(selectedPatientIdProvider);
    final patientsAsync = ref.watch(misPacientesProvider);
    
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

class _DashboardView extends ConsumerWidget {
  final String? idPaciente;
  const _DashboardView({required this.idPaciente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final planAsync = idPaciente != null
        ? ref.watch(planDiarioProvider((idPaciente: idPaciente!, fecha: DateTime.now())))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16), 
          Row(
            children: [
              Icon(Icons.schedule, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text("Hoy", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          planAsync.when(
            data: (meals) {
              if (meals.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No hay plan asignado para hoy")));
              
              final featured = meals.first;
              final upcoming = meals.skip(1).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FeaturedMealCard(meal: featured),
                  const SizedBox(height: 24),
                  if (upcoming.isNotEmpty) ...[
                    const Text("Próximas Comidas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...upcoming.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _UpcomingMealCard(meal: m),
                    )),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text("Error: $err")),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _FeaturedMealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  const _FeaturedMealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 160, decoration: const BoxDecoration(color: Color(0xFFE2E8F0), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: const Icon(Icons.restaurant, size: 64, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal["momento_nombre"] ?? "Comida", style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(meal["receta_nombre"] ?? "Sin nombre", style: theme.textTheme.headlineSmall),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: () {}, child: const Text("Ver Receta")),
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
  const _UpcomingMealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.fastfood, color: Colors.grey)),
        title: Text(meal["momento_nombre"] ?? ""),
        subtitle: Text(meal["receta_nombre"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
      ),
    );
  }
}
