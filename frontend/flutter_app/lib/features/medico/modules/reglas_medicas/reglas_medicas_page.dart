import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(medicalRulesProvider.notifier).loadPage();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
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
            _buildFiltersPanel(state),
            const SizedBox(height: 24),
            _buildTable(state),
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
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  ref.read(medicalRulesProvider.notifier).setSearchQuery(v);
                });
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
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              label: "Condiciones clínicas",
              isSelected: state.origenFilter == "CLINICA",
              onTap: () => ref.read(medicalRulesProvider.notifier).setOrigenFilter("CLINICA"),
            ),
          ),
          Expanded(
            child: _buildTabItem(
              label: "Síntomas temporales",
              isSelected: state.origenFilter == "TEMPORAL",
              onTap: () => ref.read(medicalRulesProvider.notifier).setOrigenFilter("TEMPORAL"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = AppTema.verdeSalud;
    final inactiveColor = Colors.blueGrey;

    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? activeColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : inactiveColor,
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
                    value: state.idCondicionFilter,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.medical_services_outlined, color: AppTema.verdeSalud, size: 18),
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
                      value: state.idObjetivoFilter,
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
        final currentRowsPerPage = state.rules.isEmpty
            ? 5
            : (state.rules.length < MedicalRulesNotifier.pageSize
                ? state.rules.length
                : MedicalRulesNotifier.pageSize);

        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(
                elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
            dividerColor: Colors.transparent,
          ),
          child: PaginatedDataTable(
            header: null,
            rowsPerPage: currentRowsPerPage,
            showFirstLastButtons: true,
            availableRowsPerPage: [currentRowsPerPage],
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
      builder: (ctx) => _NutritionalRuleFormDialog(
        formData: state.formData,
        initialRule: rule,
        onSaved: () => ref.read(medicalRulesProvider.notifier).loadPage(),
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
  final VoidCallback onSaved;
  const _NutritionalRuleFormDialog(
      {required this.formData, this.initialRule, required this.onSaved});
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

    bool isClinicalRule = false;
    for (final condId in _selectedCondiciones) {
      final cond = (widget.formData["condiciones"] ?? []).firstWhere(
          (c) => c["id"] == condId,
          orElse: () => null);
      if (cond != null && cond["id_tipo_condicion"] == 1) {
        isClinicalRule = true;
        break;
      }
    }
    final forceStrict = _idAccion == 1 || isClinicalRule;
    final activeEsEstricta = forceStrict ? true : _esEstricta;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: AppTema.azulPrincipal,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24))),
        child: Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Text(isEdit ? "Editar regla clínica" : "Nueva regla clínica",
              style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFieldSection("Objetivo", [
                DropdownButtonFormField<int>(
                  initialValue: _idObjetivo,
                  decoration:
                      _modalDecor("Tipo de objetivo*", Icons.track_changes),
                  items: (widget.formData["objetivos"] ?? [])
                      .map((o) => DropdownMenuItem<int>(
                          value: o["id"],
                          child: Text(o["nombre"].toString(),
                              style: GoogleFonts.montserrat(
                                  fontSize: 12, fontWeight: FontWeight.w600))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _idObjetivo = v;
                    _idTarget = null;
                  }),
                ),
                if (_idObjetivo != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _idTarget,
                    decoration:
                        _modalDecor("Seleccionar elemento*", Icons.ads_click),
                    items: targetList
                        .map((t) => DropdownMenuItem<int>(
                            value: t["id"],
                            child: Text(
                                t["nombre"] ?? t["nombre_visible"] ?? "-",
                                style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))))
                        .toList(),
                    onChanged: (v) => setState(() => _idTarget = v),
                  ),
                ],
              ]),
              const SizedBox(height: 16),
              _buildFieldSection("Acción", [
                DropdownButtonFormField<int>(
                  initialValue: _idAccion,
                  decoration:
                      _modalDecor("Acción sugerida*", Icons.lightbulb_outline),
                  items: (widget.formData["acciones"] ?? [])
                      .map((a) => DropdownMenuItem<int>(
                          value: a["id"],
                          child: Text(a["nombre"].toString(),
                              style: GoogleFonts.montserrat(
                                  fontSize: 12, fontWeight: FontWeight.w600))))
                      .toList(),
                  onChanged: (v) => setState(() => _idAccion = v),
                ),
                SwitchListTile(
                    title: Text(
                        forceStrict
                            ? "Restricción Estricta (Requerido)"
                            : "Restricción Estricta",
                        style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: forceStrict ? Colors.grey : null)),
                    subtitle: forceStrict
                        ? Text(
                            "Las reglas de eliminación y las condiciones clínicas son estrictas por defecto.",
                            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blueGrey))
                        : null,
                    value: activeEsEstricta,
                    onChanged: forceStrict ? null : (v) => setState(() => _esEstricta = v)),
              ]),
              const SizedBox(height: 16),
              _buildFieldSection("Aplicabilidad del diagnóstico", [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12)),
                  child: ListView(
                      children: (widget.formData["condiciones"] ?? [])
                          .map((c) => CheckboxListTile(
                              title: Text(
                                  c["nombre"]?.toString() ?? "Condición",
                                  style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              value: _selectedCondiciones.contains(c["id"]),
                              activeColor: AppTema.azulPrincipal,
                              onChanged: (v) => setState(() {
                                    if (v!) {
                                      _selectedCondiciones.add(c["id"]);
                                    } else {
                                      _selectedCondiciones.remove(c["id"]);
                                    }
                                  }),
                              dense: true))
                          .toList()),
                ),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _mensajeController,
                  maxLines: 2,
                  style: GoogleFonts.montserrat(fontSize: 13),
                  decoration: _modalDecor(
                      "Mensaje clínico", Icons.chat_bubble_outline)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar",
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold, color: Colors.grey))),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? "..." : "Guardar regla",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildFieldSection(String title, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        ...children
      ]);
  InputDecoration _modalDecor(String l, IconData i) => InputDecoration(
      labelText: l,
      prefixIcon: Icon(i, size: 18),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none));

  Future<void> _save() async {
    if (_idAccion == null ||
        _idObjetivo == null ||
        _idTarget == null ||
        _selectedCondiciones.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      bool isClinicalRule = false;
      for (final condId in _selectedCondiciones) {
        final cond = (widget.formData["condiciones"] ?? []).firstWhere(
            (c) => c["id"] == condId,
            orElse: () => null);
        if (cond != null && cond["id_tipo_condicion"] == 1) {
          isClinicalRule = true;
          break;
        }
      }
      final forceStrict = _idAccion == 1 || isClinicalRule;
      final activeEsEstricta = forceStrict ? true : _esEstricta;

      final payload = {
        "id_accion": _idAccion,
        "id_tipo_objetivo": _idObjetivo,
        "mensaje_error": _mensajeController.text,
        "id_condiciones": _selectedCondiciones,
        "es_estricta": activeEsEstricta,
        "id_ingrediente": _idObjetivo == 1 ? _idTarget : null,
        "id_grupo_alimentario": _idObjetivo == 2 ? _idTarget : null,
        "id_etiqueta": _idObjetivo == 3 ? _idTarget : null,
        "id_subgrupo_alimentario": _idObjetivo == 4 ? _idTarget : null
      };
      if (widget.initialRule != null) {
        await ref
            .read(dioProvider)
            .put("reglas-medicas/${widget.initialRule!['id']}", data: payload);
      } else {
        await ref.read(dioProvider).post("reglas-medicas", data: payload);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
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
      ),
    );
  }
}
