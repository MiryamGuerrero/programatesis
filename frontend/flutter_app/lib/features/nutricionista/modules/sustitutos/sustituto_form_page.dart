import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';

class SustitutoFormPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? sustitutoInicial;
  final VoidCallback onBack;

  const SustitutoFormPage({super.key, this.sustitutoInicial, required this.onBack});

  @override
  ConsumerState<SustitutoFormPage> createState() => _SustitutoFormPageState();
}

class _SustitutoFormPageState extends ConsumerState<SustitutoFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  Map<String, dynamic>? _original;
  Map<String, dynamic>? _reemplazo;
  final _ctrlRatio = TextEditingController(text: '1.0');
  final _ctrlAviso = TextEditingController();
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    if (widget.sustitutoInicial != null) {
      final s = widget.sustitutoInicial!;
      _original = {'id': s['id_ingrediente_original'], 'nombre': s['nombre_original']};
      _reemplazo = {'id': s['id_ingrediente_reemplazo'], 'nombre': s['nombre_reemplazo']};
      _ctrlRatio.text = s['ratio_conversion'].toString();
      _ctrlAviso.text = s['mensaje_aviso'] ?? '';
      _activo = s['activo'] ?? true;
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_original == null || _reemplazo == null) {
      NutriSnack.show(context, "Debes seleccionar ambos ingredientes", isError: true);
      return;
    }
    if (_original!['id'] == _reemplazo!['id']) {
      NutriSnack.show(context, "El ingrediente original y el reemplazo no pueden ser el mismo", isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final payload = {
        if (widget.sustitutoInicial != null) 'id': widget.sustitutoInicial!['id'],
        'id_ingrediente_original': _original!['id'],
        'id_ingrediente_reemplazo': _reemplazo!['id'],
        'ratio_conversion': double.tryParse(_ctrlRatio.text) ?? 1.0,
        'mensaje_aviso': _ctrlAviso.text.trim().isEmpty ? null : _ctrlAviso.text.trim(),
        'activo': _activo,
      };

      final dio = ref.read(dioProvider);
      await dio.post('nutricionista/sustitutos', data: payload);
      
      if (!mounted) return;
      NutriSnack.show(context, widget.sustitutoInicial == null ? 'Sustituto creado' : 'Sustituto actualizado');
      widget.onBack();
    } catch (e) {
      if (mounted) NutriSnack.show(context, 'Error al guardar', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Vinculación de Alimentos', Icons.swap_horiz_rounded),
                  const SizedBox(height: 24),
                  _IngredientSelector(
                    label: "Ingrediente Original",
                    selected: _original,
                    onSelected: (v) => setState(() => _original = v),
                    icon: Icons.egg_rounded,
                  ),
                  const SizedBox(height: 32),
                  const Center(child: Icon(Icons.arrow_downward_rounded, color: AppTema.azulPrincipal, size: 32)),
                  const SizedBox(height: 32),
                  _IngredientSelector(
                    label: "Ingrediente de Reemplazo",
                    selected: _reemplazo,
                    onSelected: (v) => setState(() => _reemplazo = v),
                    icon: Icons.auto_awesome_rounded,
                    accentColor: AppTema.verdeSalud,
                  ),
                  const SizedBox(height: 40),
                  _buildSectionHeader('Configuración Técnica', Icons.settings_suggest_rounded),
                  const SizedBox(height: 24),
                  _buildInputField('Ratio de Conversión (ej: 1.2)', _ctrlRatio, isNumber: true, hint: '1.0'),
                  const SizedBox(height: 20),
                  _buildInputField('Mensaje de Aviso / Nota Terapéutica', _ctrlAviso, maxLines: 3, hint: 'Ej: Puede variar el sabor ligeramente.'),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: const Text('Vínculo Activo', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Determina si el sistema sugerirá este cambio.'),
                    value: _activo,
                    onChanged: (v) => setState(() => _activo = v),
                    activeColor: AppTema.azulPrincipal,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: widget.onBack),
          const SizedBox(width: 12),
          Text(widget.sustitutoInicial == null ? 'Nuevo Sustituto' : 'Editar Sustituto',
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
          const Spacer(),
          if (_loading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('GUARDAR'),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTema.azulPrincipal, size: 20),
        const SizedBox(width: 10),
        Text(title.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, {bool isNumber = false, int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
        const SizedBox(height: 10),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
      ],
    );
  }
}

class _IngredientSelector extends ConsumerStatefulWidget {
  final String label;
  final Map<String, dynamic>? selected;
  final Function(Map<String, dynamic>?) onSelected;
  final IconData icon;
  final Color accentColor;

  const _IngredientSelector({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.icon,
    this.accentColor = AppTema.azulPrincipal,
  });

  @override
  ConsumerState<_IngredientSelector> createState() => _IngredientSelectorState();
}

class _IngredientSelectorState extends ConsumerState<_IngredientSelector> {
  bool _searching = false;
  List<dynamic> _results = [];
  final _ctrl = TextEditingController();

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final data = await repo.fetchIngredientes();
      if (mounted) {
        setState(() {
          _results = data.where((i) => i['nombre'].toString().toLowerCase().contains(q.toLowerCase())).take(10).toList();
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
        const SizedBox(height: 12),
        if (widget.selected != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.accentColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.accentColor),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.selected!['nombre'], style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => widget.onSelected(null)),
              ],
            ),
          )
        else
          Column(
            children: [
              TextField(
                controller: _ctrl,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: "Buscar ingrediente...",
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              if (_searching) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
              if (_results.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        title: Text(item['nombre'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        onTap: () {
                          widget.onSelected({'id': item['id'], 'nombre': item['nombre']});
                          _ctrl.clear();
                          setState(() => _results = []);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
