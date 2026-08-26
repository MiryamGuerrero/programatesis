import "dart:async";
import "dart:math";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";
import "package:dio/dio.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";
import "../data/repositorio_medico.dart";
import "../data/supervision_provider.dart";
import "_shared/medico_nav_providers.dart";

import '../../../shared/widgets/escalas/escala_selector.dart';
import '../../../shared/widgets/role_shell.dart';
import '../../../shared/widgets/custom_date_picker.dart';

class RegistroPacientePage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool fixedOnly;
  const RegistroPacientePage(
      {super.key, this.initialData, this.fixedOnly = false});

  @override
  ConsumerState<RegistroPacientePage> createState() =>
      _RegistroPacientePageState();
}

class _RegistroPacientePageState extends ConsumerState<RegistroPacientePage> {
  int _currentStep = 0;
  bool _loading = false;
  bool _sending = false;
  bool _showSuccess = false;
  String? _idPacienteEditando;
  Timer? _debounceOMS;
  Timer? _debounceCedulaPaciente;

  static const Color greenBrand = AppTema.verdeSalud;

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
  bool _credencialesCopiadas = false;

  // Paciente
  final _pacNombre = TextEditingController();
  final _pacCedula = TextEditingController();
  int? _pacSexo;
  int? _pacCanton;
  int? _pacParroquia;
  DateTime? _pacFechaNac;
  final _pacFechaNacCtrl = TextEditingController();
  bool _validandoCedulaPaciente = false;
  String? _mensajeCedulaPaciente;

  // Clínico
  final _clinPeso = TextEditingController();
  final _clinTalla = TextEditingController();
  final _clinArtInflam = TextEditingController(text: "0");
  final _clinArtDolor = TextEditingController(text: "0");
  final _clinRigidez = TextEditingController();
  final _clinNotas = TextEditingController();
  final _ingSearchCtrl = TextEditingController();
  final _subgrupoSearchCtrl = TextEditingController();
  final _ingredienteAlergiaSearchCtrl = TextEditingController();
  final _ingRecomSearchCtrl = TextEditingController();
  final _ingFocus = FocusNode();
  final _subgrupoFocus = FocusNode();
  final _ingredienteAlergiaFocus = FocusNode();
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
  late TextEditingController _proximaCitaCtrl;

