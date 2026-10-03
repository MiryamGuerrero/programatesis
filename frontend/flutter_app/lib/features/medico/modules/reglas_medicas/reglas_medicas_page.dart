import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "../../data/medical_catalogs_notifier.dart";

class ReglasMedicasPage extends ConsumerStatefulWidget {
  const ReglasMedicasPage({super.key});

  @override
  ConsumerState<ReglasMedicasPage> createState() => _ReglasMedicasPageState();
}

class _ReglasMedicasPageState extends ConsumerState<ReglasMedicasPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(medicalRulesProvider.notifier);
      // Cargar únicamente la pestaña activa si no está en memoria
      notifier.loadPageIfNeeded(origen: "CLINICA");
      // Suscripción reactiva en tiempo real con Supabase ante cambios reales en la BD
      _setupRealtime();
    });
  }

  void _setupRealtime() {
    try {
      final supabase = ref.read(supabaseClientProvider);
      _realtimeChannel = supabase
          .channel('medico_reglas_rt_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'heuristico',
            table: 'regla',
            callback: (_) {
              ref.read(medicalRulesProvider.notifier).refreshAllSilently();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'heuristico',
            table: 'condicion_regla',
            callback: (_) {
              ref.read(medicalRulesProvider.notifier).refreshAllSilently();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      if (!mounted) return;
      ref.read(medicalRulesProvider.notifier).setSearchQuery("");
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(medicalRulesProvider.notifier).setSearchQuery(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(medicalRulesProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(state),
            const SizedBox(height: 32),
            _buildToolbar(state),
            const SizedBox(height: 32),
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
        Text("Reglas Clínicas",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(
            "Configura priorizaciones, restricciones y exclusiones alimentarias basadas en diagnósticos clínicos y síntomas temporales.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildToolbar(MedicalRulesState state) {
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
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar por diagnóstico u objetivo de regla...",
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _searchDebounce?.cancel();
                          ref.read(medicalRulesProvider.notifier).setSearchQuery("");
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _onSearchChanged,
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
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.add_circle, size: 20, color: Colors.white),
            label: Text("Nueva regla",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(MedicalRulesState state) {
    if (state.isLoading && state.rules.isEmpty) {
      return const Row(
        children: [
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
          Expanded(child: NutriResumenCardShimmer()),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: NutriResumenCard(
              titulo: 'REGLAS MÉDICAS',
              valor: '${state.totalItems}',
              icon: Icons.gavel_rounded,
              colorValor: AppTema.azulPrincipal,
              subtitle: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Clínicas: ${state.clinicalRulesCount}",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 10,
                    color: const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCA8A04),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Temporales: ${state.temporalRulesCount}",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: NutriResumenCard(
              titulo: 'REGLAS ESTRICTAS',
              valor: '${state.strictRulesCount}',
              icon: Icons.lock_outline_rounded,
              colorValor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(MedicalRulesState state) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
      ),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTabItem(
                  label: "Condiciones clínicas",
                  count: state.clinicalRulesCount,
                  isSelected: state.origenFilter == "CLINICA",
                  onTap: () {
                    ref.read(medicalRulesProvider.notifier).setOrigenFilter("CLINICA");
                  },
                ),
              ),
              Expanded(
                child: _buildTabItem(
                  label: "Síntomas temporales",
                  count: state.temporalRulesCount,
                  isSelected: state.origenFilter == "TEMPORAL",
                  onTap: () {
                    ref.read(medicalRulesProvider.notifier).setOrigenFilter("TEMPORAL");
                  },
                ),
              ),
            ],
          ),
          // Indicador animado que se desliza suavemente entre pestañas
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: state.origenFilter == "CLINICA"
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

  Widget _buildContent(MedicalRulesState state) {
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
          final double direction = (state.origenFilter == "TEMPORAL") ? 1.0 : -1.0;
          final isIncoming = child.key == ValueKey("content_reglas_${state.origenFilter}");
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
          key: ValueKey("content_reglas_${state.origenFilter}"),
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

  Widget _buildFiltersPanel(MedicalRulesState state) {
    final conds = (state.formData["condiciones"] ?? []).where((c) {
      final tipo = c["id_tipo_condicion"];
      if (state.origenFilter == "CLINICA") {
        return tipo == 1;
      } else {
        return tipo == 2;
      }
    }).toList();

    List<dynamic> targetList = [];
    if (state.idTipoObjetivoFilter == 1) {
      targetList = state.formData["ingredientes"] ?? [];
    } else if (state.idTipoObjetivoFilter == 2) {
      targetList = state.formData["grupos"] ?? [];
    } else if (state.idTipoObjetivoFilter == 3) {
      targetList = state.formData["etiquetas"] ?? [];
    } else if (state.idTipoObjetivoFilter == 4) {
      targetList = state.formData["subgrupos"] ?? [];
    }

    final hasObjetivo = state.idTipoObjetivoFilter != null;

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
                    "Tipo de enfermedad",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: state.idCondicionFilter,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.medical_services_outlined, color: AppTema.verdeSalud, size: 18),
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
                        "Seleccionar tipo de enfermedad",
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
                    onChanged: (v) => ref.read(medicalRulesProvider.notifier).setIdCondicionFilter(v),
                  ),
                ],
              );

              final col2 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Acción médica",
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
                        isSelected: state.idAccionFilter == 3,
                        onTap: () => ref.read(medicalRulesProvider.notifier).setIdAccionFilter(state.idAccionFilter == 3 ? null : 3),
                      ),
                      const SizedBox(width: 6),
                      _buildActionButton(
                        label: "Disminuir",
                        icon: Icons.arrow_downward_rounded,
                        color: const Color(0xFFCA8A04),
                        bgSelected: const Color(0xFFFEF9C3),
                        isSelected: state.idAccionFilter == 2,
                        onTap: () => ref.read(medicalRulesProvider.notifier).setIdAccionFilter(state.idAccionFilter == 2 ? null : 2),
                      ),
                      const SizedBox(width: 6),
                      _buildActionButton(
                        label: "Eliminar",
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFB91C1C),
                        bgSelected: const Color(0xFFFEE2E2),
                        isSelected: state.idAccionFilter == 1,
                        onTap: () => ref.read(medicalRulesProvider.notifier).setIdAccionFilter(state.idAccionFilter == 1 ? null : 1),
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
                      initialValue: state.idObjetivoFilter,
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
                      onChanged: (v) => ref.read(medicalRulesProvider.notifier).setIdObjetivoFilter(v),
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
              onPressed: () => ref.read(medicalRulesProvider.notifier).clearFilters(),
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
    required MedicalRulesState state,
  }) {
    final isSelected = state.idTipoObjetivoFilter == value;
    final color = isSelected ? AppTema.azulPrincipal : Colors.blueGrey.shade600;
    final bg = isSelected ? AppTema.azulPrincipal.withValues(alpha: 0.05) : Colors.white;
    final borderColor = isSelected ? AppTema.azulPrincipal : Colors.grey.shade300;

    return Expanded(
      child: InkWell(
        onTap: () {
          final newValue = isSelected ? null : value;
          ref.read(medicalRulesProvider.notifier).setIdTipoObjetivoFilter(newValue);
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

  Widget _buildTable(MedicalRulesState state) {
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
              "No se encontraron reglas clínicas",
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
        const rowsPerPage = MedicalRulesNotifier.pageSize;

        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(
                elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
            dividerColor: Colors.transparent,
          ),
          child: PaginatedDataTable(
            key: ValueKey("tabla_reglas_datatable_${state.origenFilter}"),
            header: null,
            rowsPerPage: rowsPerPage,
            showEmptyRows: true,
            showFirstLastButtons: true,
            availableRowsPerPage: const [rowsPerPage],
            onPageChanged: (idx) =>
                ref.read(medicalRulesProvider.notifier).loadPage(offset: idx),
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 65,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("DIAGNÓSTICO", width: usableWidth * 0.32),
              _col("ACCIÓN", width: usableWidth * 0.15),
              _col("OBJETIVO", width: usableWidth * 0.23),
              _col("ESTRICTA", width: usableWidth * 0.12),
              _col("ACCIONES", width: usableWidth * 0.18, center: true),
            ],
            source: _MedicalRulesDataSource(
              rules: state.rules,
              totalRows: state.totalItems,
              offset: state.offset,
              isLoading: state.isLoading,
              formData: state.formData,
              onEdit: _showForm,
              onDelete: (id) => _eliminarRegla(id),
              totalWidth: usableWidth,
              context: context,
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

  Future<void> _showForm([Map<String, dynamic>? rule]) async {
    var state = ref.read(medicalRulesProvider);
    if (state.formData.isEmpty) {
      await ref.read(medicalRulesProvider.notifier).loadFormData();
      if (!mounted) return;
      state = ref.read(medicalRulesProvider);
      if (state.formData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudieron cargar los datos del formulario."),
          ),
        );
        return;
      }
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _NutritionalRuleFormDialog(
        formData: state.formData,
        initialRule: rule,
        defaultOrigen: state.origenFilter,
        onSaved: () =>
            ref.read(medicalRulesProvider.notifier).refreshAfterMutation(),
      ),
    );
  }

  Future<void> _eliminarRegla(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Eliminar regla médica?"),
        content:
            const Text("Esta acción eliminará la lógica del motor experto."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(medicalRulesProvider.notifier).deleteRule(id);
    }
  }
}

class _MedicalRulesDataSource extends DataTableSource {
  final List<dynamic> rules;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Map<String, List<dynamic>> formData;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;
  final double totalWidth;
  final BuildContext context;

  _MedicalRulesDataSource({
    required this.rules,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.formData,
    required this.onEdit,
    required this.onDelete,
    required this.totalWidth,
    required this.context,
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
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 8),
              NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.circular(12)),
            ],
          ),
        )),
      ]);
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= rules.length) return null;
    final r = rules[localIndex];

    final nombresCondiciones = (r["condiciones_nombres"] ?? "SIN DIAGNÓSTICOS").toString();
    final isClinica = (r["origen_regla"] ?? "CLINICA") == "CLINICA";

    final targetName = r["ingrediente_nombre"] ??
        r["grupo_nombre"] ??
        r["subgrupo_nombre"] ??
        r["etiqueta_nombre"] ??
        "-";
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
                  color: isClinica ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    isClinica
                        ? "assets/images/clinica.png"
                        : "assets/images/temporal.png",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombresCondiciones,
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
          child: _estrictaWidget(
            r['es_estricta'] == true ||
            r['id_accion'] == 1 ||
            r['accion_codigo'] == 'ELIMINAR' ||
            isClinica,
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
    ]);
  }

  Widget _accionBadge(String rawLabel) {
    final label = rawLabel.trim().toUpperCase();
    Color bg = const Color(0xFFFEE2E2);
    Color tx = const Color(0xFFDC2626);
    IconData icon = Icons.delete_rounded;
    String displayLabel = "ELIMINAR";

    if (label == 'PRIORIZAR' || label == '3') {
      bg = const Color(0xFFDCFCE7);
      tx = const Color(0xFF16A34A);
      icon = Icons.arrow_upward_rounded;
      displayLabel = "PRIORIZAR";
    } else if (label == 'DISMINUIR' || label == '2') {
      bg = const Color(0xFFFFEDD5);
      tx = const Color(0xFFEA580C);
      icon = Icons.arrow_downward_rounded;
      displayLabel = "DISMINUIR";
    } else if (label == 'ELIMINAR' || label == '1') {
      bg = const Color(0xFFFEE2E2);
      tx = const Color(0xFFDC2626);
      icon = Icons.delete_rounded;
      displayLabel = "ELIMINAR";
    } else {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 10, color: tx),
          ),
          const SizedBox(width: 6),
          Text(
            displayLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tx,
            ),
          ),
        ],
      ),
    );
  }

  Widget _estrictaWidget(bool esEstricta) {
    final icon = esEstricta ? Icons.lock_rounded : Icons.lock_open_rounded;
    final color = esEstricta ? const Color(0xFF15803D) : Colors.blueGrey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          esEstricta ? "Sí" : "No",
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
  final String? defaultOrigen;
  final VoidCallback onSaved;
  const _NutritionalRuleFormDialog({
    required this.formData,
    this.initialRule,
    this.defaultOrigen,
    required this.onSaved,
  });
  @override
  ConsumerState<_NutritionalRuleFormDialog> createState() =>
      _NutritionalRuleFormDialogState();
}

