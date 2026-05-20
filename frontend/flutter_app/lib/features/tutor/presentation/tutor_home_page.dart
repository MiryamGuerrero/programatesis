import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'tutor_calendario_page.dart';
import 'tutor_recetas_page.dart';
import 'tutor_compras_page.dart';

class TutorHomePage extends StatefulWidget {
  final String idPaciente;
  final String nombrePaciente;

  const TutorHomePage({
    super.key,
    required this.idPaciente,
    required this.nombrePaciente,
  });

  @override
  State<TutorHomePage> createState() => _TutorHomePageState();
}

class _TutorHomePageState extends State<TutorHomePage> with TickerProviderStateMixin {
  int _bottomNavIndex = 0;
  int _oldBottomNavIndex = 0; 
  late String _nombrePacienteActual = widget.nombrePaciente;
  
  // CONTROLADORES PARA EL SELECTOR ANIMADO
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

  final List<Map<String, String>> _pacientes = [
    {"nombre": "Carlos Ruiz", "detalle": "8 años · AIJ Oligoarticular"},
    {"nombre": "Sofía Méndez", "detalle": "6 años · AIJ Poliarticular"},
    {"nombre": "Juan Pérez", "detalle": "10 años · AIJ Sistémica"},
  ];

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
    {"titulo": "Compras", "subtitulo": "Semana 1"},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<Widget> _vistas = [
      _buildDashboard(context),
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20, 
              ),
            ),
            Text(
              _appBarData[_bottomNavIndex]["subtitulo"]!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          _buildPatientSelector(context),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.topCenter, // Mantiene la estabilidad vertical
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          // EXTRACCIÓN SEGURA DE KEY PARA EVITAR CRASH
          final childKey = child.key;
          int childKeyIndex = -1;
          if (childKey is ValueKey<int>) {
            childKeyIndex = childKey.value;
          }
          
          final bool isForward = _bottomNavIndex >= _oldBottomNavIndex;
          
          Offset beginOffset;
          if (childKeyIndex == _bottomNavIndex) {
            beginOffset = isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
          } else {
            beginOffset = isForward ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
          }
          
          return SlideTransition(
            position: animation.drive(Tween<Offset>(begin: beginOffset, end: Offset.zero)),
            child: child,
          );
        },
        // EL KEY DEBE ESTAR EN EL HIJO DIRECTO
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
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Hoy",
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: "Calendario",
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: "Recetas",
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: "Compras",
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                      child: Container(color: Colors.black.withOpacity(0.1)),
                    ),
                  ),
                  Positioned(
                    width: 280,
                    child: CompositedTransformFollower(
                      link: _layerLink,
                      targetAnchor: Alignment.bottomRight,
                      followerAnchor: Alignment.topRight,
                      offset: const Offset(0, 8),
                      child: ScaleTransition(
                        scale: _selectorAnimation,
                        alignment: Alignment.topRight,
                        child: FadeTransition(
                          opacity: _selectorController,
                          child: Card(
                            elevation: 8,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "CAMBIAR PACIENTE",
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF94A3B8),
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Divider(height: 1),
                                      ],
                                    ),
                                  ),
                                  ..._pacientes.map((p) => ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: colorScheme.primaryContainer,
                                      child: Icon(Icons.person_outline, color: colorScheme.primary, size: 20),
                                    ),
                                    title: Text(p["nombre"]!, style: theme.textTheme.titleSmall),
                                    subtitle: Text(p["detalle"]!, style: theme.textTheme.bodySmall),
                                    trailing: p["nombre"] == _nombrePacienteActual 
                                      ? Icon(Icons.check_outlined, color: AppTema.verdeSalud, size: 18)
                                      : null,
                                    onTap: () {
                                      setState(() => _nombrePacienteActual = p["nombre"]!);
                                      _toggleSelector();
                                    },
                                  )),
                                ],
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _nombrePacienteActual.split(' ').first,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    AnimatedBuilder(
                      animation: _selectorController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _selectorController.value * 3.14159,
                          child: const Icon(
                            Icons.keyboard_arrow_down_outlined,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(), // Evita efectos de rebote que causan saltos
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16), 
          Row(
            children: [
              Icon(Icons.schedule, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                "Ahora · 7:30 AM",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _FeaturedMealCard(),
          const SizedBox(height: 24),
          Text(
            "Próximas Comidas",
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          const _UpcomingMealCard(
            horaCategoria: "10:00 · Snack Mañana",
            nombre: "Yogur con Nueces",
            planBadge: "Plan Sistema",
          ),
          const SizedBox(height: 16),
          const _UpcomingMealCard(
            horaCategoria: "13:30 · Almuerzo",
            nombre: "Pechuga de Pollo a la Plancha",
            planBadge: "Plan Sistema",
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _FeaturedMealCard extends StatelessWidget {
  const _FeaturedMealCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Container(
                height: 180,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Icon(Icons.restaurant, size: 64, color: Colors.white.withOpacity(0.5)),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    "Desayuno",
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_offer_outlined, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "Plan Nutricionista",
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Huevos Revueltos con Espinaca",
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  "Una comida rica en proteínas y hierro, ideal para empezar el día con energía.",
                  style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                    children: [
                      const TextSpan(text: "Porción: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: "1 tazón (250g)"),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double btnWidth = (constraints.maxWidth - 12) / 2;
                    // Ajuste dinámico de fuente basado en el ancho disponible
                    final double fontSize = btnWidth < 140 ? 11 : 13;
                    
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {},
                            child: const Text("Ver Receta Completa"),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: btnWidth,
                              child: FilledButton.tonal(
                                onPressed: () {},
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
  final String horaCategoria;
  final String nombre;
  final String planBadge;

  const _UpcomingMealCard({
    required this.horaCategoria,
    required this.nombre,
    required this.planBadge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.fastfood, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      horaCategoria,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nombre,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        planBadge,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}
