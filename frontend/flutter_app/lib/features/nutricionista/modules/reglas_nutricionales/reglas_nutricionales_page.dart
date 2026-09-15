import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "reglas_nutricionales_provider.dart";

String _sentenceCaseLabel(Object? value) {
  final text = value?.toString().trim().replaceAll('_', ' ').toLowerCase() ?? '';
  return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

class ReglasNutricionalesPage extends ConsumerStatefulWidget {
  const ReglasNutricionalesPage({super.key});

  @override
  ConsumerState<ReglasNutricionalesPage> createState() =>
      _ReglasNutricionalesPageState();
}

class _ReglasNutricionalesPageState extends ConsumerState<ReglasNutricionalesPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reglasNutricionalesProvider.notifier).loadData();
      _setupRealtime();
    });
  }

  void _setupRealtime() {
    try {
      final supabase = ref.read(supabaseClientProvider);
      _realtimeChannel = supabase
          .channel('reglas_nutricionales_realtime_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'heuristico',
            table: 'regla',
            callback: (payload) {
              debugPrint("[Realtime] Cambio detectado en heuristico.regla: ${payload.eventType}");
              final notifier = ref.read(reglasNutricionalesProvider.notifier);
              notifier.markDirty();
              if (mounted) {
                notifier.loadData();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("Error setting up realtime subscription for reglas nutricionales: $e");
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _limpiarFiltros() {
    _searchController.clear();
    ref.read(reglasNutricionalesProvider.notifier).clearAllFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reglasNutricionalesProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: state.errorMessage != null
          ? _buildErrorView(state.errorMessage!)
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatsRow(state),
                  const SizedBox(height: 32),
                  _buildToolbar(state),
                  const SizedBox(height: 24),
                  _buildTabBar(state),
                  const SizedBox(height: 24),
                  _buildContent(state),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión de reglas nutricionales",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Configuración de lógica experta basada en etiquetas y condiciones nutricionales.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.read(reglasNutricionalesProvider.notifier).loadData(),
            child: const Text("Reintentar"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ReglasNutricionalesState state) {
    if (state.isLoading && state.rules.isEmpty) {
      return const Row(
        children: [
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
          Expanded(child: NutriResumenCardShimmer()),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
            child: NutriResumenCard(
                titulo: "Total de reglas",
                valor: "${state.totalItems}",
                icon: Icons.rule_rounded)),
        const SizedBox(width: 20),
        Expanded(
            child: NutriResumenCard(
                titulo: "Estrictas",
                valor: "${state.strictRulesCount}",
                colorValor: Colors.redAccent,
                icon: Icons.lock_outline_rounded)),
        const SizedBox(width: 20),
        const Expanded(
            child: NutriResumenCard(
                titulo: "Sistema",
                valor: "SIA",
                colorValor: AppTema.azulOscuro,
                icon: Icons.auto_awesome_rounded)),
      ],
    );
  }

  Widget _buildToolbar(ReglasNutricionalesState state) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar por diagnóstico, alimento o regla...",
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _searchDebounce?.cancel();
                          ref
                              .read(reglasNutricionalesProvider.notifier)
                              .setSearchQuery("");
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                setState(() {});
                _searchDebounce?.cancel();
                if (v.trim().isEmpty) {
                  ref
                      .read(reglasNutricionalesProvider.notifier)
                      .setSearchQuery("");
                } else {
                  _searchDebounce =
                      Timer(const Duration(milliseconds: 250), () {
                    ref
                        .read(reglasNutricionalesProvider.notifier)
                        .setSearchQuery(v.trim());
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => _showForm(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTema.verdeSalud,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: Text("Nueva regla",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(ReglasNutricionalesState state) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTabItem(
                  label: "Condiciones por peso",
                  icon: Icons.monitor_weight_rounded,
                  count: state.pesoRulesCount,
                  isSelected: state.indicadorFilter == "BMI",
                  onTap: () => ref.read(reglasNutricionalesProvider.notifier).setIndicadorFilter("BMI"),
                ),
              ),
              Expanded(
                child: _buildTabItem(
                  label: "Condiciones por estatura",
                  icon: Icons.height_rounded,
                  count: state.estaturaRulesCount,
                  isSelected: state.indicadorFilter == "HFA",
                  onTap: () => ref.read(reglasNutricionalesProvider.notifier).setIndicadorFilter("HFA"),
                ),
              ),
            ],
          ),
          // Indicador animado que se desliza suavemente entre pestañas
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: state.indicadorFilter == "BMI"
                ? Alignment.bottomLeft
                : Alignment.bottomRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppTema.verdeSalud,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTema.verdeSalud.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const activeColor = AppTema.verdeSalud;
    const inactiveColor = Colors.blueGrey;

    return InkWell(
      onTap: onTap,
      hoverColor: activeColor.withValues(alpha: 0.04),
      splashColor: activeColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? activeColor : inactiveColor),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
              child: Text(label),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.12)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$count",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? activeColor : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ReglasNutricionalesState state) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          final double direction = (state.indicadorFilter == "HFA") ? 1.0 : -1.0;
          final isIncoming = child.key == ValueKey("content_reglas_${state.indicadorFilter}");
          final slideTween = isIncoming
              ? Tween<Offset>(
                  begin: Offset(direction * 0.15, 0.0),
                  end: Offset.zero,
                )
              : Tween<Offset>(
                  begin: Offset(-direction * 0.15, 0.0),
                  end: Offset.zero,
                );

          return SlideTransition(
            position: slideTween.animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey("content_reglas_${state.indicadorFilter}"),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFiltersPanel(state),
              const SizedBox(height: 24),
              _buildTable(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersPanel(ReglasNutricionalesState state) {
    final conds = (state.formData["condiciones"] ?? []).where((c) {
      return c["indicador_codigo"] == state.indicadorFilter;
    }).toList();

    List<dynamic> targetList = [];
    if (state.filtroTipoObjetivo == 1) {
      targetList = state.formData["ingredientes"] ?? [];
    } else if (state.filtroTipoObjetivo == 2) {
      targetList = state.formData["grupos"] ?? [];
    } else if (state.filtroTipoObjetivo == 3) {
      targetList = state.formData["etiquetas"] ?? [];
    } else if (state.filtroTipoObjetivo == 4) {
      targetList = state.formData["subgrupos"] ?? [];
    }

    final hasObjetivo = state.filtroTipoObjetivo != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, color: AppTema.azulPrincipal, size: 20),
              const SizedBox(width: 8),
              Text(
                "Filtros",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTema.azulPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 950;

              final col1 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Condición nutricional",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: state.filtroCondicion,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        state.indicadorFilter == "BMI"
                            ? Icons.monitor_weight_outlined
                            : Icons.height_outlined,
                        color: AppTema.verdeSalud,
                        size: 18,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTema.verdeSalud),
                      ),
                    ),
                    hint: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Seleccionar condición nutricional",
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                    items: conds.map((c) => DropdownMenuItem<int>(
                      value: c["id"],
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          c["nombre"] ?? "",
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      ),
                    )).toList(),
                    onChanged: (v) => ref.read(reglasNutricionalesProvider.notifier).setFiltroCondicion(v),
                  ),
                ],
              );

              final col2 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Acción sugerida",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildActionButton(
                        label: "Priorizar",
                        icon: Icons.arrow_upward_rounded,
                        color: const Color(0xFF15803D),
                        bgSelected: const Color(0xFFDCFCE7),
                        isSelected: state.filtroAccion == 3,
                        onTap: () => ref.read(reglasNutricionalesProvider.notifier).setFiltroAccion(state.filtroAccion == 3 ? null : 3),
                      ),
                      const SizedBox(width: 6),
                      _buildActionButton(
                        label: "Disminuir",
                        icon: Icons.arrow_downward_rounded,
                        color: const Color(0xFFCA8A04),
                        bgSelected: const Color(0xFFFEF9C3),
                        isSelected: state.filtroAccion == 2,
                        onTap: () => ref.read(reglasNutricionalesProvider.notifier).setFiltroAccion(state.filtroAccion == 2 ? null : 2),
                      ),
                      const SizedBox(width: 6),
                      _buildActionButton(
                        label: "Eliminar",
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFB91C1C),
                        bgSelected: const Color(0xFFFEE2E2),
                        isSelected: state.filtroAccion == 1,
                        onTap: () => ref.read(reglasNutricionalesProvider.notifier).setFiltroAccion(state.filtroAccion == 1 ? null : 1),
                      ),
                    ],
                  ),
                ],
              );

              final col3 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tipo de objetivo",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildObjectiveTypeButton(label: "Ingrediente", icon: Icons.eco_outlined, value: 1, state: state),
                      const SizedBox(width: 4),
                      _buildObjectiveTypeButton(label: "Grupo", icon: Icons.group_outlined, value: 2, state: state),
                      const SizedBox(width: 4),
                      _buildObjectiveTypeButton(label: "Subgrupo", icon: Icons.layers_outlined, value: 4, state: state),
                      const SizedBox(width: 4),
                      _buildObjectiveTypeButton(label: "Etiqueta", icon: Icons.label_outline_rounded, value: 3, state: state),
                    ],
                  ),
                  if (hasObjetivo) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Objetivo",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: state.filtroObjetivo,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTema.azulPrincipal),
                        ),
                      ),
                      hint: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Seleccionar objetivo",
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ),
                      items: targetList.map((t) => DropdownMenuItem<int>(
                        value: t["id"],
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            t["nombre"] ?? t["nombre_visible"] ?? "",
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        ),
                      )).toList(),
                      onChanged: (v) => ref.read(reglasNutricionalesProvider.notifier).setFiltroObjetivo(v),
                    ),
                  ],
                ],
              );

              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: col1),
                        const SizedBox(width: 24),
                        Expanded(child: col2),
                      ],
                    ),
                    const SizedBox(height: 20),
                    col3,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: col1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(width: 1, height: 80, color: Colors.grey.shade200),
                  ),
                  Expanded(flex: 3, child: col2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(width: 1, height: 80, color: Colors.grey.shade200),
                  ),
                  Expanded(flex: 4, child: col3),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: state.activeFilters ? _limpiarFiltros : null,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTema.azulPrincipal),
              label: Text(
                "Limpiar filtros",
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTema.azulPrincipal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgSelected,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? bgSelected : Colors.white,
            border: Border.all(color: isSelected ? color : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildObjectiveTypeButton({
    required String label,
    required IconData icon,
    required int value,
    required ReglasNutricionalesState state,
  }) {
    final isSelected = state.filtroTipoObjetivo == value;
    final color = isSelected ? AppTema.azulPrincipal : Colors.blueGrey.shade600;
    final bg = isSelected ? AppTema.azulPrincipal.withValues(alpha: 0.05) : Colors.white;
    final borderColor = isSelected ? AppTema.azulPrincipal : Colors.grey.shade300;

    return Expanded(
      child: InkWell(
        onTap: () {
          final newValue = isSelected ? null : value;
          ref.read(reglasNutricionalesProvider.notifier).setFiltroTipoObjetivo(newValue);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(ReglasNutricionalesState state) {
    if (!state.isLoading && state.rules.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.find_in_page_outlined, size: 48, color: Colors.blueGrey.shade300),
            const SizedBox(height: 16),
            Text(
              "No se encontraron reglas nutricionales",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTema.azulOscuro,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Prueba a ajustar o limpiar los filtros seleccionados.",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.blueGrey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return NutriTableContainer(
      child: LayoutBuilder(builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final usableWidth = totalWidth - 20;
        const rowsPerPage = ReglasNutricionalesNotifier.pageSize;

        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(
                elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
            dividerColor: Colors.transparent,
          ),
          child: PaginatedDataTable(
            header: null,
            rowsPerPage: rowsPerPage,
            showEmptyRows: true,
            showFirstLastButtons: true,
            availableRowsPerPage: const [rowsPerPage],
            onPageChanged: (idx) => ref
                .read(reglasNutricionalesProvider.notifier)
                .loadData(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 65,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("CONDICIONES", width: usableWidth * 0.32),
              _col("ACCIÓN", width: usableWidth * 0.15),
              _col("OBJETIVO", width: usableWidth * 0.23),
              _col("ESTRICTA", width: usableWidth * 0.12),
              _col("ACCIONES", width: usableWidth * 0.18, center: true),
            ],
            source: _ReglasNutricionalesDataSource(
              rules: state.rules,
              totalRows: state.totalItems,
              offset: state.offset,
              formData: state.formData,
              isLoading: state.isLoading,
              onEdit: _showForm,
              onDelete: _deleteRule,
              totalWidth: usableWidth,
              context: context,
              indicador: state.indicadorFilter,
            ),
          ),
        );
      }),
    );
  }

  DataColumn _col(String label, {required double width, bool center = false}) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Container(
          alignment: center ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  void _showForm([Map<String, dynamic>? rule]) {
    final state = ref.read(reglasNutricionalesProvider);
    showDialog(
      context: context,
      barrierColor: AppTema.azulOscuro.withValues(alpha: 0.4),
      builder: (ctx) => _NutritionalRuleFormDialog(
        formData: state.formData,
        initialRule: rule,
        defaultIndicador: state.indicadorFilter,
        onSaved: () {
          final notifier = ref.read(reglasNutricionalesProvider.notifier);
          notifier.markDirty();
          notifier.loadData();
        },
      ),
    );
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Eliminar regla?",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content:
            const Text("Se eliminará la regla nutricional del motor experto."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Eliminar")),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(reglasNutricionalesProvider.notifier).deleteRule(id);
    }
  }
}

class _ReglasNutricionalesDataSource extends DataTableSource {
  final List<dynamic> rules;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Map<String, List<dynamic>> formData;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;
  final double totalWidth;
  final BuildContext context;
  final String indicador;

  _ReglasNutricionalesDataSource({
    required this.rules,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.formData,
    required this.onEdit,
    required this.onDelete,
    required this.totalWidth,
    required this.context,
    required this.indicador,
  });

  @override
  DataRow? getRow(int index) {
    final rowColor = index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC);

    if (isLoading) {
      return DataRow(
        color: WidgetStateProperty.all(rowColor),
        cells: [
          DataCell(SizedBox(
              width: totalWidth * 0.32,
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: NutriShimmer(width: 150, height: 20),
                  )))),
          DataCell(SizedBox(
              width: totalWidth * 0.15,
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: NutriShimmer(width: 80, height: 20),
                  )))),
          DataCell(SizedBox(
              width: totalWidth * 0.23,
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: NutriShimmer(width: double.infinity, height: 24)))),
          DataCell(SizedBox(
              width: totalWidth * 0.12,
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: NutriShimmer(width: 60, height: 20)))),
          DataCell(SizedBox(
            width: totalWidth * 0.18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NutriShimmer(
                    width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 8),
                NutriShimmer(
                    width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
              ],
            ),
          )),
        ],
      );
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= rules.length) return null;
    final r = rules[localIndex];

    final condicionesIdsRaw = r["id_condiciones"];
    final List<dynamic> condicionesIds =
        condicionesIdsRaw is List ? condicionesIdsRaw : [];

    final condList = formData["condiciones"] ?? [];
    final nombresCondiciones = condicionesIds.map((id) {
      final match = condList.firstWhere(
        (c) => c["id"] == id,
        orElse: () => <String, dynamic>{},
      );
      return match.isNotEmpty ? (match["nombre"] ?? "") : "C-$id";
    }).join(", ");

    final isPeso = indicador == "BMI";
    final targetName = reglasNutricionalesTargetName(r);
    final targetType = r["objetivo_nombre"] ?? "Objetivo";

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
        DataCell(SizedBox(
          width: totalWidth * 0.32,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isPeso ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isPeso ? Icons.monitor_weight_rounded : Icons.height_rounded,
                      color: isPeso ? const Color(0xFF15803D) : const Color(0xFFCA8A04),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nombresCondiciones.isEmpty ? "Sin condiciones" : nombresCondiciones,
                    softWrap: true,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _accionBadge(r['accion_codigo'] ?? 'N/A'),
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.23,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  targetType,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.blueGrey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  targetName,
                  softWrap: true,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.12,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _estrictaWidget(r['es_estricta'] == true),
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.18,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HoverActionButton(
                  icon: Icons.edit_note_rounded,
                  label: "Editar",
                  color: Colors.orange,
                  onTap: () => onEdit(r),
                ),
                const SizedBox(width: 12),
                _HoverActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: "Eliminar",
                  color: Colors.redAccent,
                  onTap: () => onDelete(r["id"]),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _accionBadge(String label) {
    Color bg = const Color(0xFFF1F5F9);
    Color tx = Colors.blueGrey;
    String displayLabel = _sentenceCaseLabel(label);
    if (label == 'ELIMINAR') {
      bg = const Color(0xFFFEE2E2);
      tx = const Color(0xFFB91C1C);
      displayLabel = 'Eliminar';
    } else if (label == 'PRIORIZAR') {
      bg = const Color(0xFFDCFCE7);
      tx = const Color(0xFF15803D);
      displayLabel = 'Priorizar';
    } else if (label == 'DISMINUIR') {
      bg = const Color(0xFFFEF3C7);
      tx = const Color(0xFFB45309);
      displayLabel = 'Disminuir';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(displayLabel,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w800, color: tx)),
    );
  }

  Widget _estrictaWidget(bool isStrict) {
    final color = isStrict ? const Color(0xFFDC2626) : Colors.blueGrey;
    final bg = isStrict ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isStrict ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
              size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            isStrict ? "Sí" : "No",
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => (isLoading && totalRows == 0) ? 5 : totalRows;
  @override
  int get selectedRowCount => 0;
}

class _NutritionalRuleFormDialog extends ConsumerStatefulWidget {
  final Map<String, List<dynamic>> formData;
  final Map<String, dynamic>? initialRule;
  final String? defaultIndicador;
  final VoidCallback onSaved;

  const _NutritionalRuleFormDialog({
    required this.formData,
    this.initialRule,
    this.defaultIndicador,
    required this.onSaved,
  });

  @override
  ConsumerState<_NutritionalRuleFormDialog> createState() =>
      _NutritionalRuleFormDialogState();
}

class _NutritionalRuleFormDialogState
    extends ConsumerState<_NutritionalRuleFormDialog> {
  late String _selectedIndicador; // "BMI" or "HFA"
  int? _idAccion, _idObjetivo, _idTarget;
  late TextEditingController _mensajeController;
  late List<int> _selectedCondiciones;
  late bool _esEstricta;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRule;
    _idAccion = r?["id_accion"];
    _idObjetivo = r?["id_tipo_objetivo"];
    _idTarget = r?["id_ingrediente"] ??
        r?["id_grupo_alimentario"] ??
        r?["id_subgrupo_alimentario"] ??
        r?["id_etiqueta"];
    _mensajeController = TextEditingController(text: r?["mensaje_error"]);
    _selectedCondiciones = List<int>.from(r?["id_condiciones"] ?? []);
    _esEstricta = r?["es_estricta"] ?? false;

    // Detectar indicador de la regla al editar, o usar defaultIndicador
    if (r != null) {
      String? ind = r["indicador_codigo"]?.toString().toUpperCase();
      if (ind == null || (ind != "BMI" && ind != "HFA")) {
        final List condIds = r["id_condiciones"] is List ? r["id_condiciones"] : [];
        if (condIds.isNotEmpty) {
          final allConds = widget.formData["condiciones"] ?? [];
          for (final c in allConds) {
            if (condIds.contains(c["id"])) {
              final cInd = c["indicador_codigo"]?.toString().toUpperCase();
              if (cInd == "BMI" || cInd == "HFA") {
                ind = cInd;
                break;
              }
            }
          }
        }
      }
      _selectedIndicador = ind ?? widget.defaultIndicador ?? "BMI";
    } else {
      _selectedIndicador = widget.defaultIndicador ?? "BMI";
    }
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialRule != null;
    List<dynamic> targetList = [];
    if (_idObjetivo == 1) {
      targetList = widget.formData["ingredientes"] ?? [];
    } else if (_idObjetivo == 2) {
      targetList = widget.formData["grupos"] ?? [];
    } else if (_idObjetivo == 3) {
      targetList = widget.formData["etiquetas"] ?? [];
    } else if (_idObjetivo == 4) {
      targetList = widget.formData["subgrupos"] ?? [];
    }

    final condicionesFiltradas = (widget.formData["condiciones"] ?? []).where((c) {
      final ind = (c["indicador_codigo"]?.toString().toUpperCase() ?? "BMI");
      return ind == _selectedIndicador;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? "Modificar regla nutricional" : "Nueva regla nutricional",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTema.azulOscuro,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Complete la configuración técnica de la regla para el motor experto.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle("Clasificación"),
              Row(
                children: [
                  _typeOption(
                    "BMI",
                    "Peso",
                    Icons.monitor_weight_rounded,
                    "Regla para peso",
                  ),
                  const SizedBox(width: 12),
                  _typeOption(
                    "HFA",
                    "Talla",
                    Icons.height_rounded,
                    "Regla para estatura",
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle("Objetivo del alimento"),
              _dropdownInput<int>(
                value: _idObjetivo,
                hint: "Tipo de objetivo*",
                icon: Icons.track_changes_outlined,
                items: (widget.formData["objetivos"] ?? [])
                    .map((o) => DropdownMenuItem<int>(
                          value: o["id"],
                          child: Text(
                            o["nombre"].toString(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _idObjetivo = v;
                  _idTarget = null;
                }),
              ),
              if (_idObjetivo != null) ...[
                const SizedBox(height: 12),
                _dropdownInput<int>(
                  value: _idTarget,
                  hint: "Seleccionar elemento*",
                  icon: Icons.ads_click_outlined,
                  items: targetList
                      .map((t) => DropdownMenuItem<int>(
                            value: t["id"],
                            child: Text(
                              t["nombre"] ?? t["nombre_visible"] ?? "-",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _idTarget = v),
                ),
              ],
              const SizedBox(height: 24),
              _sectionTitle("Acción y restricción"),
              _dropdownInput<int>(
                value: _idAccion,
                hint: "Acción sugerida*",
                icon: Icons.lightbulb_outline_rounded,
                items: (widget.formData["acciones"] ?? [])
                    .map((a) => DropdownMenuItem<int>(
                          value: a["id"],
                          child: Text(
                            _sentenceCaseLabel(a["nombre"]),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _idAccion = v),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTema.grisLienzo,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      _esEstricta ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: _esEstricta ? Colors.redAccent : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Restricción estricta",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTema.azulOscuro,
                            ),
                          ),
                          Text(
                            _esEstricta
                                ? "Bloqueo obligatorio al generar planes nutricionales."
                                : "Regla sugerida o de ajuste no bloqueante.",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                        value: _esEstricta,
                        activeTrackColor: Colors.redAccent,
                        onChanged: (v) => setState(() => _esEstricta = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle(
                  "Aplicabilidad (${_selectedIndicador == 'BMI' ? 'Condiciones de peso' : 'Condiciones de talla'})"),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: AppTema.grisLienzo,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: condicionesFiltradas.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            "No hay condiciones registradas para este indicador.",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: condicionesFiltradas.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, idx) {
                            final c = condicionesFiltradas[idx];
                            final int id = (c["id"] as num).toInt();
                            final bool isChecked =
                                _selectedCondiciones.contains(id);
                            return CheckboxListTile(
                              title: Text(
                                c["nombre"]?.toString() ?? "Condición",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isChecked
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isChecked
                                      ? AppTema.azulOscuro
                                      : Colors.blueGrey.shade800,
                                ),
                              ),
                              value: isChecked,
                              activeColor: AppTema.verdeSalud,
                              checkboxShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              dense: true,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedCondiciones.add(id);
                                  } else {
                                    _selectedCondiciones.remove(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              _sectionTitle("Mensaje clínico (opcional)"),
              _minimalInput(
                _mensajeController,
                "Mensaje explicativo para el paciente o reporte...",
                Icons.chat_bubble_outline_rounded,
                lines: 2,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancelar",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTema.azulPrincipal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _saving ? "Procesando..." : "Guardar regla",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
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
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: AppTema.azulPrincipal.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _typeOption(String val, String title, IconData icon, String sub) {
    final sel = _selectedIndicador == val;
    final color = sel ? AppTema.verdeSalud : Colors.grey.shade300;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedIndicador == val) return;
          setState(() {
            _selectedIndicador = val;
            final validIds = (widget.formData["condiciones"] ?? [])
                .where((c) =>
                    (c["indicador_codigo"]?.toString().toUpperCase() ?? "BMI") ==
                    val)
                .map((c) => (c["id"] as num).toInt())
                .toSet();
            _selectedCondiciones.removeWhere((id) => !validIds.contains(id));
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sel
                ? AppTema.verdeSalud.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: sel ? 2 : 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: sel ? AppTema.verdeSalud : Colors.grey.shade500,
                ),
              ),
              Text(
                sub,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownInput<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.arrow_drop_down, color: AppTema.azulPrincipal),
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTema.azulOscuro,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTema.azulPrincipal, size: 18),
        filled: true,
        fillColor: AppTema.grisLienzo,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _minimalInput(TextEditingController c, String h, IconData i,
          {int lines = 1}) =>
      TextFormField(
        controller: c,
        maxLines: lines,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTema.azulOscuro,
        ),
        decoration: InputDecoration(
          hintText: h,
          prefixIcon: Icon(i, color: AppTema.azulPrincipal, size: 18),
          filled: true,
          fillColor: AppTema.grisLienzo,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Future<void> _save() async {
    if (_idAccion == null ||
        _idObjetivo == null ||
        _idTarget == null ||
        _selectedCondiciones.isEmpty) {
      NutriSnack.show(
        context,
        "Por favor completa el objetivo, acción y selecciona al menos una condición.",
        isError: true,
        ref: ref,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        "id_accion": _idAccion,
        "id_tipo_objetivo": _idObjetivo,
        "mensaje_error": _mensajeController.text.trim().isEmpty
            ? null
            : _mensajeController.text.trim(),
        "id_condiciones": _selectedCondiciones,
        "es_estricta": _esEstricta,
        "id_ingrediente": _idObjetivo == 1 ? _idTarget : null,
        "id_grupo_alimentario": _idObjetivo == 2 ? _idTarget : null,
        "id_etiqueta": _idObjetivo == 3 ? _idTarget : null,
        "id_subgrupo_alimentario": _idObjetivo == 4 ? _idTarget : null
      };
      if (widget.initialRule != null) {
        await ref.read(dioProvider).put(
            "reglas-nutricionales/${widget.initialRule!['id']}",
            data: payload);
      } else {
        await ref.read(dioProvider).post("reglas-nutricionales", data: payload);
      }
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        NutriSnack.show(
          context,
          widget.initialRule != null
              ? "Regla actualizada correctamente"
              : "Regla creada exitosamente",
          ref: ref,
        );
      }
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al guardar regla: $e",
            isError: true, ref: ref);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HoverActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onHover: (hovered) {
        setState(() {
          _isHovered = hovered;
        });
      },
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      hoverColor: Colors.transparent,
      splashColor: widget.color.withValues(alpha: 0.2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.2)
                  : Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: widget.color, size: 18),
            const SizedBox(height: 4),
            Text(widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                    height: 1.0)),
          ],
        ),
      ),
    );
  }
}
