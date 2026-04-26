import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';

class EtiquetasGestionPage extends ConsumerStatefulWidget {
  const EtiquetasGestionPage({super.key});
  @override
  ConsumerState<EtiquetasGestionPage> createState() => _EtiquetasGestionPageState();
}

class _EtiquetasGestionPageState extends ConsumerState<EtiquetasGestionPage> {
  List<dynamic> _etiquetas = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('etiquetas-lista');
      if (mounted) {
        setState(() {
          _etiquetas = response.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        NutriSnack.show(context, "Error al cargar etiquetas", isError: true, ref: ref);
      }
    }
  }

  Future<void> _rename(int id, String oldName) async {
    final controller = TextEditingController(text: oldName);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Renombrar Etiqueta', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nuevo nombre descriptivo', filled: true),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text), 
            style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white),
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
        if (mounted) NutriSnack.show(context, "Etiqueta renombrada con éxito", ref: ref);
      } catch (e) {
        if (mounted) NutriSnack.show(context, "Error al renombrar", isError: true, ref: ref);
      }
    }
  }

  Future<void> _delete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Etiqueta?'),
        content: Text('Esto eliminará "$name" de TODOS los ingredientes vinculados. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
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
        if (mounted) NutriSnack.show(context, "Etiqueta eliminada del sistema", ref: ref);
      } catch (e) {
        if (mounted) NutriSnack.show(context, "Error al eliminar", isError: true, ref: ref);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _etiquetas.where((e) => 
      e['nombre_visible'].toString().toLowerCase().contains(_search.toLowerCase())
    ).toList();

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
              onAction: () => NutriSnack.show(context, "Módulo de creación automática mediante reglas"),
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
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
                Text("Control de advertencias y clasificaciones diagnósticas de alimentos.", 
                  style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 13)),
              ],
            ),
            IconButton(icon: const Icon(Icons.sync_rounded, color: AppTema.azulPrincipal), onPressed: _fetch),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int visibles) {
    return Row(
      children: [
        Expanded(child: NutriResumenCard(titulo: "TOTAL ETIQUETAS", valor: "${_etiquetas.length}", icon: Icons.label_important_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "FILTRADAS", valor: "$visibles", colorValor: AppTema.verdeSalud, icon: Icons.filter_alt_rounded)),
        const SizedBox(width: 20),
        const Expanded(child: NutriResumenCard(titulo: "SISTEMA", valor: "SIA", colorValor: AppTema.cianLimpio, icon: Icons.auto_awesome_rounded)),
      ],
    );
  }

  Widget _buildTableContainer(List<dynamic> filtered) {
    return NutriTableContainer(
      child: _loading
        ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Cargando glosario de etiquetas..."))
        : filtered.isEmpty
          ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No se encontraron etiquetas.")))
          : DataTable(
              headingRowColor: WidgetStateProperty.all(AppTema.pastelCeleste),
              columns: [
                _col("ETIQUETA VISIBLE"),
                _col("CÓDIGO INTERNO"),
                _col("TIPO"),
                _col("ACCIONES"),
              ],
              rows: filtered.map((e) => DataRow(
                cells: [
                  DataCell(Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: (e['tipo'] == 'RESTRICCION' ? Colors.red : Colors.blue).withOpacity(0.1), shape: BoxShape.circle),
                        child: Text(e['nombre_visible'][0].toString().toUpperCase(), style: TextStyle(color: e['tipo'] == 'RESTRICCION' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Text(e['nombre_visible'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTema.azulPrincipal)),
                    ],
                  )),
                  DataCell(Text(e['nombre'], style: GoogleFonts.firaMono(fontSize: 11))),
                  DataCell(NutriBadge(label: e['tipo'].toString(), type: e['tipo'] == 'RESTRICCION' ? 'danger' : 'info')),
                  DataCell(Row(
                    children: [
                      IconButton(icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppTema.azulPrincipal), onPressed: () => _rename(e['id'], e['nombre_visible'])),
                      IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent), onPressed: () => _delete(e['id'], e['nombre_visible'])),
                    ],
                  )),
                ],
              )).toList(),
            ),
    );
  }

  DataColumn _col(String l) => DataColumn(label: Text(l, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal)));
}
