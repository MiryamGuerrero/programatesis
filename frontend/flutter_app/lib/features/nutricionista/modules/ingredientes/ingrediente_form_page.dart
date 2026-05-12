import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  ConsumerState<IngredienteFormPage> createState() => _IngredienteFormPageState();
}

class _IngredienteFormPageState extends ConsumerState<IngredienteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _factorCtrl;
  final Map<String, TextEditingController> _composicionCtrls = {};
  
  int? _idGrupo;
  int? _idSubgrupo;
  List<dynamic> _grupos = [];
  List<dynamic> _subgrupos = [];
  List<dynamic> _subgruposFiltrados = [];

  bool _loading = false;
  bool _initializing = false;

  final List<String> _camposComposicion = [
    'energia_kcal', 'agua_g', 'alcohol_g', 'proteinas_g', 'hidratos_carbono_g', 
    'almidon_g', 'azucares_sencillos_g', 'azucares_libres_g', 'fibra_vegetal_g', 
    'grasa_total_g', 'ags_g', 'agm_g', 'agp_g', 'colesterol_mg', 'vitamina_a_eq_retinol_ug', 
    'retinol_ug', 'carotenoides_eq_beta_caroteno_ug', 'vit_d_ug', 'vit_e_eq_alpha_tocoferol_mg', 
    'vit_k_ug', 'vitamina_b1_mg', 'vitamina_b2_mg', 'eq_niacina_mg', 'vit_b6_mg', 
    'eq_folato_dietetico_ug', 'vit_b12_ug', 'pantotenico_mg', 'biotina_ug', 'vit_c_mg', 
    'calcio_mg', 'fosforo_mg', 'hierro_mg', 'iodo_ug', 'cinc_mg', 'magnesio_mg', 
    'sodio_mg', 'potasio_mg', 'manganeso_mg', 'cobre_mg', 'selenio_ug', 'omega3_g', 
    'tipo_omega3', 'grasas_trans_g', 'polifenoles_mg', 'probioticos_billones_ufc'
  ];

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController();
    _factorCtrl = TextEditingController(text: "1.0");
    for (var campo in _camposComposicion) {
      _composicionCtrls[campo] = TextEditingController(text: campo == 'tipo_omega3' ? "" : "0");
    }
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _initializing = true);
    try {
      final repoCrud = ref.read(supabaseCrudRepositoryProvider);
      _grupos = await repoCrud.fetchCatalog('nutricion', 'grupo_alimentario');
      _subgrupos = await repoCrud.fetchCatalog('nutricion', 'subgrupo_alimentario');
      
      if (widget.idIngrediente != null && widget.idIngrediente! > 0) {
        final repoInt = ref.read(inteligenciaRepositoryProvider);
        final data = await repoInt.obtenerIngredienteDetalle(widget.idIngrediente!);
        if (mounted) {
          _nombreCtrl.text = data['nombre'] ?? '';
          _factorCtrl.text = (data['factor_parte_comestible'] ?? 1.0).toString();
          _idGrupo = data['id_grupo_alimentario'];
          _idSubgrupo = data['id_subgrupo_alimentario'];
          _filtrarSubgrupos(_idGrupo);
          for (var campo in _camposComposicion) {
            _composicionCtrls[campo]?.text = (data[campo] ?? (campo == 'tipo_omega3' ? "" : 0)).toString();
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
      _subgruposFiltrados = [];
    } else {
      _subgruposFiltrados = _subgrupos.where((s) => s['id_grupo_alimentario'] == idGrupo).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esNuevo = widget.idIngrediente == null || widget.idIngrediente == 0;
    
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTema.azulPrincipal, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text(
          esNuevo ? "Nuevo Ingrediente" : "Editar Ingrediente",
          style: GoogleFonts.montserrat(color: AppTema.azulOscuro, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_initializing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 20),
                label: const Text("GUARDAR"),
                style: FilledButton.styleFrom(backgroundColor: AppTema.azulPrincipal),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("DATOS BÁSICOS"),
              const SizedBox(height: 24),
              _buildField("Nombre del Alimento", _nombreCtrl, Icons.restaurant_rounded),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildDropdown("Grupo Alimentario", _grupos, _idGrupo, (v) {
                    setState(() { 
                      _idGrupo = v; 
                      _idSubgrupo = null;
                      _filtrarSubgrupos(v);
                    });
                  })),
                  const SizedBox(width: 24),
                  Expanded(child: _buildDropdown("Subgrupo Alimentario", _subgruposFiltrados, _idSubgrupo, (v) {
                    setState(() { _idSubgrupo = v; });
                  }, enabled: _idGrupo != null)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildField("Factor Parte Comestible (0-1)", _factorCtrl, Icons.pie_chart_rounded, isNum: true)),
                  const SizedBox(width: 24),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 40),
              
              _buildSectionTitle("MACRONUTRIENTES Y GENERAL (POR 100G)"),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24, runSpacing: 24,
                children: [
                  _wField("Energía (kcal)", "energia_kcal", Icons.bolt_rounded),
                  _wField("Agua (g)", "agua_g", Icons.water_drop_outlined),
                  _wField("Proteínas (g)", "proteinas_g", Icons.fitness_center_rounded),
                  _wField("Grasas Totales (g)", "grasa_total_g", Icons.water_drop_rounded),
                  _wField("Carbohidratos (g)", "hidratos_carbono_g", Icons.bakery_dining_rounded),
                  _wField("Fibra (g)", "fibra_vegetal_g", Icons.grass_rounded),
                ],
              ),
              const SizedBox(height: 40),

              _buildSectionTitle("AZÚCARES Y ALMIDÓN"),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24, runSpacing: 24,
                children: [
                  _wField("Azúcares Sencillos (g)", "azucares_sencillos_g", Icons.icecream_rounded),
                  _wField("Azúcares Libres (g)", "azucares_libres_g", Icons.warning_amber_rounded),
                  _wField("Almidón (g)", "almidon_g", Icons.grain_rounded),
                ],
              ),
              const SizedBox(height: 40),

              _buildSectionTitle("DETALLE DE GRASAS"),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24, runSpacing: 24,
                children: [
                  _wField("AGS (g)", "ags_g", Icons.opacity),
                  _wField("AGM (g)", "agm_g", Icons.opacity),
                  _wField("AGP (g)", "agp_g", Icons.opacity),
                  _wField("Colesterol (mg)", "colesterol_mg", Icons.monitor_heart_rounded),
                  _wField("Omega 3 (g)", "omega3_g", Icons.set_meal_rounded),
                  _wField("Tipo Omega 3", "tipo_omega3", Icons.label_important_outline_rounded, isNum: false),
                  _wField("Grasas Trans (g)", "grasas_trans_g", Icons.block_flipped),
                ],
              ),
              const SizedBox(height: 40),

              _buildSectionTitle("VITAMINAS"),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24, runSpacing: 24,
                children: [
                  _wField("Vit A (ug)", "vitamina_a_eq_retinol_ug", Icons.visibility_rounded),
                  _wField("Vit D (ug)", "vit_d_ug", Icons.wb_sunny_rounded),
                  _wField("Vit E (mg)", "vit_e_eq_alpha_tocoferol_mg", Icons.health_and_safety_rounded),
                  _wField("Vit K (ug)", "vit_k_ug", Icons.healing_rounded),
                  _wField("Vit B1 (mg)", "vitamina_b1_mg", Icons.vibration_rounded),
                  _wField("Vit B2 (mg)", "vitamina_b2_mg", Icons.vibration_rounded),
                  _wField("Niacina (mg)", "eq_niacina_mg", Icons.vibration_rounded),
                  _wField("Vit B6 (mg)", "vit_b6_mg", Icons.vibration_rounded),
                  _wField("Folato (ug)", "eq_folato_dietetico_ug", Icons.vibration_rounded),
                  _wField("Vit B12 (ug)", "vit_b12_ug", Icons.vibration_rounded),
                  _wField("Pantoténico (mg)", "pantotenico_mg", Icons.vibration_rounded),
                  _wField("Biotina (ug)", "biotina_ug", Icons.vibration_rounded),
                  _wField("Vit C (mg)", "vit_c_mg", Icons.vibration_rounded),
                ],
              ),
              const SizedBox(height: 40),

              _buildSectionTitle("MINERALES"),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24, runSpacing: 24,
                children: [
                  _wField("Calcio (mg)", "calcio_mg", Icons.diamond_rounded),
                  _wField("Fósforo (mg)", "fosforo_mg", Icons.diamond_rounded),
                  _wField("Hierro (mg)", "hierro_mg", Icons.diamond_rounded),
                  _wField("Iodo (ug)", "iodo_ug", Icons.diamond_rounded),
                  _wField("Cinc (mg)", "cinc_mg", Icons.diamond_rounded),
                  _wField("Magnesio (mg)", "magnesio_mg", Icons.diamond_rounded),
                  _wField("Sodio (mg)", "sodio_mg", Icons.diamond_rounded),
                  _wField("Potasio (mg)", "potasio_mg", Icons.diamond_rounded),
                  _wField("Manganeso (mg)", "manganeso_mg", Icons.diamond_rounded),
                  _wField("Cobre (mg)", "cobre_mg", Icons.diamond_rounded),
                  _wField("Selenio (ug)", "selenio_ug", Icons.diamond_rounded),
                ],
              ),
              const SizedBox(height: 40),

              _buildSectionTitle("OTROS"),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24, runSpacing: 24,
                children: [
                  _wField("Alcohol (g)", "alcohol_g", Icons.local_bar_rounded),
                  _wField("Polifenoles (mg)", "polifenoles_mg", Icons.energy_savings_leaf_rounded),
                  _wField("Probióticos (B ufc)", "probioticos_billones_ufc", Icons.bug_report_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<dynamic> items, int? value, Function(int?) onChanged, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
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
              hint: Text("Seleccione...", style: GoogleFonts.lato(fontSize: 14)),
              items: items.map((e) => DropdownMenuItem<int?>(
                value: e['id'],
                child: Text(e['nombre'].toString().toUpperCase(), style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600)),
              )).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _wField(String label, String key, IconData icon, {bool isNum = true}) {
    return SizedBox(width: 180, child: _buildField(label, _composicionCtrls[key]!, icon, isNum: isNum));
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: 1.2),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {bool isNum = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppTema.azulPrincipal),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debe seleccionar Grupo y Subgrupo"), backgroundColor: Colors.orange));
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
      };
      
      for (var entry in _composicionCtrls.entries) {
        if (entry.key == 'tipo_omega3') {
          payload[entry.key] = entry.value.text.trim();
        } else {
          payload[entry.key] = double.tryParse(entry.value.text) ?? 0.0;
        }
      }
      
      await repo.guardarIngrediente(widget.idIngrediente ?? 0, payload);
      widget.onBack();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
