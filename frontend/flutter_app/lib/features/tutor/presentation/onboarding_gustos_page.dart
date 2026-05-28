import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingGustosPage extends ConsumerStatefulWidget {
  final String idPaciente;
  final VoidCallback onCompletado;

  const OnboardingGustosPage({
    super.key, 
    required this.idPaciente,
    required this.onCompletado,
  });

  @override
  ConsumerState<OnboardingGustosPage> createState() => _OnboardingGustosPageState();
}

class _OnboardingGustosPageState extends ConsumerState<OnboardingGustosPage> {
  List<Map<String, dynamic>> _subgrupos = [];
  final Set<int> _seleccionados = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarSubgrupos();
  }

  Future<void> _cargarSubgrupos() async {
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('tutor/subgrupos-preferencia/${widget.idPaciente}');
      final List<dynamic> data = resp.data;
      
      setState(() {
        _subgrupos = List<Map<String, dynamic>>.from(data);
        // Inicializar seleccionados si ya hay (por si se re-abre)
        for (var s in _subgrupos) {
          if (s['es_preferido'] == true) {
            _seleccionados.add(s['id']);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando subgrupos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardar() async {
    if (_seleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor selecciona al menos una preferencia")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('tutor/guardar-preferencias', data: {
        "id_paciente": widget.idPaciente,
        "subgrupos_ids": _seleccionados.toList(),
      });
      widget.onCompletado();
    } catch (e) {
      debugPrint("Error guardando preferencias: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al guardar. Intenta de nuevo.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Gustos y Preferencias",
                        style: GoogleFonts.montserrat(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTema.azulOscuro,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Selecciona los grupos de alimentos que más le gustan al paciente. Esto nos ayudará a sugerir mejores recetas.",
                        style: theme.textTheme.bodyLarge?.copyWith(color: Colors.blueGrey, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
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
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                s['emoji'] ?? "🍲",
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  s['nombre'],
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : AppTema.azulOscuro,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _guardar,
                      child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Finalizar Configuración", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
