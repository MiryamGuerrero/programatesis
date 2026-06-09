import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';

class EtiquetasGestionPage extends ConsumerStatefulWidget {
  const EtiquetasGestionPage({super.key});
  @override
  ConsumerState<EtiquetasGestionPage> createState() =>
      _EtiquetasGestionPageState();
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
                onPressed: _fetch),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int visibles) {
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
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(100),
              child: NutriLoading(mensaje: "Cargando glosario de etiquetas..."))
          : filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: Text("No se encontraron etiquetas.")))
              : Column(
                  children: [
                    _buildTableHeader([
                      "Etiqueta visible",
                      "Código interno",
                      "Tipo",
                      "Acciones"
                    ]),
                    ...filtered.asMap().entries.map((entry) {
                      final index = entry.key;
                      final e = entry.value;
                      return _buildTableRow(e, index);
                    }),
                  ],
                ),
    );
  }

  Widget _buildTableHeader(List<String> labels) {
    return Container(
      color: AppTema.azulPrincipal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: _headerCell(labels[0])),
          Expanded(flex: 3, child: _headerCell(labels[1])),
          Expanded(flex: 2, child: _headerCell(labels[2])),
          Expanded(flex: 2, child: Center(child: _headerCell(labels[3]))),
        ],
      ),
    );
  }

  Widget _headerCell(String t) => Text(t,
      style: GoogleFonts.inter(
          fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white));

  Widget _buildTableRow(Map<String, dynamic> e, int index) {
    final bool isEven = index % 2 == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF1F5F9),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: (e['tipo'] == 'RESTRICCION'
                              ? Colors.red
                              : Colors.blue)
                          .withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Text(
                      (e['nombre_visible']?.toString() ?? "E")[0].toUpperCase(),
                      style: GoogleFonts.inter(
                          color: e['tipo'] == 'RESTRICCION'
                              ? Colors.red
                              : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e['nombre_visible']?.toString() ?? "Etiqueta",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: const Color(0xFF1E293B))),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(e['nombre']?.toString() ?? "N/A",
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: NutriBadge(
                  label: e['tipo'].toString(),
                  type: e['tipo'] == 'RESTRICCION' ? 'danger' : 'info'),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit_note_rounded,
                        size: 20, color: AppTema.azulPrincipal),
                    onPressed: () => _rename(e['id'], e['nombre_visible'])),
                IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: Colors.redAccent),
                    onPressed: () => _delete(e['id'], e['nombre_visible'])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
