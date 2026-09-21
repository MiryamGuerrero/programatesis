import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../../../core/theme/app_theme.dart";

/// Clave de almacenamiento local para registrar si el tutor ya vio o saltó el tutorial.
const String _kPrefTutorialTutorVisto = "tutorial_tutor_completado_v1";

/// Muestra el modal interactivo del tutorial para el Tutor.
/// Permite especificar un [initialIndex] (0 a 4) para abrir directamente la sección
/// contextual que el tutor está consultando.
Future<void> mostrarTutorialTutor(
  BuildContext context, {
  int initialIndex = 0,
  bool guardarVisto = true,
}) async {
  if (guardarVisto) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefTutorialTutorVisto, true);
    } catch (e) {
      debugPrint("Error guardando estado de tutorial: $e");
    }
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => TutorTutorialModal(initialIndex: initialIndex),
  );
}

/// Comprueba si el tutor aún no ha visto el tutorial para mostrárselo automáticamente.
Future<bool> tutorDebeVerTutorial() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kPrefTutorialTutorVisto) ?? false);
  } catch (_) {
    return false;
  }
}

class TutorTutorialModal extends StatefulWidget {
  final int initialIndex;

  const TutorTutorialModal({super.key, this.initialIndex = 0});

  @override
  State<TutorTutorialModal> createState() => _TutorTutorialModalState();
}

class _TutorTutorialModalState extends State<TutorTutorialModal> {
  late final PageController _pageController;
  late int _currentPage;

  final List<Map<String, dynamic>> _slides = [
    {
      "badge": "PASO 1 DE 5",
      "icon": Icons.waving_hand_rounded,
      "iconBg": const Color(0xFFFEF3C7),
      "iconColor": const Color(0xFFD97706),
      "titulo": "¡Bienvenido, Tutor!",
      "subtitulo": "Tu asistente nutricional pediátrico",
      "descripcion":
          "Esta aplicación te ayuda a gestionar de forma sencilla, segura y personalizada la alimentación diaria de los niños bajo tu cuidado médico.",
      "tips": [
        "Planes de alimentación adaptados a cada diagnóstico.",
        "Recetas nutritivas sin alérgenos ni ingredientes prohibidos.",
      ],
    },
    {
      "badge": "PASO 2 DE 5",
      "icon": Icons.family_restroom_rounded,
      "iconBg": const Color(0xFFE0F2FE),
      "iconColor": const Color(0xFF0284C7),
      "titulo": "Mis Pacientes",
      "subtitulo": "Gestión y cambio de pacientes",
      "descripcion":
          "En la pestaña 'Mi paciente' encuentras la lista de todos los niños registrados a tu cargo.",
      "tips": [
        "Toca la tarjeta de un paciente para ver su plan diario y comidas.",
        "Si tienes más de un paciente, puedes alternar entre ellos cuando desees.",
      ],
    },
    {
      "badge": "PASO 3 DE 5",
      "icon": Icons.restaurant_menu_rounded,
      "iconBg": const Color(0xFFDCFCE7),
      "iconColor": const Color(0xFF16A34A),
      "titulo": "Plan Diario y Comidas",
      "subtitulo": "Horarios y momentos programados",
      "descripcion":
          "El día está dividido en momentos de comida (Desayuno, Media mañana, Almuerzo, Media tarde y Merienda).",
      "tips": [
        "Usa 'Generar Plan Automático' para crear menús seguros para la semana.",
        "Revisa los ingredientes exactos y pasos de preparación de cada plato.",
      ],
    },
    {
      "badge": "PASO 4 DE 5",
      "icon": Icons.check_circle_outline_rounded,
      "iconBg": const Color(0xFFCCFBF1),
      "iconColor": const Color(0xFF0D9488),
      "titulo": "Consumo y Alternativas",
      "subtitulo": "Registro de comidas y reemplazos",
      "descripcion":
          "Controla la adherencia nutricional y adapta el menú a tu despensa.",
      "tips": [
        "Marca 'Consumida' una vez preparada la comida dentro de su horario.",
        "¿No tienes los ingredientes? Toca 'Intercambiar' para recibir otra receta segura al instante.",
      ],
    },
    {
      "badge": "PASO 5 DE 5",
      "icon": Icons.notifications_active_rounded,
      "iconBg": const Color(0xFFFFEDD5),
      "iconColor": const Color(0xFFEA580C),
      "titulo": "Alertas y Ayuda",
      "subtitulo": "Notificaciones oportunas y guía",
      "descripcion":
          "La app te enviará recordatorios al inicio de cada comida para que comiences a prepararla a tiempo.",
      "tips": [
        "Si tienes varios pacientes con comidas a la misma hora, recibirás un resumen familiar sin saturarte.",
        "Puedes volver a ver este tutorial cuando quieras tocando el icono (?) de la barra superior.",
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex.clamp(0, _slides.length - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 440,
          maxHeight: 620,
        ),
        child: Column(
          children: [
            // Cabecera superior con botón de saltar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTema.azulPrincipal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          size: 18,
                          color: AppTema.azulPrincipal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "GUÍA RÁPIDA",
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTema.azulPrincipal,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      "Saltar",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Contenido deslizable (PageView)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  final List<String> tips = List<String>.from(slide["tips"]);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      children: [
                        // Icono representativo
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: slide["iconBg"] as Color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (slide["iconColor"] as Color)
                                  .withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            slide["icon"] as IconData,
                            color: slide["iconColor"] as Color,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Badge del paso
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            slide["badge"] as String,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Título
                        Text(
                          slide["titulo"] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Subtítulo
                        Text(
                          slide["subtitulo"] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTema.azulPrincipal,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Descripción
                        Text(
                          slide["descripcion"] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: const Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tarjetas de tips / puntos clave
                        ...tips.map(
                          (tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: AppTema.verdeSalud,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: GoogleFonts.lato(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF334155),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Barra inferior con controles y puntos de progreso
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  // Botón Anterior
                  if (_currentPage > 0)
                    IconButton.filledTonal(
                      onPressed: _previousPage,
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF475569),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 44),

                  // Indicadores de puntos (Dots)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final isCurrent = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          margin: const EdgeInsets.symmetric(horizontal: 3.5),
                          width: isCurrent ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppTema.azulPrincipal
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Botón Siguiente / Comenzar
                  FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(
                      backgroundColor: isLastPage
                          ? AppTema.verdeSalud
                          : AppTema.azulPrincipal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLastPage ? "¡Comenzar!" : "Siguiente",
                          style: GoogleFonts.montserrat(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isLastPage
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
