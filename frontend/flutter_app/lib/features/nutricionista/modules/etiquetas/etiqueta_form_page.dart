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

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlDescripcion.dispose();
    super.dispose();
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
      NutriSnack.show(
        context,
        widget.etiquetaInicial == null
            ? 'Etiqueta creada exitosamente'
            : 'Etiqueta actualizada exitosamente',
      );
    } catch (e) {
      NutriSnack.show(context, 'Error al guardar la etiqueta: $e',
          isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.etiquetaInicial != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera institucional
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTema.verdeSalud.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.label_rounded,
                      color: AppTema.verdeSalud,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Editar etiqueta' : 'Nueva etiqueta',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTema.azulOscuro,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit
                              ? 'Modifica los datos de la etiqueta nutricional.'
                              : 'Define una etiqueta para clasificar recetas y alimentos.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.grey, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Sección 1: Información general
              _sectionTitle('INFORMACIÓN GENERAL'),
              Text(
                'Nombre visible*',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTema.azulOscuro,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ctrlNombre,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTema.azulOscuro,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre de la etiqueta es requerido';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Ej. Alto en proteína, Sin gluten, Bajo en sodio',
                  prefixIcon: const Icon(Icons.badge_outlined,
                      color: AppTema.azulPrincipal, size: 18),
                  filled: true,
                  fillColor: AppTema.grisLienzo,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Chip de previsualización en vivo
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTema.grisLienzo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Text(
                      'Vista previa:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTema.azulPrincipal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTema.azulPrincipal.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.label_rounded,
                              size: 13, color: AppTema.azulPrincipal),
                          const SizedBox(width: 5),
                          Text(
                            _ctrlNombre.text.trim().isEmpty
                                ? 'Nombre de etiqueta'
                                : _ctrlNombre.text.trim(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTema.azulPrincipal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Sección 2: Detalle de aplicabilidad
              _sectionTitle('DETALLE DE APLICABILIDAD'),
              Text(
                'Descripción clínica (opcional)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTema.azulOscuro,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ctrlDescripcion,
                maxLines: 3,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTema.azulOscuro,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Describe las pautas clínicas o condiciones en las que se aplica esta etiqueta...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.description_outlined,
                        color: AppTema.azulPrincipal, size: 18),
                  ),
                  filled: true,
                  fillColor: AppTema.grisLienzo,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Acciones del formulario (Cancelar y Guardar)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _guardar,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      isEdit ? 'Guardar cambios' : 'Crear etiqueta',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTema.verdeSalud,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: AppTema.azulPrincipal.withValues(alpha: 0.6),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
