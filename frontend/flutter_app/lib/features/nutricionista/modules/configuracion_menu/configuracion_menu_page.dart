import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';

class _TabInfo {
  final String label;
  final int count;
  final Color color;
  _TabInfo({required this.label, required this.count, required this.color});
}

class ConfiguracionMenuPage extends ConsumerStatefulWidget {
  const ConfiguracionMenuPage({super.key});

  @override
  ConsumerState<ConfiguracionMenuPage> createState() =>
      _ConfiguracionMenuPageState();
}

class _ConfiguracionMenuPageState extends ConsumerState<ConfiguracionMenuPage> {
  static const List<String> _momentColorOptions = [
    '#2E7D32',
    '#1976D2',
    '#F57C00',
    '#7B1FA2',
    '#C2185B',
    '#00897B',
    '#5D4037',
    '#455A64',
  ];

  static const List<Map<String, dynamic>> _rolesCombinacion = [
    {'valor': 'COMBINACION_LIGERA', 'etiqueta': 'Ligera', 'color': 0xFF4CAF50},
    {'valor': 'COMBINACION_EQUILIBRADA', 'etiqueta': 'Equilibrada', 'color': 0xFF2196F3},
    {'valor': 'COMBINACION_ENERGETICA', 'etiqueta': 'Energetica', 'color': 0xFFFF9800},
    {'valor': 'COMBINACION_RECUPERACION_NUTRICIONAL', 'etiqueta': 'Recuperacion', 'color': 0xFF9C27B0},
    {'valor': 'COMBINACION_SUAVE', 'etiqueta': 'Suave', 'color': 0xFF00BCD4},
  ];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _momentos = const [];
  List<Map<String, dynamic>> _tiposPlato = const [];
  List<Map<String, dynamic>> _condicionesNutricionales = const [];
  List<Map<String, dynamic>> _reglasInteligentes = const [];
  List<Map<String, dynamic>> _todasReglas = const [];
  Map<String, dynamic>? _selectedMomento;
  Map<String, dynamic>? _reglaMomento;
  List<Map<String, dynamic>> _detalleTipos = const [];

  final TextEditingController _minPrincipalesCtrl =
      TextEditingController(text: '1');
  final TextEditingController _maxPrincipalesCtrl =
      TextEditingController(text: '1');
  final TextEditingController _maxComplementosCtrl =
      TextEditingController(text: '2');
  bool _permiteComplementos = true;
  bool _reglaActiva = true;

