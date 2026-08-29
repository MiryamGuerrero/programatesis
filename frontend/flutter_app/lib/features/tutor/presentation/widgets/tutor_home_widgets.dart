import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../../core/state/app_providers.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/app_responsive.dart';
import '../tutor_receta_detalle_page.dart';
import '../momento_horario.dart';
import '../../data/repositorio_tutor.dart';
import 'generar_plan_automatico_modal.dart';

class DashboardView extends ConsumerStatefulWidget {
  final String? idPaciente;
  const DashboardView({super.key, required this.idPaciente});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final Map<int, bool> _expandedStates = {};
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleConsumida(int idPlanItem, bool currentStatus) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('tutor/marcar-consumida', data: {
        "id_plan_item": idPlanItem,
        "consumida": !currentStatus,
        "fecha": fechaHoyIso(),
        "hora": horaActualHhMm(),
      });
      if (widget.idPaciente != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        await ref.refresh(
            planDiarioProvider((idPaciente: widget.idPaciente!, fecha: today))
                .future);
      } else {
        ref.invalidate(planDiarioProvider);
      }
    } catch (e) {
      debugPrint("Error marcando consumo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al marcar consumo: $e")));
      }
    }
  }

  Future<void> _intercambiarReceta(int idPlanItem) async {
    try {
      final repo = ref.read(repositorioTutorProvider);
      await repo.intercambiarRecetaPlan(idPlanItem);
      if (widget.idPaciente != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        await ref.refresh(
            planDiarioProvider((idPaciente: widget.idPaciente!, fecha: today))
                .future);
      } else {
        ref.invalidate(planDiarioProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Receta intercambiada por una alternativa segura")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _refreshPage() async {
    final idPaciente = widget.idPaciente ?? ref.read(selectedPatientIdProvider);
    if (idPaciente != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      ref.invalidate(planDiarioProvider((idPaciente: idPaciente, fecha: today)));
      ref.invalidate(tipSaludableProvider);
      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  Widget _buildDashboardShimmer(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveSpacing(AppSpacing.md),
          vertical: AppSpacing.md,
        ),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFCBD5E1),
          highlightColor: const Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Container(
                height: 24,
                width: 180,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Container(
                height: 140,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              Container(
                height: 140,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final idPaciente = widget.idPaciente ?? ref.watch(selectedPatientIdProvider);
    if (idPaciente == null) {
      return _buildDashboardShimmer(context);
    }

    final planAsync = ref.watch(planDiarioProvider((idPaciente: idPaciente, fecha: today)));

    if (planAsync.isLoading && !planAsync.hasValue) {
      return _buildDashboardShimmer(context);
    }

    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: planAsync.when(
        data: (meals) {
          if (meals.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.no_food_outlined,
                        size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 24),
                    Text(
                      "No hay un plan para hoy",
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "El nutricionista aún no ha asignado un plan. Puedes generar uno automáticamente basado en tus necesidades.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () async {
                        final result = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => GenerarPlanAutomaticoModal(
                                idPaciente: idPaciente),
                          );
                          if (result == true) {
                            ref.invalidate(planDiarioProvider);
                          }
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text("Generar Plan Automático"),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16)),
                    ),
                  ],
                ),
              ),
            );
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
              final startMin =
                  int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
              final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

              if (currentTimeInMinutes >= startMin &&
                  currentTimeInMinutes <= endMin) {
                featuredMomentId = momId;
                break;
              }
            }
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
                horizontal: context.responsiveSpacing(AppSpacing.md),
                vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...momentOrder.map((momId) {
                  final isFeatured = momId == featuredMomentId;
                  final momentMeals = grouped[momId]!;
                  final firstMeal = momentMeals.first;
                  final firstMealWithImage = momentMeals.firstWhere(
                    (m) =>
                        m["receta_url_imagen"] != null &&
                        m["receta_url_imagen"].toString().trim().isNotEmpty,
                    orElse: () => firstMeal,
                  );
                  final String momentImageUrl =
                      firstMealWithImage["receta_url_imagen"]?.toString() ?? "";
                  final String momentoNombre =
                      firstMeal["momento_nombre"]?.toString() ?? "COMIDA";
                  final String range =
                      "${firstMeal["momento_hora_inicio"]?.toString().substring(0, 5)} - ${firstMeal["momento_hora_fin"]?.toString().substring(0, 5)}";
                  
                  final isExpanded = _expandedStates[momId] ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isFeatured
                          ? const Color(0xFFF0F9FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: isFeatured
                          ? Border.all(
                              color: colorScheme.primary, width: 1.8)
                          : Border.all(
                              color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: isFeatured
                              ? colorScheme.primary.withOpacity(0.08)
                              : Colors.black.withOpacity(0.03),
                          blurRadius: isFeatured ? 12 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Imagen de la primera comida extendida hasta el extremo derecho, ocupando toda la altura de la tarjeta, con mayor transparencia y que se oculta al desplegar el acordeón
                        if (momentImageUrl.isNotEmpty)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: context.responsiveValue(
                                mobile: 200.0, tablet: 280.0),
                            child: AnimatedOpacity(
                              opacity: isExpanded ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: IgnorePointer(
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        Colors.transparent,
                                        Color(0x99000000), // Máxima opacidad suave (~60%)
                                      ],
                                      stops: [0.0, 0.35, 1.0],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Image.network(
                                    momentImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: Theme(
                            data:
                                theme.copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: Key("expansion_tile_$momId"),
                              initiallyExpanded: isExpanded,
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  _expandedStates[momId] = expanded;
                                });
                              },
                              tilePadding: EdgeInsets.zero,
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              trailing: Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: isFeatured
                                        ? colorScheme.primary
                                        : const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  if (isFeatured)
                                    Container(
                                      width: 5,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(4),
                                          bottomRight: Radius.circular(4),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: (isFeatured
                                                      ? colorScheme.primary
                                                      : Colors.grey.shade200)
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _getMomentIcon(momentoNombre),
                                              color: isFeatured
                                                  ? colorScheme.primary
                                                  : Colors.grey.shade600,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  momentoNombre,
                                                  style: theme.textTheme.titleMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 17,
                                                    color: isFeatured
                                                        ? colorScheme.primary
                                                        : const Color(0xFF1E293B),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  range,
                                                  style: theme.textTheme.bodySmall
                                                      ?.copyWith(
                                                    color:
                                                        const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                            Column(
                              children: momentMeals.map((m) {
                                final bool isConsumida = m["consumida"] == true;
                                final bool canToggle = puedeMarcarConsumida(
                                  horaInicio:
                                      m["momento_hora_inicio"]?.toString(),
                                  horaFin: m["momento_hora_fin"]?.toString(),
                                  ahora: now,
                                );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: (isFeatured && !isConsumida)
                                      ? _FeaturedMealCard(
                                          meal: m,
                                          onConsumida: () => _toggleConsumida(
                                              m["id_plan_item"], isConsumida),
                                          onCambiar: () => _intercambiarReceta(
                                              m["id_plan_item"]),
                                        )
                                      : _UpcomingMealCard(
                                          meal: m,
                                          isConsumida: isConsumida,
                                          canToggle: canToggle,
                                          onToggleConsumida: () =>
                                              _toggleConsumida(
                                                  m["id_plan_item"], isConsumida),
                                        ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Etiqueta de estado reposicionada en la esquina superior derecha
                    Positioned(
                      top: 10,
                      right: 14,
                      child: IgnorePointer(
                        child: _buildStatusPill(
                            momentMeals, currentTimeInMinutes),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            const _HealthyTipBanner(),
            const SizedBox(height: 32),
          ],
        ),
      );
        },
        loading: () => _buildDashboardShimmer(context),
        error: (err, _) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 400,
            alignment: Alignment.center,
            child: Text("Error: $err"),
          ),
        ),
      ),
    );
  }

  IconData _getMomentIcon(String nombre) {
    nombre = nombre.toLowerCase();
    if (nombre.contains("desayuno")) return Icons.coffee_rounded;
    if (nombre.contains("almuerzo")) return Icons.restaurant_rounded;
    if (nombre.contains("merienda") || nombre.contains("cena"))
      return Icons.nights_stay_rounded;
    if (nombre.contains("mañana")) return Icons.wb_sunny_rounded;
    if (nombre.contains("tarde")) return Icons.wb_twilight_rounded;
    return Icons.fastfood_rounded;
  }

  Widget _buildStatusPill(List<Map<String, dynamic>> meals, int currentMin) {
    final first = meals.first;
    final startStr = first["momento_hora_inicio"]?.toString();
    final endStr = first["momento_hora_fin"]?.toString();
    if (startStr == null || endStr == null) return const SizedBox();

    final startMin = int.parse(startStr.split(':')[0]) * 60 +
        int.parse(startStr.split(':')[1]);
    final endMin =
        int.parse(endStr.split(':')[0]) * 60 + int.parse(endStr.split(':')[1]);

    final allConsumida = meals.every((m) => m["consumida"] == true);
    final anyConsumida = meals.any((m) => m["consumida"] == true);

    String label = "";
    Color color = Colors.grey;

    if (allConsumida) {
      label = "COMPLETADO";
      color = AppTema.verdeSalud;
    } else if (anyConsumida) {
      label = "PENDIENTE";
      color = Colors.orange;
    } else if (currentMin >= startMin && currentMin <= endMin) {
      label = "AHORA";
      color = AppTema.azulPrincipal;
    } else if (currentMin < startMin) {
      label = "SIGUIENTE";
      color = Colors.blueGrey;
    } else {
      label = "NO COMPLETADO";
      color = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FeaturedMealCard extends StatefulWidget {
  final Map<String, dynamic> meal;
  final Future<void> Function() onConsumida;
  final Future<void> Function() onCambiar;

  const _FeaturedMealCard({
    required this.meal,
    required this.onConsumida,
    required this.onCambiar,
  });

  @override
  State<_FeaturedMealCard> createState() => _FeaturedMealCardState();
}

class _FeaturedMealCardState extends State<_FeaturedMealCard> {
  bool _isChanging = false;
  bool _isConsuming = false;

  Future<void> _handleCambiar() async {
    setState(() => _isChanging = true);
    try {
      await widget.onCambiar();
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  Future<void> _handleConsumida() async {
    setState(() => _isConsuming = true);
    try {
      await widget.onConsumida();
    } finally {
      if (mounted) setState(() => _isConsuming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final String url = widget.meal["receta_url_imagen"] ?? "";
    final bool esAutomatico = widget.meal["id_origen_plan"] == 2;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: context.responsiveValue(mobile: 200, tablet: 300),
            color: const Color(0xFFE2E8F0),
            child: url.isNotEmpty
                ? Image.network(url,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.restaurant,
                        size: 48, color: Colors.white))
                : const Icon(Icons.restaurant, size: 64, color: Colors.white),
          ),
          Padding(
            padding: EdgeInsets.all(context.responsiveSpacing(AppSpacing.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.meal["receta_nombre"] ?? "Sin nombre",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTextSizes.headline(context.screenWidth) * 0.8,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (widget.meal["receta_descripcion"] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      widget.meal["receta_descripcion"],
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          height: 1.4,
                          fontSize: AppTextSizes.body(context.screenWidth)),
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
                          height: AppSizes.buttonHeight,
                          child: FilledButton(
                            onPressed: () {
                              final idReceta = widget.meal["id_receta"];
                              if (idReceta != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TutorRecetaDetallePage(
                                            idReceta: idReceta as int),
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
                              width: esAutomatico
                                  ? btnWidth
                                  : constraints.maxWidth,
                              height: AppSizes.buttonHeight,
                              child: FilledButton.tonal(
                                onPressed: (_isChanging || _isConsuming)
                                    ? null
                                    : _handleConsumida,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTema.verdeSalud,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                ),
                                child: _isConsuming
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check, size: 16),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              "Consumida",
                                              style:
                                                  TextStyle(fontSize: fontSize),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            if (esAutomatico) ...[
                              const SizedBox(width: 12),
                              SizedBox(
                                width: btnWidth,
                                height: AppSizes.buttonHeight,
                                child: OutlinedButton(
                                  onPressed: (_isChanging || _isConsuming)
                                      ? null
                                      : _handleCambiar,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                  child: _isChanging
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.grey))
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.autorenew,
                                                size: 16),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                "Cambiar",
                                                style: TextStyle(
                                                    fontSize: fontSize),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
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

class _UpcomingMealCard extends StatefulWidget {
  final Map<String, dynamic> meal;
  final bool isConsumida;
  final bool canToggle;
  final Future<void> Function() onToggleConsumida;

  const _UpcomingMealCard(
      {required this.meal,
      this.isConsumida = false,
      this.canToggle = true,
      required this.onToggleConsumida});

  @override
  State<_UpcomingMealCard> createState() => _UpcomingMealCardState();
}

class _UpcomingMealCardState extends State<_UpcomingMealCard> {
  bool _isLoading = false;

  Future<void> _handleToggle() async {
    setState(() => _isLoading = true);
    try {
      await widget.onToggleConsumida();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String url = widget.meal["receta_url_imagen"] ?? "";
    final theme = Theme.of(context);

    // Determina si el momento de comida ya pasó (hora actual > hora_fin)
    final bool hasExpired = momentoYaPaso(
      horaFin: widget.meal["momento_hora_fin"]?.toString(),
    );

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: widget.isConsumida
            ? BorderSide(color: AppTema.verdeSalud.withOpacity(0.5), width: 1.5)
            : BorderSide.none,
      ),
      elevation: widget.isConsumida ? 0 : 1,
      color: widget.isConsumida ? Colors.grey.shade50 : Colors.white,
      child: ListTile(
        onTap: () {
          final idReceta = widget.meal["id_receta"];
          if (idReceta != null) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        TutorRecetaDetallePage(idReceta: idReceta as int)));
          }
        },
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: url.isNotEmpty
                  ? Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          const Icon(Icons.fastfood, color: Colors.grey))
                  : const Icon(Icons.fastfood, color: Colors.grey),
            ),
            if (widget.isConsumida)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: AppTema.verdeSalud, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          widget.meal["receta_nombre"] ?? "Sin nombre",
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.isConsumida ? Colors.grey : null,
              decoration:
                  widget.isConsumida ? TextDecoration.lineThrough : null,
              fontSize: AppTextSizes.bodyLarge(context.screenWidth)),
        ),
        subtitle: widget.isConsumida
            ? const Text("Consumida",
                style: TextStyle(
                    color: AppTema.verdeSalud,
                    fontWeight: FontWeight.bold,
                    fontSize: 12))
            : (hasExpired
                ? const Text("No completada",
                    style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 12))
                : (widget.meal["receta_descripcion"] != null
                    ? Text(widget.meal["receta_descripcion"],
                        style: TextStyle(
                            fontSize: AppTextSizes.bodySmall(context.screenWidth)))
                    : null)),
        trailing: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : (widget.isConsumida
                ? (widget.canToggle
                    ? IconButton(
                        icon: const Icon(Icons.undo_rounded,
                            size: 20, color: Colors.grey),
                        tooltip: "Desmarcar",
                        onPressed: _handleToggle,
                      )
                    : const Tooltip(
                        message:
                            "El horario de este momento ya venció, no se puede modificar",
                        child: Icon(Icons.check_circle_rounded,
                            size: 20, color: AppTema.verdeSalud),
                      ))
                : (widget.canToggle
                    ? IconButton(
                        icon: const Icon(Icons.check_circle_outline_rounded,
                            size: 24, color: AppTema.verdeSalud),
                        tooltip: "Marcar como consumida",
                        onPressed: _handleToggle,
                      )
                    : (hasExpired
                        ? const Tooltip(
                            message:
                                "El horario de este momento ya venció (No completada)",
                            child: Icon(Icons.lock_clock_outlined,
                                size: 20, color: Color(0xFFEF4444)),
                          )
                        : const Tooltip(
                            message:
                                "Aún no es hora de este momento de comida",
                            child: Icon(Icons.schedule_rounded,
                                size: 20, color: Color(0xFF94A3B8)),
                          )))),
      ),
    );
  }
}

class _HealthyTipBanner extends ConsumerWidget {
  const _HealthyTipBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipAsync = ref.watch(tipSaludableProvider);
    final theme = Theme.of(context);

    return tipAsync.when(
      data: (tip) {
        final String mensaje = tip["mensaje"] ?? "";
        final String categoria = tip["categoria"] ?? "salud";

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
                color: AppTema.verdeSalud.withOpacity(0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppTema.verdeSalud.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -10,
                  child: Opacity(
                    opacity: 0.05,
                    child: Icon(
                      _getCategoryIcon(categoria),
                      size: 100,
                      color: AppTema.verdeSalud,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppTema.verdeSalud,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getCategoryIcon(categoria),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FormattedTipText(
                          mensaje: mensaje,
                          accentColor: AppTema.verdeSalud,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case "crecimiento":
        return Icons.trending_up_rounded;
      case "agua":
        return Icons.water_drop_rounded;
      case "nutricion":
        return Icons.eco_rounded;
      case "ejercicio":
        return Icons.fitness_center_rounded;
      case "descanso":
        return Icons.bedtime_rounded;
      case "habito":
        return Icons.auto_awesome_rounded;
      case "mente":
        return Icons.psychology_rounded;
      case "salud":
        return Icons.health_and_safety_rounded;
      case "hogar":
        return Icons.home_rounded;
      case "bienestar":
        return Icons.volunteer_activism_rounded;
      case "energia":
        return Icons.bolt_rounded;
      case "clinico":
        return Icons.medical_services_rounded;
      case "naturaleza":
        return Icons.wb_sunny_rounded;
      default:
        return Icons.lightbulb_rounded;
    }
  }
}

class _FormattedTipText extends StatelessWidget {
  final String mensaje;
  final Color accentColor;

  const _FormattedTipText({required this.mensaje, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final List<TextSpan> spans = [];
    final parts = mensaje.split("**");

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: accentColor,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ));
      }
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.montserrat(
          fontSize: 13,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }
}
