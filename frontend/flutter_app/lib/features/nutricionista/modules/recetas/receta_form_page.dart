import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import 'widgets/selector_ingrediente_dialog.dart';

class RecetaFormPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? recetaInicial;
  final VoidCallback onBack;

  const RecetaFormPage({
    super.key,
    this.recetaInicial,
    required this.onBack,
  });

  @override
  ConsumerState<RecetaFormPage> createState() => _RecetaFormPageState();
}

class _RecetaFormPageState extends ConsumerState<RecetaFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // Controladores Básicos
  late TextEditingController _ctrlNombre;
  late TextEditingController _ctrlDescCorta;
  late TextEditingController _ctrlDescLarga;
  late TextEditingController _ctrlPorciones;
  late TextEditingController _ctrlTPrep;
  late TextEditingController _ctrlTCoccion;
  late TextEditingController _ctrlImagen;
  
  String _dificultad = 'Media';
  String _categoria = 'Almuerzo';
  bool _activa = true;

  // Listas Dinámicas
  List<Map<String, dynamic>> _ingredientes = [];
  List<Map<String, dynamic>> _pasos = [];
  List<Map<String, dynamic>> _etiquetasSeleccionadas = [];
  
  // Búsqueda de Etiquetas
  List<dynamic> _etiquetasDisponibles = [];
  bool _loadingEtiquetas = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recetaInicial;
    _ctrlNombre = TextEditingController(text: r?['nombre'] ?? '');
    _ctrlDescCorta = TextEditingController(text: r?['descripcion'] ?? '');
    _ctrlDescLarga = TextEditingController(text: r?['descripcion_larga'] ?? '');
    _ctrlPorciones = TextEditingController(text: (r?['porciones'] ?? 1).toString());
    _ctrlTPrep = TextEditingController(text: (r?['tiempo_preparacion'] ?? 0).toString());
    _ctrlTCoccion = TextEditingController(text: (r?['tiempo_coccion'] ?? 0).toString());
    _ctrlImagen = TextEditingController(text: r?['imagen_url'] ?? '');
    
    if (r != null) {
      _dificultad = r['dificultad'] ?? 'Media';
      _categoria = r['categoria'] ?? 'Almuerzo';
      _activa = r['activa'] ?? true;
      _ingredientes = List<Map<String, dynamic>>.from(r['ingredientes'] ?? []);
      _pasos = List<Map<String, dynamic>>.from(r['preparacion'] ?? []);
      _etiquetasSeleccionadas = List<Map<String, dynamic>>.from(r['etiquetas_salud'] ?? []);
    }
    
    if (_pasos.isEmpty && r == null) {
      _pasos.add({'paso': 1, 'descripcion': '', 'tiempo': '', 'nota': ''});
    }
  }

  Future<void> _buscarEtiquetas(String q) async {
    if (q.isEmpty) {
      setState(() => _etiquetasDisponibles = []);
      return;
    }
    setState(() => _loadingEtiquetas = true);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('nutricionista/etiquetas', queryParameters: {'q': q});
      if (mounted) {
        setState(() {
          _etiquetasDisponibles = resp.data;
          _loadingEtiquetas = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingEtiquetas = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    try {
      final payload = {
        if (widget.recetaInicial != null) 'id': widget.recetaInicial!['id'],
        'nombre': _ctrlNombre.text,
        'descripcion': _ctrlDescCorta.text,
        'descripcion_larga': _ctrlDescLarga.text,
        'dificultad': _dificultad,
        'categoria': _categoria,
        'porciones': int.tryParse(_ctrlPorciones.text) ?? 1,
        'tiempo_preparacion': int.tryParse(_ctrlTPrep.text) ?? 0,
        'tiempo_coccion': int.tryParse(_ctrlTCoccion.text) ?? 0,
        'imagen_url': _ctrlImagen.text.isEmpty ? null : _ctrlImagen.text,
        'activa': _activa,
        'ingredientes': _ingredientes,
        'preparacion': _pasos,
        'etiquetas_salud': _etiquetasSeleccionadas,
      };

      final dio = ref.read(dioProvider);
      await dio.post('crud/recetas', data: payload);
      
      if (!mounted) return;
      NutriSnack.show(context, 'Receta guardada con éxito');
      widget.onBack();
    } catch (e) {
      NutriSnack.show(context, 'Error al guardar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.grey),
          onPressed: widget.onBack,
        ),
        title: Text(
          widget.recetaInicial == null ? 'Nueva Receta' : 'Editar Receta',
          style: GoogleFonts.montserrat(color: AppTema.azulOscuro, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _loading 
        ? const Center(child: NutriLoading(mensaje: 'Procesando recetario...'))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSeccionInfoBasica(),
                  const SizedBox(height: 40),
                  _buildSeccionEtiquetas(),
                  const SizedBox(height: 40),
                  _buildSeccionIngredientes(),
                  const SizedBox(height: 40),
                  _buildSeccionPasos(),
                  const SizedBox(height: 40),
                  _buildFooterFeedback(),
                  const SizedBox(height: 40),
                  _buildAccionesFinales(),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
    );
  }

  // --- BLOQUE 1: INFORMACIÓN BÁSICA ---
  Widget _buildSeccionInfoBasica() {
    return _buildContenedorBlanco(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloSeccion('Información Básica'),
          const SizedBox(height: 24),
          _buildInputField('Nombre de la receta *', _ctrlNombre, true),
          const SizedBox(height: 20),
          _buildInputField('Descripción corta (para la tarjeta) *', _ctrlDescCorta, true),
          const SizedBox(height: 20),
          _buildInputField('Descripción detallada (terapéutica)', _ctrlDescLarga, true, maxLines: 3),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildDropdown('Categoría *', ['Almuerzo', 'Desayuno', 'Cena', 'Snack', 'Bebida'], _categoria, (v) => setState(() => _categoria = v!))),
              const SizedBox(width: 20),
              Expanded(child: _buildDropdown('Dificultad *', ['Fácil', 'Media', 'Difícil'], _dificultad, (v) => setState(() => _dificultad = v!))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildInputField('Porciones *', _ctrlPorciones, false, isNumber: true)),
              const SizedBox(width: 20),
              Expanded(child: _buildInputField('Tiempo Prep. (min) *', _ctrlTPrep, false, isNumber: true)),
              const SizedBox(width: 20),
              Expanded(child: _buildInputField('Tiempo Cocción (min)', _ctrlTCoccion, false, isNumber: true)),
            ],
          ),
          const SizedBox(height: 20),
          _buildInputField('URL Imagen de referencia', _ctrlImagen, true, hint: 'https://ejemplo.com/imagen.jpg'),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _activa,
            onChanged: (v) => setState(() => _activa = v!),
            title: Text('Receta activa y visible para planificación', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: AppTema.azulOscuro)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppTema.azulPrincipal,
          ),
        ],
      ),
    );
  }

  // --- BLOQUE ETIQUETAS ---
  Widget _buildSeccionEtiquetas() {
    return _buildContenedorBlanco(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloSeccion('Etiquetas Nutricionales'),
          const SizedBox(height: 8),
          Text('Asigna etiquetas para clasificar la receta (ej: Sin Gluten, Keto, etc.)', style: GoogleFonts.inter(fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 24),
          
          _buildEtiquetaBuscador(),
          
          const SizedBox(height: 24),
          if (_etiquetasSeleccionadas.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text('No hay etiquetas seleccionadas.', 
                  style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13, fontStyle: FontStyle.italic)),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _etiquetasSeleccionadas.map((e) => _buildTagChip(e)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tag_rounded, size: 14, color: AppTema.azulPrincipal),
          const SizedBox(width: 8),
          Text(
            e['titulo'] ?? e['nombre_visible'] ?? '-',
            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: AppTema.azulOscuro),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _etiquetasSeleccionadas.remove(e)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.close_rounded, size: 12, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtiquetaBuscador() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar etiquetas...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppTema.azulPrincipal),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onChanged: _buscarEtiquetas,
        ),
        if (_loadingEtiquetas)
          const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
        if (_etiquetasDisponibles.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _etiquetasDisponibles.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade50, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final tag = _etiquetasDisponibles[index];
                final yaSeleccionada = _etiquetasSeleccionadas.any((e) => e['id'] == tag['id']);
                
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: yaSeleccionada ? Colors.green.withOpacity(0.1) : Colors.grey.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      yaSeleccionada ? Icons.check_rounded : Icons.label_outline_rounded,
                      size: 14,
                      color: yaSeleccionada ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(tag['nombre_visible'], style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
                  subtitle: Text(tag['codigo'], style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey.shade400)),
                  trailing: yaSeleccionada 
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                    : IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: AppTema.azulPrincipal, size: 24),
                        onPressed: () {
                          setState(() {
                            _etiquetasSeleccionadas.add({
                              'id': tag['id'],
                              'titulo': tag['nombre_visible'],
                              'explicacion': tag['codigo'],
                            });
                            _etiquetasDisponibles = [];
                          });
                        },
                      ),
                );
              },
            ),
          ),
      ],
    );
  }

  // --- BLOQUE 2: GESTIÓN DE INGREDIENTES ---
  Widget _buildSeccionIngredientes() {
    return _buildContenedorBlanco(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTituloSeccion('Gestión de Ingredientes (${_ingredientes.length})'),
              FilledButton.icon(
                onPressed: _abrirSelectorIngrediente,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('AGREGAR INGREDIENTE'),
                style: FilledButton.styleFrom(backgroundColor: AppTema.azulPrincipal, padding: const EdgeInsets.symmetric(horizontal: 16)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_ingredientes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text('No hay ingredientes. Agrega al menos uno para calcular la nutrición.', style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
            )
          else
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(4),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(2),
                5: IntrinsicColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _buildTableHeaderIngrediente(),
                ...List.generate(_ingredientes.length, (index) => _buildRowIngrediente(index)),
              ],
            ),
        ],
      ),
    );
  }

  // --- BLOQUE 3: PASOS DE PREPARACIÓN ---
  Widget _buildSeccionPasos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTituloSeccion('Pasos de Preparación'),
            TextButton.icon(
              onPressed: () => setState(() => _pasos.add({'paso': _pasos.length + 1, 'descripcion': '', 'tiempo': '', 'nota': ''})),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('AÑADIR PASO'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...List.generate(_pasos.length, (index) => _buildCardPaso(index)),
      ],
    );
  }

  Widget _buildCardPaso(int index) {
    final p = _pasos[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: AppTema.azulPrincipal, shape: BoxShape.circle),
            child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                TextFormField(
                  initialValue: p['descripcion'],
                  maxLines: 2,
                  decoration: _inputStyle('Instrucciones del paso...'),
                  onChanged: (v) => _pasos[index]['descripcion'] = v,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(
                      initialValue: p['tiempo'],
                      decoration: _inputStyle('Tiempo (ej: 5 min)'),
                      onChanged: (v) => _pasos[index]['tiempo'] = v,
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(
                      initialValue: p['nota'],
                      decoration: _inputStyle('Nota adicional o temperatura'),
                      onChanged: (v) => _pasos[index]['nota'] = v,
                    )),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => setState(() => _pasos.removeAt(index)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PIE Y FEEDBACK ---
  Widget _buildFooterFeedback() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTema.pastelCeleste.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppTema.azulPrincipal),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'La composición nutricional de la receta se calculará automáticamente basándose en los ingredientes y pesos seleccionados.',
              style: GoogleFonts.montserrat(fontSize: 13, color: AppTema.azulOscuro, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesFinales() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: widget.onBack,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
          child: const Text('CANCELAR'),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.save_rounded),
          label: Text(widget.recetaInicial == null ? 'CREAR RECETA' : 'ACTUALIZAR RECETA'),
          style: FilledButton.styleFrom(backgroundColor: AppTema.azulPrincipal, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
        ),
      ],
    );
  }

  // --- HELPERS DE UI ---
  Widget _buildContenedorBlanco({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildTituloSeccion(String t) {
    return Text(t, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, color: AppTema.azulOscuro));
  }

  Widget _buildInputField(String label, TextEditingController ctrl, bool fullWidth, {bool isNumber = false, int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: _inputStyle(hint ?? ''),
          validator: (v) => v!.isEmpty && label.contains('*') ? 'Campo requerido' : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> options, String value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
          decoration: _inputStyle(''),
        ),
      ],
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  TableRow _buildTableHeaderIngrediente() {
    return TableRow(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      children: [' ', 'Ingrediente', 'Cant.', 'Unidad', 'Gramos', ' '].map((c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(c, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
      )).toList(),
    );
  }

  TableRow _buildRowIngrediente(int index) {
    final ing = _ingredientes[index];
    return TableRow(
      children: [
        const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
        Padding(padding: const EdgeInsets.all(8), child: Text(ing['nombre'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
        _buildTableInput(index, 'cantidad'),
        _buildTableInput(index, 'unidad'),
        _buildTableInput(index, 'gramos', isNumber: true),
        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18), onPressed: () => setState(() => _ingredientes.removeAt(index))),
      ],
    );
  }

  Widget _buildTableInput(int index, String key, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: TextFormField(
        initialValue: _ingredientes[index][key]?.toString(),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: _inputStyle(''),
        onChanged: (v) => _ingredientes[index][key] = isNumber ? (double.tryParse(v) ?? 0) : v,
      ),
    );
  }

  // --- LÓGICA DE SELECCIÓN DE INGREDIENTES ---
  void _abrirSelectorIngrediente() async {
    final List<Map<String, dynamic>>? seleccion = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => const SelectorIngredienteDialog(),
    );

    if (seleccion != null && seleccion.isNotEmpty) {
      setState(() {
        _ingredientes.addAll(seleccion);
      });
    }
  }
}
