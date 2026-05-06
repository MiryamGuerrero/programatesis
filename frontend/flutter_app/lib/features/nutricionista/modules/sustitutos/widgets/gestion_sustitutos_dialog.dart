import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/state/app_providers.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/layout_components.dart';

class GestionSustitutosDialog extends ConsumerStatefulWidget {
  final int idIngredienteOriginal;
  final String nombreIngredienteOriginal;

  const GestionSustitutosDialog({
    super.key,
    required this.idIngredienteOriginal,
    required this.nombreIngredienteOriginal,
  });

  @override
  ConsumerState<GestionSustitutosDialog> createState() => _GestionSustitutosDialogState();
}

class _GestionSustitutosDialogState extends ConsumerState<GestionSustitutosDialog> {
  bool _loading = false;
  List<dynamic> _sustitutos = [];
  bool _mostrandoFormulario = false;

  // Formulario Nuevo Sustituto
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _reemplazosSeleccionados = [];
  final _ctrlRatio = TextEditingController(text: '1.0');
  final _ctrlAviso = TextEditingController();
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    _fetchSustitutos();
  }

  Future<void> _fetchSustitutos() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('nutricionista/sustitutos', queryParameters: {
        'id_original': widget.idIngredienteOriginal
      });
      if (mounted) {
        setState(() {
          _sustitutos = resp.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guardarSustitutos() async {
    if (!_formKey.currentState!.validate()) return;
    if (_reemplazosSeleccionados.isEmpty) {
      NutriSnack.show(context, "Selecciona al menos un ingrediente de reemplazo", isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final ratio = double.tryParse(_ctrlRatio.text) ?? 1.0;
      final aviso = _ctrlAviso.text.trim().isEmpty ? null : _ctrlAviso.text.trim();

      for (final reemplazo in _reemplazosSeleccionados) {
        final payload = {
          'id_ingrediente_original': widget.idIngredienteOriginal,
          'id_ingrediente_reemplazo': reemplazo['id'],
          'ratio_conversion': ratio,
          'mensaje_aviso': aviso,
          'activo': _activo,
        };
        await dio.post('nutricionista/sustitutos', data: payload);
      }
      
      if (!mounted) return;
      NutriSnack.show(context, _reemplazosSeleccionados.length == 1 ? 'Sustituto guardado' : 'Sustitutos guardados');
      setState(() {
        _mostrandoFormulario = false;
        _reemplazosSeleccionados = [];
        _ctrlRatio.text = '1.0';
        _ctrlAviso.clear();
      });
      _fetchSustitutos();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        NutriSnack.show(context, 'Error al guardar algunos sustitutos', isError: true);
      }
    }
  }

  Future<void> _eliminarSustituto(int id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('nutricionista/sustitutos/$id');
      if (mounted) {
        NutriSnack.show(context, "Sustituto eliminado");
        _fetchSustitutos();
      }
    } catch (e) {
      if (mounted) NutriSnack.show(context, "Error al eliminar", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              if (_mostrandoFormulario)
                _buildFormulario()
              else
                _buildLista(),
              const SizedBox(height: 24),
              _buildAcciones(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gestionar Sustitutos', 
              style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        const SizedBox(height: 8),
        Text('Alimento original: ${widget.nombreIngredienteOriginal}', 
          style: GoogleFonts.inter(fontSize: 14, color: AppTema.azulPrincipal, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLista() {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    
    if (_sustitutos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No hay sustitutos definidos para este alimento.', 
                style: GoogleFonts.inter(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _sustitutos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final s = _sustitutos[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppTema.verdeSalud, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['nombre_reemplazo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Ratio: x${s['ratio_conversion']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (s['mensaje_aviso'] != null)
                  Tooltip(message: s['mensaje_aviso'], child: const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _eliminarSustituto(s['id']),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IngredientSelectorMulti(
            label: "Buscar y Marcar Alimentos de Reemplazo",
            selected: _reemplazosSeleccionados,
            onChanged: (list) => setState(() => _reemplazosSeleccionados = list),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildInputField('Ratio (ej: 1.0)', _ctrlRatio, isNumber: true)),
              const SizedBox(width: 20),
              Expanded(child: SwitchListTile(
                title: const Text('Activo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
                contentPadding: EdgeInsets.zero,
              )),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField('Mensaje de aviso (opcional)', _ctrlAviso, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildAcciones() {
    if (_mostrandoFormulario) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => setState(() {
            _mostrandoFormulario = false;
            _reemplazosSeleccionados = [];
          }), child: const Text('CANCELAR')),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _guardarSustitutos,
            style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white),
            child: Text(_reemplazosSeleccionados.isEmpty 
              ? 'GUARDAR' 
              : 'AÑADIR ${_reemplazosSeleccionados.length} SELECCIONADOS'),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => setState(() => _mostrandoFormulario = true),
        icon: const Icon(Icons.add_rounded),
        label: const Text('AÑADIR NUEVO SUSTITUTO'),
        style: FilledButton.styleFrom(backgroundColor: AppTema.azulPrincipal, padding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
      ],
    );
  }
}

class _IngredientSelectorMulti extends ConsumerStatefulWidget {
  final String label;
  final List<Map<String, dynamic>> selected;
  final Function(List<Map<String, dynamic>>) onChanged;

  const _IngredientSelectorMulti({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  ConsumerState<_IngredientSelectorMulti> createState() => _IngredientSelectorMultiState();
}

class _IngredientSelectorMultiState extends ConsumerState<_IngredientSelectorMulti> {
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
          _results = data.where((i) => i['nombre'].toString().toLowerCase().contains(q.toLowerCase())).take(15).toList();
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toggleSelection(Map<String, dynamic> item) {
    final list = List<Map<String, dynamic>>.from(widget.selected);
    final index = list.indexWhere((e) => e['id'] == item['id']);
    if (index >= 0) {
      list.removeAt(index);
    } else {
      list.add({'id': item['id'], 'nombre': item['nombre']});
    }
    widget.onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        
        // Buscador
        TextField(
          controller: _ctrl,
          onChanged: _search,
          decoration: InputDecoration(
            hintText: "Escribe para buscar...",
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        
        if (_searching) const LinearProgressIndicator(),

        // Resultados con Scroll y Checkboxes (Soluciona Overflow)
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _results[index];
                final isSelected = widget.selected.any((e) => e['id'] == item['id']);
                return CheckboxListTile(
                  title: Text(item['nombre'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(item),
                  dense: true,
                  activeColor: AppTema.azulPrincipal,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),

        // Resumen de Selección
        if (widget.selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selected.map((item) => Chip(
                label: Text(item['nombre'], style: const TextStyle(fontSize: 11)),
                onDeleted: () => _toggleSelection(item),
                deleteIcon: const Icon(Icons.close, size: 14),
                backgroundColor: AppTema.azulPrincipal.withOpacity(0.1),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              )).toList(),
            ),
          ),
      ],
    );
  }
}
