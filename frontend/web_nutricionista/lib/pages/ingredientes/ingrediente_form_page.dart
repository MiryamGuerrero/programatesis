import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/nutricionista_providers.dart';

class IngredienteFormPage extends ConsumerStatefulWidget {
  final int id;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  const IngredienteFormPage({
    super.key,
    required this.id,
    required this.onClose,
    required this.onSaved,
  });

  @override
  ConsumerState<IngredienteFormPage> createState() => _IngredienteFormPageState();
}

class _IngredienteFormPageState extends ConsumerState<IngredienteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _energiaCtrl;
  late TextEditingController _proteinaCtrl;
  late TextEditingController _grasaCtrl;
  late TextEditingController _carboCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController();
    _energiaCtrl = TextEditingController();
    _proteinaCtrl = TextEditingController();
    _grasaCtrl = TextEditingController();
    _carboCtrl = TextEditingController();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final detalle = await ref.read(ingredienteDetalleProvider(widget.id).future);
    final comp = detalle['composicion'] ?? {};
    _nombreCtrl.text = detalle['nombre'] ?? '';
    _energiaCtrl.text = (comp['energia_kcal'] ?? 0).toString();
    _proteinaCtrl.text = (comp['proteinas_g'] ?? 0).toString();
    _grasaCtrl.text = (comp['grasa_total_g'] ?? 0).toString();
    _carboCtrl.text = (comp['hidratos_carbono_g'] ?? 0).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Editar Ingrediente', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: ListView(
                children: [
                  _buildField('Nombre del ingrediente', _nombreCtrl),
                  const SizedBox(height: 24),
                  Text('Composición Nutricional (por 100g)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 16),
                  _buildField('Energía (kcal)', _energiaCtrl, isNumber: true),
                  _buildField('Proteínas (g)', _proteinaCtrl, isNumber: true),
                  _buildField('Grasas Totales (g)', _grasaCtrl, isNumber: true),
                  _buildField('Carbohidratos (g)', _carboCtrl, isNumber: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Guardar Cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(nutricionistaRepositoryProvider);
      final payload = {
        'nombre': _nombreCtrl.text,
        'composicion': {
          'energia_kcal': double.tryParse(_energiaCtrl.text) ?? 0,
          'proteinas_g': double.tryParse(_proteinaCtrl.text) ?? 0,
          'grasa_total_g': double.tryParse(_grasaCtrl.text) ?? 0,
          'hidratos_carbono_g': double.tryParse(_carboCtrl.text) ?? 0,
        }
      };
      await repo.actualizarIngrediente(widget.id, payload);
      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
