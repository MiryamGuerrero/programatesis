import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';

class EtiquetaFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? etiquetaInicial;

  const EtiquetaFormDialog({
    super.key,
    this.etiquetaInicial,
  });

  @override
  ConsumerState<EtiquetaFormDialog> createState() => _EtiquetaFormDialogState();
}

class _EtiquetaFormDialogState extends ConsumerState<EtiquetaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late TextEditingController _ctrlNombre;
  late TextEditingController _ctrlDescripcion;

  @override
  void initState() {
    super.initState();
    final e = widget.etiquetaInicial;
    _ctrlNombre = TextEditingController(text: e?['nombre_visible'] ?? '');
    _ctrlDescripcion = TextEditingController(text: e?['descripcion'] ?? '');
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final payload = {
        'nombre_visible': _ctrlNombre.text.trim(),
        'descripcion': _ctrlDescripcion.text.trim(),
      };

      final dio = ref.read(dioProvider);
      if (widget.etiquetaInicial != null) {
        await dio.put(
            'nutricionista/etiquetas/${widget.etiquetaInicial!['id']}',
            data: payload);
      } else {
        await dio.post('nutricionista/etiquetas', data: payload);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      NutriSnack.show(context, 'Etiqueta guardada con éxito');
    } catch (e) {
      NutriSnack.show(context, 'Error al guardar la etiqueta', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.etiquetaInicial == null
                        ? 'Nueva Etiqueta'
                        : 'Editar Etiqueta',
                    style: GoogleFonts.quicksand(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTema.azulOscuro,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(
                  'Información de la Etiqueta', Icons.label_important_rounded),
              const SizedBox(height: 24),
              _buildTextField(
                label: 'Nombre Visible',
                controller: _ctrlNombre,
                hint: 'Ej: Alto en Proteína',
                icon: Icons.title_rounded,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                label: 'Descripción',
                controller: _ctrlDescripcion,
                hint: 'Describe cuándo se aplica esta etiqueta...',
                icon: Icons.description_rounded,
                maxLines: 4,
              ),
              const SizedBox(height: 40),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTema.azulPrincipal, size: 24),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppTema.azulPrincipal,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTema.azulOscuro,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            filled: true,
            fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        const SizedBox(width: 16),
        if (_loading)
          const CircularProgressIndicator()
        else
          ElevatedButton(
            onPressed: _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTema.azulPrincipal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(widget.etiquetaInicial == null
                ? 'CREAR ETIQUETA'
                : 'GUARDAR CAMBIOS'),
          ),
      ],
    );
  }
}
