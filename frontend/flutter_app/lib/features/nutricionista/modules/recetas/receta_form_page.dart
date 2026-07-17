import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import 'dart:convert';
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
  static const Set<String> _codigosCriticosAmarillos = {
    'NO_APTO_DIABETICOS',
    'NO_APTO_INTOLERANCIA_FRUCTOSA',
    'NO_APTO_PARA_INTOLERANTES_A_LACTOSA',
    'NO_APTO_PARA_INTOLERANTES_AL_GLUTEN',
    'NO_APTO_PARA_INTOLERANTES_A_SULFITO',
    'NO_APTO_VEGETARIANOS',
  };

  static const Set<String> _codigosCriticosRojos = {
    'E9001_ALFALFA_L_CANAVANINA',
  };

  static const Map<String, String> _nombresCriticosAmigables = {
    'E9001_ALFALFA_L_CANAVANINA': 'LES: alfalfa / L-canavanina',
  };

  static const Map<String, List<String>> _patronesCriticosPorCodigo = {
    'NO_APTO_PARA_INTOLERANTES_A_LACTOSA': [
      'leche',
      'lacteo',
      'lacteos',
      'yogur',
      'queso',
      'nata',
      'crema',
      'mantequilla',
      'suero',
    ],
    'NO_APTO_PARA_INTOLERANTES_AL_GLUTEN': [
      'trigo',
      'cebada',
      'centeno',
      'cuscus',
      'couscous',
      'pasta',
      'galleta',
      'pan',
    ],
    'NO_APTO_INTOLERANCIA_FRUCTOSA': [
      'fructosa',
      'miel',
      'jarabe',
      'sirope',
      'manzana',
      'pera',
      'mango',
      'sandia',
      'sandía',
      'uva',
      'pasas',
      'higo',
      'datil',
      'dátil',
    ],
    'NO_APTO_PARA_INTOLERANTES_A_SULFITO': [
      'sulfito',
      'vino',
      'pasas',
      'fruta deshidratada',
      'frutos secos',
      'conserva',
      'encurtido',
      'vinagre',
    ],
    'E9001_ALFALFA_L_CANAVANINA': [
      'alfalfa',
      'l-canavanina',
      'l canavanina',
    ],
    'NO_APTO_VEGETARIANOS': [
      'carne',
      'pollo',
      'cerdo',
      'res',
      'ternera',
      'pescado',
      'atun',
      'atún',
      'marisco',
      'jamon',
      'jamón',
      'chorizo',
      'salami',
      'huevo',
      'gelatina',
    ],
    'NO_APTO_DIABETICOS': [
      'azucar',
      'azúcar',
      'panela',
      'miel',
      'jarabe',
      'sirope',
      'caramelo',
      'mermelada',
      'dulce de leche',
      'gaseosa',
      'refresco',
      'chocolate blanco',
      'chocolate con leche',
    ],
  };

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
  List<Map<String, dynamic>> _etiquetasSugeridas = [];
  final Set<int> _etiquetasDescartadas = {};
  final Map<int, List<Map<String, dynamic>>> _etiquetasIngredienteCache = {};

  // Catálogos
  List<dynamic> _momentosDisponibles = [];
  List<int> _momentosSeleccionados = [];
  List<dynamic> _tiposPlatoDisponibles = [];
  List<int> _tiposPlatoSeleccionados = [];
  List<Map<String, dynamic>>? _catalogoEtiquetasCache;

  // Búsqueda de Etiquetas
  List<dynamic> _etiquetasBuscadas = [];
  bool _loadingEtiquetas = false;
  bool _sugiriendoEtiquetas = false;

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
      final catalogos = await Future.wait([
        dio.get('crud/momentos'),
        dio.get('crud/tipos-plato'),
      ]);
      _momentosDisponibles = catalogos[0].data;
      _tiposPlatoDisponibles = catalogos[1].data;

      // 2. Cargar Receta si es edición
      final r = widget.recetaInicial;
      if (r != null) {
        _ctrlNombre.text = r['nombre'] ?? '';
        _ctrlDescCorta.text = r['descripcion'] ?? '';
        _ctrlDescLarga.text = r['descripcion_larga'] ?? '';
        _ctrlPorciones.text = (r['porciones'] ?? 1).toString();
        _ctrlTPrep.text =
            (r['tiempo_preparacion_min'] ?? r['tiempo_preparacion'] ?? 0)
                .toString();
        _ctrlTCoccion.text =
            (r['tiempo_coccion_min'] ?? r['tiempo_coccion'] ?? 0).toString();

        _dificultad = _normalizarDificultad(r['dificultad']);
        _activa = r['activa'] ?? true;
        _imagenUrl = r['imagen_url'];
        _ingredientes =
            List<Map<String, dynamic>>.from(r['ingredientes'] ?? []);
        _pasos = List<Map<String, dynamic>>.from(r['preparacion'] ?? []);
        _etiquetasSeleccionadas =
            List<Map<String, dynamic>>.from(r['etiquetas_salud'] ?? []);

        _momentosSeleccionados = _normalizarIdsSeleccionados(
          r['momentos'] ?? r['momentos_ids'],
          _momentosDisponibles,
          _momentosSeleccionados,
        );
        _tiposPlatoSeleccionados = _normalizarIdsSeleccionados(
          r['tipos_plato'] ?? r['tipos_plato_ids'],
          _tiposPlatoDisponibles,
          _tiposPlatoSeleccionados,
        );
      }

      if (_pasos.isEmpty) {
        _pasos.add({'paso': 1, 'descripcion': '', 'tiempo': '', 'nota': ''});
      }

      if (_ingredientes.isNotEmpty || _etiquetasSeleccionadas.isNotEmpty) {
        await _actualizarSugerenciasDesdeIngredientes(
          extras: _etiquetasSeleccionadas,
        );
      }
    } catch (e) {
      debugPrint("Error inicializando formulario: $e");
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? picked =
        await RecipeImageService.pickImage(ImageSource.gallery);
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
      final resp =
          await dio.get('nutricionista/etiquetas', queryParameters: {'q': q});
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
    final ingredientesSinId =
        _ingredientes.where((ing) => ing['id_ingrediente'] == null).length;
    if (ingredientesSinId > 0) {
      NutriSnack.show(
        context,
        'Hay $ingredientesSinId ingrediente(s) sin coincidencia en el catálogo. Elimínalos y agrégalos con el selector antes de guardar.',
        isError: true,
      );
      return;
    }

    final etiquetasValidadas =
        await _validarEtiquetasConfirmadasContraCatalogo();
    if (etiquetasValidadas == null) return;

    setState(() => _loading = true);
    try {
      String? finalImageUrl = _imagenUrl;

      // 1. Manejo de subida física si se seleccionó un archivo
      if (_imageFile != null) {
        setState(() => _uploadingImage = true);
        try {
          finalImageUrl = await RecipeImageService.uploadRecipeImage(
            imageFile: _imageFile!,
            fileName: 'receta_${DateTime.now().millisecondsSinceEpoch}.webp',
          );
        } catch (e) {
          if (mounted) {
            NutriSnack.show(context, 'Error al subir imagen: $e',
                isError: true);
          }
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
        'etiquetas_salud': etiquetasValidadas,
        'momentos': _momentosSeleccionados,
        'tipos_plato': _tiposPlatoSeleccionados,
      };

      final dio = ref.read(dioProvider);
      await dio.post('crud/recetas', data: payload);

      if (!mounted) return;
      NutriSnack.show(context, 'Receta guardada con éxito');
      widget.onBack();
    } catch (e) {
      await _manejarErrorGuardar(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _manejarErrorGuardar(Object error) async {
    final motivos = _motivosBloqueoClinico(error);
    if (motivos != null && mounted) {
      await _mostrarBloqueoClinico(motivos);
      return;
    }
    if (mounted) {
      NutriSnack.show(context, _mensajeErrorGuardar(error), isError: true);
    }
  }

  List<String>? _motivosBloqueoClinico(Object error) {
    try {
      final dynamic data = (error as dynamic).response?.data;
      if (data is! Map) return null;
      final detail = data['detail'];
      if (detail is! Map) return null;
      if (detail['estado']?.toString() != 'NO_APTA_REUMATICA') return null;
      final motivos = detail['motivos'];
      if (motivos is! List) {
        return [
          'Esta receta no es apta para el filtro clinico base reumatico.'
        ];
      }
      final salida = motivos
          .map((m) => m?.toString().trim() ?? '')
          .where((m) => m.isNotEmpty)
          .toList();
      return salida.isEmpty
          ? ['Esta receta no es apta para el filtro clinico base reumatico.']
          : salida;
    } catch (_) {
      return null;
    }
  }

  Future<void> _mostrarBloqueoClinico(List<String> motivos) async {
    final accion = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.health_and_safety_outlined,
                color: Color(0xFFB45309)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Receta no apta',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta receta no se puede guardar porque contiene un ingrediente o grupo bloqueado por el filtro clinico base reumatico.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.blueGrey.shade700),
              ),
              const SizedBox(height: 16),
              ...motivos.map(
                (motivo) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          motivo,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTema.azulOscuro,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'descartar'),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'modificar'),
            child: const Text('Modificar receta'),
          ),
        ],
      ),
    );

    if (accion == 'descartar' && mounted) {
      widget.onBack();
    }
  }

  String _mensajeErrorGuardar(Object error) {
    try {
      final dynamic data = (error as dynamic).response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          final motivos = detail['motivos'];
          if (motivos is List && motivos.isNotEmpty) {
            return 'No se puede guardar: ${motivos.join(' | ')}';
          }
          final estado = detail['estado'];
          if (estado != null) return 'No se puede guardar: $estado';
        }
        if (detail is String && detail.trim().isNotEmpty) return detail;
      }
    } catch (_) {}
    return 'Error al guardar: $error';
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
          widget.recetaInicial == null ? 'Nueva receta' : 'Editar receta',
          style: GoogleFonts.montserrat(
              color: AppTema.azulOscuro,
              fontWeight: FontWeight.w800,
              fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: _abrirImportadorJson,
              icon: const Icon(Icons.data_object_rounded, size: 18),
              label: const Text('Código JSON'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTema.azulPrincipal,
                side: const BorderSide(color: AppTema.azulPrincipal),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: (_loading || _initializing)
          ? Center(
              child: NutriLoading(
                  mensaje: _initializing
                      ? 'Cargando catálogos...'
                      : 'Procesando recetario...'))
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
          _buildTituloSeccion('Información básica'),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePicker(),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    _buildInputField(
                        'Nombre de la receta *', _ctrlNombre, true),
                    const SizedBox(height: 20),
                    _buildInputField('Descripción corta (para la tarjeta) *',
                        _ctrlDescCorta, true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInputField(
              'Descripción detallada (terapéutica)', _ctrlDescLarga, true,
              maxLines: 3),
          const SizedBox(height: 24),
          _buildMultiSelect('Momentos de comida', _momentosDisponibles,
              _momentosSeleccionados),
          const SizedBox(height: 20),
          _buildMultiSelect('Tipos de plato', _tiposPlatoDisponibles,
              _tiposPlatoSeleccionados),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildDropdown(
                      'Dificultad *',
                      ['Fácil', 'Media', 'Difícil'],
                      _dificultad,
                      (v) => setState(() => _dificultad = v!))),
              const SizedBox(width: 20),
              Expanded(
                  child: _buildInputField('Porciones *', _ctrlPorciones, false,
                      isNumber: true)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildInputField(
                      'Tiempo de preparación (min) *', _ctrlTPrep, false,
                      isNumber: true)),
              const SizedBox(width: 20),
              Expanded(
                  child: _buildInputField(
                      'Tiempo de cocción (min)', _ctrlTCoccion, false,
                      isNumber: true)),
            ],
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _activa,
            onChanged: (v) => setState(() => _activa = v!),
            title: Text('Receta activa y visible para planificación',
                style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTema.azulOscuro)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppTema.azulPrincipal,
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelect(
      String label, List<dynamic> options, List<int> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12)),
          child: Wrap(
            spacing: 8,
            children: options.map((opt) {
              final bool isSelected = selected.contains(opt['id']);
              return FilterChip(
                label: Text(opt['nombre'],
                    style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.blueGrey)),
                selected: isSelected,
                selectedColor: AppTema.azulPrincipal,
                onSelected: (val) {
                  setState(() {
                    if (val)
                      selected.add(opt['id']);
                    else
                      selected.remove(opt['id']);
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
        return 'Fácil';
      case 'dificil':
      case 'difícil':
      case 'difã­cil':
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
            Text('Código JSON',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
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
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.blueGrey.shade700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ctrl.text = _jsonEjemplo,
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Usar estructura'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => ctrl.clear(),
                      icon: const Icon(Icons.cleaning_services_outlined,
                          size: 18),
                      label: const Text('Limpiar'),
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
                    helperText:
                        'Puedes pegar tu JSON completo aquí. También se acepta que venga dentro de { "receta": ... }.',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, ctrl.text),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Aceptar'),
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
        NutriSnack.show(context, 'El JSON debe ser un objeto de receta.',
            isError: true);
        return;
      }
      final decoded = root['receta'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(root['receta'] as Map)
          : root;

      final ingredientes = _listaMapas(decoded['ingredientes']);
      final pasos = _listaMapas(decoded['preparacion'] ?? decoded['pasos']);
      final etiquetas = _listaMapas(decoded['etiquetas_salud'] ??
          decoded['etiquetas'] ??
          decoded['etiquetas_salud_sugeridas']);
      final ingredientesNormalizados =
          await _normalizarIngredientesJson(ingredientes);
      final etiquetasNormalizadas = await _normalizarEtiquetasJson(etiquetas);

      setState(() {
        _ctrlNombre.text =
            _texto(decoded['nombre'], fallback: _ctrlNombre.text);
        _ctrlDescCorta.text = _texto(
            decoded['descripcion'] ?? decoded['descripcion_corta'],
            fallback: _ctrlDescCorta.text);
        _ctrlDescLarga.text =
            _texto(decoded['descripcion_larga'], fallback: _ctrlDescLarga.text);
        _ctrlPorciones.text =
            _enteroTexto(decoded['porciones'], fallback: _ctrlPorciones.text);
        _ctrlTPrep.text = _enteroTexto(
            decoded['tiempo_preparacion'] ?? decoded['tiempo_preparacion_min'],
            fallback: _ctrlTPrep.text);
        _ctrlTCoccion.text = _enteroTexto(
            decoded['tiempo_coccion'] ?? decoded['tiempo_coccion_min'],
            fallback: _ctrlTCoccion.text);
        if (decoded.containsKey('dificultad'))
          _dificultad = _normalizarDificultad(decoded['dificultad']);
        _activa =
            decoded['activa'] is bool ? decoded['activa'] as bool : _activa;
        _imagenUrl = _texto(decoded['imagen_url'], fallback: _imagenUrl ?? '');
        if (_imagenUrl != null && _imagenUrl!.isEmpty) {
          _imagenUrl = null;
        }
        _imageFile = null;
        _imagePreviewBytes = null;

        if (ingredientesNormalizados.isNotEmpty) {
          _ingredientes = ingredientesNormalizados;
        }
        if (pasos.isNotEmpty) {
          _pasos = pasos
              .asMap()
              .entries
              .map((entry) => _normalizarPasoJson(entry.key, entry.value))
              .toList();
        }
        _agregarEtiquetasSugeridas(etiquetasNormalizadas);

        _momentosSeleccionados = _normalizarIdsSeleccionados(
            decoded['momentos'] ?? decoded['momentos_comida'],
            _momentosDisponibles,
            _momentosSeleccionados);
        _tiposPlatoSeleccionados = _normalizarIdsSeleccionados(
            decoded['tipos_plato'],
            _tiposPlatoDisponibles,
            _tiposPlatoSeleccionados);
      });
      await _actualizarSugerenciasDesdeIngredientes(
        extras: etiquetasNormalizadas,
      );

      final sinId = ingredientesNormalizados
          .where((ing) => ing['id_ingrediente'] == null)
          .length;
      final etiquetasSinId =
          etiquetasNormalizadas.where((etq) => etq['id'] == null).length;
      if (!mounted) return;
      NutriSnack.show(
        context,
        sinId == 0 && etiquetasSinId == 0
            ? 'JSON cargado. Puedes editar la información y guardar.'
            : 'JSON cargado. Revisa $sinId ingrediente(s) y $etiquetasSinId etiqueta(s) sin coincidencia en catálogo.',
        isError: sinId > 0 || etiquetasSinId > 0,
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      NutriSnack.show(context, 'JSON inválido: ${e.message}', isError: true);
    } catch (e) {
      if (!mounted) return;
      NutriSnack.show(context, 'No se pudo cargar el JSON: $e', isError: true);
    }
  }

  List<Map<String, dynamic>> _listaMapas(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _normalizarIngredientesJson(
      List<Map<String, dynamic>> ingredientes) async {
    if (ingredientes.isEmpty) return [];
    final catalogo = await _cargarCatalogoIngredientes();
    final porNombre = {
      for (final ing in catalogo) _normalizarTextoBusqueda(ing['nombre']): ing,
    };

    return ingredientes.map((item) {
      final nombre = _texto(item['nombre'] ?? item['ingrediente'],
          fallback: 'Ingrediente');
      final match = porNombre[_normalizarTextoBusqueda(nombre)];
      return {
        'id_ingrediente': _entero(item['id_ingrediente'] ?? item['id']) ??
            _entero(match?['id']),
        'nombre': match?['nombre']?.toString() ?? nombre,
        'cantidad':
            _decimal(item['cantidad'] ?? item['cantidad_visual'], fallback: 1),
        'unidad':
            _texto(item['unidad'] ?? item['unidad_visual'], fallback: 'unidad'),
        'gramos': _decimal(
            item['gramos'] ?? item['peso_gramos'] ?? item['peso_en_gramos'],
            fallback: 0),
        'observaciones': _texto(item['observaciones'], fallback: ''),
        'es_principal': item['es_principal'] == true,
      };
    }).toList();
  }

  Map<String, dynamic> _normalizarPasoJson(
      int index, Map<String, dynamic> item) {
    return {
      'paso': _entero(item['paso'] ?? item['numero_paso'], fallback: index + 1),
      'descripcion':
          _texto(item['descripcion'] ?? item['instruccion'], fallback: ''),
      'tiempo': _texto(item['tiempo'] ?? item['tiempo_estimado'], fallback: ''),
      'nota': _texto(item['nota'] ?? item['nota_adicional'], fallback: ''),
    };
  }

  Map<String, dynamic> _normalizarEtiquetaJson(Map<String, dynamic> item) {
    final id = _entero(item['id'] ?? item['id_etiqueta']);
    final nombre = _texto(
        item['titulo'] ??
            item['nombre_visible'] ??
            item['nombre'] ??
            item['etiqueta'],
        fallback: '');
    if (id == null && nombre.isEmpty) return {};
    return {
      if (id != null) 'id': id,
      'titulo': nombre,
      'nombre_visible': nombre,
      if (item['codigo'] != null) 'codigo': item['codigo'],
    };
  }

  Future<List<Map<String, dynamic>>> _normalizarEtiquetasJson(
      List<Map<String, dynamic>> etiquetas) async {
    if (etiquetas.isEmpty) return [];
    final catalogo = await _cargarCatalogoEtiquetas();
    final porNombre = {
      for (final etq in catalogo)
        _normalizarTextoBusqueda(
            etq['nombre_visible'] ?? etq['titulo'] ?? etq['nombre']): etq,
    };

    return etiquetas
        .map((item) {
          final base = _normalizarEtiquetaJson(item);
          if (base.isEmpty) return base;
          final nombre =
              _texto(base['titulo'] ?? item['etiqueta'], fallback: '');
          final id = _entero(base['id']);
          final match = catalogo.cast<Map<String, dynamic>?>().firstWhere(
                (etq) => _entero(etq?['id']) == id,
                orElse: () => porNombre[_normalizarTextoBusqueda(nombre)],
              );
          return match == null
              ? <String, dynamic>{}
              : _normalizarEtiquetaCatalogo(match);
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<int> _normalizarIdsSeleccionados(
      dynamic value, List<dynamic> catalogo, List<int> actual) {
    if (value is! List) return actual;
    final ids = <int>[];
    for (final item in value) {
        if (item is Map && item['aplica'] == false) {
          continue;
        }
      final id = item is Map
          ? _entero(item['id'] ??
              item['id_momento'] ??
              item['id_tipo_plato'] ??
              item['tipo_plato_id'])
          : _entero(item);
      if (id != null) {
        ids.add(id);
        continue;
      }
      final nombre = item is Map
          ? (item['nombre'] ??
                  item['tipo_plato'] ??
                  item['momento'] ??
                  item['momento_comida'] ??
                  item['nombre_visible'])
              ?.toString()
              .trim()
          : item?.toString().trim();
      if (nombre == null || nombre.isEmpty) {
        continue;
      }
      final nombreNormalizado = _normalizarTextoBusqueda(nombre);
      for (final opt in catalogo) {
        if (opt is Map &&
            _normalizarTextoBusqueda(opt['nombre']) == nombreNormalizado) {
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
    if (_catalogoEtiquetasCache != null) return _catalogoEtiquetasCache!;
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('nutricionista/etiquetas', queryParameters: {'q': '', 'limit': 1000});
      _catalogoEtiquetasCache = List<Map<String, dynamic>>.from(resp.data);
      return _catalogoEtiquetasCache!;
    } catch (e) {
      debugPrint('No se pudo cargar catalogo de etiquetas: $e');
      return [];
    }
  }

  Map<String, dynamic> _normalizarEtiquetaCatalogo(Map<String, dynamic> etq) {
    final codigo = etq['codigo']?.toString() ?? '';
    final nombreVisible = _nombreAmigableEtiqueta(
      codigo,
      etq['nombre_visible']?.toString() ??
          etq['titulo']?.toString() ??
          etq['nombre']?.toString() ??
          '',
    );
    return {
      'id': _entero(etq['id'] ?? etq['id_etiqueta']),
      'titulo': nombreVisible,
      'nombre_visible': nombreVisible,
      'codigo': codigo,
    };
  }

  String _nombreAmigableEtiqueta(String codigo, String fallback) {
    final normalizado = _normalizarCodigoEtiqueta(codigo);
    return _nombresCriticosAmigables[normalizado] ?? fallback;
  }

  Future<List<Map<String, dynamic>>?>
      _validarEtiquetasConfirmadasContraCatalogo() async {
    final catalogo = await _cargarCatalogoEtiquetas();
    if (catalogo.isEmpty && _etiquetasSeleccionadas.isNotEmpty) {
      if (!mounted) return null;
      NutriSnack.show(
        context,
        'No se pudo validar el catálogo de etiquetas. Intenta guardar nuevamente.',
        isError: true,
      );
      return null;
    }

    final idsCatalogo = {
      for (final etq in catalogo) _entero(etq['id'] ?? etq['id_etiqueta'])
    }..remove(null);
    final validadas = <Map<String, dynamic>>[];
    final invalidas = <Map<String, dynamic>>[];

    for (final etiqueta in _etiquetasSeleccionadas) {
      final id = _entero(etiqueta['id']);
      if (id == null || !idsCatalogo.contains(id)) {
        invalidas.add(etiqueta);
        continue;
      }
      final catalogoItem = catalogo
          .firstWhere((etq) => _entero(etq['id'] ?? etq['id_etiqueta']) == id);
      validadas.add(_normalizarEtiquetaCatalogo(catalogoItem));
    }

    if (invalidas.isNotEmpty) {
      setState(() {
        _etiquetasSeleccionadas = validadas;
      });
      if (!mounted) return null;
      NutriSnack.show(
        context,
        'Se retiraron ${invalidas.length} etiqueta(s) fuera del catálogo backend. Revisa y guarda nuevamente.',
        isError: true,
      );
      return null;
    }

    return validadas;
  }

  void _agregarEtiquetasSugeridas(List<Map<String, dynamic>> etiquetas) {
    for (final etiqueta in etiquetas) {
      final id = _entero(etiqueta['id']);
      if (id == null) continue;
      if (_etiquetasDescartadas.contains(id)) continue;
      final yaSeleccionada =
          _etiquetasSeleccionadas.any((actual) => _entero(actual['id']) == id);
      if (!yaSeleccionada) {
        _etiquetasSeleccionadas.add(etiqueta);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _cargarEtiquetasIngrediente(
      int idIngrediente) async {
    final cache = _etiquetasIngredienteCache[idIngrediente];
    if (cache != null) return cache;
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('nutricionista/ingredientes/$idIngrediente');
      final data = resp.data;
      if (data is! Map || data['etiquetas'] is! List) return [];
      final etiquetas = List<Map<String, dynamic>>.from(data['etiquetas'])
          .map(_normalizarEtiquetaCatalogo)
          .where((etq) => _entero(etq['id']) != null)
          .toList();
      _etiquetasIngredienteCache[idIngrediente] = etiquetas;
      return etiquetas;
    } catch (e) {
      debugPrint("Error al sugerir etiquetas por ingrediente: $e");
      return [];
    }
  }

  Future<void> _actualizarSugerenciasDesdeIngredientes({
    List<Map<String, dynamic>> extras = const [],
  }) async {
    final ids = _ingredientes
        .map((ing) => _entero(ing['id_ingrediente']))
        .whereType<int>()
        .toSet()
        .toList();
    if (ids.isEmpty && extras.isEmpty) {
      if (mounted) setState(() => _etiquetasSugeridas = []);
      return;
    }

    if (mounted) setState(() => _sugiriendoEtiquetas = true);
    final catalogoEtiquetas = await _cargarCatalogoEtiquetas();
    final etiquetasCatalogoPorCodigo = <String, Map<String, dynamic>>{
      for (final etq in catalogoEtiquetas)
        _normalizarCodigoEtiqueta(etq['codigo'] ??
            etq['titulo'] ??
            etq['nombre_visible'] ??
            etq['nombre']): _normalizarEtiquetaCatalogo(etq),
    };

    final sugeridas = <Map<String, dynamic>>[...extras];
    final etiquetasPorIngrediente = await Future.wait(
      ids.map(_cargarEtiquetasIngrediente),
    );
    for (final lista in etiquetasPorIngrediente) {
      sugeridas.addAll(lista);
    }

    sugeridas.addAll(
      _etiquetasCriticasLocalesDesdeIngredientes(
        etiquetasCatalogoPorCodigo: etiquetasCatalogoPorCodigo,
      ),
    );

    if (!mounted) return;
    setState(() {
      _etiquetasSugeridas = [];
      _agregarEtiquetasSugeridas(sugeridas);
      _sugiriendoEtiquetas = false;
    });
  }

  void _confirmarEtiqueta(Map<String, dynamic> etiqueta) {
    final id = _entero(etiqueta['id']);
    if (id == null) return;
    setState(() {
      _etiquetasDescartadas.remove(id);
      if (!_etiquetasSeleccionadas
          .any((actual) => _entero(actual['id']) == id)) {
        _etiquetasSeleccionadas.add(etiqueta);
      }
      _etiquetasSugeridas.removeWhere((actual) => _entero(actual['id']) == id);
    });
  }

  List<Map<String, dynamic>> _etiquetasCriticasLocalesDesdeIngredientes({
    required Map<String, Map<String, dynamic>> etiquetasCatalogoPorCodigo,
  }) {
    final textosIngredientes = _ingredientes
        .map((ing) => [
              ing['nombre'],
              ing['nombre_ingrediente'],
              ing['subgrupo_nombre'],
              ing['categoria'],
              ing['grupo_nombre'],
            ].map(_normalizarTextoBusqueda).join(' '))
        .where((txt) => txt.trim().isNotEmpty)
        .join(' | ');

    if (textosIngredientes.isEmpty) return [];

    final resultado = <Map<String, dynamic>>[];
    for (final entry in _patronesCriticosPorCodigo.entries) {
      final codigo = entry.key;
      if (!_codigosCriticosAmarillos.contains(codigo) &&
          !_codigosCriticosRojos.contains(codigo)) {
        continue;
      }
      final catalogoEtiqueta = etiquetasCatalogoPorCodigo[codigo];
      if (catalogoEtiqueta == null) continue;

      final patrones = entry.value
          .map(_normalizarTextoBusqueda)
          .where((p) => p.isNotEmpty)
          .toList();
      final coincide =
          patrones.any((patron) => textosIngredientes.contains(patron));
      if (coincide) {
        resultado.add(catalogoEtiqueta);
      }
    }
    return resultado;
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
            .replaceAll('ñ', 'n') ??
        '';
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
    final tieneImagen = _imagePreviewBytes != null ||
        (_imagenUrl != null && _imagenUrl!.isNotEmpty);

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
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _imagePreviewBytes != null
                ? Image.memory(_imagePreviewBytes!,
                    fit: BoxFit.cover, width: 240, height: 180)
                : (_imagenUrl != null && _imagenUrl!.isNotEmpty
                    ? Image.network(
                        _imagenUrl!,
                        fit: BoxFit.cover,
                        width: 240,
                        height: 180,
                        key: ValueKey(_imagenUrl),
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderContent(),
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
              label: Text(tieneImagen ? 'Cambiar' : 'Subir imagen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTema.azulPrincipal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (tieneImagen) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _quitarImagen,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Colors.redAccent),
                label: const Text('Quitar',
                    style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
        Icon(Icons.image_not_supported_outlined,
            color: Colors.grey.shade300, size: 48),
        const SizedBox(height: 12),
        Text('Sin imagen seleccionada',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500)),
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
              _buildTituloSeccion(
                  'Gestión de ingredientes (${_ingredientes.length})'),
              FilledButton.icon(
                onPressed: _abrirSelectorIngrediente,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar ingrediente'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTema.azulPrincipal,
                    padding: const EdgeInsets.symmetric(horizontal: 16)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_ingredientes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(
                  'No hay ingredientes. Agrega al menos uno para calcular la nutrición.',
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic)),
            )
          else
            Column(
              children: [
                _buildTableHeaderIngredienteRow(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ingredientes.length,
                  itemBuilder: (context, index) =>
                      _buildRowIngredienteItem(index),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderIngredienteRow() {
    return Container(
      color: AppTema.azulPrincipal,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: _headerText('Ingrediente')),
          Expanded(flex: 2, child: _headerText('Cantidad')),
          Expanded(flex: 2, child: _headerText('Unidad')),
          Expanded(flex: 2, child: _headerText('Gramos')),
          Expanded(flex: 3, child: _headerText('Observaciones')),
          Expanded(flex: 2, child: Center(child: _headerText('Principal'))),
          SizedBox(width: 80, child: Center(child: _headerText('Acciones'))),
        ],
      ),
    );
  }

  Widget _headerText(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white));

  Widget _buildRowIngredienteItem(int index) {
    final ing = _ingredientes[index];
    final bool isEven = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF1F5F9),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(ing['nombre'] ?? '-',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B))),
              )),
          Expanded(flex: 2, child: _buildRowInput(index, 'cantidad')),
          Expanded(flex: 2, child: _buildRowInput(index, 'unidad')),
          Expanded(
              flex: 2, child: _buildRowInput(index, 'gramos', isNumber: true)),
          Expanded(
              flex: 3,
              child: _buildRowInput(index, 'observaciones', maxLines: 2)),
          Expanded(
            flex: 2,
            child: Center(
              child: Switch(
                value: ing['es_principal'] == true,
                activeColor: AppTema.verdeSalud,
                onChanged: (v) {
                  setState(() => _ingredientes[index]['es_principal'] = v);
                },
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.redAccent, size: 18),
              onPressed: () {
                setState(() => _ingredientes.removeAt(index));
                _actualizarSugerenciasDesdeIngredientes();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowInput(int index, String key,
      {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextFormField(
        initialValue: _ingredientes[index][key]?.toString(),
        key: ValueKey('ingrediente-$index-$key-${_ingredientes[index][key]}'),
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: _inputStyle(''),
        onChanged: (v) => _ingredientes[index][key] =
            isNumber ? (double.tryParse(v) ?? 0) : v,
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
                onPressed: () => setState(() => _pasos.add({
                      'paso': _pasos.length + 1,
                      'descripcion': '',
                      'tiempo': '',
                      'nota': ''
                    })),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Añadir paso'),
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
          CircleAvatar(
              radius: 14,
              backgroundColor: AppTema.azulPrincipal,
              child: Text('${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12))),
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
                    Expanded(
                        child: TextFormField(
                            key: ValueKey('paso-tiempo-$index-${p['tiempo']}'),
                            initialValue: p['tiempo'],
                            decoration: _inputStyle('Tiempo'),
                            onChanged: (v) => _pasos[index]['tiempo'] = v)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextFormField(
                            key: ValueKey('paso-nota-$index-${p['nota']}'),
                            initialValue: p['nota'],
                            decoration: _inputStyle('Nota'),
                            onChanged: (v) => _pasos[index]['nota'] = v)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () =>
                            setState(() => _pasos.removeAt(index))),
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
          const SizedBox(height: 16),
          _buildAdvertenciaClinicaEtiquetas(),
          const SizedBox(height: 8),
          Text(
              'Las etiquetas sugeridas se agregan automaticamente. Quita con la x las que no correspondan antes de guardar.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 24),
          _buildEtiquetaBuscador(),
          const SizedBox(height: 24),
          if (_sugiriendoEtiquetas) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 24),
          ],
          if (_etiquetasSeleccionadas.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Center(
                  child: Text('No hay etiquetas seleccionadas.',
                      style: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                          fontStyle: FontStyle.italic))),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  _etiquetasSeleccionadas.map((e) => _buildTagChip(e)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAdvertenciaClinicaEtiquetas() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_outlined,
              color: Color(0xFFB45309), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'advertencia clínica: revisa si falta o están demás estas etiquetas críticas: no_apto_intolerancia_fructosa, no_apto_para_intolerantes_a_lactosa, no_apto_para_intolerantes_al_gluten, no_apto_para_intolerantes_a_sulfito, no_apto_vegetarianos.',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF78350F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> e) {
    final isRoja = _isEtiquetaCriticaRoja(e);
    final isAlerta = !isRoja && _isEtiquetaAlertaIntolerancia(e);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: isRoja
              ? const Color(0xFFFFD6D6)
              : (isAlerta ? const Color(0xFFFFF8E1) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isRoja
                  ? const Color(0xFFD32F2F)
                  : (isAlerta
                      ? const Color(0xFFF6C453)
                      : const Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRoja
                ? Icons.dangerous_rounded
                : (isAlerta ? Icons.warning_amber_rounded : Icons.tag_rounded),
            size: 14,
            color: isRoja
                ? const Color(0xFFB71C1C)
                : (isAlerta ? const Color(0xFF9A6700) : AppTema.azulPrincipal),
          ),
          const SizedBox(width: 8),
          Text(_textoEtiquetaVisible(e),
              style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isRoja
                      ? const Color(0xFFB71C1C)
                      : (isAlerta
                          ? const Color(0xFF7A5200)
                          : AppTema.azulOscuro))),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              final id = _entero(e['id']);
              setState(() {
                if (id != null) _etiquetasDescartadas.add(id);
                _etiquetasSeleccionadas.remove(e);
              });
            },
            child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  bool _isEtiquetaAlertaIntolerancia(Map<String, dynamic> etiqueta) {
    if (_isEtiquetaCriticaRoja(etiqueta)) return false;
    final valores = [
      etiqueta['codigo'],
      etiqueta['titulo'],
      etiqueta['nombre_visible'],
      etiqueta['nombre'],
    ].map(_normalizarCodigoEtiqueta).where((v) => v.isNotEmpty);

    return valores.any((valor) => _codigosCriticosAmarillos.any(
        (codigoCritico) =>
            valor == codigoCritico || valor.contains(codigoCritico)));
  }

  bool _isEtiquetaCriticaRoja(Map<String, dynamic> etiqueta) {
    final id = _entero(etiqueta['id']);
    if (id == 9001) return true;
    final valores = [
      etiqueta['codigo'],
      etiqueta['titulo'],
      etiqueta['nombre_visible'],
      etiqueta['nombre'],
    ].map(_normalizarCodigoEtiqueta).where((v) => v.isNotEmpty);

    return valores.any((valor) =>
        _codigosCriticosRojos.any((codigoCritico) =>
            valor == codigoCritico || valor.contains(codigoCritico)) ||
        valor.contains('ALFALFA') ||
        valor.contains('L_CANAVANINA'));
  }

  String _textoEtiquetaVisible(Map<String, dynamic> etiqueta) {
    final codigo = _normalizarCodigoEtiqueta(etiqueta['codigo']);
    if (_nombresCriticosAmigables.containsKey(codigo)) {
      return _nombresCriticosAmigables[codigo]!;
    }
    return (etiqueta['titulo'] ??
                etiqueta['nombre_visible'] ??
                etiqueta['nombre'])
            ?.toString() ??
        '-';
  }

  String _normalizarCodigoEtiqueta(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toUpperCase()
            .replaceAll('Á', 'A')
            .replaceAll('É', 'E')
            .replaceAll('Í', 'I')
            .replaceAll('Ó', 'O')
            .replaceAll('Ú', 'U')
            .replaceAll('Ñ', 'N')
            .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .replaceAll(RegExp(r'^_|_$'), '') ??
        '';
  }

  Widget _buildEtiquetaBuscador() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
              hintText: 'Buscar etiquetas...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppTema.azulPrincipal),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none)),
          onChanged: _buscarEtiquetas,
        ),
        if (_loadingEtiquetas)
          const Padding(
              padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
        if (_etiquetasBuscadas.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ]),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _etiquetasBuscadas.length,
              separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey.shade50,
                  indent: 16,
                  endIndent: 16),
              itemBuilder: (context, index) {
                final tag = _etiquetasBuscadas[index];
                final yaSeleccionada =
                    _etiquetasSeleccionadas.any((e) => e['id'] == tag['id']);
                return ListTile(
                  dense: true,
                  leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: yaSeleccionada
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.shade50,
                          shape: BoxShape.circle),
                      child: Icon(
                          yaSeleccionada
                              ? Icons.check_rounded
                              : Icons.label_outline_rounded,
                          size: 14,
                          color: yaSeleccionada ? Colors.green : Colors.grey)),
                  title: Text(tag['nombre_visible'],
                      style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTema.azulOscuro)),
                  subtitle: Text(tag['codigo'] ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.blueGrey.shade400)),
                  trailing: yaSeleccionada
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 20)
                      : IconButton(
                          icon: const Icon(Icons.add_circle_rounded,
                              color: AppTema.azulPrincipal, size: 24),
                          onPressed: () {
                            _confirmarEtiqueta(_normalizarEtiquetaCatalogo(
                                Map<String, dynamic>.from(tag)));
                            setState(() => _etiquetasBuscadas = []);
                          }),
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
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: child,
    );
  }

  Widget _buildTituloSeccion(String t) {
    return Text(t,
        style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTema.azulOscuro));
  }

  Widget _buildInputField(
      String label, TextEditingController ctrl, bool fullWidth,
      {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: _inputStyle(''),
            validator: (v) =>
                v!.isEmpty && label.contains('*') ? 'Campo requerido' : null),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> options, String value,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
            value: value,
            items: options
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
            decoration: _inputStyle('')),
      ],
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(16));
  }

  Widget _buildFooterFeedback() {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppTema.pastelCeleste.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: AppTema.azulPrincipal),
          const SizedBox(width: 16),
          Expanded(
              child: Text(
                  'La composición nutricional de la receta se calculará automáticamente basándose en los ingredientes y pesos seleccionados.',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTema.azulOscuro,
                      fontWeight: FontWeight.w500)))
        ]));
  }

  Widget _buildAccionesFinales() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      OutlinedButton(onPressed: widget.onBack, child: const Text('Cancelar')),
      const SizedBox(width: 16),
      FilledButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.save_rounded),
          label: Text(widget.recetaInicial == null
              ? 'Crear receta'
              : 'Actualizar receta'))
    ]);
  }

  void _abrirSelectorIngrediente() async {
    final List<Map<String, dynamic>>? seleccion =
        await showDialog<List<Map<String, dynamic>>>(
            context: context,
            builder: (context) => const SelectorIngredienteDialog());

    if (seleccion != null) {
      setState(() {
        _ingredientes.addAll(seleccion);
      });
      await _actualizarSugerenciasDesdeIngredientes();
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
