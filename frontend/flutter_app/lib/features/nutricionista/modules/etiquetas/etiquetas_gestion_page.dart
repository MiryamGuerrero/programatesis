import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';

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
      final repo = ref.read(inteligenciaRepositoryProvider);
      final dio = ref.read(dioProvider); // Usamos dio para los endpoints específicos si no están en repo
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar etiquetas: Asegúrate de tener sesión activa.'))
        );
      }
    }
  }

  Future<void> _rename(int id, String oldName) async {
    final controller = TextEditingController(text: oldName);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar Etiqueta'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nuevo nombre'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Guardar')),
        ],
      ),
    );

    if (nuevo != null && nuevo.trim().isNotEmpty && nuevo != oldName) {
      try {
        final dio = ref.read(dioProvider);
        await dio.put('etiquetas/$id', data: {'nombre_visible': nuevo.trim()});
        _fetch();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al renombrar: $e')));
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete('etiquetas/$id');
        _fetch();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _etiquetas.where((e) => 
      e['nombre_visible'].toString().toLowerCase().contains(_search.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gestión de Etiquetas', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900)),
                      const Text('Administra los nombres y existencias de reglas nutricionales', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 220,
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Filtrar etiquetas...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading) 
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = filtered[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      leading: CircleAvatar(
                        backgroundColor: (e['tipo'] == 'RESTRICCION' ? Colors.red : Colors.blue).withOpacity(0.1),
                        child: Text(e['nombre_visible'][0], style: TextStyle(color: e['tipo'] == 'RESTRICCION' ? Colors.red : Colors.blue)),
                      ),
                      title: Text(e['nombre_visible'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Tipo: ${e['tipo']} | Código: ${e['nombre']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_note, color: Colors.blueGrey),
                            onPressed: () => _rename(e['id'], e['nombre_visible']),
                            tooltip: 'Renombrar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _delete(e['id'], e['nombre_visible']),
                            tooltip: 'Eliminar del sistema',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
