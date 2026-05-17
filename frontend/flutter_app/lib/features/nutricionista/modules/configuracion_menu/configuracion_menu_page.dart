import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';

class ConfiguracionMenuPage extends ConsumerStatefulWidget {
  const ConfiguracionMenuPage({super.key});

  @override
  ConsumerState<ConfiguracionMenuPage> createState() => _ConfiguracionMenuPageState();
}

class _ConfiguracionMenuPageState extends ConsumerState<ConfiguracionMenuPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _momentos = const [];
  List<Map<String, dynamic>> _tiposPlato = const [];
  Map<String, dynamic>? _selectedMomento;
  Map<String, dynamic>? _reglaMomento;
  List<Map<String, dynamic>> _detalleTipos = const [];

  final TextEditingController _minPrincipalesCtrl = TextEditingController(text: '1');
  final TextEditingController _maxPrincipalesCtrl = TextEditingController(text: '1');
  final TextEditingController _maxComplementosCtrl = TextEditingController(text: '2');
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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get('nutricionista/momentos-comida'),
        dio.get('nutricionista/tipos-plato'),
      ]);

      final momentos = _toRows(results[0].data);
      final tipos = _toRows(results[1].data);
      Map<String, dynamic>? selected = momentos.isNotEmpty ? momentos.first : null;
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
        _selectedMomento = selected;
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
      final response = await dio.get('nutricionista/reglas-generales/por-momento/${momento['id']}');
      final regla = Map<String, dynamic>.from(response.data as Map);
      final detalle = _toRows(regla['tipos_permitidos']);
      if (!mounted) return;
      setState(() {
        _reglaMomento = regla;
        _detalleTipos = detalle;
        _minPrincipalesCtrl.text = '${regla['min_principales'] ?? 1}';
        _maxPrincipalesCtrl.text = '${regla['max_principales'] ?? 1}';
        _permiteComplementos = regla['permite_complementos'] != false;
        _maxComplementosCtrl.text = '${regla['max_complementos_total'] ?? 2}';
        _reglaActiva = regla['activo'] != false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reglaMomento = null;
        _detalleTipos = const [];
        _minPrincipalesCtrl.text = '1';
        _maxPrincipalesCtrl.text = '1';
        _permiteComplementos = true;
        _maxComplementosCtrl.text = '2';
        _reglaActiva = true;
      });
    }
  }

  Future<int> _ensureRule() async {
    if (_selectedMomento == null) throw Exception('Selecciona un momento de comida');
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
        'max_complementos_total': _permiteComplementos ? (_asInt(_maxComplementosCtrl.text) ?? 0) : 0,
        'activo': _reglaActiva,
      };
      await dio.post('nutricionista/reglas-generales', data: payload);
      await _loadRuleForMoment(_selectedMomento!);
      if (mounted && showMessage) {
        NutriSnack.show(context, 'Regla de menu guardada');
      }
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'Error al guardar regla: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteDetail(int id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('nutricionista/reglas-generales/detalle/$id');
      if (_selectedMomento != null) await _loadRuleForMoment(_selectedMomento!);
    } catch (error) {
      if (mounted) {
        NutriSnack.show(context, 'No se pudo quitar el tipo de plato', isError: true);
      }
    }
  }

  Future<void> _openMomentDialog([Map<String, dynamic>? momento]) async {
    final nombreCtrl = TextEditingController(text: momento?['nombre']?.toString() ?? '');
    final ordenCtrl = TextEditingController(text: '${momento?['orden'] ?? _momentos.length + 1}');
    final inicioCtrl = TextEditingController(text: _timeText(momento?['hora_inicio']));
    final finCtrl = TextEditingController(text: _timeText(momento?['hora_fin']));
    final colorCtrl = TextEditingController(text: momento?['color']?.toString() ?? '#4CAF50');
    bool obligatorio = momento?['obligatorio'] == true;
    bool activo = momento?['activo'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(momento == null ? 'Nuevo momento' : 'Editar momento'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogTextField(nombreCtrl, 'Nombre', Icons.restaurant_rounded),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dialogTextField(ordenCtrl, 'Orden', Icons.sort_rounded, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _dialogTextField(colorCtrl, 'Color', Icons.palette_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dialogTextField(inicioCtrl, 'Hora inicio (HH:mm)', Icons.schedule_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _dialogTextField(finCtrl, 'Hora fin (HH:mm)', Icons.schedule_rounded)),
                  ],
                ),
                SwitchListTile(
                  value: obligatorio,
                  title: const Text('Obligatorio en el plan'),
                  onChanged: (v) => setModalState(() => obligatorio = v),
                ),
                SwitchListTile(
                  value: activo,
                  title: const Text('Activo'),
                  onChanged: (v) => setModalState(() => activo = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('GUARDAR')),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'nombre': nombreCtrl.text.trim(),
        'orden': _asInt(ordenCtrl.text) ?? 0,
        'hora_inicio': _normalizeTime(inicioCtrl.text),
        'hora_fin': _normalizeTime(finCtrl.text),
        'obligatorio': obligatorio,
        'activo': activo,
        'color': colorCtrl.text.trim().isEmpty ? '#4CAF50' : colorCtrl.text.trim(),
      };
      if (momento == null) {
        await dio.post('nutricionista/momentos-comida', data: payload);
      } else {
        await dio.put('nutricionista/momentos-comida/${momento['id']}', data: payload);
      }
      await _loadAll();
      if (mounted) NutriSnack.show(context, 'Momento guardado');
    } catch (error) {
      if (mounted) NutriSnack.show(context, 'No se pudo guardar el momento: $error', isError: true);
    }
  }

  Future<void> _openDishTypeDialog() async {
    final nombreCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo tipo de plato'),
        content: SizedBox(width: 420, child: _dialogTextField(nombreCtrl, 'Nombre', Icons.restaurant_menu_rounded)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CREAR')),
        ],
      ),
    );
    if (saved != true || nombreCtrl.text.trim().isEmpty) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.post('nutricionista/tipos-plato', data: {'nombre': nombreCtrl.text.trim()});
      await _loadAll();
      if (mounted) NutriSnack.show(context, 'Tipo de plato creado');
    } catch (error) {
      if (mounted) NutriSnack.show(context, 'No se pudo crear el tipo de plato', isError: true);
    }
  }

  Future<void> _openDetailDialog([Map<String, dynamic>? detail]) async {
    if (_selectedMomento == null) return;
    int? tipoId = _asInt(detail?['id_tipo_plato']);
    String rol = detail?['rol_permitido']?.toString() ?? 'PRINCIPAL';
    final minimoCtrl = TextEditingController(text: '${detail?['minimo'] ?? (rol == 'PRINCIPAL' ? 1 : 0)}');
    final maximoCtrl = TextEditingController(text: '${detail?['maximo'] ?? 1}');
    final ordenCtrl = TextEditingController(text: '${detail?['orden'] ?? _detalleTipos.length + 1}');
    bool obligatorio = detail?['obligatorio'] == true;
    bool activo = detail?['activo'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Tipo de plato del momento'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: tipoId,
                  decoration: const InputDecoration(labelText: 'Tipo de plato', prefixIcon: Icon(Icons.restaurant_menu_rounded)),
                  items: _tiposPlato.where((t) => _asInt(t['id']) != null).map((t) {
                    return DropdownMenuItem<int>(
                      value: _asInt(t['id'])!,
                      child: Text(t['nombre']?.toString() ?? 'Sin nombre'),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => tipoId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: rol,
                  decoration: const InputDecoration(labelText: 'Rol en el menu', prefixIcon: Icon(Icons.account_tree_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'PRINCIPAL', child: Text('Principal')),
                    DropdownMenuItem(value: 'COMPLEMENTO', child: Text('Complemento')),
                  ],
                  onChanged: (v) => setModalState(() => rol = v ?? 'PRINCIPAL'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dialogTextField(minimoCtrl, 'Minimo', Icons.remove_rounded, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _dialogTextField(maximoCtrl, 'Maximo', Icons.add_rounded, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _dialogTextField(ordenCtrl, 'Orden', Icons.sort_rounded, keyboardType: TextInputType.number)),
                  ],
                ),
                SwitchListTile(
                  value: obligatorio,
                  title: const Text('Obligatorio'),
                  onChanged: (v) => setModalState(() => obligatorio = v),
                ),
                SwitchListTile(
                  value: activo,
                  title: const Text('Activo'),
                  onChanged: (v) => setModalState(() => activo = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('GUARDAR')),
          ],
        ),
      ),
    );

    if (saved != true || tipoId == null) return;

    try {
      final dio = ref.read(dioProvider);
      final ruleId = await _ensureRule();
      await dio.post('nutricionista/reglas-generales/detalle', data: {
        'id_regla_momento': ruleId,
        'id_tipo_plato': tipoId,
        'rol_permitido': rol,
        'minimo': _asInt(minimoCtrl.text) ?? 0,
        'maximo': _asInt(maximoCtrl.text) ?? 1,
        'obligatorio': obligatorio,
        'orden': _asInt(ordenCtrl.text) ?? 0,
        'activo': activo,
      });
      await _loadRuleForMoment(_selectedMomento!);
      if (mounted) NutriSnack.show(context, 'Componente del menu guardado');
    } catch (error) {
      if (mounted) NutriSnack.show(context, 'No se pudo guardar el componente', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: _loading
          ? const Center(child: NutriLoading(mensaje: 'Cargando configuracion del menu...'))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  if (_error != null) _buildError(),
                  _buildStats(),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: _buildMomentsPanel()),
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
                'Configuracion del Menu',
                style: GoogleFonts.montserrat(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTema.azulPrincipal,
                ),
              ),
              Text(
                'Define horarios, momentos del dia y que tipos de plato forman cada comida.',
                style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _openDishTypeDialog(),
          icon: const Icon(Icons.playlist_add_rounded),
          label: const Text('TIPO DE PLATO'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () => _openMomentDialog(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('MOMENTO'),
          style: FilledButton.styleFrom(backgroundColor: AppTema.verdeSalud),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final activos = _momentos.where((m) => m['activo'] != false).length;
    return Row(
      children: [
        Expanded(child: NutriResumenCard(titulo: 'Momentos', valor: '${_momentos.length}', icon: Icons.schedule_rounded)),
        const SizedBox(width: 16),
        Expanded(child: NutriResumenCard(titulo: 'Activos', valor: '$activos', icon: Icons.check_circle_outline, colorValor: AppTema.verdeSalud)),
        const SizedBox(width: 16),
        Expanded(child: NutriResumenCard(titulo: 'Tipos de plato', valor: '${_tiposPlato.length}', icon: Icons.restaurant_menu_rounded, colorValor: AppTema.azulOscuro)),
      ],
    );
  }

  Widget _buildMomentsPanel() {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle('Momentos del dia', Icons.schedule_rounded),
          const Divider(height: 1),
          if (_momentos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay momentos configurados.'),
            )
          else
            ..._momentos.map((m) => _buildMomentTile(m)),
        ],
      ),
    );
  }

  Widget _buildMomentTile(Map<String, dynamic> momento) {
    final selected = _selectedMomento?['id'] == momento['id'];
    final color = _parseColor(momento['color']?.toString());
    return Material(
      color: selected ? AppTema.pastelCeleste.withOpacity(0.35) : Colors.white,
      child: InkWell(
        onTap: () {
          setState(() => _selectedMomento = momento);
          _loadRuleForMoment(momento);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(width: 8, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(momento['nombre']?.toString() ?? 'Sin nombre', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
                    const SizedBox(height: 4),
                    Text(
                      '${_timeText(momento['hora_inicio'])} - ${_timeText(momento['hora_fin'])}',
                      style: GoogleFonts.montserrat(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                onPressed: () => _openMomentDialog(momento),
                icon: const Icon(Icons.edit_rounded, size: 18),
              ),
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
        padding: const EdgeInsets.all(32),
        child: const Text('Selecciona un momento para configurar su menu.'),
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
                  'Menu para ${_selectedMomento!['nombre']}',
                  Icons.account_tree_rounded,
                  compact: true,
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : () => _saveRule(),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('GUARDAR REGLA'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _numberField(_minPrincipalesCtrl, 'Min. principales')),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_maxPrincipalesCtrl, 'Max. principales')),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_maxComplementosCtrl, 'Max. complementos', enabled: _permiteComplementos)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  value: _permiteComplementos,
                  title: const Text('Permite complementos'),
                  onChanged: (v) => setState(() => _permiteComplementos = v),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  value: _reglaActiva,
                  title: const Text('Regla activa'),
                  onChanged: (v) => setState(() => _reglaActiva = v),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tipos de plato permitidos',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppTema.azulOscuro),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openDetailDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('AGREGAR'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_detalleTipos.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Text('Aun no se definieron tipos de plato para este momento.'),
            )
          else
            ..._detalleTipos.map(_buildDetailTile),
        ],
      ),
    );
  }

  Widget _buildDetailTile(Map<String, dynamic> detail) {
    final principal = detail['rol_permitido'] == 'PRINCIPAL';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: principal ? AppTema.verdeLima.withOpacity(0.35) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: principal ? AppTema.verdeSalud.withOpacity(0.25) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(principal ? Icons.restaurant_rounded : Icons.add_circle_outline_rounded, color: principal ? AppTema.verdeSalud : Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail['tipo_plato_nombre']?.toString() ?? 'Tipo de plato', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
                Text(
                  '${principal ? 'Principal' : 'Complemento'} | min ${detail['minimo']} max ${detail['maximo']} | orden ${detail['orden']}',
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          if (detail['obligatorio'] == true)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(label: Text('Obligatorio')),
            ),
          IconButton(onPressed: () => _openDetailDialog(detail), icon: const Icon(Icons.edit_rounded, size: 18)),
          IconButton(onPressed: () => _deleteDetail(_asInt(detail['id'])!), icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
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
          Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: AppTema.azulOscuro)),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
    );
  }

  Widget _dialogTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label, {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  List<Map<String, dynamic>> _toRows(dynamic payload) {
    if (payload is! List) return const [];
    return payload.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

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
    final parsed = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return parsed == null ? AppTema.verdeSalud : Color(parsed);
  }
}