  bool _tieneAlergiaSub = false;
  bool _tieneAlergiaIng = false;
  List<int> _alergiasSub = [];
  Set<String> _restriccionesAlimentarias = {};
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
  List<dynamic> _restriccionesAlimentariasCat = [];
  static const Set<int> _subgruposLactosa = {
    98,
    100,
    101,
    104,
    105,
    108,
    111,
    114,
    117,
    119
  };
  List<dynamic> _cantones = [];
  List<dynamic> _parroquiasCat = [];
  List<dynamic> _parroquiasFiltradas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(menuExpandedProvider.notifier).state = false;
    });
    _generatedPassword = _generateRandomPassword();
    _proximaCitaCtrl = TextEditingController(text: DateFormat('dd/MM/yyyy', 'es').format(_proximaCita));
    _fetchCatalogos().then((_) => _loadInitialData());
    _ingFocus.addListener(() => setState(() {}));
  }

  Future<void> _pickProximaCita() async {
    final d = await showCustomDatePicker(
      context,
      initialDate: _proximaCita,
      colorActivo: AppTema.azulPrincipal,
      colorTexto: AppTema.azulOscuro,
    );
    if (d != null) {
      setState(() {
        _proximaCita = d;
        _proximaCitaCtrl.text = DateFormat('dd/MM/yyyy', 'es').format(d);
      });
    }
  }

  @override
  void dispose() {
    _proximaCitaCtrl.dispose();
    _tutNombre.dispose();
    _tutCedula.dispose();
    _tutEmail.dispose();
    _tutTelefono.dispose();
    _tutDireccion.dispose();
    _pacNombre.dispose();
    _pacCedula.dispose();
    _clinPeso.dispose();
    _clinTalla.dispose();
    _clinArtInflam.dispose();
    _clinArtDolor.dispose();
    _clinRigidez.dispose();
    _clinNotas.dispose();
    _ingSearchCtrl.dispose();
    _subgrupoSearchCtrl.dispose();
    _ingredienteAlergiaSearchCtrl.dispose();
    _ingFocus.dispose();
    _subgrupoFocus.dispose();
    _ingredienteAlergiaFocus.dispose();
    _debounceOMS?.cancel();
    _debounceCedulaPaciente?.cancel();
    super.dispose();
  }

  String _generateRandomPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%';
    final rnd = Random.secure();
    return List.generate(10, (index) => chars[rnd.nextInt(chars.length)])
        .join();
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
          _patologias = ((catalogos["patologias"] ?? []) as List)
              .where((p) => !_sinAcentos(_norm(p['nombre']).toLowerCase())
                  .contains("general reumatic"))
              .toList();
          _condicionesTemporalesCat = catalogos["condiciones_temporales"] ?? [];
          _restriccionesAlimentariasCat =
              catalogos["restricciones_alimentarias"] ?? [];
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
      _parroquiasFiltradas =
          _parroquiasCat.where((p) => p['id_canton'] == _pacCanton).toList();
      if (resetSelection)
        _pacParroquia = null;
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

            if (t.isNotEmpty) {
              _tutNombre.text = t['nombre_completo'] ?? "";
              _tutCedula.text = t['cedula'] ?? "";
              _tutEmail.text = t['email'] ?? "";
              _tutTelefono.text = t['telefono'] ?? "";
              _tutDireccion.text = t['direccion'] ?? "";
              _tutParentesco = t['id_parentesco'];
              _tutorExistente = true;
              _tutorNoEncontrado = false;
            } else {
              _tutorExistente = false;
              _tutorNoEncontrado = true;
            }

            _idPatologiaBase = d['id_condicion'];
            _clinNotas.text = d['observaciones'] ?? "";

            if (al != null) {
              _alergiasSub = (al['subgrupos'] as List? ?? [])
                  .map((e) => (e['id'] as num).toInt())
                  .toList();
              _selectedIngredientes = (al['ingredientes'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              _tieneAlergiaSub = _alergiasSub.isNotEmpty;
              _tieneAlergiaIng = _selectedIngredientes.isNotEmpty;
              final restriccionesRaw =
                  (data['restricciones_alimentarias'] as List?) ??
                      (al['restricciones_codigos'] as List?) ??
                      const [];
              _restriccionesAlimentarias =
                  restriccionesRaw.map((e) => e.toString()).toSet();
              _lactosa = (data['es_intolerante_lactosa'] == true) ||
                  _restriccionesAlimentarias.contains("INTOLERANCIA_LACTOSA");
              if (_lactosa == true) {
                _restriccionesAlimentarias.add("INTOLERANCIA_LACTOSA");
              }
            }

            final c = data['ultimo_control'] ?? {};
            if (c.isNotEmpty) {
              _clinPeso.text = c['peso_kg']?.toString() ?? "";
              _clinTalla.text = c['talla_cm']?.toString() ?? "";
              _clinArtInflam.text =
                  c['articulaciones_inflamadas']?.toString() ?? "0";
              _clinArtDolor.text =
                  c['articulaciones_dolorosas']?.toString() ?? "0";
              _clinRigidez.text = c['minutos_rigidez']?.toString() ?? "";
              _dolor = (c['puntos_dolor'] ?? 0).toDouble();
              _inflamacion = (c['escala_inflamacion'] ?? 0).toDouble();
              _fatiga = (c['nivel_fatiga'] ?? 10).toDouble();
              _brote = c['en_brote'] ?? false;
              _estadoEnfermedad =
                  c['estado_enfermedad'] ?? "Estable en remisión";
              _proximaCita = DateTime.tryParse(c['fecha_proxima_cita'] ?? "") ??
                  DateTime.now().add(const Duration(days: 30));
            }

            _condicionesTemp = (data['condiciones_temporales'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            _recomendacionesIng =
                (data['recomendaciones']?['ingredientes'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();

            if (widget.fixedOnly) {
              _fixedInitialSnapshot = _buildFixedSnapshot();
            }
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
    _debounceOMS =
        Timer(const Duration(milliseconds: 200), () => _calculateOMS());
  }

  Future<void> _calculateOMS() async {
    double p = double.tryParse(_clinPeso.text) ?? 0;
    double t = double.tryParse(_clinTalla.text) ?? 0;
    if (p > 1 && t > 30 && _pacFechaNac != null && _pacSexo != null) {
      setState(() { _calculandoOMS = true; _omsError = null; });
      try {
        double asDouble(dynamic value, {double fallback = 0}) {
          if (value is num) return value.toDouble();
          return double.tryParse(value?.toString() ?? "") ?? fallback;
        }

        final data = await ref
            .read(repositorioMedicoProvider)
            .preDiagnosticoNutricional({
          "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first,
          "id_sexo": _pacSexo,
          "peso_kg": p,
          "talla_cm": t
        });
        if (mounted) {
          setState(() {
            _omsStatusPeso = data['diagnostico_nutri_texto'] ?? "Normal";
            _omsStatusTalla = data['diagnostico_talla_texto'] ?? "Adecuada";
            _resumenClinico = data['resumen_clinico'] ?? "";
            _gananciaPeso = asDouble(data['ganancia_peso_necesaria']);
            _gananciaTalla = asDouble(data['ganancia_talla_necesaria']);
            _estadoPeso = data['estado_peso'] ?? "mantener";
            _pesoMediana = asDouble(data['peso_ideal']);
            _tallaMediana = asDouble(data['talla_ideal']);

            final combined = (data['diagnostico_combinado'] ??
                    "$_omsStatusPeso / $_omsStatusTalla")
                .toString()
                .toLowerCase();
            if (combined.contains("severa") ||
                combined.contains("emaciación") ||
                combined.contains("desnutrición"))
              _omsColor = Colors.red;
            else if (combined.contains("sobrepeso") ||
                combined.contains("riesgo"))
              _omsColor = Colors.orange;
            else
              _omsColor = greenBrand;
            _calculandoOMS = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _calculandoOMS = false;
            String err = e.toString().replaceAll("Exception: ", "").replaceAll("Exception", "").trim();
            if (err.toLowerCase().contains("connection error") || err.toLowerCase().contains("dioexception") || err.toLowerCase().contains("apierror") || err.toLowerCase().contains("failed host lookup")) {
              err = "Error de conexión con el servidor. Verifica tu internet e intenta de nuevo.";
            }
            _omsError = err;
            _omsColor = Colors.red;
          });
        }
      }
    }
  }

  String _omsStatusPeso = "PENDIENTE";
  String _omsStatusTalla = "PENDIENTE";
  String _resumenClinico = "";
  double _gananciaPeso = 0;
  double _gananciaTalla = 0;
  String _estadoPeso = "mantener";
  bool _calculandoOMS = false;
  String? _omsError;
  Color _omsColor = Colors.grey;
  double _pesoMediana = 0;
  double _tallaMediana = 0;

  final _formKeyTutor = GlobalKey<FormState>();
  final _formKeyPaciente = GlobalKey<FormState>();
  final _formKeyClinico = GlobalKey<FormState>();
  Map<String, dynamic> _fixedInitialSnapshot = {};

  @override
  Widget build(BuildContext context) {

    if (widget.fixedOnly) {
      return _buildFixedOnlyPage();
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHeader(),
              const SizedBox(height: 56),
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 950), child: Theme(
                data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: greenBrand),
                    inputDecorationTheme: const InputDecorationTheme(
                        filled: true,
                        fillColor: Color(0xFFF1F5F9),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppTema.azulPrincipal, width: 2)),
                        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: AppTema.azulPrincipal, fontSize: 13),
                    )),
                child: Stepper(
                    type: StepperType.vertical,
                    currentStep: _currentStep,
                    physics: const NeverScrollableScrollPhysics(),
                    onStepContinue: () {
                      bool stepValid = false;
                      if (_currentStep == 0) stepValid = _formKeyTutor.currentState?.validate() ?? false;
                      else if (_currentStep == 1) stepValid = _formKeyPaciente.currentState?.validate() ?? false;
                      else if (_currentStep == 2) stepValid = _formKeyClinico.currentState?.validate() ?? false;

                      if (_validateCurrentStep(_currentStep) && stepValid) {
                        if (_currentStep < 2)
                          setState(() => _currentStep++);
                        else
                          _finish();
                      }
                    },
                    onStepCancel: () => setState(
                        () => _currentStep > 0 ? _currentStep-- : null),
                    controlsBuilder: (context, details) =>
                        _buildControls(details),
                    steps: [_stepTutor(), _stepPaciente(), _stepClinico()],
                  ),
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

  Widget _buildFixedOnlyPage() {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                Theme(
                  data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(primary: greenBrand),
                      inputDecorationTheme: const InputDecorationTheme(
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide:
                                BorderSide(color: greenBrand, width: 2)),
                        labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                            fontSize: 13),
                      )),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Form(key: _formKeyTutor, child: _fixedSection("Representante legal", Icons.person_outline, _buildFixedTutorFields())),
                        const SizedBox(height: 24),
                        Form(key: _formKeyPaciente, child: _fixedSection("Datos generales del paciente", Icons.badge_outlined, _buildFixedPatientFields())),
                        const SizedBox(height: 24),
                        Form(key: _formKeyClinico, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _fixedSection("Enfermedad y diagnostico", Icons.coronavirus_outlined, _buildFixedDiseaseFields()),
                          const SizedBox(height: 24),
                          _fixedSection("Alergias e intolerancias", Icons.warning_amber_rounded, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("Registra restricciones alimentarias y alergias relevantes del paciente.", style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 32),
                            _buildAlergiasStepContent(),
                          ])),
                          const SizedBox(height: 24),
                          _fixedSection("Condiciones temporales", Icons.event_note_rounded, _buildSintomasTemporalesSelector()),
                        ])),
                        const SizedBox(height: 36),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 320,
                            child: FilledButton.icon(
                              onPressed: () {
                                final tOk = _formKeyTutor.currentState?.validate() ?? false;
                                final pOk = _formKeyPaciente.currentState?.validate() ?? false;
                                final cOk = _formKeyClinico.currentState?.validate() ?? false;
                                if (tOk && pOk && cOk) _confirmAndFinishFixedOnly();
                              },
                              icon: const Icon(Icons.save_alt_rounded),
                              label: const Text("Actualizar datos médicos"),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_sending) _buildSendingOverlay(),
      ],
    );
  }

  Widget _fixedSection(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title, icon),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildFixedTutorFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: _field(
            _tutCedula,
            "Cédula del tutor*",
            Icons.assignment_ind_outlined,
            hint: "Ingrese la cédula del tutor",
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)
            ],
            onChanged: (v) {
              final limpia = _soloDigitos(v);
              if (limpia.length == 10) {
                _buscarTutor(limpia);
              } else if (_tutorExistente || _tutorNoEncontrado) {
                setState(() {
                  _tutorExistente = false;
                  _tutorNoEncontrado = false;
                  _tutNombre.clear();
                  _tutEmail.clear();
                  _tutTelefono.clear();
                  _tutDireccion.clear();
                });
              }
            },
          )),
          const SizedBox(width: 12),
          IconButton.filled(
              onPressed: () {
                if (_cedulaValida(_tutCedula))
                  _buscarTutor(_tutCedula.text);
                else
                  NutriSnack.show(context,
                      "La cédula del tutor debe tener exactamente 10 dígitos.",
                      isError: true, ref: ref);
              },
              icon: const Icon(Icons.search),
              style: IconButton.styleFrom(
                  backgroundColor: greenBrand,
                  padding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)))),
        ]),
        if (_buscandoTutor)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator()),
        if (_tutorNoEncontrado)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFEDD5), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.priority_high_rounded,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 12),
                Text("Tutor no registrado. Por favor complete los datos.",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900)),
              ],
            ),
          ),
        if (_tutorExistente)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: greenBrand, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 12),
                Text(
                    "Tutor encontrado. Puede actualizar sus datos si es necesario.",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade900)),
              ],
            ),
          ),
        const SizedBox(height: 24),
        _field(_tutNombre, "Nombre y apellidos*", Icons.person_outline,
            hint: "Ingrese los nombres y apellidos completos"),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
              child: _field(_tutEmail, "Correo electrónico del usuario*",
                  Icons.alternate_email,
                  helper: "Este será su nombre de acceso.",
                  hint: "usuario@ejemplo.com")),
          const SizedBox(width: 20),
          Expanded(
              child: _dropdown("Parentesco*", _parentescos, _tutParentesco,
                  (v) => setState(() => _tutParentesco = v),
                  hint: "Seleccione una opción")),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
              child: _field(
            _tutTelefono,
            "Teléfono móvil*",
            Icons.phone_android_outlined,
            hint: "09XXXXXXXX",
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)
            ],
          )),
          const SizedBox(width: 20),
          Expanded(
              child: _field(
                  _tutDireccion, "Dirección del hogar", Icons.map_outlined,
                  hint: "Av. principal y calle secundaria")),
        ]),
      ],
    );
  }

  Widget _buildFixedPatientFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          _pacCedula,
          "Cédula del paciente*",
          Icons.assignment_ind_outlined,
          hint: "Ingrese los 10 dígitos",
          keyboardType: TextInputType.number,
          onChanged: _onCedulaPacienteChanged,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ],
        ),
        if (_validandoCedulaPaciente || _mensajeCedulaPaciente != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Row(
              children: [
                if (_validandoCedulaPaciente)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.error_outline_rounded,
                      size: 14, color: Colors.red),
                const SizedBox(width: 6),
                Text(
                  _validandoCedulaPaciente
                      ? "Validando cédula..."
                      : _mensajeCedulaPaciente!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        _validandoCedulaPaciente ? Colors.blueGrey : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        _field(
            _pacNombre, "Nombres y apellidos completos*", Icons.person_outline,
            hint: "Ingrese los nombres y apellidos completos"),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
            child: _field(
              _pacFechaNacCtrl,
              "Fecha de nacimiento*",
              Icons.calendar_month_outlined,
              hint: "Seleccione una fecha completa",
              readOnly: true,
              onTap: _pickFechaNac,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
              child: _dropdown(
                  "Sexo biológico*",
                  _sexos,
                  _pacSexo,
                  (v) => setState(() {
                        _pacSexo = v;
                        _calculateOMS();
                      }),
                  hint: "Seleccione una opción")),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
              child:
                  _dropdown("Cantón de residencia", _cantones, _pacCanton, (v) {
            setState(() {
              _pacCanton = v;
              _updateParroquiasFiltradas();
            });
          }, hint: "Seleccione un cantón")),
          const SizedBox(width: 20),
          Expanded(
              child: _dropdown("Parroquia de residencia", _parroquiasFiltradas,
                  _pacParroquia, (v) => setState(() => _pacParroquia = v),
                  hint: "Seleccione una parroquia")),
        ]),
      ],
    );
  }

  Widget _buildFixedDiseaseFields() {
    return _dropdown("Patología/enfermedad base*", _patologias,
        _idPatologiaBase, (v) => setState(() => _idPatologiaBase = v),
        hint: "Seleccione...");
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () {
                ref.read(medicoNavProvider.notifier).setView(MedicoView.list);
              },
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTema.azulPrincipal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: Icon(Icons.arrow_back_ios, size: 16, color: AppTema.azulPrincipal),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              "Registro del paciente",
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF334155)), 
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 52),
          child: Text(
            "Formulario para registrar los datos iniciales de un nuevo paciente, información del tutor, y enfermedad principal.",
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppTema.verdeSalud, 
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  ref.read(medicoNavProvider.notifier).setView(MedicoView.list);
                },
                child: Text("Gestión de Pacientes", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, decoration: TextDecoration.none)) 
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
              ),
              Text("Nuevo Registro", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          )
        ),
      ],
    );
  }


  Widget _buildSendingOverlay() => Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!_showSuccess)
          const CircularProgressIndicator(color: Colors.white, strokeWidth: 8),
        if (_showSuccess)
          const Icon(Icons.check_circle_outline_rounded,
              color: Colors.green, size: 120),
        const SizedBox(height: 32),
        Text(
            widget.fixedOnly
                ? (_showSuccess
                    ? "Datos clínicos actualizados"
                    : "Actualizando datos clínicos...")
                : (_showSuccess ? "Guardado" : "Sincronizando..."),
            style: GoogleFonts.inter(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))
      ])));

  String _soloDigitos(String value) => value.replaceAll(RegExp(r'\D'), '');

  bool _cedulaValida(TextEditingController controller) {
    final limpia = _soloDigitos(controller.text);
    if (controller.text != limpia) controller.text = limpia;
    return limpia.length == 10;
  }

  bool _telefonoMovilValido(TextEditingController controller) {
    final limpia = _soloDigitos(controller.text);
    if (controller.text != limpia) controller.text = limpia;
    return limpia.length == 10 && limpia.startsWith("09");
  }

  void _onCedulaPacienteChanged(String value) {
    final limpia = _soloDigitos(value);
    _debounceCedulaPaciente?.cancel();
    if (limpia.length != 10) {
      setState(() {
        _mensajeCedulaPaciente = null;
        _validandoCedulaPaciente = false;
      });
      return;
    }

    _debounceCedulaPaciente = Timer(
      const Duration(milliseconds: 250),
      () => _verificarCedulaPaciente(limpia),
    );
  }

  Future<void> _verificarCedulaPaciente(String cedula) async {
    setState(() {
      _validandoCedulaPaciente = true;
      _mensajeCedulaPaciente = null;
    });
    try {
      final res = await ref
          .read(repositorioMedicoProvider)
          .verificarPacientePorCedula(cedula);
      if (!mounted) return;
      
      String? errMsg;
      if (res['error_rol'] == 'medico') {
        errMsg = "Esta cédula pertenece a personal del sistema.";
      } else if (res['error_rol'] == 'tutor') {
        errMsg = "Esta cédula ya está registrada como representante.";
      } else {
        final paciente = res['paciente'] is Map
            ? Map<String, dynamic>.from(res['paciente'])
            : null;
        final pacienteId = paciente?['id']?.toString();
        final existeOtro = res['existe'] == true &&
            (_idPacienteEditando == null || pacienteId != _idPacienteEditando);
        if (existeOtro) {
          errMsg = "Este paciente con esa cédula ya existe.";
        }
      }
      
      setState(() {
        _mensajeCedulaPaciente = errMsg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensajeCedulaPaciente = null);
    } finally {
      if (mounted) setState(() => _validandoCedulaPaciente = false);
    }
  }

  bool _validateCurrentStep(int step) {
    if (step == 0) {
      final telefonoOk = _tutorExistente
          ? (_tutTelefono.text.trim().isEmpty ||
              _telefonoMovilValido(_tutTelefono))
          : _telefonoMovilValido(_tutTelefono);
      return _tutNombre.text.trim().isNotEmpty &&
          _cedulaValida(_tutCedula) &&
          _tutParentesco != null &&
          _tutEmail.text.trim().isNotEmpty &&
          telefonoOk;
    }
    if (step == 1) {
      bool validAge = false;
      if (_pacFechaNac != null) {
        final age = DateTime.now().difference(_pacFechaNac!).inDays / 365.25;
        validAge = age >= 3 && age < 18;
      }
      return _pacNombre.text.trim().isNotEmpty &&
          _cedulaValida(_pacCedula) &&
          !_validandoCedulaPaciente &&
          _mensajeCedulaPaciente == null &&
          _pacSexo != null &&
          validAge;
    }
    return _idPatologiaBase != null &&
        _lactosa != null &&
        _restriccionesAlimentariasCat.isNotEmpty;
  }

  bool _validateAlergiasIntolerancias() {
    if (_lactosa == null) {
      NutriSnack.show(
        context,
        "Debe indicar si presenta intolerancia a la lactosa.",
        isError: true,
        ref: ref,
      );
      return false;
    }

    if (_lactosa == true) {
      _restriccionesAlimentarias.add("INTOLERANCIA_LACTOSA");
    } else {
      _restriccionesAlimentarias.remove("INTOLERANCIA_LACTOSA");
    }

    if (_tieneAlergiaSub && _alergiasSub.isEmpty) {
      NutriSnack.show(
        context,
        "Marcó alergias por subgrupo, pero no seleccionó ninguna.",
        isError: true,
        ref: ref,
      );
      return false;
    }

    if (!_tieneAlergiaSub) {
      _alergiasSub.clear();
    }

    if (_tieneAlergiaIng && _selectedIngredientes.isEmpty) {
      NutriSnack.show(
        context,
        "Marcó alergias por ingrediente, pero no seleccionó ninguna.",
        isError: true,
        ref: ref,
      );
      return false;
    }

    if (!_tieneAlergiaIng) {
      _selectedIngredientes.clear();
    }

    return true;
  }

  bool _validateFixedOnly() {
    bool invalidAge = true;
    if (_pacFechaNac != null) {
      final age = DateTime.now().difference(_pacFechaNac!).inDays / 365.25;
      invalidAge = age < 3 || age >= 18;
    }

    if (_tutNombre.text.trim().isEmpty ||
        !_cedulaValida(_tutCedula) ||
        _tutEmail.text.trim().isEmpty ||
        _tutTelefono.text.trim().isEmpty ||
        _tutParentesco == null ||
        _pacNombre.text.trim().isEmpty ||
        !_cedulaValida(_pacCedula) ||
        _validandoCedulaPaciente ||
        _mensajeCedulaPaciente != null ||
        _pacSexo == null ||
        invalidAge ||
        _idPatologiaBase == null) {
      return false;
    }
    return _validateAlergiasIntolerancias();
  }

  Map<String, dynamic> _buildFixedSnapshot() {
    final restricciones = Set<String>.from(_restriccionesAlimentarias);
    if (_lactosa == true) {
      restricciones.add("INTOLERANCIA_LACTOSA");
    } else {
      restricciones.remove("INTOLERANCIA_LACTOSA");
    }
    final alergiasIng = _selectedIngredientes
        .map((e) => (e['id'] as num?)?.toInt())
        .whereType<int>()
        .toList()
      ..sort();
    final alergiasSub = List<int>.from(_alergiasSub)..sort();
    final restriccionesList = restricciones.toList()..sort();

    return {
      "tutCedula": _tutCedula.text.trim(),
      "tutNombre": _tutNombre.text.trim(),
      "tutEmail": _tutEmail.text.trim(),
      "tutTelefono": _tutTelefono.text.trim(),
      "tutParentesco": _tutParentesco,
      "tutDireccion": _tutDireccion.text.trim(),
      "cedula": _pacCedula.text.trim(),
      "nombre": _pacNombre.text.trim(),
      "fecha_nacimiento":
          _pacFechaNac?.toIso8601String().split("T").first ?? "",
      "sexo": _pacSexo,
      "canton": _pacCanton,
      "parroquia": _pacParroquia,
      "patologia": _idPatologiaBase,
      "lactosa": _lactosa,
      "restricciones": restriccionesList,
      "alergias_subgrupos": alergiasSub,
      "alergias_ingredientes": alergiasIng,
    };
  }

  String _nameById(List items, int? id) {
    if (id == null) return "-";
    for (final item in items) {
      if (item is Map && item['id'] == id) {
        return _norm(item['nombre'] ?? item['descripcion'] ?? "-");
      }
    }
    return "-";
  }

  String _yesNo(dynamic value) {
    if (value == true) return "Sí";
    if (value == false) return "No";
    return "-";
  }

  String _dateLabel(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? "-" : _formatFechaCompleta(date);
  }

  String _namesByIds(List items, List ids) {
    final names = ids
        .map((id) => _nameById(items, (id as num?)?.toInt()))
        .where((name) => name.trim().isNotEmpty && name != "-")
        .toList();
    return names.isEmpty ? "Ninguno" : names.join(", ");
  }

  String _restrictionNames(List codes) {
    final names = <String>[];
    for (final rawCode in codes) {
      final code = rawCode.toString();
      final item = _restriccionesAlimentariasCat.cast<Map?>().firstWhere(
            (r) => r != null && (r['codigo'] ?? '').toString() == code,
            orElse: () => null,
          );
      names.add(item == null ? code : _norm(item['nombre']));
    }
    return names.isEmpty ? "Ninguna" : names.join(", ");
  }

  bool _sameFixedValue(dynamic oldValue, dynamic newValue) {
    if (oldValue is List && newValue is List) {
      if (oldValue.length != newValue.length) return false;
      for (var i = 0; i < oldValue.length; i++) {
        if (oldValue[i] != newValue[i]) return false;
      }
      return true;
    }
    return oldValue == newValue;
  }

  List<Map<String, String>> _fixedChanges() {
    final before = _fixedInitialSnapshot;
    final after = _buildFixedSnapshot();
    final changes = <Map<String, String>>[];

    void addText(String key, String field,
        {String Function(dynamic value)? label}) {
      final oldValue = before[key];
      final newValue = after[key];
      if (_sameFixedValue(oldValue, newValue)) return;
      changes.add({
        "field": field,
        "before":
            label == null ? (oldValue?.toString() ?? "-") : label(oldValue),
        "after":
            label == null ? (newValue?.toString() ?? "-") : label(newValue),
      });
    }

    addText("cedula", "Cédula");
    addText("nombre", "Nombre completo");
    addText("fecha_nacimiento", "Fecha de nacimiento",
        label: (value) => _dateLabel(value?.toString() ?? ""));
    addText("sexo", "Sexo biológico",
        label: (value) => _nameById(_sexos, (value as num?)?.toInt()));
    addText("canton", "Cantón",
        label: (value) => _nameById(_cantones, (value as num?)?.toInt()));
    addText("parroquia", "Parroquia",
        label: (value) => _nameById(_parroquiasCat, (value as num?)?.toInt()));
    addText("patologia", "Patología / enfermedad base",
        label: (value) => _nameById(_patologias, (value as num?)?.toInt()));
    addText("lactosa", "Intolerancia a la lactosa", label: _yesNo);
    addText("restricciones", "Restricciones alimentarias",
        label: (value) => _restrictionNames((value as List?) ?? const []));
    addText("alergias_subgrupos", "Alergias a grupos alimentarios",
        label: (value) =>
            _namesByIds(_subgrupos, (value as List?) ?? const []));
    addText("alergias_ingredientes", "Alergias a ingredientes",
        label: (value) =>
            _namesByIds(_ingredientes, (value as List?) ?? const []));

    return changes;
  }

  Future<void> _confirmAndFinishFixedOnly() async {
    if (!_validateFixedOnly()) return;

    final changes = _fixedChanges();
    if (changes.isEmpty) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.8),
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(
                "No se hizo cambios de datos",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop();
        ref.read(medicoNavProvider.notifier).goBackToList();
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Confirmar actualización",
            style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Se actualizarán los siguientes campos:",
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Column(
                    children: changes
                        .map((change) => _changePreviewRow(change))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: greenBrand),
              child: const Text("Sí, actualizar")),
        ],
      ),
    );

    if (confirm == true) {
      await _finishFixedOnly();
    }
  }

  Widget _changePreviewRow(Map<String, String> change) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(change["field"] ?? "",
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTema.azulOscuro)),
        const SizedBox(height: 6),
        Text("Antes: ${change["before"]}",
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700)),
        const SizedBox(height: 3),
        Text("Después: ${change["after"]}",
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700)),
      ]),
    );
  }

  Future<void> _finishFixedOnly() async {
    setState(() {
      _sending = true;
      _showSuccess = false;
    });
    try {
      final validCodes = _restriccionesAlimentariasCat
          .map((e) => (e['codigo'] ?? '').toString())
          .where((c) => c.isNotEmpty)
          .toSet();
      final sanitizedRestricciones =
          _restriccionesAlimentarias.where(validCodes.contains).toSet();
      if (_lactosa == true) {
        sanitizedRestricciones.add("INTOLERANCIA_LACTOSA");
      } else {
        sanitizedRestricciones.remove("INTOLERANCIA_LACTOSA");
      }

      final payload = {
        "tutor": {
          "nombre": _tutNombre.text,
          "cedula": _tutCedula.text,
          "email": _tutEmail.text,
          "id_parentesco": _tutParentesco,
          "telefono": _tutTelefono.text,
          "direccion": _tutDireccion.text,
          "password": null
        },
        "paciente": {
          "id": _idPacienteEditando,
          "nombre_completo": _pacNombre.text,
          "cedula": _pacCedula.text,
          "id_sexo": _pacSexo,
          "id_canton": _pacCanton,
          "id_parroquia": _pacParroquia,
          "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first
        },
        "salud": {
          "id_patologia_base": _idPatologiaBase,
          "observaciones": _clinNotas.text,
          "es_intolerante_lactosa": _lactosa,
          "restricciones_alimentarias": sanitizedRestricciones.toList(),
          "alergias_subgrupos": _alergiasSub,
          "alergias_ingredientes":
              _selectedIngredientes.map((e) => e['id']).toList(),
          "recomendaciones_ingredientes":
              _recomendacionesIng.map((e) => e['id']).toList(),
        }
      };

      await ref
          .read(repositorioMedicoProvider)
          .actualizarExpedienteMaestro(_idPacienteEditando!, payload);

      setState(() {
        _showSuccess = true;
        _fixedInitialSnapshot = _buildFixedSnapshot();
      });
      
      await Future.delayed(const Duration(milliseconds: 1500));
      ref.invalidate(medicalPatientsProvider);
      if (mounted) ref.read(medicoNavProvider.notifier).goBackToList();
    } catch (e) {
      if (mounted) {
        NutriSnack.show(
          context,
          "Error al actualizar: ${_mensajeError(e)}",
          isError: true,
          ref: ref,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _showSuccess = false;
        });
      }
    }
  }

  Future<void> _finish() async {
    setState(() => _sending = true);
    try {
      if (_restriccionesAlimentariasCat.isEmpty) {
        NutriSnack.show(
          context,
          "No se pudo cargar el catálogo de restricciones. Intente recargar antes de guardar.",
          isError: true,
          ref: ref,
        );
        setState(() => _sending = false);
        return;
      }

      if (!_validateAlergiasIntolerancias()) {
        setState(() => _sending = false);
        return;
      }

      final validCodes = _restriccionesAlimentariasCat
          .map((e) => (e['codigo'] ?? '').toString())
          .where((c) => c.isNotEmpty)
          .toSet();
      final sanitizedRestricciones =
          _restriccionesAlimentarias.where(validCodes.contains).toSet();
      if (sanitizedRestricciones.length != _restriccionesAlimentarias.length &&
          mounted) {
        NutriSnack.show(
          context,
          "Se removieron restricciones no validas del catalogo actual.",
          ref: ref,
        );
      }
      final payload = {
        "tutor": {
          "nombre": _tutNombre.text,
          "cedula": _tutCedula.text,
          "email": _tutEmail.text,
          "id_parentesco": _tutParentesco,
          "telefono": _tutTelefono.text,
          "direccion": _tutDireccion.text,
          "password": _idPacienteEditando == null && !_tutorExistente
              ? _generatedPassword
              : null
        },
        "paciente": {
          "id": _idPacienteEditando,
          "nombre_completo": _pacNombre.text,
          "cedula": _pacCedula.text,
          "id_sexo": _pacSexo,
          "id_canton": _pacCanton,
          "id_parroquia": _pacParroquia,
          "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first
        },
        "salud": {
          "id_patologia_base": _idPatologiaBase,
          "peso_kg": _clinPeso.text,
          "talla_cm": _clinTalla.text,
          "articulaciones_inflamadas": _clinArtInflam.text,
          "articulaciones_dolorosas": _clinArtDolor.text,
          "minutos_rigidez": _clinRigidez.text,
          "puntos_dolor": _dolor.toInt(),
          "escala_inflamacion": _inflamacion.toInt(),
          "fatiga": _fatiga.toInt(),
          "en_brote": _brote,
          "estado_enfermedad": _estadoEnfermedad,
          "observaciones": _clinNotas.text,
          "es_intolerante_lactosa": _lactosa,
          "restricciones_alimentarias": sanitizedRestricciones.toList(),
          "alergias_subgrupos": _alergiasSub,
          "alergias_ingredientes":
              _selectedIngredientes.map((e) => e['id']).toList(),
          "recomendaciones_ingredientes":
              _recomendacionesIng.map((e) => e['id']).toList(),
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
      ref.invalidate(medicalPatientsProvider);
      if (mounted) ref.read(medicoNavProvider.notifier).goBackToList();
    } catch (e) {
      if (mounted) {
        NutriSnack.show(
          context,
          "Error al guardar: ${_mensajeError(e)}",
          isError: true,
          ref: ref,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _mensajeError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data["detail"];
        if (detail is String && detail.trim().isNotEmpty) return detail;
        if (detail is Map) {
          final motivo =
              detail["detail"] ?? detail["message"] ?? detail["error"];
          if (motivo is String && motivo.trim().isNotEmpty) return motivo;
        }
      }
      final msg = error.message;
      if (msg != null && msg.trim().isNotEmpty) return msg;
    }
    return error.toString();
  }

  Widget _credItem(String l, String v, IconData i) => Row(children: [
        Icon(i, size: 18, color: greenBrand),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l,
              style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          Text(v,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))
        ])
      ]);

  Step _stepTutor() => Step(
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.editing,
      title: Row(
          children: [
            const Icon(Icons.person_outline, color: AppTema.azulPrincipal, size: 24),
            const SizedBox(width: 12),
            Text(widget.fixedOnly ? "Referencia del tutor" : "Representante legal",
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AppTema.azulPrincipal)),
          ]
        ),
      content: Form(key: _formKeyTutor, child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(height: 4, width: 48, decoration: const BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.horizontal(left: Radius.circular(2)))),
                Expanded(child: Container(height: 4, decoration: const BoxDecoration(color: AppTema.verdeSalud, borderRadius: BorderRadius.horizontal(right: Radius.circular(2))))),
              ],
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _field(
                _tutCedula,
                "Cédula del tutor*",
                Icons.assignment_ind_outlined,
                hint: "Ingrese la cédula del tutor",
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10)
                ],
                onChanged: (v) {
                  final limpia = _soloDigitos(v);
                  if (limpia.length == 10) {
                    _buscarTutor(limpia);
                  } else if (_tutorExistente || _tutorNoEncontrado) {
                    setState(() {
                      _tutorExistente = false;
                      _tutorNoEncontrado = false;
                      _tutNombre.clear();
                      _tutEmail.clear();
                      _tutTelefono.clear();
                      _tutDireccion.clear();
                    });
                  }
                },
              )),
              const SizedBox(width: 12),
              IconButton.filled(
                  onPressed: () {
                    if (_cedulaValida(_tutCedula))
                      _buscarTutor(_tutCedula.text);
                    else
                      NutriSnack.show(context,
                          "La cédula del tutor debe tener exactamente 10 dígitos.",
                          isError: true, ref: ref);
                  },
                  icon: const Icon(Icons.search),
                  style: IconButton.styleFrom(
                      backgroundColor: greenBrand,
                      padding: const EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)))),
            ]),
            if (_buscandoTutor)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator()),
            if (_tutorNoEncontrado)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFFFEDD5), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.priority_high_rounded,
                          color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 12),
                    Text("Tutor no registrado. Por favor complete los datos.",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade900)),
                  ],
                ),
              ),
            if (_tutorExistente)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: greenBrand, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 12),
                    Text(
                        "Tutor encontrado. Puede actualizar sus datos si es necesario.",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade900)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _field(_tutNombre, "Nombre y apellidos*", Icons.person_outline,
                hint: "Ingrese los nombres y apellidos completos"),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _field(_tutEmail, "Correo electrónico del usuario*",
                      Icons.alternate_email,
                      helper: "Este será su nombre de acceso.",
                      hint: "usuario@ejemplo.com")),
              const SizedBox(width: 20),
              Expanded(
                  child: _dropdown("Parentesco*", _parentescos, _tutParentesco,
                      (v) => setState(() => _tutParentesco = v),
                      hint: "Seleccione una opción")),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _field(
                _tutTelefono,
                "Teléfono móvil*",
                Icons.phone_android_outlined,
                hint: "09XXXXXXXX",
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10)
                ],
              )),
              const SizedBox(width: 20),
              Expanded(
                  child: _field(
                      _tutDireccion, "Dirección del hogar", Icons.map_outlined,
                      hint: "Av. principal y calle secundaria")),
            ]),
          ],
        ),
      )));

  Step _stepPaciente() => Step(
      isActive: _currentStep >= (widget.fixedOnly ? 0 : 1),
      state: _currentStep > (widget.fixedOnly ? 0 : 1)
          ? StepState.complete
          : StepState.editing,
      title: Row(
          children: [
            const Icon(Icons.badge_outlined, color: AppTema.azulPrincipal, size: 24),
            const SizedBox(width: 12),
            Text(widget.fixedOnly ? "Referencia del paciente" : "Identidad del paciente",
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AppTema.azulPrincipal)),
          ]
        ),
      content: Form(key: _formKeyPaciente, child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(height: 4, width: 48, decoration: const BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.horizontal(left: Radius.circular(2)))),
                Expanded(child: Container(height: 4, decoration: const BoxDecoration(color: AppTema.verdeSalud, borderRadius: BorderRadius.horizontal(right: Radius.circular(2))))),
              ],
            ),
            const SizedBox(height: 24),
            _field(
              _pacCedula,
              "Cédula del paciente*",
              Icons.assignment_ind_outlined,
              hint: "Ingrese los 10 dígitos",
              keyboardType: TextInputType.number,
              onChanged: _onCedulaPacienteChanged,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10)
              ],
            ),
            if (_validandoCedulaPaciente || _mensajeCedulaPaciente != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Row(
                  children: [
                    if (_validandoCedulaPaciente)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.error_outline_rounded,
                          size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Text(
                      _validandoCedulaPaciente
                          ? "Validando cédula..."
                          : _mensajeCedulaPaciente!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _validandoCedulaPaciente
                            ? Colors.blueGrey
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _field(_pacNombre, "Nombres y apellidos completos*",
                Icons.person_outline,
                hint: "Ingrese los nombres y apellidos completos"),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: _field(
                  _pacFechaNacCtrl,
                  "Fecha de nacimiento*",
                  Icons.calendar_month_outlined,
                  hint: "Seleccione una fecha completa",
                  readOnly: true,
                  onTap: _pickFechaNac,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                  child: _dropdown(
                      "Sexo biológico*",
                      _sexos,
                      _pacSexo,
                      (v) => setState(() {
                            _pacSexo = v;
                            _calculateOMS();
                          }),
                      hint: "Seleccione una opción")),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _dropdown(
                      "Cantón de residencia", _cantones, _pacCanton, (v) {
                setState(() {
                  _pacCanton = v;
                  _updateParroquiasFiltradas();
                });
              }, hint: "Seleccione un cantón")),
              const SizedBox(width: 20),
              Expanded(
                  child: _dropdown(
                      "Parroquia de residencia",
                      _parroquiasFiltradas,
                      _pacParroquia,
                      (v) => setState(() => _pacParroquia = v),
                      hint: "Seleccione una parroquia")),
            ]),
          ],
        ),
      )));

  Step _stepClinico() => Step(
      isActive: _currentStep >= (widget.fixedOnly ? 1 : 2),
      state: StepState.editing,
      title: Text(
          widget.fixedOnly
              ? "Datos clínicos base"
              : "Protocolo de evaluación clínica",
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
      content: Form(key: _formKeyClinico, child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(height: 4, width: 48, decoration: const BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.horizontal(left: Radius.circular(2)))),
                Expanded(child: Container(height: 4, decoration: const BoxDecoration(color: AppTema.verdeSalud, borderRadius: BorderRadius.horizontal(right: Radius.circular(2))))),
              ],
            ),
            const SizedBox(height: 24),
          // ENFERMEDAD PRINCIPAL
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader("Enfermedad y diagnostico", Icons.coronavirus_outlined, isSub: true),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: _dropdown(
                        "Patología/enfermedad base*",
                        _patologias,
                        _idPatologiaBase,
                        (v) => setState(() => _idPatologiaBase = v),
                        hint: "Seleccione...")),
                const SizedBox(width: 24),
                Expanded(
                    child: _dropdown(
                        "Estado de la enfermedad*",
                        _estadosClinicos
                            .asMap()
                            .entries
                            .map((e) => {"id": e.key, "nombre": e.value})
                            .toList(),
                        _estadosClinicos.indexOf(_estadoEnfermedad),
                        (v) => setState(
                            () => _estadoEnfermedad = _estadosClinicos[v!]),
                        hint: "Seleccione...")),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // ACTIVIDAD DE LA ENFERMEDAD
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader(
                  "Actividad de la enfermedad", Icons.analytics_outlined, isSub: true),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: EscalaSelector(
                          titulo: "Dolor",
                          descripcion: "Escala EVA dolor",
                          min: 0,
                          max: 10,
                          value: _dolor.toInt(),
                          icons: const [
                            Icons.sentiment_very_satisfied_rounded,
                            Icons.sentiment_satisfied_rounded,
                            Icons.sentiment_satisfied_rounded,
                            Icons.sentiment_neutral_rounded,
                            Icons.sentiment_neutral_rounded,
                            Icons.sentiment_dissatisfied_rounded,
                            Icons.sentiment_dissatisfied_rounded,
                            Icons.sentiment_very_dissatisfied_rounded,
                            Icons.sentiment_very_dissatisfied_rounded,
                            Icons.sick_rounded,
                            Icons.sick_rounded
                          ],
                          etiquetas: [
                            EscalaEtiqueta("Leve", 3),
                            EscalaEtiqueta("Moderado", 4),
                            EscalaEtiqueta("Severo", 4)
                          ],
                          colorActivo: AppTema.verdeSalud,
                          colorFondoActivo: AppTema.verdeSalud,
                          backgroundColor: const Color(0xFFF8FAFC),
                          showIdentityRow: false,
                          onChanged: (v) =>
                              setState(() => _dolor = v.toDouble()),
                          puntajeLabel: "${_dolor.toInt()}/10",
                          headerIcon: const Text("😣",
                              style: TextStyle(fontSize: 26)))),
                  const SizedBox(width: 24),
                  Expanded(
                      child: _buildEVACard("Inflamación", _inflamacion, 3,
                          (v) => setState(() => _inflamacion = v),
                          icon: Icons.verified_user_outlined,
                          dynamicIcons: const [
                        Icons.health_and_safety_outlined,
                        Icons.shield_outlined,
                        Icons.warning_amber_rounded,
                        Icons.local_hospital_rounded
                      ],
                          labels: [
                        "0 = Sin inflamación",
                        "1 = Leve",
                        "2 = Moderada",
                        "3 = Severa / Activa"
                      ])),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _buildEVACard("Energía", _fatiga, 10,
                          (v) => setState(() => _fatiga = v),
                          icon: Icons.battery_full_rounded,
                          dynamicIcons: const [
                        Icons.battery_0_bar_rounded,
                        Icons.battery_1_bar_rounded,
                        Icons.battery_1_bar_rounded,
                        Icons.battery_2_bar_rounded,
                        Icons.battery_3_bar_rounded,
                        Icons.battery_4_bar_rounded,
                        Icons.battery_5_bar_rounded,
                        Icons.battery_6_bar_rounded,
                        Icons.battery_full_rounded,
                        Icons.battery_full_rounded,
                        Icons.bolt_rounded
                      ],
                          labels: [
                        "0-3 = Agotamiento",
                        "4-7 = Intermedio",
                        "8-10 = Alta energía"
                      ])),
                  const SizedBox(width: 24),
                  Expanded(
                      child: Column(
                    children: [
                      Row(children: [
                        Expanded(
                            child: _buildCounterField("Art. Inflamadas",
                                _clinArtInflam, Icons.track_changes_outlined)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildCounterField("Art. Dolorosas",
                                _clinArtDolor, Icons.back_hand_outlined)),
                      ]),
                      const SizedBox(height: 24),
                      _buildRigidezCard(),
                      const SizedBox(height: 24),
                      _buildBroteToggle(),
                    ],
                  )),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ALERGIAS E INTOLERANCIAS
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader(
                  "Alergias e intolerancias", Icons.warning_amber_rounded, isSub: true),
              const SizedBox(height: 8),
              Text(
                  "Registra restricciones alimentarias y alergias relevantes del paciente.",
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 32),
              _buildAlergiasStepContent(),
            ]),
          ),

          if (!widget.fixedOnly) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader("Identificar condición nutricional",
                        Icons.scale_outlined),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: _field(_clinPeso, "Peso inicial (kg)*",
                              Icons.monitor_weight_outlined,
                              onChanged: (_) => _debouncedOMS())),
                      const SizedBox(width: 20),
                      Expanded(
                          child: _field(_clinTalla, "Talla inicial (cm)*",
                              Icons.height_outlined,
                              onChanged: (_) => _debouncedOMS())),
                    ]),
                    const SizedBox(height: 20),
                    _buildProfessionalPrediagnosis(),
                  ]),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                        "Condiciones temporales", Icons.event_note_rounded),
                    const SizedBox(height: 16),
                    _buildSintomasTemporalesSelector(),
                  ]),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                        "Ingredientes recomendados", Icons.recommend_rounded),
                    const SizedBox(height: 12),
                    Text(
                        "Opcional. El doctor puede recomendar ingredientes con búsqueda inteligente.",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 14),
                    _buildRecomendacionesSelector(),
                  ]),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  _clinNotas, 
                  "Observaciones médicas iniciales",
                  Icons.edit_note_rounded,
                  maxLines: 4
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _field(
                  _proximaCitaCtrl,
                  "Fecha de próxima consulta",
                  Icons.event_note_rounded,
                  readOnly: true,
                  onTap: _pickProximaCita,
                ),
              ),
            ],
          ),
        ]),
      )));

  Widget _buildEVACard(String title, double val, int max, Function(double) onC,
      {required IconData icon,
      required List<String> labels,
      List<IconData>? dynamicIcons}) {
    final int current = val.toInt().clamp(0, max);
    final IconData activeIcon =
        (dynamicIcons != null && dynamicIcons.length > current)
            ? dynamicIcons[current]
            : icon;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTema.verdeSalud.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(activeIcon, color: AppTema.verdeSalud, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTema.azulOscuro)),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTema.verdeSalud.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text("${val.toInt()}/$max",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTema.verdeSalud)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: List.generate(max + 1, (index) {
              final isSel = val.toInt() == index;
              return Expanded(
                child: InkWell(
                  onTap: () => onC(index.toDouble()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSel ? AppTema.verdeSalud : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: isSel
                              ? AppTema.verdeSalud
                              : Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Text("$index",
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSel ? Colors.white : Colors.blueGrey)),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map((l) => Text(l,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterField(
      String label, TextEditingController ctrl, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, size: 18, color: Colors.blueGrey),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero),
                ),
              ),
              IconButton(
                  onPressed: () {
                    int v = int.tryParse(ctrl.text) ?? 0;
                    if (v > 0) ctrl.text = (v - 1).toString();
                  },
                  icon: const Icon(Icons.remove, size: 16)),
              IconButton(
                  onPressed: () {
                    int v = int.tryParse(ctrl.text) ?? 0;
                    ctrl.text = (v + 1).toString();
                  },
                  icon: const Icon(Icons.add, size: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRigidezCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppTema.verdeSalud.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Text("⏱️", style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Minutos de rigidez",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTema.azulOscuro)),
                const SizedBox(height: 4),
                Text("Rigidez matutina registrada en minutos",
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey)),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _clinRigidez,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3)
              ],
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTema.azulOscuro),
              decoration: InputDecoration(
                suffixText: "min",
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroteToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _brote
            ? Colors.red.withOpacity(0.05)
            : AppTema.verdeSalud.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _brote
                ? Colors.red.withOpacity(0.1)
                : AppTema.verdeSalud.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _brote ? Colors.red : AppTema.verdeSalud,
                shape: BoxShape.circle),
            child: Icon(
                _brote ? Icons.warning_amber_rounded : Icons.check_rounded,
                color: Colors.white,
                size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_brote ? "Brote activo detectado" : "Sin brote activo",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _brote
                            ? Colors.red.shade900
                            : Colors.green.shade900)),
                Text("¿Presenta crisis hoy?",
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Switch.adaptive(
              value: _brote,
              activeColor: Colors.red,
              onChanged: (v) => setState(() => _brote = v)),
        ],
      ),
    );
  }

  Widget _buildAlergiasStepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepCircleLabel("1", "¿Presenta intolerancia a la lactosa?*"),
        const SizedBox(height: 16),
        Row(children: [
          _lactoseCard(true, "Sí, restricción activa",
              "El paciente presenta intolerancia a la lactosa."),
          const SizedBox(width: 20),
          _lactoseCard(false, "No detectada",
              "No se ha detectado intolerancia a la lactosa."),
        ]),
        const SizedBox(height: 24),
        _stepCircleLabel("2", "Otras restricciones clínicas"),
        const SizedBox(height: 8),
        Text("Seleccione las condiciones que aplican al paciente.",
            style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.blueGrey,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final sorted = _restriccionesAlimentariasCat
                .where((r) =>
                    (r['codigo'] ?? '').toString() != "INTOLERANCIA_LACTOSA")
                .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
                .toList()
              ..sort((a, b) => _norm(a['nombre'])
                  .toLowerCase()
                  .compareTo(_norm(b['nombre']).toLowerCase()));
            final width = (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: sorted.map<Widget>((r) {
                final String code = r['codigo'];
                final bool isSel = _restriccionesAlimentarias.contains(code);
                return SizedBox(
                    width: width,
                    child: _restrictionChip(_norm(r['nombre']), code, isSel));
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          value: _tieneAlergiaSub,
          onChanged: (v) => setState(() {
            _tieneAlergiaSub = v ?? false;
            if (!_tieneAlergiaSub) {
              _alergiasSub.clear();
              _subgrupoSearchCtrl.clear();
            }
          }),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text("Tiene alergias a grupos alimentarios",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTema.azulOscuro)),
        ),
        if (_tieneAlergiaSub)
          _buildMultiSelector(
            title: "",
            subtitle: "",
            enabled: _tieneAlergiaSub,
            items: _subgrupos.map((s) => Map<String, dynamic>.from(s)).toList(),
            selectedIds: _alergiasSub,
            searchCtrl: _subgrupoSearchCtrl,
            focusNode: _subgrupoFocus,
            blockedIds: _subgruposBloqueados,
            showSearch: false,
            onToggle: (id) {
              setState(() {
                if (_alergiasSub.contains(id)) {
                  _alergiasSub.remove(id);
                } else if (!_subgruposBloqueados.contains(id)) {
                  _alergiasSub.add(id);
                }
              });
            },
          ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _tieneAlergiaIng,
          onChanged: (v) => setState(() {
            _tieneAlergiaIng = v ?? false;
            if (!_tieneAlergiaIng) {
              _selectedIngredientes.clear();
              _ingredienteAlergiaSearchCtrl.clear();
            }
          }),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text("Tiene alergias a ingredientes específicos",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTema.azulOscuro)),
        ),
        if (_tieneAlergiaIng)
          _buildMultiSelector(
            title: "",
            subtitle: "",
            enabled: _tieneAlergiaIng,
            items:
                _ingredientes.map((i) => Map<String, dynamic>.from(i)).toList(),
            selectedIds: _selectedIngredientes
                .map((e) => (e['id'] as num).toInt())
                .toList(),
            searchCtrl: _ingredienteAlergiaSearchCtrl,
            focusNode: _ingredienteAlergiaFocus,
            blockedIds: _subgruposBloqueados,
            blockedIngredientIds: _ingredientesBloqueados,
            isIngredientes: true,
            onMarkAll: (matches) {
              setState(() {
                for (final item in matches) {
                  final id = (item['id'] as num?)?.toInt();
                  if (id == null) continue;
                  if (_ingredientesBloqueados.contains(id)) continue;
                  if (_selectedIngredientes.any((e) => e['id'] == id)) continue;
                  _selectedIngredientes.add(Map<String, dynamic>.from(item));
                }
              });
            },
            onToggle: (id) {
              setState(() {
                final idx =
                    _selectedIngredientes.indexWhere((e) => e['id'] == id);
                if (idx >= 0) {
                  _selectedIngredientes.removeAt(idx);
                } else {
                  final item =
                      _ingredientes.cast<Map<String, dynamic>?>().firstWhere(
                            (e) =>
                                e != null && (e['id'] as num?)?.toInt() == id,
                            orElse: () => null,
                          );
                  if (item != null) {
                    final idSub =
                        (item['id_subgrupo_alimentario'] as num?)?.toInt() ??
                            (item['id_subgrupo'] as num?)?.toInt();
                    if (_ingredientesBloqueados.contains(id)) return;
                    if (idSub != null && _subgruposBloqueados.contains(idSub))
                      return;
                    _selectedIngredientes.add(Map<String, dynamic>.from(item));
                  }
                }
              });
            },
          ),
        if (_selectedIngredientes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedIngredientes.map((ing) {
              final id = (ing['id'] as num?)?.toInt();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (ing['nombre'] ?? "").toString(),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade900),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() =>
                          _selectedIngredientes.removeWhere(
                              (e) => (e['id'] as num?)?.toInt() == id)),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: Colors.red.shade800),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Set<int> get _subgruposBloqueados {
    final bloqueados = <int>{};
    if (_lactosa == true) bloqueados.addAll(_subgruposLactosa);
    for (final r in _restriccionesAlimentariasCat) {
      final code = (r['codigo'] ?? "").toString();
      if (!_restriccionesAlimentarias.contains(code)) continue;
      final raw = r['ids_subgrupos'] ??
          r['subgrupos_ids'] ??
          r['id_subgrupos'] ??
          r['subgrupos'];
      if (raw is List) {
        for (final v in raw) {
          final id =
              (v is Map) ? (v['id'] as num?)?.toInt() : (v as num?)?.toInt();
          if (id != null) bloqueados.add(id);
        }
      } else if (raw is String && raw.trim().isNotEmpty) {
        for (final part in raw.split(',')) {
          final id = int.tryParse(part.trim());
          if (id != null) bloqueados.add(id);
        }
      }
    }
    return bloqueados;
  }

  Set<int> get _ingredientesBloqueados {
    final bloqueados = <int>{};
    for (final r in _restriccionesAlimentariasCat) {
      final code = (r['codigo'] ?? "").toString();
      if (!_restriccionesAlimentarias.contains(code)) continue;
      final raw = r['ids_ingredientes'] ??
          r['ingredientes_ids'] ??
          r['id_ingredientes'] ??
          r['ingredientes'];
      if (raw is List) {
        for (final v in raw) {
          final id =
              (v is Map) ? (v['id'] as num?)?.toInt() : (v as num?)?.toInt();
          if (id != null) bloqueados.add(id);
        }
      } else if (raw is String && raw.trim().isNotEmpty) {
        for (final part in raw.split(',')) {
          final id = int.tryParse(part.trim());
          if (id != null) bloqueados.add(id);
        }
      }
    }
    return bloqueados;
  }

  Widget _buildMultiSelector({
    required String title,
    required String subtitle,
    required bool enabled,
    required List<Map<String, dynamic>> items,
    required List<int> selectedIds,
    required TextEditingController searchCtrl,
    required FocusNode focusNode,
    required Set<int> blockedIds,
    Set<int> blockedIngredientIds = const {},
    required Function(int id) onToggle,
    bool isIngredientes = false,
    bool showSearch = true,
    void Function(List<Map<String, dynamic>> matches)? onMarkAll,
  }) {
    final q = searchCtrl.text.toLowerCase().trim();
    final filtered = items.where((e) {
      final id = (e['id'] as num?)?.toInt() ?? -1;
      final idSub = (e['id_subgrupo_alimentario'] as num?)?.toInt() ??
          (e['id_subgrupo'] as num?)?.toInt();
      if (!isIngredientes && blockedIds.contains(id)) return true;
      if (isIngredientes && blockedIngredientIds.contains(id)) return false;
      if (isIngredientes && idSub != null && blockedIds.contains(idSub))
        return false;
      if (!showSearch || q.isEmpty) return true;
      final name = _norm(e['nombre']).toLowerCase();
      final syns = (e['sinonimos'] as List? ?? [])
          .map((s) => s.toString().toLowerCase())
          .toList();
      return name.contains(q) || syns.any((s) => s.contains(q));
    }).toList();

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.trim().isNotEmpty) ...[
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTema.azulOscuro)),
                const SizedBox(height: 4),
              ],
              if (subtitle.trim().isNotEmpty) ...[
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey)),
                const SizedBox(height: 10),
              ],
              if (showSearch) ...[
                TextField(
                  controller: searchCtrl,
                  focusNode: focusNode,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: q.isEmpty
                        ? (isIngredientes
                            ? "Buscar ingrediente..."
                            : "Filtrar subgrupo...")
                        : "Filtrando: $q",
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: q.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              searchCtrl.clear();
                              setState(() {});
                            })
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              if (showSearch &&
                  isIngredientes &&
                  onMarkAll != null &&
                  q.isNotEmpty &&
                  filtered.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onMarkAll(filtered),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: Text("Marcar ${filtered.length}",
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (!isIngredientes && !showSearch)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: filtered.map((item) {
                    final id = (item['id'] as num?)?.toInt() ?? -1;
                    final bool locked = blockedIds.contains(id);
                    final bool isSel = selectedIds.contains(id);
                    final String name = _norm(item['nombre']);
                    return InkWell(
                      onTap: locked ? null : () => onToggle(id),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: locked
                              ? Colors.grey.shade100
                              : isSel
                                  ? AppTema.verdeSalud.withOpacity(0.12)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: locked
                                ? Colors.grey.shade300
                                : isSel
                                    ? AppTema.verdeSalud
                                    : Colors.grey.shade300,
                            width: isSel ? 1.8 : 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_emojiSubgrupo(item),
                                style: TextStyle(
                                    fontSize: 16,
                                    color: locked ? Colors.grey : null)),
                            const SizedBox(width: 8),
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: locked
                                    ? Colors.grey
                                    : (isSel
                                        ? AppTema.verdeSalud
                                        : AppTema.azulOscuro),
                              ),
                            ),
                            if (isSel) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.check_circle,
                                  size: 14, color: AppTema.verdeSalud),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 210),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length > 60 ? 60 : filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final id = (item['id'] as num?)?.toInt() ?? -1;
                      final idSub =
                          (item['id_subgrupo_alimentario'] as num?)?.toInt() ??
                              (item['id_subgrupo'] as num?)?.toInt();
                      final locked = isIngredientes &&
                          (blockedIngredientIds.contains(id) ||
                              (idSub != null && blockedIds.contains(idSub)));
                      final isSel = selectedIds.contains(id);
                      return ListTile(
                        dense: true,
                        enabled: !locked,
                        title: Text(
                          _norm(item['nombre']),
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight:
                                  isSel ? FontWeight.w700 : FontWeight.w500,
                              color: locked ? Colors.grey : AppTema.azulOscuro),
                        ),
                        subtitle: locked
                            ? Text("Bloqueado por intolerancia/restricción",
                                style: GoogleFonts.inter(
                                    fontSize: 9, color: Colors.grey))
                            : null,
                        trailing: isSel
                            ? const Icon(Icons.check_circle,
                                color: Colors.green, size: 18)
                            : Icon(
                                locked ? Icons.block : Icons.add_circle_outline,
                                size: 18,
                                color: locked ? Colors.grey : Colors.blueGrey),
                        onTap: locked ? null : () => onToggle(id),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _emojiSubgrupo(Map<String, dynamic> item) {
    final rawEmoji = item['emoji']?.toString().trim();
    if (rawEmoji != null && rawEmoji.isNotEmpty) return rawEmoji;

    final id = (item['id'] as num?)?.toInt() ?? -1;
    switch (id) {
      case 13:
        return "🥬";
      case 17:
        return "🍎";
      case 25:
        return "🍗";
      case 33:
        return "🐟";
      case 34:
        return "🐠";
      case 35:
        return "🐟";
      case 37:
        return "🧂";
      case 49:
        return "🥤";
      case 53:
        return "🧃";
      case 98:
        return "🥛";
      case 100:
        return "🥣";
      case 101:
        return "🧈";
      case 104:
        return "🥛";
      case 105:
        return "🥛";
      case 108:
        return "🧀";
      case 109:
        return "🥓";
      case 110:
        return "🌭";
      default:
        return "🍽️";
    }
  }

  void _autoBloquearDerivados(String nombre) {
    final n = nombre.toLowerCase().trim();
    if (n.length < 3) return;
    final stopWords = {
      'de',
      'con',
      'en',
      'el',
      'la',
      'los',
      'las',
      'un',
      'una',
      'para',
      'sin',
      'y',
      'del'
    };
    final words = n
        .split(' ')
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();
    if (words.isEmpty && n.isNotEmpty) words.add(n);
    for (final raw in _ingredientes) {
      final i = Map<String, dynamic>.from(raw);
      final iname = (i['nombre'] ?? "").toString().toLowerCase();
      if (iname == n) continue;
      final syns = (i['sinonimos'] as List? ?? [])
          .map((s) => s.toString().toLowerCase())
          .toList();
      bool matches = words.any((w) => iname.contains(w));
      if (!matches) {
        matches = syns.any((s) => words.any((w) => s.contains(w)));
      }
      if (!matches) continue;
      final id = (i['id'] as num?)?.toInt();
      if (id == null) continue;
      if (_selectedIngredientes.any((x) => x['id'] == id)) continue;
      final idSub = (i['id_subgrupo_alimentario'] as num?)?.toInt() ??
          (i['id_subgrupo'] as num?)?.toInt();
      if (idSub != null && _subgruposBloqueados.contains(idSub)) continue;
      _selectedIngredientes.add(i);
    }
  }

  Widget _stepCircleLabel(String num, String text) => Row(children: [
        Container(
            width: 24,
            height: 24,
            decoration:
                const BoxDecoration(color: greenBrand, shape: BoxShape.circle),
            child: Center(
                child: Text(num,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)))),
        const SizedBox(width: 12),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTema.azulOscuro)),
      ]);

  Widget _lactoseCard(bool val, String title, String desc) {
    final bool sel = _lactosa == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _lactosa = val;
          if (val)
            _restriccionesAlimentarias.add("INTOLERANCIA_LACTOSA");
          else
            _restriccionesAlimentarias.remove("INTOLERANCIA_LACTOSA");
        }),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sel
                ? (val ? Colors.green.shade50 : Colors.white)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: sel ? greenBrand : Colors.grey.shade200,
                width: sel ? 2 : 1),
            boxShadow: [
              if (sel)
                BoxShadow(
                    color: greenBrand.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Icon(
                  sel
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: sel ? greenBrand : Colors.grey.shade400,
                  size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: sel ? greenBrand : AppTema.azulOscuro)),
                    const SizedBox(height: 4),
                    Text(desc,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _restrictionChip(String name, String code, bool isSel) {
    IconData icon = Icons.restaurant_outlined;
    if (code.contains("GLUTEN"))
      icon = Icons.grain_outlined;
    else if (code.contains("FRUCTOSA"))
      icon = Icons.apple_outlined;
    else if (code.contains("HISTAMINA"))
      icon = Icons.science_outlined;
    else if (code.contains("HUEVO"))
      icon = Icons.egg_outlined;
    else if (code.contains("SOYA"))
      icon = Icons.spa_outlined;
    else if (code.contains("FRUTOS"))
      icon = Icons.bakery_dining_outlined;
    else if (code.contains("PESCADO"))
      icon = Icons.set_meal_outlined;
    else if (code.contains("DIABETES"))
      icon = Icons.monitor_heart_outlined;
    else if (code.contains("VEGETARIANA"))
      icon = Icons.eco_outlined;
    else if (code.contains("SULFITOS"))
      icon = Icons.biotech_outlined;
    else if (code.contains("SORBITOL")) icon = Icons.icecream_outlined;

    return InkWell(
      onTap: () => setState(() => isSel
          ? _restriccionesAlimentarias.remove(code)
          : _restriccionesAlimentarias.add(code)),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSel ? AppTema.verdeSalud.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSel ? AppTema.verdeSalud : Colors.grey.shade200,
              width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: isSel ? AppTema.verdeSalud : Colors.blueGrey),
            const SizedBox(width: 10),
            Text(name,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSel ? AppTema.verdeSalud : Colors.blueGrey)),
            if (isSel) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 14, color: AppTema.verdeSalud),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSintomasTemporalesSelector() {
    if (_condicionesTemporalesCat.isEmpty) return const SizedBox.shrink();
    final ordenadas = [..._condicionesTemporalesCat]..sort((a, b) =>
        (a['nombre'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['nombre'] ?? '').toString().toLowerCase()));
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: ordenadas.map<Widget>((c) {
            final id = c['id'] as int;
            final index = _condicionesTemp.indexWhere((s) => s['id'] == id);
            final sel = index != -1;
            final duracionSugerida = (c['duracion_dias_sugerida'] ??
                c['dias_duracion_estandar'] ??
                7) as int;
            return Container(
              width: (constraints.maxWidth - 40) / 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: sel
                        ? greenBrand.withOpacity(0.3)
                        : const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                key: Key("temp_patient_$id"),
                initiallyExpanded: sel,
                shape: const Border(),
                leading: Checkbox(
                  activeColor: greenBrand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  value: sel,
                  onChanged: (v) async {
                    if (v == true) {
                      final ini = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (ini != null) {
                        setState(() => _condicionesTemp.add({
                              "id": id,
                              "nombre": c['nombre'],
                              "fecha_inicio":
                                  ini.toIso8601String().split('T')[0],
                              "fecha_fin": ini
                                  .add(Duration(days: duracionSugerida))
                                  .toIso8601String()
                                  .split('T')[0],
                            }));
                      }
                    } else {
                      setState(() => _condicionesTemp.removeAt(index));
                    }
                  },
                ),
                title: Text(
                  c['nombre']?.toString() ?? "Condición",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                    color: sel ? greenBrand : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  sel
                      ? "Activa por $duracionSugerida días"
                      : "Duración: $duracionSugerida días",
                  style: GoogleFonts.inter(
                      fontSize: 9, color: const Color(0xFF64748B)),
                ),
                children: sel
                    ? [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child:
                              _buildTemporalDatesRow(index, duracionSugerida),
                        )
                      ]
                    : [],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTemporalDatesRow(int index, int duracionSugerida) {
    final inicio = _condicionesTemp[index]['fecha_inicio']?.toString() ??
        DateTime.now().toIso8601String().split('T')[0];
    final fin = _condicionesTemp[index]['fecha_fin']?.toString() ??
        DateTime.now()
            .add(Duration(days: duracionSugerida))
            .toIso8601String()
            .split('T')[0];
    final finDate = DateTime.tryParse(fin) ?? DateTime.now();
    final restantes = finDate.difference(DateTime.now()).inDays;
    final diasRestantes = restantes < 0 ? 0 : restantes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text("Quedan $diasRestantes días",
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569))),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _datePickerSmall(
                "Inicio",
                inicio,
                (d) => setState(() {
                  _condicionesTemp[index]['fecha_inicio'] =
                      d.toIso8601String().split('T')[0];
                  _condicionesTemp[index]['fecha_fin'] = d
                      .add(Duration(days: duracionSugerida))
                      .toIso8601String()
                      .split('T')[0];
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _dateStaticSmall("Fin", fin)),
          ],
        ),
      ],
    );
  }

  Widget _datePickerSmall(String l, String v, Function(DateTime) onP) =>
      InkWell(
        onTap: () async {
          final d0 = DateTime.tryParse(v) ?? DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: d0,
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (d != null) onP(d);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "$l: ${DateFormat('dd/MM/yyyy', 'es').format(DateTime.tryParse(v) ?? DateTime.now())}",
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155)),
                ),
              ),
              const Icon(Icons.expand_more_rounded,
                  size: 18, color: Color(0xFF64748B)),
            ],
          ),
        ),
      );

  Widget _dateStaticSmall(String l, String v) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available_rounded,
                size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "$l: ${DateFormat('dd/MM/yyyy', 'es').format(DateTime.tryParse(v) ?? DateTime.now())}",
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      );

  void _autoRecomendarDerivados(String nombreBase) {
    final base = nombreBase.toLowerCase().trim();
    if (base.isEmpty) return;
    final derivados = _ingredientes.where((e) {
      final n = (e['nombre'] ?? '').toString().toLowerCase();
      return n.contains(base) && n != base;
    });
    for (final d in derivados) {
      if (!_recomendacionesIng.any((x) => x['id'] == d['id'])) {
        setState(() => _recomendacionesIng.add(Map<String, dynamic>.from(d)));
      }
    }
  }

  Widget _buildRecomendacionesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMultiSelector(
            title: "Recomendador de ingredientes (Opcional)",
            subtitle: "Ingresa algún ingrediente, nosotros te recomendaremos el más adecuado según el paciente.",
            enabled: true,
            items: _ingredientes.map((i) => Map<String, dynamic>.from(i)).toList(),
            selectedIds: _recomendacionesIng.map((e) => (e['id'] as num).toInt()).toList(),
            searchCtrl: _ingRecomSearchCtrl,
            focusNode: _ingRecomFocus,
            blockedIds: {},
            isIngredientes: true,
            onToggle: (id) {
              setState(() {
                final idx = _recomendacionesIng.indexWhere((e) => e['id'] == id);
                if (idx >= 0) {
                  _recomendacionesIng.removeAt(idx);
                } else {
                  final item = _ingredientes.cast<Map<String, dynamic>?>().firstWhere(
                        (e) => e != null && e['id'] == id,
                        orElse: () => null,
                      );
                  if (item != null) {
                    _recomendacionesIng.add(Map<String, dynamic>.from(item));
                    _autoRecomendarDerivados(item['nombre'] ?? "");
                  }
                }
              });
            },
        ),
        if (_recomendacionesIng.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recomendacionesIng
                .map((e) => Chip(
                      label: Text(
                        e['nombre'] ?? "",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700),
                      ),
                      onDeleted: () =>
                          setState(() => _recomendacionesIng.remove(e)),
                      backgroundColor: Colors.green.shade50,
                      deleteIconColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ))
                .toList(),
          ),
        ]
      ],
    );
  }

  Widget _buildProfessionalPrediagnosis() => Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: _omsColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _omsColor.withOpacity(0.2), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.analytics_rounded, color: _omsColor, size: 22),
            const SizedBox(width: 12),
            Text("Diagnóstico nutricional OMS",
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF475569)))
          ]),
          if (_calculandoOMS)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: greenBrand))
          else
            IconButton(
                onPressed: _calculateOMS,
                icon: const Icon(Icons.refresh_rounded,
                    size: 20, color: Colors.blueGrey))
        ]),
        if (_omsError != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_omsError!,
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        Text(
            "${_omsStatusPeso.toUpperCase()} / ${_omsStatusTalla.toUpperCase()}",
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A))),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _metricPill(
                  "Peso ideal",
                  _pesoMediana > 0
                      ? "${_pesoMediana.toStringAsFixed(1)} kg"
                      : "-"),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricPill(
                  "Talla ideal",
                  _tallaMediana > 0
                      ? "${_tallaMediana.toStringAsFixed(1)} cm"
                      : "-"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildObjetivosOmsRow(),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _omsColor.withOpacity(0.2)),
          ),
          child: _buildClinicalSummaryBullets(),
        ),
      ]));

  Widget _buildObjetivosOmsRow() {
    final pesoAbs = _gananciaPeso.abs();
    final pesoLabel = _gananciaPeso > 0.1
        ? "Peso a subir"
        : (_gananciaPeso < -0.1 ? "Peso a bajar" : "Peso");
    final pesoValue =
        pesoAbs > 0.1 ? "${pesoAbs.toStringAsFixed(1)} kg" : "Mantener";
    final mostrarTalla = _gananciaTalla > 0.1;

    return Row(
      children: [
        Expanded(child: _metricPill(pesoLabel, pesoValue)),
        if (mostrarTalla) ...[
          const SizedBox(width: 10),
          Expanded(
              child: _metricPill("Talla por crecer",
                  "${_gananciaTalla.abs().toStringAsFixed(1)} cm")),
        ],
      ],
    );
  }

  Widget _buildClinicalSummaryBullets() {
    final text = _buildClinicalSummaryText();
    final parts = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts
          .map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("•",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: _omsColor)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(line,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                                height: 1.35))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  String _buildClinicalSummaryText() {
    final stPeso = _omsStatusPeso.toLowerCase();
    final stTalla = _omsStatusTalla.toLowerCase();
    String pesoTxt;
    String tallaTxt;
    final deltaPeso = _gananciaPeso.abs().toStringAsFixed(1);
    final deltaTalla = _gananciaTalla.abs().toStringAsFixed(1);

    if (stPeso.contains('sobrepeso') ||
        stPeso.contains('obesidad') ||
        stPeso.contains('alto') ||
        _gananciaPeso < -0.1) {
      pesoTxt = "Se recomienda bajar aproximadamente $deltaPeso kg.";
    } else if (_gananciaPeso > 0.1 ||
        stPeso.contains('bajo') ||
        stPeso.contains('delgadez') ||
        stPeso.contains('desnut')) {
      pesoTxt = "Se recomienda subir aproximadamente $deltaPeso kg.";
    } else {
      pesoTxt = "El peso está dentro de lo esperado para su edad.";
    }

    if (_gananciaTalla > 0.1 ||
        stTalla.contains('baja') ||
        stTalla.contains('retraso')) {
      tallaTxt =
          "Debe crecer aproximadamente $deltaTalla cm para alcanzar la talla esperada.";
    } else if (stTalla.contains('alta') || stTalla.contains('elevada')) {
      tallaTxt = "La talla está por encima de lo esperado para su edad.";
    } else {
      tallaTxt = "La talla está dentro de lo esperado para su edad.";
    }

    final extra =
        _resumenClinico.trim().isNotEmpty ? " ${_resumenClinico.trim()}" : "";
    return "$pesoTxt $tallaTxt$extra";
  }

  Widget _metricPill(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A))),
          ],
        ),
      );

  Future<void> _buscarTutor(String c) async {
    final cedula = _soloDigitos(c);
    if (cedula.length != 10) return;
    if (_tutCedula.text != cedula) _tutCedula.text = cedula;
    setState(() {
      _buscandoTutor = true;
      _tutorNoEncontrado = false;
      _tutorExistente = false;
    });
    try {
      final res = await ref
          .read(repositorioMedicoProvider)
          .buscarTutorPorCedula(cedula);
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
        } else {
          setState(() {
            _tutorNoEncontrado = true;
            _tutNombre.clear();
            _tutEmail.clear();
            _tutTelefono.clear();
            _tutDireccion.clear();
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _buscandoTutor = false);
    }
  }

  Future<void> _pickFechaNac() async {
    final d = await showCustomDatePicker(
      context,
      initialDate: _pacFechaNac,
      colorActivo: AppTema.azulPrincipal,
      colorTexto: AppTema.azulOscuro,
    );
    if (d != null) {
      setState(() {
        _pacFechaNac = d;
        _pacFechaNacCtrl.text = _formatFechaCompleta(d);
      });
      _calculateOMS();
    }
  }

  String _formatFechaCompleta(DateTime d) {
    final raw = DateFormat("EEEE, d 'de' MMMM 'de' y", 'es').format(d);
    return raw.isEmpty ? "" : "${raw[0].toUpperCase()}${raw.substring(1)}";
  }

  String _norm(dynamic value) {
    final s = (value ?? "").toString();
    return s
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã­', 'í')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ãº', 'ú')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã', 'Á')
        .replaceAll('Ã‰', 'É')
        .replaceAll('Ã', 'Í')
        .replaceAll('Ã“', 'Ó')
        .replaceAll('Ãš', 'Ú')
        .replaceAll('Ã‘', 'Ñ')
        .replaceAll('Â°', '°')
        .replaceAll('Â¿', '¿')
        .replaceAll('Â¡', '¡')
        .replaceAll('Celequía', 'Celiaquía')
        .replaceAll('Celequia', 'Celiaquía')
        .replaceAll('Celiquia', 'Celiaquía')
        .replaceAll('Celiaquia', 'Celiaquía')
        .replaceAll('Celequ?a', 'Celiaquía')
        .replaceAll('Celiqu?a', 'Celiaquía')
        .replaceAll('Celiaqu?a', 'Celiaquía');
  }

  String _sinAcentos(String value) => value
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U');

  Widget _field(
    TextEditingController c,
    String l,
    IconData i, {
    int maxLines = 1,
    Function(String)? onChanged,
    bool enabled = true,
    String? helper,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTema.azulPrincipal)),
          const SizedBox(height: 8),
          TextFormField(
              controller: c,
              readOnly: readOnly,
              onTap: onTap,
              validator: validator ?? (v) {
                if (c == _pacFechaNacCtrl) {
                  if (_pacFechaNac == null) return "Campo requerido";
                  final age = DateTime.now().difference(_pacFechaNac!).inDays / 365.25;
                  if (age < 3 || age >= 18) return "La edad debe ser mayor a 3 y menor a 18 años";
                  return null;
                }
                if (c == _tutCedula) {
                  if (v == null || v.trim().isEmpty) return "Campo requerido";
                  if (v.trim().length != 10) return "Debe tener 10 dígitos";
                  if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) return "Solo números";
                }
                if (c == _pacCedula) {
                  if (v == null || v.trim().isEmpty) {
                    if (l.contains("*")) return "Campo requerido";
                  } else {
                    if (v.trim().length != 10) return "Debe tener 10 dígitos";
                    if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) return "Solo números";
                  }
                }
                if (c == _tutTelefono) {
                  if (v != null && v.trim().isNotEmpty) {
                    if (v.trim().length != 10) return "Debe tener 10 dígitos";
                    if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) return "Solo números";
                  }
                }
                if (c == _tutEmail) {
                  if (v != null && v.trim().isNotEmpty) {
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return "Correo electrónico inválido";
                    }
                  }
                }
                if (l.contains("*") && (v == null || v.trim().isEmpty)) return "Campo requerido";
                return null;
              },
              maxLines: maxLines,
              enabled: enabled,
              onChanged: onChanged,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B)),
              decoration: InputDecoration(
                  prefixIcon: Icon(i, size: 20, color: const Color(0xFF64748B)),
                  helperText: helper,
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500)))
        ],
      );
}

  Widget _dropdown(String l, List items, int? val, Function(int?) onC,
          {String? hint}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTema.azulPrincipal)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
              value: val == -1 ? null : val,
              validator: (v) {
                if (l.contains("*") && v == null) return "Campo requerido";
                return null;
              },
              isExpanded: true,
              hint: hint != null
                  ? Text(hint,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500))
                  : null,
              items: items
                  .map((e) => DropdownMenuItem<int>(
                      value: e['id'],
                      child: Text(_norm(e['nombre'] ?? e['descripcion'] ?? ""),
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B)))))
                  .toList(),
              onChanged: onC,
              decoration: const InputDecoration())
        ],
      );
}

  Widget _buildControls(ControlsDetails d) => Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Row(children: [
        Expanded(
            child: FilledButton(
                onPressed: d.onStepContinue,
                style: FilledButton.styleFrom(
                    backgroundColor: AppTema.azulPrincipal,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_currentStep < (widget.fixedOnly ? 1 : 2)) ...[
                      const Icon(Icons.chevron_right_rounded, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                        _currentStep == (widget.fixedOnly ? 1 : 2)
                            ? (_idPacienteEditando == null
                                ? "Registrar paciente"
                                : widget.fixedOnly
                                    ? "Actualizar datos clínicos"
                                    : "Guardar cambios")
                            : "Continuar",
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ))),
        if (_currentStep > 0) ...[
          const SizedBox(width: 20),
          Expanded(
              child: OutlinedButton(
                  onPressed: d.onStepCancel,
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTema.azulPrincipal, width: 2),
                      foregroundColor: greenBrand,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: const Text("Regresar",
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800))))
        ]
      ]));

  Widget _sectionHeader(String t, IconData i, {bool isSub = false}) => Row(children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTema.azulPrincipal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(i, size: 20, color: AppTema.azulPrincipal)),
        const SizedBox(width: 18),
        Text(t,
            style: GoogleFonts.inter(
                fontWeight: isSub ? FontWeight.w800 : FontWeight.w900,
                fontSize: isSub ? 11 : 13,
                color: isSub ? Colors.blueGrey : const Color(0xFF0F172A),
                letterSpacing: 0.8))
      ]);
}
