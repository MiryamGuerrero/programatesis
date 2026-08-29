import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/seguimiento_provider.dart';

class TutorGustosPage extends ConsumerStatefulWidget {
  const TutorGustosPage({super.key});

  @override
  ConsumerState<TutorGustosPage> createState() => _TutorGustosPageState();
}

class _TutorGustosPageState extends ConsumerState<TutorGustosPage> {
  List<Map<String, dynamic>> _subgrupos = [];
  final Set<int> _seleccionados = {};
  final Set<int> _iniciales = {};
  String? _lastLoadedId;
  bool _isSaving = false;

  bool get _hayCambios {
    if (_seleccionados.length != _iniciales.length) return true;
    return !_seleccionados.containsAll(_iniciales);
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
        setState(() {
          _isSaving = false;
          _iniciales.clear();
          _iniciales.addAll(_seleccionados);
        });
        ref.invalidate(subgruposGustosProvider(idPaciente));
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
    final size = MediaQuery.of(context).size;
    final itemWidth = (size.width - 48 - 12) / 2;

    final idPaciente = ref.watch(selectedPatientIdProvider);
    final gustosAsync = idPaciente != null
        ? ref.watch(subgruposGustosProvider(idPaciente))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return gustosAsync.when(
      data: (data) {
        if (_lastLoadedId != idPaciente) {
          _subgrupos = data;
          _seleccionados.clear();
          _iniciales.clear();
          for (var s in _subgrupos) {
            if (s['es_preferido'] == true) {
              final id = s['id'] as int;
              _seleccionados.add(id);
              _iniciales.add(id);
            }
          }
          _lastLoadedId = idPaciente;
        }

        final showButton = _hayCambios || _isSaving;

    return Container(
      color: colorScheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () async {
                if (idPaciente != null) {
                  _lastLoadedId = null;
                  ref.invalidate(subgruposGustosProvider(idPaciente));
                  await ref.read(subgruposGustosProvider(idPaciente).future);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 24, 24, showButton ? 96 : 24),
                child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _subgrupos.map((s) {
                  final id = s['id'] as int;
                  final bool isSelected = _seleccionados.contains(id);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _seleccionados.remove(id);
                        } else {
                          _seleccionados.add(id);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: itemWidth,
                      constraints: const BoxConstraints(
                          minHeight: 100), // Altura mínima base
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 16),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? colorScheme.primary : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : const Color(0xFFE2E8F0),
                          width: 2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                                color: colorScheme.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6))
                          else
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            s['emoji'] ?? "🍲",
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s['nombre'],
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppTema.azulOscuro,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s['grupo'].toString().toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white60
                                  : Colors.grey.shade400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !showButton,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                offset: showButton ? Offset.zero : const Offset(0, 1.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  opacity: showButton ? 1.0 : 0.0,
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTema.verdeSalud,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: AppTema.verdeSalud.withOpacity(0.4),
                        ),
                        onPressed: _isSaving ? null : _guardarCambios,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: const Text("Confirmar Preferencias",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
      loading: () => _buildGustosShimmer(context),
      error: (e, _) => Center(child: Text("Error al cargar gustos: $e")),
    );
  }

  Widget _buildGustosShimmer(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final itemWidth = (size.width - 48 - 12) / 2;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFCBD5E1),
          highlightColor: const Color(0xFFF8FAFC),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(8, (index) {
              return Container(
                width: itemWidth,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
