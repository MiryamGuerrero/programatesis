import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';

class TutorGustosPage extends ConsumerStatefulWidget {
  const TutorGustosPage({super.key});

  @override
  ConsumerState<TutorGustosPage> createState() => _TutorGustosPageState();
}

class _TutorGustosPageState extends ConsumerState<TutorGustosPage> {
  List<Map<String, dynamic>> _subgrupos = [];
  final Set<int> _seleccionados = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _cargarDatos());
  }

  Future<void> _cargarDatos() async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    if (idPaciente == null) return;

    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('tutor/subgrupos-preferencia/$idPaciente');
      final List<dynamic> data = resp.data;
      
      if (mounted) {
        setState(() {
          _subgrupos = List<Map<String, dynamic>>.from(data);
          _seleccionados.clear();
          for (var s in _subgrupos) {
            if (s['es_preferido'] == true) {
              _seleccionados.add(s['id']);
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando gustos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarCambios() async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    if (idPaciente == null) return;

    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('tutor/guardar-preferencias', data: {
        "id_paciente": idPaciente,
        "subgrupos_ids": _seleccionados.toList(),
      });
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Preferencias actualizadas correctamente"),
            backgroundColor: AppTema.verdeSalud,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error actualizando gustos: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al actualizar preferencias")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _subgrupos.length,
              itemBuilder: (context, index) {
                final s = _subgrupos[index];
                final id = s['id'] as int;
                final bool isSelected = _seleccionados.contains(id);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) _seleccionados.remove(id);
                      else _seleccionados.add(id);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : const Color(0xFFF1F5F9),
                        width: 2,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                        else
                          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          s['emoji'] ?? "🍲",
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            s['nombre'],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : AppTema.azulOscuro,
                            ),
                          ),
                        ),
                        Text(
                          s['grupo'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white60 : Colors.grey.shade400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Botón de guardado flotante o fijo abajo
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _guardarCambios,
                icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_outline_rounded),
                label: const Text("Confirmar Preferencias", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
