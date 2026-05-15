import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/recipe_image_service.dart';
import 'widgets/selector_ingrediente_dialog.dart';

class RecetaFormPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? recetaInicial;
  final VoidCallback onBack;
  final int? idReceta;

  const RecetaFormPage({
    super.key,
    this.idReceta,
    this.recetaInicial,
    required this.onBack,
  });

  @override
  ConsumerState<RecetaFormPage> createState() => _RecetaFormPageState();
}

class _RecetaFormPageState extends ConsumerState<RecetaFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _initializing = true;
  
  // Soporte para archivos físicos
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

        _dificultad = _normalizarDificultad(r['dificultad']);
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
    final XFile? picked = await RecipeImageService.pickImage(ImageSource.gallery);
    if (picked != null) {
      final bytes = await RecipeImageService.optimizeImage(picked);
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
    final ingredientesSinId = _ingredientes.where((ing) => ing['id_ingrediente'] == null).length;
    if (ingredientesSinId > 0) {
      NutriSnack.show(
        context,
        'Hay $ingredientesSinId ingrediente(s) sin coincidencia en el catálogo. Elimínalos y agrégalos con el selector antes de guardar.',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      String? finalImageUrl = _imagenUrl;

      // 1. Manejo de subida física si se seleccionó un archivo
      if (_imageFile != null) {
        setState(() => _uploadingImage = true);
        try {
          finalImageUrl = await RecipeImageService.uploadRecipeImage(
            imageFile: _imageFile!,
            fileName: 'receta_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } catch (e) {
          NutriSnack.show(context, 'Error al subir imagen: $e', isError: true);
        } finally {
          setState(() => _uploadingImage = false);
        }
      }

      final payload = {
        if (widget.recetaInicial != null) 'id': widget.recetaInicial!['id'],
        'nombre': _ctrlNombre.text,
        'descripcion': _ctrlDescCorta.text,
        'descripcion_larga': _ctrlDescLarga.text,
        'dificultad': _normalizarDificultad(_dificultad),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: _abrirImportadorJson,
              icon: const Icon(Icons.data_object_rounded, size: 18),
              label: const Text('CÓDIGO JSON'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTema.azulPrincipal,
                side: const BorderSide(color: AppTema.azulPrincipal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
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

  String _normalizarDificultad(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    switch (raw) {
      case 'facil':
      case 'fácil':
      case 'fã¡cil':
      case 'fãƒâ¡cil':
        return 'Fácil';
      case 'dificil':
      case 'difícil':
      case 'difã­cil':
      case 'difãƒâ­cil':
        return 'Difícil';
      case 'media':
        return 'Media';
      default:
        return 'Media';
    }
  }

  Future<void> _abrirImportadorJson() async {
    final ctrl = TextEditingController(text: _jsonEjemplo);
    final jsonText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        title: Row(
          children: [
            const Icon(Icons.data_object_rounded, color: AppTema.azulPrincipal),
            const SizedBox(width: 12),
            Text('Código JSON', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 860,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Llena esta estructura, presiona ACEPTAR y la información se reflejará en el formulario para editarla antes de guardar.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.blueGrey.shade700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ctrl.text = _jsonEjemplo,
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('USAR ESTRUCTURA'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => ctrl.clear(),
                      icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                      label: const Text('LIMPIAR'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 22,
                  minLines: 16,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    helperText: 'Puedes pegar tu JSON completo aquí. También se acepta que venga dentro de { "receta": ... }.',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, ctrl.text),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('ACEPTAR'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (jsonText == null || jsonText.trim().isEmpty) return;
    await _aplicarJsonReceta(jsonText);
  }

  Future<void> _aplicarJsonReceta(String rawJson) async {
    try {
      final root = jsonDecode(rawJson);
      if (root is! Map<String, dynamic>) {
        NutriSnack.show(context, 'El JSON debe ser un objeto de receta.', isError: true);
        return;
      }
      final decoded = root['receta'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(root['receta'] as Map)
          : root;

      final ingredientes = _listaMapas(decoded['ingredientes']);
      final pasos = _listaMapas(decoded['preparacion'] ?? decoded['pasos']);
      final etiquetas = _listaMapas(decoded['etiquetas_salud'] ?? decoded['etiquetas'] ?? decoded['etiquetas_salud_sugeridas']);
      final ingredientesNormalizados = await _normalizarIngredientesJson(ingredientes);
      final etiquetasNormalizadas = await _normalizarEtiquetasJson(etiquetas);

      setState(() {
        _ctrlNombre.text = _texto(decoded['nombre'], fallback: _ctrlNombre.text);
        _ctrlDescCorta.text = _texto(decoded['descripcion'] ?? decoded['descripcion_corta'], fallback: _ctrlDescCorta.text);
        _ctrlDescLarga.text = _texto(decoded['descripcion_larga'], fallback: _ctrlDescLarga.text);
        _ctrlPorciones.text = _enteroTexto(decoded['porciones'], fallback: _ctrlPorciones.text);
        _ctrlTPrep.text = _enteroTexto(decoded['tiempo_preparacion'] ?? decoded['tiempo_preparacion_min'], fallback: _ctrlTPrep.text);
        _ctrlTCoccion.text = _enteroTexto(decoded['tiempo_coccion'] ?? decoded['tiempo_coccion_min'], fallback: _ctrlTCoccion.text);
        if (decoded.containsKey('dificultad')) _dificultad = _normalizarDificultad(decoded['dificultad']);
        _activa = decoded['activa'] is bool ? decoded['activa'] as bool : _activa;
        _imagenUrl = _texto(decoded['imagen_url'], fallback: _imagenUrl ?? '');
        if (_imagenUrl != null && _imagenUrl!.isEmpty) _imagenUrl = null;
        _imageFile = null;
        _imagePreviewBytes = null;

        if (ingredientesNormalizados.isNotEmpty) _ingredientes = ingredientesNormalizados;
        if (pasos.isNotEmpty) {
          _pasos = pasos.asMap().entries.map((entry) => _normalizarPasoJson(entry.key, entry.value)).toList();
        }
        if (etiquetasNormalizadas.isNotEmpty) _etiquetasSeleccionadas = etiquetasNormalizadas;

        _momentosSeleccionados = _normalizarIdsSeleccionados(decoded['momentos'] ?? decoded['momentos_comida'], _momentosDisponibles, _momentosSeleccionados);
        _tiposPlatoSeleccionados = _normalizarIdsSeleccionados(decoded['tipos_plato'], _tiposPlatoDisponibles, _tiposPlatoSeleccionados);
      });

      final sinId = ingredientesNormalizados.where((ing) => ing['id_ingrediente'] == null).length;
      final etiquetasSinId = etiquetasNormalizadas.where((etq) => etq['id'] == null).length;
      NutriSnack.show(
        context,
        sinId == 0 && etiquetasSinId == 0
            ? 'JSON cargado. Puedes editar la información y guardar.'
            : 'JSON cargado. Revisa $sinId ingrediente(s) y $etiquetasSinId etiqueta(s) sin coincidencia en catálogo.',
        isError: sinId > 0 || etiquetasSinId > 0,
      );
    } on FormatException catch (e) {
      NutriSnack.show(context, 'JSON inválido: ${e.message}', isError: true);
    } catch (e) {
      NutriSnack.show(context, 'No se pudo cargar el JSON: $e', isError: true);
    }
  }

  List<Map<String, dynamic>> _listaMapas(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> _normalizarIngredientesJson(List<Map<String, dynamic>> ingredientes) async {
    if (ingredientes.isEmpty) return [];
    final catalogo = await _cargarCatalogoIngredientes();
    final porNombre = {
      for (final ing in catalogo)
        _normalizarTextoBusqueda(ing['nombre']): ing,
    };

    return ingredientes.map((item) {
      final nombre = _texto(item['nombre'] ?? item['ingrediente'], fallback: 'Ingrediente');
      final match = porNombre[_normalizarTextoBusqueda(nombre)];
      return {
        'id_ingrediente': _entero(item['id_ingrediente'] ?? item['id']) ?? _entero(match?['id']),
        'nombre': match?['nombre']?.toString() ?? nombre,
        'cantidad': _decimal(item['cantidad'] ?? item['cantidad_visual'], fallback: 1),
        'unidad': _texto(item['unidad'] ?? item['unidad_visual'], fallback: 'unidad'),
        'gramos': _decimal(item['gramos'] ?? item['peso_gramos'] ?? item['peso_en_gramos'], fallback: 0),
        'observaciones': _texto(item['observaciones'], fallback: ''),
        'es_principal': item['es_principal'] == true,
      };
    }).toList();
  }

  Map<String, dynamic> _normalizarPasoJson(int index, Map<String, dynamic> item) {
    return {
      'paso': _entero(item['paso'] ?? item['numero_paso'], fallback: index + 1),
      'descripcion': _texto(item['descripcion'] ?? item['instruccion'], fallback: ''),
      'tiempo': _texto(item['tiempo'] ?? item['tiempo_estimado'], fallback: ''),
      'nota': _texto(item['nota'] ?? item['nota_adicional'], fallback: ''),
    };
  }

  Map<String, dynamic> _normalizarEtiquetaJson(Map<String, dynamic> item) {
    final id = _entero(item['id'] ?? item['id_etiqueta']);
    final nombre = _texto(item['titulo'] ?? item['nombre_visible'] ?? item['nombre'] ?? item['etiqueta'], fallback: '');
    if (id == null && nombre.isEmpty) return {};
    return {
      if (id != null) 'id': id,
      'titulo': nombre,
      'nombre_visible': nombre,
    };
  }

  Future<List<Map<String, dynamic>>> _normalizarEtiquetasJson(List<Map<String, dynamic>> etiquetas) async {
    if (etiquetas.isEmpty) return [];
    final catalogo = await _cargarCatalogoEtiquetas();
    final porNombre = {
      for (final etq in catalogo)
        _normalizarTextoBusqueda(etq['nombre_visible'] ?? etq['titulo'] ?? etq['nombre']): etq,
    };

    return etiquetas.map((item) {
      final base = _normalizarEtiquetaJson(item);
      if (base.isEmpty) return base;
      final nombre = _texto(base['titulo'] ?? item['etiqueta'], fallback: '');
      final match = porNombre[_normalizarTextoBusqueda(nombre)];
      return {
        if (_entero(base['id'] ?? match?['id']) != null) 'id': _entero(base['id'] ?? match?['id']),
        'titulo': match?['nombre_visible']?.toString() ?? nombre,
        'nombre_visible': match?['nombre_visible']?.toString() ?? nombre,
      };
    }).where((e) => e.isNotEmpty).toList();
  }

  List<int> _normalizarIdsSeleccionados(dynamic value, List<dynamic> catalogo, List<int> actual) {
    if (value is! List) return actual;
    final ids = <int>[];
    for (final item in value) {
      if (item is Map && item['aplica'] == false) continue;
      final id = item is Map
          ? _entero(item['id'] ?? item['id_momento'] ?? item['id_tipo_plato'] ?? item['tipo_plato_id'])
          : _entero(item);
      if (id != null) {
        ids.add(id);
        continue;
      }
      final nombre = item is Map
          ? (item['nombre'] ?? item['tipo_plato'] ?? item['nombre_visible'])?.toString().trim().toLowerCase()
          : item?.toString().trim().toLowerCase();
      if (nombre == null || nombre.isEmpty) continue;
      for (final opt in catalogo) {
        if (opt is Map && opt['nombre']?.toString().trim().toLowerCase() == nombre) {
          final optId = _entero(opt['id']);
          if (optId != null) ids.add(optId);
        }
      }
    }
    return ids.toSet().toList();
  }

  Future<List<Map<String, dynamic>>> _cargarCatalogoIngredientes() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      return List<Map<String, dynamic>>.from(await repo.fetchIngredientes());
    } catch (e) {
      debugPrint('No se pudo cargar catalogo de ingredientes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _cargarCatalogoEtiquetas() async {
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('nutricionista/etiquetas', queryParameters: {'q': ''});
      return List<Map<String, dynamic>>.from(resp.data);
    } catch (e) {
      debugPrint('No se pudo cargar catalogo de etiquetas: $e');
      return [];
    }
  }

  String _normalizarTextoBusqueda(dynamic value) {
    return value
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n') ?? '';
  }

  String _texto(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String _enteroTexto(dynamic value, {String fallback = '0'}) {
    return (_entero(value)?.toString()) ?? fallback;
  }

  int? _entero(dynamic value, {int? fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  double _decimal(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
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
                      key: ValueKey(_imagenUrl),
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
          Expanded(flex: 3, child: Text('Observaciones', style: _headerStyle())),
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
          Expanded(flex: 3, child: _buildRowInput(index, 'observaciones', maxLines: 2)),
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

  Widget _buildRowInput(int index, String key, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextFormField(
        initialValue: _ingredientes[index][key]?.toString(),
        key: ValueKey('ingrediente-$index-$key-${_ingredientes[index][key]}'),
        maxLines: maxLines,
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
                  key: ValueKey('paso-desc-$index-${p['descripcion']}'),
                  initialValue: p['descripcion'],
                  maxLines: 2,
                  decoration: _inputStyle('Instrucciones...'),
                  onChanged: (v) => _pasos[index]['descripcion'] = v,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextFormField(key: ValueKey('paso-tiempo-$index-${p['tiempo']}'), initialValue: p['tiempo'], decoration: _inputStyle('Tiempo'), onChanged: (v) => _pasos[index]['tiempo'] = v)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(key: ValueKey('paso-nota-$index-${p['nota']}'), initialValue: p['nota'], decoration: _inputStyle('Nota'), onChanged: (v) => _pasos[index]['nota'] = v)),
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
          if (_etiquetasSeleccionadas.isEmpty)
             Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Center(child: Text('No hay etiquetas seleccionadas.', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13, fontStyle: FontStyle.italic))),
            )
          else
            Wrap(
              spacing: 12, runSpacing: 12,
              children: _etiquetasSeleccionadas.map((e) => _buildTagChip(e)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tag_rounded, size: 14, color: AppTema.azulPrincipal),
          const SizedBox(width: 8),
          Text((e['titulo'] ?? e['nombre_visible'])?.toString() ?? '-', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _etiquetasSeleccionadas.remove(e)),
            child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.close_rounded, size: 12, color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildEtiquetaBuscador() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(hintText: 'Buscar etiquetas...', prefixIcon: const Icon(Icons.search_rounded, color: AppTema.azulPrincipal), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          onChanged: _buscarEtiquetas,
        ),
        if (_loadingEtiquetas) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
        if (_etiquetasBuscadas.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))]),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _etiquetasBuscadas.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade50, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final tag = _etiquetasBuscadas[index];
                final yaSeleccionada = _etiquetasSeleccionadas.any((e) => e['id'] == tag['id']);
                return ListTile(
                  dense: true,
                  leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: yaSeleccionada ? Colors.green.withOpacity(0.1) : Colors.grey.shade50, shape: BoxShape.circle), child: Icon(yaSeleccionada ? Icons.check_rounded : Icons.label_outline_rounded, size: 14, color: yaSeleccionada ? Colors.green : Colors.grey)),
                  title: Text(tag['nombre_visible'], style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
                  subtitle: Text(tag['codigo'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey.shade400)),
                  trailing: yaSeleccionada ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : IconButton(icon: const Icon(Icons.add_circle_rounded, color: AppTema.azulPrincipal, size: 24), onPressed: () { setState(() { _etiquetasSeleccionadas.add({'id': tag['id'], 'titulo': tag['nombre_visible'], 'nombre_visible': tag['nombre_visible']}); _etiquetasBuscadas = []; }); }),
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

  static const String _jsonEjemplo = '''
{
  "receta": {
    "nombre": "Batido de fresa",
    "descripcion": "Batido frío con fresa, yogur y avena.",
    "descripcion_larga": "Preparación fría y cremosa.",
    "dificultad": "Fácil",
    "porciones": 1,
    "tiempo_preparacion_min": 6,
    "tiempo_coccion_min": 0,
    "activa": true,
    "momentos_comida": [
      {"nombre": "Desayuno", "aplica": true}
    ],
    "tipos_plato": [
      {"tipo_plato": "Batido", "aplica": true}
    ],
    "ingredientes": [
      {
        "nombre": "Fresa",
        "cantidad_visual": "1/2",
        "unidad_visual": "taza",
        "peso_en_gramos": 75,
        "es_principal": true,
        "observaciones": "lavada y picada"
      }
    ],
    "preparacion": [
      {
        "numero_paso": 1,
        "descripcion": "Lavar bien las fresas.",
        "tiempo_estimado": 2,
        "nota_adicional": "Usar fruta fresca."
      }
    ],
    "etiquetas_salud_sugeridas": [
      {"etiqueta": "Alto poder antioxidante"}
    ]
  }
}
''';
}
