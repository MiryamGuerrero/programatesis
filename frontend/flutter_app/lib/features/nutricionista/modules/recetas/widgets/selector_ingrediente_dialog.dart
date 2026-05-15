import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/state/app_providers.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/layout_components.dart';

class SelectorIngredienteDialog extends ConsumerStatefulWidget {
  const SelectorIngredienteDialog({super.key});

  @override
  ConsumerState<SelectorIngredienteDialog> createState() => _SelectorIngredienteDialogState();
}

class _SelectorIngredienteDialogState extends ConsumerState<SelectorIngredienteDialog> {
  String _query = "";
  List<Map<String, dynamic>> _resultados = [];
  final List<Map<String, dynamic>> _seleccionados = [];
  bool _buscando = false;

  // Estado para el ingrediente que se está configurando actualmente
  Map<String, dynamic>? _ingredienteEnConfig;
  final _ctrlCantidad = TextEditingController(text: '1');
  final _ctrlUnidad = TextEditingController(text: 'unidad');
  final _ctrlGramos = TextEditingController(text: '100');
  final _ctrlObservaciones = TextEditingController();

  Future<void> _buscar(String v) async {
    if (v.length < 2) {
      setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      // Usamos el listado de ingredientes maestro
      final data = await repo.fetchIngredientes();
      if (!mounted) return;
      setState(() {
        _resultados = data.where((i) =>
          i['nombre'].toString().toLowerCase().contains(v.toLowerCase())
        ).toList();
      });
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _configurarIngrediente(Map<String, dynamic> item) {
    setState(() {
      _ingredienteEnConfig = item;
      _ctrlCantidad.text = '1';
      _ctrlUnidad.text = 'unidad';
      _ctrlGramos.text = '100';
      _ctrlObservaciones.clear();
    });
  }

  void _confirmarIngredienteIndividual() {
    if (_ingredienteEnConfig == null) return;

    setState(() {
      _seleccionados.add({
        'id_ingrediente': _ingredienteEnConfig!['id'],
        'nombre': _ingredienteEnConfig!['nombre'],
        'cantidad': double.tryParse(_ctrlCantidad.text) ?? 1.0,
        'unidad': _ctrlUnidad.text,
        'gramos': double.tryParse(_ctrlGramos.text) ?? 0.0,
        'observaciones': _ctrlObservaciones.text.trim(),
      });
      _ingredienteEnConfig = null;
      _query = "";
      _resultados = [];
    });
  }

  @override
  void dispose() {
    _ctrlCantidad.dispose();
    _ctrlUnidad.dispose();
    _ctrlGramos.dispose();
    _ctrlObservaciones.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogHeight = (screenSize.height - 48).clamp(420.0, 700.0).toDouble();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 900,
        height: dialogHeight,
        padding: const EdgeInsets.all(32),
        child: Row(
          children: [
            // PANEL IZQUIERDO: Búsqueda y Resultados
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBusqueda(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _ingredienteEnConfig != null
                      ? _buildFormularioConfiguracion()
                      : _buildListaResultados(),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 64, color: Color(0xFFF1F5F9)),
            // PANEL DERECHO: Selección Actual
            Expanded(
              flex: 2,
              child: _buildPanelSeleccionados(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBusqueda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Añadir Ingredientes',
          style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) {
            _query = v;
            _buscar(v);
          },
          decoration: InputDecoration(
            hintText: 'Buscar en el catálogo de alimentos...',
            prefixIcon: const Icon(Icons.search, color: AppTema.azulPrincipal),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildListaResultados() {
    if (_buscando) return const Center(child: NutriLoading(mensaje: 'Consultando catálogo...'));
    if (_resultados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text('Escribe el nombre de un alimento\npara comenzar la búsqueda',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _resultados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _resultados[index];
        return ListTile(
          onTap: () => _configurarIngrediente(item),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFFF8FAFC),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTema.pastelCeleste, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.shopping_basket_outlined, color: AppTema.azulPrincipal, size: 20),
          ),
          title: Text(item['nombre']?.toString() ?? "Ingrediente", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(item['categoria']?.toString() ?? 'Sin categoría'),
          trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTema.azulPrincipal),
        );
      },
    );
  }

  Widget _buildFormularioConfiguracion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        IconButton(
          onPressed: () => setState(() => _ingredienteEnConfig = null),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTema.pastelCeleste.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTema.pastelCeleste),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configurar Cantidad', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
              const SizedBox(height: 8),
              Text(
                _ingredienteEnConfig!['nombre']?.toString() ?? "Ingrediente",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _buildConfigInput('Cantidad', _ctrlCantidad, true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildConfigInput('Unidad (taza, unidad, etc)', _ctrlUnidad, false)),
                ],
              ),
              const SizedBox(height: 12),
              _buildConfigInput('Peso Técnico en Gramos (g)', _ctrlGramos, true),
              const SizedBox(height: 12),
              _buildConfigInput('Observaciones', _ctrlObservaciones, false, maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _confirmarIngredienteIndividual,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('AGREGAR A LA LISTA'),
                  style: FilledButton.styleFrom(backgroundColor: AppTema.azulPrincipal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildConfigInput(String label, TextEditingController ctrl, bool isNumber, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelSeleccionados() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Seleccionados', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTema.azulOscuro, borderRadius: BorderRadius.circular(20)),
              child: Text('${_seleccionados.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _seleccionados.isEmpty
            ? Center(child: Text('Aún no has seleccionado nada', style: TextStyle(color: Colors.grey.shade400)))
            : ListView.separated(
                itemCount: _seleccionados.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = _seleccionados[index];
                  final observaciones = s['observaciones']?.toString().trim() ?? '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s['nombre']?.toString() ?? "Ingrediente", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                      observaciones.isEmpty
                          ? '${s['cantidad']} ${s['unidad']} (${s['gramos']}g)'
                          : '${s['cantidad']} ${s['unidad']} (${s['gramos']}g) - $observaciones',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => setState(() => _seleccionados.removeAt(index)),
                    ),
                  );
                },
              ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton(
            onPressed: _seleccionados.isEmpty ? null : () => Navigator.pop(context, _seleccionados),
            style: FilledButton.styleFrom(
              backgroundColor: AppTema.verdeSalud,
              disabledBackgroundColor: Colors.grey.shade200,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('CONFIRMAR SELECCIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
