import "dart:async";
import "dart:math";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";

import "../../../core/state/app_providers.dart";
import "../../../shared/widgets/layout_components.dart";

class RegistroPacientePage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool fixedOnly;
  const RegistroPacientePage({super.key, this.initialData, this.fixedOnly = false});

  @override
  ConsumerState<RegistroPacientePage> createState() => _RegistroPacientePageState();
}

class _RegistroPacientePageState extends ConsumerState<RegistroPacientePage> {
  int _currentStep = 0;
  bool _loading = false;
  bool _sending = false;
  bool _showSuccess = false;
  String? _idPacienteEditando;
  Timer? _debounceOMS;

  static const Color greenBrand = Color(0xFF2E7D32);

  // Tutor
  final _tutNombre = TextEditingController();
  final _tutCedula = TextEditingController();
  final _tutEmail = TextEditingController();
  final _tutTelefono = TextEditingController();
  final _tutDireccion = TextEditingController();
  String _generatedPassword = "";
  int? _tutParentesco;
  bool _tutorExistente = false;
  bool _buscandoTutor = false;
  bool _tutorNoEncontrado = false;

  // Paciente
  final _pacNombre = TextEditingController();
  final _pacCedula = TextEditingController();
  int? _pacSexo;
  int? _pacCanton;
  int? _pacParroquia;
  DateTime? _pacFechaNac;

  // Clínico
  final _clinPeso = TextEditingController();
  final _clinTalla = TextEditingController();
  final _clinPCR = TextEditingController();
  final _clinVSG = TextEditingController();
  final _clinArtInflam = TextEditingController(text: "0");
  final _clinArtDolor = TextEditingController(text: "0");
  final _clinRigidez = TextEditingController();
  final _clinNotas = TextEditingController();
  int? _idPatologiaBase;
  
  String _estadoEnfermedad = "Estable en remisión";
  final List<String> _estadosClinicos = [
    "Estable en remisión",
    "Estable con actividad baja",
    "Activa moderada",
    "Activa grave (alta actividad)",
    "Seguimiento"
  ];

  double _dolor = 0;
  double _inflamacion = 0;
  double _fatiga = 10;
  bool _brote = false;
  bool? _lactosa; 
  DateTime _proximaCita = DateTime.now().add(const Duration(days: 30));
  
  bool _tieneAlergiaSub = false;
  bool _tieneAlergiaIng = false;
  List<int> _alergiasSub = [];
  List<Map<String, dynamic>> _selectedIngredientes = [];
  List<Map<String, dynamic>> _condicionesTemp = [];

  // Catálogos
  List<dynamic> _parentescos = [];
  List<dynamic> _sexos = [];
  List<dynamic> _patologias = [];
  List<dynamic> _subgrupos = [];
  List<dynamic> _ingredientes = [];
  List<dynamic> _condicionesTemporalesCat = [];
  List<dynamic> _cantones = [];
  List<dynamic> _parroquiasCat = [];
  List<dynamic> _parroquiasFiltradas = [];

  final Set<int> _idsLacteos = {98, 100, 101, 104, 105, 108, 111, 114, 117, 119};

