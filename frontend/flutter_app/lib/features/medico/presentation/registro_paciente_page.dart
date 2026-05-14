import "dart:async";
import "dart:math";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";

import "../../../core/state/app_providers.dart";
import "../../../shared/widgets/layout_components.dart";
import "../data/repositorio_medico.dart";
import "../data/supervision_provider.dart";

import '../../../shared/widgets/escalas/escala_selector.dart';

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
  final _ingSearchCtrl = TextEditingController();
  final _ingRecomSearchCtrl = TextEditingController();
  final _ingFocus = FocusNode();
  final _ingRecomFocus = FocusNode();
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
  List<Map<String, dynamic>> _recomendacionesIng = [];
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
  String _resumenClinico = "Ingrese peso y talla para obtener el diagnóstico";
  double _gananciaPeso = 0;
  double _gananciaTalla = 0;
  String _estadoPeso = "mantener";
  bool _calculandoOMS = false;
  Color _omsColor = Colors.grey.shade400;
  double _pesoMediana = 0;
  double _tallaMediana = 0;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _generatedPassword = _generateRandomPassword();
    _fetchCatalogos().then((_) => _loadInitialData());
    _ingFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tutNombre.dispose();
    _tutCedula.dispose();
    _tutEmail.dispose();
    _tutTelefono.dispose();
    _tutDireccion.dispose();
    _pacNombre.dispose();
    _pacCedula.dispose();
    _clinPeso.dispose();
    _clinTalla.dispose();
    _clinPCR.dispose();
    _clinVSG.dispose();
    _clinArtInflam.dispose();
    _clinArtDolor.dispose();
    _clinRigidez.dispose();
    _clinNotas.dispose();
    _ingSearchCtrl.dispose();
    _ingFocus.dispose();
    _debounceOMS?.cancel();
    super.dispose();
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%';
    final rnd = Random.secure();
    return List.generate(10, (index) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _fetchCatalogos() async {
    setState(() => _loading = true);
    try {
      final catalogos = await ref
          .read(repositorioMedicoProvider)
          .obtenerCatalogosRegistroPaciente();
      if (mounted) {
        setState(() {
          _parentescos = catalogos["parentescos"] ?? [];
          _sexos = catalogos["sexos"] ?? [];
          _patologias = catalogos["patologias"] ?? [];
          _condicionesTemporalesCat = catalogos["condiciones_temporales"] ?? [];
          _ingredientes = catalogos["ingredientes"] ?? [];
          _cantones = catalogos["cantones"] ?? [];
          _parroquiasCat = catalogos["parroquias"] ?? [];
          _subgrupos = catalogos["subgrupos"] ?? [];
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
        final data = await ref
            .read(repositorioMedicoProvider)
            .obtenerExpedienteCompleto(widget.initialData!['id'].toString());
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
            _recomendacionesIng = (data['recomendaciones']?['ingredientes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
            
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
    _debounceOMS = Timer(const Duration(milliseconds: 200), () => _calculateOMS());
  }

  Future<void> _calculateOMS() async {
    double p = double.tryParse(_clinPeso.text) ?? 0;
    double t = double.tryParse(_clinTalla.text) ?? 0;
    if (p > 1 && t > 30 && _pacFechaNac != null && _pacSexo != null) {
      setState(() => _calculandoOMS = true);
      try {
        final data = await ref.read(repositorioMedicoProvider).preDiagnosticoNutricional({
          "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first,
          "id_sexo": _pacSexo, "peso_kg": p, "talla_cm": t
        });
        if (mounted) {
          setState(() {
            _omsStatusPeso = data['diagnostico_nutri_texto'] ?? "Normal";
            _omsStatusTalla = data['diagnostico_talla_texto'] ?? "Adecuada";
            _resumenClinico = data['resumen_clinico'] ?? "";
            _gananciaPeso = (data['ganancia_peso_necesaria'] ?? 0).toDouble();
            _gananciaTalla = (data['ganancia_talla_necesaria'] ?? 0).toDouble();
            _estadoPeso = data['estado_peso'] ?? "mantener";
            _pesoMediana = (data['peso_ideal'] ?? 0).toDouble();
            _tallaMediana = (data['talla_ideal'] ?? 0).toDouble();
            
            final String combined = (data['diagnostico_combinado'] ?? "$_omsStatusPeso / $_omsStatusTalla").toString().toLowerCase();
            if (combined.contains("severa") || combined.contains("emaciación") || combined.contains("obesidad") || combined.contains("desnutrición")) _omsColor = Colors.red;
            else if (combined.contains("sobrepeso") || combined.contains("baja") || combined.contains("delgadez") || combined.contains("bajo peso") || combined.contains("riesgo")) _omsColor = Colors.orange;
            else _omsColor = greenBrand;
            _calculandoOMS = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _calculandoOMS = false);
      }
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
                      if (_validateCurrentStep(_currentStep)) {
                        if (_currentStep < 2) setState(() => _currentStep++);
                        else _finish();
                      } else {
                        NutriSnack.show(context, "Complete campos obligatorios marcados con (*)", isError: true, ref: ref);
                      }
                    },
                    onStepCancel: () => setState(() => _currentStep > 0 ? _currentStep-- : null),
                    controlsBuilder: (context, details) => _buildControls(details),
                    steps: [_stepTutor(), _stepPaciente(), _stepClinico()],
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

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start, 
    children: [
      Row(children: [
        IconButton.filledTonal(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: greenBrand), onPressed: () => ref.read(medicoNavProvider.notifier).state = MedicoView.list), 
        const SizedBox(width: 24), 
        Expanded(child: Text(
          _idPacienteEditando == null ? "REGISTRO INTEGRAL PEDIÁTRICO" : "EXPEDIENTE: ${_pacNombre.text.toUpperCase()}", 
          style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          overflow: TextOverflow.ellipsis,
        ))
      ])
    ]
  );

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
          actions: [
            TextButton.icon(
              onPressed: () async {
                await _copiarCredencialesTutor();
                if (mounted) {
                  NutriSnack.show(context, "Credenciales copiadas", ref: ref);
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text("COPIAR"),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: greenBrand, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)), child: const Text("ACEPTAR Y REGISTRAR")),
          ],
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
          "recomendaciones_ingredientes": _recomendacionesIng.map((e) => e['id']).toList(),
          "condiciones_temporales": _condicionesTemp,
          "fecha_proxima_cita": _proximaCita.toIso8601String().split("T").first
        }
      };
      final repo = ref.read(repositorioMedicoProvider);
      if (_idPacienteEditando == null) {
        await repo.registrarPacienteIntegral(payload);
      } else {
        await repo.actualizarExpedienteMaestro(_idPacienteEditando!, payload);
      }
      
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      ref.invalidate(medicoPatientsProvider);
      if (mounted) ref.read(medicoNavProvider.notifier).state = MedicoView.list;
    } catch (e) {
      if (mounted) NutriSnack.show(context, "Error al guardar: $e", isError: true, ref: ref);
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _copiarCredencialesTutor() {
    final credenciales = [
      "Credenciales del tutor",
      "Usuario: ${_tutEmail.text}",
      "Clave temporal: $_generatedPassword",
    ].join("\n");
    return Clipboard.setData(ClipboardData(text: credenciales));
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

  Widget _miniHint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(Icons.info_outline, size: 12, color: Colors.blueGrey.shade300),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade400, fontStyle: FontStyle.italic))),
    ]),
  );

  Step _stepClinico() => Step(
    isActive: _currentStep >= (widget.fixedOnly ? 1 : 2),
    state: StepState.editing,
    title: Text("PROTOCOLO DE EVALUACIÓN CLÍNICA", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
    content: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // --- 1. ENFERMEDAD PRINCIPAL ---
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader("ENFERMEDAD PRINCIPAL", Icons.local_hospital_outlined),
            const SizedBox(height: 20),
            _dropdown("Patología / Enfermedad Base*", _patologias, _idPatologiaBase, (v) => setState(() => _idPatologiaBase = v)),
            const SizedBox(height: 20),
            _dropdown("Estado de la Enfermedad*", _estadosClinicos.asMap().entries.map((e) => {"id": e.key, "nombre": e.value}).toList(), _estadosClinicos.indexOf(_estadoEnfermedad), (v) => setState(() => _estadoEnfermedad = _estadosClinicos[v!])),
            if (!widget.fixedOnly) ...[
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),
              Text("ACTIVIDAD DE LA ENFERMEDAD (EVA)", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 11, color: const Color(0xFF475569), letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _miniHint("EVA = Escala Visual Análoga. Evalúa la percepción del paciente sobre su estado actual."),
              EscalaSelector(
            titulo: _dolor == 0 ? 'SIN DOLOR' : _dolor <= 3 ? 'LEVE' : _dolor <= 6 ? 'MODERADO' : _dolor <= 8 ? 'INTENSO' : 'INSOPORTABLE',
            descripcion: _dolor == 0 ? 'Sin molestias reportadas' : _dolor <= 3 ? 'Molestia ligera ocasional' : _dolor <= 6 ? 'Dolor que interfiere con actividades' : _dolor <= 8 ? 'Dolor fuerte y persistente' : 'Dolor extremo, requiere atención',
            min: 0,
            max: 10,
            value: _dolor.toInt(),
            icons: const [
              Icons.sentiment_very_satisfied_outlined,
              Icons.sentiment_satisfied_outlined,
              Icons.sentiment_neutral_outlined,
              Icons.sentiment_dissatisfied_outlined,
              Icons.sentiment_very_dissatisfied_outlined,
              Icons.sentiment_neutral_outlined,
              Icons.sentiment_dissatisfied_outlined,
              Icons.sentiment_very_dissatisfied_outlined,
              Icons.mood_bad_outlined,
              Icons.sick_outlined,
              Icons.personal_injury_outlined,
            ],
            etiquetas: [
              EscalaEtiqueta('Leve', 3),
              EscalaEtiqueta('Moderado', 4),
              EscalaEtiqueta('Severo', 4),
            ],
            colorActivo: _dolor == 0 ? greenBrand : _dolor <= 3 ? Colors.blue : _dolor <= 6 ? Colors.orange : Colors.red,
            colorFondoActivo: (_dolor == 0 ? greenBrand : _dolor <= 3 ? Colors.blue : _dolor <= 6 ? Colors.orange : Colors.red).withOpacity(0.1),
            onChanged: (v) => setState(() => _dolor = v.toDouble()),
            puntajeLabel: '${_dolor.toInt()}/10',
            headerIcon: Icon(_dolor == 0 ? Icons.sentiment_very_satisfied_rounded : _dolor <= 3 ? Icons.sentiment_satisfied_rounded : _dolor <= 6 ? Icons.sentiment_neutral_rounded : _dolor <= 8 ? Icons.sentiment_dissatisfied_rounded : Icons.sentiment_very_dissatisfied_rounded, color: _dolor == 0 ? greenBrand : _dolor <= 3 ? Colors.blue : _dolor <= 6 ? Colors.orange : Colors.red, size: 32),
          ),
          const SizedBox(height: 24),
          EscalaSelector(
            titulo: _inflamacion == 0 ? 'SIN INFLAMACIÓN' : _inflamacion == 1 ? 'LEVE / DISCRETA' : _inflamacion == 2 ? 'MODERADA' : 'SEVERA / ACTIVA',
            descripcion: _inflamacion == 0 ? 'Sin signos de inflamación' : _inflamacion == 1 ? 'Hinchazón mínima detectable' : _inflamacion == 2 ? 'Inflamación visible y limitante' : 'Inflamación severa y sistémica',
            min: 0,
            max: 3,
            value: _inflamacion.toInt(),
            icons: const [
              Icons.health_and_safety_outlined,
              Icons.healing_outlined,
              Icons.report_problem_outlined,
              Icons.local_fire_department_outlined,
            ],
            etiquetas: [
              EscalaEtiqueta('Leve', 1),
              EscalaEtiqueta('Moderada', 2),
              EscalaEtiqueta('Severa / Activa', 1),
            ],
            colorActivo: _inflamacion == 0 ? greenBrand : _inflamacion == 1 ? Colors.blue : _inflamacion == 2 ? Colors.orange : Colors.red,
            colorFondoActivo: (_inflamacion == 0 ? greenBrand : _inflamacion == 1 ? Colors.blue : _inflamacion == 2 ? Colors.orange : Colors.red).withOpacity(0.1),
            onChanged: (v) => setState(() => _inflamacion = v.toDouble()),
            puntajeLabel: '${_inflamacion.toInt()}/3',
            headerIcon: Icon(_inflamacion == 0 ? Icons.verified_user_rounded : _inflamacion == 1 ? Icons.healing_rounded : _inflamacion == 2 ? Icons.warning_rounded : Icons.whatshot_rounded, color: _inflamacion == 0 ? greenBrand : _inflamacion == 1 ? Colors.blue : _inflamacion == 2 ? Colors.orange : Colors.red, size: 32),
          ),
          const SizedBox(height: 24),
          EscalaSelector(
            titulo: _fatiga >= 8 ? 'MUCHA ENERGÍA' : _fatiga >= 5 ? 'NORMAL' : _fatiga >= 3 ? 'FATIGA LEVE' : 'AGOTAMIENTO',
            descripcion: _fatiga >= 8 ? 'Paciente con vitalidad máxima' : _fatiga >= 5 ? 'Energía estable para el día' : _fatiga >= 3 ? 'Cansancio superior al normal' : 'Falta total de energía basal',
            min: 0,
            max: 10,
            value: _fatiga.toInt(),
            icons: const [
              Icons.battery_0_bar_outlined,
              Icons.battery_1_bar_outlined,
              Icons.battery_2_bar_outlined,
              Icons.battery_3_bar_outlined,
              Icons.battery_4_bar_outlined,
              Icons.battery_5_bar_outlined,
              Icons.battery_6_bar_outlined,
              Icons.battery_full_outlined,
              Icons.bolt_outlined,
              Icons.flash_on_outlined,
              Icons.star_outline_rounded,
            ],
            etiquetas: [
              EscalaEtiqueta('Agotamiento', 3),
              EscalaEtiqueta('Intermedio', 5),
              EscalaEtiqueta('Alta energía', 3),
            ],
            colorActivo: _fatiga >= 8 ? greenBrand : _fatiga >= 5 ? Colors.blue : _fatiga >= 3 ? Colors.orange : _fatiga >= 2 ? Colors.red : Colors.red,
            colorFondoActivo: (_fatiga >= 8 ? greenBrand : _fatiga >= 5 ? Colors.blue : _fatiga >= 3 ? Colors.orange : _fatiga >= 2 ? Colors.red : Colors.red).withOpacity(0.1),
            onChanged: (v) => setState(() => _fatiga = v.toDouble()),
            puntajeLabel: '${_fatiga.toInt()}/10',
            headerIcon: Icon(_fatiga >= 8 ? Icons.battery_full_rounded : _fatiga >= 5 ? Icons.battery_charging_full_rounded : _fatiga >= 3 ? Icons.battery_alert_rounded : Icons.battery_0_bar_rounded, color: _fatiga >= 8 ? greenBrand : _fatiga >= 5 ? Colors.blue : _fatiga >= 3 ? Colors.orange : _fatiga >= 2 ? Colors.red : Colors.red, size: 32),
          ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _field(_clinPCR, "PCR (mg/L)", Icons.science_outlined)),
                const SizedBox(width: 16),
                Expanded(child: _field(_clinVSG, "VSG/VRC (mm/h)", Icons.bloodtype_outlined)),
              ]),
              _miniHint("PCR = Proteína C Reactiva. VSG/VRC = Velocidad de Sedimentación Globular. Marcadores de inflamación sistémica."),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _field(_clinArtInflam, "Art. Inflamadas", Icons.adjust_rounded)),
                const SizedBox(width: 16),
                Expanded(child: _field(_clinArtDolor, "Art. Dolorosas", Icons.pan_tool_alt_rounded)),
              ]),
              _miniHint("Número de articulaciones con inflamación visible / dolorosas a la palpación en el examen físico."),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _brote ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: _brote ? Colors.red : greenBrand)),
                child: SwitchListTile(title: Text(_brote ? "BROTE ACTIVO DETECTADO" : "SIN BROTE ACTIVO", style: TextStyle(fontWeight: FontWeight.w900, color: _brote ? Colors.red : greenBrand, fontSize: 13)), subtitle: const Text("¿Presenta crisis hoy?", style: TextStyle(fontSize: 11)), value: _brote, onChanged: (v) => setState(() => _brote = v), activeColor: Colors.red),
              ),
            ],
          ]),
        ),

        // --- 2. ALERGIAS E INTOLERANCIAS ---
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader("ALERGIAS E INTOLERANCIAS", Icons.warning_amber_rounded),
            const SizedBox(height: 20),
            _buildIntoleranciaLactosa(),
            const SizedBox(height: 32),
            _buildAlergiasCheckboxes(),
          ]),
        ),

        // --- 3. IDENTIFICAR CONDICIÓN NUTRICIONAL ---
        if (!widget.fixedOnly) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader("IDENTIFICAR CONDICIÓN NUTRICIONAL", Icons.scale_outlined),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _field(_clinPeso, "Peso Inicial (kg)*", Icons.monitor_weight_outlined, onChanged: (_) => _debouncedOMS())),
                const SizedBox(width: 20),
                Expanded(child: _field(_clinTalla, "Talla Inicial (cm)*", Icons.height_outlined, onChanged: (_) => _debouncedOMS())),
              ]),
              const SizedBox(height: 20),
              _buildProfessionalPrediagnosis(),
            ]),
          ),
        ],

        // --- 4. CONDICIONES TEMPORALES ---
        if (!widget.fixedOnly) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader("CONDICIONES TEMPORALES", Icons.event_note_rounded),
              const SizedBox(height: 16),
              _buildSintomasTemporalesSelector(),
            ]),
          ),
        ],

        // --- 5. RECOMENDACIÓN DE INGREDIENTES (NUEVO) ---
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader("INGREDIENTES RECOMENDADOS / SEGUROS", Icons.thumb_up_alt_outlined),
            const SizedBox(height: 16),
            _miniHint("Seleccione ingredientes que desea priorizar o que considera especialmente beneficiosos para el paciente."),
            _buildRecomendacionesSelector(),
          ]),
        ),

        // --- 6. OBSERVACIONES ---
        const SizedBox(height: 24),
        _field(_clinNotas, "Observaciones Médicas Iniciales", Icons.edit_note_rounded, maxLines: 4),
      ]),
    )
  );

  Widget _buildRecomendacionesSelector() {
    if (_ingredientes.isEmpty) return const Text("Cargando ingredientes...");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatefulBuilder(
          builder: (context, setInternalState) {
            final q = _ingRecomSearchCtrl.text.toLowerCase().trim();
            final matches = _ingredientes.where((e) {
              if (q.isEmpty) return false;
              final name = (e['nombre'] ?? "").toString().toLowerCase();
              final syns = (e['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
              return name.contains(q) || syns.any((s) => s.contains(q));
            }).toList();

            return Column(
              children: [
                TextFormField(
                  controller: _ingRecomSearchCtrl,
                  focusNode: _ingRecomFocus,
                  onChanged: (v) => setInternalState(() {}),
                  decoration: InputDecoration(
                    labelText: "Buscar ingrediente a recomendar...",
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.blue),
                    suffixIcon: q.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _ingRecomSearchCtrl.clear(); setInternalState(() {}); }) : null,
                  ),
                ),
                if (matches.isNotEmpty && _ingRecomFocus.hasFocus)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: matches.length > 50 ? 50 : matches.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = matches[i];
                        final isSel = _recomendacionesIng.any((ing) => ing['id'] == item['id']);
                        return ListTile(
                          dense: true,
                          title: Text(item['nombre'] ?? ""),
                          trailing: isSel ? const Icon(Icons.check_circle, color: Colors.blue) : const Icon(Icons.add_circle_outline),
                          onTap: () {
                            setState(() {
                              if (!isSel) {
                                _recomendacionesIng.add(Map<String, dynamic>.from(item));
                                _autoRecomendarDerivados(item['nombre']?.toString() ?? "");
                              }
                              else _recomendacionesIng.removeWhere((ing) => ing['id'] == item['id']);
                            });
                            setInternalState(() {});
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (_recomendacionesIng.isEmpty)
          const Text("No ha seleccionado ingredientes recomendados.", style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic))
        else
          Wrap(spacing: 8, runSpacing: 8, children: _recomendacionesIng.map((e) => Chip(
            label: Text(e['nombre']?.toString() ?? "", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
            onDeleted: () => setState(() => _recomendacionesIng.remove(e)),
            backgroundColor: Colors.blue.shade50, deleteIconColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          )).toList()),
      ],
    );
  }

  Widget _buildIntoleranciaLactosa() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text("¿PRESENTA INTOLERANCIA A LA LACTOSA?*", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5)),
    const SizedBox(height: 20),
    Row(children: [_yesNoBtn("SÍ, RESTRICCIÓN ACTIVA", true, _lactosa == true, (v) {
      setState(() {
        _lactosa = v;
        if (v == true) {
          _alergiasSub.removeWhere((id) => _idsLacteos.contains(id));
        }
      });
    }), const SizedBox(width: 20), _yesNoBtn("NO DETECTADA", false, _lactosa == false, (v) => setState(() => _lactosa = v))])
  ]);

  Widget _yesNoBtn(String l, bool val, bool sel, Function(bool) onTap) => Expanded(child: InkWell(onTap: () => onTap(val), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: sel ? (val ? Colors.red.shade50 : greenBrand.withOpacity(0.1)) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? (val ? Colors.red : greenBrand) : const Color(0xFFE2E8F0), width: 2.5)), child: Center(child: Text(l, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: sel ? (val ? Colors.red : greenBrand) : Colors.blueGrey))))));

  String _emojiSubgrupo(int id) {
    return {
      8: "🍄", 9: "🍄", 10: "🥔", 11: "🥦", 12: "🥫", 13: "🥬", 14: "🥤", 15: "🍓",
      16: "🍇", 17: "🍎", 18: "🥜", 19: "🍊", 24: "🥚", 25: "🍗", 26: "🐖", 27: "🐑",
      29: "🥩", 30: "🐄", 31: "🫀", 32: "🦐", 33: "🐟", 34: "🐠", 35: "🐟", 36: "🥫",
      37: "🧂", 38: "🫒", 41: "🧄", 43: "🍬", 47: "🍭", 48: "🍿", 49: "🥤", 50: "💧",
      51: "☕", 53: "🧃", 88: "🌾", 89: "🌾", 90: "🍞", 91: "🍞", 92: "🍝", 93: "🫘",
      94: "🌱", 95: "🫘", 96: "🥫", 97: "🥜", 98: "🥛", 99: "🥛", 100: "🍶", 101: "🥛",
      102: "🥛", 103: "🥥", 104: "🥛", 105: "🧀", 106: "🧀", 107: "🧀", 108: "🧀",
      109: "🥓", 110: "🌭", 111: "🧈", 112: "🧈", 113: "🥓", 114: "🥣", 115: "🥣",
      116: "🥢", 117: "🍫", 118: "🍫", 119: "🍮", 120: "🍬", 121: "🍪", 122: "🥛",
      123: "🥛", 124: "🥛",
    }[id] ?? "🍽️";
  }

  void _autoBloquearDerivados(String nombreSeleccionado) {
    _autoExpandirIngredientes(nombreSeleccionado, _selectedIngredientes);
  }

  void _autoRecomendarDerivados(String nombreSeleccionado) {
    _autoExpandirIngredientes(nombreSeleccionado, _recomendacionesIng);
  }

  void _autoExpandirIngredientes(String nombreSeleccionado, List<Map<String, dynamic>> lista) {
    final n = nombreSeleccionado.toLowerCase().trim();
    if (n.length < 3) return;

    final stopWords = {'de', 'con', 'en', 'el', 'la', 'los', 'las', 'un', 'una', 'para', 'sin', 'y', 'del'};
    final words = n.split(' ').where((w) => w.length > 2 && !stopWords.contains(w)).toList();
    if (words.isEmpty && n.isNotEmpty) words.add(n);

    final derivados = _ingredientes.where((i) {
      final iname = (i['nombre'] ?? "").toString().toLowerCase();
      final sinonimos = (i['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
      
      if (iname == n) return false;

      bool match(String source, String target) {
        if (source.isEmpty || target.isEmpty) return false;
        final sourceWords = source.split(' ');
        return words.any((w) => sourceWords.contains(w)) || sourceWords.any((sw) => words.contains(sw));
      }

      if (match(iname, n)) return true;
      for (var s in sinonimos) {
        if (s.trim().isEmpty) continue;
        if (match(s, n)) return true;
      }
      return false;
    }).toList();

    for (var d in derivados) {
      if (!lista.any((x) => x['id'] == d['id'])) {
        setState(() => lista.add(Map<String, dynamic>.from(d)));
      }
    }
  }

  Widget _richSummary(String text, Color color) {
    List<TextSpan> spans = [];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(text: parts[i], style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)));
      } else {
        spans.add(TextSpan(text: parts[i]));
      }
    }
    return RichText(text: TextSpan(style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, height: 1.4, fontFamily: GoogleFonts.montserrat().fontFamily), children: spans));
  }

  Widget _buildSintomasTemporalesSelector() {
    return Column(children: [
      _dropdown("Seleccionar condición temporal", _condicionesTemporalesCat, null, (v) async {
        if (v != null) {
          final s = _condicionesTemporalesCat.firstWhere((e) => e['id'] == v);
          final DateTime? inicio = await showDatePicker(
            context: context, initialDate: DateTime.now(), 
            firstDate: DateTime.now().subtract(const Duration(days: 30)), 
            lastDate: DateTime.now().add(const Duration(days: 60)),
            helpText: "FECHA DE INICIO DE LA CONDICIÓN"
          );
          if (inicio != null && !_condicionesTemp.any((ct) => ct['id'] == v)) {
            final int dias = (s['duracion_dias_sugerida'] ?? s['dias_duracion_estandar'] ?? 7).toInt();
            final fin = inicio.add(Duration(days: dias));
            setState(() => _condicionesTemp.add({
              "id": v, "nombre": s['nombre'],
              "fecha_inicio": inicio.toIso8601String().split('T')[0],
              "fecha_fin": fin.toIso8601String().split('T')[0],
              "duracion": dias
            }));
          }
        }
      }),
      const SizedBox(height: 16),
      if (_condicionesTemp.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text("No hay condiciones temporales registradas.", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic)))
      else
        ...List.generate(_condicionesTemp.length, (i) {
          final ct = _condicionesTemp[i];
          final DateTime fin = DateTime.parse(ct['fecha_fin']);
          final int restantes = fin.difference(DateTime.now()).inDays;
          return Card(
            margin: const EdgeInsets.only(bottom: 8), elevation: 0, color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: ListTile(
              leading: Icon(restantes <= 0 ? Icons.check_circle : Icons.schedule, color: restantes <= 0 ? Colors.green : restantes <= 3 ? Colors.orange : Colors.blueGrey),
              title: Text(ct['nombre']?.toString() ?? "Condición", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Del ${ct['fecha_inicio']} al ${ct['fecha_fin']}", style: const TextStyle(fontSize: 11)),
                Row(children: [
                  Text("Duración: ${ct['duracion'] ?? 7} días", style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Icon(Icons.timer_outlined, size: 12, color: restantes <= 0 ? Colors.green : restantes <= 3 ? Colors.orange : Colors.blueGrey),
                  const SizedBox(width: 4),
                  Text(restantes <= 0 ? "VENCIDA" : "$restantes días restantes", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: restantes <= 0 ? Colors.green : restantes <= 3 ? Colors.orange : Colors.blueGrey)),
                ]),
              ]),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _condicionesTemp.removeAt(i))),
            ),
          );
        })
    ]);
  }

  Widget _buildAlergiasCheckboxes() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    CheckboxListTile(title: const Text("TIENE ALERGIAS A GRUPOS ALIMENTARIOS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), value: _tieneAlergiaSub, onChanged: (v) => setState(() => _tieneAlergiaSub = v!), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, activeColor: greenBrand),
    if (_tieneAlergiaSub) _multiSelectChips("SELECCIONE GRUPOS RESTRINGIDOS", _subgrupos, _alergiasSub, (id, sel) { setState(() { if (sel) _alergiasSub.add(id); else _alergiasSub.remove(id); }); }, blockedIds: _lactosa == true ? _idsLacteos : {}),
    const SizedBox(height: 12),
    CheckboxListTile(title: const Text("TIENE ALERGIAS A INGREDIENTES ESPECÍFICOS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), value: _tieneAlergiaIng, onChanged: (v) => setState(() => _tieneAlergiaIng = v!), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, activeColor: greenBrand),
    if (_tieneAlergiaIng) ...[
      const SizedBox(height: 12),
      if (_ingredientes.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
          child: Row(children: [
            const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text("Catálogo de ingredientes no disponible. Verifique su conexión.", style: TextStyle(fontSize: 11, color: Colors.orange.shade800))),
          ]),
        )
      else ...[
        StatefulBuilder(
          builder: (context, setInternalState) {
            final q = _ingSearchCtrl.text.toLowerCase().trim();
            final matches = _ingredientes.where((e) {
              // Filtrar por subgrupos bloqueados (Lactosa + Subgrupos seleccionados)
              final idSub = (e['id_subgrupo_alimentario'] as num?)?.toInt();
              final subBloqueados = <int>{};
              if (_lactosa == true) subBloqueados.addAll(_idsLacteos);
              subBloqueados.addAll(_alergiasSub);
              if (idSub != null && subBloqueados.contains(idSub)) return false;

              if (q.isEmpty) return true;
              final name = (e['nombre'] ?? "").toString().toLowerCase();
              final syns = (e['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
              return name.contains(q) || syns.any((s) => s.contains(q));
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ingSearchCtrl,
                        focusNode: _ingFocus,
                        onChanged: (v) => setInternalState(() {}),
                        decoration: InputDecoration(
                          labelText: q.isEmpty ? "Buscar ingrediente (ej: fresa, maní, gluten)..." : "Filtrando: $q",
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: q.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _ingSearchCtrl.clear(); setInternalState(() {}); }) : null,
                        ),
                      ),
                    ),
                    if (q.isNotEmpty && matches.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            for (var m in matches) {
                              if (!_selectedIngredientes.any((ing) => ing['id'] == m['id'])) {
                                _selectedIngredientes.add(Map<String, dynamic>.from(m));
                              }
                            }
                            _ingSearchCtrl.clear();
                          });
                          setInternalState(() {});
                        },
                        icon: const Icon(Icons.playlist_add_check_rounded, color: greenBrand),
                        label: Text("MARCAR ${matches.length}", style: const TextStyle(color: greenBrand, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ],
                ),
                if (_ingSearchCtrl.text.isNotEmpty || _ingFocus.hasFocus) 
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: matches.length > 50 ? 50 : matches.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = matches[i];
                        final isSel = _selectedIngredientes.any((ing) => ing['id'] == item['id']);
                        return ListTile(
                          dense: true,
                          title: Text(item['nombre'] ?? "", style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? greenBrand : Colors.black)),
                          trailing: isSel ? const Icon(Icons.check_circle, color: greenBrand, size: 18) : const Icon(Icons.add_circle_outline, size: 18),
                          onTap: () {
                            setState(() {
                              if (!isSel) {
                                _selectedIngredientes.add(Map<String, dynamic>.from(item));
                                _autoBloquearDerivados(item['nombre']?.toString() ?? "");
                              } else {
                                _selectedIngredientes.removeWhere((ing) => ing['id'] == item['id']);
                              }
                            });
                            setInternalState(() {});
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
      Wrap(spacing: 12, runSpacing: 12, children: _selectedIngredientes.map((e) => Chip(label: Text(e['nombre']?.toString() ?? "Ingrediente", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 11)), onDeleted: () => setState(() => _selectedIngredientes.remove(e)), backgroundColor: Colors.orange.shade50, deleteIconColor: Colors.deepOrange, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.orange.shade200)))).toList())
    ]
  ]);

  Widget _multiSelectChips(String label, List items, List<int> sel, Function(int, bool) onS, {Set<int> blockedIds = const {}}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
    const SizedBox(height: 16),
    Wrap(spacing: 10, runSpacing: 10, children: items.map((i) { 
      final id = (i['id'] as num).toInt(); final s = sel.contains(id); final b = blockedIds.contains(id); 
      final emoji = i['emoji']?.toString() ?? _emojiSubgrupo(id);
      return FilterChip(
        label: Row(mainAxisSize: MainAxisSize.min, children: [Text(emoji, style: const TextStyle(fontSize: 16)), const SizedBox(width: 8), Text(i['nombre'] ?? "", style: TextStyle(fontSize: 11, fontWeight: s ? FontWeight.bold : FontWeight.w500, color: b ? Colors.grey.shade400 : (s ? greenBrand : const Color(0xFF475569))))]), 
        selected: s, onSelected: b ? null : (v) => onS(id, v), selectedColor: greenBrand.withOpacity(0.12), checkmarkColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: s ? greenBrand.withOpacity(0.3) : const Color(0xFFE2E8F0))), backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
      ); 
    }).toList()),
    const SizedBox(height: 24),
  ]);

  Widget _buildProfessionalPrediagnosis() => Container(
    padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: _omsColor.withOpacity(0.06), borderRadius: BorderRadius.circular(24), border: Border.all(color: _omsColor.withOpacity(0.2), width: 2)), 
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Icon(Icons.analytics_rounded, color: _omsColor, size: 22), const SizedBox(width: 12), Text("DIAGNÓSTICO NUTRICIONAL OMS", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF475569)))]),
        if (_calculandoOMS) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: greenBrand))
        else IconButton(onPressed: _calculateOMS, icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.blueGrey), tooltip: "Recalcular")
      ]),
      const SizedBox(height: 24),
      Text("${_omsStatusPeso.toUpperCase()} / ${_omsStatusTalla.toUpperCase()}", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
      if (_resumenClinico.isNotEmpty) ...[
        const SizedBox(height: 12),
        _richSummary(_resumenClinico, _omsColor),
      ],
      const Divider(height: 40),
      Row(children: [
        _metaItem("PESO IDEAL", "${_pesoMediana.toStringAsFixed(1)} kg", Icons.scale_rounded),
        const SizedBox(width: 24),
        _metaItem("TALLA IDEAL", "${_tallaMediana.toStringAsFixed(1)} cm", Icons.height_rounded),
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(_estadoPeso == "aumentar" ? Icons.trending_up_rounded : _estadoPeso == "disminuir" ? Icons.trending_down_rounded : Icons.trending_flat_rounded, color: _omsColor),
          const SizedBox(width: 16),
          Expanded(child: Text(
            _estadoPeso == "mantener"
                ? (_gananciaTalla > 0.5
                    ? "EL PACIENTE TIENE UN PESO ADECUADO, PERO PRESENTA RETRASO DE TALLA (${_gananciaTalla.toStringAsFixed(1)} CM)."
                    : "EL PACIENTE TIENE UN PESO ADECUADO.")
                : (_gananciaTalla > 0.5
                    ? "EL PACIENTE DEBE ${_estadoPeso.toUpperCase()} ${_gananciaPeso.abs().toStringAsFixed(1)} KG Y CRECER ${_gananciaTalla.toStringAsFixed(1)} CM."
                    : "EL PACIENTE DEBE ${_estadoPeso.toUpperCase()} ${_gananciaPeso.abs().toStringAsFixed(1)} KG."),
            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))
          ))
        ]),
      )
    ])
  );

  Widget _metaItem(String l, String v, IconData i) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(i, size: 14, color: Colors.blueGrey), const SizedBox(width: 8), Text(l, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blueGrey))]),
    const SizedBox(height: 4),
    Text(v, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
  ]));

  Future<void> _buscarTutor(String c) async { 
    if (c.length < 10) return;
    setState(() { _buscandoTutor = true; _tutorNoEncontrado = false; _tutorExistente = false; }); 
    try { 
      final res = await ref.read(repositorioMedicoProvider).buscarTutorPorCedula(c); 
      if (mounted) {
        if (res['existe'] == true) { 
          final t = res['tutor']; 
          setState(() { 
            _tutNombre.text = (t['nombre_completo'] ?? "").toString(); 
            _tutEmail.text = (t['email'] ?? "").toString(); 
            _tutTelefono.text = (t['telefono'] ?? "").toString(); 
            _tutDireccion.text = (t['direccion'] ?? "").toString(); 
            _tutorExistente = true; 
          });
          // NutriSnack removed
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
}
