import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import '../../../../shared/widgets/shimmer_components.dart';

class EtiquetasGestionPage extends ConsumerStatefulWidget {
  const EtiquetasGestionPage({super.key});
  @override
  ConsumerState<EtiquetasGestionPage> createState() =>
      _EtiquetasGestionPageState();
}

class _EtiquetasGestionPageState extends ConsumerState<EtiquetasGestionPage> {
  List<dynamic> _etiquetas = [];
  bool _loading = true;
  bool _loadingStats = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetch(updateStats: true);
  }

  Future<void> _fetch({bool updateStats = false}) async {
    setState(() {
      _loading = true;
      if (updateStats) _loadingStats = true;
    });
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('etiquetas-lista');
      if (mounted) {
        setState(() {
          _etiquetas = response.data;
          _loading = false;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingStats = false;
        });
        NutriSnack.show(context, "Error al cargar etiquetas",
            isError: true, ref: ref);
      }
    }
  }

  Future<void> _rename(int id, String oldName) async {
    final controller = TextEditingController(text: oldName);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Renombrar Etiqueta',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'Nuevo nombre descriptivo', filled: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTema.azulPrincipal,
                foregroundColor: Colors.white),
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );

    if (nuevo != null && nuevo.trim().isNotEmpty && nuevo != oldName) {
      try {
        final dio = ref.read(dioProvider);
        await dio.put('etiquetas/$id', data: {'nombre_visible': nuevo.trim()});
        _fetch();
        if (mounted)
          NutriSnack.show(context, "Etiqueta renombrada con éxito", ref: ref);
      } catch (e) {
        if (mounted)
          NutriSnack.show(context, "Error al renombrar",
              isError: true, ref: ref);
      }
    }
  }

  Future<void> _delete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Etiqueta?'),
        content: Text(
            'Esto eliminará "$name" de TODOS los ingredientes vinculados. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SÍ, ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete('etiquetas/$id');
        _fetch();
        if (mounted)
          NutriSnack.show(context, "Etiqueta eliminada del sistema", ref: ref);
      } catch (e) {
        if (mounted)
          NutriSnack.show(context, "Error al eliminar",
              isError: true, ref: ref);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _etiquetas
        .where((e) => e['nombre_visible']
            .toString()
            .toLowerCase()
            .contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(filtered.length),
            const SizedBox(height: 32),
            NutriTableToolbar(
              actionLabel: "Nueva Etiqueta",
              onAction: () => NutriSnack.show(
                  context, "Módulo de creación automática mediante reglas"),
              onSearch: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 24),
            _buildTableContainer(filtered),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Gestión de Etiquetas Nutricionales",
                    style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTema.azulPrincipal,
                        letterSpacing: -0.5)),
                Text(
                    "Control de advertencias y clasificaciones diagnósticas de alimentos.",
                    style: GoogleFonts.inter(
                        color: Colors.blueGrey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            IconButton(
                icon: const Icon(Icons.sync_rounded,
                    color: AppTema.azulPrincipal),
                onPressed: () => _fetch(updateStats: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int visibles) {
    if (_loadingStats) {
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
                titulo: "TOTAL ETIQUETAS",
                valor: "${_etiquetas.length}",
                icon: Icons.label_important_rounded)),
        const SizedBox(width: 20),
        Expanded(
            child: NutriResumenCard(
                titulo: "FILTRADAS",
                valor: "$visibles",
                colorValor: AppTema.verdeSalud,
                icon: Icons.filter_alt_rounded)),
        const SizedBox(width: 20),
        const Expanded(
            child: NutriResumenCard(
                titulo: "SISTEMA",
                valor: "SIA",
                colorValor: AppTema.azulOscuro,
                icon: Icons.auto_awesome_rounded)),
      ],
    );
  }

  Widget _buildTableContainer(List<dynamic> filtered) {
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
          headingRowColor: WidgetStateProperty.all(AppTema.pastelCeleste),
          columns: [
            _col("ETIQUETA VISIBLE"),
            _col("CÓDIGO INTERNO"),
            _col("TIPO"),
            _col("ACCIONES"),
          ],
          source: _EtiquetasDataSource(
            items: filtered,
            isLoading: _loading,
            onRename: (id, name) => _rename(id, name),
            onDelete: (id, name) => _delete(id, name),
            context: context,
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
              color: AppTema.azulPrincipal)));
}

class _EtiquetasDataSource extends DataTableSource {
  final List<dynamic> items;
  final bool isLoading;
  final Function(int, String) onRename;
  final Function(int, String) onDelete;
  final BuildContext context;

  _EtiquetasDataSource({
    required this.items,
    required this.isLoading,
    required this.onRename,
    required this.onDelete,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    if (isLoading) {
      return DataRow(cells: [
        DataCell(Row(
          children: [
            NutriShimmer(width: 32, height: 32, borderRadius: BorderRadius.circular(16)),
            const SizedBox(width: 12),
            NutriShimmer(width: 120, height: 12),
          ],
        )),
        DataCell(NutriShimmer(width: 80, height: 10)),
        DataCell(NutriShimmer(width: 70, height: 20)),
        DataCell(Row(
          children: [
            NutriShimmer(width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
            const SizedBox(width: 8),
            NutriShimmer(width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
          ],
        )),
      ]);
    }

    if (index >= items.length) return null;
    final e = items[index];

    return DataRow(cells: [
      DataCell(Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: (e['tipo'] == 'RESTRICCION' ? Colors.red : Colors.blue)
                    .withOpacity(0.1),
                shape: BoxShape.circle),
            child: Text((e['nombre_visible']?.toString() ?? "E")[0].toUpperCase(),
                style: TextStyle(
                    color: e['tipo'] == 'RESTRICCION' ? Colors.red : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Text(e['nombre_visible']?.toString() ?? "Etiqueta",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTema.azulPrincipal)),
        ],
      )),
      DataCell(Text(e['nombre']?.toString() ?? "N/A",
          style: GoogleFonts.lato(fontSize: 11))),
      DataCell(NutriBadge(
          label: e['tipo'].toString(),
          type: e['tipo'] == 'RESTRICCION' ? 'danger' : 'info')),
      DataCell(Row(
        children: [
          IconButton(
              icon: const Icon(Icons.edit_note_rounded,
                  size: 20, color: AppTema.azulPrincipal),
              onPressed: () => onRename(e['id'], e['nombre_visible'])),
          IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: Colors.redAccent),
              onPressed: () => onDelete(e['id'], e['nombre_visible'])),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => isLoading && items.isEmpty ? 5 : items.length;
  @override
  int get selectedRowCount => 0;
}