  String _omsStatusPeso = "PENDIENTE";
  String _omsStatusTalla = "PENDIENTE";
  Color _omsColor = Colors.grey.shade400;
  double _pesoMediana = 0;
  double _tallaMediana = 0;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _generatedPassword = _generateRandomPassword();
    _fetchCatalogos().then((_) => _loadInitialData());
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%';
    final rnd = Random.secure();
    return List.generate(10, (index) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _fetchCatalogos() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final results = await Future.wait([
        repo.fetchCatalog("usuarios", "parentesco"),
        repo.fetchCatalog("usuarios", "catalogo_sexo"),
        repo.fetchCatalog("heuristico", "condicion"),
        repo.fetchCatalog("nutricion", "ingrediente"),
        repo.fetchCatalog("usuarios", "canton"),
        repo.fetchCatalog("usuarios", "parroquia"),
        repo.fetchCatalog("nutricion", "subgrupo_alimentario"),
      ]);
      if (mounted) {
        setState(() {
          _parentescos = results[0];
          _sexos = results[1];
          final List conds = results[2];
          _patologias = conds.where((e) => (e['id_tipo'] ?? e['id_tipo_condicion']) == 1).toList();
          _condicionesTemporalesCat = conds.where((e) => (e['id_tipo'] ?? e['id_tipo_condicion']) == 2).toList();
          _ingredientes = results[3];
          _cantones = results[4];
          _parroquiasCat = results[5];
          _subgrupos = results[6];
          _updateParroquiasFiltradas(resetSelection: false);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateParroquiasFiltradas({bool resetSelection = true}) {
    if (_pacCanton != null && _parroquiasCat.isNotEmpty) {
      _parroquiasFiltradas = _parroquiasCat.where((p) => p['id_canton'] == _pacCanton).toList();
      if (resetSelection) _pacParroquia = null;
      else {
        bool existe = _parroquiasFiltradas.any((p) => p['id'] == _pacParroquia);
        if (!existe && _pacParroquia != null) _pacParroquia = null;
      }
    } else {
      _parroquiasFiltradas = [];
      if (resetSelection && _parroquiasCat.isNotEmpty) _pacParroquia = null;
    }
  }

  Future<void> _loadInitialData() async {
    if (widget.initialData == null) return;
    setState(() => _loading = true);
    Future.microtask(() async {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get("pacientes/${widget.initialData!['id']}/expediente-completo");
        final data = res.data;
        final p = data['paciente'] ?? {};
        final t = data['tutor'] ?? {};
        final d = data['diagnostico'] ?? {};
        final al = data['alergias'] ?? {};

        if (mounted) {
          setState(() {
            _idPacienteEditando = p['id'];
            _pacNombre.text = p['nombre_completo'] ?? "";
            _pacCedula.text = p['cedula'] ?? "";
            _pacFechaNac = DateTime.tryParse(p['fecha_nacimiento'] ?? "");
            _pacSexo = p['id_sexo'];
            _pacCanton = p['id_canton'];
            _pacParroquia = p['id_parroquia'];
            _updateParroquiasFiltradas(resetSelection: false);

            _tutNombre.text = t['nombre_completo'] ?? "";
            _tutCedula.text = t['cedula'] ?? "";
            _tutEmail.text = t['email'] ?? "";
            _tutTelefono.text = t['telefono'] ?? "";
            _tutDireccion.text = t['direccion'] ?? "";
            _tutParentesco = t['id_parentesco'];
            _tutorExistente = true;

            _idPatologiaBase = d['id_condicion'];
            _clinNotas.text = d['observaciones'] ?? "";

            if (al != null) {
              _alergiasSub = (al['subgrupos'] as List? ?? []).map((e) => (e['id'] as num).toInt()).toList();
              _selectedIngredientes = (al['ingredientes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
              _tieneAlergiaSub = _alergiasSub.isNotEmpty;
              _tieneAlergiaIng = _selectedIngredientes.isNotEmpty;
              _lactosa = data['es_intolerante_lactosa'] == true;
              if (_lactosa == true) _alergiasSub.removeWhere((id) => _idsLacteos.contains(id));
            }

            final c = data['ultimo_control'] ?? {};
            if (c.isNotEmpty) {
               _clinPeso.text = c['peso_kg']?.toString() ?? "";
               _clinTalla.text = c['talla_cm']?.toString() ?? "";
               _clinPCR.text = c['valor_pcr']?.toString() ?? "";
               _clinVSG.text = c['valor_vsg']?.toString() ?? "";
               _clinArtInflam.text = c['articulaciones_inflamadas']?.toString() ?? "0";
               _clinArtDolor.text = c['articulaciones_dolorosas']?.toString() ?? "0";
               _clinRigidez.text = c['minutos_rigidez']?.toString() ?? "";
               _dolor = (c['puntos_dolor'] ?? 0).toDouble();
               _inflamacion = (c['escala_inflamacion'] ?? 0).toDouble();
               _fatiga = (c['nivel_fatiga'] ?? 10).toDouble();
               _brote = c['en_brote'] ?? false;
               _estadoEnfermedad = c['estado_enfermedad'] ?? "Estable en remisión";
               _proximaCita = DateTime.tryParse(c['fecha_proxima_cita'] ?? "") ?? DateTime.now().add(const Duration(days: 30));
            }
            
            _condicionesTemp = (data['condiciones_temporales'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
            
            _loading = false;
          });
          _calculateOMS();
        }
      } catch (e) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  void _debouncedOMS() {
    _debounceOMS?.cancel();
    _debounceOMS = Timer(const Duration(milliseconds: 1000), () => _calculateOMS());
  }

  Future<void> _calculateOMS() async {
    double p = double.tryParse(_clinPeso.text) ?? 0;
    double t = double.tryParse(_clinTalla.text) ?? 0;
    if (p > 1 && t > 30 && _pacFechaNac != null && _pacSexo != null) {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.post("pre-diagnostico-nutricional", data: {
          "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first,
          "id_sexo": _pacSexo, "peso_kg": p, "talla_cm": t
        });
        if (mounted) {
          setState(() {
            _omsStatusPeso = res.data['diagnostico_nutri_texto'] ?? "Normal";
            _omsStatusTalla = res.data['diagnostico_talla_texto'] ?? "Adecuada";
            _pesoMediana = (res.data['peso_ideal'] ?? 0).toDouble();
            _tallaMediana = (res.data['talla_ideal'] ?? 0).toDouble();
            final String combined = (res.data['diagnostico_combinado'] ?? "$_omsStatusPeso / $_omsStatusTalla").toString().toLowerCase();
            if (combined.contains("severa") || combined.contains("obesidad")) _omsColor = Colors.red;
            else if (combined.contains("sobrepeso") || combined.contains("baja") || combined.contains("delgadez") || combined.contains("bajo peso") || combined.contains("riesgo")) _omsColor = Colors.orange;
            else _omsColor = greenBrand;
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _parentescos.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator(color: greenBrand)));
    
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHeader(),
              const SizedBox(height: 56),
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(primary: greenBrand),
                  inputDecorationTheme: const InputDecorationTheme(
                    floatingLabelBehavior: FloatingLabelBehavior.always, 
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: greenBrand, width: 2)),
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15),
                  )
                ),
                child: Form(
                  key: _formKey,
                  child: Stepper(
                    type: StepperType.vertical, 
                    currentStep: _currentStep,
                    physics: const NeverScrollableScrollPhysics(),
                    onStepContinue: () {
                      int st = widget.fixedOnly ? _currentStep + 1 : _currentStep;
                      if (_validateCurrentStep(st)) {
                        if (_currentStep < (widget.fixedOnly ? 1 : 2)) setState(() => _currentStep++);
                        else _finish();
                      } else {
                        NutriSnack.show(context, "Complete campos obligatorios marcados con (*)", isError: true, ref: ref);
                      }
                    },
                    onStepCancel: () => setState(() => _currentStep > 0 ? _currentStep-- : null),
                    controlsBuilder: (context, details) => _buildControls(details),
                    steps: [if (!widget.fixedOnly) _stepTutor(), _stepPaciente(), _stepClinico()],
                  ),
                ),
              ),
            ]),
          ),
        ),
        if (_sending) _buildSendingOverlay(),
      ],
    );
  }

  Widget _buildHeader() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [IconButton.filledTonal(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: greenBrand), onPressed: () => ref.read(medicoNavProvider.notifier).state = MedicoView.list), const SizedBox(width: 24), Text(_idPacienteEditando == null ? "REGISTRO INTEGRAL PEDIÁTRICO" : "ACTUALIZACIÓN DE EXPEDIENTE", style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)))])]);

  Widget _buildSendingOverlay() => Container(color: Colors.black.withOpacity(0.85), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [if (!_showSuccess) const CircularProgressIndicator(color: Colors.white, strokeWidth: 8), if (_showSuccess) const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 120), const SizedBox(height: 32), Text(_showSuccess ? "GUARDADO" : "SINCRONIZANDO...", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))])));

  bool _validateCurrentStep(int step) {
    if (step == 0) return _tutNombre.text.isNotEmpty && _tutCedula.text.isNotEmpty && _tutParentesco != null && _tutEmail.text.isNotEmpty;
    if (step == 1) return _pacNombre.text.isNotEmpty && _pacCedula.text.isNotEmpty && _pacSexo != null && _pacFechaNac != null;
    return _idPatologiaBase != null && _lactosa != null;
  }

  Future<void> _finish() async {
    if (_idPacienteEditando == null && !_tutorExistente) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Column(children: [const Icon(Icons.vpn_key_rounded, color: greenBrand, size: 48), const SizedBox(height: 16), Text("CREDENCIALES DEL TUTOR", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18))]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Se creará una nueva cuenta para el representante legal. Comparta estos datos con el tutor:", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: greenBrand.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: greenBrand.withOpacity(0.15))), child: Column(children: [
              _credItem("USUARIO (EMAIL)", _tutEmail.text, Icons.alternate_email),
              const Divider(height: 32),
              _credItem("CLAVE TEMPORAL", _generatedPassword, Icons.lock_outline),
            ])),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: greenBrand, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)), child: const Text("ACEPTAR Y REGISTRAR"))],
        )
      );
      if (confirm != true) return;
    }

    setState(() => _sending = true);
    try {
      final payload = {
        "tutor": {
          "nombre": _tutNombre.text, "cedula": _tutCedula.text, "email": _tutEmail.text,
          "id_parentesco": _tutParentesco, "telefono": _tutTelefono.text, "direccion": _tutDireccion.text,
          "password": _idPacienteEditando == null && !_tutorExistente ? _generatedPassword : null
        },
        "paciente": {
          "id": _idPacienteEditando, "nombre_completo": _pacNombre.text, "cedula": _pacCedula.text,
          "id_sexo": _pacSexo, "id_canton": _pacCanton, "id_parroquia": _pacParroquia,
          "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first
        },
        "salud": {
          "id_patologia_base": _idPatologiaBase, "peso_kg": _clinPeso.text, "talla_cm": _clinTalla.text,
          "valor_pcr": _clinPCR.text, "valor_vsg": _clinVSG.text, 
          "articulaciones_inflamadas": _clinArtInflam.text, "articulaciones_dolorosas": _clinArtDolor.text,
          "minutos_rigidez": _clinRigidez.text, "puntos_dolor": _dolor.toInt(),
          "escala_inflamacion": _inflamacion.toInt(), "fatiga": _fatiga.toInt(),
          "en_brote": _brote, "estado_enfermedad": _estadoEnfermedad, "observaciones": _clinNotas.text,
          "es_intolerante_lactosa": _lactosa, "alergias_subgrupos": _alergiasSub,
          "alergias_ingredientes": _selectedIngredientes.map((e) => e['id']).toList(),
          "condiciones_temporales": _condicionesTemp,
          "fecha_proxima_cita": _proximaCita.toIso8601String().split("T").first
        }
      };
      final dio = ref.read(dioProvider);
      if (_idPacienteEditando == null) await dio.post("registro/paciente-integral", data: payload);
      else await dio.put("pacientes/$_idPacienteEditando/expediente-maestro", data: payload);
      
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      ref.invalidate(patientsListProvider);
      if (mounted) ref.read(medicoNavProvider.notifier).state = MedicoView.list;
    } catch (e) {
      if (mounted) NutriSnack.show(context, "Error al guardar: $e", isError: true, ref: ref);
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Widget _credItem(String l, String v, IconData i) => Row(children: [Icon(i, size: 18, color: greenBrand), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))])]);

  Step _stepTutor() => Step(
    isActive: _currentStep >= 0,
    state: _currentStep > 0 ? StepState.complete : StepState.editing,
    title: Text("REPRESENTANTE LEGAL", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
    content: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(children: [
        Row(children: [
          Expanded(child: _field(_tutCedula, "Cédula del Tutor*", Icons.badge_outlined, onChanged: (v) { if (v.length == 10) _buscarTutor(v); })),
          const SizedBox(width: 12),
          IconButton.filled(onPressed: () => _buscarTutor(_tutCedula.text), icon: const Icon(Icons.search), style: IconButton.styleFrom(backgroundColor: greenBrand, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
        ]),
        if (_buscandoTutor) const LinearProgressIndicator(),
        if (_tutorNoEncontrado) Padding(padding: const EdgeInsets.only(top: 8), child: Text("⚠️ Tutor no registrado. POR FAVOR COMPLETE LOS DATOS.", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800))),
        if (_tutorExistente) Padding(padding: const EdgeInsets.only(top: 8), child: Text("✅ Tutor encontrado. PUEDE ACTUALIZAR SUS DATOS SI ES NECESARIO.", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: greenBrand))),
        const SizedBox(height: 24),
        _field(_tutNombre, "Nombre y Apellidos*", Icons.person_outline),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _field(_tutEmail, "Email de Usuario*", Icons.alternate_email, helper: "Este será su nombre de acceso.")),
          const SizedBox(width: 20),
          Expanded(child: _dropdown("Parentesco*", _parentescos, _tutParentesco, (v) => setState(() => _tutParentesco = v))),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _field(_tutTelefono, "Teléfono Móvil", Icons.phone_android_outlined)),
          const SizedBox(width: 20),
          Expanded(child: _field(_tutDireccion, "Dirección del Hogar", Icons.map_outlined)),
        ]),
      ]),
    )
  );

  Step _stepPaciente() => Step(
    isActive: _currentStep >= (widget.fixedOnly ? 0 : 1),
    state: _currentStep > (widget.fixedOnly ? 0 : 1) ? StepState.complete : StepState.editing,
    title: Text("IDENTIDAD DEL PACIENTE", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
    content: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(children: [
        _field(_pacCedula, "Cédula / ID del Menor*", Icons.badge_outlined),
        const SizedBox(height: 24),
        _field(_pacNombre, "Nombres y Apellidos Completos*", Icons.child_friendly_outlined),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: InkWell(onTap: _pickFechaNac, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))), child: Row(children: [const Icon(Icons.calendar_month_outlined, size: 20, color: greenBrand), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("FECHA DE NACIMIENTO*", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)), Text(_pacFechaNac == null ? "Día / Mes / Año" : DateFormat('dd / MM / yyyy').format(_pacFechaNac!), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))])])))),
          const SizedBox(width: 20),
          Expanded(child: _dropdown("Sexo Biológico*", _sexos, _pacSexo, (v) => setState(() { _pacSexo = v; _calculateOMS(); }))),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _dropdown("Cantón de Residencia", _cantones, _pacCanton, (v) { setState(() { _pacCanton = v; _updateParroquiasFiltradas(); }); })),
          const SizedBox(width: 20),
          Expanded(child: _dropdown("Parroquia de Residencia", _parroquiasFiltradas, _pacParroquia, (v) => setState(() => _pacParroquia = v))),
        ]),
      ]),
    )
  );

  Step _stepClinico() => Step(
    isActive: _currentStep >= (widget.fixedOnly ? 1 : 2),
    state: _currentStep == (widget.fixedOnly ? 1 : 2) ? StepState.editing : StepState.complete,
    title: Text("CONFIGURACIÓN DE SALUD", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
    content: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _dropdown("Patología / Enfermedad Base*", _patologias, _idPatologiaBase, (v) => setState(() => _idPatologiaBase = v)),
        const SizedBox(height: 24),
        _dropdown("Estado de la Enfermedad*", _estadosClinicos.asMap().entries.map((e) => {"id": e.key, "nombre": e.value}).toList(), _estadosClinicos.indexOf(_estadoEnfermedad), (v) => setState(() => _estadoEnfermedad = _estadosClinicos[v!])),
        
        const SizedBox(height: 40),
        _sectionHeader("MEDIDAS ANTROPOMÉTRICAS", Icons.scale_outlined),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _field(_clinPeso, "Peso Inicial (kg)*", Icons.monitor_weight_outlined, onChanged: (_) => _debouncedOMS())),
          const SizedBox(width: 20),
          Expanded(child: _field(_clinTalla, "Talla Inicial (cm)*", Icons.height_outlined, onChanged: (_) => _debouncedOMS())),
        ]),
        const SizedBox(height: 20),
        _buildProfessionalPrediagnosis(),
        
        const SizedBox(height: 40),
        _sectionHeader("ACTIVIDAD DE LA ENFERMEDAD (EVA)", Icons.healing_outlined),
        const SizedBox(height: 24),
        _buildMetricSlider("NIVEL DE DOLOR ACTUAL", _dolor, (v) => setState(() => _dolor = v), "DOLOR"),
        const SizedBox(height: 24),
        _buildMetricSlider("NIVEL DE INFLAMACIÓN", _inflamacion, (v) => setState(() => _inflamacion = v), "INFLAMACION"),
        const SizedBox(height: 24),
        _buildMetricSlider("NIVEL DE FATIGA / ENERGÍA", _fatiga, (v) => setState(() => _fatiga = v), "FATIGA"),
        
        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: _field(_clinPCR, "PCR (mg/L)", Icons.science_outlined)),
          const SizedBox(width: 16),
          Expanded(child: _field(_clinVSG, "VSG/VRC (mm/h)", Icons.bloodtype_outlined)),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _field(_clinArtInflam, "Art. Inflamadas", Icons.adjust_rounded)),
          const SizedBox(width: 16),
          Expanded(child: _field(_clinArtDolor, "Art. Dolorosas", Icons.pan_tool_alt_rounded)),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _brote ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: _brote ? Colors.red : greenBrand)),
          child: SwitchListTile(title: Text(_brote ? "BROTE ACTIVO DETECTADO" : "SIN BROTE ACTIVO", style: TextStyle(fontWeight: FontWeight.w900, color: _brote ? Colors.red : greenBrand, fontSize: 13)), subtitle: const Text("¿Presenta crisis hoy?", style: TextStyle(fontSize: 11)), value: _brote, onChanged: (v) => setState(() => _brote = v), activeColor: Colors.red),
        ),

        const SizedBox(height: 40),
        _sectionHeader("SEGURIDAD ALIMENTARIA", Icons.warning_amber_rounded),
        const SizedBox(height: 24),
        _buildIntoleranciaLactosa(),
        const SizedBox(height: 32),
        _buildAlergiasCheckboxes(),
        
        const SizedBox(height: 40),
        _sectionHeader("SÍNTOMAS TEMPORALES ACTUALES", Icons.event_note_rounded),
        const SizedBox(height: 16),
        _buildSintomasTemporalesSelector(),
        
        const SizedBox(height: 40),
        _field(_clinNotas, "Observaciones Médicas Iniciales", Icons.edit_note_rounded, maxLines: 4),
      ]),
    )
  );

  Widget _buildSintomasTemporalesSelector() {
    return Column(children: [
      _dropdown("Añadir Síntoma Temporal", _condicionesTemporalesCat, null, (v) {
        if (v != null) {
          final s = _condicionesTemporalesCat.firstWhere((e) => e['id'] == v);
          if (!_condicionesTemp.any((ct) => ct['id'] == v)) {
            setState(() => _condicionesTemp.add({
              "id": v, "nombre": s['nombre'],
              "fecha_inicio": DateTime.now().toIso8601String().split('T')[0],
              "fecha_fin": DateTime.now().add(const Duration(days: 7)).toIso8601String().split('T')[0]
            }));
          }
        }
      }),
      const SizedBox(height: 16),
      ...List.generate(_condicionesTemp.length, (i) => Card(
        margin: const EdgeInsets.only(bottom: 8), elevation: 0, color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        child: ListTile(
          title: Text(_condicionesTemp[i]['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text("Del ${_condicionesTemp[i]['fecha_inicio']} al ${_condicionesTemp[i]['fecha_fin']}", style: const TextStyle(fontSize: 11)),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _condicionesTemp.removeAt(i))),
        ),
      ))
    ]);
  }

  Widget _buildIntoleranciaLactosa() => Container(
    padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("¿PRESENTA INTOLERANCIA A LA LACTOSA?*", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5)),
      const SizedBox(height: 20),
      Row(children: [_yesNoBtn("SÍ, RESTRICCIÓN ACTIVA", true, _lactosa == true, (v) => setState(() => _lactosa = v)), const SizedBox(width: 20), _yesNoBtn("NO DETECTADA", false, _lactosa == false, (v) => setState(() => _lactosa = v))])
    ]),
  );

  Widget _yesNoBtn(String l, bool val, bool sel, Function(bool) onTap) => Expanded(child: InkWell(onTap: () => onTap(val), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: sel ? (val ? Colors.red.shade50 : greenBrand.withOpacity(0.1)) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? (val ? Colors.red : greenBrand) : const Color(0xFFE2E8F0), width: 2.5)), child: Center(child: Text(l, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: sel ? (val ? Colors.red : greenBrand) : Colors.blueGrey))))));

  Widget _buildAlergiasCheckboxes() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    CheckboxListTile(title: const Text("TIENE ALERGIAS A GRUPOS ALIMENTARIOS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), value: _tieneAlergiaSub, onChanged: (v) => setState(() => _tieneAlergiaSub = v!), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, activeColor: greenBrand),
    if (_tieneAlergiaSub) _multiSelectChips("SELECCIONE GRUPOS RESTRINGIDOS", _subgrupos, _alergiasSub, (id, sel) { setState(() { if (sel) _alergiasSub.add(id); else _alergiasSub.remove(id); }); }, blockedIds: _lactosa == true ? _idsLacteos : {}),
    const SizedBox(height: 12),
    CheckboxListTile(title: const Text("TIENE ALERGIAS A INGREDIENTES ESPECÍFICOS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), value: _tieneAlergiaIng, onChanged: (v) => setState(() => _tieneAlergiaIng = v!), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, activeColor: greenBrand),
    if (_tieneAlergiaIng) ...[
      const SizedBox(height: 12),
      Autocomplete<Map<String, dynamic>>(
        displayStringForOption: (e) => e['nombre'],
        optionsBuilder: (v) => _ingredientes.where((e) => e['nombre'].toString().toLowerCase().contains(v.text.toLowerCase())).cast<Map<String, dynamic>>(),
        onSelected: (e) { if (!_selectedIngredientes.any((ing) => ing['id'] == e['id'])) setState(() => _selectedIngredientes.add(e)); },
        fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) => _field(ctrl, "Buscar ingrediente...", Icons.search_rounded),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: _selectedIngredientes.map((e) => Chip(label: Text(e['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 11)), onDeleted: () => setState(() => _selectedIngredientes.remove(e)), backgroundColor: Colors.orange.shade50, deleteIconColor: Colors.deepOrange, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.orange.shade200)))).toList())
    ]
  ]);

  Widget _multiSelectChips(String label, List items, List<int> sel, Function(int, bool) onS, {Set<int> blockedIds = const {}}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
    const SizedBox(height: 16),
    Wrap(spacing: 10, runSpacing: 10, children: items.map((i) { 
      final id = (i['id'] as num).toInt(); final s = sel.contains(id); final b = blockedIds.contains(id); 
      return FilterChip(label: Text(i['nombre'] ?? "", style: TextStyle(fontSize: 11, fontWeight: s ? FontWeight.bold : FontWeight.w500, color: b ? Colors.grey.shade400 : (s ? greenBrand : const Color(0xFF475569)))), selected: s, onSelected: b ? null : (v) => onS(id, v), selectedColor: greenBrand.withOpacity(0.12), checkmarkColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: s ? greenBrand.withOpacity(0.3) : const Color(0xFFE2E8F0))), backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)); 
    }).toList()),
    const SizedBox(height: 24),
  ]);

  Widget _buildProfessionalPrediagnosis() => Container(
    padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: _omsColor.withOpacity(0.06), borderRadius: BorderRadius.circular(24), border: Border.all(color: _omsColor.withOpacity(0.2), width: 2)), 
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.analytics_rounded, color: _omsColor, size: 22), const SizedBox(width: 12), Text("PRE-DIAGNÓSTICO OMS ESTIMADO", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF475569)))],),
      const SizedBox(height: 24),
      Text("${_omsStatusPeso.toUpperCase()} / ${_omsStatusTalla.toUpperCase()}", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
    ])
  );

  Future<void> _buscarTutor(String c) async { 
    if (c.length < 10) return;
    setState(() { _buscandoTutor = true; _tutorNoEncontrado = false; _tutorExistente = false; }); 
    try { 
      final res = await ref.read(dioProvider).get("usuarios/tutor-by-cedula/$c"); 
      if (mounted) {
        if (res.data['existe'] == true) { 
          final t = res.data['tutor']; 
          setState(() { 
            _tutNombre.text = (t['nombre_completo'] ?? "").toString(); 
            _tutEmail.text = (t['email'] ?? "").toString(); 
            _tutTelefono.text = (t['telefono'] ?? "").toString(); 
            _tutDireccion.text = (t['direccion'] ?? "").toString(); 
            _tutorExistente = true; 
          });
          NutriSnack.show(context, "✅ Tutor encontrado", ref: ref);
        } else { setState(() { _tutorNoEncontrado = true; }); }
      }
    } catch (_) {} finally { if (mounted) setState(() => _buscandoTutor = false); } 
  }

  Future<void> _pickFechaNac() async { 
    final d = await showDatePicker(context: context, initialDate: _pacFechaNac ?? DateTime(2015), firstDate: DateTime(2005), lastDate: DateTime.now(), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: greenBrand)), child: child!)); 
    if (d != null) { setState(() => _pacFechaNac = d); _calculateOMS(); } 
  }

  Widget _field(TextEditingController c, String l, IconData i, {int maxLines = 1, Function(String)? onChanged, bool enabled = true, String? helper}) => TextFormField(controller: c, maxLines: maxLines, enabled: enabled, onChanged: onChanged, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 20), helperText: helper, floatingLabelBehavior: FloatingLabelBehavior.always));
  Widget _dropdown(String l, List items, int? val, Function(int?) onC) => DropdownButtonFormField<int>(value: val, items: items.map((e) => DropdownMenuItem<int>(value: e['id'], child: Text(e['nombre'] ?? e['descripcion'] ?? "", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(), onChanged: onC, decoration: InputDecoration(labelText: l));
  Widget _buildControls(ControlsDetails d) => Padding(padding: const EdgeInsets.only(top: 56), child: Row(children: [Expanded(child: FilledButton(onPressed: d.onStepContinue, style: FilledButton.styleFrom(backgroundColor: greenBrand, padding: const EdgeInsets.symmetric(vertical: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(_currentStep == (widget.fixedOnly ? 1 : 2) ? (_idPacienteEditando == null ? "REGISTRAR PACIENTE" : "GUARDAR CAMBIOS") : "SIGUIENTE PASO", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))), if (_currentStep > 0) ...[const SizedBox(width: 20), Expanded(child: OutlinedButton(onPressed: d.onStepCancel, style: OutlinedButton.styleFrom(side: const BorderSide(color: greenBrand, width: 2), foregroundColor: greenBrand, padding: const EdgeInsets.symmetric(vertical: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("REGRESAR", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))))]]));
  Widget _sectionHeader(String t, IconData i) => Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: greenBrand.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(i, size: 20, color: greenBrand)), const SizedBox(width: 18), Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0F172A), letterSpacing: 0.8))]);

  Widget _buildMetricSlider(String title, double val, Function(double) onC, String type) {
    String desc = ""; String emoji = ""; Color color = Colors.grey; double maxV = 10; int divisions = 10;
    if (type == "DOLOR") {
      if (val == 0) { desc = "SIN DOLOR"; emoji = "😀"; color = greenBrand; }
      else if (val <= 3) { desc = "LEVE"; emoji = "🙂"; color = Colors.blue; }
      else if (val <= 6) { desc = "MODERADO"; emoji = "😐"; color = Colors.orange; }
      else if (val <= 8) { desc = "INTENSO"; emoji = "😫"; color = Colors.deepOrange; }
      else { desc = "INSOPORTABLE"; emoji = "😭"; color = Colors.red; }
    } else if (type == "INFLAMACION") {
      maxV = 3; divisions = 3;
      if (val == 0) { desc = "SIN INFLAMACIÓN"; emoji = "💪"; color = greenBrand; }
      else if (val == 1) { desc = "LEVE / DISCRETA"; emoji = "🩹"; color = Colors.blue; }
      else if (val == 2) { desc = "MODERADA"; emoji = "🟠"; color = Colors.orange; }
      else { desc = "SEVERA / ACTIVA"; emoji = "🔥"; color = Colors.red; }
    } else if (type == "FATIGA") {
      if (val >= 8) { desc = "MUCHA ENERGÍA"; emoji = "⚡"; color = greenBrand; }
      else if (val >= 5) { desc = "NORMAL"; emoji = "🙂"; color = Colors.blue; }
      else if (val >= 3) { desc = "FATIGA LEVE"; emoji = "🥱"; color = Colors.orange; }
      else { desc = "AGOTAMIENTO"; emoji = "🪫"; color = Colors.red; }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.blueGrey)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text("${val.toInt()}/${maxV.toInt()}", style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)))
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Row(children: [Text(emoji, style: const TextStyle(fontSize: 24)), const SizedBox(width: 12), Expanded(child: Text(desc, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)))]),
          Slider(value: val, min: 0, max: maxV, divisions: divisions, activeColor: color, onChanged: onC),
        ]),
      )
    ]);
  }
  
  // stubs
  Widget _section(String title) => Container(); Widget _dateField() => Container(); Widget _buildRealtimeOMS() => Container(); Widget _buildSecuencialAlergias() => Container(); Widget _botonAccion(String l, bool sel, Color c, VoidCallback onTap) => Container(); Widget _buildCredentialBox(String l, String v, IconData i) => Container();
}
