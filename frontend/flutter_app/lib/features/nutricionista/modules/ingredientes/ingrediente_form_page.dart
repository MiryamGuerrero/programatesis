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
  late TextEditingController _kcalCtrl;
  late TextEditingController _protCtrl;
  late TextEditingController _grasCtrl;
  late TextEditingController _carbCtrl;
  bool _loading = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController();
    _kcalCtrl = TextEditingController();
    _protCtrl = TextEditingController();
    _grasCtrl = TextEditingController();
    _carbCtrl = TextEditingController();
    if (widget.idIngrediente != null && widget.idIngrediente! > 0) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _initializing = true);
    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final data = await repo.obtenerIngredienteDetalle(widget.idIngrediente!);
      if (mounted) {
        setState(() {
          _nombreCtrl.text = data['nombre'] ?? '';
          _kcalCtrl.text = (data['energia_kcal'] ?? 0).toString();
          _protCtrl.text = (data['proteinas_g'] ?? 0).toString();
          _grasCtrl.text = (data['grasa_total_g'] ?? 0).toString();
          _carbCtrl.text = (data['hidratos_carbono_g'] ?? 0).toString();
          _initializing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        Flexible(
          child: _initializing 
            ? const Padding(padding: EdgeInsets.all(40), child: NutriLoading(mensaje: "Cargando datos..."))
            : _buildFormBody(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bool esNuevo = widget.idIngrediente == null || widget.idIngrediente == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      decoration: const BoxDecoration(
        color: AppTema.azulPrincipal,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Icon(esNuevo ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Text(
            esNuevo ? "Nuevo Ingrediente" : "Editar Ingrediente",
            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (!_initializing)
            TextButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded, color: Colors.white, size: 20),
              label: Text("GUARDAR", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("DATOS BÁSICOS"),
            const SizedBox(height: 16),
            _buildField("Nombre del Alimento", _nombreCtrl, Icons.restaurant_rounded),
            const SizedBox(height: 32),
            _buildSectionTitle("COMPOSICIÓN POR 100G"),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: 230, child: _buildField("Energía (kcal)", _kcalCtrl, Icons.bolt_rounded, isNum: true)),
                SizedBox(width: 230, child: _buildField("Proteínas (g)", _protCtrl, Icons.fitness_center_rounded, isNum: true)),
                SizedBox(width: 230, child: _buildField("Grasas (g)", _grasCtrl, Icons.water_drop_rounded, isNum: true)),
                SizedBox(width: 230, child: _buildField("Carbohidratos (g)", _carbCtrl, Icons.bakery_dining_rounded, isNum: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (v) => v == null || v.isEmpty ? "Campo requerido" : null,
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final payload = {
        'nombre': _nombreCtrl.text.trim(),
        'energia_kcal': double.tryParse(_kcalCtrl.text) ?? 0,
        'proteinas_g': double.tryParse(_protCtrl.text) ?? 0,
        'grasa_total_g': double.tryParse(_grasCtrl.text) ?? 0,
        'hidratos_carbono_g': double.tryParse(_carbCtrl.text) ?? 0,
      };
      
      if (widget.idIngrediente != null && widget.idIngrediente! > 0) {
        await repo.guardarIngrediente(widget.idIngrediente!, payload);
      } else {
        // En una app real aquí llamaríamos a un POST
        await repo.guardarIngrediente(0, payload);
      }
      widget.onBack();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
