import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';

class IngredienteFormPage extends ConsumerStatefulWidget {
  final int? idIngrediente;
  final VoidCallback onBack;

  const IngredienteFormPage({
    super.key,
    this.idIngrediente,
    required this.onBack,
  });

  @override
  ConsumerState<IngredienteFormPage> createState() =>
      _IngredienteFormPageState();
}

class _IngredienteFormPageState extends ConsumerState<IngredienteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _factorCtrl;
  final Map<String, TextEditingController> _composicionCtrls = {};
  final Map<String, FocusNode> _focusNodes = {};

  int? _idGrupo;
  int? _idSubgrupo;
  List<dynamic> _grupos = [];
  List<dynamic> _subgroups = [];
  List<dynamic> _subgroupsFiltrados = [];
  List<dynamic> _etiquetasCatalog = [];
  List<int> _etiquetasSeleccionadas = [];
  List<dynamic> _etiquetasFiltradas = [];
  final TextEditingController _tagSearchCtrl = TextEditingController();

  bool _loading = false;
  bool _initializing = false;

  final List<String> _secciones = [
    "MACRONUTRIENTES Y GENERAL",
    "AZÚCARES Y ALMIDÓN",
    "DETALLE DE GRASAS",
    "VITAMINAS",
    "MINERALES",
    "OTROS"
  ];
  String _seccionActual = "MACRONUTRIENTES Y GENERAL";

  final Map<String, List<Map<String, dynamic>>> _camposPorSeccion = {
    "MACRONUTRIENTES Y GENERAL": [
      {
        "label": "Energía (kcal)",
        "key": "energia_kcal",
        "icon": Icons.bolt_rounded
      },
      {"label": "Agua (g)", "key": "agua_g", "icon": Icons.water_drop_outlined},
      {
        "label": "Proteínas (g)",
        "key": "proteinas_g",
        "icon": Icons.fitness_center_rounded
      },
      {
        "label": "Grasas Totales (g)",
        "key": "grasa_total_g",
        "icon": Icons.water_drop_rounded
      },
      {
        "label": "Carbohidratos (g)",
        "key": "hidratos_carbono_g",
        "icon": Icons.bakery_dining_rounded
      },
      {
        "label": "Fibra (g)",
        "key": "fibra_vegetal_g",
        "icon": Icons.grass_rounded
      },
    ],
    "AZÚCARES Y ALMIDÓN": [
      {
        "label": "Azúcares Sencillos (g)",
        "key": "azucares_sencillos_g",
        "icon": Icons.icecream_rounded
      },
      {
        "label": "Azúcares Libres (g)",
        "key": "azucares_libres_g",
        "icon": Icons.warning_amber_rounded
      },
      {"label": "Almidón (g)", "key": "almidon_g", "icon": Icons.grain_rounded},
    ],
    "DETALLE DE GRASAS": [
      {"label": "AGS (g)", "key": "ags_g", "icon": Icons.opacity},
      {"label": "AGM (g)", "key": "agm_g", "icon": Icons.opacity},
      {"label": "AGP (g)", "key": "agp_g", "icon": Icons.opacity},
      {
        "label": "Colesterol (mg)",
        "key": "colesterol_mg",
        "icon": Icons.monitor_heart_rounded
      },
      {
        "label": "Omega 3 (g)",
        "key": "omega3_g",
        "icon": Icons.set_meal_rounded
      },
      {
        "label": "Tipo Omega 3",
        "key": "tipo_omega3",
        "icon": Icons.label_important_outline_rounded,
        "isNum": false
      },
      {
        "label": "Grasas Trans (g)",
        "key": "grasas_trans_g",
        "icon": Icons.block_flipped
      },
    ],
    "VITAMINAS": [
      {
        "label": "Vit A (ug)",
        "key": "vitamina_a_eq_retinol_ug",
        "icon": Icons.visibility_rounded
      },
      {
        "label": "Vit D (ug)",
        "key": "vit_d_ug",
        "icon": Icons.wb_sunny_rounded
      },
      {
        "label": "Vit E (mg)",
        "key": "vit_e_eq_alpha_tocoferol_mg",
        "icon": Icons.health_and_safety_rounded
      },
      {"label": "Vit K (ug)", "key": "vit_k_ug", "icon": Icons.healing_rounded},
      {
        "label": "Vit B1 (mg)",
        "key": "vitamina_b1_mg",
        "icon": Icons.vibration_rounded
      },
      {
        "label": "Vit B2 (mg)",
        "key": "vitamina_b2_mg",
        "icon": Icons.vibration_rounded
      },
      {
        "label": "Niacina (mg)",
        "key": "eq_niacina_mg",
        "icon": Icons.vibration_rounded
      },
      {
        "label": "Vit B6 (mg)",
        "key": "vit_b6_mg",
        "icon": Icons.vibration_rounded
      },
      {
        "label": "Folato (ug)",
        "key": "eq_folato_dietetico_ug",
        "icon": Icons.vibration_rounded
      },
      {
        "label": "Vit B12 (ug)",
        "key": "vit_b12_ug",
        "icon": Icons.vibration_rounded
      },
      {
        "label": "Pantoténico (mg)",
        "key": "pantotenico_mg",
        "icon": Icons.vibration_rounded
      },
      {
        "label": "Biotina (ug)",
        "key": "biotina_ug",
        "icon": Icons.vibration_rounded
      },
      {
        "label": "Vit C (mg)",
        "key": "vit_c_mg",
        "icon": Icons.vibration_rounded
      },
    ],
    "MINERALES": [
      {
        "label": "Calcio (mg)",
        "key": "calcio_mg",
        "icon": Icons.diamond_rounded
      },
      {
        "label": "Fósforo (mg)",
        "key": "fosforo_mg",
        "icon": Icons.diamond_rounded
      },
      {
        "label": "Hierro (mg)",
        "key": "hierro_mg",
        "icon": Icons.diamond_rounded
      },
      {"label": "Iodo (ug)", "key": "iodo_ug", "icon": Icons.diamond_rounded},
      {"label": "Cinc (mg)", "key": "cinc_mg", "icon": Icons.diamond_rounded},
      {
        "label": "Magnesio (mg)",
        "key": "magnesio_mg",
        "icon": Icons.diamond_rounded
      },
      {"label": "Sodio (mg)", "key": "sodio_mg", "icon": Icons.diamond_rounded},
      {
        "label": "Potasio (mg)",
        "key": "potasio_mg",
        "icon": Icons.diamond_rounded
      },
      {
        "label": "Manganeso (mg)",
        "key": "manganeso_mg",
        "icon": Icons.diamond_rounded
      },
      {"label": "Cobre (mg)", "key": "cobre_mg", "icon": Icons.diamond_rounded},
      {
        "label": "Selenio (ug)",
        "key": "selenio_ug",
        "icon": Icons.diamond_rounded
      },
    ],
    "OTROS": [
      {
        "label": "Alcohol (g)",
        "key": "alcohol_g",
        "icon": Icons.local_bar_rounded
      },
      {
        "label": "Polifenoles (mg)",
        "key": "polifenoles_mg",
        "icon": Icons.energy_savings_leaf_rounded
      },
      {
        "label": "Probióticos (B ufc)",
        "key": "probioticos_billones_ufc",
        "icon": Icons.bug_report_rounded
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController();
    _factorCtrl = TextEditingController(text: "1.0");

    // Inicializar controladores y focus nodes
    for (var seccion in _camposPorSeccion.values) {
      for (var campo in seccion) {
        final key = campo['key'] as String;
        _composicionCtrls[key] =
            TextEditingController(text: key == 'tipo_omega3' ? "" : "0");
        _focusNodes[key] = FocusNode(onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _focusNext(key);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _focusPrevious(key);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        });

        _focusNodes[key]!.addListener(() {
          if (_focusNodes[key]!.hasFocus) {
            if (_composicionCtrls[key]!.text == "0" ||
                _composicionCtrls[key]!.text == "0.0") {
              _composicionCtrls[key]!.clear();
            }
          } else {
            // Si el campo queda vacío al perder foco, volver a poner 0 (si es numérico)
            if (_composicionCtrls[key]!.text.isEmpty && key != 'tipo_omega3') {
              _composicionCtrls[key]!.text = "0";
            }
          }
        });
      }
    }

    _loadInitialData();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _factorCtrl.dispose();
    _tagSearchCtrl.dispose();
    for (var ctrl in _composicionCtrls.values) {
      ctrl.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _focusNext(String currentKey) {
    final currentFields = _camposPorSeccion[_seccionActual]!;
    final index = currentFields.indexWhere((f) => f['key'] == currentKey);
    if (index != -1 && index < currentFields.length - 1) {
      _focusNodes[currentFields[index + 1]['key']]?.requestFocus();
    }
  }

  void _focusPrevious(String currentKey) {
    final currentFields = _camposPorSeccion[_seccionActual]!;
    final index = currentFields.indexWhere((f) => f['key'] == currentKey);
    if (index > 0) {
      _focusNodes[currentFields[index - 1]['key']]?.requestFocus();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _initializing = true);
    try {
      final repoCrud = ref.read(supabaseCrudRepositoryProvider);
      final dio = ref.read(dioProvider);

      // Cargar catálogos en paralelo
      final results = await Future.wait([
        repoCrud.fetchCatalog('nutricion', 'grupo_alimentario'),
        repoCrud.fetchCatalog('nutricion', 'subgrupo_alimentario'),
        dio.get('nutricionista/etiquetas'),
      ]);

      _grupos = results[0] as List<dynamic>;
      _subgroups = results[1] as List<dynamic>;
      _etiquetasCatalog = ((results[2] as Response).data as List<dynamic>);
      _etiquetasFiltradas = _etiquetasCatalog;

      if (widget.idIngrediente != null && widget.idIngrediente! > 0) {
        final repoInt = ref.read(inteligenciaRepositoryProvider);
        final data =
            await repoInt.obtenerIngredienteDetalle(widget.idIngrediente!);
        if (mounted) {
          _nombreCtrl.text = data['nombre'] ?? '';
          _factorCtrl.text =
              (data['factor_parte_comestible'] ?? 1.0).toString();
          _idGrupo = data['id_grupo_alimentario'];
          _idSubgrupo = data['id_subgrupo_alimentario'];
          _filtrarSubgrupos(_idGrupo);

          // Cargar etiquetas seleccionadas
          final etq = data['etiquetas'] as List<dynamic>? ?? [];
          _etiquetasSeleccionadas =
              etq.map((e) => (e['id'] as num).toInt()).toList();

          for (var seccion in _camposPorSeccion.values) {
            for (var campo in seccion) {
              final key = campo['key'] as String;
              if (data.containsKey(key)) {
                _composicionCtrls[key]?.text =
                    (data[key] ?? (key == 'tipo_omega3' ? "" : 0)).toString();
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading form data: $e");
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _filtrarSubgrupos(int? idGrupo) {
    if (idGrupo == null) {
      _subgroupsFiltrados = [];
    } else {
      _subgroupsFiltrados = _subgroups
          .where((s) => s['id_grupo_alimentario'] == idGrupo)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esNuevo =
        widget.idIngrediente == null || widget.idIngrediente == 0;

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTema.azulPrincipal, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text(
          esNuevo ? "Nuevo Ingrediente" : "Editar Ingrediente",
          style: GoogleFonts.montserrat(
              color: AppTema.azulOscuro,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_initializing)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 20),
                label: const Text("GUARDAR"),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTema.azulPrincipal),
              ),
            ),
        ],
      ),
      body: _initializing
          ? const Center(child: NutriLoading(mensaje: "Cargando datos..."))
          : _buildFormBody(),
    );
  }

  Widget _buildFormBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("DATOS BÁSICOS"),
              const SizedBox(height: 24),
              _buildField(
                  "Nombre del Alimento", _nombreCtrl, Icons.restaurant_rounded),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: _buildDropdown(
                          "Grupo Alimentario", _grupos, _idGrupo, (v) {
                    setState(() {
                      _idGrupo = v;
                      _idSubgrupo = null;
                      _filtrarSubgrupos(v);
                    });
                  })),
                  const SizedBox(width: 24),
                  Expanded(
                      child: _buildDropdown("Subgrupo Alimentario",
                          _subgroupsFiltrados, _idSubgrupo, (v) {
                    setState(() {
                      _idSubgrupo = v;
                    });
                  }, enabled: _idGrupo != null)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: _buildField("Factor Parte Comestible (0-1)",
                          _factorCtrl, Icons.pie_chart_rounded,
                          isNum: true)),
                  const SizedBox(width: 24),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 32),
              _buildEtiquetasSostenible(),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),
              _buildSectionTitle("COMPOSICIÓN NUTRICIONAL"),
              const SizedBox(height: 16),
              Text("Seleccione la sección de nutrientes que desea completar:",
                  style: GoogleFonts.lato(
                      fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              _buildSeccionDropdown(),
              const SizedBox(height: 32),
              _buildCamposSeccionActual(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEtiquetasSostenible() {
    final seleccionadas = _etiquetasCatalog
        .where((e) => _etiquetasSeleccionadas.contains(e['id']))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("ETIQUETAS NUTRICIONALES",
            style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600)),
        const SizedBox(height: 12),

        // Área de Chips Seleccionados
        if (seleccionadas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: seleccionadas
                  .map((etq) => Chip(
                        label: Text(etq['nombre_visible'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTema.azulPrincipal)),
                        backgroundColor: AppTema.azulPrincipal.withOpacity(0.1),
                        deleteIcon: const Icon(Icons.close_rounded,
                            size: 14, color: AppTema.azulPrincipal),
                        onDeleted: () => setState(
                            () => _etiquetasSeleccionadas.remove(etq['id'])),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide.none),
                      ))
                  .toList(),
            ),
          ),

        // Buscador y Selector
        Stack(
          children: [
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _tagSearchCtrl,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Buscar y agregar etiquetas...",
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _etiquetasFiltradas = _etiquetasCatalog.where((e) {
                          final nombre = (e['nombre_visible'] ?? '')
                              .toString()
                              .toLowerCase();
                          return nombre.contains(v.toLowerCase()) &&
                              !_etiquetasSeleccionadas.contains(e['id']);
                        }).toList();
                      });
                    },
                  ),
                ),
                // Lista de sugerencias (se muestra debajo si hay búsqueda)
                if (_tagSearchCtrl.text.isNotEmpty &&
                    _etiquetasFiltradas.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10)
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _etiquetasFiltradas.length,
                      itemBuilder: (context, index) {
                        final etq = _etiquetasFiltradas[index];
                        return ListTile(
                          title: Text(etq['nombre_visible'] ?? '',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.add_circle_outline_rounded,
                              size: 18, color: AppTema.azulPrincipal),
                          onTap: () {
                            setState(() {
                              _etiquetasSeleccionadas.add(etq['id']);
                              _tagSearchCtrl.clear();
                              _etiquetasFiltradas = _etiquetasCatalog;
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeccionDropdown() {
    return Container(
      width: 400,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTema.azulPrincipal.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _seccionActual,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTema.azulPrincipal),
          style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTema.azulPrincipal),
          items: _secciones
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _seccionActual = v);
          },
        ),
      ),
    );
  }

  Widget _buildCamposSeccionActual() {
    final campos = _camposPorSeccion[_seccionActual]!;
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: campos.map((c) {
        return SizedBox(
            width: 200,
            child: _buildField(
              c['label'],
              _composicionCtrls[c['key']]!,
              c['icon'],
              isNum: c['isNum'] ?? true,
              focusNode: _focusNodes[c['key']],
            ));
      }).toList(),
    );
  }

  Widget _buildDropdown(
      String label, List<dynamic> items, int? value, Function(int?) onChanged,
      {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF8FAFC) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: value,
              isExpanded: true,
              hint:
                  Text("Seleccione...", style: GoogleFonts.lato(fontSize: 14)),
              items: items
                  .map((e) => DropdownMenuItem<int?>(
                        value: e['id'],
                        child: Text(e['nombre'].toString().toUpperCase(),
                            style: GoogleFonts.lato(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppTema.azulPrincipal,
          letterSpacing: 1.2),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {bool isNum = false, FocusNode? focusNode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          keyboardType: isNum
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppTema.azulPrincipal),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTema.azulPrincipal, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return "Requerido";
            if (isNum && double.tryParse(v) == null) return "Inválido";
            return null;
          },
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idGrupo == null || _idSubgrupo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Debe seleccionar Grupo y Subgrupo"),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final Map<String, dynamic> payload = {
        'nombre': _nombreCtrl.text.trim(),
        'id_grupo_alimentario': _idGrupo,
        'id_subgrupo_alimentario': _idSubgrupo,
        'parte_comestible_factor': double.tryParse(_factorCtrl.text) ?? 1.0,
        'unidad_base': '100g',
        'etiquetas': _etiquetasSeleccionadas,
      };

      for (var seccion in _camposPorSeccion.values) {
        for (var campo in seccion) {
          final key = campo['key'] as String;
          final isNum = campo['isNum'] ?? true;
          if (!isNum) {
            payload[key] = _composicionCtrls[key]!.text.trim();
          } else {
            payload[key] = double.tryParse(_composicionCtrls[key]!.text) ?? 0.0;
          }
        }
      }

      await repo.guardarIngrediente(widget.idIngrediente ?? 0, payload);

      if (mounted) {
        NutriSnack.show(context, "Ingrediente guardado correctamente");
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al guardar: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