class _NutritionalRuleFormDialogState
    extends ConsumerState<_NutritionalRuleFormDialog> {
  int? _idAccion, _idObjetivo, _idTarget;
  late TextEditingController _mensajeController;
  late List<int> _selectedCondiciones;
  late bool _esEstricta;
  bool _saving = false;
  String _condicionSearch = "";
  int _filtroTipoCondicion = 0; // 0: Todas, 1: Crónicas, 2: Temporales
  String? _formWarningText;

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
    _mensajeController = TextEditingController(text: r?["mensaje_error"] ?? "");
    _selectedCondiciones = List<int>.from(r?["id_condiciones"] ?? []);
    _esEstricta = r?["es_estricta"] ?? false;

    if (widget.defaultOrigen == "TEMPORAL") {
      _filtroTipoCondicion = 2;
    } else if (widget.defaultOrigen == "CLINICA") {
      _filtroTipoCondicion = 1;
    }
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  bool _computeIsClinicalRule() {
    final condiciones = widget.formData["condiciones"] ?? [];
    for (final c in condiciones) {
      if (c is Map &&
          _selectedCondiciones.contains(c["id"]) &&
          c["id_tipo_condicion"] == 1) {
        return true;
      }
    }
    return false;
  }

  String _getTargetName(int? id, int? idObj) {
    if (id == null || idObj == null) return "";
    List<dynamic> list = [];
    if (idObj == 1) list = widget.formData["ingredientes"] ?? [];
    if (idObj == 2) list = widget.formData["grupos"] ?? [];
    if (idObj == 3) list = widget.formData["etiquetas"] ?? [];
    if (idObj == 4) list = widget.formData["subgrupos"] ?? [];
    for (final item in list) {
      if (item is Map && item["id"] == id) {
        return (item["nombre"] ?? item["nombre_visible"] ?? "").toString();
      }
    }
    return "";
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

    final isClinicalRule = _computeIsClinicalRule();
    final forceStrict = _idAccion == 1 || isClinicalRule;
    final activeEsEstricta = forceStrict ? true : _esEstricta;

    final todasCondiciones = (widget.formData["condiciones"] ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final listaFiltrada = todasCondiciones.where((c) {
      if (_filtroTipoCondicion == 1 && c["id_tipo_condicion"] != 1) return false;
      if (_filtroTipoCondicion == 2 && c["id_tipo_condicion"] != 2) return false;
      if (_condicionSearch.isNotEmpty) {
        final nom = (c["nombre"] ?? "").toString().toLowerCase();
        return nom.contains(_condicionSearch.toLowerCase());
      }
      return true;
    }).toList();

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 960,
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EAF2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppTema.azulPrincipal,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEdit
                          ? Icons.edit_note_rounded
                          : Icons.rule_folder_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? "Editar Regla Clínica" : "Nueva Regla Clínica",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTema.azulOscuro,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF64748B),
                    iconSize: 20,
                    tooltip: "Cerrar",
                    splashRadius: 18,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Guía explicativa: Cómo crear una regla clínica
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppTema.verdeSalud,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Configuración de Regla Clínica",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "1. Seleccione elemento   ➜   2. Defina acción médica   ➜   3. Elija patología",
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Las reglas clínicas aplican a las condiciones seleccionadas. Puede asociar la regla a una sola condición sin necesidad de seleccionar otras.",
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: const Color(0xFF14532D),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Cuerpo del Modal: 3 Columnas
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna 1: Elemento y Objetivo (Flex 7)
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFieldLabel("Tipo de objetivo", isRequired: true),
                      DropdownButtonFormField<int>(
                        key: ValueKey("obj_$_idObjetivo"),
                        initialValue: _idObjetivo,
                        isExpanded: true,
                        decoration: _fieldDecor(
                          "Tipo de objetivo",
                          Icons.category_outlined,
                        ),
                        items: (widget.formData["objetivos"] ?? [])
                            .map((o) => DropdownMenuItem<int>(
                                  value: o["id"],
                                  child: Text(
                                    o["nombre"].toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTema.azulOscuro,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _idObjetivo = v;
                          _idTarget = null;
                          _formWarningText = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Elemento específico", isRequired: true),
                      LayoutBuilder(
                        builder: (context, colConstraints) {
                          return Autocomplete<Map<String, dynamic>>(
                            key: ValueKey("auto_$_idObjetivo"),
                            initialValue: TextEditingValue(
                              text: _getTargetName(_idTarget, _idObjetivo),
                            ),
                            displayStringForOption: (opt) =>
                                (opt["nombre"] ?? opt["nombre_visible"] ?? "")
                                    .toString(),
                            optionsBuilder: (textEditingValue) {
                              if (_idObjetivo == null) return const [];
                              if (textEditingValue.text.isEmpty) {
                                return targetList
                                    .whereType<Map<String, dynamic>>()
                                    .take(15);
                              }
                              final q = textEditingValue.text.toLowerCase();
                              return targetList
                                  .whereType<Map<String, dynamic>>()
                                  .where((item) {
                                final name = (item["nombre"] ??
                                        item["nombre_visible"] ??
                                        "")
                                    .toString()
                                    .toLowerCase();
                                return name.contains(q);
                              }).take(20);
                            },
                            onSelected: (opt) {
                              setState(() {
                                _idTarget = (opt["id"] as num?)?.toInt();
                                _formWarningText = null;
                              });
                            },
                            fieldViewBuilder: (context, textEditingController,
                                focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                enabled: _idObjetivo != null,
                                style: GoogleFonts.inter(fontSize: 12),
                                decoration: _fieldDecor(
                                  _idObjetivo == null
                                      ? "Seleccione un tipo primero"
                                      : "Escriba para buscar...",
                                  Icons.search_rounded,
                                ).copyWith(
                                  suffixIcon: _idTarget != null
                                      ? IconButton(
                                          icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                              color: Colors.blueGrey),
                                          tooltip: "Borrar selección",
                                          onPressed: () {
                                            textEditingController.clear();
                                            setState(() {
                                              _idTarget = null;
                                              _formWarningText = null;
                                            });
                                          },
                                        )
                                      : const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: Colors.blueGrey),
                                ),
                              );
                            },
                            optionsViewBuilder:
                                (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  shadowColor: Colors.black26,
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white,
                                  child: Container(
                                    width: colConstraints.maxWidth,
                                    constraints:
                                        const BoxConstraints(maxHeight: 200),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: options.isEmpty
                                        ? Padding(
                                            padding:
                                                const EdgeInsets.all(12.0),
                                            child: Text(
                                              "No se encontraron elementos",
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: Colors.blueGrey),
                                            ),
                                          )
                                        : ListView.builder(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 4),
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final opt =
                                                  options.elementAt(index);
                                              final name = opt["nombre"] ??
                                                  opt["nombre_visible"] ??
                                                  "-";
                                              final isSel =
                                                  opt["id"] == _idTarget;
                                              return InkWell(
                                                onTap: () =>
                                                    onSelected(opt),
                                                child: Container(
                                                  color: isSel
                                                      ? AppTema.azulPrincipal
                                                          .withValues(
                                                              alpha: 0.08)
                                                      : Colors.transparent,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          name,
                                                          style: GoogleFonts
                                                              .inter(
                                                            fontSize: 11.5,
                                                            fontWeight: isSel
                                                                ? FontWeight
                                                                    .w700
                                                                : FontWeight
                                                                    .w500,
                                                            color: isSel
                                                                ? AppTema
                                                                    .azulPrincipal
                                                                : AppTema
                                                                    .azulOscuro,
                                                          ),
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                      if (isSel)
                                                        const Icon(
                                                            Icons.check,
                                                            size: 14,
                                                            color: AppTema
                                                                .azulPrincipal),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Divisor vertical 1
                Container(
                  width: 1.0,
                  height: 260,
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),

                // Columna 2: Acción Clínica y Severidad (Flex 7)
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFieldLabel("Acción clínica", isRequired: true),
                      DropdownButtonFormField<int>(
                        key: ValueKey("accion_$_idAccion"),
                        initialValue: _idAccion,
                        isExpanded: true,
                        decoration: _fieldDecor(
                          "Acción clínica",
                          Icons.shield_outlined,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 1,
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_outlined,
                                    color: Colors.red, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "Eliminar (Exclusión)",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.amber.shade800, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "Limitar (Moderado)",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    color: AppTema.verdeSalud, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "Recomendar (Beneficioso)",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTema.verdeSalud,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _idAccion = v;
                          _formWarningText = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Restricción estricta"),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            forceStrict
                                ? "Bloqueo Requerido"
                                : "Bloqueo Estricto",
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: forceStrict
                                  ? Colors.blueGrey
                                  : AppTema.azulOscuro,
                            ),
                          ),
                          subtitle: Text(
                            forceStrict
                                ? "Obligatorio en exclusiones o patologías crónicas."
                                : "Bloquea recetas y menús con este elemento.",
                            style: GoogleFonts.inter(
                                fontSize: 9.5, color: Colors.blueGrey),
                          ),
                          value: activeEsEstricta,
                          activeTrackColor: AppTema.azulPrincipal,
                          onChanged: forceStrict
                              ? null
                              : (v) => setState(() => _esEstricta = v),
                        ),
                      ),
                    ],
                  ),
                ),

                // Divisor vertical 2
                Container(
                  width: 1.0,
                  height: 260,
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),

                // Columna 3: Diagnósticos y Condiciones Clínicas (Flex 10)
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _buildFieldLabel(
                            "Condición o Patología",
                            isRequired: true,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedCondiciones.isNotEmpty
                                  ? AppTema.azulPrincipal
                                      .withValues(alpha: 0.1)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedCondiciones.isEmpty
                                  ? "0 sel."
                                  : "${_selectedCondiciones.length} sel.",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _selectedCondiciones.isNotEmpty
                                    ? AppTema.azulPrincipal
                                    : Colors.blueGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        onChanged: (val) =>
                            setState(() => _condicionSearch = val.trim()),
                        decoration: _fieldDecor(
                          "Buscar patología o síntoma...",
                          Icons.search_rounded,
                        ),
                        style: GoogleFonts.inter(fontSize: 11.5),
                      ),
                      const SizedBox(height: 4),
                      // Filtros de categoría abajo del buscador
                      Row(
                        children: [
                          _buildTipoChip(0, "Todas"),
                          const SizedBox(width: 4),
                          _buildTipoChip(1, "🩺 Crónicas"),
                          const SizedBox(width: 4),
                          _buildTipoChip(2, "⏱️ Temporales"),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Lista scrolleable con tarjetas tipo toggle
                      Container(
                        height: 168,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: listaFiltrada.isEmpty
                            ? Center(
                                child: Text(
                                  "Sin resultados con ese criterio",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(4),
                                itemCount: listaFiltrada.length,
                                itemBuilder: (context, index) {
                                  final c = listaFiltrada[index];
                                  final int id =
                                      (c["id"] as num).toInt();
                                  final bool isSelected =
                                      _selectedCondiciones.contains(id);
                                  final bool isCronica =
                                      c["id_tipo_condicion"] == 1;
                                  return _buildCondicionToggle(
                                    label: c["nombre"]?.toString() ??
                                        "Condición",
                                    description: c["descripcion"]
                                            ?.toString() ??
                                        (isCronica
                                            ? "Patología crónica reumatológica"
                                            : "Síntoma o condición temporal"),
                                    checked: isSelected,
                                    isCronica: isCronica,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedCondiciones.add(id);
                                        } else {
                                          _selectedCondiciones.remove(id);
                                        }
                                        _formWarningText = null;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Parte de Abajo: Mensaje Clínico Informativo (Ancho Completo)
            _buildFieldLabel("Mensaje clínico informativo (opcional)"),
            TextFormField(
              controller: _mensajeController,
              maxLines: 2,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecor(
                "Ej: Evitar o limitar este alimento para prevenir brotes agudos en fases inflamatorias...",
                Icons.notes_rounded,
              ),
            ),

            // Banner de advertencia si faltan campos
            if (_formWarningText != null) ...[
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formWarningText!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 14, color: Color(0xFF92400E)),
                      onPressed: () => setState(() => _formWarningText = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTema.azulPrincipal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  child: const Text("Cancelar"),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 136,
                  height: 40,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTema.azulPrincipal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEdit ? "Guardar" : "Guardar"),
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

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 5),
      child: RichText(
        text: TextSpan(
          text: label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTema.azulOscuro,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: " *",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCondicionToggle({
    required String label,
    required String description,
    required bool checked,
    required bool isCronica,
    required ValueChanged<bool?> onChanged,
  }) {
    final activeColor =
        isCronica ? AppTema.azulPrincipal : Colors.amber.shade800;
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: checked
              ? activeColor.withValues(alpha: 0.05)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked
                ? activeColor.withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
            width: checked ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: checked,
                onChanged: onChanged,
                activeColor: activeColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: checked ? activeColor : AppTema.azulOscuro,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isCronica
                              ? AppTema.azulPrincipal.withValues(alpha: 0.1)
                              : Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          isCronica ? "Crónica" : "Temporal",
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: isCronica
                                ? AppTema.azulPrincipal
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoChip(int tipo, String label) {
    final isSelected = _filtroTipoCondicion == tipo;
    return InkWell(
      onTap: () => setState(() => _filtroTipoCondicion = tipo),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTema.azulPrincipal
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.blueGrey,
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.grey.shade400,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        prefixIcon: Icon(icon, size: 18, color: Colors.blueGrey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppTema.azulPrincipal, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      );

  Future<void> _save() async {
    setState(() => _formWarningText = null);
    if (_idObjetivo == null) {
      setState(() => _formWarningText = "Por favor seleccione el tipo de objetivo.");
      NutriSnack.show(
        context,
        "Por favor seleccione el tipo de objetivo",
        isError: true,
      );
      return;
    }
    if (_idTarget == null) {
      setState(() => _formWarningText = "Por favor seleccione el elemento específico.");
      NutriSnack.show(
        context,
        "Por favor seleccione el elemento específico",
        isError: true,
      );
      return;
    }
    if (_idAccion == null) {
      setState(() => _formWarningText = "Por favor seleccione la acción clínica.");
      NutriSnack.show(
        context,
        "Por favor seleccione la acción clínica",
        isError: true,
      );
      return;
    }
    if (_selectedCondiciones.isEmpty) {
      setState(() => _formWarningText = "Por favor seleccione al menos una enfermedad o condición.");
      NutriSnack.show(
        context,
        "Por favor seleccione al menos una enfermedad o condición",
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final isClinicalRule = _computeIsClinicalRule();
      final forceStrict = _idAccion == 1 || isClinicalRule;
      final activeEsEstricta = forceStrict ? true : _esEstricta;

      // Determinar origen coherente
      String origen = "CLINICA";
      final condiciones = (widget.formData["condiciones"] ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final selectedTipos = condiciones
          .where((c) => _selectedCondiciones.contains(c["id"]))
          .map((c) => c["id_tipo_condicion"])
          .toSet();

      if (selectedTipos.length == 1 && selectedTipos.first == 2) {
        origen = "TEMPORAL";
      }

      final payload = {
        "id_accion": _idAccion,
        "id_tipo_objetivo": _idObjetivo,
        "mensaje_error": _mensajeController.text.trim(),
        "id_condiciones": _selectedCondiciones,
        "es_estricta": activeEsEstricta,
        "origen_regla": origen,
        "id_ingrediente": _idObjetivo == 1 ? _idTarget : null,
        "id_grupo_alimentario": _idObjetivo == 2 ? _idTarget : null,
        "id_etiqueta": _idObjetivo == 3 ? _idTarget : null,
        "id_subgrupo_alimentario": _idObjetivo == 4 ? _idTarget : null,
      };

      final dio = ref.read(dioProvider);
      if (widget.initialRule != null) {
        await dio.put("reglas-medicas/${widget.initialRule!['id']}",
            data: payload);
        if (mounted) {
          NutriSnack.show(context, "Regla clínica actualizada exitosamente");
        }
      } else {
        await dio.post("reglas-medicas", data: payload);
        if (mounted) {
          NutriSnack.show(context, "Regla clínica guardada exitosamente");
        }
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        NutriSnack.show(
          context,
          "Error al guardar regla clínica: $e",
          isError: true,
        );
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
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                    height: 1.0)),
          ],
        ),
      ),
    );
  }
}
