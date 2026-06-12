import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import '../../../../shared/widgets/shimmer_components.dart';
import 'widgets/etiqueta_card.dart';
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
  String? _error;
  List<Map<String, dynamic>> _etiquetas = const [];
  int _currentPage = 0;

  bool get _filtrosActivos => _query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadEtiquetas(updateStats: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _limpiarFiltros() {
    _searchController.clear();
    setState(() => _query = "");
    _loadEtiquetas();
  }

  Future<void> _loadEtiquetas({bool updateStats = false}) async {
    setState(() {
      _loading = true;
      if (updateStats) _loadingStats = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final resp = await dio
          .get('nutricionista/etiquetas', queryParameters: {'q': _query});
      if (!mounted) return;
      setState(() {
        _etiquetas = List<Map<String, dynamic>>.from(resp.data);
        _currentPage = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingStats = false;
        });
      }
    }
  }

  void _abrirFormulario([Map<String, dynamic>? etiqueta]) async {
    final exito = await showDialog<bool>(
      context: context,
      builder: (context) => EtiquetaFormDialog(etiquetaInicial: etiqueta),
    );

    if (exito == true) {
      _loadEtiquetas();
    }
  }

  Future<void> _deleteEtiqueta(int id, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Etiqueta?'),
        content: Text(
            '¿Estás seguro de que deseas eliminar la etiqueta "$nombre"? Esta acción desvinculará la etiqueta de todos los ingredientes y recetas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete('nutricionista/etiquetas/$id');
        if (mounted) {
          NutriSnack.show(context, 'Etiqueta eliminada con éxito');
          _loadEtiquetas();
        }
      } catch (e) {
        if (mounted) {
          NutriSnack.show(context, 'Error al eliminar la etiqueta',
              isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateEtiquetas = _etiquetas;
    final stateLoading = _loading;
    final stateError = _error;

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(),
            const SizedBox(height: 32),
            _buildToolbar(),
            const SizedBox(height: 24),
            if (stateError != null)
              _buildErrorState()
            else
              _buildTableContainer(stateEtiquetas, stateLoading),
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
            Text(
              'Gestión de Etiquetas',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Configura las etiquetas nutricionales y descriptivas para las recetas.',
              style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
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
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: NutriResumenCard(
            titulo: 'TOTAL ETIQUETAS',
            valor: _etiquetas.length.toString(),
            icon: Icons.label_rounded,
            colorValor: AppTema.azulPrincipal,
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
                  setState(() => _query = v);
                  _loadEtiquetas();
                },
                style:
                    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Buscar por nombre o código...",
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppTema.azulPrincipal),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                size: 22, color: AppTema.azulPrincipal),
            onPressed: () => _loadEtiquetas(updateStats: true),
            tooltip: "Actualizar catálogo",
            style: IconButton.styleFrom(
              backgroundColor: AppTema.azulPrincipal.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableContainer(List<Map<String, dynamic>> items, bool loading) {
    return NutriTableContainer(
      child: Theme(
        data: Theme.of(context).copyWith(
          cardTheme: const CardThemeData(
              elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
        ),
        child: PaginatedDataTable(
          header: null,
          rowsPerPage: 10,
          showFirstLastButtons: true,
          availableRowsPerPage: const [10],
          dataRowMinHeight: 60,
          dataRowMaxHeight: 120,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
          columns: [
            _col("ETIQUETA"),
            _col("DESCRIPCIÓN"),
            _col("INGREDIENTES"),
            _col("FECHA"),
            _col("ACCIONES"),
          ],
          source: _EtiquetasDataSource(
            items: items,
            isLoading: loading,
            onEdit: (e) => _abrirFormulario(e),
            onDelete: (id, name) => _deleteEtiqueta(id, name),
          ),
        ),
      ),
    );
  }

  DataColumn _col(String l) => DataColumn(
      label: Text(l,
          style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppTema.azulOscuro)));

  Widget _buildErrorState() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          TextButton(
              onPressed: () => _loadEtiquetas(updateStats: true),
              child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.label_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No se encontraron etiquetas.',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _EtiquetasDataSource extends DataTableSource {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int, String) onDelete;

  _EtiquetasDataSource({
    required this.items,
    required this.isLoading,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (isLoading) {
      return DataRow(cells: [
        DataCell(NutriShimmer(width: 150, height: 10)),
        DataCell(NutriShimmer(width: 250, height: 10)),
        DataCell(NutriShimmer(width: 200, height: 10)),
        DataCell(NutriShimmer(width: 80, height: 10)),
        DataCell(Row(
          children: [
            NutriShimmer(
                width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
            const SizedBox(width: 8),
            NutriShimmer(
                width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
          ],
        )),
      ]);
    }

    if (index >= items.length) return null;
    final item = items[index];

    final String fechaRaw = item['created_at'] ?? '';
    String fechaFormateada = 'N/A';
    if (fechaRaw.isNotEmpty) {
      try {
        final date = DateTime.parse(fechaRaw);
        fechaFormateada = DateFormat('dd/MM/yyyy').format(date);
      } catch (_) {}
    }

    return DataRow(cells: [
      DataCell(SizedBox(
        width: 150,
        child: Text(item['nombre_visible'] ?? 'Sin nombre',
            softWrap: true,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTema.azulPrincipal)),
      )),
      DataCell(SizedBox(
        width: 350,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(item['descripcion'] ?? '-',
              softWrap: true,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey)),
        ),
      )),
      DataCell(SizedBox(
        width: 250,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(item['ingredientes'] ?? 'Ninguno',
              softWrap: true,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600)),
        ),
      )),
      DataCell(Text(fechaFormateada,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey))),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded,
                color: AppTema.azulPrincipal, size: 22),
            onPressed: () => onEdit(item),
            tooltip: "Editar",
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 20),
            onPressed: () => onDelete(item['id'], item['nombre_visible'] ?? ''),
            tooltip: "Eliminar",
          ),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => (isLoading && items.isEmpty) ? 5 : items.length;
  @override
  int get selectedRowCount => 0;
}
