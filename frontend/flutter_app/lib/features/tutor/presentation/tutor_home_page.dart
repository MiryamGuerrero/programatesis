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

class _TutorHomePageState extends State<TutorHomePage> {
  int _bottomNavIndex = 0;

  // Datos dinámicos para la AppBar
  final List<Map<String, String>> _appBarData = [
    {"titulo": "Inicio", "subtitulo": "Plan de alimentación"},
    {"titulo": "Calendario", "subtitulo": "Agenda de alimentación"},
    {"titulo": "Recetas", "subtitulo": "Explora opciones seguras"},
    {"titulo": "Compras", "subtitulo": "Semana 1"},
  ];

  @override
  Widget build(BuildContext context) {
    final Color colorFondo = AppTema.grisFondo;
    final Color colorTitulo = const Color(0xFF1E293B);
    final Color colorSubtitulo = const Color(0xFF64748B);
    final Color colorAcento = AppTema.azulPrincipal;
    final Color colorVerde = AppTema.verdeSalud;

    // Lista de vistas (ahora solo el cuerpo de cada página)
    final List<Widget> _vistas = [
      _buildDashboard(colorFondo, colorTitulo, colorSubtitulo, colorAcento, colorVerde),
      const TutorCalendarioPage(),
      const TutorRecetasPage(),
      const TutorComprasPage(),
    ];

    return Scaffold(
      backgroundColor: colorFondo,
      // AppBar UNIFICADA Y DINÁMICA
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0, // Ajustado para que el botón de atrás y el título se vean bien
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _appBarData[_bottomNavIndex]["titulo"]!,
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorTitulo,
              ),
            ),
            Text(
              _appBarData[_bottomNavIndex]["subtitulo"]!,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: colorSubtitulo,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorFondo,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorAcento.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_outline, color: colorAcento, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.nombrePaciente.split(' ').first,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorTitulo,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8), size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _bottomNavIndex,
        children: _vistas,
      ),
      bottomNavigationBar: Container(
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
          currentIndex: _bottomNavIndex,
          onTap: (index) => setState(() => _bottomNavIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: colorAcento,
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.lato(fontWeight: FontWeight.normal, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Hoy",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              label: "Calendario",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              label: "Recetas",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              label: "Compras",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(Color colorFondo, Color colorTitulo, Color colorSubtitulo, Color colorAcento, Color colorVerde) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.schedule, color: colorAcento, size: 20),
              const SizedBox(width: 8),
              Text(
                "Ahora · 7:30 AM",
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorAcento,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FeaturedMealCard(
            colorTitulo: colorTitulo,
            colorSubtitulo: colorSubtitulo,
            colorAcento: colorAcento,
            colorVerde: colorVerde,
          ),
          const SizedBox(height: 24),
          Text(
            "Próximas Comidas",
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorTitulo,
            ),
          ),
          const SizedBox(height: 16),
          _UpcomingMealCard(
            horaCategoria: "10:00 · Snack Mañana",
            nombre: "Yogur con Nueces",
            planBadge: "Plan Sistema",
            colorTitulo: colorTitulo,
            colorSubtitulo: colorSubtitulo,
            colorAcento: colorAcento,
          ),
          const SizedBox(height: 16),
          _UpcomingMealCard(
            horaCategoria: "13:30 · Almuerzo",
            nombre: "Pechuga de Pollo a la Plancha",
            planBadge: "Plan Sistema",
            colorTitulo: colorTitulo,
            colorSubtitulo: colorSubtitulo,
            colorAcento: colorAcento,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ... Mantener las clases _FeaturedMealCard y _UpcomingMealCard ...
class _FeaturedMealCard extends StatelessWidget {
  final Color colorTitulo;
  final Color colorSubtitulo;
  final Color colorAcento;
  final Color colorVerde;

  const _FeaturedMealCard({
    required this.colorTitulo,
    required this.colorSubtitulo,
    required this.colorAcento,
    required this.colorVerde,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Container(
                height: 180,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
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
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorAcento,
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
                    color: colorAcento,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_offer_outlined, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "Plan Nutricionista",
                        style: GoogleFonts.lato(
                          fontSize: 12,
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
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorTitulo,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Una comida rica en proteínas y hierro, ideal para empezar el día con energía.",
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: colorSubtitulo,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.lato(fontSize: 14, color: colorSubtitulo),
                    children: [
                      const TextSpan(text: "Porción: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: "1 tazón (250g)"),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorAcento,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      "Ver Receta Completa",
                      style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            "Consumida",
                            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorVerde,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.autorenew, size: 18, color: colorAcento),
                          label: Text(
                            "Otra Receta",
                            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: colorAcento),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: colorAcento.withOpacity(0.5)),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
  final Color colorTitulo;
  final Color colorSubtitulo;
  final Color colorAcento;

  const _UpcomingMealCard({
    required this.horaCategoria,
    required this.nombre,
    required this.planBadge,
    required this.colorTitulo,
    required this.colorSubtitulo,
    required this.colorAcento,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: colorSubtitulo,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nombre,
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorTitulo,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorAcento.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          planBadge,
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorAcento,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
