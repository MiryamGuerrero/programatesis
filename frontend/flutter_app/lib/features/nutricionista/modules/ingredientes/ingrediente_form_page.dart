import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';

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
    final repo = ref.read(inteligenciaRepositoryProvider);
    final data = await repo.obtenerIngredienteDetalle(widget.idIngrediente!);
    final comp = data['composicion'] ?? {};
    setState(() {
      _nombreCtrl.text = data['nombre'] ?? '';
      _kcalCtrl.text = (comp['energia_kcal'] ?? 0).toString();
      _protCtrl.text = (comp['proteinas_g'] ?? 0).toString();
      _grasCtrl.text = (comp['grasa_total_g'] ?? 0).toString();
      _carbCtrl.text = (comp['hidratos_carbono_g'] ?? 0).toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
              Text(widget.idIngrediente == null || widget.idIngrediente == 0 ? 'Nuevo Ingrediente' : 'Editar Ingrediente',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildField('Nombre', _nombreCtrl),
                const SizedBox(height: 24),
                const Text("Composición Nutricional (por 100g)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                const SizedBox(height: 16),
                _buildField('Energía (kcal)', _kcalCtrl, isNum: true),
                _buildField('Proteínas (g)', _protCtrl, isNum: true),
                _buildField('Grasas (g)', _grasCtrl, isNum: true),
                _buildField('Carbohidratos (g)', _carbCtrl, isNum: true),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Guardar Cambios"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final payload = {
        'nombre': _nombreCtrl.text,
        'composicion': {
          'energia_kcal': double.tryParse(_kcalCtrl.text) ?? 0,
          'proteinas_g': double.tryParse(_protCtrl.text) ?? 0,
          'grasa_total_g': double.tryParse(_grasCtrl.text) ?? 0,
          'hidratos_carbono_g': double.tryParse(_carbCtrl.text) ?? 0,
        }
      };
      await repo.guardarIngrediente(widget.idIngrediente!, payload);
      widget.onBack();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }
}
