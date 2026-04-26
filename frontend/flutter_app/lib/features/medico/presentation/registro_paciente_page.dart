import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/layout_components.dart';

class RegistroPacientePage extends ConsumerStatefulWidget {
  const RegistroPacientePage({super.key});
  @override
  ConsumerState<RegistroPacientePage> createState() => _RegistroPacientePageState();
}

class _RegistroPacientePageState extends ConsumerState<RegistroPacientePage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _loading = true;
  bool _isEditMode = false;
  String? _idPacienteEditando;

  // --- DATOS DEL TUTOR ---
  final _tutorCedula = TextEditingController();
  final _tutorNombre = TextEditingController();
  final _tutorEmail = TextEditingController();
  int? _idParentesco;
  bool _esTutorNuevo = false;
  bool _buscandoTutor = false;

  // --- DATOS DEL PACIENTE ---
  final _pacNombre = TextEditingController();
  final _pacCedula = TextEditingController();
  DateTime? _pacFechaNac;
  int? _pacSexo;

  // --- DATOS CLÍNICOS ---
  final _clinPeso = TextEditingController();
  final _clinTalla = TextEditingController();
  final _clinPCR = TextEditingController();
  final _clinRigidez = TextEditingController();
  final _clinObservaciones = TextEditingController();
  
  double _dolorEva = 0;
  double _inflamacion = 0;
  double _fatiga = 10;
  bool _broteActivo = false;
  int? _idPatologiaBase;
  DateTime _proximaCita = DateTime.now().add(const Duration(days: 30));
  final Map<int, DateTime> _condicionesTemporalesSeleccionadas = {};

  // --- ALERGIAS ---
  bool? _esIntoleranteLactosa;
  bool? _tieneAlergiaGrupos;
  bool? _tieneAlergiaIngredientes;
  final List<int> _alergiasSubIds = [];
  final List<Map<String, dynamic>> _alergiasIngredientesObj = [];
  String _ingredienteSearch = "";

  String _omsStatus = "PENDIENTE";
  Color _omsColor = Colors.grey;

  List<dynamic> _sexos = [];
  List<dynamic> _parentescos = [];
  List<dynamic> _condicionesBase = [];
  List<dynamic> _condicionesTemp = [];
  List<dynamic> _subgruposAlim = [];
  List<dynamic> _ingredientes = [];

  @override
  void initState() {
    super.initState();
    _inicializarTodo();
  }

  Future<void> _inicializarTodo() async {
    await _loadCatalogs();
    final selected = ref.read(selectedPatientProvider);
    if (selected != null) {
      _isEditMode = true;
      _idPacienteEditando = selected['id'].toString();
      await _loadExpedienteParaEdicion(_idPacienteEditando!);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCatalogs() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.fetchCatalog("usuarios", "catalogo_sexo"),
        repo.fetchCatalog("usuarios", "parentesco"),
        repo.fetchCatalog("heuristico", "condicion"),
        repo.fetchCatalog("nutricion", "subgrupo_alimentario"),
        repo.fetchIngredientes(),
      ]);
      if (mounted) {
        setState(() {
          _sexos = results[0];
          _parentescos = results[1];
          final todasCond = results[2] as List;
          _condicionesBase = todasCond.where((c) => c["id_tipo_condicion"] == 1).toList();
          _condicionesTemp = todasCond.where((c) => c["id_tipo_condicion"] == 2).toList();
          _subgruposAlim = results[3];
          _ingredientes = results[4];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadExpedienteParaEdicion(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("pacientes/$id/expediente-completo");
      final data = res.data;

      final pac = data['paciente'];
      final tutor = data['tutor'];
      final salud = data['ultimo_control'];
      final diag = data['diagnostico'];
      final alergias = data['alergias'];

      setState(() {
        _pacNombre.text = pac['nombre_completo'] ?? "";
        _pacCedula.text = pac['cedula'] ?? "";
        if (pac['fecha_nacimiento'] != null) _pacFechaNac = DateTime.parse(pac['fecha_nacimiento']);
        _pacSexo = pac['id_sexo'];

        _tutorCedula.text = tutor['cedula'] ?? "";
        _tutorNombre.text = tutor['nombre_completo'] ?? "";
        _tutorEmail.text = tutor['email'] ?? "";
        _idParentesco = tutor['id_parentesco'];
        _esTutorNuevo = false;

        _idPatologiaBase = diag['id_condicion'];
        _clinObservaciones.text = diag['observaciones'] ?? "";
        _clinPeso.text = salud['peso_kg']?.toString() ?? "";
        _clinTalla.text = salud['talla_cm']?.toString() ?? "";
        _clinPCR.text = salud['inflamacion_pcr']?.toString() ?? "";
        _clinRigidez.text = salud['minutos_rigidez_matutina']?.toString() ?? "";
        _dolorEva = (salud['nivel_dolor_eva'] ?? 0).toDouble();
        _inflamacion = (salud['nivel_inflamacion'] ?? 0).toDouble();
        _fatiga = (salud['nivel_fatiga'] ?? 10).toDouble();
        _broteActivo = salud['hay_brote_activo'] ?? false;
        if (salud['fecha_proxima_cita'] != null) _proximaCita = DateTime.parse(salud['fecha_proxima_cita']);

        final List subs = alergias['subgrupos'] ?? [];
        final List ings = alergias['ingredientes'] ?? [];
        _alergiasSubIds.clear();
        _alergiasSubIds.addAll(subs.map((s) => s['id'] as int));
        _alergiasIngredientesObj.clear();
        _alergiasIngredientesObj.addAll(ings.map((i) => Map<String, dynamic>.from(i)));

        _esIntoleranteLactosa = _alergiasSubIds.any((id) => [20, 21, 22, 23, 66, 79, 39].contains(id));
        _tieneAlergiaGrupos = _alergiasSubIds.isNotEmpty;
        _tieneAlergiaIngredientes = _alergiasIngredientesObj.isNotEmpty;

        _calculateOMS();
      });
    } catch (e) { print("Error Edición: $e"); }
  }

  Future<void> _buscarTutor(String cedula) async {
    if (cedula.isEmpty) return;
    setState(() => _buscandoTutor = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("usuarios/tutor-by-cedula/$cedula");
      if (res.data['existe'] == true) {
        setState(() {
          _tutorNombre.text = res.data['nombre_completo'] ?? "";
          _tutorEmail.text = res.data['email'] ?? "";
          _idParentesco = res.data['id_parentesco'];
          _esTutorNuevo = false;
        });
      } else {
        setState(() {
          _tutorNombre.clear();
          _tutorEmail.clear();
          _idParentesco = null;
          _esTutorNuevo = true;
        });
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _buscandoTutor = false); }
  }

  void _calculateOMS() {
    double p = double.tryParse(_clinPeso.text) ?? 0;
    double t = double.tryParse(_clinTalla.text) ?? 0;
    if (p > 0 && t > 0) {
      double imc = p / ((t / 100) * (t / 100));
      setState(() {
        if (imc < 13) { _omsStatus = "DELGADEZ SEVERA"; _omsColor = Colors.red; }
        else if (imc < 14.5) { _omsStatus = "DELGADEZ"; _omsColor = Colors.orange; }
        else if (imc < 18.5) { _omsStatus = "RIESGO DESNUTRICIÓN"; _omsColor = Colors.amber; }
        else if (imc < 25) { _omsStatus = "EUTRÓFICO (NORMAL)"; _omsColor = Colors.green; }
        else if (imc < 30) { _omsStatus = "SOBREPESO"; _omsColor = Colors.orange; }
        else { _omsStatus = "OBESIDAD"; _omsColor = Colors.red; }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Theme(
            data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppTema.azulPrincipal)),
            child: Stepper(
              type: StepperType.vertical, currentStep: _currentStep,
              onStepContinue: () {
                if (_validateCurrentStep(_currentStep)) {
                  setState(() => _currentStep < 2 ? _currentStep++ : _finish());
                } else {
                  NutriSnack.show(context, "Complete campos obligatorios (*)", isError: true, ref: ref);
                }
              },
              onStepCancel: () => setState(() => _currentStep > 0 ? _currentStep-- : null),
              controlsBuilder: (context, details) => _buildControls(details),
              steps: [_stepTutor(), _stepPaciente(), _stepClinico()],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      IconButton.filledTonal(onPressed: () {
        ref.read(selectedPatientProvider.notifier).state = null;
        ref.read(medicoNavProvider.notifier).state = MedicoView.list;
      }, icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18)),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_isEditMode ? "Edición de Perfil Maestro" : "Registro de Expediente Pediátrico", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal)),
        Text(_isEditMode ? "Actualizando expediente de ${_pacNombre.text}" : "Consistencia clínica estandarizada OMS.", style: const TextStyle(color: Colors.blueGrey)),
      ]),
    ]);
  }

  bool _validateCurrentStep(int step) {
    if (step == 0) return _tutorCedula.text.isNotEmpty && _tutorNombre.text.isNotEmpty && _idParentesco != null;
    if (step == 1) return _pacNombre.text.isNotEmpty && _pacCedula.text.isNotEmpty && _pacFechaNac != null && _pacSexo != null;
    return true;
  }

  Step _stepTutor() => Step(
    title: Text("Representante Legal", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
    isActive: _currentStep >= 0,
    content: NutriTableContainer(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      _field(_tutorCedula, "Cédula del Tutor*", Icons.badge_outlined, onSubmitted: _buscarTutor),
      if (_buscandoTutor) const LinearProgressIndicator(),
      const SizedBox(height: 16),
      _field(_tutorNombre, "Nombre Completo*", Icons.person_outline, enabled: _esTutorNuevo || _isEditMode),
      const SizedBox(height: 16),
      _field(_tutorEmail, "Correo Electrónico*", Icons.alternate_email, enabled: _esTutorNuevo || _isEditMode),
      const SizedBox(height: 16),
      _dropdown("Parentesco*", _parentescos, _idParentesco, (v) => setState(() => _idParentesco = v)),
    ]))),
  );

  Step _stepPaciente() => Step(
    title: Text("Identidad del Paciente", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
    isActive: _currentStep >= 1,
    content: NutriTableContainer(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      _field(_pacCedula, "Cédula del Niño*", Icons.badge_rounded),
      const SizedBox(height: 16),
      _field(_pacNombre, "Nombre Completo del Niño/a*", Icons.child_care_rounded),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _dateField()), const SizedBox(width: 16), Expanded(child: _dropdownSexo())]),
      const SizedBox(height: 16),
      _field(TextEditingController(text: "CHIMBORAZO"), "Provincia (Fijo)", Icons.location_on, enabled: false),
    ]))),
  );

  Widget _dropdownSexo() => DropdownButtonFormField<int>(
    value: _pacSexo, 
    items: _sexos.map((e) => DropdownMenuItem<int>(value: e["id"], child: Text(e["descripcion"]?.toString() ?? "-"))).toList(), 
    onChanged: (v) => setState(() => _pacSexo = v), 
    decoration: InputDecoration(labelText: "Sexo*", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))
  );

  Step _stepClinico() => Step(
    title: Text("Evaluación Clínica y Alergias", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
    isActive: _currentStep >= 2,
    content: NutriTableContainer(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _dropdown("Patología Crónica Base*", _condicionesBase, _idPatologiaBase, (v) => setState(() => _idPatologiaBase = v)),
      const SizedBox(height: 32),
      _section("ESTADO NUTRICIONAL (OMS)"),
      _buildRealtimeOMS(),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _field(_clinPeso, "Peso (kg)*", Icons.monitor_weight_outlined, onChanged: (_)=>_calculateOMS())),
        const SizedBox(width: 24),
        Expanded(child: _field(_clinTalla, "Talla (cm)*", Icons.height_rounded, onChanged: (_)=>_calculateOMS())),
      ]),
      const SizedBox(height: 32),
      _section("MÉTRICAS CLÍNICAS (EVA)"),
      _buildMetricSlider("DOLOR", _dolorEva, (v)=>setState(()=>_dolorEva=v), type: "DOLOR"),
      const SizedBox(height: 16),
      _buildMetricSlider("INFLAMACIÓN", _inflamacion, (v)=>setState(()=>_inflamacion=v), type: "INFLAMACION"),
      const SizedBox(height: 16),
      _buildMetricSlider("ENERGÍA", _fatiga, (v)=>setState(()=>_fatiga=v), type: "FATIGA"),
      const SizedBox(height: 32),
      Row(children: [Expanded(child: _field(_clinPCR, "PCR*", Icons.biotech)), const SizedBox(width: 24), Expanded(child: _field(_clinRigidez, "Rigidez (min)", Icons.timer))]),
      const SizedBox(height: 32),
      _section("CONDICIONES TEMPORALES ACTIVAS"),
      Wrap(spacing: 8, runSpacing: 8, children: _condicionesTemp.map((c) {
        final id = c["id"] as int;
        return FilterChip(
          label: Text(c["nombre"]), selected: _condicionesTemporalesSeleccionadas.containsKey(id),
          onSelected: (v) async {
            if (v) {
              final f = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now());
              if (f != null) setState(() => _condicionesTemporalesSeleccionadas[id] = f);
            } else { setState(() => _condicionesTemporalesSeleccionadas.remove(id)); }
          },
        );
      }).toList()),
      const SizedBox(height: 32),
      _buildBroteActivoSeccion(),
      const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Divider()),
      _section("VALIDACIÓN DE SEGURIDAD (ALERGIAS)"),
      _buildSecuencialAlergias(),
      const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Divider()),
      _section("AGENDAMIENTO"),
      ListTile(
        tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Icon(Icons.event), title: const Text("Próxima Cita"),
        subtitle: Text(DateFormat('dd/MM/yyyy').format(_proximaCita)),
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: _proximaCita, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
          if (d != null) setState(() => _proximaCita = d);
        },
      ),
      const SizedBox(height: 32),
      _section("OBSERVACIONES MÉDICAS"),
      _field(_clinObservaciones, "Notas adicionales...", Icons.edit_note, maxLines: 3),
    ]))),
  );

  Widget _buildBroteActivoSeccion() => Container(
    padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _broteActivo ? Colors.red.shade50 : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _broteActivo ? Colors.redAccent : Colors.grey.shade200, width: 2)),
    child: Column(children: [
      Text("¿EL PACIENTE PRESENTA BROTE ACTIVO?", style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 13, color: _broteActivo ? Colors.red.shade900 : Colors.black87)),
      const SizedBox(height: 20),
      Row(children: [_botonAccion("SÍ, HAY BROTE", _broteActivo == true, Colors.red, () => setState(() => _broteActivo = true)), const SizedBox(width: 16), _botonAccion("NO, ESTABLE", _broteActivo == false, Colors.green, () => setState(() => _broteActivo = false))]),
    ]),
  );

  Widget _buildMetricSlider(String title, double val, Function(double) onC, {required String type}) {
    String desc = ""; String emoji = ""; Color color = Colors.grey;
    if (type == "DOLOR") {
      if (val == 0) { desc = "SIN DOLOR"; emoji = "😀"; color = Colors.green; }
      else if (val <= 4) { desc = "MODERADO"; emoji = "😐"; color = Colors.amber; }
      else { desc = "INTENSO"; emoji = "😫"; color = Colors.red; }
    } else if (type == "INFLAMACION") {
      if (val == 0) { desc = "NORMAL"; emoji = "💪"; color = Colors.green; }
      else if (val <= 5) { desc = "MODERADA"; emoji = "🩹"; color = Colors.orange; }
      else { desc = "CRÍTICA"; emoji = "🔥"; color = Colors.red; }
    } else {
      if (val >= 8) { desc = "ENÉRGICO"; emoji = "⚡"; color = Colors.green; }
      else if (val >= 4) { desc = "REGULAR"; emoji = "🥱"; color = Colors.orange; }
      else { desc = "AGOTADO"; emoji = "🪫"; color = Colors.red; }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text("${val.toInt()}/10", style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
      Container(
        margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Row(children: [Text(emoji, style: const TextStyle(fontSize: 28)), const SizedBox(width: 12), Text(desc, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]),
          SliderTheme(data: SliderThemeData(activeTrackColor: color, inactiveTrackColor: Colors.black12, thumbColor: color, trackHeight: 6), child: Slider(value: val, min: 0, max: 10, divisions: 10, onChanged: onC)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(11, (i) => Text("$i", style: TextStyle(fontSize: 9, color: val.toInt() == i ? color : Colors.grey))))),
        ]),
      ),
    ]);
  }

  Widget _buildSecuencialAlergias() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _preguntaSiNo("¿EL PACIENTE ES INTOLERANTE A LA LACTOSA?", _esIntoleranteLactosa, (v) => setState(() { 
      _esIntoleranteLactosa = v; 
      if (v) _marcarLacteosAuto();
      else _alergiasSubIds.removeWhere((id) => [20, 21, 22, 23, 66, 79, 39].contains(id));
    })),
    const SizedBox(height: 24),
    _preguntaSiNo("¿TIENE ALERGIAS A GRUPOS ALIMENTARIOS?", _tieneAlergiaGrupos, (v) => setState(() => _tieneAlergiaGrupos = v)),
    if (_tieneAlergiaGrupos == true) Padding(padding: const EdgeInsets.only(top: 12), child: _multiSelect("", _subgruposAlim.where((s) => !(_esIntoleranteLactosa == true && [20, 21, 22, 23, 66, 79, 39].contains(s['id']))).toList(), _alergiasSubIds)),
    const SizedBox(height: 24),
    _preguntaSiNo("¿TIENE ALERGIAS A INGREDIENTES PUNTUALES?", _tieneAlergiaIngredientes, (v) => setState(() => _tieneAlergiaIngredientes = v)),
    if (_tieneAlergiaIngredientes == true) Padding(padding: const EdgeInsets.only(top: 12), child: _buildBuscadorIngredientesInteligente()),
  ]);

  void _marcarLacteosAuto() {
    final ids = [20, 21, 22, 23, 66, 79, 39];
    for (var id in ids) { if (!_alergiasSubIds.contains(id)) _alergiasSubIds.add(id); }
  }

  Widget _buildBuscadorIngredientesInteligente() {
    final filtrados = _ingredientes.where((ing) {
      final n = ing["nombre"].toString().toLowerCase();
      if (_alergiasSubIds.contains(ing["id_subgrupo"])) return false;
      if (_esIntoleranteLactosa == true && (n.contains("leche") || n.contains("queso") || n.contains("lactosa"))) return false;
      return n.contains(_ingredienteSearch.toLowerCase());
    }).take(8).toList();
    return Column(children: [
      TextField(decoration: const InputDecoration(hintText: "Buscar ingrediente...", prefixIcon: Icon(Icons.search)), onChanged: (v)=>setState(()=>_ingredienteSearch=v)),
      if (_ingredienteSearch.isNotEmpty) Wrap(spacing: 8, children: filtrados.map((ing) => FilterChip(label: Text(ing["nombre"]), selected: _alergiasIngredientesObj.any((x) => x["id"] == ing["id"]), onSelected: (v) => setState(() { if(v) _alergiasIngredientesObj.add(ing); else _alergiasIngredientesObj.removeWhere((x) => x["id"] == ing["id"]); }))).toList()),
    ]);
  }

  Widget _multiSelect(String l, List<dynamic> items, List<int> selected) => Wrap(spacing: 8, runSpacing: 8, children: items.map((e) {
    final emoji = _getEmojiForGrupo(e["nombre"] ?? "");
    return FilterChip(label: Text("$emoji ${e["nombre"]}"), selected: selected.contains(e["id"]), onSelected: (v) => setState(() => v ? selected.add(e["id"]) : selected.remove(e["id"])));
  }).toList());

  String _getEmojiForGrupo(String n) {
    n = n.toLowerCase(); if (n.contains("lácteo")) return "🥛"; if (n.contains("carne")) return "🥩"; if (n.contains("ave")) return "🍗"; if (n.contains("vegetal")) return "🥦"; if (n.contains("fruta")) return "🍎"; if (n.contains("marisco")) return "🦐"; if (n.contains("cereal")) return "🌾"; if (n.contains("fruto seco")) return "🥜"; if (n.contains("legumbre")) return "🫘"; return "🍴";
  }

  Widget _buildControls(ControlsDetails d) => Padding(padding: const EdgeInsets.only(top: 32), child: Row(children: [if (_currentStep > 0) OutlinedButton(onPressed: d.onStepCancel, child: const Text("ANTERIOR")), const Spacer(), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)), onPressed: _loading ? null : d.onStepContinue, child: Text(_currentStep == 2 ? (_isEditMode ? "GUARDAR CAMBIOS MAESTROS" : "REGISTRAR EXPEDIENTE") : "CONTINUAR"))]));

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        "tutor": {"cedula": _tutorCedula.text, "nombre": _tutorNombre.text, "email": _tutorEmail.text, "id_parentesco": _idParentesco},
        "paciente": {"nombre_completo": _pacNombre.text, "cedula": _pacCedula.text, "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first, "id_sexo": _pacSexo},
        "salud": {
          "id_patologia_base": _idPatologiaBase, 
          "enfermedad_nombre": _condicionesBase.firstWhere((c) => c['id'] == _idPatologiaBase)['nombre'],
          "peso_kg": _clinPeso.text, "talla_cm": _clinTalla.text, 
          "edad_meses": (DateTime.now().difference(_pacFechaNac!).inDays / 30).floor(),
          "dolor_eva": _dolorEva.toInt(), "inflamacion": _inflamacion.toInt(), "fatiga": _fatiga.toInt(),
          "pcr": double.tryParse(_clinPCR.text) ?? 0, "rigidez_min": int.tryParse(_clinRigidez.text) ?? 0, "brote_activo": _broteActivo,
          "observaciones": _clinObservaciones.text, "fecha_proxima_cita": _proximaCita.toIso8601String().split("T").first,
          "condiciones_temporales": _condicionesTemporalesSeleccionadas.entries.map((e) => {"id": e.key, "fecha_inicio": e.value.toIso8601String().split("T").first}).toList(),
          "alergias_subgrupos": _alergiasSubIds, "alergias_ingredientes": _alergiasIngredientesObj.map((e) => e["id"]).toList(),
        }
      };
      if (_isEditMode) await dio.put("pacientes/$_idPacienteEditando/expediente-maestro", data: payload);
      else await dio.post("registro/paciente-integral", data: payload);
      ref.invalidate(patientsListProvider);
      ref.read(selectedPatientProvider.notifier).state = null;
      ref.read(medicoNavProvider.notifier).state = MedicoView.list;
    } catch (e) { NutriSnack.show(context, "Error: $e", isError: true, ref: ref); } 
    finally { if(mounted) setState(() => _loading = false); }
  }

  Widget _field(TextEditingController c, String l, IconData i, {Function(String)? onChanged, Function(String)? onSubmitted, bool enabled = true, int maxLines = 1}) {
    bool n = l.contains("kg") || l.contains("cm") || l.contains("PCR") || l.contains("min");
    return TextFormField(controller: c, enabled: enabled, onChanged: onChanged, onFieldSubmitted: onSubmitted, maxLines: maxLines, keyboardType: n ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, inputFormatters: n ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: AppTema.azulPrincipal), filled: true, fillColor: enabled ? Colors.white : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
  }

  Widget _dropdown(String l, List<dynamic> items, int? val, Function(int?) onC) => DropdownButtonFormField<int>(value: val, items: items.map((e) => DropdownMenuItem<int>(value: e["id"], child: Text(e["nombre"]?.toString() ?? "-"))).toList(), onChanged: onC, decoration: InputDecoration(labelText: l, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));

  Widget _dateField() => TextFormField(readOnly: true, controller: TextEditingController(text: _pacFechaNac == null ? "" : DateFormat('dd/MM/yyyy').format(_pacFechaNac!)), decoration: InputDecoration(labelText: "Nacimiento*", prefixIcon: const Icon(Icons.calendar_today), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime(2015), firstDate: DateTime(2000), lastDate: DateTime.now()); if (d != null) setState(() => _pacFechaNac = d); });

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 11, color: AppTema.azulPrincipal)));

  Widget _preguntaSiNo(String t, bool? v, Function(bool) onC) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 12), Row(children: [_botonAccion("SÍ", v == true, Colors.redAccent, () => onC(true)), const SizedBox(width: 16), _botonAccion("NO", v == false, Colors.green, () => onC(false))])]);

  Widget _botonAccion(String l, bool s, Color col, VoidCallback o) => Expanded(child: InkWell(onTap: o, child: Container(height: 45, alignment: Alignment.center, decoration: BoxDecoration(color: s ? col : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: s ? col : Colors.grey.shade300, width: 2)), child: Text(l, style: TextStyle(fontWeight: FontWeight.bold, color: s ? Colors.white : Colors.blueGrey)))));

  Widget _buildRealtimeOMS() => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _omsColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _omsColor.withOpacity(0.3))), child: Column(children: [const Text("ESTADO NUTRICIONAL ACTUAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(_omsStatus, style: GoogleFonts.lexend(fontSize: 20, fontWeight: FontWeight.w900, color: _omsColor))]));
}
