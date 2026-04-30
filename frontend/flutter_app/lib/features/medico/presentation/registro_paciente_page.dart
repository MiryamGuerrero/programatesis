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
  final _clinVSG = TextEditingController();
  final _clinArtInflamadas = TextEditingController(text: "0");
  final _clinArtDolorosas = TextEditingController(text: "0");
  final _clinRigidez = TextEditingController();
  final _clinObservaciones = TextEditingController();
  final _ingredienteSearchCtrl = TextEditingController();
  
  double _dolorEva = 0;
  double _inflamacionEscala = 0; 
  double _fatiga = 10;
  bool _enBrote = false;
  String _estadoEnfermedad = "Estable";
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
    _ingredienteSearchCtrl.addListener(() {
      setState(() => _ingredienteSearch = _ingredienteSearchCtrl.text);
    });
  }

  @override
  void dispose() {
    _tutorCedula.dispose();
    _tutorNombre.dispose();
    _tutorEmail.dispose();
    _pacNombre.dispose();
    _pacCedula.dispose();
    _clinPeso.dispose();
    _clinTalla.dispose();
    _clinPCR.dispose();
    _clinVSG.dispose();
    _clinArtInflamadas.dispose();
    _clinArtDolorosas.dispose();
    _clinRigidez.dispose();
    _clinObservaciones.dispose();
    _ingredienteSearchCtrl.dispose();
    super.dispose();
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
        
        if (salud != null && salud.isNotEmpty) {
          _clinPeso.text = salud['peso_kg']?.toString() ?? "";
          _clinTalla.text = salud['talla_cm']?.toString() ?? "";
          _clinPCR.text = salud['valor_pcr']?.toString() ?? "";
          _clinVSG.text = salud['valor_vsg']?.toString() ?? "";
          _clinArtInflamadas.text = salud['articulaciones_inflamadas']?.toString() ?? "0";
          _clinArtDolorosas.text = salud['articulaciones_dolorosas']?.toString() ?? "0";
          _clinRigidez.text = salud['minutos_rigidez']?.toString() ?? "";
          _dolorEva = (salud['puntos_dolor'] ?? 0).toDouble();
          _inflamacionEscala = (salud['escala_inflamacion'] ?? 0).toDouble();
          _fatiga = (salud['nivel_fatiga'] ?? 10).toDouble();
          _enBrote = salud['en_brote'] ?? false;
          _estadoEnfermedad = salud['estado_enfermedad'] ?? "Estable";
          if (salud['fecha_proxima_cita'] != null) _proximaCita = DateTime.parse(salud['fecha_proxima_cita']);
        }

        _condicionesTemporalesSeleccionadas.clear();
        if (data['condiciones_vigentes'] != null) {
          for (var c in data['condiciones_vigentes']) {
            _condicionesTemporalesSeleccionadas[c['id_condicion']] = DateTime.now();
          }
        }

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
                  if (_currentStep < 2) {
                    setState(() => _currentStep++);
                  } else {
                    _finish();
                  }
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

  Widget _buildControls(ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: details.onStepCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("ANTERIOR"),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: details.onStepContinue,
              style: FilledButton.styleFrom(
                backgroundColor: _currentStep == 2 ? AppTema.verdeSalud : AppTema.azulPrincipal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_currentStep == 2 ? (_isEditMode ? "GUARDAR CAMBIOS" : "FINALIZAR REGISTRO") : "SIGUIENTE PASO"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuencialAlergias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _preguntaSiNo(
          "¿ES INTOLERANTE A LA LACTOSA?",
          _esIntoleranteLactosa,
          (v) {
            setState(() {
              _esIntoleranteLactosa = v;
              if (v) _marcarLacteosAuto();
              else _quitarLacteosAuto();
            });
          },
        ),
        const SizedBox(height: 24),
        _preguntaSiNo(
          "¿TIENE ALERGIAS A GRUPOS (MARISCOS, FRUTOS SECOS, ETC)?",
          _tieneAlergiaGrupos,
          (v) {
            setState(() {
              _tieneAlergiaGrupos = v;
              if (!v) _alergiasSubIds.clear();
              if (_esIntoleranteLactosa == true) _marcarLacteosAuto();
            });
          },
        ),
        if (_tieneAlergiaGrupos == true) ...[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListView(
                shrinkWrap: true,
                children: _subgruposAlim.map((s) {
                  final id = s["id"] as int;
                  final isLacteo = s["nombre"].toString().toLowerCase().contains("lácteo");
                  if (_esIntoleranteLactosa == true && isLacteo) return const SizedBox.shrink();
                  
                  return CheckboxListTile(
                    title: Text(s["nombre"], style: const TextStyle(fontSize: 13)),
                    value: _alergiasSubIds.contains(id),
                    onChanged: (val) => setState(() => val! ? _alergiasSubIds.add(id) : _alergiasSubIds.remove(id)),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _preguntaSiNo(
          "¿ALERGIA A INGREDIENTES PUNTUALES?",
          _tieneAlergiaIngredientes,
          (v) => setState(() => _tieneAlergiaIngredientes = v),
        ),
        if (_tieneAlergiaIngredientes == true) ...[
          const SizedBox(height: 16),
          _field(_ingredienteSearchCtrl, "Buscar ingrediente...", Icons.search),
          if (_ingredienteSearch.length > 2)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: ListView(
                shrinkWrap: true,
                children: _ingredientes.where((i) {
                  final n = i["nombre"].toString().toLowerCase();
                  final search = _ingredienteSearch.toLowerCase();
                  if (!n.contains(search)) return false;
                  if (_esIntoleranteLactosa == true && (n.contains("leche") || n.contains("queso") || n.contains("yogurt"))) return false;
                  if (_alergiasSubIds.contains(i["id_subgrupo_alimentario"])) return false;
                  return true;
                }).map((i) => ListTile(
                  title: Text(i["nombre"], style: const TextStyle(fontSize: 13)),
                  onTap: () {
                    final searchName = i["nombre"].toString().toLowerCase();
                    final relacionados = _ingredientes.where((ing) {
                      final name = ing["nombre"].toString().toLowerCase();
                      return name.contains(searchName);
                    }).toList();

                    setState(() {
                      for (var rel in relacionados) {
                        if (!_alergiasIngredientesObj.any((x) => x["id"] == rel["id"])) {
                          _alergiasIngredientesObj.add(rel);
                        }
                      }
                      _ingredienteSearchCtrl.clear();
                      _ingredienteSearch = "";
                    });
                  },
                )).toList(),
              ),
            ),
          if (_alergiasIngredientesObj.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(spacing: 8, runSpacing: 8, children: _alergiasIngredientesObj.map((i) => _buildIngredienteChip(i)).toList()),
            ),
        ],
      ],
    );
  }

  void _marcarLacteosAuto() {
    final lacteosIds = _subgruposAlim.where((s) => s["nombre"].toString().toLowerCase().contains("lácteo")).map((s) => s["id"] as int);
    for (var id in lacteosIds) {
      if (!_alergiasSubIds.contains(id)) _alergiasSubIds.add(id);
    }
  }

  void _quitarLacteosAuto() {
    final lacteosIds = _subgruposAlim.where((s) => s["nombre"].toString().toLowerCase().contains("lácteo")).map((s) => s["id"] as int).toSet();
    _alergiasSubIds.removeWhere((id) => lacteosIds.contains(id));
  }

  Widget _buildIngredienteChip(Map<String, dynamic> i) {
    return Chip(
      label: Text(i["nombre"], style: const TextStyle(fontSize: 11)),
      onDeleted: () => setState(() => _alergiasIngredientesObj.removeWhere((x) => x["id"] == i["id"])),
      deleteIconColor: Colors.red,
      backgroundColor: Colors.red.shade50,
      side: BorderSide(color: Colors.red.shade100),
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
        Text(_isEditMode ? "Edición de Perfil Maestro" : "Registro de Expediente Pediátrico", 
          style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text(_isEditMode ? "Actualizando expediente de ${_pacNombre.text}" : "Consistencia clínica estandarizada OMS.", 
          style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    ]);
  }

  bool _validateCurrentStep(int step) {
    if (step == 0) return _tutorCedula.text.isNotEmpty && _tutorNombre.text.isNotEmpty && _idParentesco != null;
    if (step == 1) return _pacNombre.text.isNotEmpty && _pacCedula.text.isNotEmpty && _pacFechaNac != null && _pacSexo != null;
    return true;
  }

  Step _stepTutor() => Step(
    title: Text("Representante Legal", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
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
    title: Text("Identidad del Paciente", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
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
    title: Text("Evaluación Clínica y Alergias", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
    isActive: _currentStep >= 2,
    content: NutriTableContainer(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("SELECCIÓN DE ENFERMEDAD REUMÁTICA", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTema.azulPrincipal, letterSpacing: 1)),
      const SizedBox(height: 16),
      _dropdown("Diagnóstico Reumatológico*", _condicionesBase, _idPatologiaBase, (v) => setState(() => _idPatologiaBase = v)),
      const SizedBox(height: 32),
      _section("ESTADO NUTRICIONAL (OMS)"),
      _buildRealtimeOMS(),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _field(_clinPeso, "Peso Actual (kg)*", Icons.monitor_weight_outlined, onChanged: (_)=>_calculateOMS())),
        const SizedBox(width: 24),
        Expanded(child: _field(_clinTalla, "Talla Actual (cm)*", Icons.height_rounded, onChanged: (_)=>_calculateOMS())),
      ]),
      const SizedBox(height: 32),
      _section("MÉTRICAS CLÍNICAS (EVA / ARTICULACIONES)"),
      _buildMetricSlider("NIVEL DE DOLOR", _dolorEva, (v)=>setState(()=>_dolorEva=v), type: "DOLOR"),
      const SizedBox(height: 16),
      _buildMetricSlider("INFLAMACIÓN ARTICULAR (0-3)", _inflamacionEscala, (v)=>setState(()=>_inflamacionEscala=v), type: "INFLAMACION_REUMA"),
      const SizedBox(height: 16),
      _buildMetricSlider("NIVEL DE ENERGÍA / FATIGA", _fatiga, (v)=>setState(()=>_fatiga=v), type: "FATIGA"),
      const SizedBox(height: 32),
      Row(children: [
        Expanded(child: _field(_clinArtInflamadas, "Artic. Inflamadas", Icons.settings_accessibility)),
        const SizedBox(width: 16),
        Expanded(child: _field(_clinArtDolorosas, "Artic. Dolorosas", Icons.front_hand_outlined)),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_clinPCR, "PCR (mg/L)*", Icons.biotech),
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 4),
              child: Text("Proteína C Reactiva: Mide inflamación aguda.", style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic)),
            ),
          ],
        )), 
        const SizedBox(width: 16), 
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_clinVSG, "VSG (mm/h)", Icons.bloodtype_outlined),
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 4),
              child: Text("Velocidad Sedimentación: Inflamación crónica.", style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic)),
            ),
          ],
        )),
        const SizedBox(width: 16), 
        Expanded(child: _field(_clinRigidez, "Rigidez (min)", Icons.timer))
      ]),
      const SizedBox(height: 32),
      _section("ESTADO DE LA ENFERMEDAD"),
      _dropdownString("Actividad actual*", ["Estable", "Actividad Leve", "Actividad Moderada", "Actividad Alta"], _estadoEnfermedad, (v)=>setState(()=>_estadoEnfermedad=v!)),
      const SizedBox(height: 32),
      _section("CONDICIONES TEMPORALES ACTIVAS"),
      const Text("Seleccione síntomas o condiciones actuales y defina su periodo:", style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: _condicionesTemp.map((c) {
        final id = c["id"] as int;
        final isSelected = _condicionesTemporalesSeleccionadas.containsKey(id);
        return FilterChip(
          label: Text(c["nombre"]), 
          selected: isSelected,
          onSelected: (v) async {
            if (v) {
              final f = await showDatePicker(
                context: context, 
                helpText: "FECHA DE INICIO DEL SÍNTOMA",
                initialDate: DateTime.now(), 
                firstDate: DateTime.now().subtract(const Duration(days: 30)), 
                lastDate: DateTime.now()
              );
              if (f != null) setState(() => _condicionesTemporalesSeleccionadas[id] = f);
            } else { 
              setState(() => _condicionesTemporalesSeleccionadas.remove(id)); 
            }
          },
        );
      }).toList()),
      if (_condicionesTemporalesSeleccionadas.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text("PERIODOS DEFINIDOS:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._condicionesTemporalesSeleccionadas.entries.map((e) {
          final nombre = _condicionesTemp.firstWhere((c) => c["id"] == e.key)["nombre"];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(child: Text(nombre, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                const Text("Inicio:", style: TextStyle(fontSize: 10)),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: e.value, firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now());
                    if (d != null) setState(() => _condicionesTemporalesSeleccionadas[e.key] = d);
                  },
                  child: Text(DateFormat('dd/MM/yy').format(e.value), style: const TextStyle(fontSize: 11)),
                ),
                const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                const SizedBox(width: 8),
                const Text("Fin (est.):", style: TextStyle(fontSize: 10)),
                Text(DateFormat('dd/MM/yy').format(e.value.add(const Duration(days: 7))), style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ],
            ),
          );
        }).toList(),
      ],
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

  Widget _dropdownString(String l, List<String> items, String val, Function(String?) onC) => DropdownButtonFormField<String>(value: val, items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(), onChanged: onC, decoration: InputDecoration(labelText: l, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));

  Widget _buildBroteActivoSeccion() => Container(
    padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _enBrote ? Colors.red.shade50 : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _enBrote ? Colors.redAccent : Colors.grey.shade200, width: 2)),
    child: Column(children: [
      Text("¿EL PACIENTE PRESENTA BROTE ACTIVO?", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: _enBrote ? Colors.red.shade900 : Colors.black87)),
      const SizedBox(height: 20),
      Row(children: [_botonAccion("SÍ, HAY BROTE", _enBrote == true, Colors.red, () => setState(() => _enBrote = true)), const SizedBox(width: 16), _botonAccion("NO, ESTABLE", _enBrote == false, Colors.green, () => setState(() => _enBrote = false))]),
    ]),
  );

  Widget _buildMetricSlider(String title, double val, Function(double) onC, {required String type}) {
    String desc = ""; String emoji = ""; Color color = Colors.grey;
    double maxV = 10; int divisions = 10;
    if (type == "DOLOR") {
      if (val == 0) { desc = "SIN DOLOR"; emoji = "😀"; color = Colors.green; }
      else if (val <= 4) { desc = "MODERADO"; emoji = "😐"; color = Colors.amber; }
      else { desc = "INTENSO"; emoji = "😫"; color = Colors.red; }
    } else if (type == "INFLAMACION_REUMA") {
      maxV = 3; divisions = 3;
      if (val == 0) { desc = "SIN INFLAMACIÓN"; emoji = "💪"; color = Colors.green; }
      else if (val == 1) { desc = "LEVE"; emoji = "🩹"; color = Colors.blue; }
      else if (val == 2) { desc = "MODERADA"; emoji = "🟠"; color = Colors.orange; }
      else { desc = "SEVERA"; emoji = "🔥"; color = Colors.red; }
    } else {
      if (val >= 8) { desc = "ENÉRGICO"; emoji = "⚡"; color = Colors.green; }
      else if (val >= 4) { desc = "REGULAR"; emoji = "🥱"; color = Colors.orange; }
      else { desc = "AGOTADO"; emoji = "🪫"; color = Colors.red; }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text("${val.toInt()}/${maxV.toInt()}", style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
      Container(
        margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Row(children: [Text(emoji, style: const TextStyle(fontSize: 28)), const SizedBox(width: 12), Text(desc, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]),
          SliderTheme(data: SliderThemeData(activeTrackColor: color, inactiveTrackColor: Colors.black12, thumbColor: color, trackHeight: 6), child: Slider(value: val, min: 0, max: maxV, divisions: divisions, onChanged: onC)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(maxV.toInt() + 1, (i) => Text("$i", style: TextStyle(fontSize: 9, color: val.toInt() == i ? color : Colors.grey))))),
        ]),
      ),
    ]);
  }

  Future<void> _finish() async {
    if (_idPatologiaBase == null) {
      NutriSnack.show(context, "Seleccione el Diagnóstico Base", isError: true, ref: ref);
      return;
    }
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
          "puntos_dolor": _dolorEva.toInt(), 
          "escala_inflamacion": _inflamacionEscala.toInt(), 
          "fatiga": _fatiga.toInt(),
          "valor_pcr": double.tryParse(_clinPCR.text) ?? 0, 
          "valor_vsg": double.tryParse(_clinVSG.text) ?? 0,
          "articulaciones_inflamadas": int.tryParse(_clinArtInflamadas.text) ?? 0,
          "articulaciones_dolorosas": int.tryParse(_clinArtDolorosas.text) ?? 0,
          "estado_enfermedad": _estadoEnfermedad,
          "minutos_rigidez": int.tryParse(_clinRigidez.text) ?? 0, 
          "en_brote": _enBrote,
          "es_intolerante_lactosa": _esIntoleranteLactosa ?? false,
          "observaciones": _clinObservaciones.text, "fecha_proxima_cita": _proximaCita.toIso8601String().split("T").first,
          "condiciones_temporales": _condicionesTemporalesSeleccionadas.entries.map((e) => {"id": e.key}).toList(),
          "alergias_subgrupos": _alergiasSubIds, "alergias_ingredientes": _alergiasIngredientesObj.map((e) => e["id"]).toList(),
        }
      };
      if (_isEditMode) await dio.put("pacientes/$_idPacienteEditando/expediente-maestro", data: payload);
      else {
        final res = await dio.post("registro/paciente-integral", data: payload);
        final tempPass = res.data['temp_password'];
        if (tempPass != null && mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(Icons.lock_person_rounded, color: AppTema.azulPrincipal, size: 28),
                  const SizedBox(width: 12),
                  Text("ACCESO PARA TUTOR", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Se ha generado una cuenta de acceso. Por favor, entregue estas credenciales al representante para su primer ingreso en la App Móvil:"),
                  const SizedBox(height: 24),
                  _buildCredentialBox("USUARIO (EMAIL)", _tutorEmail.text, Icons.email_outlined),
                  const SizedBox(height: 12),
                  _buildCredentialBox("CONTRASEÑA TEMPORAL", tempPass, Icons.key_outlined, isPassword: true),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text("El tutor también recibirá un enlace en su correo para establecer su contraseña definitiva.", style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTema.azulPrincipal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text("ENTENDIDO Y FINALIZAR")
                )
              ],
            ),
          );
        }
      }
      ref.invalidate(patientsListProvider);
      ref.read(selectedPatientProvider.notifier).state = null;
      ref.read(medicoNavProvider.notifier).state = MedicoView.list;
      if (mounted) NutriSnack.show(context, _isEditMode ? "Expediente actualizado" : "Paciente registrado", ref: ref);
    } catch (e) { NutriSnack.show(context, "Error: $e", isError: true, ref: ref); } 
    finally { if(mounted) setState(() => _loading = false); }
  }

  Widget _buildCredentialBox(String label, String value, IconData icon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTema.azulPrincipal),
              const SizedBox(width: 12),
              Expanded(child: Text(value, style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, fontSize: 13, color: isPassword ? Colors.blue.shade700 : Colors.black87))),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copiado: $value"), duration: const Duration(seconds: 1)));
                },
                tooltip: "Copiar",
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String l, IconData i, {Function(String)? onChanged, Function(String)? onSubmitted, bool enabled = true, int maxLines = 1}) {
    bool n = l.contains("kg") || l.contains("cm") || l.contains("PCR") || l.contains("VSG") || l.contains("min") || l.contains("Artic");
    return TextFormField(controller: c, enabled: enabled, onChanged: onChanged, onFieldSubmitted: onSubmitted, maxLines: maxLines, keyboardType: n ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, inputFormatters: n ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: AppTema.azulPrincipal), filled: true, fillColor: enabled ? Colors.white : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
  }

  Widget _dropdown(String l, List<dynamic> items, int? val, Function(int?) onC) => DropdownButtonFormField<int>(value: val, items: items.map((e) => DropdownMenuItem<int>(value: e["id"], child: Text(e["nombre"]?.toString() ?? "-"))).toList(), onChanged: onC, decoration: InputDecoration(labelText: l, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));

  Widget _dateField() => TextFormField(readOnly: true, controller: TextEditingController(text: _pacFechaNac == null ? "" : DateFormat('dd/MM/yyyy').format(_pacFechaNac!)), decoration: InputDecoration(labelText: "Nacimiento*", prefixIcon: const Icon(Icons.calendar_today), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime(2015), firstDate: DateTime(2000), lastDate: DateTime.now()); if (d != null) setState(() => _pacFechaNac = d); });

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 11, color: AppTema.azulPrincipal)));

  Widget _preguntaSiNo(String t, bool? v, Function(bool) onC) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 12), Row(children: [_botonAccion("SÍ", v == true, Colors.redAccent, () => onC(true)), const SizedBox(width: 16), _botonAccion("NO", v == false, Colors.green, () => onC(false))])]);

  Widget _botonAccion(String l, bool s, Color col, VoidCallback o) => Expanded(child: InkWell(onTap: o, child: Container(height: 45, alignment: Alignment.center, decoration: BoxDecoration(color: s ? col : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: s ? col : Colors.grey.shade300, width: 2)), child: Text(l, style: TextStyle(fontWeight: FontWeight.bold, color: s ? Colors.white : Colors.blueGrey)))));

  Widget _buildRealtimeOMS() => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _omsColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _omsColor.withOpacity(0.3))), child: Column(children: [const Text("ESTADO NUTRICIONAL ACTUAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(_omsStatus, style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900, color: _omsColor))]));
}
