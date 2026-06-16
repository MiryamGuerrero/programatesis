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
        title: const Text('Eliminar Etiqueta'),
        content: Text(
            '¿Deseas eliminar la etiqueta "$nombre"? Esta acción desvinculará la etiqueta de ingredientes y recetas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ELIMINAR'),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Catálogo de Etiquetas",
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
        ),
        FilledButton.icon(
          onPressed: () => _abrirFormulario(),
          style: FilledButton.styleFrom(
            backgroundColor: AppTema.verdeSalud,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          label: Text("NUEVA ETIQUETA",
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 13)),
        ),
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
            titulo: 'TOTAL ETIQUETAS',
            valor: '$_total',
            icon: Icons.label_rounded,
            colorValor: AppTema.azulPrincipal,
          ),
        ),
        const SizedBox(width: 20),
        const Expanded(
          child: NutriResumenCard(
            titulo: 'ESTADO MOTOR',
            valor: 'ACTIVO',
            icon: Icons.bolt_rounded,
            colorValor: AppTema.verdeSalud,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTema.grisLienzo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  _query = v;
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                    _loadEtiquetas(offset: 0, updateStats: true);
                  });
                },
                style:
                    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Buscar por nombre de etiqueta...",
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppTema.azulPrincipal),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _filtrosActivos ? _limpiarFiltros : null,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
              label: Text(
                "LIMPIAR",
                style: GoogleFonts.montserrat(
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
              backgroundColor:
                  AppTema.azulPrincipal.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableContainer() {
    return NutriTableContainer(
      child: LayoutBuilder(builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(
                elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
          ),
          child: PaginatedDataTable(
            header: null,
            rowsPerPage: _rowsPerPage,
            availableRowsPerPage: const [_rowsPerPage],
            onPageChanged: (idx) => _loadEtiquetas(offset: idx),
            showFirstLastButtons: true,
            columnSpacing: 20,
            horizontalMargin: 20,
            dataRowMinHeight: 65,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
            columns: [
              _col("IDENTIDAD", width: totalWidth * 0.30),
              _col("ALIMENTOS VINCULADOS", width: totalWidth * 0.40),
              _col("FECHA", width: totalWidth * 0.12),
              _col("ACCIONES", width: totalWidth * 0.12, center: true),
            ],
            source: _EtiquetasDataSource(
              items: _etiquetas,
              totalRows: _total,
              offset: _offset,
              isLoading: _loading,
              onEdit: (e) => _abrirFormulario(e),
              onDelete: (id, name) => _deleteEtiqueta(id, name),
              totalWidth: totalWidth,
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
          child: Text(
            label,
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppTema.azulOscuro),
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
    if (isLoading) {
      return DataRow(cells: [
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
            width: totalWidth * 0.12, child: const NutriShimmer(width: 60, height: 10))),
        DataCell(SizedBox(
          width: totalWidth * 0.12,
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

    return DataRow(cells: [
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
                            fontSize: 13,
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
        width: totalWidth * 0.12,
        child: Text(fechaFormateada,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey)),
      )),
      DataCell(SizedBox(
        width: totalWidth * 0.12,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
                tooltip: "Editar etiqueta",
                icon: const Icon(Icons.edit_note_rounded,
                    color: Colors.blueGrey, size: 24),
                onPressed: () => onEdit(e)),
            IconButton(
                tooltip: "Eliminar registro",
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 20),
                onPressed: () => onDelete(e['id'], e['nombre_visible'] ?? '')),
          ],
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
