import 'dart:async';
import 'dart:convert';

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

  Future<void> _deleteMoment(Map<String, dynamic> momento) async {
    final id = _asInt(momento['id']);
    if (id == null) return;
    final confirmed = await _confirmAction('Eliminar horario',
        'Se eliminara el horario "${momento['nombre']}" y sus reglas.');
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
        'Eliminar combinacion', 'Esta accion es irreversible.');
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
        'Eliminar opcion', 'Se eliminara "${tipo['nombre']}" del catalogo.');
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
              Text('Menú y Horarios',
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
            icon: const Icon(Icons.refresh_rounded,
                color: AppTema.azulPrincipal)),
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
              titulo: 'Reglas Totales',
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
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('NUEVO TIPO'),
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
                  icon: const Icon(Icons.add_box_outlined,
                      color: AppTema.verdeSalud)),
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
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _parseColor(m['color']))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['nombre'] ?? '-',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      Text(
                          '${_timeText(m['hora_inicio'])} - ${_timeText(m['hora_fin'])}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.blueGrey)),
                    ]),
              ),
              if (sel)
                const Icon(Icons.chevron_right_rounded,
                    color: AppTema.azulPrincipal),
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
            'Selecciona un horario en la izquierda para ver su configuracion clínica.'),
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
              _panelTitle('Configuración: ${_selectedMomento!['nombre']}',
                  Icons.settings_rounded,
                  compact: true),
              FilledButton.icon(
                onPressed: _saving ? null : _saveRule,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('GUARDAR CAMBIOS'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTema.azulPrincipal),
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
            Text('COMBINACIONES CLÍNICAS',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTema.azulOscuro,
                    letterSpacing: 0.5)),
            Row(
              children: [
                OutlinedButton.icon(
                    onPressed: _openJsonImportDialog,
                    icon: const Icon(Icons.code_rounded, size: 16),
                    label: const Text('JSON')),
                const SizedBox(width: 8),
                FilledButton.icon(
                    onPressed: _openCreateCombinationDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('NUEVA'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTema.verdeSalud)),
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
        Text('No hay combinaciones clinicas registradas para este momento.',
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
                    onPressed: _paginaActualReglas > 0
                        ? () => _loadRuleForMoment(_selectedMomento!,
                            page: _paginaActualReglas - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded)),
                IconButton(
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
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("CANCELAR")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("CONFIRMAR")),
        ],
      ),
    );
    return confirmed == true;
  }

  // DIALOGS
  void _openMomentDialog([Map<String, dynamic>? momento]) async {
    final nombreCtrl = TextEditingController(text: momento?['nombre'] ?? '');
    final inicioCtrl = TextEditingController(text: _timeText(momento?['hora_inicio']));
    final finCtrl = TextEditingController(text: _timeText(momento?['hora_fin']));
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(momento == null ? 'Nuevo Horario' : 'Editar Horario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: inicioCtrl, decoration: const InputDecoration(labelText: 'Inicio (HH:mm)')),
            TextField(controller: finCtrl, decoration: const InputDecoration(labelText: 'Fin (HH:mm)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          FilledButton(onPressed: () async {
            final dio = ref.read(dioProvider);
            final payload = {
              'nombre': nombreCtrl.text,
              'hora_inicio': inicioCtrl.text,
              'hora_fin': finCtrl.text,
              'activo': true,
              'color': '#2E7D32',
              'orden': momento?['orden'] ?? _momentos.length + 1
            };
            if (momento == null) {
              await dio.post('nutricionista/momentos-comida', data: payload);
            } else {
              await dio.put('nutricionista/momentos-comida/${momento['id']}', data: payload);
            }
            Navigator.pop(ctx);
            _loadAll();
          }, child: const Text('GUARDAR')),
        ],
      )
    );
  }

  void _openDishTypeDialog([Map<String, dynamic>? tipo]) async {
    final ctrl = TextEditingController(text: tipo?['nombre'] ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tipo == null ? 'Nuevo Tipo' : 'Editar Tipo'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          FilledButton(onPressed: () async {
            final dio = ref.read(dioProvider);
            if (tipo == null) {
              await dio.post('nutricionista/tipos-plato', data: {'nombre': ctrl.text});
            } else {
              await dio.put('nutricionista/tipos-plato/${tipo['id']}', data: {'nombre': ctrl.text});
            }
            Navigator.pop(ctx);
            _loadAll();
          }, child: const Text('GUARDAR')),
        ],
      )
    );
  }

  void _openCreateCombinationDialog() async {
    NutriSnack.show(context, "Utilice la importación JSON para crear combinaciones masivas.");
  }

  void _openJsonImportDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar Combinaciones (JSON)'),
        content: TextField(controller: ctrl, maxLines: 10, decoration: const InputDecoration(hintText: '{"combinaciones": [...]}')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          FilledButton(onPressed: () async {
            if (_selectedMomento == null) return;
            try {
              final data = jsonDecode(ctrl.text);
              await ref.read(dioProvider).post(
                'nutricionista/reglas-menu-combinaciones/por-momento/${_selectedMomento!['id']}/importar-json',
                data: data
              );
              Navigator.pop(ctx);
              _loadRuleForMoment(_selectedMomento!);
            } catch(e) {
              NutriSnack.show(context, "Error JSON: $e", isError: true);
            }
          }, child: const Text('IMPORTAR')),
        ],
      )
    );
  }

  void _showRuleDetail(Map<String, dynamic> rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detalle de Combinación'),
        content: SingleChildScrollView(child: SelectableText(const JsonEncoder.withIndent('  ').convert(rule))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR'))],
      )
    );
  }
}
