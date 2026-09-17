import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import '../../../../shared/widgets/shimmer_components.dart';

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
    {
      'valor': 'COMBINACION_EQUILIBRADA',
      'etiqueta': 'Equilibrada',
      'color': 0xFF2196F3
    },
    {
      'valor': 'COMBINACION_ENERGETICA',
      'etiqueta': 'Energetica',
      'color': 0xFFFF9800
    },
    {
      'valor': 'COMBINACION_RECUPERACION_NUTRICIONAL',
      'etiqueta': 'Recuperacion',
      'color': 0xFF9C27B0
    },
    {'valor': 'COMBINACION_SUAVE', 'etiqueta': 'Suave', 'color': 0xFF00BCD4},
  ];

  bool _loading = true;
  bool _loadingStats = true;
  bool _loadingDetails = false;
  bool _loadingCombinaciones = false;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _momentos = const [];
  List<Map<String, dynamic>> _tiposPlato = const [];
  List<Map<String, dynamic>> _condicionesNutricionales = const [];
  List<Map<String, dynamic>> _reglasInteligentes = const [];
  int _totalReglasGlobal = 0;
  int _totalReglas = 0;
  int _paginaActualReglas = 0;
  static const int _itemsPorPaginaReglas = 9;

  Map<String, dynamic>? _selectedMomento;
  Map<String, dynamic>? _reglaMomento;
  List<Map<String, dynamic>> _detalleTipos = const [];

  final Map<int, Map<String, dynamic>> _cacheReglasCompletas = {};

  final TextEditingController _minPrincipalesCtrl =
      TextEditingController(text: '1');
  final TextEditingController _maxPrincipalesCtrl =
      TextEditingController(text: '1');
  final TextEditingController _maxComplementosCtrl =
      TextEditingController(text: '2');
  bool _permiteComplementos = true;
  bool _reglaActiva = true;

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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadingStats = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        'nutricionista/configuracion-maestra-menu',
        queryParameters: {
          if (_selectedMomento != null)
            'id_momento_inicial': _selectedMomento!['id']
        },
      );

      final data = Map<String, dynamic>.from(response.data);
      final momentos = _toRows(data['momentos']);
      final tipos = _toRows(data['tipos_plato']);
      final condiciones = _toRows(data['condiciones']);
      final totalReglasGlobal = _asInt(data['total_reglas']) ?? 0;
      final reglaDetalleInicial = data['regla_detalle_inicial'];
      final combinacionesIniciales = data['combinaciones_iniciales'] is Map
          ? Map<String, dynamic>.from(data['combinaciones_iniciales'] as Map)
          : <String, dynamic>{};

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
        _totalReglasGlobal = totalReglasGlobal;
      });

      if (reglaDetalleInicial != null) {
        final regla = Map<String, dynamic>.from(reglaDetalleInicial as Map);
        final selectedId = selected == null ? null : _asInt(selected['id']);
        if (selectedId != null) {
          _cacheReglasCompletas[selectedId] = regla;
        }
        _aplicarReglaEnEstado(regla);
        setState(() {
          _reglasInteligentes = _toRows(combinacionesIniciales['items']);
          _totalReglas = _asInt(combinacionesIniciales['total']) ?? 0;
          _paginaActualReglas = 0;
        });
      } else if (selected != null) {
        await _loadRuleForMoment(selected);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingStats = false;
        });
      }
    }
  }

  Future<void> _loadRuleForMoment(Map<String, dynamic> momento,
      {int page = 0}) async {
    final mId = _asInt(momento['id']);
    if (mId == null) return;

    if (!mounted) return;
    setState(() {
      _loadingCombinaciones = true;
      _paginaActualReglas = page;
    });

    try {
      final dio = ref.read(dioProvider);

      Future<dynamic>? detailRequest;
      if (!_cacheReglasCompletas.containsKey(mId)) {
        setState(() => _loadingDetails = true);
        detailRequest =
            dio.get('nutricionista/reglas-generales/por-momento/$mId');
      }

      final comboRequest = dio.get(
        'nutricionista/reglas-menu-combinaciones/por-momento/$mId',
        queryParameters: {
          'limit': _itemsPorPaginaReglas,
          'offset': page * _itemsPorPaginaReglas,
          'include_total': true,
        },
      );

      if (detailRequest != null) {
        final respGral = await detailRequest;
        _cacheReglasCompletas[mId] =
            Map<String, dynamic>.from(respGral.data as Map);
      }

      final respCombo = await comboRequest;

      final comboData = Map<String, dynamic>.from(respCombo.data as Map);

      if (!mounted) return;

      _aplicarReglaEnEstado(_cacheReglasCompletas[mId]!);
      setState(() {
        _reglasInteligentes = _toRows(comboData['items']);
        _totalReglas = comboData['total'] ?? 0;
      });
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, 'Error al cargar detalles: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetails = false;
          _loadingCombinaciones = false;
        });
      }
    }
  }

  void _aplicarReglaEnEstado(Map<String, dynamic> regla) {
    final detalle = _toRows(regla['tipos_permitidos']);
    setState(() {
      _reglaMomento = regla;
      _detalleTipos = detalle;
      _minPrincipalesCtrl.text = '${regla['min_principales'] ?? 1}';
      _maxPrincipalesCtrl.text = '${regla['max_principales'] ?? 1}';
      _permiteComplementos = regla['permite_complementos'] != false;
      _maxComplementosCtrl.text = '${regla['max_complementos_total'] ?? 2}';
      _reglaActiva = regla['activo'] != false;
    });
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
      _cacheReglasCompletas.remove(_asInt(_selectedMomento!['id']));
      await _loadRuleForMoment(_selectedMomento!);
      if (mounted && showMessage) {
        NutriSnack.show(context, 'Menú guardado');
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

  Future<void> _deleteMoment(Map<String, dynamic> momento) async {
    final id = _asInt(momento['id']);
    if (id == null) return;
    final confirmed = await _confirmAction('Eliminar horario',
        'Se eliminará el horario "${momento['nombre']}" y sus reglas.');
    if (!confirmed) return;

    final oldMomentos = List<Map<String, dynamic>>.from(_momentos);
    setState(() {
      _momentos.removeWhere((m) => _asInt(m['id']) == id);
      if (_selectedMomento?['id'] == id) _selectedMomento = null;
    });

    try {
      await ref.read(dioProvider).delete('nutricionista/momentos-comida/$id');
    } catch (_) {
      setState(() => _momentos = oldMomentos);
    }
  }

  Future<void> _deleteSmartRule(Map<String, dynamic> rule) async {
    final id = _asInt(rule['id']);
    if (id == null) return;
    final confirmed = await _confirmAction(
        'Eliminar combinación', 'Esta acción es irreversible.');
    if (!confirmed) return;

    final oldRules = List<Map<String, dynamic>>.from(_reglasInteligentes);
    setState(() {
      _reglasInteligentes.removeWhere((r) => _asInt(r['id']) == id);
      _totalReglas--;
    });

    try {
      await ref
          .read(dioProvider)
          .delete('nutricionista/reglas-menu-combinaciones/$id');
    } catch (_) {
      setState(() => _reglasInteligentes = oldRules);
    }
  }

  Future<void> _deleteDishType(Map<String, dynamic> tipo) async {
    final id = _asInt(tipo['id']);
    if (id == null) return;
    final confirmed = await _confirmAction(
        'Eliminar opción', 'Se eliminará "${tipo['nombre']}" del catálogo.');
    if (!confirmed) return;

    final oldTipos = List<Map<String, dynamic>>.from(_tiposPlato);
    setState(() => _tiposPlato.removeWhere((t) => _asInt(t['id']) == id));

    try {
      await ref.read(dioProvider).delete('nutricionista/tipos-plato/$id');
    } catch (_) {
      setState(() => _tiposPlato = oldTipos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 28),
            _buildStats(),
            const SizedBox(height: 24),
            _buildDishTypesPanel(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 280, child: _buildMomentsPanel()),
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
              Text('Menú y horarios',
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTema.azulPrincipal)),
              Text(
                  'Gestión técnica de tiempos de comida y combinaciones clínicas.',
                  style:
                      GoogleFonts.inter(color: Colors.blueGrey, fontSize: 13)),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadAll,
          tooltip: 'Actualizar configuración',
          icon: const Icon(Icons.refresh_rounded,
              size: 22, color: AppTema.azulPrincipal),
          style: IconButton.styleFrom(
            backgroundColor: AppTema.azulPrincipal.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    if (_loadingStats) {
      return const Row(children: [
        Expanded(child: NutriResumenCardShimmer()),
        SizedBox(width: 16),
        Expanded(child: NutriResumenCardShimmer()),
        SizedBox(width: 16),
        Expanded(child: NutriResumenCardShimmer()),
      ]);
    }
    return Row(children: [
      Expanded(
          child: NutriResumenCard(
              titulo: 'Horarios',
              valor: '${_momentos.length}',
              icon: Icons.schedule_rounded)),
      const SizedBox(width: 16),
      Expanded(
          child: NutriResumenCard(
              titulo: 'Opciones',
              valor: '${_tiposPlato.length}',
              icon: Icons.restaurant_menu_rounded,
              colorValor: AppTema.verdeSalud)),
      const SizedBox(width: 16),
      Expanded(
          child: NutriResumenCard(
              titulo: 'Reglas totales',
              valor: '$_totalReglasGlobal',
              icon: Icons.auto_awesome_rounded,
              colorValor: AppTema.azulOscuro)),
    ]);
  }

  Widget _buildDishTypesPanel() {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _panelTitle('Tipos de platillo disponibles',
                  Icons.restaurant_rounded,
                  compact: true),
              OutlinedButton.icon(
                onPressed: () => _openDishTypeDialog(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTema.azulOscuro,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Nuevo tipo',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading && _tiposPlato.isEmpty)
            const Wrap(spacing: 12, children: [
              NutriShimmer(width: 120, height: 40),
              NutriShimmer(width: 120, height: 40)
            ])
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _tiposPlato.map((t) => _buildDishTypeTile(t)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDishTypeTile(Map<String, dynamic> t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_dining_rounded,
              size: 14, color: AppTema.azulPrincipal),
          const SizedBox(width: 8),
          Text(t['nombre'] ?? '-',
              style:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          InkWell(
              onTap: () => _deleteDishType(t),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildMomentsPanel() {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _panelTitle('Horarios', Icons.alarm_rounded, compact: true),
              IconButton(
                onPressed: () => _openMomentDialog(),
                tooltip: 'Nuevo horario',
                icon: const Icon(Icons.add_rounded,
                    size: 20, color: AppTema.verdeSalud),
                style: IconButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading && _momentos.isEmpty)
            const Column(children: [
              NutriCardShimmer(height: 80),
              SizedBox(height: 12),
              NutriCardShimmer(height: 80)
            ])
          else
            ..._momentos.map((m) => _buildMomentTile(m)),
        ],
      ),
    );
  }

  Widget _buildMomentTile(Map<String, dynamic> m) {
    final sel = _selectedMomento?['id'] == m['id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          setState(() => _selectedMomento = m);
          _loadRuleForMoment(m);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel
                ? AppTema.azulPrincipal.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? AppTema.azulPrincipal : Colors.grey.shade200,
                width: sel ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _parseColor(m['color']))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['nombre'] ?? '-',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                          Text(
                              '${_timeText(m['hora_inicio'])} - ${_timeText(m['hora_fin'])}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey)),
                        ],
                      ),
                    ]),
              ),
              IconButton(
                tooltip: 'Editar horario e intervalo',
                icon: const Icon(Icons.edit_outlined,
                    size: 16, color: AppTema.azulPrincipal),
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _openMomentDialog(m),
              ),
              if (sel)
                const Icon(Icons.chevron_right_rounded,
                    color: AppTema.azulPrincipal, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRulePanel() {
    if (_selectedMomento == null) {
      return Container(
        decoration: _panelDecoration(),
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const Text(
            'Selecciona un horario en la izquierda para ver su configuración clínica.'),
      );
    }

    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _panelTitle('Configuración: ${_selectedMomento!['nombre']}',
                        Icons.settings_rounded,
                        compact: true),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _openMomentDialog(_selectedMomento),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTema.azulPrincipal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTema.azulPrincipal
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 13, color: AppTema.azulPrincipal),
                            const SizedBox(width: 6),
                            Text(
                              'Intervalo: ${_timeText(_selectedMomento!['hora_inicio'])} - ${_timeText(_selectedMomento!['hora_fin'])}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTema.azulPrincipal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_rounded,
                                size: 12, color: AppTema.azulPrincipal),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _saveRule,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  'Guardar cambios',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.azulPrincipal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loadingDetails)
            const Column(children: [
              NutriCardShimmer(height: 100),
              SizedBox(height: 12),
              NutriCardShimmer(height: 100)
            ])
          else ...[
            _buildSmartRulesPanel(),
          ],
        ],
      ),
    );
  }

  Widget _buildSmartRulesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Combinaciones clínicas',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTema.azulOscuro,
                    letterSpacing: 0.5)),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _openJsonImportDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTema.azulOscuro,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.code_rounded, size: 16),
                  label: Text('JSON',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _openCreateCombinationDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTema.verdeSalud,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Nueva',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingCombinaciones)
          _buildShimmerGrid()
        else if (_reglasInteligentes.isEmpty)
          _buildEmptyCombinations()
        else
          _buildCombinationsGrid(),
      ],
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: 6,
      itemBuilder: (_, __) =>
          const NutriShimmer(width: double.infinity, height: 80),
    );
  }

  Widget _buildEmptyCombinations() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
      child: const Column(children: [
        Icon(Icons.auto_awesome_rounded, size: 40, color: Colors.grey),
        SizedBox(height: 12),
        Text('No hay combinaciones clínicas registradas para este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildCombinationsGrid() {
    final totalPaginas = (_totalReglas / _itemsPorPaginaReglas).ceil();
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: _reglasInteligentes.length,
          itemBuilder: (ctx, i) => _buildCompactRuleCard(_reglasInteligentes[i]),
        ),
        if (totalPaginas > 1) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  'Página ${_paginaActualReglas + 1} de $totalPaginas ($_totalReglas reglas)',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey)),
              Row(children: [
                IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _paginaActualReglas > 0
                        ? () => _loadRuleForMoment(_selectedMomento!,
                            page: _paginaActualReglas - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded)),
                const SizedBox(width: 4),
                IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _paginaActualReglas < totalPaginas - 1
                        ? () => _loadRuleForMoment(_selectedMomento!,
                            page: _paginaActualReglas + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded)),
              ]),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCompactRuleCard(Map<String, dynamic> rule) {
    final platillos =
        _jsonList(rule['platillos']).map((e) => e is Map ? e['nombre'] : e).toList();
    final rol = rule['rol']?.toString() ?? 'COMBINACION';
    final color = _rolColor(rol);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _badge(rol.split('_').last, color),
              Row(children: [
                InkWell(
                    onTap: () => _showRuleDetail(rule),
                    child:
                        Icon(Icons.visibility_outlined, size: 14, color: color)),
                const SizedBox(width: 8),
                InkWell(
                    onTap: () => _deleteSmartRule(rule),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 14, color: Colors.redAccent)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
              child: Text(platillos.join(' + '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTema.azulOscuro))),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200));
  Widget _panelTitle(String t, IconData i, {bool compact = false}) =>
      Row(children: [
        Icon(i, size: 18, color: AppTema.azulPrincipal),
        const SizedBox(width: 8),
        Text(t,
            style: GoogleFonts.montserrat(
                fontSize: compact ? 12 : 14, fontWeight: FontWeight.w800))
      ]);

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
        return jsonDecode(payload) as List;
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppTema.verdeSalud;
    final cleaned = hex.replaceAll('#', '');
    final parsed =
        int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return parsed == null ? AppTema.verdeSalud : Color(parsed);
  }

  String _timeText(dynamic v) {
    final s = v?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : '--:--';
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

  TimeOfDay _parseTimeOfDay(dynamic val) {
    final s = val?.toString().trim() ?? '';
    if (s.isEmpty || s == '--:--') return const TimeOfDay(hour: 8, minute: 0);
    final parts = s.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 8;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Color _rolColor(String rol) {
    final found = _rolesCombinacion.firstWhere((r) => r['valor'] == rol,
        orElse: () => {'color': 0xFF607D8B});
    return Color(found['color'] as int);
  }

  String _rolEtiqueta(String rol) {
    final found = _rolesCombinacion.firstWhere((r) => r['valor'] == rol,
        orElse: () => {'etiqueta': rol});
    return found['etiqueta'] as String;
  }

  Future<bool> _confirmAction(String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        title: Text(title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(message,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.blueGrey.shade800)),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueGrey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
                child: Text("Cancelar",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.azulPrincipal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
                child: Text("Confirmar",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  // DIALOGS
  void _openMomentDialog([Map<String, dynamic>? momento]) async {
    final nombreCtrl = TextEditingController(text: momento?['nombre'] ?? '');
    final inicioCtrl = TextEditingController(
        text: momento?['hora_inicio'] != null
            ? _timeText(momento!['hora_inicio'])
            : '08:00');
    final finCtrl = TextEditingController(
        text: momento?['hora_fin'] != null
            ? _timeText(momento!['hora_fin'])
            : '09:00');
    String selectedColor = momento?['color'] ?? '#2E7D32';
    bool isSubmitting = false;
    final hostContext = context;

    Future<void> pickTime(
        BuildContext ctx, TextEditingController ctrl, StateSetter setDialogState) async {
      final initial = _parseTimeOfDay(ctrl.text);
      final picked = await showTimePicker(
        context: ctx,
        initialTime: initial,
        helpText: 'SELECCIONAR HORA',
        cancelText: 'CANCELAR',
        confirmText: 'ACEPTAR',
      );
      if (picked != null) {
        setDialogState(() {
          ctrl.text = _formatTimeOfDay(picked);
        });
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTema.azulPrincipal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule_rounded,
                    color: AppTema.azulPrincipal, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  momento == null
                      ? 'Nuevo horario de comida'
                      : 'Editar horario e intervalo',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Nombre del horario',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ej. Desayuno, Media Mañana, Almuerzo',
                      prefixIcon:
                          const Icon(Icons.restaurant_menu_rounded, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Intervalo de horas (Inicio - Fin)',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: inicioCtrl,
                          keyboardType: TextInputType.datetime,
                          decoration: InputDecoration(
                            labelText: 'Hora inicio',
                            hintText: 'HH:mm',
                            prefixIcon: const Icon(Icons.alarm_on_rounded,
                                size: 18, color: AppTema.verdeSalud),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.access_time_rounded,
                                  size: 18),
                              tooltip: 'Seleccionar hora',
                              onPressed: () =>
                                  pickTime(context, inicioCtrl, setModalState),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: finCtrl,
                          keyboardType: TextInputType.datetime,
                          decoration: InputDecoration(
                            labelText: 'Hora fin',
                            hintText: 'HH:mm',
                            prefixIcon: const Icon(Icons.alarm_off_rounded,
                                size: 18, color: Colors.orange),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.access_time_rounded,
                                  size: 18),
                              tooltip: 'Seleccionar hora',
                              onPressed: () =>
                                  pickTime(context, finCtrl, setModalState),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Color identificador',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _momentColorOptions.map((c) {
                      final parsed = _parseColor(c);
                      final isSelected =
                          selectedColor.toUpperCase() == c.toUpperCase();
                      return InkWell(
                        onTap: () => setModalState(() => selectedColor = c),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: parsed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTema.azulOscuro
                                  : Colors.white,
                              width: isSelected ? 3 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          actions: [
            Row(
              children: [
                if (momento != null)
                  OutlinedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _deleteMoment(momento);
                          },
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red),
                    label: Text('Eliminar',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                const Spacer(),
                OutlinedButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
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
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nombre = nombreCtrl.text.trim();
                          if (nombre.isEmpty) {
                            NutriSnack.show(
                                hostContext, 'El nombre del horario es requerido',
                                isError: true);
                            return;
                          }
                          final hInicio = _normalizeTime(inicioCtrl.text);
                          final hFin = _normalizeTime(finCtrl.text);

                          setModalState(() => isSubmitting = true);
                          try {
                            final dio = ref.read(dioProvider);
                            final payload = {
                              'nombre': nombre,
                              'hora_inicio': hInicio,
                              'hora_fin': hFin,
                              'color': selectedColor,
                              'activo': momento?['activo'] ?? true,
                              'orden': momento?['orden'] ?? (_momentos.length + 1),
                            };

                            if (momento == null) {
                              await dio.post('nutricionista/momentos-comida',
                                  data: payload);
                            } else {
                              await dio.put(
                                  'nutricionista/momentos-comida/${momento['id']}',
                                  data: payload);
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (momento != null &&
                                _selectedMomento?['id'] == momento['id']) {
                              setState(() {
                                _selectedMomento = {
                                  ..._selectedMomento!,
                                  'nombre': nombre,
                                  'hora_inicio': hInicio,
                                  'hora_fin': hFin,
                                  'color': selectedColor,
                                };
                              });
                            }
                            await _loadAll();
                            if (mounted) {
                              NutriSnack.show(
                                hostContext,
                                momento == null
                                    ? 'Horario creado exitosamente'
                                    : 'Horario e intervalo actualizados exitosamente',
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (mounted) {
                              NutriSnack.show(
                                  hostContext, 'Error al guardar horario: $e',
                                  isError: true);
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    momento == null
                        ? 'Crear horario'
                        : 'Guardar intervalo',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTema.azulPrincipal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDishTypeDialog([Map<String, dynamic>? tipo]) async {
    final ctrl = TextEditingController(text: tipo?['nombre'] ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        title: Text(
          tipo == null ? 'Nuevo tipo de platillo' : 'Editar tipo de platillo',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre del tipo',
            hintText: 'Ej. ENSALADA, GUARNICIÓN',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueGrey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade700),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () async {
                  final text = ctrl.text.trim();
                  if (text.isEmpty) return;
                  final dio = ref.read(dioProvider);
                  if (tipo == null) {
                    await dio.post('nutricionista/tipos-plato',
                        data: {'nombre': text});
                  } else {
                    await dio.put('nutricionista/tipos-plato/${tipo['id']}',
                        data: {'nombre': text});
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAll();
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  'Guardar',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.azulPrincipal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCreateCombinationDialog() async {
    if (_selectedMomento == null) {
      NutriSnack.show(
          context,
          'Por favor, selecciona primero un horario en la lista izquierda.',
          isError: true);
      return;
    }

    if (_tiposPlato.isEmpty) {
      NutriSnack.show(
          context,
          'No hay tipos de plato registrados para crear combinaciones.',
          isError: true);
      return;
    }

    final hostContext = context;
    String selectedRol = _rolesCombinacion.isNotEmpty
        ? _rolesCombinacion[0]['valor'] as String
        : 'COMBINACION_EQUILIBRADA';
    final Set<String> selectedPlatillos = {};
    final Set<int> selectedCondiciones = {};
    String queryPlatillos = '';
    String queryCondiciones = '';
    int currentTab = 0; // 0: Rol, 1: Platillos, 2: Condiciones
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredTipos = _tiposPlato.where((t) {
            final nombre = (t['nombre']?.toString() ?? '').toLowerCase();
            return nombre.contains(queryPlatillos.toLowerCase());
          }).toList();

          final filteredCondiciones = _condicionesNutricionales.where((c) {
            final nombre = (c['nombre']?.toString() ?? '').toLowerCase();
            return nombre.contains(queryCondiciones.toLowerCase());
          }).toList();

          final rolData = _rolesCombinacion.firstWhere(
            (r) => r['valor'] == selectedRol,
            orElse: () => {'color': 0xFF2196F3, 'etiqueta': selectedRol},
          );
          final currentRolColor = Color(rolData['color'] as int);

          Widget buildTabItem(int index, String title, IconData icon,
              {String? badge}) {
            final active = currentTab == index;
            return Expanded(
              child: InkWell(
                onTap: () => setModalState(() => currentTab = index),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          size: 15,
                          color:
                              active ? AppTema.azulPrincipal : Colors.blueGrey),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color:
                                active ? AppTema.azulOscuro : Colors.blueGrey,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: active
                                ? AppTema.azulPrincipal
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }

          Widget buildTabContent() {
            switch (currentTab) {
              case 0:
                // --- TAB 1: ROL NUTRICIONAL ---
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selecciona el enfoque clínico de esta combinación:',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.blueGrey),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: currentRolColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rolData['etiqueta'] as String,
                            style: TextStyle(
                              color: currentRolColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.8,
                        ),
                        itemCount: _rolesCombinacion.length,
                        itemBuilder: (_, i) {
                          final rol = _rolesCombinacion[i];
                          final val = rol['valor'] as String;
                          final label = rol['etiqueta'] as String;
                          final color = Color(rol['color'] as int);
                          final isSel = selectedRol == val;

                          return InkWell(
                            onTap: () => setModalState(() => selectedRol = val),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? color.withValues(alpha: 0.08)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel ? color : Colors.grey.shade200,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: isSel
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color:
                                            isSel ? color : AppTema.azulOscuro,
                                      ),
                                    ),
                                  ),
                                  if (isSel)
                                    Icon(Icons.check_circle_rounded,
                                        color: color, size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );

              case 1:
                // --- TAB 2: PLATILLOS ---
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Selecciona los platillos que componen la comida (mínimo 2):',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.blueGrey),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: selectedPlatillos.length >= 2
                                ? Colors.green.shade50
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selectedPlatillos.length >= 2
                                  ? Colors.green.shade200
                                  : Colors.amber.shade200,
                            ),
                          ),
                          child: Text(
                            '${selectedPlatillos.length} seleccionados (mín. 2)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selectedPlatillos.length >= 2
                                  ? Colors.green.shade800
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar tipo de platillo...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) => setModalState(() => queryPlatillos = v),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredTipos.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron platillos con esa búsqueda',
                                style: TextStyle(
                                    color: Colors.blueGrey, fontSize: 12),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filteredTipos.map((tipo) {
                                  final nombre =
                                      tipo['nombre']?.toString() ?? '';
                                  final isSel =
                                      selectedPlatillos.contains(nombre);
                                  return FilterChip(
                                    label: Text(nombre),
                                    selected: isSel,
                                    avatar: Icon(
                                      isSel
                                          ? Icons.check_circle_rounded
                                          : Icons.restaurant_rounded,
                                      size: 16,
                                      color: isSel
                                          ? Colors.white
                                          : AppTema.azulPrincipal,
                                    ),
                                    selectedColor: AppTema.azulPrincipal,
                                    backgroundColor: Colors.white,
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSel
                                          ? Colors.white
                                          : AppTema.azulOscuro,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: isSel
                                            ? AppTema.azulPrincipal
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      setModalState(() {
                                        if (selected) {
                                          selectedPlatillos.add(nombre);
                                        } else {
                                          selectedPlatillos.remove(nombre);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                );

              case 2:
              default:
                // --- TAB 3: CONDICIONES ---
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Indica para qué diagnósticos o perfiles nutricionales aplica (mínimo 1):',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.blueGrey),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: selectedCondiciones.isNotEmpty
                                ? Colors.green.shade50
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selectedCondiciones.isNotEmpty
                                  ? Colors.green.shade200
                                  : Colors.amber.shade200,
                            ),
                          ),
                          child: Text(
                            '${selectedCondiciones.length} seleccionadas (mín. 1)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selectedCondiciones.isNotEmpty
                                  ? Colors.green.shade800
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar condición clínica...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) =>
                          setModalState(() => queryCondiciones = v),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredCondiciones.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron condiciones con esa búsqueda',
                                style: TextStyle(
                                    color: Colors.blueGrey, fontSize: 12),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filteredCondiciones.map((cond) {
                                  final id = _asInt(cond['id']);
                                  final nombre =
                                      cond['nombre']?.toString() ?? '';
                                  if (id == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final isSel =
                                      selectedCondiciones.contains(id);
                                  return FilterChip(
                                    label: Text(nombre),
                                    selected: isSel,
                                    avatar: Icon(
                                      isSel
                                          ? Icons.check_circle_rounded
                                          : Icons.health_and_safety_rounded,
                                      size: 16,
                                      color: isSel
                                          ? Colors.white
                                          : AppTema.verdeSalud,
                                    ),
                                    selectedColor: AppTema.verdeSalud,
                                    backgroundColor: Colors.white,
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSel
                                          ? Colors.white
                                          : Colors.green.shade900,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: isSel
                                            ? AppTema.verdeSalud
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      setModalState(() {
                                        if (selected) {
                                          selectedCondiciones.add(id);
                                        } else {
                                          selectedCondiciones.remove(id);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                );
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTema.verdeSalud.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppTema.verdeSalud, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nueva combinación clínica',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Para el horario: ${_selectedMomento!['nombre']}',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  // --- PESTAÑAS (SEGMENTED TABS) ---
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        buildTabItem(0, '1. Rol', Icons.tune_rounded),
                        const SizedBox(width: 4),
                        buildTabItem(1, '2. Platillos',
                            Icons.restaurant_menu_rounded,
                            badge: '${selectedPlatillos.length}'),
                        const SizedBox(width: 4),
                        buildTabItem(2, '3. Condiciones',
                            Icons.health_and_safety_rounded,
                            badge: '${selectedCondiciones.length}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- CONTENIDO DE LA PESTAÑA ACTIVA (SIN SCROLL GENERAL) ---
                  SizedBox(
                    height: 320,
                    child: buildTabContent(),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
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
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (selectedPlatillos.length < 2) {
                              setModalState(() => currentTab = 1);
                              NutriSnack.show(
                                hostContext,
                                'Debes seleccionar al menos 2 tipos de platillos para la combinación.',
                                isError: true,
                              );
                              return;
                            }
                            if (selectedCondiciones.isEmpty) {
                              setModalState(() => currentTab = 2);
                              NutriSnack.show(
                                hostContext,
                                'Debes seleccionar al menos una condición clínica aplicable.',
                                isError: true,
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            try {
                              final dio = ref.read(dioProvider);
                              final payload = {
                                'id_momento':
                                    _asInt(_selectedMomento!['id']),
                                'rol': selectedRol,
                                'platillos': selectedPlatillos.toList(),
                                'condiciones_ids':
                                    selectedCondiciones.toList(),
                              };
                              await dio.post(
                                  'nutricionista/reglas-menu-combinaciones',
                                  data: payload);

                              if (ctx.mounted) Navigator.pop(ctx);
                              _cacheReglasCompletas.remove(
                                  _asInt(_selectedMomento!['id']));
                              await _loadRuleForMoment(_selectedMomento!);
                              setState(() {
                                _totalReglasGlobal++;
                              });
                              if (mounted) {
                                NutriSnack.show(
                                  hostContext,
                                  'Combinación clínica guardada con éxito',
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              String errorMsg =
                                  'Error al guardar combinación: $e';
                              if (e is DioException &&
                                  e.response?.data != null) {
                                final data = e.response!.data;
                                if (data is Map && data['detail'] != null) {
                                  errorMsg = data['detail'].toString();
                                }
                              }
                              if (mounted) {
                                NutriSnack.show(
                                  hostContext,
                                  errorMsg,
                                  isError: true,
                                );
                              }
                            }
                          },
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      'Guardar combinación',
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
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _openJsonImportDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        title: Text(
          'Importar combinaciones (JSON)',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: ctrl,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: '{\n  "combinaciones": [...]\n}',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueGrey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade700),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () async {
                  if (_selectedMomento == null) return;
                  try {
                    final data = jsonDecode(ctrl.text);
                    await ref.read(dioProvider).post(
                      'nutricionista/reglas-menu-combinaciones/por-momento/${_selectedMomento!['id']}/importar-json',
                      data: data,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadRuleForMoment(_selectedMomento!);
                  } catch (e) {
                    NutriSnack.show(context, "Error JSON: $e", isError: true);
                  }
                },
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: Text(
                  'Importar',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRuleDetail(Map<String, dynamic> rule) {
    final platillos = _jsonList(rule['platillos'])
        .map((item) =>
            item is Map ? item['nombre']?.toString() : item.toString())
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .toList();
    final condiciones = _jsonList(rule['condiciones_nutricionales'])
        .map((item) =>
            item is Map ? item['nombre']?.toString() : item.toString())
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .toList();
    final rol = rule['rol']?.toString() ?? 'COMBINACION';
    final color = _rolColor(rol);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_menu_rounded,
                  color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detalle de combinación',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    _rolEtiqueta(rol),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text('Platillos que la conforman:',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTema.azulOscuro)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: platillos
                      .map((p) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTema.azulPrincipal
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTema.azulPrincipal
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_dining_rounded,
                                    size: 13,
                                    color: AppTema.azulPrincipal),
                                const SizedBox(width: 6),
                                Text(
                                  p,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTema.azulPrincipal,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text('Condiciones clínicas asociadas:',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTema.azulOscuro)),
                const SizedBox(height: 8),
                if (condiciones.isEmpty)
                  Text('Aplica a todas las condiciones por defecto',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.blueGrey))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: condiciones
                        .map((c) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.health_and_safety_rounded,
                                      size: 13,
                                      color: Colors.green.shade800),
                                  const SizedBox(width: 6),
                                  Text(
                                    c,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  'Entendido',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.azulPrincipal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
