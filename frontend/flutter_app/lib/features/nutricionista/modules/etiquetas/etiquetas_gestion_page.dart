import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import '../../../../shared/widgets/shimmer_components.dart';

String _sentenceCase(Object? value) {
  final text = value?.toString().trim().replaceAll('_', ' ').toLowerCase() ?? '';
  return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

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
        title: Text('Renombrar etiqueta',
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
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTema.azulPrincipal,
                foregroundColor: Colors.white),
            child: const Text('Guardar'),
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
        title: const Text('¿Eliminar etiqueta?'),
        content: Text(
        'Esto eliminará "$name" de todos los ingredientes vinculados. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, eliminar'),
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
              actionLabel: "Nueva etiqueta",
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
                Text("Gestión de etiquetas nutricionales",
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
                titulo: "Total etiquetas",
                valor: "${_etiquetas.length}",
                icon: Icons.label_important_rounded)),
        const SizedBox(width: 20),
        Expanded(
            child: NutriResumenCard(
                titulo: "Filtradas",
                valor: "$visibles",
                colorValor: AppTema.verdeSalud,
                icon: Icons.filter_alt_rounded)),
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

  Widget _buildTableContainer(List<dynamic> filtered) {
    if (!_loading && filtered.isEmpty) {
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
        final currentRowsPerPage = filtered.isEmpty ? 5 : min(10, filtered.length);
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
            dividerThickness: 0.0,
            columnSpacing: 0,
            horizontalMargin: 10,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("ETIQUETA VISIBLE", width: usableWidth * 0.30),
              _col("CÓDIGO INTERNO", width: usableWidth * 0.25),
              _col("TIPO", width: usableWidth * 0.20),
              _col("ACCIONES", width: usableWidth * 0.25),
            ],
            source: _EtiquetasDataSource(
              items: filtered,
              isLoading: _loading,
              onRename: (id, name) => _rename(id, name),
              onDelete: (id, name) => _delete(id, name),
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
                fontSize: 11,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

class _EtiquetasDataSource extends DataTableSource {
  final List<dynamic> items;
  final bool isLoading;
  final Function(int, String) onRename;
  final Function(int, String) onDelete;
  final double totalWidth;
  final BuildContext context;

  _EtiquetasDataSource({
    required this.items,
    required this.isLoading,
    required this.onRename,
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
                NutriShimmer(width: 32, height: 32, borderRadius: BorderRadius.circular(16)),
                const SizedBox(width: 12),
                const Expanded(child: NutriShimmer(width: 120, height: 12)),
              ],
            ),
          )),
          DataCell(SizedBox(
              width: totalWidth * 0.25,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 80, height: 10),
              ))),
          DataCell(SizedBox(
              width: totalWidth * 0.20,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 70, height: 20),
              ))),
          DataCell(SizedBox(
            width: totalWidth * 0.25,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NutriShimmer(width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 8),
                NutriShimmer(width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
              ],
            ),
          )),
        ],
      );
    }

    if (index >= items.length) return null;
    final e = items[index];

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
        DataCell(SizedBox(
          width: totalWidth * 0.30,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: (e['tipo'] == 'RESTRICCION' ? Colors.red : Colors.blue)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Text((e['nombre_visible']?.toString() ?? "E")[0].toUpperCase(),
                      style: TextStyle(
                          color: e['tipo'] == 'RESTRICCION' ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e['nombre_visible']?.toString() ?? "Etiqueta",
                      softWrap: true,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTema.azulPrincipal)),
                ),
              ],
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.25,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(e['nombre']?.toString() ?? "N/A",
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: NutriBadge(
                  label: e['tipo'].toString(),
                  type: e['tipo'] == 'RESTRICCION' ? 'danger' : 'info'),
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.25,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HoverActionButton(
                    icon: Icons.edit_note_rounded,
                    label: "Renombrar",
                    color: AppTema.azulPrincipal,
                    onTap: () => onRename(e['id'], e['nombre_visible'])),
                const SizedBox(width: 12),
                _HoverActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: "Borrar",
                    color: Colors.redAccent,
                    onTap: () => onDelete(e['id'], e['nombre_visible'])),
              ],
            ),
          ),
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => isLoading && items.isEmpty ? 5 : items.length;
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
