import "dart:async";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
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

  // Marca: Verde Corporativo
  static const Color greenBrand = Color(0xFF2E7D32);

  // Tutor
  final _tutNombre = TextEditingController();
  final _tutCedula = TextEditingController();
  final _tutEmail = TextEditingController();
  final _tutTelefono = TextEditingController();
  final _tutDireccion = TextEditingController();
  final _tutUsuario = TextEditingController();
  final _tutPassword = TextEditingController();
  int? _tutParentesco;
  bool _tutorExistente = false;
  bool _tutorNoEncontrado = false;
  bool _buscandoTutor = false;

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
  bool? _lactosa; // null = no seleccionado, true = SI, false = NO
  DateTime _proximaCita = DateTime.now().add(const Duration(days: 30));
  
  bool _tieneAlergiaSub = false;
  bool _tieneAlergiaIng = false;
  List<int> _alergiasSub = [];
  List<Map<String, dynamic>> _selectedIngredientes = [];
  final List<Map<String, dynamic>> _condicionesTemp = [];

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

  final Set<int> _idsLacteos = {98, 99, 100, 101, 102, 104, 105, 106, 107, 108, 111, 114, 117, 119, 122, 123, 124};

  // Pre-diagnóstico Realtime
  String _omsStatusPeso = "PENDIENTE";
  String _omsStatusTalla = "PENDIENTE";
  Color _omsColor = Colors.grey;
  double _pesoMediana = 0;
  double _tallaMediana = 0;

  @override
  void initState() {
    super.initState();
    _tutCedula.addListener(_onCedulaTutorChanged);
    _initData();
  }

  Future<void> _initData() async {
    await _loadCatalogos();
    if (widget.initialData != null && mounted) {
      _setupEdit(widget.initialData!);
    }
  }

  @override
  void dispose() {
    _tutCedula.removeListener(_onCedulaTutorChanged);
    _debounceOMS?.cancel();
    super.dispose();
  }

  void _onCedulaTutorChanged() {
    if (_tutCedula.text.length == 10 && !_loading && !_buscandoTutor && widget.initialData == null) {
      _buscarTutor(_tutCedula.text);
    }
  }

  Future<void> _buscarTutor(String cedula) async {
    if (cedula.length < 10) return;
    setState(() {
      _buscandoTutor = true;
      _tutorNoEncontrado = false;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("usuarios/tutor-by-cedula/$cedula");
      if (res.data != null && res.data['existe'] == true) {
        setState(() {
          _tutNombre.text = res.data['nombre_completo'] ?? "";
          _tutEmail.text = res.data['email'] ?? "";
          _tutTelefono.text = res.data['telefono'] ?? "";
          _tutDireccion.text = res.data['direccion'] ?? "";
          _tutParentesco = res.data['id_parentesco'];
          _tutorExistente = true;
          _buscandoTutor = false;
        });
        if (mounted) NutriSnack.show(context, "✅ Tutor encontrado y vinculado", ref: ref);
      } else {
        setState(() {
          _buscandoTutor = false;
          _tutorNoEncontrado = true;
          _tutorExistente = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _buscandoTutor = false;
        _tutorNoEncontrado = true;
      });
    }
  }

  Future<void> _loadCatalogos() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final rP = await dio.get("crud/catalog?schema=usuarios&table=parentesco");
      final rS = await dio.get("crud/catalog?schema=usuarios&table=catalogo_sexo");
      final rPa = await dio.get("crud/catalog?schema=heuristico&table=condicion");
      final rSg = await dio.get("nutricion/subgrupos");
      final rIn = await dio.get("nutricion/ingredientes");
      final rCt = await dio.get("crud/catalog?schema=heuristico&table=condicion");
      final rCan = await dio.get("crud/catalog?schema=usuarios&table=canton");
      final rPar = await dio.get("crud/catalog?schema=usuarios&table=parroquia");
      
      setState(() {
        _parentescos = rP.data;
        _sexos = rS.data;
        _patologias = (rPa.data as List).where((e) => e['id_tipo_condicion'] == 1).toList();
        _subgrupos = rSg.data;
        _ingredientes = rIn.data;
        _condicionesTemporalesCat = (rCt.data as List).where((e) => e['id_tipo_condicion'] == 2).toList();
        _cantones = rCan.data;
        _parroquiasCat = rPar.data;
        
        // Default Chimborazo/Riobamba
        if (_idPacienteEditando == null) {
          _pacCanton = 1; // Riobamba
          _parroquiasFiltradas = _parroquiasCat.where((p) => p['id_canton'] == 1).toList();
        }
        
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setupEdit(Map<String, dynamic> data) {
    final pId = data['id']?.toString();
    if (pId == null) return;
    setState(() => _loading = true);
    Future.microtask(() async {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get("pacientes/$pId/expediente-completo");
        final d = res.data;
        final p = d['paciente'] ?? {};
        final t = d['tutor'] ?? {};
        final s = d['diagnostico'] ?? {};
        final c = d['ultimo_control'] ?? {};
        final al = d['alergias'] ?? {};
        setState(() {
          _idPacienteEditando = pId;
          _tutNombre.text = t['nombre_completo'] ?? "";
          _tutCedula.text = t['cedula'] ?? "";
          _tutEmail.text = t['email'] ?? "";
          _tutTelefono.text = t['telefono'] ?? "";
          _tutDireccion.text = t['direccion'] ?? "";
          _tutParentesco = t['id_parentesco'];
          _tutorExistente = true;
          _pacNombre.text = p['nombre_completo'] ?? "";
          _pacCedula.text = p['cedula'] ?? "";
          _pacSexo = p['id_sexo'];
          _pacCanton = int.tryParse(p['id_canton']?.toString() ?? '');
          _pacParroquia = int.tryParse(p['id_parroquia']?.toString() ?? '');
          if (_pacCanton != null) {
            _parroquiasFiltradas = _parroquiasCat.where((x) => 
              int.tryParse(x['id_canton']?.toString() ?? '') == _pacCanton
            ).toList();
          }
          _pacFechaNac = DateTime.tryParse(p['fecha_nacimiento'] ?? "");
          if (s.isNotEmpty) {
            _idPatologiaBase = s['id_condicion'];
            _clinNotas.text = s['observaciones'] ?? "";
          }
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
          if (al.isNotEmpty) {
            _alergiasSub = (al['subgrupos'] as List? ?? []).map((e) => (e['id'] as num).toInt()).toList();
            _selectedIngredientes = List<Map<String, dynamic>>.from(al['ingredientes'] ?? []);
            _tieneAlergiaSub = _alergiasSub.isNotEmpty;
            _tieneAlergiaIng = _selectedIngredientes.isNotEmpty;
            
            // CORRECCIÓN: Detectar intolerancia si viene la bandera O si los subgrupos de lacteos están seleccionados
            final bool flagLactosa = d['es_intolerante_lactosa'] == true;
            final bool hasLacteos = _alergiasSub.any((id) => _idsLacteos.contains(id));
            _lactosa = flagLactosa || hasLacteos;

            // SI ES INTOLERANTE: Los removemos de la selección manual de alergias para evitar redundancia
            if (_lactosa == true) {
              _alergiasSub.removeWhere((id) => _idsLacteos.contains(id));
              _selectedIngredientes.removeWhere((ing) => _idsLacteos.contains(ing['id_subgrupo_alimentario']));
            }
          }
          _loading = false;
        });
        _calculateOMS();
      } catch (e) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  void _debouncedOMS() {
    _debounceOMS?.cancel();
    _debounceOMS = Timer(const Duration(milliseconds: 500), () => _calculateOMS());
  }

  Future<void> _calculateOMS() async {
    double p = double.tryParse(_clinPeso.text) ?? 0;
    double t = double.tryParse(_clinTalla.text) ?? 0;
    if (p > 1 && t > 30 && _pacFechaNac != null && _pacSexo != null) {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.post("pre-diagnostico-nutricional", data: {
          "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first,
          "id_sexo": _pacSexo,
          "peso_kg": p,
          "talla_cm": t
        });
        if (mounted) {
          setState(() {
            _omsStatusPeso = res.data['diagnostico_nutri_texto'] ?? "Normal";
            _omsStatusTalla = res.data['diagnostico_talla_texto'] ?? "Adecuada";
            _pesoMediana = (res.data['peso_ideal'] ?? 0).toDouble();
            _tallaMediana = (res.data['talla_ideal'] ?? 0).toDouble();
            final combined = "${_omsStatusPeso} ${_omsStatusTalla}";
            if (combined.contains("Severa") || combined.contains("Obesidad") || combined.contains("Bajo peso")) {
              _omsColor = Colors.red;
            } else if (combined.contains("Sobrepeso") || combined.contains("Baja") || combined.contains("Delgadez")) {
              _omsColor = Colors.orange;
            } else {
              _omsColor = greenBrand;
            }
          });
        }
      } catch (e) {
        print("Error calculando OMS: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solo mostramos el scaffold blanco inicial si no hay catálogos cargados. 
    // Si ya hay catálogos, usamos el Stack con el overlay para una mejor transición.
    if (_loading && _parentescos.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTema.grisLienzo,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHeader(),
              const SizedBox(height: 48),
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(primary: greenBrand),
                  inputDecorationTheme: const InputDecorationTheme(
                    floatingLabelBehavior: FloatingLabelBehavior.always, 
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 14),
                  )
                ),
                child: Stepper(
                  type: StepperType.vertical, 
                  currentStep: _currentStep,
                  physics: const NeverScrollableScrollPhysics(),
                  onStepContinue: () {
                    // Mapeo dinámico de validación según el modo
                    int stepToValidate;
                    if (widget.fixedOnly) {
                      stepToValidate = _currentStep + 1; // 0 UI -> 1 Paciente, 1 UI -> 2 Clínico
                    } else {
                      stepToValidate = _currentStep;
                    }

                    if (_validateCurrentStep(stepToValidate)) {
                      final int totalSteps = widget.fixedOnly ? 2 : 3;
                      if (_currentStep < totalSteps - 1) {
                        setState(() => _currentStep++);
                      } else {
                        _finish();
                      }
                    } else {
                      NutriSnack.show(context, "Complete los campos obligatorios marcados con (*)", isError: true, ref: ref);
                    }
                  },
                  onStepCancel: () => setState(() => _currentStep > 0 ? _currentStep-- : null),
                  controlsBuilder: (context, details) => _buildControls(details),
                  steps: [
                    if (!widget.fixedOnly) _stepTutor(),
                    _stepPaciente(),
                    _stepClinico()
                  ],
                ),
              ),
            ]),
          ),
        ),
        if (_loading) _buildLoadingOverlay(),
        if (_sending) _buildSendingOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
            const SizedBox(height: 24),
            Text(
              "CARGANDO FORMULARIO...",
              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_showSuccess) const CircularProgressIndicator(color: greenBrand, strokeWidth: 6),
            if (_showSuccess) const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 100),
            const SizedBox(height: 24),
            Text(
              _showSuccess ? "INFORMACIÓN ENVIADA CON ÉXITO" : "ENVIANDO EXPEDIENTE...",
              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [IconButton.filledTonal(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16), onPressed: () => ref.read(medicoNavProvider.notifier).state = MedicoView.list), const SizedBox(width: 16), Text(_idPacienteEditando == null ? "REGISTRO INTEGRAL PEDIÁTRICO" : "ACTUALIZACIÓN DE EXPEDIENTE", style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)))]), const SizedBox(height: 8), const Text("Formulario clínico estandarizado bajo normativa OMS 2024.", style: TextStyle(color: Colors.blueGrey, fontSize: 14, fontWeight: FontWeight.w600))]);

  bool _validateCurrentStep(int step) {
    if (step == 0) {
      bool base = _tutNombre.text.isNotEmpty && _tutCedula.text.isNotEmpty && _tutParentesco != null && _tutTelefono.text.isNotEmpty && _tutDireccion.text.isNotEmpty && _tutEmail.text.isNotEmpty;
      if (!_tutorExistente) {
        return base && _tutUsuario.text.isNotEmpty && _tutPassword.text.length >= 8;
      }
      return base;
    }
    if (step == 1) return _pacNombre.text.isNotEmpty && _pacCedula.text.isNotEmpty && _pacSexo != null && _pacFechaNac != null;
    return (widget.fixedOnly || (_clinPeso.text.isNotEmpty && _clinTalla.text.isNotEmpty)) && _idPatologiaBase != null;
  }

  Future<void> _finish() async {
    // Si es un registro nuevo (no edición) y el tutor es nuevo, mostramos el modal de credenciales
    if (_idPacienteEditando == null && !_tutorExistente) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Column(
            children: [
              const Icon(Icons.vpn_key_rounded, color: greenBrand, size: 48),
              const SizedBox(height: 16),
              Text("CREDENCIALES DEL TUTOR", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Se creará una nueva cuenta para el representante legal. Por favor, asegúrese de guardar o compartir estos datos:",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.blueGrey, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: greenBrand.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: greenBrand.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    _credRow("USUARIO (EMAIL)", _tutUsuario.text, Icons.alternate_email_rounded),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),
                    _credRow("CONTRASEÑA TEMPORAL", _tutPassword.text, Icons.password_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text("Al hacer clic en 'ACEPTAR', el expediente se enviará al sistema.", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange))),
                ],
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("CANCELAR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: greenBrand,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("ACEPTAR Y ENVIAR", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        )
      );
      if (confirm != true) return;
    }

    setState(() => _sending = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        "tutor": {
          "nombre": _tutNombre.text, 
          "cedula": _tutCedula.text, 
          "email": _tutEmail.text, 
          "id_parentesco": _tutParentesco,
          "telefono": _tutTelefono.text,
          "direccion": _tutDireccion.text,
          "usuario": _tutUsuario.text,
          "password": _tutPassword.text
        },
        "paciente": {
          "nombre_completo": _pacNombre.text, 
          "cedula": _pacCedula.text, 
          "id_sexo": _pacSexo, 
          "id_canton": _pacCanton,
          "id_parroquia": _pacParroquia,
          "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first
        },
        "salud": {
          "id_patologia_base": _idPatologiaBase, "peso_kg": _clinPeso.text, "talla_cm": _clinTalla.text,
          "puntos_dolor": _dolor.toInt(), "escala_inflamacion": _inflamacion.toInt(), "fatiga": _fatiga.toInt(),
          "valor_pcr": _clinPCR.text, "valor_vsg": _clinVSG.text, "articulaciones_inflamadas": _clinArtInflam.text,
          "articulaciones_dolorosas": _clinArtDolor.text, "minutos_rigidez": _clinRigidez.text,
          "en_brote": _brote, "estado_enfermedad": _estadoEnfermedad, "observaciones": _clinNotas.text,
          "es_intolerante_lactosa": _lactosa ?? false, 
          "alergias_subgrupos": _alergiasSub, 
          "alergias_ingredientes": _selectedIngredientes.map((e) => e['id']).toList(),
          "condiciones_temporales": _condicionesTemp, "fecha_proxima_cita": _proximaCita.toIso8601String().split("T").first
        }
      };
      if (_idPacienteEditando == null) {
        await dio.post("registro/paciente-integral", data: payload);
      } else {
        await dio.put("pacientes/$_idPacienteEditando/expediente-maestro", data: payload);
      }
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        final campos = widget.fixedOnly ? "Enfermedad y Alergias" : "Expediente Completo";
        NutriSnack.show(context, "✅ Se han actualizado los campos de $campos correctamente", ref: ref);
      }
      ref.invalidate(patientsListProvider);
      ref.read(medicoNavProvider.notifier).state = MedicoView.list;
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) NutriSnack.show(context, "Error: $e", isError: true, ref: ref);
    }
  }

  Widget _credRow(String l, String v, IconData i) => Row(children: [
    Icon(i, size: 18, color: greenBrand), 
    const SizedBox(width: 12), 
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 4),
        Text(v, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
      ]),
    ),
    IconButton(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: v));
        NutriSnack.show(context, "✅ $l COPIADO", ref: ref);
      },
      icon: const Icon(Icons.copy_rounded, size: 18, color: greenBrand),
      tooltip: "Copiar $l",
    ),
  ]);

  Step _stepTutor() => Step(
    title: const Text("Tutor / Responsable Legal"), 
    isActive: _currentStep >= 0,
    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    content: Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _field(_tutCedula, "Cédula de Identidad del Tutor*", Icons.badge_outlined, helper: "10 dígitos numéricos")),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(height: 52, child: ElevatedButton.icon(
              onPressed: _buscandoTutor ? null : () => _buscarTutor(_tutCedula.text), 
              style: ElevatedButton.styleFrom(backgroundColor: greenBrand, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
              icon: _buscandoTutor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.search, size: 18), 
              label: Text(_buscandoTutor ? "BUSCANDO..." : "VALIDAR"))),
          ),
        ]),
        if (_tutorNoEncontrado) ...[
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Text("TUTOR NO ENCONTRADO. INGRESE DATOS MANUALMENTE.", style: GoogleFonts.montserrat(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
          ]),
        ],
        const SizedBox(height: 32),
        _field(_tutNombre, "Nombre Completo del Responsable*", Icons.person_outline),
        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: _field(_tutTelefono, "Teléfono / Celular*", Icons.phone_android_rounded)),
          const SizedBox(width: 16),
          Expanded(child: _field(_tutDireccion, "Dirección de Domicilio*", Icons.home_work_outlined)),
        ]),
        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: _dropdown("Grado de Parentesco*", _parentescos, _tutParentesco, (v) => setState(() => _tutParentesco = v))),
          const SizedBox(width: 16),
          Expanded(child: _field(_tutEmail, "Correo Electrónico Principal*", Icons.email_outlined)),
        ]),
        if (!_tutorExistente) ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          _sectionHeader("CREDENCIALES DE ACCESO PARA EL TUTOR", Icons.lock_person_rounded),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _field(_tutUsuario, "Usuario de Acceso (Email)*", Icons.alternate_email_rounded, helper: "Sugerido: usar el mismo correo")),
            const SizedBox(width: 16),
            Expanded(child: _field(_tutPassword, "Contraseña Temporal*", Icons.password_rounded, helper: "Mínimo 8 caracteres")),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text("Estas credenciales permitirán al tutor acceder a la aplicación móvil para realizar el seguimiento nutricional.", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold))),
            ]),
          )
        ],
      ]),
    )
  );

  Step _stepPaciente() => Step(
    title: const Text("Información del Paciente"), 
    isActive: _currentStep >= 1,
    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    content: Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(children: [
        _field(_pacCedula, "Cédula de Identidad del Paciente*", Icons.badge_outlined),
        const SizedBox(height: 32),
        _field(_pacNombre, "Nombres y Apellidos Completos del Paciente*", Icons.child_care_rounded),
        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: _dropdown("Sexo Biológico*", _sexos, _pacSexo, (v) { setState(() => _pacSexo = v); _debouncedOMS(); })),
          const SizedBox(width: 16),
          Expanded(child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))), child: ListTile(leading: const Icon(Icons.cake_outlined, color: greenBrand), title: const Text("Fecha de Nacimiento*", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), subtitle: Text(_pacFechaNac == null ? "Seleccionar fecha..." : DateFormat('dd/MM/yyyy').format(_pacFechaNac!)), onTap: () async { final d = await showDatePicker(context: context, initialDate: _pacFechaNac ?? DateTime.now().subtract(const Duration(days: 3650)), firstDate: DateTime(2005), lastDate: DateTime.now()); if (d != null) { setState(() => _pacFechaNac = d); _debouncedOMS(); } }))),
        ]),
        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: _dropdown("Cantón de Residencia*", _cantones, _pacCanton, (v) {
            setState(() {
              _pacCanton = v;
              _pacParroquia = null;
              _parroquiasFiltradas = _parroquiasCat.where((p) => p['id_canton'] == v).toList();
            });
          })),
          const SizedBox(width: 16),
          Expanded(child: _dropdown("Parroquia de Residencia*", _parroquiasFiltradas, _pacParroquia, (v) => setState(() => _pacParroquia = v))),
        ]),
      ]),
    )
  );

  Step _stepClinico() => Step(
    title: Text(widget.fixedOnly ? "Edición de Datos Fijos" : "Valoración de Salud y Nutrición"), 
    isActive: widget.fixedOnly || _currentStep >= 2,
    content: Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.fixedOnly) ...[
          _buildProfessionalPrediagnosis(),
          const SizedBox(height: 48),
          _sectionHeader("MEDIDAS ANTROPOMÉTRICAS", Icons.straighten_rounded),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _field(_clinPeso, "Peso Actual (kg)*", Icons.monitor_weight_outlined, onChanged: (_) => _debouncedOMS())), 
            const SizedBox(width: 24), 
            Expanded(child: _field(_clinTalla, "Talla Actual (cm)*", Icons.height_rounded, onChanged: (_) => _debouncedOMS()))
          ]),
          const SizedBox(height: 48),
        ],
        _sectionHeader("DIAGNÓSTICO REUMATOLÓGICO BASE", Icons.medical_services_outlined),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _dropdown("Patología Base*", _patologias, _idPatologiaBase, (v) => setState(() => _idPatologiaBase = v))),
          if (!widget.fixedOnly) ...[
            const SizedBox(width: 16),
            Expanded(child: DropdownButtonFormField<String>(
              value: _estadoEnfermedad,
              decoration: const InputDecoration(labelText: "Nivel de Actividad*", floatingLabelBehavior: FloatingLabelBehavior.always),
              items: _estadosClinicos.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _estadoEnfermedad = v!),
            )),
          ]
        ]),
        if (!widget.fixedOnly) ...[
          const SizedBox(height: 40),
          _buildMetricSlider("NIVEL DE DOLOR (EVA)", _dolor, (v) => setState(() => _dolor = v), "DOLOR"),
          const SizedBox(height: 32),
          _buildMetricSlider("INFLAMACIÓN ARTICULAR (0-3)", _inflamacion, (v) => setState(() => _inflamacion = v), "INFLAMACION"),
          const SizedBox(height: 32),
          _buildMetricSlider("NIVEL DE FATIGA / ASTENIA", _fatiga, (v) => setState(() => _fatiga = v), "FATIGA"),
          const SizedBox(height: 48),
          Row(children: [
            Expanded(child: _field(_clinArtInflam, "Art. Inflamadas", Icons.adjust_rounded)),
            const SizedBox(width: 16),
            Expanded(child: _field(_clinArtDolor, "Art. Dolorosas", Icons.pan_tool_alt_rounded)),
            const SizedBox(width: 16),
            Expanded(child: _field(_clinRigidez, "Rigidez Matinal (min)", Icons.timer_outlined))
          ]),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: _field(_clinPCR, "PCR (Proteína C)", Icons.biotech_outlined, helper: "Valor normal < 5 mg/L")),
            const SizedBox(width: 16),
            Expanded(child: _field(_clinVSG, "VSG (Velocidad Sedim.)", Icons.bloodtype_outlined, helper: "Valor normal < 15 mm/h")),
          ]),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _brote ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: _brote ? Colors.red : greenBrand)),
            child: SwitchListTile(
              title: Text(_brote ? "BROTE ACTIVO DETECTADO" : "SIN BROTE ACTIVO", style: TextStyle(fontWeight: FontWeight.w900, color: _brote ? Colors.red : greenBrand)),
              subtitle: const Text("Indique si existe una crisis articular hoy"),
              value: _brote, onChanged: (v) => setState(() => _brote = v), activeColor: Colors.red,
            ),
          ),
        ],
        const SizedBox(height: 56),
        _sectionHeader("ALERGIAS E INCOMPATIBILIDADES", Icons.security_rounded),
        const SizedBox(height: 24),
        _buildAlergiasCheckboxes(),
        if (!widget.fixedOnly) ...[
          const SizedBox(height: 56),
          _sectionHeader("SÍNTOMAS AGUDOS TEMPORALES", Icons.event_note_rounded),
          const SizedBox(height: 24),
          _buildSintomasAgudosGrid(),
          const SizedBox(height: 56),
          _sectionHeader("PLANIFICACIÓN", Icons.calendar_month_rounded),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: ListTile(
              leading: const Icon(Icons.calendar_today_rounded, color: greenBrand),
              title: const Text("Fecha de Próxima Cita*", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              subtitle: Text(DateFormat('EEEE, dd/MM/yyyy', 'es').format(_proximaCita).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: greenBrand)),
              onTap: () async { 
                final d = await showDatePicker(context: context, initialDate: _proximaCita, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180))); 
                if (d != null) setState(() => _proximaCita = d); 
              }
            )
          ),
        ],
        const SizedBox(height: 32),
        _field(_clinNotas, "Observaciones Médicas", Icons.edit_note_rounded, maxLines: 3),
      ]),
    )
  );

  Widget _buildProfessionalPrediagnosis() {
    if (_omsStatusPeso == "PENDIENTE") {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [const Icon(Icons.analytics_rounded, color: Colors.grey), const SizedBox(width: 16), Text("PENDIENTE DE VALORES ANTROPOMÉTRICOS", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey))]),
      );
    }
    
    double pActual = double.tryParse(_clinPeso.text) ?? 0;
    double tActual = double.tryParse(_clinTalla.text) ?? 0;
    String weightMsg = "";
    if (pActual > _pesoMediana + 0.5) weightMsg = "PESO NORMAL: Debe disminuir ${(pActual - _pesoMediana).toStringAsFixed(1)} kg";
    else if (pActual < _pesoMediana - 0.5) weightMsg = "PESO NORMAL: Debe aumentar ${(_pesoMediana - pActual).toStringAsFixed(1)} kg";
    else weightMsg = "PESO DENTRO DEL RANGO NORMAL";

    String heightMsg = "";
    if (tActual < _tallaMediana - 0.5) heightMsg = "ESTATURA IDEAL: ${_tallaMediana.toStringAsFixed(1)} cm (Debe crecer ${(_tallaMediana - tActual).toStringAsFixed(1)} cm)";
    else heightMsg = "ESTATURA ADECUADA PARA LA EDAD";

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _omsColor.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: _omsColor.withOpacity(0.2), width: 2)),
      child: Column(children: [
        Row(children: [
          Icon(Icons.monitor_heart_rounded, color: _omsColor, size: 28), const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("EVALUACIÓN CLÍNICA NUTRICIONAL (REF. OMS)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _omsColor, letterSpacing: 1)),
            Text("${_omsStatusPeso.toUpperCase()} | ${_omsStatusTalla.toUpperCase()}", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          ])),
        ]),
        const Divider(height: 32),
        _infoRow(weightMsg, Icons.scale_outlined, _omsColor),
        const SizedBox(height: 8),
        _infoRow(heightMsg, Icons.height_rounded, _omsColor),
      ]),
    );
  }

  Widget _infoRow(String txt, IconData i, Color col) => Row(children: [Icon(i, size: 16, color: Colors.blueGrey), const SizedBox(width: 12), Expanded(child: Text(txt, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))))]);

  Widget _buildAlergiasCheckboxes() {
    return Container(
      padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("¿INTOLERANCIA A LA LACTOSA?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Row(children: [
          _yesNoBtn("SÍ", true, _lactosa == true, (v) {
            setState(() { 
              _lactosa = v; 
              // Si es intolerante, eliminamos cualquier selección previa de lácteos para evitar conflictos
              _alergiasSub.removeWhere((id) => _idsLacteos.contains(id)); 
              _selectedIngredientes.removeWhere((ing) => _idsLacteos.contains(ing['id_subgrupo_alimentario'])); 
            });
          }),
          const SizedBox(width: 12),
          _yesNoBtn("NO", false, _lactosa == false, (v) => setState(() => _lactosa = v)),
        ]),
        if (_lactosa == true) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            Text("LOS GRUPOS LÁCTEOS SE BLOQUEARÁN AUTOMÁTICAMENTE.", style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
          ]),
        ),
        const Divider(height: 48),
        SwitchListTile(title: const Text("¿ALERGIA A SUBGRUPOS?", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), value: _tieneAlergiaSub, onChanged: (v) => setState(() => _tieneAlergiaSub = v)),
        if (_tieneAlergiaSub) _multiSelectChips(
          "Seleccione los subgrupos:", 
          _subgrupos, 
          _alergiasSub, 
          (id, s) { 
            if (_lactosa == true && _idsLacteos.contains(id)) return; // Bloqueo manual
            setState(() { if (s) { _alergiasSub.add(id); _selectedIngredientes.removeWhere((ing) => ing['id_subgrupo_alimentario'] == id); } else { _alergiasSub.remove(id); } }); 
          },
          blockedIds: _lactosa == true ? _idsLacteos : {}
        ),
        const Divider(height: 48),
        SwitchListTile(title: const Text("¿ALERGIA A INGREDIENTES?", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), value: _tieneAlergiaIng, onChanged: (v) => setState(() => _tieneAlergiaIng = v)),
        if (_tieneAlergiaIng) ...[
          Autocomplete<Map<String, dynamic>>(
            displayStringForOption: (o) => o['nombre'],
            optionsBuilder: (v) {
              if (v.text.isEmpty) return const Iterable.empty();
              final term = v.text.toLowerCase();
              return _ingredientes.where((i) {
                final subId = i['id_subgrupo_alimentario'];
                final bool subBloqueado = (_lactosa == true && _idsLacteos.contains(subId)) || _alergiasSub.contains(subId);
                if (subBloqueado) return false;
                
                final nombre = i['nombre'].toString().toLowerCase();
                for (var idSub in _alergiasSub) {
                   final sg = _subgrupos.firstWhere((x) => x['id'] == idSub, orElse: () => null);
                   if (sg != null && nombre.contains(sg['nombre'].toString().toLowerCase())) return false;
                }

                final sinonimos = (i['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
                return nombre.contains(term) || sinonimos.any((s) => s.contains(term));
              }).cast<Map<String, dynamic>>();
            },
            onSelected: (i) => setState(() { if (!_selectedIngredientes.any((x) => x['id'] == i['id'])) { _selectedIngredientes.add(i); _autoBloquearDerivados(i['nombre']); } }),
            fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) => TextField(controller: ctrl, focusNode: focus, decoration: InputDecoration(hintText: _lactosa == true ? "Lácteos bloqueados por intolerancia" : "Ej. Chocolate, Maní, etc.", hintStyle: const TextStyle(fontSize: 12), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.search))),
          ),
          if (_selectedIngredientes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 8, runSpacing: 8, children: _selectedIngredientes.map((i) => Chip(label: Text(i['nombre'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), onDeleted: () => setState(() => _selectedIngredientes.remove(i)))).toList())),
        ]
      ]),
    );
  }

  Widget _yesNoBtn(String l, bool v, bool sel, Function(bool) onC) {
    return Expanded(child: InkWell(onTap: () => onC(v), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: sel ? greenBrand : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? greenBrand : Colors.grey.shade300)), child: Center(child: Text(l, style: TextStyle(color: sel ? Colors.white : Colors.black, fontWeight: FontWeight.bold))))));
  }

  void _autoBloquearDerivados(String nombre) {
    final n = nombre.toLowerCase().trim();
    final derivados = _ingredientes.where((i) {
      final iname = i['nombre'].toString().toLowerCase();
      final isyn = (i['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
      
      final subId = i['id_subgrupo_alimentario'];
      if ((_lactosa == true && _idsLacteos.contains(subId)) || _alergiasSub.contains(subId)) return false;

      // Caso base: el nombre contiene el término
      bool matches = (iname.contains(n) && iname != n);
      
      // Caso 2: algún sinónimo contiene el término
      if (!matches) {
        matches = isyn.any((s) => s.contains(n) && s != n);
      }

      // Casos especiales (ej. fresa -> mermelada de fresa)
      if (!matches) {
        if (n.contains("fresa") && (iname.contains("mermelada") || iname.contains("yogurt"))) {
          matches = iname.contains("fresa");
        }
        if (n.contains("coco") && (iname.contains("aceite") || iname.contains("leche") || iname.contains("rallado"))) {
          matches = iname.contains("coco");
        }
      }

      return matches;
    }).toList();

    for (var d in derivados) {
      if (!_selectedIngredientes.any((x) => x['id'] == d['id'])) {
        _selectedIngredientes.add(d);
      }
    }
  }

  Widget _buildSintomasAgudosGrid() {
    return Column(children: _condicionesTemporalesCat.map<Widget>((c) {
      final id = c['id'] as int; final index = _condicionesTemp.indexWhere((s) => s['id'] == id); final sel = index != -1;
      return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: sel ? greenBrand.withOpacity(0.03) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? greenBrand.withOpacity(0.2) : Colors.grey.shade100)), 
        child: ExpansionTile(key: Key("temp_$id"), initiallyExpanded: sel, shape: const Border(), leading: Checkbox(activeColor: greenBrand, value: sel, onChanged: (v) async { if (v!) { final ini = DateTime.now(); final dur = c['dias_duracion_estandar'] ?? 7; setState(() { _condicionesTemp.add({"id": id, "nombre": c['nombre'], "fecha_inicio": ini.toIso8601String().split('T')[0], "fecha_fin": ini.add(Duration(days: dur)).toIso8601String().split('T')[0]}); }); _pickTempDate(index == -1 ? _condicionesTemp.length - 1 : index, true); } else { setState(() => _condicionesTemp.removeAt(index)); } }), title: Text(c['nombre'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), children: sel ? [Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: _datePickerSmall("Desde", _condicionesTemp[index]['fecha_inicio'], (d) { setState(() { _condicionesTemp[index]['fecha_inicio'] = d.toIso8601String().split('T')[0]; final dur = c['dias_duracion_estandar'] ?? 7; _condicionesTemp[index]['fecha_fin'] = d.add(Duration(days: dur)).toIso8601String().split('T')[0]; }); })), const SizedBox(width: 12), Expanded(child: _datePickerSmall("Hasta", _condicionesTemp[index]['fecha_fin'], (d) => setState(() => _condicionesTemp[index]['fecha_fin'] = d.toIso8601String().split('T')[0])))]))] : []));
    }).toList());
  }

  Future<void> _pickTempDate(int index, bool isStart) async {
    final current = DateTime.parse(isStart ? _condicionesTemp[index]['fecha_inicio'] : _condicionesTemp[index]['fecha_fin']);
    final d = await showDatePicker(context: context, initialDate: current, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 60)));
    if (d != null) { setState(() { if (isStart) { _condicionesTemp[index]['fecha_inicio'] = d.toIso8601String().split('T')[0]; final dur = _condicionesTemporalesCat.firstWhere((e) => e['id'] == _condicionesTemp[index]['id'])['dias_duracion_estandar'] ?? 7; _condicionesTemp[index]['fecha_fin'] = d.add(Duration(days: dur)).toIso8601String().split('T')[0]; } else { _condicionesTemp[index]['fecha_fin'] = d.toIso8601String().split('T')[0]; } }); }
  }

  Widget _datePickerSmall(String l, String v, Function(DateTime) onP) => InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.parse(v), firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now().add(const Duration(days: 60))); if (d != null) onP(d); }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))])));

  Widget _field(TextEditingController c, String l, IconData i, {int maxLines = 1, Function(String)? onChanged, bool enabled = true, String? helper}) {
    bool n = l.contains("Peso") || l.contains("Talla") || l.contains("PCR") || l.contains("VSG") || l.contains("min") || l.contains("Artic") || l.contains("Cédula");
    return TextFormField(
      controller: c, maxLines: maxLines, enabled: enabled, onChanged: onChanged, textInputAction: TextInputAction.next,
      keyboardType: n ? TextInputType.number : TextInputType.text, 
      decoration: InputDecoration(labelText: l, floatingLabelBehavior: FloatingLabelBehavior.always, helperText: helper, helperMaxLines: 2, prefixIcon: Icon(i, size: 18), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22))
    );
  }

  Widget _dropdown(String l, List<dynamic> items, int? val, Function(int?) onC) => DropdownButtonFormField<int>(value: val, items: items.map((e) => DropdownMenuItem<int>(value: e['id'], child: Text(e['nombre'] ?? e['descripcion'], style: const TextStyle(fontSize: 12)))).toList(), onChanged: onC, decoration: InputDecoration(labelText: l, floatingLabelBehavior: FloatingLabelBehavior.always, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)));

  Widget _buildControls(ControlsDetails d) => Padding(padding: const EdgeInsets.only(top: 48), child: Row(children: [Expanded(child: FilledButton(onPressed: d.onStepContinue, style: FilledButton.styleFrom(backgroundColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 20)), child: Text(widget.fixedOnly || _currentStep == 2 ? (_idPacienteEditando == null ? "REGISTRAR PACIENTE" : "GUARDAR CAMBIOS") : "CONTINUAR"))), if (!widget.fixedOnly && _currentStep > 0) ...[const SizedBox(width: 16), Expanded(child: OutlinedButton(onPressed: d.onStepCancel, style: OutlinedButton.styleFrom(side: const BorderSide(color: greenBrand), foregroundColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 20)), child: const Text("REGRESAR")))]]));

  Widget _sectionHeader(String t, IconData i) => Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: greenBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(i, size: 18, color: greenBrand)), const SizedBox(width: 16), Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0F172A), letterSpacing: 0.5))]);

  String _emojiSubgrupo(int id) {
    return { 8: "🍄", 9: "🍄", 10: "🥔", 11: "🥦", 12: "🥫", 13: "🥬", 14: "🥤", 15: "🍓", 16: "🍇", 17: "🍎", 18: "🥜", 19: "🍊", 24: "🥚", 25: "🍗", 26: "🐖", 27: "🐑", 29: "🥩", 30: "🐄", 31: "🫀", 32: "🦐", 33: "🐟", 34: "🐠", 35: "🐟", 36: "🥫", 37: "🧂", 38: "🫒", 41: "🧄", 43: "🍬", 47: "🍭", 48: "🍿", 49: "🥤", 50: "💧", 51: "☕", 53: "🧃", 88: "🌾", 89: "🌾", 90: "🍞", 91: "🍞", 92: "🍝", 93: "🫘", 94: "🌱", 95: "🫘", 96: "🥫", 97: "🥜", 98: "🥛", 99: "🥛", 100: "🍶", 101: "🥛", 102: "🥛", 103: "🥥", 104: "🥛", 105: "🧀", 106: "🧀", 107: "🧀", 108: "🧀", 109: "🥓", 110: "🌭", 111: "🧈", 112: "🧈", 113: "🥓", 114: "🥣", 115: "🥣", 116: "🥢", 117: "🍫", 118: "🍫", 119: "🍮", 120: "🍬", 121: "🍪", 122: "🥛", 123: "🥛", 124: "🥛" }[id] ?? "🍽️";
  }

  Widget _multiSelectChips(String label, List<dynamic> items, List<int> selected, Function(int, bool) onSelected, {Set<int> blockedIds = const {}}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: items.map((item) {
        final id = (item['id'] as num).toInt(); 
        final isSelected = selected.contains(id);
        final isBlocked = blockedIds.contains(id);
        
        return FilterChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_emojiSubgrupo(id), style: TextStyle(fontSize: 14, color: isBlocked ? Colors.grey : null)), 
            const SizedBox(width: 4), 
            Text(item['nombre'] ?? "", style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isBlocked ? Colors.grey : null))
          ]), 
          selected: isSelected, 
          onSelected: isBlocked ? null : (val) => onSelected(id, val), 
          selectedColor: greenBrand.withOpacity(0.1), 
          checkmarkColor: greenBrand, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: isBlocked ? Colors.grey.shade100 : null,
        );
      }).toList())
    ]);
  }

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
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF475569))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text("${val.toInt()}/${maxV.toInt()}", style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)))
      ]),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.15), width: 1.5)), child: Column(children: [
        Row(children: [Text(emoji, style: const TextStyle(fontSize: 32)), const SizedBox(width: 16), Expanded(child: Text(desc, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)))]),
        const SizedBox(height: 8),
        SliderTheme(data: SliderThemeData(activeTrackColor: color, inactiveTrackColor: const Color(0xFFF1F5F9), thumbColor: color, trackHeight: 8, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10)), child: Slider(value: val, min: 0, max: maxV, divisions: divisions, onChanged: (v) { onC(v); setState(() {}); })),
      ]))
    ]);
  }
}
