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
  static const Set<int> _subgruposLactosa = {98, 100, 101, 104, 105, 108, 111, 114, 117, 119};
  List<dynamic> _cantones = [];
  List<dynamic> _parroquiasCat = [];
  List<dynamic> _parroquiasFiltradas = [];

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
      final catalogos = await ref.read(repositorioMedicoProvider).obtenerCatalogosRegistroPaciente();
      if (mounted) {
        setState(() {
          _parentescos = catalogos["parentescos"] ?? [];
          _sexos = catalogos["sexos"] ?? [];
          _patologias = catalogos["patologias"] ?? [];
          _condicionesTemporalesCat = catalogos["condiciones_temporales"] ?? [];
          _restriccionesAlimentariasCat = catalogos["restricciones_alimentarias"] ?? [];
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
        final data = await ref.read(repositorioMedicoProvider).obtenerExpedienteCompleto(widget.initialData!['id'].toString());
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
              final restriccionesRaw = (data['restricciones_alimentarias'] as List?) ??
                  (al['restricciones_codigos'] as List?) ??
                  const [];
              _restriccionesAlimentarias = restriccionesRaw.map((e) => e.toString()).toSet();
              _lactosa = (data['es_intolerante_lactosa'] == true) || _restriccionesAlimentarias.contains("INTOLERANCIA_LACTOSA");
              if (_lactosa == true) {
                _restriccionesAlimentarias.add("INTOLERANCIA_LACTOSA");
              }
            }

            final c = data['ultimo_control'] ?? {};
            if (c.isNotEmpty) {
               _clinPeso.text = c['peso_kg']?.toString() ?? "";
               _clinTalla.text = c['talla_cm']?.toString() ?? "";
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
        double asDouble(dynamic value, {double fallback = 0}) {
          if (value is num) return value.toDouble();
          return double.tryParse(value?.toString() ?? "") ?? fallback;
        }
        final data = await ref.read(repositorioMedicoProvider).preDiagnosticoNutricional({
          "fecha_nacimiento": _pacFechaNac!.toIso8601String().split("T").first,
          "id_sexo": _pacSexo, "peso_kg": p, "talla_cm": t
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
            
            final combined = (data['diagnostico_combinado'] ?? "$_omsStatusPeso / $_omsStatusTalla").toString().toLowerCase();
            if (combined.contains("severa") || combined.contains("emaciación") || combined.contains("desnutrición")) _omsColor = Colors.red;
            else if (combined.contains("sobrepeso") || combined.contains("riesgo")) _omsColor = Colors.orange;
            else _omsColor = greenBrand;
            _calculandoOMS = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _calculandoOMS = false);
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
  Color _omsColor = Colors.grey;
  double _pesoMediana = 0;
  double _tallaMediana = 0;

  final _formKey = GlobalKey<FormState>();

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
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: greenBrand, width: 2)),
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13),
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
          _idPacienteEditando == null ? "Registro Integral Pediátrico" : "EXPEDIENTE: ${_pacNombre.text.toUpperCase()}", 
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
    return _idPatologiaBase != null && _lactosa != null && _restriccionesAlimentariasCat.isNotEmpty;
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
                final creds = "Usuario: ${_tutEmail.text}\nClave: $_generatedPassword";
                await Clipboard.setData(ClipboardData(text: creds));
                if (mounted) NutriSnack.show(context, "Credenciales copiadas", ref: ref);
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
      final sanitizedRestricciones = _restriccionesAlimentarias
          .where(validCodes.contains)
          .toSet();
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
          "articulaciones_inflamadas": _clinArtInflam.text, "articulaciones_dolorosas": _clinArtDolor.text,
          "minutos_rigidez": _clinRigidez.text, "puntos_dolor": _dolor.toInt(),
          "escala_inflamacion": _inflamacion.toInt(), "fatiga": _fatiga.toInt(),
          "en_brote": _brote, "estado_enfermedad": _estadoEnfermedad, "observaciones": _clinNotas.text,
          "es_intolerante_lactosa": _lactosa,
          "restricciones_alimentarias": sanitizedRestricciones.toList(),
          "alergias_subgrupos": _alergiasSub,
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
      if (mounted) {
        NutriSnack.show(
          context,
          "Error al guardar: ${_mensajeError(e)}",
          isError: true,
          ref: ref,
        );
      }
    } finally { if (mounted) setState(() => _sending = false); }
  }

  String _mensajeError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data["detail"];
        if (detail is String && detail.trim().isNotEmpty) return detail;
        if (detail is Map) {
          final motivo = detail["detail"] ?? detail["message"] ?? detail["error"];
          if (motivo is String && motivo.trim().isNotEmpty) return motivo;
        }
      }
      final msg = error.message;
      if (msg != null && msg.trim().isNotEmpty) return msg;
    }
    return error.toString();
  }

  Widget _credItem(String l, String v, IconData i) => Row(children: [Icon(i, size: 18, color: greenBrand), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))])]);

  Step _stepTutor() => Step(
    isActive: _currentStep >= 0,
    state: _currentStep > 0 ? StepState.complete : StepState.editing,
    title: Text("REPRESENTANTE LEGAL", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
    content: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field(_tutCedula, "Cédula del Tutor*", Icons.assignment_ind_outlined, hint: "Ingrese la cédula del tutor", onChanged: (v) { if (v.length == 10) _buscarTutor(v); })),
            const SizedBox(width: 12),
            IconButton.filled(onPressed: () => _buscarTutor(_tutCedula.text), icon: const Icon(Icons.search), style: IconButton.styleFrom(backgroundColor: greenBrand, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
          ]),
          if (_buscandoTutor) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
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
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Tutor no registrado. Por favor complete los datos.", 
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange.shade900)
                  ),
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
                    decoration: const BoxDecoration(color: greenBrand, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Tutor encontrado. Puede actualizar sus datos si es necesario.", 
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade900)
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          _field(_tutNombre, "Nombre y Apellidos*", Icons.person_outline, hint: "Ingrese los nombres y apellidos completos"),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _field(_tutEmail, "Email de Usuario*", Icons.alternate_email, helper: "Este será su nombre de acceso.", hint: "usuario@ejemplo.com")),
            const SizedBox(width: 20),
            Expanded(child: _dropdown("Parentesco*", _parentescos, _tutParentesco, (v) => setState(() => _tutParentesco = v), hint: "Seleccione una opción")),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _field(_tutTelefono, "Teléfono Móvil", Icons.phone_android_outlined, hint: "09XXXXXXXX")),
            const SizedBox(width: 20),
            Expanded(child: _field(_tutDireccion, "Dirección del Hogar", Icons.map_outlined, hint: "Av. Principal y Calle Secundaria")),
          ]),
        ],
      ),
    )
  );

  Step _stepPaciente() => Step(
    isActive: _currentStep >= (widget.fixedOnly ? 0 : 1),
    state: _currentStep > (widget.fixedOnly ? 0 : 1) ? StepState.complete : StepState.editing,
    title: Text("IDENTIDAD DEL PACIENTE", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
    content: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _field(_pacCedula, "Cédula / ID del Menor*", Icons.assignment_ind_outlined, hint: "Ingrese la cédula o ID del menor"),
          const SizedBox(height: 24),
          _field(_pacNombre, "Nombres y Apellidos Completos*", Icons.person_outline, hint: "Ingrese los nombres y apellidos completos"),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: InkWell(onTap: _pickFechaNac, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))), child: Row(children: [const Icon(Icons.calendar_today_outlined, size: 20, color: greenBrand), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Fecha de nacimiento*", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)), Text(_pacFechaNac == null ? "Seleccione una fecha completa" : _formatFechaCompleta(_pacFechaNac!), style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _pacFechaNac == null ? Colors.grey.shade400 : Colors.black87))])])))),
            const SizedBox(width: 20),
            Expanded(child: _dropdown("Sexo Biológico*", _sexos, _pacSexo, (v) => setState(() { _pacSexo = v; _calculateOMS(); }), hint: "Seleccione una opción")),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _dropdown("Cantón de Residencia", _cantones, _pacCanton, (v) { setState(() { _pacCanton = v; _updateParroquiasFiltradas(); }); }, hint: "Seleccione un cantón")),
            const SizedBox(width: 20),
            Expanded(child: _dropdown("Parroquia de Residencia", _parroquiasFiltradas, _pacParroquia, (v) => setState(() => _pacParroquia = v), hint: "Seleccione una parroquia")),
          ]),
        ],
      ),
    )
  );

  Step _stepClinico() => Step(
    isActive: _currentStep >= (widget.fixedOnly ? 1 : 2),
    state: StepState.editing,
    title: Text("PROTOCOLO DE EVALUACIÓN CLÍNICA", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14)),
    content: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ENFERMEDAD PRINCIPAL
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader("ENFERMEDAD PRINCIPAL", Icons.add_box_outlined),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _dropdown("Patología / Enfermedad Base*", _patologias, _idPatologiaBase, (v) => setState(() => _idPatologiaBase = v), hint: "Seleccione...")),
              const SizedBox(width: 24),
              Expanded(child: _dropdown("Estado de la Enfermedad*", _estadosClinicos.asMap().entries.map((e) => {"id": e.key, "nombre": e.value}).toList(), _estadosClinicos.indexOf(_estadoEnfermedad), (v) => setState(() => _estadoEnfermedad = _estadosClinicos[v!]), hint: "Seleccione...")),
            ]),
          ]),
        ),
        const SizedBox(height: 24),

        // ACTIVIDAD DE LA ENFERMEDAD
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader("ACTIVIDAD DE LA ENFERMEDAD", Icons.analytics_outlined),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: EscalaSelector(titulo: "DOLOR", descripcion: "", min: 0, max: 10, value: _dolor.toInt(), icons: const [Icons.sentiment_very_satisfied_rounded, Icons.sentiment_satisfied_rounded, Icons.sentiment_satisfied_rounded, Icons.sentiment_neutral_rounded, Icons.sentiment_neutral_rounded, Icons.sentiment_dissatisfied_rounded, Icons.sentiment_dissatisfied_rounded, Icons.sentiment_very_dissatisfied_rounded, Icons.sentiment_very_dissatisfied_rounded, Icons.sick_rounded, Icons.sick_rounded], etiquetas: [EscalaEtiqueta("Leve", 3), EscalaEtiqueta("Moderado", 4), EscalaEtiqueta("Severo", 4)], colorActivo: Colors.red, colorFondoActivo: Colors.red, backgroundColor: const Color(0xFFF8FAFC), showIdentityRow: false, onChanged: (v) => setState(() => _dolor = v.toDouble()), puntajeLabel: "${_dolor.toInt()}/10", headerIcon: const Icon(Icons.healing_rounded, color: Colors.red, size: 28))),
                const SizedBox(width: 24),
                Expanded(child: _buildEVACard("INFLAMACIÓN", _inflamacion, 3, (v) => setState(() => _inflamacion = v), 
                  icon: Icons.verified_user_outlined,
                  dynamicIcons: const [
                    Icons.health_and_safety_outlined,
                    Icons.shield_outlined,
                    Icons.warning_amber_rounded,
                    Icons.local_hospital_rounded
                  ],
                  labels: ["0 = Sin inflamación", "1 = Leve", "2 = Moderada", "3 = Severa / Activa"])),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildEVACard("ENERGÍA", _fatiga, 10, (v) => setState(() => _fatiga = v), 
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
                  labels: ["0-3 = Agotamiento", "4-7 = Intermedio", "8-10 = Alta energía"])),
                const SizedBox(width: 24),
                Expanded(child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: _buildCounterField("Art. Inflamadas", _clinArtInflam, Icons.track_changes_outlined)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildCounterField("Art. Dolorosas", _clinArtDolor, Icons.back_hand_outlined)),
                    ]),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader("ALERGIAS E INTOLERANCIAS", Icons.warning_amber_rounded),
            const SizedBox(height: 8),
            Text("Registra restricciones alimentarias y alergias relevantes del paciente.", 
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),
            _buildAlergiasStepContent(),
          ]),
        ),

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
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader("INGREDIENTES RECOMENDADOS", Icons.recommend_rounded),
              const SizedBox(height: 12),
              Text("Opcional. El doctor puede recomendar ingredientes con búsqueda inteligente.", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              _buildRecomendacionesSelector(),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        _field(_clinNotas, "Observaciones Médicas Iniciales", Icons.edit_note_rounded, maxLines: 4),
      ]),
    )
  );

  Widget _buildEVACard(String title, double val, int max, Function(double) onC, {required IconData icon, required List<String> labels, List<IconData>? dynamicIcons}) {
    final int current = val.toInt().clamp(0, max);
    final IconData activeIcon = (dynamicIcons != null && dynamicIcons.length > current) ? dynamicIcons[current] : icon;
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
                  decoration: BoxDecoration(color: AppTema.verdeSalud.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(activeIcon, color: AppTema.verdeSalud, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTema.verdeSalud.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text("${val.toInt()}/$max", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: AppTema.verdeSalud)),
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
                      border: Border.all(color: isSel ? AppTema.verdeSalud : Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Text("$index", 
                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: isSel ? Colors.white : Colors.blueGrey)),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((l) => Text(l, style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.blueGrey))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterField(String label, TextEditingController ctrl, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, size: 18, color: Colors.blueGrey),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.zero),
                ),
              ),
              IconButton(onPressed: () { int v = int.tryParse(ctrl.text) ?? 0; if (v > 0) ctrl.text = (v - 1).toString(); }, icon: const Icon(Icons.remove, size: 16)),
              IconButton(onPressed: () { int v = int.tryParse(ctrl.text) ?? 0; ctrl.text = (v + 1).toString(); }, icon: const Icon(Icons.add, size: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBroteToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _brote ? Colors.red.withOpacity(0.05) : AppTema.verdeSalud.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brote ? Colors.red.withOpacity(0.1) : AppTema.verdeSalud.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _brote ? Colors.red : AppTema.verdeSalud, shape: BoxShape.circle),
            child: Icon(_brote ? Icons.warning_amber_rounded : Icons.check_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_brote ? "BROTE ACTIVO DETECTADO" : "SIN BROTE ACTIVO", 
                  style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: _brote ? Colors.red.shade900 : Colors.green.shade900)),
                Text("¿Presenta crisis hoy?", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Switch.adaptive(value: _brote, activeColor: Colors.red, onChanged: (v) => setState(() => _brote = v)),
        ],
      ),
    );
  }  Widget _buildAlergiasStepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepCircleLabel("1", "¿Presenta intolerancia a la lactosa?*"),
        const SizedBox(height: 16),
        Row(children: [
          _lactoseCard(true, "Sí, restricción activa", "El paciente presenta intolerancia a la lactosa."),
          const SizedBox(width: 20),
          _lactoseCard(false, "No detectada", "No se ha detectado intolerancia a la lactosa."),
        ]),
        const SizedBox(height: 24),
        _stepCircleLabel("2", "Otras restricciones clínicas"),
        const SizedBox(height: 8),
        Text("Seleccione las condiciones que aplican al paciente.", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final sorted = _restriccionesAlimentariasCat
                .where((r) => (r['codigo'] ?? '').toString() != "INTOLERANCIA_LACTOSA")
                .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
                .toList()
              ..sort((a, b) => _norm(a['nombre']).toLowerCase().compareTo(_norm(b['nombre']).toLowerCase()));
            final width = (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: sorted.map<Widget>((r) {
                final String code = r['codigo'];
                final bool isSel = _restriccionesAlimentarias.contains(code);
                return SizedBox(width: width, child: _restrictionChip(_norm(r['nombre']), code, isSel));
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
          title: Text("Tiene alergias a grupos alimentarios", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
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
          title: Text("Tiene alergias a ingredientes específicos", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
        ),
        if (_tieneAlergiaIng)
          _buildMultiSelector(
            title: "",
            subtitle: "",
            enabled: _tieneAlergiaIng,
            items: _ingredientes.map((i) => Map<String, dynamic>.from(i)).toList(),
            selectedIds: _selectedIngredientes.map((e) => (e['id'] as num).toInt()).toList(),
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
                final idx = _selectedIngredientes.indexWhere((e) => e['id'] == id);
                if (idx >= 0) {
                  _selectedIngredientes.removeAt(idx);
                } else {
                  final item = _ingredientes.cast<Map<String, dynamic>?>().firstWhere(
                    (e) => e != null && (e['id'] as num?)?.toInt() == id,
                    orElse: () => null,
                  );
                  if (item != null) {
                    final idSub = (item['id_subgrupo_alimentario'] as num?)?.toInt() ?? (item['id_subgrupo'] as num?)?.toInt();
                    if (_ingredientesBloqueados.contains(id)) return;
                    if (idSub != null && _subgruposBloqueados.contains(idSub)) return;
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade900),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _selectedIngredientes.removeWhere((e) => (e['id'] as num?)?.toInt() == id)),
                      child: Icon(Icons.close_rounded, size: 14, color: Colors.red.shade800),
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
      final raw = r['ids_subgrupos'] ?? r['subgrupos_ids'] ?? r['id_subgrupos'] ?? r['subgrupos'];
      if (raw is List) {
        for (final v in raw) {
          final id = (v is Map) ? (v['id'] as num?)?.toInt() : (v as num?)?.toInt();
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
      final raw = r['ids_ingredientes'] ?? r['ingredientes_ids'] ?? r['id_ingredientes'] ?? r['ingredientes'];
      if (raw is List) {
        for (final v in raw) {
          final id = (v is Map) ? (v['id'] as num?)?.toInt() : (v as num?)?.toInt();
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
      final idSub = (e['id_subgrupo_alimentario'] as num?)?.toInt() ?? (e['id_subgrupo'] as num?)?.toInt();
      if (!isIngredientes && blockedIds.contains(id)) return true;
      if (isIngredientes && blockedIngredientIds.contains(id)) return false;
      if (isIngredientes && idSub != null && blockedIds.contains(idSub)) return false;
      if (!showSearch || q.isEmpty) return true;
      final name = _norm(e['nombre']).toLowerCase();
      final syns = (e['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
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
                Text(title, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
                const SizedBox(height: 4),
              ],
              if (subtitle.trim().isNotEmpty) ...[
                Text(subtitle, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.blueGrey)),
                const SizedBox(height: 10),
              ],
              if (showSearch) ...[
                TextField(
                  controller: searchCtrl,
                  focusNode: focusNode,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: q.isEmpty ? (isIngredientes ? "Buscar ingrediente..." : "Filtrar subgrupo...") : "Filtrando: $q",
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: q.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () { searchCtrl.clear(); setState(() {}); }) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              if (showSearch && isIngredientes && onMarkAll != null && q.isNotEmpty && filtered.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onMarkAll(filtered),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: Text("Marcar ${filtered.length}", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            Text(_emojiSubgrupo(id), style: TextStyle(fontSize: 16, color: locked ? Colors.grey : null)),
                            const SizedBox(width: 8),
                            Text(
                              name,
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: locked ? Colors.grey : (isSel ? AppTema.verdeSalud : AppTema.azulOscuro),
                              ),
                            ),
                            if (isSel) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.check_circle, size: 14, color: AppTema.verdeSalud),
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
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final id = (item['id'] as num?)?.toInt() ?? -1;
                      final idSub = (item['id_subgrupo_alimentario'] as num?)?.toInt() ?? (item['id_subgrupo'] as num?)?.toInt();
                      final locked = isIngredientes && (blockedIngredientIds.contains(id) || (idSub != null && blockedIds.contains(idSub)));
                      final isSel = selectedIds.contains(id);
                      return ListTile(
                        dense: true,
                        enabled: !locked,
                        title: Text(
                          _norm(item['nombre']),
                          style: GoogleFonts.montserrat(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: locked ? Colors.grey : AppTema.azulOscuro),
                        ),
                        subtitle: locked ? Text("Bloqueado por intolerancia/restricción", style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey)) : null,
                        trailing: isSel
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                            : Icon(locked ? Icons.block : Icons.add_circle_outline, size: 18, color: locked ? Colors.grey : Colors.blueGrey),
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

  String _emojiSubgrupo(int id) {
    switch (id) {
      case 13: return "🥬";
      case 17: return "🍎";
      case 25: return "🍗";
      case 33: return "🐟";
      case 34: return "🐠";
      case 35: return "🐟";
      case 37: return "🧂";
      case 49: return "🥤";
      case 53: return "🧃";
      case 98: return "🥛";
      case 100: return "🥣";
      case 101: return "🧈";
      case 104: return "🥛";
      case 105: return "🥛";
      case 108: return "🧀";
      case 109: return "🥓";
      case 110: return "🌭";
      default: return "🍽️";
    }
  }

  void _autoBloquearDerivados(String nombre) {
    final n = nombre.toLowerCase().trim();
    if (n.length < 3) return;
    final stopWords = {'de', 'con', 'en', 'el', 'la', 'los', 'las', 'un', 'una', 'para', 'sin', 'y', 'del'};
    final words = n.split(' ').where((w) => w.length > 2 && !stopWords.contains(w)).toList();
    if (words.isEmpty && n.isNotEmpty) words.add(n);
    for (final raw in _ingredientes) {
      final i = Map<String, dynamic>.from(raw);
      final iname = (i['nombre'] ?? "").toString().toLowerCase();
      if (iname == n) continue;
      final syns = (i['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
      bool matches = words.any((w) => iname.contains(w));
      if (!matches) {
        matches = syns.any((s) => words.any((w) => s.contains(w)));
      }
      if (!matches) continue;
      final id = (i['id'] as num?)?.toInt();
      if (id == null) continue;
      if (_selectedIngredientes.any((x) => x['id'] == id)) continue;
      final idSub = (i['id_subgrupo_alimentario'] as num?)?.toInt() ?? (i['id_subgrupo'] as num?)?.toInt();
      if (idSub != null && _subgruposBloqueados.contains(idSub)) continue;
      _selectedIngredientes.add(i);
    }
  }
  Widget _stepCircleLabel(String num, String text) => Row(children: [
    Container(width: 24, height: 24, decoration: const BoxDecoration(color: greenBrand, shape: BoxShape.circle), child: Center(child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
    const SizedBox(width: 12),
    Text(text, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
  ]);

  Widget _lactoseCard(bool val, String title, String desc) {
    final bool sel = _lactosa == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _lactosa = val;
          if (val) _restriccionesAlimentarias.add("INTOLERANCIA_LACTOSA");
          else _restriccionesAlimentarias.remove("INTOLERANCIA_LACTOSA");
        }),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sel ? (val ? Colors.green.shade50 : Colors.white) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? greenBrand : Colors.grey.shade200, width: sel ? 2 : 1),
            boxShadow: [if (sel) BoxShadow(color: greenBrand.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: sel ? greenBrand : Colors.grey.shade400, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? greenBrand : AppTema.azulOscuro)),
                    const SizedBox(height: 4),
                    Text(desc, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
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
    if (code.contains("GLUTEN")) icon = Icons.grain_outlined;
    else if (code.contains("FRUCTOSA")) icon = Icons.apple_outlined;
    else if (code.contains("HISTAMINA")) icon = Icons.science_outlined;
    else if (code.contains("HUEVO")) icon = Icons.egg_outlined;
    else if (code.contains("SOYA")) icon = Icons.spa_outlined;
    else if (code.contains("FRUTOS")) icon = Icons.bakery_dining_outlined;
    else if (code.contains("PESCADO")) icon = Icons.set_meal_outlined;
    else if (code.contains("DIABETES")) icon = Icons.monitor_heart_outlined;
    else if (code.contains("VEGETARIANA")) icon = Icons.eco_outlined;
    else if (code.contains("SULFITOS")) icon = Icons.biotech_outlined;
    else if (code.contains("SORBITOL")) icon = Icons.icecream_outlined;

    return InkWell(
      onTap: () => setState(() => isSel ? _restriccionesAlimentarias.remove(code) : _restriccionesAlimentarias.add(code)),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSel ? AppTema.verdeSalud.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSel ? AppTema.verdeSalud : Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSel ? AppTema.verdeSalud : Colors.blueGrey),
            const SizedBox(width: 10),
            Text(name, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? AppTema.verdeSalud : Colors.blueGrey)),
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
    final ordenadas = [..._condicionesTemporalesCat]
      ..sort((a, b) => (a['nombre'] ?? '').toString().toLowerCase().compareTo((b['nombre'] ?? '').toString().toLowerCase()));
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: ordenadas.map<Widget>((c) {
            final id = c['id'] as int;
            final index = _condicionesTemp.indexWhere((s) => s['id'] == id);
            final sel = index != -1;
            final duracionSugerida = (c['duracion_dias_sugerida'] ?? c['dias_duracion_estandar'] ?? 7) as int;
            return Container(
              width: (constraints.maxWidth - 40) / 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sel ? greenBrand.withOpacity(0.3) : const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                key: Key("temp_patient_$id"),
                initiallyExpanded: sel,
                shape: const Border(),
                leading: Checkbox(
                  activeColor: greenBrand,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  value: sel,
                  onChanged: (v) async {
                    if (v == true) {
                      final ini = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (ini != null) {
                        setState(() => _condicionesTemp.add({
                          "id": id,
                          "nombre": c['nombre'],
                          "fecha_inicio": ini.toIso8601String().split('T')[0],
                          "fecha_fin": ini.add(Duration(days: duracionSugerida)).toIso8601String().split('T')[0],
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
                  sel ? "Activa por $duracionSugerida días" : "Sugerencia: $duracionSugerida días",
                  style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B)),
                ),
                children: sel
                    ? [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _buildTemporalDatesRow(index, duracionSugerida),
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
    final inicio = _condicionesTemp[index]['fecha_inicio']?.toString() ?? DateTime.now().toIso8601String().split('T')[0];
    final fin = _condicionesTemp[index]['fecha_fin']?.toString() ?? DateTime.now().add(Duration(days: duracionSugerida)).toIso8601String().split('T')[0];
    final finDate = DateTime.tryParse(fin) ?? DateTime.now();
    final restantes = finDate.difference(DateTime.now()).inDays;
    final diasRestantes = restantes < 0 ? 0 : restantes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text("Quedan $diasRestantes días", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _datePickerSmall(
                "Inicio",
                inicio,
                (d) => setState(() {
                  _condicionesTemp[index]['fecha_inicio'] = d.toIso8601String().split('T')[0];
                  _condicionesTemp[index]['fecha_fin'] = d.add(Duration(days: duracionSugerida)).toIso8601String().split('T')[0];
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

  Widget _datePickerSmall(String l, String v, Function(DateTime) onP) => InkWell(
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
          const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$l: ${DateFormat('dd/MM/yyyy', 'es').format(DateTime.tryParse(v) ?? DateTime.now())}",
              style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
            ),
          ),
          const Icon(Icons.expand_more_rounded, size: 18, color: Color(0xFF64748B)),
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
        const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "$l: ${DateFormat('dd/MM/yyyy', 'es').format(DateTime.tryParse(v) ?? DateTime.now())}",
            style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
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
        StatefulBuilder(
          builder: (context, setInternalState) {
            final q = _ingRecomSearchCtrl.text.toLowerCase().trim();
            final matches = _ingredientes.where((e) {
              if (q.isEmpty) return false;
              final name = _norm(e['nombre']).toLowerCase();
              final syns = (e['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
              return name.contains(q) || syns.any((s) => s.contains(q));
            }).toList();
            return Column(
              children: [
                TextField(
                  controller: _ingRecomSearchCtrl,
                  focusNode: _ingRecomFocus,
                  onChanged: (_) => setInternalState(() {}),
                  decoration: InputDecoration(
                    labelText: "Buscar ingrediente recomendado",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _ingRecomSearchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _ingRecomSearchCtrl.clear();
                              setInternalState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                if (matches.isNotEmpty && _ingRecomFocus.hasFocus)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: min(matches.length, 60),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = matches[i];
                        final isSel = _recomendacionesIng.any((ing) => ing['id'] == item['id']);
                        return ListTile(
                          dense: true,
                          title: Text(item['nombre'] ?? ""),
                          trailing: Icon(isSel ? Icons.check_circle : Icons.add_circle_outline, color: isSel ? Colors.green : null),
                          onTap: () {
                            setState(() {
                              if (!isSel) {
                                _recomendacionesIng.add(Map<String, dynamic>.from(item));
                                _autoRecomendarDerivados(item['nombre'] ?? "");
                              } else {
                                _recomendacionesIng.removeWhere((ing) => ing['id'] == item['id']);
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
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recomendacionesIng
              .map((e) => Chip(
                    label: Text(
                      e['nombre'] ?? "",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    onDeleted: () => setState(() => _recomendacionesIng.remove(e)),
                    backgroundColor: Colors.blue.shade50,
                    deleteIconColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildProfessionalPrediagnosis() => Container(
    padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: _omsColor.withOpacity(0.06), borderRadius: BorderRadius.circular(24), border: Border.all(color: _omsColor.withOpacity(0.2), width: 2)), 
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Icon(Icons.analytics_rounded, color: _omsColor, size: 22), const SizedBox(width: 12), Text("DIAGNÓSTICO NUTRICIONAL OMS", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF475569)))]),
        if (_calculandoOMS) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: greenBrand))
        else IconButton(onPressed: _calculateOMS, icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.blueGrey))
      ]),
      const SizedBox(height: 24),
      Text("${_omsStatusPeso.toUpperCase()} / ${_omsStatusTalla.toUpperCase()}", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _metricPill("Peso ideal", _pesoMediana > 0 ? "${_pesoMediana.toStringAsFixed(1)} kg" : "-"),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricPill("Talla ideal", _tallaMediana > 0 ? "${_tallaMediana.toStringAsFixed(1)} cm" : "-"),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _metricPill("Peso actual vs ideal", "${_gananciaPeso.toStringAsFixed(1)} kg"),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricPill("Talla actual vs ideal", "${_gananciaTalla.toStringAsFixed(1)} cm"),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _omsColor.withOpacity(0.2)),
        ),
        child: Text(
          _buildClinicalSummaryText(),
          style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155), height: 1.4),
        ),
      ),
    ])
  );

  String _buildClinicalSummaryText() {
    final stPeso = _omsStatusPeso.toLowerCase();
    final stTalla = _omsStatusTalla.toLowerCase();
    String pesoTxt;
    String tallaTxt;
    final deltaPeso = _gananciaPeso.abs().toStringAsFixed(1);
    final deltaTalla = _gananciaTalla.abs().toStringAsFixed(1);

    if (_gananciaPeso > 0.1 || stPeso.contains('bajo') || stPeso.contains('delgadez') || stPeso.contains('desnut')) {
      pesoTxt = "Se recomienda subir aproximadamente $deltaPeso kg.";
    } else if (stPeso.contains('sobrepeso') || stPeso.contains('obesidad') || stPeso.contains('alto')) {
      pesoTxt = "Se recomienda bajar aproximadamente $deltaPeso kg.";
    } else {
      pesoTxt = "El peso está dentro de lo esperado para su edad.";
    }

    if (_gananciaTalla > 0.1 || stTalla.contains('baja') || stTalla.contains('retraso')) {
      tallaTxt = "Debe crecer aproximadamente $deltaTalla cm para alcanzar la talla esperada.";
    } else if (stTalla.contains('alta') || stTalla.contains('elevada')) {
      tallaTxt = "La talla está por encima de lo esperado para su edad.";
    } else {
      tallaTxt = "La talla está dentro de lo esperado para su edad.";
    }

    final extra = _resumenClinico.trim().isNotEmpty ? " ${_resumenClinico.trim()}" : "";
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
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
      ],
    ),
  );

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
        } else { setState(() { _tutorNoEncontrado = true; }); }
      }
    } catch (_) {} finally { if (mounted) setState(() => _buscandoTutor = false); } 
  }

  Future<void> _pickFechaNac() async { 
    final d = await showDatePicker(
      context: context,
      initialDate: _pacFechaNac ?? DateTime(2015),
      firstDate: DateTime(2005),
      lastDate: DateTime.now(),
      helpText: "Seleccione la fecha de nacimiento",
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: greenBrand)),
        child: child!,
      ),
    ); 
    if (d != null) { setState(() => _pacFechaNac = d); _calculateOMS(); } 
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

  Widget _field(TextEditingController c, String l, IconData i, {int maxLines = 1, Function(String)? onChanged, bool enabled = true, String? helper, String? hint}) => TextFormField(
    controller: c, 
    maxLines: maxLines, 
    enabled: enabled, 
    onChanged: onChanged, 
    style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
    decoration: InputDecoration(
      labelText: l, 
      prefixIcon: Icon(i, size: 20, color: const Color(0xFF334155)), 
      helperText: helper, 
      hintText: hint,
      hintStyle: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
      floatingLabelBehavior: FloatingLabelBehavior.always
    )
  );

  Widget _dropdown(String l, List items, int? val, Function(int?) onC, {String? hint}) => DropdownButtonFormField<int>(
    value: val, 
    isExpanded: true,
    hint: hint != null ? Text(hint, style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w500)) : null,
    items: items.map((e) => DropdownMenuItem<int>(
      value: e['id'], 
      child: Text(_norm(e['nombre'] ?? e['descripcion'] ?? ""), 
        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))
    )).toList(), 
    onChanged: onC, 
    decoration: InputDecoration(labelText: l)
  );

  Widget _buildControls(ControlsDetails d) => Padding(padding: const EdgeInsets.only(top: 56), child: Row(children: [
    Expanded(
      child: FilledButton(
        onPressed: d.onStepContinue, 
        style: FilledButton.styleFrom(
          backgroundColor: greenBrand, 
          padding: const EdgeInsets.symmetric(vertical: 24), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
        ), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_currentStep == (widget.fixedOnly ? 1 : 2) ? (_idPacienteEditando == null ? "REGISTRAR PACIENTE" : "GUARDAR CAMBIOS") : "SIGUIENTE PASO", 
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (_currentStep < (widget.fixedOnly ? 1 : 2)) ...[
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ]
          ],
        )
      )
    ), 
    if (_currentStep > 0) ...[
      const SizedBox(width: 20), 
      Expanded(
        child: OutlinedButton(
          onPressed: d.onStepCancel, 
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: greenBrand, width: 2), 
            foregroundColor: greenBrand, 
            padding: const EdgeInsets.symmetric(vertical: 24), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
          ), 
          child: const Text("REGRESAR", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))
        )
      )
    ]
  ]));

  Widget _sectionHeader(String t, IconData i) => Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: greenBrand.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(i, size: 20, color: greenBrand)), const SizedBox(width: 18), Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0F172A), letterSpacing: 0.8))]);
}








