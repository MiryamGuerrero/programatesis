import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_responsive.dart';
import '../../../core/services/notification_service.dart';
import 'momento_horario.dart';

class TutorRecetaDetallePage extends ConsumerStatefulWidget {
  final int idReceta;
  const TutorRecetaDetallePage({super.key, required this.idReceta});

  @override
  ConsumerState<TutorRecetaDetallePage> createState() =>
      _TutorRecetaDetallePageState();
}

class _TutorRecetaDetallePageState extends ConsumerState<TutorRecetaDetallePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _receta;
  bool _isLoading = true;
  bool _isActionLoading = false;
  int _userRating = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio
          .get('tutor/receta-detalle/${widget.idReceta}', queryParameters: {
        'id_paciente': idPaciente,
      });
      if (mounted) {
        setState(() {
          _receta = resp.data;
          _userRating = (_receta!['calificacion_personal'] ?? 0).toInt();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar receta: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleConsumida() async {
    if (_receta == null || _receta!['en_plan_hoy'] != true) return;

    final bool canToggle = puedeMarcarConsumida(
      horaInicio: _receta?['momento_hora_inicio_hoy']?.toString(),
      horaFin: _receta?['momento_hora_fin_hoy']?.toString(),
    );
    if (!canToggle) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "El horario de este momento de comida ya venció, no se puede modificar el consumo."),
          ),
        );
      }
      return;
    }

    final idPlanItem = _receta!['id_plan_item_hoy'];
    final bool currentStatus = _receta!['consumida_hoy'] == true;

    setState(() => _isActionLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('tutor/marcar-consumida', data: {
        "id_plan_item": idPlanItem,
        "consumida": !currentStatus,
        "fecha": fechaHoyIso(),
        "hora": horaActualHhMm(),
      });

      setState(() {
        _receta!['consumida_hoy'] = !currentStatus;
      });
      final idPaciente = ref.read(selectedPatientIdProvider);
      if (idPaciente != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        ref.invalidate(
            planDiarioProvider((idPaciente: idPaciente, fecha: today)));
      } else {
        ref.invalidate(planDiarioProvider);
      }
      ref.read(notificationServiceProvider).sincronizarNotificacionesPlanHoy();
    } catch (e) {
      debugPrint("Error marcando consumo: $e");
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_receta == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
            child: Text("No se pudo cargar la información de la receta.")),
      );
    }

    final r = _receta!;
    final String url = r['imagen_url'] ?? "";

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _cargarDetalle();
        },
        child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(context, r, url, colorScheme),
            SliverToBoxAdapter(
              child: ResponsiveMaxConstraints(
                child: Padding(
                  padding:
                      EdgeInsets.all(context.responsiveSpacing(AppSpacing.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummarySection(context, r),
                      const SizedBox(height: 20),

                      _buildDescriptionSection(context, r, theme),
                      const SizedBox(height: 24),
                      if (r['en_plan_hoy'] == true) ...[
                        _buildConsumidaSection(context, r),
                        const SizedBox(height: 24),
                      ],
                      _buildTabsMenu(context, colorScheme),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: ResponsiveMaxConstraints(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildIngredientesTab(context, r),
              _buildPreparacionTab(context, r),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMacronutrientesPieChart(
      BuildContext context, Map<String, dynamic> r) {
    final double prot = (r['proteinas_totales'] ?? 0).toDouble();
    final double carb = (r['carbohidratos_totales'] ?? 0).toDouble();
    final double fat = (r['grasas_totales'] ?? 0).toDouble();
    final double total = prot + carb + fat;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 24, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Text(
            "Distribución de Macronutrientes",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTema.azulOscuro,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                height: 90,
                width: 90,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 22,
                    sections: [
                      PieChartSectionData(value: prot, title: '', color: AppTema.azulPrincipal, radius: 18),
                      PieChartSectionData(value: carb, title: '', color: Colors.orange, radius: 18),
                      PieChartSectionData(value: fat, title: '', color: Colors.redAccent, radius: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChartLegend("Proteínas",
                        "${prot.toStringAsFixed(1)}g", AppTema.azulPrincipal),
                    const SizedBox(height: 8),
                    _buildChartLegend("Carbohidratos",
                        "${carb.toStringAsFixed(1)}g", Colors.orange),
                    const SizedBox(height: 8),
                    _buildChartLegend("Grasas", "${fat.toStringAsFixed(1)}g",
                        Colors.redAccent),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTema.azulOscuro),
        ),
      ],
    );
  }

  Widget _buildTabsMenu(BuildContext context, ColorScheme colorScheme) {

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.primary,
        ),
        dividerColor: Colors.transparent,
        labelColor: colorScheme.onPrimary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: context.responsiveValue(mobile: 12, tablet: 14)),
        tabs: const [
          Tab(text: "Ingredientes"),
          Tab(text: "Preparación"),
        ],
      ),
    );
  }

  Widget _buildConsumidaSection(BuildContext context, Map<String, dynamic> r) {
    final bool isConsumida = r['consumida_hoy'] == true;
    final bool canToggle = puedeMarcarConsumida(
      horaInicio: r['momento_hora_inicio_hoy']?.toString(),
      horaFin: r['momento_hora_fin_hoy']?.toString(),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isConsumida ? AppTema.verdeSalud.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isConsumida
                ? AppTema.verdeSalud.withOpacity(0.3)
                : Colors.grey.shade200),
        boxShadow: isConsumida
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isConsumida ? AppTema.verdeSalud : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConsumida ? Icons.check_rounded : Icons.restaurant_rounded,
              color: isConsumida ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Plan de Hoy",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTextSizes.bodySmall(context.screenWidth),
                    color: AppTema.azulOscuro,
                  ),
                ),
                Text(
                  isConsumida
                      ? "Consumida"
                      : (canToggle
                          ? "¿Ya la preparaste?"
                          : "No completada"),
                  style: TextStyle(
                    fontSize: AppTextSizes.caption(context.screenWidth),
                    color: isConsumida
                        ? AppTema.verdeSalud
                        : (canToggle ? Colors.grey.shade600 : const Color(0xFFEF4444)),
                    fontWeight:
                        canToggle ? null : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            height: 40,
            child: FilledButton.tonal(
              onPressed: (_isActionLoading || !canToggle) ? null : _toggleConsumida,
              style: FilledButton.styleFrom(
                backgroundColor:
                    isConsumida ? Colors.grey.shade100 : AppTema.verdeSalud,
                foregroundColor:
                    isConsumida ? Colors.grey.shade700 : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isActionLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.grey))
                  : Text(isConsumida ? "Desmarcar" : "Marcar",
                      style: TextStyle(
                          fontSize: AppTextSizes.caption(context.screenWidth),
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCircleButton(
      BuildContext context, Map<String, dynamic> r) {
    final double promedio =
        double.tryParse(r['puntuacion_promedio']?.toString() ?? "0") ?? 0;
    final int recetaId = r['id'];

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: Tooltip(
          message: "Toca para calificar esta receta",
          child: InkWell(
            onTap: () => _openRatingModal(context, recetaId),
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _userRating > 0
                          ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                          : [Colors.white, const Color(0xFFF8FAFC)],
                    ),
                    border: Border.all(
                      color: Colors.amber.shade400,
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                      if (_userRating > 0)
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: _userRating > 0
                              ? Colors.white
                              : const Color(0xFFF59E0B),
                          size: 15,
                        ),
                        Text(
                          promedio > 0 ? promedio.toStringAsFixed(1) : "-",
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: _userRating > 0
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: _userRating > 0
                          ? const Color(0xFF16A34A)
                          : AppTema.azulPrincipal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3),
                      ],
                    ),
                    child: Icon(
                      _userRating > 0 ? Icons.check : Icons.edit_rounded,
                      color: Colors.white,
                      size: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRatingModal(BuildContext context, int recetaId) async {
    final double promedio =
        double.tryParse(_receta!['puntuacion_promedio']?.toString() ?? "0") ??
            0;
    final int total = _receta!['total_evaluaciones'] ?? 0;
    int selectedRating = 0;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            String ratingLabel = "";
            switch (selectedRating) {
              case 1:
                ratingLabel = "No me gustó (1 / 5)";
                break;
              case 2:
                ratingLabel = "Regular (2 / 5)";
                break;
              case 3:
                ratingLabel = "Buena (3 / 5)";
                break;
              case 4:
                ratingLabel = "Muy buena (4 / 5)";
                break;
              case 5:
                ratingLabel = "¡Excelente! (5 / 5)";
                break;
              default:
                ratingLabel = "Toca las estrellas para calificar";
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: Colors.white,
              elevation: 16,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.amber.shade200),
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Calificar receta",
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTema.azulOscuro,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.grey),
                            onPressed: () => Navigator.pop(dialogCtx),
                            tooltip: "Cerrar",
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _receta!['nombre'] ?? 'Receta',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber.shade600, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "$promedio",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            " ($total ${total == 1 ? 'evaluación' : 'evaluaciones'})",
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      Text(
                        "¿Qué puntuación le das a este plato?",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          final isFilled = starValue <= selectedRating;
                          return IconButton(
                            iconSize: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () {
                              setModalState(() {
                                selectedRating = starValue;
                              });
                            },
                            icon: Icon(
                              isFilled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isFilled
                                  ? Colors.amber
                                  : Colors.grey.shade300,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedRating == 0
                                ? const Color(0xFFF8FAFC)
                                : (selectedRating <= 2
                                    ? const Color(0xFFFEF2F2)
                                    : const Color(0xFFF0FDF4)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selectedRating == 0
                                  ? const Color(0xFFE2E8F0)
                                  : (selectedRating <= 2
                                      ? const Color(0xFFFECACA)
                                      : const Color(0xFFBBF7D0)),
                            ),
                          ),
                          child: Text(
                            ratingLabel,
                            style: GoogleFonts.montserrat(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: selectedRating == 0
                                  ? const Color(0xFF64748B)
                                  : (selectedRating <= 2
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A)),
                            ),
                          ),
                        ),
                      ),
                      if (selectedRating > 0 && selectedRating <= 2) ...[
                        const SizedBox(height: 12),
                        Text(
                          "Al seleccionar 1 o 2 estrellas, te pediremos un breve motivo para no volver a sugerir platos similares.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                "Cancelar",
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: selectedRating == 0
                                  ? null
                                  : () {
                                      Navigator.pop(dialogCtx);
                                      _handleRating(selectedRating, recetaId);
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTema.azulPrincipal,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                "Guardar",
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleRating(int rating, int recetaId) async {
    final int previousRating = _userRating;
    setState(() => _userRating = rating);
    if (rating <= 2) {
      _showFeedbackDialog(rating, recetaId, previousRating);
    } else {
      _submitRating(rating, recetaId, null, null);
    }
  }

  Future<void> _showFeedbackDialog(
      int stars, int recetaId, int previousRating) async {
    final dio = ref.read(dioProvider);
    List<dynamic> motivos = [];
    try {
      final resp = await dio.get('tutor/motivos-rechazo');
      motivos = resp.data;
    } catch (e) {
      debugPrint("Error cargando motivos: $e");
    }

    if (!mounted) return;

    int? selectedMotivoId;
    final commentController = TextEditingController();
    bool showOtherField = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.white,
          elevation: 12,
          clipBehavior: Clip.antiAlias,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icono de cabecera centrado
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFDE68A),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.rate_review_rounded,
                        color: Color(0xFFD97706),
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Título principal
                  Text(
                    "Ayúdanos a mejorar",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Píldora de estrellas seleccionadas
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 16,
                              color: index < stars
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$stars de 5 estrellas",
                            style: GoogleFonts.montserrat(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Subtítulo explicativo
                  Text(
                    "Lamentamos que la receta no haya sido de tu agrado. ¿Podrías indicarnos el motivo principal para tomarlo en cuenta?",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: 13.5,
                      color: const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Lista interactiva de motivos de rechazo
                  ...motivos.map((m) {
                    final bool isSelected = selectedMotivoId == m['id'];
                    final String nombre = m['nombre']?.toString() ?? "";
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedMotivoId = m['id'];
                            showOtherField =
                                nombre.toLowerCase().contains("otro");
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTema.azulPrincipal.withOpacity(0.08)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppTema.azulPrincipal
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.8 : 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 20,
                                color: isSelected
                                    ? AppTema.azulPrincipal
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  nombre,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppTema.azulPrincipal
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // Campo de texto para detalle adicional u "Otro"
                  if (showOtherField) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText:
                            "Describe con más detalle el motivo o sugerencia...",
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppTema.azulPrincipal, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _userRating = previousRating);
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: const Text(
                            "Cancelar",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: selectedMotivoId == null
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _submitRating(stars, recetaId,
                                      selectedMotivoId, commentController.text);
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTema.azulPrincipal,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Enviar opinión",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitRating(
      int stars, int recetaId, int? motivoId, String? comentario) async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    if (idPaciente == null) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.post('tutor/evaluar-receta', data: {
        "id_paciente": idPaciente,
        "id_receta": recetaId,
        "estrellas": stars,
        "id_motivo_rechazo": motivoId,
        "comentario": comentario,
      });

      _cargarDetalle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡Gracias por tu evaluación!"),
              backgroundColor: AppTema.verdeSalud),
        );
      }
    } catch (e) {
      debugPrint("Error enviando evaluación: $e");
    }
  }

  Widget _buildSliverAppBar(BuildContext context, Map<String, dynamic> r,
      String url, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: context.responsiveValue(mobile: 280, tablet: 400),
      toolbarHeight: 68,
      pinned: true,
      backgroundColor: AppTema.azulOscuro,
      surfaceTintColor: AppTema.azulOscuro,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        _buildRatingCircleButton(context, r),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 12, right: 66),
        title: Text(
          r['nombre'] ?? 'Receta',
          softWrap: true,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: AppTextSizes.title(context.screenWidth) * 0.82,
            color: Colors.white,
            shadows: const [
              Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 1)),
              Shadow(blurRadius: 16, color: Colors.black87),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isNotEmpty)
              Image.network(url, fit: BoxFit.cover)
            else
              Container(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(Icons.restaurant,
                    size: 80,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3)),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.black87],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, Map<String, dynamic> r) {
    final int tTotal = r['tiempo_total_min'] ??
        ((r['tiempo_preparacion_min'] ?? r['tiempo_preparacion'] ?? 0) +
            (r['tiempo_coccion_min'] ?? r['tiempo_coccion'] ?? 0));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: context.responsiveSpacing(AppSpacing.md),
          horizontal: context.responsiveSpacing(AppSpacing.sm)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(context, Icons.people_outline,
              "${r['porciones'] ?? 1}", "Porciones"),
          _buildStatItem(
              context, Icons.timer_outlined, "$tTotal min", "Tiempo"),
          _buildStatItem(
              context,
              Icons.local_fire_department_rounded,
              "${(r['calorias_por_porcion'] ?? r['calorias_kcal'] ?? r['calorias_totales'] ?? 0).toInt()}",
              "Kcal"),
          _buildStatItem(context, Icons.bar_chart_rounded,
              r['dificultad'] ?? "Media", "Dificultad"),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(
      BuildContext context, Map<String, dynamic> r, ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          title: Text(
            "Sobre esta receta",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTema.azulOscuro,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                r['descripcion'] ?? "Sin descripción disponible.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade700,
                  height: 1.6,
                  fontSize: AppTextSizes.body(context.screenWidth),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildStatItem(
      BuildContext context, IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Icon(icon,
              color: AppTema.azulPrincipal,
              size: context.responsiveValue(mobile: 22, tablet: 28)),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: AppTextSizes.body(context.screenWidth))),
          Text(label,
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: AppTextSizes.caption(context.screenWidth),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildIngredientesTab(BuildContext context, Map<String, dynamic> r) {
    final List<dynamic> ing = r['ingredientes'] ?? [];
    if (ing.isEmpty)
      return const Center(child: Text("No hay ingredientes registrados."));

    return ListView.builder(
      padding: EdgeInsets.all(context.responsiveSpacing(AppSpacing.lg)),
      itemCount: ing.length + 1,
      itemBuilder: (context, index) {
        if (index == ing.length) return _buildMacronutrientesPieChart(context, r);
        final i = ing[index];
        return Card(
          elevation: 0,
          color: Colors.grey.shade50,
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.check_circle,
                color: AppTema.verdeSalud, size: 20),
            title: Text(i['nombre'] ?? "-",
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppTextSizes.body(context.screenWidth))),
            trailing: Text(
              "${i['cantidad']} ${i['unidad']}",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTema.azulPrincipal,
                  fontSize: AppTextSizes.bodySmall(context.screenWidth)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreparacionTab(BuildContext context, Map<String, dynamic> r) {
    final List<dynamic> pasos = r['preparacion'] ?? [];
    if (pasos.isEmpty)
      return const Center(child: Text("No hay instrucciones registradas."));

    return ListView.builder(
      padding: EdgeInsets.all(context.responsiveSpacing(AppSpacing.lg)),
      itemCount: pasos.length,
      itemBuilder: (context, index) {
        final p = pasos[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: AppTema.azulPrincipal, shape: BoxShape.circle),
                child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14))),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paso ${index + 1}',
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: AppTextSizes.body(context.screenWidth),
                            color: AppTema.azulOscuro)),
                    const SizedBox(height: 8),
                    Text(
                      p['descripcion'] ?? "-",
                      style: GoogleFonts.montserrat(
                          fontSize: AppTextSizes.body(context.screenWidth),
                          color: Colors.blueGrey.shade700,
                          height: 1.5),
                    ),
                    if (p['nota'] != null && p['nota'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppTema.verdeSalud.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTema.verdeSalud.withOpacity(0.1))),
                        child: Text(
                          'Nota: ${p['nota']}',
                          style: GoogleFonts.montserrat(
                              fontSize:
                                  AppTextSizes.bodySmall(context.screenWidth),
                              fontWeight: FontWeight.w600,
                              color: AppTema.verdeSalud,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
