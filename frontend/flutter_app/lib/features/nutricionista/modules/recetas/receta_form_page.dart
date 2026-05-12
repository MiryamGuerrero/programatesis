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
    this.idReceta,
    this.recetaInicial,
    required this.onBack,
  });

  final int? idReceta;

  @override
  ConsumerState<RecetaFormPage> createState() => _RecetaFormPageState();
}

class _RecetaFormPageState extends ConsumerState<RecetaFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _initializing = true;
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
  
  String _dificultad = 'Media';
  bool _activa = true;
  String? _imagenUrl;

  // Listas Dinámicas
  List<Map<String, dynamic>> _ingredientes = [];
  List<Map<String, dynamic>> _pasos = [];
  List<Map<String, dynamic>> _etiquetasSeleccionadas = [];
  
  // Catálogos
  List<dynamic> _momentosDisponibles = [];
  List<dynamic> _tiposPlatoDisponibles = [];
  List<int> _momentosSeleccionados = [];
  List<int> _tiposPlatoSeleccionados = [];

  // Búsqueda de Etiquetas
  List<dynamic> _etiquetasBuscadas = [];
  bool _loadingEtiquetas = false;

  @override
  void initState() {
    super.initState();
    _ctrlNombre = TextEditingController();
    _ctrlDescCorta = TextEditingController();
    _ctrlDescLarga = TextEditingController();
    _ctrlPorciones = TextEditingController(text: '1');
    _ctrlTPrep = TextEditingController(text: '0');
    _ctrlTCoccion = TextEditingController(text: '0');
    
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _initializing = true);
    try {
      final dio = ref.read(dioProvider);
      
      // 1. Cargar Catálogos
      final resMom = await dio.get('crud/momentos');
      final resTip = await dio.get('crud/tipos-plato');
      _momentosDisponibles = resMom.data;
      _tiposPlatoDisponibles = resTip.data;

      // 2. Cargar Receta si es edición
      final r = widget.recetaInicial;
      if (r != null) {
        _ctrlNombre.text = r['nombre'] ?? '';
        _ctrlDescCorta.text = r['descripcion'] ?? '';
        _ctrlDescLarga.text = r['descripcion_larga'] ?? '';
        _ctrlPorciones.text = (r['porciones'] ?? 1).toString();
        _ctrlTPrep.text = (r['tiempo_preparacion_min'] ?? r['tiempo_preparacion'] ?? 0).toString();
        _ctrlTCoccion.text = (r['tiempo_coccion_min'] ?? r['tiempo_coccion'] ?? 0).toString();
        
        _dificultad = r['dificultad'] ?? 'Media';
        _activa = r['activa'] ?? true;
        _imagenUrl = r['imagen_url'];
        _ingredientes = List<Map<String, dynamic>>.from(r['ingredientes'] ?? []);
        _pasos = List<Map<String, dynamic>>.from(r['preparacion'] ?? []);
        _etiquetasSeleccionadas = List<Map<String, dynamic>>.from(r['etiquetas_salud'] ?? []);
        
        _momentosSeleccionados = List<int>.from(r['momentos'] ?? []);
        _tiposPlatoSeleccionados = List<int>.from(r['tipos_plato'] ?? []);
      }
      
      if (_pasos.isEmpty) {
        _pasos.add({'paso': 1, 'descripcion': '', 'tiempo': '', 'nota': ''});
      }

    } catch (e) {
      debugPrint("Error inicializando formulario: $e");
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? picked = await RecipeImageService.pickAndCropImage(context, ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageFile = picked;
        _imagePreviewBytes = bytes;
      });
    }
  }

  Future<void> _quitarImagen() async {
    setState(() {
      _imageFile = null;
      _imagePreviewBytes = null;
      _imagenUrl = null;
    });
  }

  Future<void> _buscarEtiquetas(String q) async {
    if (q.isEmpty) {
      setState(() => _etiquetasBuscadas = []);
      return;
    }
    setState(() => _loadingEtiquetas = true);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('nutricionista/etiquetas', queryParameters: {'q': q});
      if (mounted) {
        setState(() {
          _etiquetasBuscadas = resp.data;
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
      String? finalImageUrl = _imagenUrl;

      // 1. Manejo de cambio/eliminación de imagen
      final bool esEdicion = widget.recetaInicial != null;
      final String? urlPrevia = esEdicion ? widget.recetaInicial!['imagen_url'] : null;

      // Si se subió una nueva imagen
      if (_imageFile != null) {
        setState(() => _uploadingImage = true);
        try {
          // Eliminar la previa si existía para no dejar huérfanos
          if (urlPrevia != null && urlPrevia.isNotEmpty) {
            await RecipeImageService.deleteImageByUrl(urlPrevia);
          }

          finalImageUrl = await RecipeImageService.uploadRecipeImage(
            imageFile: _imageFile!,
            fileName: 'receta_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } catch (e) {
          NutriSnack.show(context, 'Error al procesar imagen: $e', isError: true);
        } finally {
          setState(() => _uploadingImage = false);
        }
      } 
      // Si el usuario quitó la imagen manualmente
      else if (_imagenUrl == null && urlPrevia != null) {
        await RecipeImageService.deleteImageByUrl(urlPrevia);
        finalImageUrl = null;
      }

      final payload = {
        if (esEdicion) 'id': widget.recetaInicial!['id'],
        'nombre': _ctrlNombre.text,
        'descripcion': _ctrlDescCorta.text,
        'descripcion_larga': _ctrlDescLarga.text,
        'dificultad': _dificultad,
        'porciones': int.tryParse(_ctrlPorciones.text) ?? 1,
        'tiempo_preparacion': int.tryParse(_ctrlTPrep.text) ?? 0,
        'tiempo_coccion': int.tryParse(_ctrlTCoccion.text) ?? 0,
        'imagen_url': finalImageUrl,
        'activa': _activa,
        'ingredientes': _ingredientes,
        'preparacion': _pasos,
        'etiquetas_salud': _etiquetasSeleccionadas,
        'momentos': _momentosSeleccionados,
        'tipos_plato': _tiposPlatoSeleccionados,
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
      body: (_loading || _initializing)
        ? Center(child: NutriLoading(mensaje: _initializing ? 'Cargando catálogos...' : 'Procesando recetario...'))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSeccionInfoBasica(),
                  const SizedBox(height: 40),
                  _buildSeccionIngredientes(),
                  const SizedBox(height: 40),
                  _buildSeccionPasos(),
                  const SizedBox(height: 40),
                  _buildSeccionEtiquetas(),
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
              Expanded(child: _buildMultiSelect('Momentos de Comida', _momentosDisponibles, _momentosSeleccionados)),
              const SizedBox(width: 20),
              Expanded(child: _buildMultiSelect('Tipos de Plato', _tiposPlatoDisponibles, _tiposPlatoSeleccionados)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildDropdown('Dificultad *', ['Fácil', 'Media', 'Difícil'], _dificultad, (v) => setState(() => _dificultad = v!))),
              const SizedBox(width: 20),
              Expanded(child: _buildInputField('Porciones *', _ctrlPorciones, false, isNumber: true)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildInputField('Tiempo Prep. (min) *', _ctrlTPrep, false, isNumber: true)),
              const SizedBox(width: 20),
              Expanded(child: _buildInputField('Tiempo Cocción (min)', _ctrlTCoccion, false, isNumber: true)),
            ],
          ),
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

  Widget _buildMultiSelect(String label, List<dynamic> options, List<int> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
          child: Wrap(
            spacing: 8,
            children: options.map((opt) {
              final bool isSelected = selected.contains(opt['id']);
              return FilterChip(
                label: Text(opt['nombre'], style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.blueGrey)),
                selected: isSelected,
                selectedColor: AppTema.azulPrincipal,
                onSelected: (val) {
                  setState(() {
                    if (val) selected.add(opt['id']);
                    else selected.remove(opt['id']);
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final tieneImagen = _imagePreviewBytes != null || (_imagenUrl != null && _imagenUrl!.isNotEmpty);

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
              : (_imagenUrl != null && _imagenUrl!.isNotEmpty 
                  ? Image.network(
                      _imagenUrl!, 
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
                onPressed: _quitarImagen,
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                label: const Text('QUITAR', style: TextStyle(color: Colors.redAccent)),
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

<<<<<<< HEAD
=======
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

>>>>>>> 9f49549bc028bb5a0bc7b8cda2e6a8cbc14509d8
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
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ingredientes.length,
                  itemBuilder: (context, index) => _buildRowIngredienteItem(index),
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
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
                  setState(() => _ingredientes[index]['es_principal'] = v);
                  if (v == true && ing['id_ingrediente'] != null) {
                    _fetchAndAddEtiquetas(ing['id_ingrediente']);
                  }
                },
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
              onPressed: () => setState(() => _ingredientes.removeAt(index)),
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
    return _buildContenedorBlanco(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTituloSeccion('Preparación'),
              TextButton.icon(
                onPressed: () => setState(() => _pasos.add({'paso': _pasos.length + 1, 'descripcion': '', 'tiempo': '', 'nota': ''})),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('AÑADIR PASO'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pasos.length,
            itemBuilder: (context, index) => _buildCardPaso(index),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPaso(int index) {
    final p = _pasos[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, backgroundColor: AppTema.azulPrincipal, child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                TextFormField(
                  initialValue: p['descripcion'],
                  maxLines: 2,
                  decoration: _inputStyle('Instrucciones...'),
                  onChanged: (v) => _pasos[index]['descripcion'] = v,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextFormField(initialValue: p['tiempo'], decoration: _inputStyle('Tiempo'), onChanged: (v) => _pasos[index]['tiempo'] = v)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(initialValue: p['nota'], decoration: _inputStyle('Nota'), onChanged: (v) => _pasos[index]['nota'] = v)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => setState(() => _pasos.removeAt(index))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- BLOQUE 4: ETIQUETAS ---
  Widget _buildSeccionEtiquetas() {
    return _buildContenedorBlanco(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloSeccion('Etiquetas'),
          const SizedBox(height: 8),
          Text('Las etiquetas inteligentes se heredan de los ingredientes principales. Puedes gestionarlas manualmente aquí.', style: GoogleFonts.inter(fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 24),
          _buildEtiquetaBuscador(),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: _etiquetasSeleccionadas.map((e) => _buildTagChip(e)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> e) {
    return Chip(
      label: Text(e['titulo'] ?? e['nombre_visible'] ?? '-', style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: () => setState(() => _etiquetasSeleccionadas.remove(e)),
    );
  }

  Widget _buildEtiquetaBuscador() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(hintText: 'Buscar etiquetas...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          onChanged: _buscarEtiquetas,
        ),
        if (_loadingEtiquetas) const LinearProgressIndicator(),
        if (_etiquetasBuscadas.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _etiquetasBuscadas.length,
              itemBuilder: (context, index) {
                final tag = _etiquetasBuscadas[index];
                return ListTile(
                  title: Text(tag['nombre_visible']),
                  onTap: () {
                    setState(() {
                      if (!_etiquetasSeleccionadas.any((e) => e['id'] == tag['id'])) {
                        _etiquetasSeleccionadas.add({'id': tag['id'], 'titulo': tag['nombre_visible']});
                      }
                      _etiquetasBuscadas = [];
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // --- HELPERS ---
  Widget _buildContenedorBlanco({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: child,
    );
  }

  Widget _buildTituloSeccion(String t) {
    return Text(t, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, color: AppTema.azulOscuro));
  }

  Widget _buildInputField(String label, TextEditingController ctrl, bool fullWidth, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextFormField(controller: ctrl, maxLines: maxLines, keyboardType: isNumber ? TextInputType.number : TextInputType.text, decoration: _inputStyle(''), validator: (v) => v!.isEmpty && label.contains('*') ? 'Campo requerido' : null),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> options, String value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: value, items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged, decoration: _inputStyle('')),
      ],
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(16));
  }

  Widget _buildFooterFeedback() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppTema.pastelCeleste.withOpacity(0.3), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.lightbulb_outline_rounded, color: AppTema.azulPrincipal), const SizedBox(width: 16), Expanded(child: Text('La composición nutricional de la receta se calculará automáticamente basándose en los ingredientes y pesos seleccionados.', style: GoogleFonts.montserrat(fontSize: 13, color: AppTema.azulOscuro, fontWeight: FontWeight.w500)))]));
  }

  Widget _buildAccionesFinales() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [OutlinedButton(onPressed: widget.onBack, child: const Text('CANCELAR')), const SizedBox(width: 16), FilledButton.icon(onPressed: _guardar, icon: const Icon(Icons.save_rounded), label: Text(widget.recetaInicial == null ? 'CREAR RECETA' : 'ACTUALIZAR RECETA'))]);
  }

  void _abrirSelectorIngrediente() async {
    final List<Map<String, dynamic>>? seleccion = await showDialog<List<Map<String, dynamic>>>(
      context: context, 
      builder: (context) => const SelectorIngredienteDialog()
    );
    
    if (seleccion != null) {
      setState(() {
        _ingredientes.addAll(seleccion);
      });
    }
  }

  Future<void> _fetchAndAddEtiquetas(int idIngrediente) async {
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('nutricionista/ingredientes/$idIngrediente');
      final ingDetalle = resp.data;
      if (ingDetalle != null && ingDetalle['etiquetas'] != null) {
        final List<dynamic> etqs = ingDetalle['etiquetas'];
        setState(() {
          for (var etq in etqs) {
            if (!_etiquetasSeleccionadas.any((e) => e['id'] == etq['id'])) {
              _etiquetasSeleccionadas.add({
                'id': etq['id'], 
                'titulo': etq['nombre_visible'],
                'nombre_visible': etq['nombre_visible']
              });
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error al heredar etiquetas inteligentes: $e");
    }
  }
}
