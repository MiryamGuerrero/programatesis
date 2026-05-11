import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/recipe_image_service.dart';
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
  XFile? _imageFile;
  Uint8List? _imagePreviewBytes;
  bool _uploadingImage = false;

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

  Future<void> _seleccionarImagen() async {
    final XFile? picked = await RecipeImageService.pickImage(ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageFile = picked;
        _imagePreviewBytes = bytes;
      });
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
      String? finalImageUrl = _ctrlImagen.text;

      // 1. Subir imagen si se seleccionó una nueva
      if (_imageFile != null) {
        setState(() => _uploadingImage = true);
        try {
          finalImageUrl = await RecipeImageService.uploadRecipeImage(
            imageFile: _imageFile!,
            fileName: 'receta_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } catch (e) {
          NutriSnack.show(context, 'Error al subir imagen, se usará la URL previa', isError: true);
        } finally {
          setState(() => _uploadingImage = false);
        }
      }

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
        'imagen_url': (finalImageUrl == null || finalImageUrl.isEmpty) ? null : finalImageUrl,
        'activa': _activa,
        'ingredientes': _ingredientes,
        'preparacion': _pasos,
        'etiquetas_salud': _etiquetasSeleccionadas,
      };

      final dio = ref.read(dioProvider);
      final response = await dio.post('crud/recetas', data: payload);
      
      // 2. Si subimos imagen, registrarla en la tabla de imágenes
      if (response.data != null && response.data['id'] != null && _imageFile != null) {
        final idReceta = response.data['id'];
        await RecipeImageService.registerImageInDb(
          idReceta: idReceta,
          url: finalImageUrl!,
        );
      }
      
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePicker(),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    _buildInputField('Nombre de la receta *', _ctrlNombre, true),
                    const SizedBox(height: 20),
                    _buildInputField('Descripción corta (para la tarjeta) *', _ctrlDescCorta, true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInputField('Descripción detallada (terapéutica)', _ctrlDescLarga, true, maxLines: 3),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildDropdown('Categoría *', ['Desayuno', 'Media mañana', 'Almuerzo', 'Media tarde', 'Merienda', 'Cena', 'Snack', 'Bebida'], _categoria, (v) => setState(() => _categoria = v!))),
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
          _buildInputField('URL Imagen manual (opcional)', _ctrlImagen, true, hint: 'https://ejemplo.com/imagen.jpg'),
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

  Future<void> _eliminarImagen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar imagen?'),
        content: const Text('La imagen se borrará permanentemente del servidor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_ctrlImagen.text.isNotEmpty) {
        await RecipeImageService.deleteImageByUrl(_ctrlImagen.text);
      }
      setState(() {
        _imageFile = null;
        _imagePreviewBytes = null;
        _ctrlImagen.clear();
      });
      NutriSnack.show(context, 'Imagen eliminada');
    }
  }

  Widget _buildImagePicker() {
    final tieneImagen = _imagePreviewBytes != null || _ctrlImagen.text.isNotEmpty;

    return Column(
      children: [
        Container(
          width: 240,
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _imagePreviewBytes != null 
              ? Image.memory(_imagePreviewBytes!, fit: BoxFit.cover, width: 240, height: 180)
              : (_ctrlImagen.text.isNotEmpty 
                  ? Image.network(
                      _ctrlImagen.text, 
                      fit: BoxFit.cover, 
                      width: 240, 
                      height: 180,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholderContent(),
                    )
                  : _buildPlaceholderContent()),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _seleccionarImagen,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(tieneImagen ? 'CAMBIAR' : 'SUBIR IMAGEN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTema.azulPrincipal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (tieneImagen) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _eliminarImagen,
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                label: const Text('BORRAR', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
        if (_uploadingImage)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: SizedBox(width: 240, child: LinearProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildPlaceholderContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade300, size: 48),
        const SizedBox(height: 12),
        Text(
          'Sin imagen seleccionada', 
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500)
        ),
      ],
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
            (e['titulo'] ?? e['nombre_visible'])?.toString() ?? '-',
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
            Column(
              children: [
                _buildTableHeaderIngredienteRow(),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                SizedBox(
                  height: _ingredientes.length * 75.0, // Altura estimada para los items
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _ingredientes.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _ingredientes.removeAt(oldIndex);
                        _ingredientes.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) => _buildRowIngredienteItem(index),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderIngredienteRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 40), // Espacio para el drag handle
          Expanded(flex: 3, child: Text('Ingrediente', style: _headerStyle())),
          Expanded(flex: 2, child: Text('Cantidad', style: _headerStyle())),
          Expanded(flex: 2, child: Text('Unidad', style: _headerStyle())),
          Expanded(flex: 2, child: Text('Gramos', style: _headerStyle())),
          Expanded(flex: 2, child: Center(child: Text('Principal', style: _headerStyle()))),
          SizedBox(width: 80, child: Center(child: Text('Acciones', style: _headerStyle()))),
        ],
      ),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey);

  Widget _buildRowIngredienteItem(int index) {
    final ing = _ingredientes[index];
    final key = ValueKey('ing_${ing['id_ingrediente'] ?? ing['id']}_$index');

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const SizedBox(
              width: 40,
              child: Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
            ),
          ),
          Expanded(flex: 3, child: Text(ing['nombre'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: _buildRowInput(index, 'cantidad')),
          Expanded(flex: 2, child: _buildRowInput(index, 'unidad')),
          Expanded(flex: 2, child: _buildRowInput(index, 'gramos', isNumber: true)),
          Expanded(
            flex: 2,
            child: Center(
              child: Switch(
                value: ing['es_principal'] == true,
                activeColor: AppTema.verdeSalud,
                onChanged: (v) {
                  setState(() {
                    _ingredientes[index]['es_principal'] = v;
                  });
                },
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _ingredientes.removeAt(index)),
                  tooltip: 'Quitar ingrediente',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowInput(int index, String key, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextFormField(
        initialValue: _ingredientes[index][key]?.toString(),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: _inputStyle(''),
        onChanged: (v) => _ingredientes[index][key] = isNumber ? (double.tryParse(v) ?? 0) : v,
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
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _pasos.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _pasos.removeAt(oldIndex);
              _pasos.insert(newIndex, item);
              
              // Actualizar el número de paso en la data interna
              for (int i = 0; i < _pasos.length; i++) {
                _pasos[i]['paso'] = i + 1;
              }
            });
          },
          itemBuilder: (context, index) => _buildCardPaso(index),
        ),
      ],
    );
  }

  Widget _buildCardPaso(int index) {
    final p = _pasos[index];
    // Key estable basada en contenido inicial o un identificador único si existiera
    final key = ValueKey('paso_${p['paso']}_$index');

    return Container(
      key: key,
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
          // Drag Handle e Índice
          Column(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 24),
              ),
              const SizedBox(height: 12),
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(color: AppTema.azulPrincipal, shape: BoxShape.circle),
                child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ),
            ],
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
                      onPressed: () => setState(() {
                        _pasos.removeAt(index);
                        // Re-indexar tras eliminar
                        for (int i = 0; i < _pasos.length; i++) {
                          _pasos[i]['paso'] = i + 1;
                        }
                      }),
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
    // Asegurar que value esté en options para evitar error de Dropdown
    final effectiveValue = options.contains(value) ? value : options.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: effectiveValue,
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
