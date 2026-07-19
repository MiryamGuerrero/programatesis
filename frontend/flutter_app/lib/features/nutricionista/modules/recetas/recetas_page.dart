import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "../../../../shared/widgets/shimmer_components.dart";
import "receta_detalle_page.dart";
import "receta_form_page.dart";
import "recetas_provider.dart";
import "widgets/receta_card.dart";

class RecetasPage extends ConsumerStatefulWidget {
  const RecetasPage({super.key});

  @override
  ConsumerState<RecetasPage> createState() => _RecetasPageState();
}

class _RecetasPageState extends ConsumerState<RecetasPage> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedReceta;
  bool _isEditing = false;
  Map<String, dynamic>? _recetaParaEditar;
  int? _loadingRecetaId;
  String? _loadingAction; // 'ver', 'editar', 'eliminar'
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(recetasProvider.notifier).loadRecetas(reload: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return RecetaFormPage(
        recetaInicial: _recetaParaEditar,
        onBack: () {
          setState(() {
            _isEditing = false;
            _recetaParaEditar = null;
          });
          ref.read(recetasProvider.notifier).loadRecetas(reload: true);
        },
      );
    }

    if (_selectedReceta != null) {
      return RecetaDetallePage(
        receta: _selectedReceta!,
        onBack: () => setState(() => _selectedReceta = null),
      );
    }

    final state = ref.watch(recetasProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40.0, vertical: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildStatsRow(state),
                      const SizedBox(height: 32),
                      _buildToolbar(state),
                      if (state.error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          state.error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      _buildGrid(state.visibleRecetas, state.isLoading),
                    ],
                  ),
                ),
              ),
              if (state.totalPages > 1) _buildPaginationBar(state),
            ],
          ),
          if (state.isDeleting)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      "Eliminando...",
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Recetario terapéutico",
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTema.azulPrincipal,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          "Administración de preparaciones y composición nutricional por plato.",
          style: GoogleFonts.inter(
            color: Colors.blueGrey,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(RecetasState state) {
    if (state.isLoadingMetadata) {
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
            titulo: "Total recetas",
            valor: "${state.totalItems}",
            icon: Icons.menu_book_rounded,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: NutriResumenCard(
            titulo: "Filtradas",
            valor: "${state.totalItems}",
            colorValor: AppTema.verdeSalud,
            icon: Icons.filter_list_rounded,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: NutriResumenCard(
            titulo: "Activas / inact.",
            valor: "${state.activos} / ${state.inactivos}",
            colorValor: AppTema.azulOscuro,
            icon: Icons.check_circle_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(RecetasState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                  onChanged: (v) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                      ref.read(recetasProvider.notifier).setQuery(v);
                    });
                  },
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre, momento o tipo de plato...",
                    hintStyle: GoogleFonts.inter(
                        color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: Colors.grey),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => setState(() {
                  _isEditing = true;
                  _recetaParaEditar = null;
                }),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: Text("Nueva receta",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: "Momento",
                  value: state.momentoSeleccionado,
                  items: state.momentosComida,
                  onChanged: (value) =>
                      ref.read(recetasProvider.notifier).setMomentoSeleccionado(value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  label: "Tipo de plato",
                  value: state.tipoPlatoSeleccionado,
                  items: state.tiposPlato,
                  onChanged: (value) => ref
                      .read(recetasProvider.notifier)
                      .setTipoPlatoSeleccionado(value),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: state.filtrosActivos
                      ? () {
                          _searchController.clear();
                          ref.read(recetasProvider.notifier).clearFilters();
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    side: BorderSide(color: Colors.grey.shade200),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
                  label: Text(
                    "Limpiar",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    size: 22, color: AppTema.azulPrincipal),
                onPressed: () => ref.read(recetasProvider.notifier).loadRecetas(reload: true),
                tooltip: "Actualizar recetario",
                style: IconButton.styleFrom(
                  backgroundColor: AppTema.azulPrincipal.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: AppTema.grisLienzo.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTema.azulPrincipal, size: 20),
          hint: Text(
            label,
            style: GoogleFonts.montserrat(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                label == "Momento" ? "Todos los momentos" : "Todo el menú",
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...items.where((item) => _asInt(item["id"]) != null).map((item) {
              final id = _asInt(item["id"]);
              return DropdownMenuItem<int?>(
                value: id,
                child: Text(
                  item["nombre"]?.toString() ?? "Sin nombre",
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> visible, bool loading) {
    if (loading) {
      return const NutriGridShimmer(itemCount: 12);
    }

    if (visible.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: Text("No se encontraron recetas."),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, _) {
        const int crossAxisCount = 3;
        const double spacing = 24.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: 480,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final receta = visible[index];
            final id = receta["id"] as int;
            final isTargetCard = _loadingRecetaId == id;
            return RecetaCard(
              receta: receta,
              loadingAction: isTargetCard ? _loadingAction : null,
              onVer: () => _abrirDetalleCompleto(id),
              onEditar: () => _prepararEdicion(id),
              onEliminar: () => _confirmarEliminacion(receta),
              onToggleActive: (valor) => _toggleActiva(id, valor),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleActiva(int id, bool valor) async {
    try {
      await ref.read(recetasProvider.notifier).toggleActiva(id, valor);
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al cambiar estado: $e", isError: true);
      }
    }
  }

  Future<void> _abrirDetalleCompleto(int id) async {
    final dio = ref.read(dioProvider);
    setState(() {
      _loadingRecetaId = id;
      _loadingAction = 'ver';
    });
    try {
      final resp = await dio.get("crud/recetas/$id");
      if (!mounted) return;
      setState(() => _selectedReceta = Map<String, dynamic>.from(resp.data as Map));
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al cargar detalle", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecetaId = null;
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _prepararEdicion(int id) async {
    final dio = ref.read(dioProvider);
    setState(() {
      _loadingRecetaId = id;
      _loadingAction = 'editar';
    });
    try {
      final resp = await dio.get("crud/recetas/$id");
      if (!mounted) return;
      setState(() {
        _recetaParaEditar = Map<String, dynamic>.from(resp.data as Map);
        _isEditing = true;
      });
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al cargar detalle para editar",
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecetaId = null;
          _loadingAction = null;
        });
      }
    }
  }

  Widget _buildPaginationBar(RecetasState state) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Página ${state.currentPage + 1} de ${state.totalPages}",
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey,
            ),
          ),
          Row(
            children: [
              _buildNavButton(
                Icons.chevron_left_rounded,
                state.currentPage > 0
                    ? () async {
                        ref.read(recetasProvider.notifier).setLoading(true);
                        await Future.delayed(const Duration(milliseconds: 300));
                        ref.read(recetasProvider.notifier).previousPage();
                        ref.read(recetasProvider.notifier).setLoading(false);
                      }
                    : null,
              ),
              const SizedBox(width: 12),
              _buildNavButton(
                Icons.chevron_right_rounded,
                state.currentPage < state.totalPages - 1
                    ? () async {
                        ref.read(recetasProvider.notifier).setLoading(true);
                        await Future.delayed(const Duration(milliseconds: 300));
                        ref.read(recetasProvider.notifier).nextPage();
                        ref.read(recetasProvider.notifier).setLoading(false);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback? onPressed) {
    final bool disabled = onPressed == null;
    return Container(
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: disabled ? Colors.grey.shade100 : const Color(0xFFF1F5F9)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon,
            color: disabled ? Colors.grey.shade300 : AppTema.azulPrincipal),
      ),
    );
  }

  Future<void> _confirmarEliminacion(Map<String, dynamic> receta) async {
    final id = receta["id"] as int;
    ref.read(recetasProvider.notifier).setDeleting(true);
    try {
      await ref.read(recetasProvider.notifier).eliminarReceta(id);
      if (!mounted) return;
      NutriSnack.show(context, "Receta eliminada correctamente");
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al eliminar: $e", isError: true);
      }
    } finally {
      if (mounted) {
        ref.read(recetasProvider.notifier).setDeleting(false);
      }
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