  // Combinaciones form state
  int? _formMomentoId;
  String _formRol = 'COMBINACION_LIGERA';
  final Set<int> _formCondiciones = {};
  final Set<int> _formPlatillos = {};
  String _filtroComboMomento = '';
  String _filtroComboRol = '';
  int? _filtroComboCondicion;
  String _busquedaPlatillo = '';
  String _vistaAgrupada = 'momento';
  int _paginaActual = 0;
  final int _filasPorPagina = 3;
  final int _columnasPorPagina = 3;
  int get _itemsPorPagina => _filasPorPagina * _columnasPorPagina;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAll);
  }

  @override
  void dispose() {
    _minPrincipalesCtrl.dispose();
    _maxPrincipalesCtrl.dispose();
    _maxComplementosCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get('nutricionista/momentos-comida'),
        dio.get('nutricionista/tipos-plato'),
        dio.get('condiciones-nutricionales'),
        dio.get('nutricionista/reglas-menu-combinaciones'),
      ]);

      final momentos = _toRows(results[0].data);
      final tipos = _toRows(results[1].data);
      final condiciones = _toRows(results[2].data);
      final todasReglas = _toRows(results[3].data);
      Map<String, dynamic>? selected =
          momentos.isNotEmpty ? momentos.first : null;
      if (_selectedMomento != null) {
        for (final momento in momentos) {
          if (momento['id'] == _selectedMomento?['id']) {
            selected = momento;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _momentos = momentos;
        _tiposPlato = tipos;
        _condicionesNutricionales = condiciones;
        _selectedMomento = selected;
        _todasReglas = todasReglas;
      });

      if (selected != null) {
        await _loadRuleForMoment(selected);
      } else if (mounted) {
        setState(() {
          _reglaMomento = null;
          _detalleTipos = const [];
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRuleForMoment(Map<String, dynamic> momento) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio
          .get('nutricionista/reglas-generales/por-momento/${momento['id']}');
      final regla = Map<String, dynamic>.from(response.data as Map);
      final detalle = _toRows(regla['tipos_permitidos']);
      if (!mounted) return;
      setState(() {
        _reglaMomento = regla;
        _detalleTipos = detalle;
        _reglasInteligentes = const [];
        _minPrincipalesCtrl.text = '${regla['min_principales'] ?? 1}';
        _maxPrincipalesCtrl.text = '${regla['max_principales'] ?? 1}';
        _permiteComplementos = regla['permite_complementos'] != false;
        _maxComplementosCtrl.text = '${regla['max_complementos_total'] ?? 2}';
        _reglaActiva = regla['activo'] != false;
      });
      await _loadSmartRulesForMoment(momento);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reglaMomento = null;
        _detalleTipos = const [];
        _reglasInteligentes = const [];
        _minPrincipalesCtrl.text = '1';
        _maxPrincipalesCtrl.text = '1';
        _permiteComplementos = true;
        _maxComplementosCtrl.text = '2';
        _reglaActiva = true;
      });
    }
  }

  Future<void> _loadSmartRulesForMoment(Map<String, dynamic> momento) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        'nutricionista/reglas-menu-combinaciones/por-momento/${momento['id']}',
      );
      if (!mounted) return;
      setState(() => _reglasInteligentes = _toRows(response.data));
      setState(() => _paginaActual = 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reglasInteligentes = const [];
        _paginaActual = 0;
      });
    }
  }

  Future<int> _ensureRule() async {
    if (_selectedMomento == null) {
      throw Exception('Selecciona un momento de comida');
    }
    if (_reglaMomento != null && _reglaMomento!['id'] != null) {
      return _asInt(_reglaMomento!['id'])!;
    }
    await _saveRule(showMessage: false);
    if (_reglaMomento == null || _reglaMomento!['id'] == null) {
      throw Exception('No se pudo crear la regla del momento');
    }
    return _asInt(_reglaMomento!['id'])!;
  }

  Future<void> _saveRule({bool showMessage = true}) async {
    if (_selectedMomento == null) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'id_momento': _selectedMomento!['id'],
        'min_principales': _asInt(_minPrincipalesCtrl.text) ?? 1,
        'max_principales': _asInt(_maxPrincipalesCtrl.text) ?? 1,
        'permite_complementos': _permiteComplementos,
        'max_complementos_total':
            _permiteComplementos ? (_asInt(_maxComplementosCtrl.text) ?? 0) : 0,
        'activo': _reglaActiva,
      };
      await dio.post('nutricionista/reglas-generales', data: payload);
      await _loadRuleForMoment(_selectedMomento!);
      if (mounted && showMessage) {
        NutriSnack.show(context, 'Menu guardado');
      }
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'Error al guardar regla: $error',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteDetailGroup(Map<String, dynamic> detail) async {
    final ids = _detailItems(detail)
        .map((item) => _asInt(item['id']))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return;

    try {
      final dio = ref.read(dioProvider);
      for (final id in ids) {
        await dio.delete('nutricionista/reglas-generales/detalle/$id');
      }
      if (_selectedMomento != null) await _loadRuleForMoment(_selectedMomento!);
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'No se pudo quitar la opcion',
            isError: true);
      }
    }
  }

  Future<bool> _confirmAction(String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _modalFrame(
        width: 520,
        icon: Icons.warning_amber_rounded,
        title: title,
        subtitle: message,
        onClose: () => Navigator.pop(ctx, false),
        child: const SizedBox.shrink(),
        actions: _modalActions(
          ctx,
          saveLabel: 'Confirmar',
          saveIcon: Icons.check_rounded,
          onCancel: () => Navigator.pop(ctx, false),
          onSave: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    return confirmed == true;
  }

  Widget _modalFrame({
    required double width,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    required List<Widget> actions,
    required VoidCallback onClose,
  }) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: 720),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTema.azulPrincipal.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppTema.azulPrincipal, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTema.azulOscuro,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Cerrar',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(child: child),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _modalActions(
    BuildContext ctx, {
    required String saveLabel,
    required IconData saveIcon,
    required VoidCallback onCancel,
    required VoidCallback onSave,
  }) {
    return [
      TextButton(
        onPressed: onCancel,
        child: Text(
          'Cancelar',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 12),
      FilledButton.icon(
        onPressed: onSave,
        icon: Icon(saveIcon),
        label: Text(saveLabel),
        style: FilledButton.styleFrom(
          backgroundColor: AppTema.verdeSalud,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ];
  }

  Widget _menuTypeChip({
    required Widget label,
    required bool selected,
    required ValueChanged<bool>? onSelected,
  }) {
    return FilterChip(
      label: label,
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        selected ? Icons.check_circle_rounded : Icons.add_circle_outline,
        size: 18,
        color: selected ? AppTema.azulPrincipal : AppTema.verdeSalud,
      ),
      labelStyle: GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTema.azulOscuro,
      ),
      backgroundColor: Colors.white,
      selectedColor: AppTema.azulPrincipal.withValues(alpha: 0.08),
      side: BorderSide(
        color: selected
            ? AppTema.azulPrincipal.withValues(alpha: 0.45)
            : Colors.grey.shade300,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: onSelected,
    );
  }

  Widget _roleChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTema.azulPrincipal.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTema.azulPrincipal : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: selected
                    ? AppTema.azulPrincipal
                    : AppTema.verdeSalud.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : AppTema.verdeSalud,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTema.azulOscuro,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMoment(Map<String, dynamic> momento) async {
    final confirmed = await _confirmAction(
      'Eliminar horario',
      'Se eliminara el horario "${momento['nombre']}" y sus reglas de menu.',
    );
    if (!confirmed) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('nutricionista/momentos-comida/${momento['id']}');
      if (_selectedMomento?['id'] == momento['id']) {
        _selectedMomento = null;
      }
      await _loadAll();
      if (mounted) NutriSnack.show(context, 'Horario eliminado');
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'No se pudo eliminar el horario',
            isError: true);
      }
    }
  }

  Future<void> _deleteDishType(Map<String, dynamic> tipo) async {
    final confirmed = await _confirmAction(
      'Eliminar opcion',
      'Se eliminara "${tipo['nombre']}" del catalogo de opciones.',
    );
    if (!confirmed) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('nutricionista/tipos-plato/${tipo['id']}');
      await _loadAll();
      if (mounted) NutriSnack.show(context, 'Opcion eliminada');
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context,
            'No se pudo eliminar la opcion. Revisa si esta usada por recetas.',
            isError: true);
      }
    }
  }

  Future<void> _clearSelectedMomentMenu() async {
    if (_selectedMomento == null) return;
    final confirmed = await _confirmAction(
      'Limpiar menu',
      'Se borraran solo las combinaciones de ${_selectedMomento!['nombre']}. Los demas momentos no se modifican.',
    );
    if (!confirmed) return;

    try {
      final dio = ref.read(dioProvider);
      final ids = _detalleTipos
          .map((item) => _asInt(item['id']))
          .whereType<int>()
          .toList();
      for (final id in ids) {
        await dio.delete('nutricionista/reglas-generales/detalle/$id');
      }
      await _loadRuleForMoment(_selectedMomento!);
      if (mounted) NutriSnack.show(context, 'Menu del momento limpiado');
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'No se pudo limpiar este menu',
            isError: true);
      }
    }
  }

  // ============================================================
  // COMBINACIONES: CREAR POR FORMULARIO
  // ============================================================

  Future<void> _openCreateCombinationDialog() async {
    _formMomentoId = _selectedMomento != null ? _asInt(_selectedMomento!['id']) : (_momentos.isNotEmpty ? _asInt(_momentos.first['id']) : null);
    _formRol = 'COMBINACION_LIGERA';
    _formCondiciones.clear();
    _formPlatillos.clear();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => _modalFrame(
          width: 700,
          icon: Icons.restaurant_menu_rounded,
          title: 'Nueva combinacion',
          subtitle: 'Crea una combinacion de tipos de plato vinculada a condiciones nutricionales.',
          onClose: () => Navigator.pop(ctx, false),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Momento de comida
              _buildFormFieldLabel('Momento de comida'),
              DropdownButtonFormField<int>(
                value: _formMomentoId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: _momentos.map((m) => DropdownMenuItem(
                  value: _asInt(m['id']),
                  child: Text(m['nombre']?.toString() ?? ''),
                )).toList(),
                onChanged: (v) => setModalState(() => _formMomentoId = v),
              ),
              const SizedBox(height: 16),
              // Rol
              _buildFormFieldLabel('Tipo de combinacion'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _rolesCombinacion.map((r) {
                  final selected = _formRol == r['valor'];
                  return ChoiceChip(
                    label: Text(r['etiqueta'] as String),
                    selected: selected,
                    selectedColor: Color(r['color'] as int).withValues(alpha: 0.15),
                    labelStyle: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Color(r['color'] as int) : Colors.grey.shade700,
                    ),
                    onSelected: (_) => setModalState(() => _formRol = r['valor'] as String),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Condiciones nutricionales
              _buildFormFieldLabel('Condiciones nutricionales'),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar condicion...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (v) => setModalState(() {}),
              ),
              const SizedBox(height: 8),
              if (_formCondiciones.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _formCondiciones.map((id) {
                    final cond = _condicionesNutricionales.firstWhere(
                      (c) => _asInt(c['id']) == id,
                      orElse: () => {'nombre': 'Desconocida'},
                    );
                    return InputChip(
                      label: Text(cond['nombre']?.toString() ?? ''),
                      selected: true,
                      onDeleted: () => setModalState(() => _formCondiciones.remove(id)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _condicionesNutricionales.map((c) {
                      final id = _asInt(c['id']) ?? 0;
                      final selected = _formCondiciones.contains(id);
                      return FilterChip(
                        label: Text(c['nombre']?.toString() ?? ''),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) => setModalState(() {
                          if (_) _formCondiciones.add(id);
                          else _formCondiciones.remove(id);
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tipos de plato
              _buildFormFieldLabel('Tipos de plato (minimo 2)'),
              if (_formPlatillos.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _formPlatillos.map((id) {
                    final tipo = _tiposPlato.firstWhere(
                      (t) => _asInt(t['id']) == id,
                      orElse: () => {'nombre': 'Tipo'},
                    );
                    return InputChip(
                      label: Text(tipo['nombre']?.toString() ?? ''),
                      selected: true,
                      onDeleted: () => setModalState(() => _formPlatillos.remove(id)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tiposPlato.map((t) {
                      final id = _asInt(t['id']) ?? 0;
                      final selected = _formPlatillos.contains(id);
                      return FilterChip(
                        label: Text(t['nombre']?.toString() ?? ''),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) => setModalState(() {
                          if (_) _formPlatillos.add(id);
                          else _formPlatillos.remove(id);
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: _modalActions(
            ctx,
            saveLabel: 'Guardar combinacion',
            saveIcon: Icons.save_rounded,
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () {
              if (_formMomentoId == null) {
                NutriSnack.show(context, 'Selecciona un momento de comida', isError: true);
                return;
              }
              if (_formCondiciones.isEmpty) {
                NutriSnack.show(context, 'Selecciona al menos una condicion nutricional', isError: true);
                return;
              }
              if (_formPlatillos.length < 2) {
                NutriSnack.show(context, 'Selecciona al menos 2 tipos de plato', isError: true);
                return;
              }
              Navigator.pop(ctx, true);
            },
          ),
        ),
      ),
    );

    if (saved != true) return;

    setState(() => _saving = true);
    try {
      final platillosNombres = _formPlatillos.map((id) {
        final t = _tiposPlato.firstWhere((x) => _asInt(x['id']) == id, orElse: () => {'nombre': ''});
        return t['nombre']?.toString() ?? '';
      }).where((n) => n.isNotEmpty).toList();

      final dio = ref.read(dioProvider);
      final response = await dio.post(
        'nutricionista/reglas-menu-combinaciones',
        data: {
          'id_momento': _formMomentoId,
          'rol': _formRol,
          'platillos': platillosNombres,
          'condiciones_ids': _formCondiciones.toList(),
        },
      );
      final data = response.data is Map ? response.data as Map : {};
      final accion = data['accion']?.toString() ?? '';
      if (accion == 'creada') {
        NutriSnack.show(context, 'Combinacion guardada correctamente');
      } else if (accion == 'actualizada') {
        final nuevas = data['condiciones_agregadas'] ?? 0;
        if (nuevas > 0) {
          NutriSnack.show(context, 'La combinacion ya existia, se agregaron $nuevas condiciones nuevas');
        } else {
          NutriSnack.show(context, 'La combinacion ya estaba registrada sin cambios');
        }
      }
      await _loadAll();
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'Error: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildFormFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppTema.azulOscuro,
        ),
      ),
    );
  }

  // ============================================================
  // COMBINACIONES: IMPORTAR JSON
  // ============================================================

  Future<void> _openJsonImportDialog() async {
    if (_selectedMomento == null) return;

    final momentoNombre = _selectedMomento!['nombre']?.toString() ?? '';
    final tiposDisponibles = _tiposPlato
        .map((t) => t['nombre']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final condicionesDisponibles = _condicionesNutricionales
        .map((c) => c['nombre']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    final String exampleJson;
    if (momentoNombre.toLowerCase().contains('desayuno')) {
      exampleJson = '''
{
  "combinaciones": [
    {
      "rol": "COMBINACION_LIGERA",
      "orientacion_nutricional": ["Sobrepeso", "Obesidad", "Posible riesgo de sobrepeso"],
      "platillos": ["Tortilla", "Batido"]
    },
    {
      "rol": "COMBINACION_LIGERA",
      "orientacion_nutricional": ["Sobrepeso", "Obesidad"],
      "platillos": ["Plato ligero", "Batido"]
    },
    {
      "rol": "COMBINACION_EQUILIBRADA",
      "orientacion_nutricional": ["Normal", "Talla normal"],
      "platillos": ["Wrap desayuno", "Jugo natural"]
    },
    {
      "rol": "COMBINACION_EQUILIBRADA",
      "orientacion_nutricional": ["Normal"],
      "platillos": ["Sandwich saludable", "Jugo natural"]
    },
    {
      "rol": "COMBINACION_ENERGETICA",
      "orientacion_nutricional": ["Bajo peso", "Delgadez", "Emaciacion severa"],
      "platillos": ["Pancakes saludables", "Batido"]
    },
    {
      "rol": "COMBINACION_ENERGETICA",
      "orientacion_nutricional": ["Bajo peso", "Delgadez"],
      "platillos": ["Wrap desayuno", "Colada"]
    }
  ]
}''';
    } else {
      exampleJson = '''
{
  "combinaciones": [
    {
      "rol": "COMBINACION_LIGERA",
      "orientacion_nutricional": ["Sobrepeso", "Obesidad"],
      "platillos": ["Ensalada", "Jugo natural"]
    },
    {
      "rol": "COMBINACION_EQUILIBRADA",
      "orientacion_nutricional": ["Normal", "Talla normal"],
      "platillos": ["Plato fuerte", "Batido"]
    },
    {
      "rol": "COMBINACION_ENERGETICA",
      "orientacion_nutricional": ["Bajo peso", "Delgadez", "Emaciacion severa"],
      "platillos": ["Plato fuerte", "Colada"]
    }
  ]
}''';
    }

    int? selectedMomentoId = _asInt(_selectedMomento!['id']);
    final jsonCtrl = TextEditingController(text: exampleJson.trim());
    String? jsonError;

    final saved = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => _modalFrame(
          width: 740,
          icon: Icons.code_rounded,
          title: 'Codigo JSON',
          subtitle: 'Escribe aqui todas las combinaciones para "$momentoNombre". El sistema validara y guardara cada una.',
          onClose: () => Navigator.pop(ctx, false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Momento selector
              _buildFormFieldLabel('Momento de comida'),
              DropdownButtonFormField<int>(
                value: selectedMomentoId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _momentos.map((m) => DropdownMenuItem(
                  value: _asInt(m['id']),
                  child: Text(m['nombre']?.toString() ?? ''),
                )).toList(),
                onChanged: (v) => setModalState(() => selectedMomentoId = v),
              ),
              const SizedBox(height: 14),
              // Format help
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTema.azulPrincipal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTema.azulPrincipal.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_rounded, size: 16, color: AppTema.azulPrincipal),
                        const SizedBox(width: 8),
                        Text(
                          'Formato JSON:',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTema.azulPrincipal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• "combinaciones" = arreglo con cada regla\n'
                      '• "rol" = uno de los roles de combinacion\n'
                      '• "orientacion_nutricional" = nombres de condiciones (puede ser tambien "condiciones_nutricionales" o "condiciones")\n'
                      '• "platillos" = nombres de tipos de plato (minimo 2)\n'
                      '• Si una combinacion ya existe, se agregan las condiciones nuevas sin duplicar\n'
                      '• Puedes escribir todas las combinaciones que necesites en un solo JSON',
                      style: GoogleFonts.montserrat(fontSize: 11, height: 1.4, color: Colors.blueGrey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Available references
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Condiciones disponibles (${condicionesDisponibles.length}):',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            condicionesDisponibles.join(', '),
                            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.green.shade700),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipos de plato disponibles (${tiposDisponibles.length}):',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tiposDisponibles.join(', '),
                            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blue.shade700),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // JSON input
              TextField(
                controller: jsonCtrl,
                minLines: 10,
                maxLines: 16,
                expands: false,
                style: GoogleFonts.robotoMono(fontSize: 12, height: 1.35),
                decoration: InputDecoration(
                  hintText: 'Escribe aqui el codigo JSON...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  errorText: jsonError,
                ),
                onChanged: (v) {
                  if (jsonError != null) {
                    setModalState(() => jsonError = null);
                  }
                },
              ),
            ],
          ),
          actions: _modalActions(
            ctx,
            saveLabel: 'Guardar combinaciones',
            saveIcon: Icons.save_rounded,
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () {
              if (selectedMomentoId == null) {
                setModalState(() => jsonError = 'Selecciona un momento de comida');
                return;
              }
              if (jsonCtrl.text.trim().isEmpty) {
                setModalState(() => jsonError = 'El campo JSON esta vacio');
                return;
              }
              dynamic decoded;
              try {
                decoded = jsonDecode(jsonCtrl.text.trim());
              } catch (_) {
                setModalState(() => jsonError = 'Error: el JSON no tiene un formato valido');
                return;
              }
              // Validacion previa contra catalogos locales
              final combinaciones = decoded is Map && decoded['combinaciones'] is List
                  ? decoded['combinaciones'] as List
                  : <dynamic>[];
              if (combinaciones.isEmpty) {
                setModalState(() => jsonError = 'El JSON debe contener al menos una combinacion en el arreglo "combinaciones"');
                return;
              }
              final errores = <String>[];
              final rolesValidos = _rolesCombinacion.map((r) => r['valor'] as String).toSet();
              for (int i = 0; i < combinaciones.length; i++) {
                final c = combinaciones[i];
                if (c is! Map) {
                  errores.add('Combinacion ${i + 1}: debe ser un objeto JSON');
                  continue;
                }
                final rol = c['rol'] as String?;
                if (rol == null || rol.isEmpty) {
                  errores.add('Combinacion ${i + 1}: falta el campo "rol"');
                } else if (!rolesValidos.contains(rol)) {
                  errores.add('Combinacion ${i + 1}: rol "$rol" no es valido. Usa uno de: ${rolesValidos.join(', ')}');
                }
                final orientacion = c['orientacion_nutricional'] is List ? c['orientacion_nutricional'] as List : (c['condiciones_nutricionales'] is List ? c['condiciones_nutricionales'] as List : (c['condiciones'] is List ? c['condiciones'] as List : null));
                if (orientacion == null || orientacion.isEmpty) {
                  errores.add('Combinacion ${i + 1}: debe tener al menos una condicion en "orientacion_nutricional"');
                } else {
                  for (final cond in orientacion) {
                    if (!condicionesDisponibles.contains(cond)) {
                      errores.add('Combinacion ${i + 1}: la condicion "$cond" no existe en la base de datos');
                    }
                  }
                }
                final platillos = c['platillos'] is List ? c['platillos'] as List : <dynamic>[];
                if (platillos.isEmpty) {
                  errores.add('Combinacion ${i + 1}: debe tener al menos un platillo en "platillos"');
                } else if (platillos.length < 2) {
                  errores.add('Combinacion ${i + 1}: debe tener al menos 2 platillos en "platillos"');
                } else {
                  for (final plat in platillos) {
                    if (!tiposDisponibles.contains(plat)) {
                      errores.add('Combinacion ${i + 1}: el platillo "$plat" no existe en la base de datos');
                    }
                  }
                }
              }
              if (errores.isNotEmpty) {
                setModalState(() => jsonError = errores.take(5).join('\n'));
                return;
              }
              setModalState(() => jsonError = null);
              Navigator.pop(ctx, {'momentoId': selectedMomentoId, 'json': jsonCtrl.text.trim()});
            },
          ),
        ),
      ),
    );

    if (saved == false || saved == null) return;

    if (saved is! Map) return;
    final result = saved;

    final momentoId = result['momentoId'] as int;
    final jsonText = result['json'] as String;

    try {
      final decoded = jsonDecode(jsonText.trim());
      final dio = ref.read(dioProvider);
      // Mostrar dialogo de carga
      if (mounted) {
        showDialog<dynamic>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppTema.azulPrincipal,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Guardando combinaciones...',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTema.azulOscuro,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      final response = await dio.post(
        'nutricionista/reglas-menu-combinaciones/por-momento/$momentoId/importar-json',
        data: decoded,
      );
      // Cerrar dialogo de carga
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await _loadAll();
      if (_selectedMomento != null && _asInt(_selectedMomento!['id']) != momentoId) {
        final momento = _momentos.firstWhere(
          (m) => _asInt(m['id']) == momentoId,
          orElse: () => _selectedMomento!,
        );
        setState(() => _selectedMomento = momento);
        await _loadRuleForMoment(momento);
      }
      if (mounted) {
        final data = response.data is Map ? response.data as Map : {};
        final insertadas = data['insertadas'] ?? 0;
        final omitidas = data['omitidas'] ?? 0;
        if (insertadas > 0 && omitidas > 0) {
          NutriSnack.show(context, 'El JSON se cargo correctamente. $insertadas creadas, $omitidas ya existian');
        } else if (insertadas > 0) {
          NutriSnack.show(context, 'El JSON se cargo correctamente. $insertadas combinaciones guardadas');
        } else {
          NutriSnack.show(context, 'Todas las combinaciones ya existian sin cambios');
        }
      }
    } catch (error) {
      // Cerrar dialogo de carga si sigue abierto
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
      if (mounted) {
        final msg = error.toString();
        String errorMsg;
        if (msg.contains('Tipo de platillo no existe') || msg.contains('no existe') || msg.contains('no encontrado')) {
          errorMsg = msg;
        } else if (msg.contains('falta') || msg.contains('debe') || msg.contains('invalido')) {
          errorMsg = msg;
        } else if (msg.contains('Bad Request') || msg.contains('400')) {
          final response = (error as dynamic).response;
          if (response != null && response.data != null) {
            final detail = response.data['detail'] ?? response.data['error'] ?? response.data['message'];
            errorMsg = detail is String ? detail : 'El servidor rechazo el JSON. Verifica que todos los platillos y condiciones existan exactamente como aparecen en el catalogo.';
          } else {
            errorMsg = 'Error 400: El servidor no acepto el JSON. Revisa nombres de platillos y condiciones.';
          }
        } else {
          errorMsg = 'Error inesperado al guardar: $error';
        }
        NutriSnack.show(context, errorMsg, isError: true);
      }
    }
  }

  Future<void> _deleteSmartRule(Map<String, dynamic> rule) async {
    final id = _asInt(rule['id']);
    if (id == null) return;
    final confirmed = await _confirmAction(
      'Eliminar combinacion',
      'Se eliminara esta combinacion de tipos de plato y sus condiciones asociadas.',
    );
    if (!confirmed) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('nutricionista/reglas-menu-combinaciones/$id');
      await _loadAll();
      if (mounted) NutriSnack.show(context, 'Combinacion eliminada');
    } catch (_) {
      if (mounted) {
        NutriSnack.show(context, 'No se pudo eliminar la combinacion',
            isError: true);
      }
    }
  }

  Future<void> _openMomentDialog([Map<String, dynamic>? momento]) async {
    final nombreCtrl =
        TextEditingController(text: momento?['nombre']?.toString() ?? '');
    final inicioCtrl =
        TextEditingController(text: _timeText(momento?['hora_inicio']));
    final finCtrl =
        TextEditingController(text: _timeText(momento?['hora_fin']));
    String selectedColor =
        momento?['color']?.toString() ?? _momentColorOptions.first;
    bool activo = momento?['activo'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => _modalFrame(
          width: 520,
          icon: Icons.schedule_rounded,
          title: momento == null ? 'Nuevo momento' : 'Editar momento',
          subtitle:
              'Define el nombre, horario y color que identificara este momento del dia.',
          onClose: () => Navigator.pop(ctx, false),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dialogTextField(
                    nombreCtrl, 'Nombre', Icons.restaurant_rounded),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _dialogTextField(inicioCtrl,
                            'Hora inicio (HH:mm)', Icons.schedule_rounded)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _dialogTextField(finCtrl, 'Hora fin (HH:mm)',
                            Icons.schedule_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      color: AppTema.azulOscuro,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _momentColorOptions.map((hex) {
                    final selected = selectedColor.toUpperCase() == hex;
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setModalState(() => selectedColor = hex),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseColor(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppTema.azulOscuro
                                : Colors.grey.shade300,
                            width: selected ? 3 : 1,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: activo,
                  title: const Text('Activo'),
                  onChanged: (v) => setModalState(() => activo = v),
                ),
              ],
            ),
          actions: _modalActions(
            ctx,
            saveLabel: 'Guardar',
            saveIcon: Icons.save_rounded,
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () => Navigator.pop(ctx, true),
          ),
        ),
      ),
    );

    if (saved != true) return;

    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'nombre': nombreCtrl.text.trim(),
        'orden': momento?['orden'] ?? _momentos.length + 1,
        'hora_inicio': _normalizeTime(inicioCtrl.text),
        'hora_fin': _normalizeTime(finCtrl.text),
        'obligatorio': false,
        'activo': activo,
        'color': selectedColor,
      };
      if (momento == null) {
        await dio.post('nutricionista/momentos-comida', data: payload);
      } else {
        await dio.put('nutricionista/momentos-comida/${momento['id']}',
            data: payload);
      }
      await _loadAll();
      if (mounted) NutriSnack.show(context, 'Momento guardado');
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'No se pudo guardar el momento: $error',
            isError: true);
      }
    }
  }

  Future<void> _openDishTypeDialog([Map<String, dynamic>? tipo]) async {
    final nombreCtrl =
        TextEditingController(text: tipo?['nombre']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _modalFrame(
        width: 460,
        icon: Icons.restaurant_menu_rounded,
        title: tipo == null ? 'Nuevo tipo de platillo' : 'Editar tipo',
        subtitle:
            'Crea un tipo reutilizable para armar combinaciones en cualquier horario.',
        onClose: () => Navigator.pop(ctx, false),
        child: _dialogTextField(
            nombreCtrl,
            'Ej: Batido, Wrap, Fruta',
            Icons.restaurant_menu_rounded,
          ),
        actions: _modalActions(
          ctx,
          saveLabel: 'Guardar',
          saveIcon: Icons.save_rounded,
          onCancel: () => Navigator.pop(ctx, false),
          onSave: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (saved != true || nombreCtrl.text.trim().isEmpty) return;

    try {
      final dio = ref.read(dioProvider);
      final payload = {'nombre': nombreCtrl.text.trim()};
      if (tipo == null) {
        await dio.post('nutricionista/tipos-plato', data: payload);
      } else {
        await dio.put('nutricionista/tipos-plato/${tipo['id']}',
            data: payload);
      }
      await _loadAll();
      if (mounted) NutriSnack.show(context, 'Tipo de platillo guardado');
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'No se pudo guardar el tipo de platillo',
            isError: true);
      }
    }
  }

  Future<void> _openDetailDialog([Map<String, dynamic>? detail]) async {
    if (_selectedMomento == null) return;
    final menuName =
        'Menu ${_selectedMomento!['nombre']} ${_groupedDetailOptions().length + 1}';
    final selectedTipos = <int>{};
    final detailItems = detail?['items'];
    if (detailItems is List) {
      for (final item in detailItems) {
        if (item is Map) {
          final id = _asInt(item['id_tipo_plato']);
          if (id != null) selectedTipos.add(id);
        }
      }
    } else if (_asInt(detail?['id_tipo_plato']) != null) {
      selectedTipos.add(_asInt(detail?['id_tipo_plato'])!);
    }
    String filtroTipos = '';
    int? tipoId = _asInt(detail?['id_tipo_plato']);
    String rol = detail?['rol_permitido']?.toString() ?? 'PRINCIPAL';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => _modalFrame(
          width: 660,
          icon: Icons.ramen_dining_rounded,
          title: detail == null ? menuName : 'Editar combinacion',
          subtitle:
              'Elige que tipos de platillo pueden aparecer en ${_selectedMomento!['nombre']}. Puedes combinar varios, por ejemplo Batido + wrap.',
          onClose: () => Navigator.pop(ctx, false),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar tipo de platillo',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) =>
                      setModalState(() => filtroTipos = value.trim()),
                ),
                const SizedBox(height: 18),
                if (selectedTipos.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedTipos.map((id) {
                      final tipo = _findDishTypeById(id);
                      final nombre = tipo?['nombre']?.toString() ?? 'Tipo $id';
                      return InputChip(
                        label: Text(nombre),
                        selected: true,
                        onDeleted: () => setModalState(() {
                          selectedTipos.remove(id);
                          if (tipoId == id) {
                            tipoId = selectedTipos.isEmpty
                                ? null
                                : selectedTipos.first;
                          }
                        }),
                      );
                    }).toList(),
                  ),
                if (_tiposPlato.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _filteredDishTypes(filtroTipos).map((tipo) {
                          final id = _asInt(tipo['id']);
                          final nombre = tipo['nombre']?.toString() ?? 'Opcion';
                          final selected =
                              id != null && selectedTipos.contains(id);
                          return _menuTypeChip(
                            label: Text(nombre),
                            selected: selected,
                            onSelected: id == null
                                ? null
                                : (value) => setModalState(() {
                                      if (value) {
                                        selectedTipos.add(id);
                                        tipoId ??= id;
                                      } else {
                                        selectedTipos.remove(id);
                                        if (tipoId == id) {
                                          tipoId = selectedTipos.isEmpty
                                              ? null
                                              : selectedTipos.first;
                                        }
                                      }
                                    }),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Como se usara en el menu',
                  style: GoogleFonts.montserrat(
                    fontSize: 11.5,
                    color: AppTema.azulOscuro,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _roleChoiceCard(
                        title: 'Opcion principal',
                        subtitle: 'El sistema elegira una de estas recetas.',
                        icon: Icons.check_rounded,
                        selected: rol == 'PRINCIPAL',
                        onTap: () => setModalState(() => rol = 'PRINCIPAL'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _roleChoiceCard(
                        title: 'Acompanamiento',
                        subtitle: 'Se mostrara junto a la opcion principal.',
                        icon: Icons.add_rounded,
                        selected: rol == 'COMPLEMENTO',
                        onTap: () => setModalState(() => rol = 'COMPLEMENTO'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTema.azulPrincipal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_rounded,
                          color: AppTema.azulPrincipal, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          rol == 'PRINCIPAL'
                              ? 'Principal: el sistema elegira una de estas recetas para llenar el horario.'
                              : 'Acompanamiento: el sistema puede sumarlo a una opcion principal.',
                          style: GoogleFonts.montserrat(
                              fontSize: 11.5,
                              color: AppTema.azulPrincipal,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          actions: _modalActions(
            ctx,
            saveLabel: 'Guardar',
            saveIcon: Icons.save_rounded,
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () => Navigator.pop(ctx, true),
          ),
        ),
      ),
    );

    if (saved != true || selectedTipos.isEmpty) return;

    try {
      final dio = ref.read(dioProvider);
      if (rol == 'COMPLEMENTO') {
        _permiteComplementos = true;
        if ((_asInt(_maxComplementosCtrl.text) ?? 0) < 1) {
          _maxComplementosCtrl.text = '1';
        }
      }
      final ruleId = await _ensureRule();
      final comboOrden = _asInt(detail?['orden']) ?? _groupedDetailOptions().length + 1;
      final oldItems = _detailItems(detail);
      final oldTipoIds = oldItems
          .map((item) => _asInt(item['id_tipo_plato']))
          .whereType<int>()
          .toSet();
      final oldRol = detail?['rol_permitido']?.toString();
      if (detail != null &&
          (oldTipoIds.difference(selectedTipos).isNotEmpty ||
              selectedTipos.difference(oldTipoIds).isNotEmpty ||
              oldRol != rol)) {
        for (final oldDetail in oldItems) {
          final oldId = _asInt(oldDetail['id']);
          if (oldId != null) {
            await dio.delete('nutricionista/reglas-generales/detalle/$oldId');
          }
        }
      }
      for (final selectedTipoId in selectedTipos) {
        await dio.post('nutricionista/reglas-generales/detalle', data: {
          'id_regla_momento': ruleId,
          'id_tipo_plato': selectedTipoId,
          'rol_permitido': rol,
          'minimo': rol == 'PRINCIPAL' ? 1 : 0,
          'maximo': 1,
          'obligatorio': false,
          'orden': comboOrden,
          'activo': true,
        });
      }
      await _loadAll();
      await _loadRuleForMoment(_selectedMomento!);
      if (mounted) NutriSnack.show(context, 'Opcion guardada');
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'No se pudo guardar la opcion', isError: true);
      }
    }
  }

  // ============================================================
  // COMBINACIONES: TARJETAS Y FILTROS
  // ============================================================

  String _rolEtiqueta(String rol) {
    final found = _rolesCombinacion.firstWhere(
      (r) => r['valor'] == rol,
      orElse: () => {'etiqueta': rol},
    );
    return found['etiqueta'] as String;
  }

  Color _rolColor(String rol) {
    final found = _rolesCombinacion.firstWhere(
      (r) => r['valor'] == rol,
      orElse: () => {'color': 0xFF607D8B},
    );
    return Color(found['color'] as int);
  }

  int _filtroComboTabRol = 0;

  List<Map<String, dynamic>> _reglasPorRol(int tabIndex) {
    if (tabIndex == 0) return _reglasInteligentes;
    final rol = _rolesCombinacion[tabIndex - 1]['valor'] as String;
    return _reglasInteligentes.where((r) => r['rol'] == rol).toList();
  }

  List<Map<String, dynamic>> _getGroupedReglas() {
    final reglas = _reglasInteligentes;
    if (reglas.isEmpty) return const [];

    if (_vistaAgrupada == 'momento') {
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final r in reglas) {
        final key = r['momento_nombre']?.toString() ?? 'Sin momento';
        groups.putIfAbsent(key, () => []).add(r);
      }
      return groups.entries.map((e) => {
        'group_key': e.key,
        'items': e.value,
        'group_type': 'momento',
      }).toList();
    } else if (_vistaAgrupada == 'rol') {
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final r in reglas) {
        final rol = r['rol']?.toString() ?? 'OTRO';
        final key = _rolEtiqueta(rol);
        groups.putIfAbsent(key, () => []).add(r);
      }
      return groups.entries.map((e) => {
        'group_key': e.key,
        'items': e.value,
        'group_type': 'rol',
      }).toList();
    } else if (_vistaAgrupada == 'condicion') {
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final r in reglas) {
        final condiciones = _jsonList(r['condiciones_nutricionales']);
        if (condiciones.isEmpty) {
          groups.putIfAbsent('Sin condicion', () => []).add(r);
        } else {
          for (final c in condiciones) {
            final key = (c is Map ? c['nombre'] : c.toString()) ?? 'Sin condicion';
            groups.putIfAbsent(key, () => []).add(r);
          }
        }
      }
      return groups.entries.map((e) => {
        'group_key': e.key,
        'items': e.value,
        'group_type': 'condicion',
      }).toList();
    }
    return [{'group_key': 'Todo', 'items': reglas, 'group_type': 'todo'}];
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: _loading
          ? const Center(
              child:
                  NutriLoading(mensaje: 'Cargando configuracion del menu...'))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  if (_error != null) _buildError(),
                  _buildStats(),
                  const SizedBox(height: 24),
                  _buildDishTypesPanel(),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 260, child: _buildMomentsPanel()),
                      const SizedBox(width: 24),
                      Expanded(child: _buildRulePanel()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu y horarios',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTema.azulPrincipal,
                ),
              ),
              Text(
                'Configura tipos de platillo, momentos del dia y combinaciones para cada horario.',
                style: GoogleFonts.montserrat(
                    color: Colors.blueGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final activos = _momentos.where((m) => m['activo'] != false).length;
    return Row(
      children: [
        Expanded(
            child: NutriResumenCard(
                titulo: 'Horarios',
                valor: '${_momentos.length}',
                icon: Icons.schedule_rounded)),
        const SizedBox(width: 16),
        Expanded(
            child: NutriResumenCard(
                titulo: 'Activos',
                valor: '$activos',
                icon: Icons.check_circle_outline,
                colorValor: AppTema.verdeSalud)),
        const SizedBox(width: 16),
        Expanded(
            child: NutriResumenCard(
                titulo: 'Tipos',
                valor: '${_tiposPlato.length}',
                icon: Icons.restaurant_menu_rounded,
                colorValor: AppTema.azulOscuro)),
        const SizedBox(width: 16),
        Expanded(
            child: NutriResumenCard(
                titulo: 'Combinaciones',
                valor: '${_todasReglas.length}',
                icon: Icons.auto_awesome_rounded,
                colorValor: AppTema.verdeSalud)),
      ],
    );
  }

  Widget _buildMomentsPanel() {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle(
            'Momentos del dia',
            Icons.schedule_rounded,
            compact: true,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
              onPressed: () => _openMomentDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('HORARIO'),
                style:
                    FilledButton.styleFrom(backgroundColor: AppTema.verdeSalud),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_momentos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay horarios configurados.'),
            )
          else
            Column(
              children: _momentos
                  .map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildMomentTile(m),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDishTypesPanel() {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _panelTitle(
                  'Tipos de platillo',
                  Icons.restaurant_menu_rounded,
                  compact: true,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openDishTypeDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('NUEVO TIPO'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Estos son los tipos que puedes reutilizar para armar combinaciones.',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 14),
          if (_tiposPlato.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay tipos de platillo creados.'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tiposPlato.map(_buildDishTypeTile).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDishTypeTile(Map<String, dynamic> tipo) {
    return SizedBox(
      width: 170,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_dining_rounded,
                size: 15, color: AppTema.azulPrincipal),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                tipo['nombre']?.toString() ?? 'Tipo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppTema.azulOscuro,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Editar',
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
              onPressed: () => _openDishTypeDialog(tipo),
              icon: const Icon(Icons.edit_rounded, size: 14),
            ),
            IconButton(
              tooltip: 'Eliminar',
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
              onPressed: () => _deleteDishType(tipo),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 14, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMomentTile(Map<String, dynamic> momento) {
    final selected = _selectedMomento?['id'] == momento['id'];
    final color = _parseColor(momento['color']?.toString());
    final activo = momento['activo'] != false;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: selected
            ? AppTema.pastelCeleste.withValues(alpha: 0.45)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedMomento = momento);
            _filtroComboMomento = momento['nombre']?.toString() ?? '';
            _loadRuleForMoment(momento);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTema.azulPrincipal : Colors.grey.shade200,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        momento['nombre']?.toString() ?? 'Sin nombre',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTema.azulOscuro,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      constraints:
                          const BoxConstraints.tightFor(width: 28, height: 28),
                      padding: EdgeInsets.zero,
                      onPressed: () => _openMomentDialog(momento),
                      icon: const Icon(Icons.edit_rounded, size: 15),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      constraints:
                          const BoxConstraints.tightFor(width: 28, height: 28),
                      padding: EdgeInsets.zero,
                      onPressed: () => _deleteMoment(momento),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 15, color: Colors.redAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_timeText(momento['hora_inicio'])} - ${_timeText(momento['hora_fin'])}',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Chip(
                  label: Text(activo ? 'Activo' : 'Pausado'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      activo ? Colors.green.shade50 : Colors.grey.shade100,
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: activo ? AppTema.verdeSalud : Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRulePanel() {
    if (_selectedMomento == null) {
      return Container(
        decoration: _panelDecoration(),
        padding: const EdgeInsets.all(32),
        child: const Text('Selecciona un horario para ver sus opciones.'),
      );
    }

    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _panelTitle(
                  'Menu de ${_selectedMomento!['nombre']}',
                  Icons.restaurant_menu_rounded,
                  compact: true,
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    _detalleTipos.isEmpty ? null : _clearSelectedMomentMenu,
                icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                label: const Text('LIMPIAR'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _saving ? null : () => _saveRule(),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('GUARDAR'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildRuleHelp(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Combinaciones de este horario',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800, color: AppTema.azulOscuro),
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _openCreateCombinationDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('CREAR COMBINACION'),
                style: FilledButton.styleFrom(backgroundColor: AppTema.azulPrincipal),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _openJsonImportDialog,
                icon: const Icon(Icons.code_rounded, size: 18),
                label: const Text('CODIGO JSON'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSmartRulesPanel(),
        ],
      ),
    );
  }

  Widget _buildSmartRulesPanel() {
    if (_reglasInteligentes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Aun no hay combinaciones para este momento.',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.blueGrey,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Usa CREAR COMBINACION o CODIGO JSON para comenzar.',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.blueGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRoleTabBar(),
        const SizedBox(height: 16),
        _buildRoleTabContent(_filtroComboTabRol),
      ],
    );
  }

  Widget _buildRoleTabBar() {
    final allCount = _reglasInteligentes.length;
    final tabs = [
      _TabInfo(label: 'Todas', count: allCount, color: AppTema.azulPrincipal),
      ..._rolesCombinacion.map((r) {
        final count = _reglasPorRol(_rolesCombinacion.indexOf(r) + 1).length;
        return _TabInfo(
          label: r['etiqueta'] as String,
          count: count,
          color: Color(r['color'] as int),
        );
      }),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final tab = tabs[i];
          final selected = _filtroComboTabRol == i;
          return Material(
            color: selected ? tab.color : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => setState(() {
                _filtroComboTabRol = i;
                _paginaActual = 0;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab.label,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : tab.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: 0.25) : tab.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${tab.count}',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : tab.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleTabContent(int tabIndex) {
    final reglas = _reglasPorRol(tabIndex);
    if (reglas.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Text(
          'No hay combinaciones de este tipo',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            color: Colors.blueGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    final totalPaginas = (reglas.length / _itemsPorPagina).ceil();
    if (_paginaActual >= totalPaginas) _paginaActual = 0;
    final inicio = _paginaActual * _itemsPorPagina;
    final fin = (inicio + _itemsPorPagina < reglas.length) ? inicio + _itemsPorPagina : reglas.length;
    final paginaReglas = reglas.sublist(inicio, fin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: paginaReglas.length,
          itemBuilder: (ctx, i) => _buildCompactRuleCard(paginaReglas[i]),
        ),
        if (totalPaginas > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pagina ${_paginaActual + 1} de $totalPaginas (${reglas.length} reglas)',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _paginaActual > 0
                        ? () => setState(() => _paginaActual--)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Anterior'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _paginaActual < totalPaginas - 1
                        ? () => setState(() => _paginaActual++)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Siguiente'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTema.azulPrincipal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCompactRuleCard(Map<String, dynamic> rule) {
    final platillos = _jsonList(rule['platillos'])
        .map((item) => item is Map ? item['nombre']?.toString() : item.toString())
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    final condiciones = _jsonList(rule['condiciones_nutricionales'])
        .map((item) => item is Map ? item['nombre']?.toString() : item.toString())
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    final rol = rule['rol']?.toString() ?? 'COMBINACION';
    final rolColor = _rolColor(rol);
    final rolLabel = _rolEtiqueta(rol);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rolColor.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: rolColor.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showRuleDetail(rule),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: rolColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        rolLabel,
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: rolColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _showRuleDetail(rule),
                      child: Icon(Icons.visibility_outlined, size: 13, color: rolColor.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _deleteSmartRule(rule),
                      child: Icon(Icons.delete_outline_rounded, size: 13, color: Colors.redAccent.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  platillos.join(' + '),
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTema.azulOscuro,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (condiciones.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      condiciones.length == 1
                          ? condiciones.first
                          : '${condiciones.length} condiciones',
                      style: GoogleFonts.montserrat(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRuleDetail(Map<String, dynamic> rule) {
    final platillos = _jsonList(rule['platillos'])
        .map((item) => item is Map ? item['nombre']?.toString() : item.toString())
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .toList();
    final condiciones = _jsonList(rule['condiciones_nutricionales'])
        .map((item) => item is Map ? item['nombre']?.toString() : item.toString())
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .toList();
    final rol = rule['rol']?.toString() ?? 'COMBINACION';
    final rolLabel = _rolEtiqueta(rol);
    final momentoNombre = rule['momento_nombre']?.toString() ?? '';

    showDialog<dynamic>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(22),
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _rolColor(rol).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.restaurant_menu_rounded, color: _rolColor(rol), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rolLabel,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTema.azulOscuro,
                          ),
                        ),
                        if (momentoNombre.isNotEmpty)
                          Text(
                            momentoNombre,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Platillos
              Text(
                'Platillos',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: platillos.map((p) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTema.azulPrincipal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTema.azulPrincipal.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    p,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTema.azulPrincipal,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 14),
              // Separador
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 14),
              // Condiciones
              Text(
                'Orientacion nutricional',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: condiciones.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    c,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 18),
              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showRuleJson(rule);
                    },
                    icon: const Icon(Icons.code_rounded, size: 16),
                    label: const Text('Ver JSON'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Entendido'),
                    style: FilledButton.styleFrom(backgroundColor: AppTema.azulPrincipal),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRuleJson(Map<String, dynamic> rule) {
    final platillos = _jsonList(rule['platillos'])
        .map((item) => item is Map ? item['nombre']?.toString() : item.toString())
        .whereType<String>()
        .toList();
    final condiciones = _jsonList(rule['condiciones_nutricionales'])
        .map((item) => item is Map ? item['nombre']?.toString() : item.toString())
        .whereType<String>()
        .toList();
    final jsonStr = jsonEncode({
      'momento_comida': rule['momento_nombre'],
      'rol': rule['rol'],
      'orientacion_nutricional': condiciones,
      'platillos': platillos,
    });
    final formatted = const JsonEncoder.withIndent('  ').convert({
      'momento_comida': rule['momento_nombre'],
      'rol': rule['rol'],
      'orientacion_nutricional': condiciones,
      'platillos': platillos,
    });

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.code_rounded, color: AppTema.azulPrincipal),
                  const SizedBox(width: 10),
                  Text(
                    'JSON de la combinacion',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SelectableText(
                formatted,
                style: GoogleFonts.robotoMono(fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      // Copy to clipboard would go here
                      Navigator.pop(ctx);
                      NutriSnack.show(context, 'JSON copiado');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleHelp() {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: Colors.orangeAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Arma combinaciones con los tipos de platillo. Un mismo tipo puede repetirse en varias combinaciones.',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: AppTema.azulOscuro,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(Map<String, dynamic> detail) {
    final items = _detailItems(detail);
    final nombres = items
        .map((item) => item['tipo_plato_nombre']?.toString() ?? 'Tipo de plato')
        .toList();
    final nombre = nombres.join(' + ');
    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openDetailDialog(detail),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.fromLTRB(12, 12, 38, 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu_rounded,
                    size: 18, color: AppTema.azulPrincipal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTema.azulOscuro,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            tooltip: 'Quitar opcion',
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: () => _deleteDetailGroup(detail),
            icon: const Icon(Icons.close_rounded,
                size: 16, color: Colors.redAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
      child: Text(_error!, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _panelTitle(String title, IconData icon, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.all(compact ? 0 : 18),
      child: Row(
        children: [
          Icon(icon, color: AppTema.azulPrincipal),
          const SizedBox(width: 10),
          Text(title,
              style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTema.azulOscuro)),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4))
      ],
    );
  }

  Widget _dialogTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.montserrat(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(fontSize: 12),
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<Map<String, dynamic>> _toRows(dynamic payload) {
    if (payload is! List) return const [];
    return payload
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  List<dynamic> _jsonList(dynamic payload) {
    if (payload is List) return payload;
    if (payload is String) {
      try {
        final decoded = jsonDecode(payload);
        return decoded is List ? decoded : const [];
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Map<String, dynamic>? _findDishTypeById(int id) {
    for (final tipo in _tiposPlato) {
      if (_asInt(tipo['id']) == id) return tipo;
    }
    return null;
  }

  List<Map<String, dynamic>> _filteredDishTypes(String query) {
    final normalized = _normalizeName(query);
    if (normalized.isEmpty) return _tiposPlato;
    return _tiposPlato.where((tipo) {
      return _normalizeName(tipo['nombre']?.toString() ?? '')
          .contains(normalized);
    }).toList();
  }

  List<Map<String, dynamic>> _groupedDetailOptions() {
    final grouped = <String, Map<String, dynamic>>{};
    for (final detail in _detalleTipos) {
      final key = [
        detail['rol_permitido']?.toString() ?? '',
        detail['orden']?.toString() ?? '',
        detail['minimo']?.toString() ?? '',
        detail['maximo']?.toString() ?? '',
        detail['obligatorio'] == true ? '1' : '0',
        detail['activo'] != false ? '1' : '0',
      ].join('|');

      final group = grouped.putIfAbsent(key, () {
        final copy = Map<String, dynamic>.from(detail);
        copy['items'] = <Map<String, dynamic>>[];
        return copy;
      });
      (group['items'] as List<Map<String, dynamic>>).add(detail);
    }

    return grouped.values.map((group) {
      final items = _detailItems(group)
        ..sort((a, b) =>
            (a['tipo_plato_nombre']?.toString() ?? '').compareTo(
              b['tipo_plato_nombre']?.toString() ?? '',
            ));
      group['items'] = items;
      return group;
    }).toList()
      ..sort((a, b) => (_asInt(a['orden']) ?? 0).compareTo(_asInt(b['orden']) ?? 0));
  }

  List<Map<String, dynamic>> _detailItems(Map<String, dynamic>? detail) {
    if (detail == null) return const [];
    final items = detail['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [detail];
  }

  String _normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _timeText(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '--:--';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  String? _normalizeTime(String value) {
    final text = value.trim();
    if (text.isEmpty || text == '--:--') return null;
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(text)) {
      final parts = text.split(':');
      return '${parts[0].padLeft(2, '0')}:${parts[1]}:00';
    }
    if (RegExp(r'^\d{1,2}:\d{2}:\d{2}$').hasMatch(text)) {
      final parts = text.split(':');
      return '${parts[0].padLeft(2, '0')}:${parts[1]}:${parts[2]}';
    }
    return text;
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppTema.verdeSalud;
    final cleaned = hex.replaceAll('#', '');
    final parsed =
        int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return parsed == null ? AppTema.verdeSalud : Color(parsed);
  }
}
