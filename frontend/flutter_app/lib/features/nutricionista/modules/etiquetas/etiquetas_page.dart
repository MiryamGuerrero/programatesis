import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import '../../../../shared/widgets/shimmer_components.dart';
import 'etiqueta_form_page.dart';

class EtiquetasPage extends ConsumerStatefulWidget {
  const EtiquetasPage({super.key});

  @override
  ConsumerState<EtiquetasPage> createState() => _EtiquetasPageState();
}

class _EtiquetasPageState extends ConsumerState<EtiquetasPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  bool _loading = false;
  bool _loadingStats = true;
  List<Map<String, dynamic>> _etiquetas = const [];
  int _total = 0;
  int _offset = 0;
  static const int _rowsPerPage = 5;
  Timer? _searchDebounce;

  bool get _filtrosActivos => _query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadEtiquetas(updateStats: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _limpiarFiltros() {
    _searchController.clear();
    setState(() {
      _query = "";
      _offset = 0;
    });
    _loadEtiquetas(offset: 0, updateStats: true);
  }

  Future<void> _loadEtiquetas({int? offset, bool updateStats = false}) async {
    final nextOffset = offset ?? _offset;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _offset = nextOffset;
      if (updateStats) _loadingStats = true;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final result = await repo.fetchLabelsPage(
        query: _query,
        limit: _rowsPerPage,
        offset: nextOffset,
      );

      if (!mounted) return;
      setState(() {
        _etiquetas = result.items;
        _total = result.total;
        _loading = false;
        _loadingStats = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingStats = false;
      });
    }
  }

  void _abrirFormulario([Map<String, dynamic>? etiqueta]) async {
    final exito = await showDialog<bool>(
      context: context,
      builder: (context) => EtiquetaFormDialog(etiquetaInicial: etiqueta),
    );

    if (exito == true) {
      _loadEtiquetas(offset: _offset, updateStats: true);
    }
  }

  Future<void> _deleteEtiqueta(int id, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar etiqueta'),
        content: Text(
            '¿Deseas eliminar la etiqueta "$nombre"? Esta acción desvinculará la etiqueta de ingredientes y recetas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final oldEtiquetas = List<Map<String, dynamic>>.from(_etiquetas);
      final oldTotal = _total;

      setState(() {
        _etiquetas.removeWhere((e) => e['id'] == id);
        _total--;
      });

      try {
        final dio = ref.read(dioProvider);
        await dio.delete('nutricionista/etiquetas/$id');
        if (mounted) {
          NutriSnack.show(context, 'Etiqueta eliminada con éxito');
        }
      } catch (e) {
        setState(() {
          _etiquetas = oldEtiquetas;
          _total = oldTotal;
        });
        if (mounted) {
          NutriSnack.show(context, 'Error al eliminar la etiqueta',
              isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(),
            const SizedBox(height: 32),
            _buildToolbar(),
            const SizedBox(height: 24),
            _buildTableContainer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Catálogo de etiquetas",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Gestión de descriptores nutricionales para automatización de dietas y reglas clínicas.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsRow() {
    if (_loadingStats) {
      return const Row(
        children: [
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
            titulo: 'Total etiquetas',
            valor: '$_total',
            icon: Icons.label_rounded,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        const Expanded(
          child: NutriResumenCard(
            titulo: 'Estado motor',
            valor: 'Activo',
            icon: Icons.bolt_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
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
                hintText: "Buscar por nombre de etiqueta...",
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                _query = v;
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  _loadEtiquetas(offset: 0, updateStats: true);
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => _abrirFormulario(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTema.verdeSalud,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: Text("Nueva etiqueta",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _filtrosActivos ? _limpiarFiltros : null,
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
          onPressed: () => _loadEtiquetas(offset: _offset, updateStats: true),
          tooltip: "Actualizar catálogo",
          style: IconButton.styleFrom(
            backgroundColor: AppTema.azulPrincipal.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ],
    );
  }

  Widget _buildTableContainer() {
    if (!_loading && _etiquetas.isEmpty) {
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
              "No se encontraron etiquetas",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTema.azulOscuro,
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
        final currentRowsPerPage = _etiquetas.isEmpty
            ? 5
            : (_etiquetas.length < _rowsPerPage
                ? _etiquetas.length
                : _rowsPerPage);

        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(
                elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
            dividerColor: Colors.transparent,
          ),
          child: PaginatedDataTable(
            header: null,
            rowsPerPage: currentRowsPerPage,
            availableRowsPerPage: [currentRowsPerPage],
            onPageChanged: (idx) => _loadEtiquetas(offset: idx),
            showFirstLastButtons: true,
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            dataRowMinHeight: 65,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("IDENTIDAD", width: usableWidth * 0.30),
              _col("ALIMENTOS VINCULADOS", width: usableWidth * 0.40),
              _col("FECHA", width: usableWidth * 0.15),
              _col("ACCIONES", width: usableWidth * 0.15, center: true),
            ],
            source: _EtiquetasDataSource(
              items: _etiquetas,
              totalRows: _total,
              offset: _offset,
              isLoading: _loading,
              onEdit: (e) => _abrirFormulario(e),
              onDelete: (id, name) => _deleteEtiqueta(id, name),
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

class _EtiquetasDataSource extends DataTableSource {
  final List<Map<String, dynamic>> items;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int, String) onDelete;
  final double totalWidth;
  final BuildContext context;

  _EtiquetasDataSource({
    required this.items,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
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
          width: totalWidth * 0.30,
          child: Row(
            children: [
              const NutriShimmer(
                  width: 24,
                  height: 24,
                  borderRadius: BorderRadius.all(Radius.circular(4))),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NutriShimmer(width: 100, height: 12),
                  const SizedBox(height: 4),
                  NutriShimmer(
                      width: 150,
                      height: 10,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ],
          ),
        )),
        DataCell(SizedBox(
            width: totalWidth * 0.40,
            child: const NutriShimmer(width: double.infinity, height: 10))),
        DataCell(SizedBox(
            width: totalWidth * 0.15, child: const NutriShimmer(width: 60, height: 10))),
        DataCell(SizedBox(
          width: totalWidth * 0.15,
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
    if (localIndex < 0 || localIndex >= items.length) return null;
    final e = items[localIndex];

    final String fechaRaw = e['created_at'] ?? '';
    String fechaFormateada = 'N/A';
    if (fechaRaw.isNotEmpty) {
      try {
        final date = DateTime.parse(fechaRaw);
        fechaFormateada = DateFormat('dd/MM/yyyy').format(date);
      } catch (_) {}
    }

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
        DataCell(SizedBox(
          width: totalWidth * 0.30,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                const Icon(Icons.label_important_outline_rounded,
                    size: 20, color: AppTema.azulPrincipal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e['nombre_visible']?.toString() ?? 'Sin nombre',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: AppTema.azulPrincipal)),
                      if (e['descripcion'] != null)
                        Text(
                          e['descripcion'].toString(),
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.blueGrey),
                          softWrap: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.40,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: AppTema.grisLienzo,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade100)),
              child: Text(e['ingredientes']?.toString() ?? 'Sin alimentos',
                  softWrap: true,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w500)),
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: Text(fechaFormateada,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey)),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HoverActionButton(
                    icon: Icons.edit_note_rounded,
                    label: "Editar",
                    color: Colors.orange,
                    onTap: () => onEdit(e)),
                const SizedBox(width: 12),
                _HoverActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: "Borrar",
                    color: Colors.redAccent,
                    onTap: () => onDelete(e['id'], e['nombre_visible'] ?? '')),
              ],
            ),
          ),
        )),
      ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => (isLoading && totalRows == 0) ? 5 : totalRows;
  @override
  int get selectedRowCount => 0;
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
