// ignore_for_file: deprecated_member_use, unused_field, unused_element, no_leading_underscores_for_local_identifiers, curly_braces_in_flow_control_structures, prefer_const_constructors, prefer_const_literals_to_create_immutables, unnecessary_brace_in_string_interps, unnecessary_string_interpolations

import "dart:async";
import "dart:math";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";
import "package:fl_chart/fl_chart.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/patient_summary_panel.dart";
import "../../../shared/widgets/layout_components.dart";
import "../data/repositorio_medico.dart";
import "../data/supervision_provider.dart";
import "_shared/medico_nav_providers.dart";
import '../../../shared/widgets/role_shell.dart';
import '../../../shared/widgets/custom_date_picker.dart';

import '../../../shared/widgets/escalas/escala_selector.dart';

class _HeatLabel extends StatelessWidget {
  const _HeatLabel(this.text, this.icon, this.iconColor);

  final String text;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegistroMensualPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> paciente;
  const RegistroMensualPage({super.key, required this.paciente});

  @override
  ConsumerState<RegistroMensualPage> createState() =>
      _RegistroMensualPageState();
}

class _RegistroMensualPageState extends ConsumerState<RegistroMensualPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeMonitorIndex = 0;
  bool _loading = false;
  bool _yaEvaluadoHoy = false;
  bool _controlMensualYaHecho = false;
  bool _controlMensualHabilitado = false;
  String _mensajeControlMensual = "";
  int _diasRestantesParaControl = 0;
  DateTime? _fechaProgramadaControl;
  Map<String, dynamic>? _expediente;
  Map<String, dynamic>? _evolucionMensual;
  Map<String, dynamic>? _controlSeleccionadoEvo;
  Map<String, dynamic>? _consumoAlimentario;
  String? _idControlEditando;
  Timer? _debounceOMS;
  final ScrollController _heatmapScrollCtrl = ScrollController();

  static const Color greenBrand = Color(0xFF2E7D32);

  final _peso = TextEditingController();
  final _talla = TextEditingController();
  final _pcr = TextEditingController();
  final _vsg = TextEditingController();
  final _artInflam = TextEditingController(text: "0");
  final _artDolor = TextEditingController(text: "0");
  final _rigidez = TextEditingController();
  final _notas = TextEditingController();

  double _dolor = 0;
  double _inflamacion = 0;
  double _fatiga = 10;
  bool _brote = false;
  bool _lactosa = false;
  List<String> _restriccionesAlimentarias = [];
  List<Map<String, dynamic>> _alergiasSubgrupos = [];
  List<Map<String, dynamic>> _alergiasIngredientes = [];
  int? _idPatologiaBase;
  String _estadoEnfermedad = "Seguimiento";
  final List<String> _estadosClinicos = [
    "Estable en remisión",
    "Estable con actividad baja",
    "Activa moderada",
    "Activa grave (alta actividad)",
    "Seguimiento"
  ];

  DateTime _proximaCita = DateTime.now().add(const Duration(days: 30));
  late TextEditingController _proximaCitaCtrl;
  final List<Map<String, dynamic>> _condicionesTemp = [];
  List<Map<String, dynamic>> _recomendacionesIng = [];
  List<dynamic> _condicionesTemporalesCat = [];
  List<dynamic> _patologiasCat = [];
  List<dynamic> _ingredientesCat = [];
  List<dynamic> _subgruposCat = [];
  List<dynamic> _restriccionesAlimentariasCat = [];
  String _foodPlanFilter = "todo";
  String _foodMomentFilter = "todo";
  String _foodStateFilter = "todo";
  int _foodPage = 1;
  String _evoRango = "12";
  String _evoEstadoEnfermedad = "todo";
  String _evoBrote = "todos";
  String _evoEstadoNutricional = "todo";
  bool _evoSoloAlterados = false;

  final _ingRecomSearchCtrl = TextEditingController();
  final _ingRecomFocus = FocusNode();

  final _subgrupoSearchCtrl = TextEditingController();
  final _subgrupoFocus = FocusNode();

  final _ingredienteAlergiaSearchCtrl = TextEditingController();
  final _ingredienteAlergiaFocus = FocusNode();

  String _omsStatusPeso = "PENDIENTE";
  String _omsStatusTalla = "PENDIENTE";
  String _resumenClinico = "";
  double _gananciaPeso = 0;
  double _gananciaTalla = 0;
  String _estadoPeso = "mantener";
  double _pesoIdeal = 0;
  double _tallaIdeal = 0;
  bool _calculandoOMS = false;
  Color _omsColor = Colors.grey.shade400;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(menuExpandedProvider.notifier).state = false;
      }
    });
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _proximaCitaCtrl = TextEditingController(text: DateFormat('dd/MM/yyyy', 'es').format(_proximaCita));
    _cargarExpediente();
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    try {
      final dio = ref.read(dioProvider);

      final results = await Future.wait([
        dio.get("catalogos/condiciones"),
        dio.get("registro/paciente-integral/catalogos"),
        dio.get("nutricionista/ingredientes/catalogo-simple"),
        dio.get("nutricionista/subgrupos/catalogo-simple"),
      ]);

      if (mounted) {
        setState(() {
          final allCond = results[0].data as List;
          _condicionesTemporalesCat = allCond
              .where((e) => (e['id_tipo'] ?? e['id_tipo_condicion']) == 2)
              .toList();
          _patologiasCat = allCond
              .where((e) => (e['id_tipo'] ?? e['id_tipo_condicion']) == 1)
              .toList();
          _restriccionesAlimentariasCat = (results[1].data
                      as Map<String, dynamic>)["restricciones_alimentarias"]
                  as List? ??
              [];
          _ingredientesCat = results[2].data as List? ?? [];
          _subgruposCat = results[3].data as List? ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error cargando catálogo: $e");
    }
  }

  @override
  void dispose() {
    _proximaCitaCtrl.dispose();
    _tabController.dispose();
    _debounceOMS?.cancel();
    _heatmapScrollCtrl.dispose();
    _ingRecomSearchCtrl.dispose();
    _ingRecomFocus.dispose();
    _subgrupoSearchCtrl.dispose();
    _subgrupoFocus.dispose();
    _ingredienteAlergiaSearchCtrl.dispose();
    _ingredienteAlergiaFocus.dispose();
    _peso.dispose();
    _talla.dispose();
    _pcr.dispose();
    _vsg.dispose();
    _artInflam.dispose();
    _artDolor.dispose();
    _rigidez.dispose();
    _notas.dispose();
    super.dispose();
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

  Future<void> _cargarExpediente() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final patientIdStr = widget.paciente['id'].toString();
      final response =
await dio.get("pacientes/$patientIdStr/expediente-completo");
      final data = Map<String, dynamic>.from(response.data as Map);

      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final historial = data['historial_controles'] as List? ?? [];
      final evaluadoHoy = historial.any((c) => c['fecha_control'] == hoy);
      final estadoControlBackend = data['estado_control_mensual'];
      final estadoControlLocal = _evaluarEstadoControlMensual(historial);
      
      final bool yaHecho = (estadoControlBackend is Map && estadoControlBackend['ya_hecho'] != null)
          ? estadoControlBackend['ya_hecho'] == true
          : estadoControlLocal['ya_hecho'] == true;
          
      final bool habilitado = (estadoControlBackend is Map && estadoControlBackend['habilitado'] != null)
          ? estadoControlBackend['habilitado'] == true
          : estadoControlLocal['habilitado'] == true;

      String mensaje = (estadoControlBackend is Map && estadoControlBackend['mensaje'] != null && estadoControlBackend['mensaje'].toString().isNotEmpty)
          ? estadoControlBackend['mensaje'].toString()
          : "";
      if (mensaje.isEmpty) {
        final diff = estadoControlLocal['diff'] as int? ?? 0;
        final diffAbs = diff.abs();
        final fechaFormateada = estadoControlLocal['fecha_formateada'] as String? ?? "";
        if (yaHecho) {
          mensaje = "Su registro ya fue realizado. Su próximo control es en $diffAbs ${diffAbs == 1 ? 'día' : 'días'} ($fechaFormateada).";
        } else if (habilitado) {
          mensaje = "Control mensual habilitado para registro.";
        } else {
          mensaje = "Aún no corresponde el control mensual. Su próximo control es en $diffAbs ${diffAbs == 1 ? 'día' : 'días'} ($fechaFormateada).";
        }
      }

      final diff = estadoControlLocal['diff'] as int? ?? 0;
      final referencia = estadoControlLocal['referencia'] as DateTime?;

      final ultimoControl = (data['ultimo_control'] is Map)
          ? Map<String, dynamic>.from(data['ultimo_control'] as Map)
          : <String, dynamic>{};

      setState(() {
        _expediente = data;
        _yaEvaluadoHoy = evaluadoHoy;
        _controlMensualYaHecho = yaHecho;
        _controlMensualHabilitado = habilitado;
        _mensajeControlMensual = mensaje;
        _diasRestantesParaControl = diff;
        _fechaProgramadaControl = referencia;
        _idPatologiaBase = data['diagnostico']?['id_condicion'];

        final al = data['alergias'] ?? {};
        _alergiasSubgrupos =
            List<Map<String, dynamic>>.from(al['subgrupos'] ?? []);
        _alergiasIngredientes =
            List<Map<String, dynamic>>.from(al['ingredientes'] ?? []);
        _restriccionesAlimentarias =
            List<String>.from(al['restricciones_codigos'] ?? []);
        _lactosa = _restriccionesAlimentarias.contains("INTOLERANCIA_LACTOSA");

        _loading = false;
      });
      unawaited(_cargarAnalitica(patientIdStr));
    } catch (e) {
      debugPrint("Error general en _cargarExpediente: $e");
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cargarAnalitica(String patientId) async {
    final repo = ref.read(repositorioMedicoProvider);
    final results = await Future.wait([
      repo.obtenerConsumoAlimentario(patientId, dias: 180).catchError((e) {
        debugPrint("Error cargando consumo alimentario: $e");
        return <String, dynamic>{};
      }),
      repo.obtenerEvolucionMensual(patientId).catchError((e) {
        debugPrint("Error cargando evolución mensual: $e");
        return <String, dynamic>{};
      }),
    ]);
    if (!mounted || widget.paciente['id'].toString() != patientId) return;

    final consumo = results[0];
    final evolucion = results[1];
    final controles = List<Map<String, dynamic>>.from(
        (evolucion['controles'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    setState(() {
      _consumoAlimentario = consumo.isEmpty ? null : consumo;
      _evolucionMensual = evolucion.isEmpty ? null : evolucion;
      _controlSeleccionadoEvo = controles.isNotEmpty ? controles.last : null;
    });
  }

  Map<String, dynamic> _evaluarEstadoControlMensual(List historial) {
    final ahora = DateTime.now();
    DateTime? ultimaFechaControl;
    DateTime? fechaProgramada;
    bool hechoEnMesActual = false;

    for (final raw in historial) {
      final row =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final fechaControl =
          DateTime.tryParse((row['fecha_control'] ?? '').toString());
      if (fechaControl == null) continue;
      if (ultimaFechaControl == null ||
          fechaControl.isAfter(ultimaFechaControl)) {
        ultimaFechaControl = fechaControl;
        fechaProgramada =
            DateTime.tryParse((row['fecha_proxima_cita'] ?? '').toString());
      }
      if (fechaControl.year == ahora.year &&
          fechaControl.month == ahora.month) {
        hechoEnMesActual = true;
      }
    }

    final referenciaReal = fechaProgramada ??
        ultimaFechaControl?.add(const Duration(days: 30)) ??
        ahora;

    // Para pruebas: asumimos que la fecha programada de monitoreo siempre es hoy
    final referencia = ahora;
    final habilitado = !hechoEnMesActual;

    final referenciaCero = DateTime(referencia.year, referencia.month, referencia.day);
    final ahoraCero = DateTime(ahora.year, ahora.month, ahora.day);
    final diff = referenciaCero.difference(ahoraCero).inDays;
    final fechaFormateada = DateFormat('dd/MM/yyyy').format(referenciaReal);

    String mensaje = "";
    if (hechoEnMesActual) {
      mensaje = "El control del paciente es el $fechaFormateada";
    } else if (habilitado) {
      mensaje = "Control mensual habilitado para registro.";
    } else {
      mensaje = "El control del paciente es el $fechaFormateada";
    }

    return {
      'ya_hecho': hechoEnMesActual,
      'habilitado': habilitado,
      'mensaje': mensaje,
      'diff': diff,
      'fecha_formateada': fechaFormateada,
      'referencia': referencia,
    };
  }

  void _debouncedOMS() {
    _debounceOMS?.cancel();
    _debounceOMS = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _calculateOMS();
    });
  }

  Future<void> _calculateOMS() async {
    double p = double.tryParse(_peso.text) ?? 0;
    double t = double.tryParse(_talla.text) ?? 0;
    if (p < 1 || t < 30) return;

    final fnac = _expediente?['paciente']?['fecha_nacimiento'] ?? widget.paciente['fecha_nacimiento'];
    final idSexo = _expediente?['paciente']?['id_sexo'] ?? widget.paciente['id_sexo'];

    if (fnac == null || idSexo == null) return;

    setState(() => _calculandoOMS = true);
    try {
      final dio = ref.read(dioProvider);
      double asDouble(dynamic value, {double fallback = 0}) {
        if (value is num) return value.toDouble();
        return double.tryParse(value?.toString() ?? "") ?? fallback;
      }

      final fechaStr = fnac.toString().split("T").first;

      final res = await dio.post("pre-diagnostico-nutricional", data: {
        "id_paciente": widget.paciente['id'],
        "fecha_nacimiento": fechaStr,
        "id_sexo": int.tryParse(idSexo.toString()) ?? 1,
        "peso_kg": p,
        "talla_cm": t
      });

      if (mounted) {
        setState(() {
          _omsStatusPeso = res.data['diagnostico_nutri_texto'] ?? "Normal";
          _omsStatusTalla = res.data['diagnostico_talla_texto'] ?? "Adecuada";
          _resumenClinico = res.data['resumen_clinico'] ?? "";
          _gananciaPeso = asDouble(res.data['ganancia_peso_necesaria']);
          _gananciaTalla = asDouble(res.data['ganancia_talla_necesaria']);
          _estadoPeso = res.data['estado_peso'] ?? "mantener";
          _pesoIdeal = asDouble(res.data['peso_ideal']);
          _tallaIdeal = asDouble(res.data['talla_ideal']);

          final String combined = (res.data['diagnostico_combinado'] ??
                  "$_omsStatusPeso / $_omsStatusTalla")
              .toString()
              .toLowerCase();

          if (combined.contains("severa") ||
              combined.contains("emaciación") ||
              combined.contains("obesidad") ||
              combined.contains("desnutrición")) {
            _omsColor = Colors.red;
          } else if (combined.contains("sobrepeso") ||
              combined.contains("baja") ||
              combined.contains("delgadez") ||
              combined.contains("bajo peso") ||
              combined.contains("riesgo")) {
            _omsColor = Colors.orange;
          } else {
            _omsColor = greenBrand;
          }
          _calculandoOMS = false;
        });
      }
    } catch (e) {
      debugPrint("Error en pre-diagnóstico: $e");
      if (mounted) setState(() => _calculandoOMS = false);
    }
  }

  void _prepararEdicion(Map<String, dynamic> h) {
    double _asDouble(dynamic value, {double fallback = 0}) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? "") ?? fallback;
    }

    setState(() {
      _idControlEditando = h['id']?.toString();
      _peso.text = h['peso_kg']?.toString() ?? "";
      _talla.text = h['talla_cm']?.toString() ?? "";
      _artInflam.text = h['articulaciones_inflamadas']?.toString() ?? "0";
      _artDolor.text = h['articulaciones_dolorosas']?.toString() ?? "0";
      _rigidez.text = h['minutos_rigidez']?.toString() ?? "";
      _notas.text = h['nota_evolucion'] ?? "";
      _dolor = _asDouble(h['puntos_dolor']);
      _inflamacion = _asDouble(h['escala_inflamacion']);
      _fatiga = _asDouble(h['nivel_fatiga'], fallback: 10);
      _brote = h['en_brote'] ?? false;
      _estadoEnfermedad = h['estado_enfermedad'] ?? "Seguimiento";
      _proximaCita = DateTime.tryParse(h['fecha_proxima_cita'] ?? "") ??
          DateTime.now().add(const Duration(days: 30));
      _proximaCitaCtrl.text = DateFormat('dd/MM/yyyy', 'es').format(_proximaCita);

      if (_expediente != null && _expediente!['recomendaciones'] != null) {
        _recomendacionesIng = List<Map<String, dynamic>>.from(
            _expediente!['recomendaciones']['ingredientes'] ?? []);
      }
    });
    _calculateOMS();
    _tabController.animateTo(0);
  }

  Future<void> _guardarConsulta() async {
    if (_peso.text.isEmpty || _talla.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final validCodes = _restriccionesAlimentariasCat
          .map((e) => (e['codigo'] ?? '').toString())
          .where((c) => c.isNotEmpty)
          .toSet();
      final sanitizedRestricciones = _restriccionesAlimentarias
          .where(validCodes.contains)
          .toSet()
          .toList();
      if (sanitizedRestricciones.length != _restriccionesAlimentarias.length &&
          mounted) {
        NutriSnack.show(
          context,
          "Se removieron restricciones no validas del catalogo actual.",
          ref: ref,
        );
      }
      final payload = {
        "peso_kg": _peso.text,
        "talla_cm": _talla.text,
        "puntos_dolor": _dolor.toInt(),
        "escala_inflamacion": _inflamacion.toInt(),
        "fatiga": _fatiga.toInt(),
        "articulaciones_inflamadas": _artInflam.text,
        "articulaciones_dolorosas": _artDolor.text,
        "minutos_rigidez": _rigidez.text,
        "en_brote": _brote,
        "estado_enfermedad": _estadoEnfermedad,
        "nota_evolucion": _notas.text,
        "fecha_proxima_cita": _proximaCita.toIso8601String().split("T").first,
        "condiciones_temporales": _condicionesTemp,
        "recomendaciones_ingredientes":
            _recomendacionesIng.map((e) => e['id']).toList(),
        "valor_pcr": _pcr.text,
        "valor_vsg": _vsg.text,

        // Nuevos campos de Alergias e Intolerancias (para actualizar record permanente)
        "alergias_subgrupos": _alergiasSubgrupos.map((e) => e['id']).toList(),
        "alergias_ingredientes":
            _alergiasIngredientes.map((e) => e['id']).toList(),
        "restricciones_alimentarias": sanitizedRestricciones,
        "es_intolerante_lactosa": _lactosa,
        if (_idControlEditando == null)
          "fecha_control": _diasRestantesParaControl == 0 && _fechaProgramadaControl != null
              ? _fechaProgramadaControl!.toIso8601String().split("T").first
              : DateFormat('yyyy-MM-dd').format(DateTime.now()),
      };
      if (_idControlEditando == null) {
        await dio.post("pacientes/${widget.paciente['id']}/control-mensual",
            data: payload);
      } else {
        if (_idControlEditando!.isEmpty) {
          throw Exception("No se pudo identificar el control a editar.");
        }
        await dio.put("pacientes/control-mensual/$_idControlEditando",
            data: payload);
      }
      if (mounted)
        NutriSnack.show(context,
            "Se han actualizado los campos de peso, talla y evaluación correctamente",
            ref: ref);

      ref.invalidate(medicalPatientsProvider);

      _limpiarForm();
      _cargarExpediente();
    } catch (e) {
      if (mounted)
        NutriSnack.show(context, "Error: $e", isError: true, ref: ref);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _limpiarForm() {
    _peso.clear();
    _talla.clear();
    _pcr.clear();
    _vsg.clear();
    _artInflam.text = "0";
    _artDolor.text = "0";
    _rigidez.clear();
    _notas.clear();
    setState(() {
      _dolor = 0;
      _inflamacion = 0;
      _fatiga = 10;
      _brote = false;
      _idControlEditando = null;
      _omsStatusPeso = "PENDIENTE";
    });
  }

  String _formatEdad(String? fechaNac) {
    if (fechaNac == null) return "-";
    try {
      final birthDate = DateTime.parse(fechaNac);
      final now = DateTime.now();
      int years = now.year - birthDate.year;
      int months = now.month - birthDate.month;
      if (now.day < birthDate.day) months--;
      if (months < 0) {
        years--;
        months += 12;
      }
      return "$years años y $months meses";
    } catch (_) {
      return "-";
    }
  }

  Widget _buildLeftSummary() {
    if (_expediente == null)
      return const SizedBox(
          width: 350, child: Center(child: CircularProgressIndicator()));

    return PatientSummaryPanel(
      expediente: _expediente!,
      formatEdad: _formatEdad,
      onVerExpediente: _mostrarExpedienteMaestroDialog,
      width: 350,
    );
  }

  void _mostrarExpedienteMaestroDialog() {
    if (_expediente == null) return;
    final p = _expediente!['paciente'] ?? {};
    final t = _expediente!['tutor'] ?? {};
    final d = _expediente!['diagnostico'] ?? {};
    final c = _expediente!['ultimo_control'] ?? {};
    final al = _expediente!['alergias'] ?? {};

    final idsLacteos = {98, 100, 101, 104, 105, 108, 111, 114, 117, 119};
    final bool esIntolerante = (al['subgrupos'] as List? ?? [])
        .any((a) => idsLacteos.contains(a['id']));

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: 1000,
          padding: const EdgeInsets.all(40),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.assignment_ind_outlined,
                      color: greenBrand, size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Expediente maestro integral",
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900, fontSize: 20)),
                      Text(
                          "Registro oficial del paciente y soporte legal en el sistema ReumaNutri",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close))
                ]),
                const Divider(height: 48),
                Flexible(
                  child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child:
                                _buildExpSection("1. Identidad del paciente", [
                           _expItem("Nombres completos", p['nombre_completo']),
                          _expItem("Cédula / ID", p['cedula']),
                          _expItem(
                              "Fecha de nacimiento", p['fecha_nacimiento']),
                           _expItem("Sexo biológico", p['sexo_nombre']),
                          const SizedBox(height: 16),
                          const Text("Localización",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                           _expItem("Cantón de residencia", p['canton_nombre']),
                          _expItem("Parroquia", p['parroquia_nombre']),
                        ])),
                        const SizedBox(width: 40),
                        Expanded(
                            child: _buildExpSection("2. Representante legal", [
                           _expItem("Nombre completo", t['nombre_completo']),
                           _expItem("Cédula del tutor", t['cedula']),
                          _expItem(
                              "Relación / Parentesco", t['parentesco_nombre'],
                              isBold: true),
                          const SizedBox(height: 16),
                          const Text("Datos de contacto",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                           _expItem("Correo electrónico", t['email']),
                          _expItem("Teléfono / Móvil", t['telefono']),
                           _expItem("Dirección domiciliaria", t['direccion']),
                        ])),
                        const SizedBox(width: 40),
                        Expanded(
                            child:
                                _buildExpSection("3. Estado clínico actual", [
                           _expItem("Enfermedad autoinmune",
                              d['condicion_nombre'] ?? "No registrada",
                              isHighlight: true),
                           _expItem("Estado nutricional (OMS)",
                              c['estado_nutricional'],
                              isBold: true),
                           _expItem("Relación peso / talla / IMC",
                              "${c['peso_kg'] ?? '-'} kg / ${c['talla_cm'] ?? '-'} cm / ${c['imc_calculado'] ?? '-'}"),
                           _expItem("Actividad clínica",
                              "Dolor ${c['puntos_dolor'] ?? '-'} | Inflamación ${c['escala_inflamacion'] ?? '-'} | Fatiga ${c['nivel_fatiga'] ?? '-'} | Rigidez ${c['minutos_rigidez'] ?? '-'} min"),
                           _expItem("Estado de enfermedad",
                              c['estado_enfermedad'] ?? "Seguimiento"),
                          const SizedBox(height: 16),
                          const Text("Seguridad alimentaria",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.orange,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          _expItem(
                              "Intolerancia a lactosa",
                              esIntolerante
                                  ? "Sí (restricción activa)"
                                  : "No detectada",
                              isAlert: esIntolerante),
                          _expItem(
                              "Alergias a subgrupos",
                              (al['subgrupos'] as List? ?? [])
                                      .map((e) => e['nombre'])
                                      .join(", ")
                                      .isEmpty
                                  ? "Ninguna"
                                  : (al['subgrupos'] as List? ?? [])
                                      .map((e) => e['nombre'])
                                      .join(", ")),
                          _expItem(
                              "Alergias a ingredientes",
                              (al['ingredientes'] as List? ?? [])
                                      .map((e) => e['nombre'])
                                      .join(", ")
                                      .isEmpty
                                  ? "Ninguna"
                                  : (al['ingredientes'] as List? ?? [])
                                      .map((e) => e['nombre'])
                                      .join(", ")),
                          _expItem(
                              "Restricciones médicas",
                              (_expediente!['restricciones_alimentarias_detalle']
                                              as List? ??
                                          [])
                                      .map((r) => r['nombre'])
                                      .join(", ")
                                      .isEmpty
                                  ? "Ninguna"
                                  : (_expediente!['restricciones_alimentarias_detalle']
                                              as List? ??
                                          [])
                                      .map((r) => r['nombre'])
                                      .join(", ")),
                          const SizedBox(height: 16),
                          const Text("Próximos eventos",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                           _expItem("Último registro", c['fecha_control']),
                           _expItem("Cita programada", c['fecha_proxima_cita'],
                              isHighlight: true),
                          _expItem(
                              "Controles registrados",
                              (_expediente!['historial_controles'] as List? ??
                                      [])
                                  .length
                                  .toString()),
                        ])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Row(children: [
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("Cerrar expediente maestro"),
                          style: FilledButton.styleFrom(
                              backgroundColor: greenBrand,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20)))),
                ])
              ]),
        ),
      ),
    );
  }

  Widget _buildExpSection(String title, List<Widget> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: greenBrand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  color: greenBrand,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(height: 24),
        ...items
      ]);

  Widget _expItem(String l, dynamic v,
          {bool isBold = false,
          bool isAlert = false,
          bool isHighlight = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2)),
            const SizedBox(height: 4),
            Text(v?.toString() ?? "No registrado",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight:
                      (isBold || isAlert) ? FontWeight.w900 : FontWeight.w600,
                  color: isAlert
                      ? Colors.red
                      : (isHighlight ? greenBrand : const Color(0xFF1E293B)),
                ))
          ]));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Stack(
        children: [
          Container(color: const Color(0xFFF8FAFC)), // background
          _buildLoadingOverlay(),
        ],
      );
    }
    
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTema.grisLienzo,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLeftSummary(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(),
                      _tabController.index == 0
                          ? _buildFormTab(isNested: true)
                          : _buildHistoryTab(isNested: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16)
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTema.azulPrincipal),
              const SizedBox(height: 16),
              Text("Cargando control mensual...", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))
            ]
          )
        )
      )
    );
  }

  Widget _buildTopBar() {
    return Column(
      children: [
        _buildHeaderBar(),
        _buildTabBar(),
      ],
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  ref.read(medicoNavProvider.notifier).goBackToList();
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
                "Control mensual del paciente",
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
              "Formulario para registrar o editar el control mensual, evolución, datos antropométricos y estado nutricional del paciente.",
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
                    ref.read(medicoNavProvider.notifier).goBackToList();
                  },
                  child: Text("Gestión de Pacientes", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, decoration: TextDecoration.none)) 
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                ),
                Text("Control Mensual", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            )
          ),
        ],
      )
    );
  }

  Widget _buildTabBar() => Container(
      height: 60,
      color: Colors.white,
      child: TabBar(
          controller: _tabController,
          labelColor: greenBrand,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(width: 4, color: greenBrand),
              insets: EdgeInsets.symmetric(horizontal: 60)),
          labelStyle: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          tabs: const [
            Tab(text: "Registro clínico"),
            Tab(text: "Monitor de evolución")
          ]));

  Widget _buildFormTab({bool isNested = false}) {
    final bloqueado = !_controlMensualHabilitado && _idControlEditando == null;
    Widget content;
    if (bloqueado) {
      content = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 10),
            )
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (_controlMensualYaHecho ? AppTema.azulPrincipal : Colors.orange).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _controlMensualYaHecho
                    ? Icons.check_circle_rounded
                    : Icons.lock_outline_rounded,
                color: _controlMensualYaHecho ? AppTema.azulPrincipal : Colors.orange.shade700,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _mensajeControlMensual.isNotEmpty
                  ? _mensajeControlMensual
                  : "Aún no corresponde el control mensual",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _controlMensualYaHecho
                    ? "Si necesitas corregir la información del control actual, por favor dirígete al monitor de evolución y edita el registro correspondiente."
                    : "La ventana de registro se habilitará automáticamente cuando se cumpla la fecha programada para el siguiente control mensual.",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.trending_up_rounded, size: 18),
                  label: Text("Ir al monitor", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(medicoNavProvider.notifier).goBackToList();
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text("Volver a Gestión", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_diasRestantesParaControl == 0 && _idControlEditando == null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      "Hoy es el día de su control",
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green))),
            ]),
          ),
        ],
        if (_yaEvaluadoHoy && _idControlEditando == null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text(
                      "PACIENTE YA EVALUADO HOY. Si registra una nueva valoración, se sobreescribirá el control de esta fecha.",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange))),
            ]),
          ),
        ],

        // 1. SIGNOS VITALES Y ANTROPOMETRÍA
        _sectionHeader(
            "Signos vitales y antropometría", Icons.monitor_weight_outlined),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: _field(
                      _peso, "Peso actual (kg)*", Icons.scale_outlined,
                      onChanged: (_) => _debouncedOMS())),
              const SizedBox(width: 20),
              Expanded(
                  child: _field(
                      _talla, "Talla actual (cm)*", Icons.height_rounded,
                      onChanged: (_) => _debouncedOMS())),
            ]),
            const SizedBox(height: 24),
            _buildOMSDiagnosisRow(),
          ]),
        ),
        const SizedBox(height: 48),

        // 2. EVALUACIÓN DE ACTIVIDAD REUMÁTICA
        _sectionHeader(
            "2. Evaluación de actividad reumática", Icons.healing_outlined),
                const SizedBox(height: 24),
        if (MediaQuery.of(context).size.width > 900) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EscalaSelector(
                  titulo: "Dolor",
                  descripcion: "",
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
                  colorActivo: Colors.red,
                  colorFondoActivo: Colors.red,
                  backgroundColor: const Color(0xFFF8FAFC),
                  showIdentityRow: false,
                  onChanged: (v) => setState(() => _dolor = v.toDouble()),
                  puntajeLabel: "${_dolor.toInt()}/10",
                  headerIcon: const Icon(Icons.healing_rounded,
                      color: Colors.red, size: 28),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildEVACard(
                  "Inflamación",
                  _inflamacion,
                  3,
                  (v) => setState(() => _inflamacion = v),
                  icon: Icons.verified_user_outlined,
                  labels: [
                    "0 = Sin inflamación",
                    "1 = Leve",
                    "2 = Moderada",
                    "3 = Severa / Activa"
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildEVACard(
                  "Fatiga",
                  _fatiga,
                  10,
                  (v) => setState(() => _fatiga = v),
                  icon: Icons.battery_full_rounded,
                  labels: [
                    "0-3 = Agotamiento",
                    "4-7 = Intermedio",
                    "8-10 = Alta energía"
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                          child: _buildCounterField("Art. Inflamadas", _artInflam,
                              Icons.track_changes_outlined)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildCounterField("Art. Dolorosas", _artDolor,
                              Icons.back_hand_outlined)),
                    ]),
                    const SizedBox(height: 24),
                    _field(
                      _rigidez,
                      "Rigidez en min",
                      Icons.timer_outlined,
                      helper: "Minutos de rigidez al despertar o durante el día",
                    ),
                    const SizedBox(height: 18),
                    _buildBroteToggle(),
                  ],
                ),
              ),
            ],
          ),
        ] else ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EscalaSelector(
                titulo: "Dolor",
                descripcion: "",
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
                colorActivo: Colors.red,
                colorFondoActivo: Colors.red,
                backgroundColor: const Color(0xFFF8FAFC),
                showIdentityRow: false,
                onChanged: (v) => setState(() => _dolor = v.toDouble()),
                puntajeLabel: "${_dolor.toInt()}/10",
                headerIcon: const Icon(Icons.healing_rounded,
                    color: Colors.red, size: 28),
              ),
              const SizedBox(height: 24),
              _buildEVACard(
                "Inflamación",
                _inflamacion,
                3,
                (v) => setState(() => _inflamacion = v),
                icon: Icons.verified_user_outlined,
                labels: [
                  "0 = Sin inflamación",
                  "1 = Leve",
                  "2 = Moderada",
                  "3 = Severa / Activa"
                ],
              ),
              const SizedBox(height: 24),
              _buildEVACard(
                "Fatiga",
                _fatiga,
                10,
                (v) => setState(() => _fatiga = v),
                icon: Icons.battery_full_rounded,
                labels: [
                  "0-3 = Agotamiento",
                  "4-7 = Intermedio",
                  "8-10 = Alta energía"
                ],
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: _buildCounterField("Art. Inflamadas", _artInflam,
                        Icons.track_changes_outlined)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildCounterField("Art. Dolorosas", _artDolor,
                        Icons.back_hand_outlined)),
              ]),
              const SizedBox(height: 24),
              _field(
                _rigidez,
                "Rigidez en min",
                Icons.timer_outlined,
                helper: "Minutos de rigidez al despertar o durante el día",
              ),
              const SizedBox(height: 18),
              _buildBroteToggle(),
            ],
          ),
        ],
        const SizedBox(height: 32),
        const SizedBox(height: 48),

        _sectionHeader(
            "3. Síntomas agudos temporales", Icons.event_note_rounded),
        const SizedBox(height: 24),
        _buildSintomasTemporalesGrid(),
        const SizedBox(height: 48),

        _sectionHeader(
            "4. Recomendación de ingredientes", Icons.thumb_up_alt_outlined),
        const SizedBox(height: 24),
        _buildRecomendacionesSelector(),
        const SizedBox(height: 48),

        _sectionHeader("Seguimiento y observaciones", Icons.event_note_rounded),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                _notas, 
                "Observaciones médicas", 
                Icons.edit_note, 
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
        const SizedBox(height: 48),

        SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.icon(
                onPressed: _loading ? null : _guardarConsulta,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(
                    _idControlEditando == null
                        ? "Registrar valoración"
                        : "Guardar cambios",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                style: FilledButton.styleFrom(
                    backgroundColor: greenBrand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))))),
      ]);
    }

    if (isNested)
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: content);
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: content);
  }

  Widget _lactoseCard(bool val, String title, String desc) {
    final bool sel = _lactosa == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _lactosa = val;
          if (val) {
            if (!_restriccionesAlimentarias.contains("INTOLERANCIA_LACTOSA"))
              _restriccionesAlimentarias.add("INTOLERANCIA_LACTOSA");
          } else
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
                            color: sel ? greenBrand : const Color(0xFF0F172A))),
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
          color: isSel ? greenBrand.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSel ? greenBrand : Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSel ? greenBrand : Colors.blueGrey),
            const SizedBox(width: 10),
            Text(name,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSel ? greenBrand : Colors.blueGrey)),
            if (isSel) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 14, color: greenBrand),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelector(
      String label,
      List items,
      List<Map<String, dynamic>> selectedList,
      TextEditingController searchCtrl,
      FocusNode focusNode) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      StatefulBuilder(builder: (context, setInternalState) {
        final q = searchCtrl.text.toLowerCase().trim();
        final matches = items.where((e) {
          if (q.isEmpty) return false;
          final name = (e['nombre'] ?? "").toString().toLowerCase();
          return name.contains(q);
        }).toList();
        return Column(children: [
          TextFormField(
              controller: searchCtrl,
              focusNode: focusNode,
              onChanged: (v) => setInternalState(() {}),
              decoration: InputDecoration(
                  labelText: label, prefixIcon: const Icon(Icons.search))),
          if (matches.isNotEmpty && focusNode.hasFocus)
            Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 10)
                    ]),
                child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: min(matches.length, 50),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = matches[i];
                      final id = item['id'];
                      final isSel = selectedList.any((ing) => ing['id'] == id);
                      return ListTile(
                          dense: true,
                          title: Text(item['nombre'] ?? ""),
                          trailing: Icon(
                              isSel
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isSel ? Colors.red : null),
                          onTap: () {
                            setState(() {
                              if (!isSel)
                                selectedList
                                    .add(Map<String, dynamic>.from(item));
                              else
                                selectedList
                                    .removeWhere((ing) => ing['id'] == id);
                            });
                            setInternalState(() {});
                          });
                    }))
        ]);
      }),
      const SizedBox(height: 12),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectedList
              .map((e) => Chip(
                  label: Text(e['nombre'] ?? "",
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                  onDeleted: () => setState(() => selectedList.remove(e)),
                  backgroundColor: Colors.red.shade50,
                  deleteIconColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))))
              .toList())
    ]);
  }

  Widget _buildSintomasTemporalesGrid() {
    if (_condicionesTemporalesCat.isEmpty) return const SizedBox.shrink();
    final ordenadas = [..._condicionesTemporalesCat]..sort((a, b) =>
        (a['nombre'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['nombre'] ?? '').toString().toLowerCase()));
    return LayoutBuilder(builder: (context, constraints) {
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
                        : const Color(0xFFE2E8F0))),
            child: ExpansionTile(
              key: Key("temp_ctrl_$id"),
              initiallyExpanded: sel,
              shape: const Border(),
              leading: Checkbox(
                  activeColor: greenBrand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  value: sel,
                  onChanged: (v) {
                    if (v == true) {
                      final ini = DateTime.now();
                      setState(() => _condicionesTemp.add({
                            "id": id,
                            "nombre": c['nombre'],
                            "fecha_inicio": ini.toIso8601String().split('T')[0],
                            "fecha_fin": ini
                                .add(Duration(days: duracionSugerida))
                                .toIso8601String()
                                .split('T')[0]
                          }));
                    } else {
                      setState(() => _condicionesTemp.removeAt(index));
                    }
                  }),
              title: Text(c['nombre']?.toString() ?? "Condición",
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                      color: sel ? greenBrand : const Color(0xFF1E293B))),
              subtitle: Text(
                  sel
                      ? "Activa por $duracionSugerida días"
                      : "Sugerencia: $duracionSugerida días",
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF64748B))),
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
    });
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
    return Row(
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
                  })),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dateStaticSmall("Fin", fin),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              "Quedan $diasRestantes días",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOMSDiagnosisRow() {
    return Container(
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
                    color: const Color(0xFF475569))),
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
                  _pesoIdeal > 0
                      ? "${_pesoIdeal.toStringAsFixed(1)} kg"
                      : "-"),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricPill(
                  "Talla ideal",
                  _tallaIdeal > 0
                      ? "${_tallaIdeal.toStringAsFixed(1)} cm"
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
  }

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

  Widget _subHeader(String t, IconData i) => Row(children: [
        Icon(i, size: 18, color: greenBrand),
        const SizedBox(width: 12),
        Text(t,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: const Color(0xFF0F172A),
                letterSpacing: 0.5))
      ]);

  Widget _buildEVACard(String title, double val, int max, Function(double) onC,
      {required IconData icon, required List<String> labels}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: greenBrand.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: greenBrand, size: 20)),
            const SizedBox(width: 12),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A))),
          ]),
          Text("${val.toInt()}/$max",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: greenBrand)),
        ]),
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
                          color: isSel ? greenBrand : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  isSel ? greenBrand : Colors.grey.shade200)),
                      child: Center(
                          child: Text("$index",
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSel
                                      ? Colors.white
                                      : Colors.blueGrey))))));
        })),
        const SizedBox(height: 16),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map((l) => Text(l,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey)))
                .toList()),
      ]),
    );
  }

  Widget _buildCounterField(
      String label, TextEditingController ctrl, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          child: Row(children: [
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
                        contentPadding: EdgeInsets.zero))),
            IconButton(
                onPressed: () {
                  int v = int.tryParse(ctrl.text) ?? 0;
                  if (v > 0) ctrl.text = (v - 1).toString();
                  setState(() {});
                },
                icon: const Icon(Icons.remove, size: 16)),
            IconButton(
                onPressed: () {
                  int v = int.tryParse(ctrl.text) ?? 0;
                  ctrl.text = (v + 1).toString();
                  setState(() {});
                },
                icon: const Icon(Icons.add, size: 16)),
          ])),
    ]);
  }

  Widget _buildBroteToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _brote
              ? Colors.red.withOpacity(0.05)
              : greenBrand.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _brote
                  ? Colors.red.withOpacity(0.1)
                  : greenBrand.withOpacity(0.1))),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _brote ? Colors.red : greenBrand,
                shape: BoxShape.circle),
            child: Icon(
                _brote ? Icons.warning_amber_rounded : Icons.check_rounded,
                color: Colors.white,
                size: 20)),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("¿Tiene brote activo?",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _brote ? Colors.red.shade900 : Colors.green.shade900)),
          Text("Indique si el paciente presenta un brote en este momento.",
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600)),
        ])),
        Switch.adaptive(
            value: _brote,
            activeColor: Colors.red,
            onChanged: (v) => setState(() => _brote = v)),
      ]),
    );
  }

  Widget _buildActiveStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
          color: _brote
              ? Colors.red.withOpacity(0.1)
              : greenBrand.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _brote
                  ? Colors.red.withOpacity(0.2)
                  : greenBrand.withOpacity(0.2))),
      child: Row(children: [
        Icon(_brote ? Icons.error_outline : Icons.verified_outlined,
            color: _brote ? Colors.red : greenBrand),
        const SizedBox(width: 16),
        Text(_brote ? "Brote activo detectado" : "Sin brote activo",
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _brote ? Colors.red : greenBrand)),
        const Spacer(),
        Switch.adaptive(
            value: _brote,
            activeColor: Colors.red,
            onChanged: (v) => setState(() => _brote = v)),
      ]),
    );
  }

  Widget _dropdown(String l, List items, int? val, Function(int?) onC,
          {String? hint}) =>
      DropdownButtonFormField<int>(
          value: val,
          isExpanded: true,
          hint: hint != null
              ? Text(hint,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500))
              : null,
          items: items
              .map((e) => DropdownMenuItem<int>(
                  value: e['id'],
                  child: Text(e['nombre'] ?? e['descripcion'] ?? "",
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B)))))
              .toList(),
          onChanged: onC,
          decoration: InputDecoration(labelText: l));

  Widget _datePickerSmall(String l, String v, Function(DateTime) onP) =>
      InkWell(
          onTap: () async {
            final d = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(v),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 90)));
            if (d != null) onP(d);
          },
          child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l,
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(v,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: greenBrand))
                  ])));

  Widget _dateStaticSmall(String l, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [
          const Icon(Icons.event_available_rounded,
              size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
                  "$l: ${DateFormat('EEEE, d MMMM y', 'es').format(DateTime.tryParse(v) ?? DateTime.now())}",
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _richSummary(String text, Color color) {
    List<TextSpan> spans = [];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1)
        spans.add(TextSpan(
            text: parts[i],
            style: TextStyle(
                fontWeight: FontWeight.w900, color: color, fontSize: 13)));
      else
        spans.add(TextSpan(text: parts[i]));
    }
    return RichText(
        text: TextSpan(
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.4,
                fontFamily: GoogleFonts.inter().fontFamily),
            children: spans));
  }

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

  Widget _field(TextEditingController c, String l, IconData i,
          {int maxLines = 1,
          Function(String)? onChanged,
          bool enabled = true,
          String? helper,
          bool readOnly = false,
          VoidCallback? onTap}) =>
      TextFormField(
          controller: c,
          maxLines: maxLines,
          enabled: enabled,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
              labelText: l,
              helperText: helper,
              prefixIcon: Icon(i, size: 18),
              border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)))));

  Widget _buildHistoryTab({bool isNested = false}) {
    if (_loading && _expediente == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final evo = _evolucionMensual;
    final historial = (evo?['controles'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (evo == null || historial.isEmpty) {
      return const Center(
          child: Text("No hay registros previos para graficar."));
    }
    
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Monitor de evolución",
            style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -1)),
        const SizedBox(height: 8),
        Text(
            "Historial y análisis clínico de la actividad de la enfermedad y estado nutricional.",
            style: GoogleFonts.inter(
                fontSize: 15, color: const Color(0xFF64748B))),
        const SizedBox(height: 28),
        _buildOpsDashboard(evo, historial),
      ],
    );

    if (isNested) {
      return Padding(padding: const EdgeInsets.all(40), child: content);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: content,
    );
  }

  Widget _buildOpsDashboard(Map<String, dynamic> evo, List<Map<String, dynamic>> historial) {
    final controls = _evoFilteredControls(evo);
    final monthlyControls = _groupEvoControlsByMonth(controls);
    final stats = _calculateEvoStats(monthlyControls);
    
    final tabs = [
      "Síntomas y Clínica",
      "Mapa Articular",
      "Crecimiento y Nutrición",
      "Historial de Controles",
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pestañas (Navegación horizontal superior)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(tabs.length, (index) {
                final active = _activeMonitorIndex == index;
                return InkWell(
                  onTap: () => setState(() => _activeMonitorIndex = index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? AppTema.azulPrincipal : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? AppTema.azulPrincipal : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      tabs[index],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.bold : FontWeight.w600,
                        color: active ? Colors.white : Colors.blueGrey,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          // Contenido principal de la pestaña (dividido en 2 columnas estilo OPS)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Columna Izquierda (Contexto y KPIs)
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border(right: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: _buildOpsLeftPanel(stats, controls, evo),
                ),
                
                // Columna Derecha (Gráficas)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: _buildOpsRightPanel(controls, evo, historial),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpsLeftPanel(Map<String, dynamic> stats, List<Map<String, dynamic>> controls, Map<String, dynamic> evo) {
    if (_activeMonitorIndex == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.circular(6)),
            child: Text("Figura 1", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Text("Evolución mensual de síntomas", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal)),
          const SizedBox(height: 24),
          _opsKpi("Último nivel de dolor", "${controls.isNotEmpty ? controls.last['puntos_dolor'] ?? '-' : '-'} / 10"),
          const SizedBox(height: 16),
          _opsKpi("Última fatiga", "${controls.isNotEmpty ? controls.last['nivel_fatiga'] ?? '-' : '-'} / 10"),
          const Spacer(),
          const Divider(),
          Text("Fuente: Historial de la Escala Visual Analógica (EVA) reportada por el paciente en sus controles regulares.", style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey)),
        ],
      );
    } else if (_activeMonitorIndex == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.circular(6)),
            child: Text("Figura 2", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Text("Mapa articular", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal)),
          const SizedBox(height: 24),
          _opsKpi("Articulaciones inflamadas", "${controls.isNotEmpty ? controls.last['articulaciones_inflamadas'] ?? '-' : '-'}"),
          const SizedBox(height: 16),
          _opsKpi("Articulaciones dolorosas", "${controls.isNotEmpty ? controls.last['articulaciones_dolorosas'] ?? '-' : '-'}"),
          const Spacer(),
          const Divider(),
          Text("Fuente: Conteo clínico de 27 articulaciones para evaluación de AIJ.", style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey)),
        ],
      );
    } else if (_activeMonitorIndex == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.circular(6)),
            child: Text("Figura 3", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Text("Crecimiento y nutrición", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal)),
          const SizedBox(height: 24),
          _opsKpi("Último IMC", "${controls.isNotEmpty ? controls.last['imc_calculado'] ?? '-' : '-'}"),
          const Spacer(),
          const Divider(),
          Text("Fuente: Evaluaciones de talla y peso usando estándares OMS.", style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey)),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppTema.azulPrincipal, borderRadius: BorderRadius.circular(6)),
            child: Text("Historial", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Text("Registros cronológicos", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal)),
          const SizedBox(height: 24),
          _opsKpi("Controles totales", "${controls.length}"),
          const Spacer(),
          const Divider(),
          Text("Fuente: Línea de tiempo de eventos clínicos del paciente.", style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey)),
        ],
      );
    }
  }

  Widget _opsKpi(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: AppTema.azulPrincipal)),
      ],
    );
  }

  Widget _buildOpsRightPanel(List<Map<String, dynamic>> controls, Map<String, dynamic> evo, List<Map<String, dynamic>> historial) {
    if (_activeMonitorIndex == 0) {
      return Column(
        children: [
          _buildEvoActivitySection(controls),
          const SizedBox(height: 24),
          _buildEvoInflammationSectionV2(controls),
        ],
      );
    } else if (_activeMonitorIndex == 1) {
      return _buildEvoHeatmapSection(controls);
    } else if (_activeMonitorIndex == 2) {
      return Column(
        children: [
          _buildEvoGrowthSection(controls, Map<String, dynamic>.from(evo['paciente'] ?? {})),
          const SizedBox(height: 40),
          _buildFoodIntakeSection(),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClinicalTimeline(historial),
          const SizedBox(height: 40),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: historial.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildHistoryItem(historial[historial.length - 1 - index]),
          ),
        ],
      );
    }
  }

  Widget _buildChartExplanation(String title, String content, Color color) =>
      Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: color.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.15))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text(content,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey,
                          height: 1.6))
                ]))
          ]));
  Widget _buildSectionHeader(
          String title, String subtitle, IconData icon, Color color) =>
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Row(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: color)),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.blueGrey))
                ]))
          ]));

  Widget _buildZScoreChart(List<dynamic> history) => Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(LineChartData(
          minY: -3,
          maxY: 3,
          gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              getDrawingHorizontalLine: (v) => v == 0
                  ? FlLine(color: Colors.green.withOpacity(0.5), strokeWidth: 2)
                  : (v.abs() == 2
                      ? FlLine(
                          color: Colors.orange.withOpacity(0.3),
                          strokeWidth: 1,
                          dashArray: [5, 5])
                      : (v.abs() == 3
                          ? FlLine(
                              color: Colors.red.withOpacity(0.3),
                              strokeWidth: 1,
                              dashArray: [5, 5])
                          : FlLine(
                              color: Colors.grey.shade100, strokeWidth: 1)))),
          titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) => v.toInt() >= 0 && v.toInt() < history.length
                          ? Text(DateFormat('dd/MM').format(DateTime.parse(history[v.toInt()]['fecha_control'])), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey))
                          : const Text(""))),
              leftTitles: AxisTitles(axisNameWidget: const Text("Z-score BMI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(1), style: TextStyle(fontSize: 10, color: v == 0 ? Colors.green : (v.abs() == 2 ? Colors.orange : (v.abs() == 3 ? Colors.red : Colors.grey)), fontWeight: FontWeight.bold))))),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            LineChartBarData(
                spots: history
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(),
                        (e.value['z_score_bmi'] ?? 0).toDouble()))
                    .toList(),
                isCurved: true,
                color: const Color(0xFF2563EB),
                barWidth: 4,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF2563EB).withOpacity(0.05)))
          ])));

  Widget _buildThermometerGauges(List<dynamic> history) {
    if (history.isEmpty) return const SizedBox.shrink();
    final ultimo = history.last;
    final pesoActual = (ultimo['peso_kg'] ?? 0).toDouble();
    final pesoIdeal = (ultimo['peso_ideal'] ?? pesoActual).toDouble();
    final tallaActual = (ultimo['talla_cm'] ?? 0).toDouble();
    final tallaIdeal = (ultimo['talla_ideal'] ?? tallaActual).toDouble();
    double pesoPct =
        pesoIdeal > 0 ? (pesoActual / pesoIdeal).clamp(0.7, 1.3) : 1.0;
    double tallaPct =
        tallaIdeal > 0 ? (tallaActual / tallaIdeal).clamp(0.85, 1.15) : 1.0;

    String pesoMsg = "";
    Color pesoColor = Colors.green;
    double pesoDiff = pesoActual - pesoIdeal;
    if (pesoDiff.abs() < 0.5) {
      pesoMsg = "[NORMAL] Peso óptimo";
      pesoColor = Colors.green;
    } else if (pesoDiff > 0) {
      pesoMsg = "[ALERTA] Bajar ${pesoDiff.toStringAsFixed(1)}kg";
      pesoColor = pesoDiff > 3 ? Colors.red : Colors.orange;
    } else {
      pesoMsg = "[ATENCIÓN] Subir ${pesoDiff.abs().toStringAsFixed(1)}kg";
      pesoColor = pesoDiff.abs() > 3 ? Colors.red : Colors.orange;
    }

    String tallaMsg = "";
    Color tallaColor = Colors.green;
    double tallaDiff = tallaIdeal - tallaActual;
    if (tallaDiff.abs() < 1) {
      tallaMsg = "[NORMAL] Talla adecuada";
      tallaColor = Colors.green;
    } else if (tallaDiff > 0) {
      tallaMsg = "[ALERTA] Crecer ${tallaDiff.toStringAsFixed(1)}cm";
      tallaColor = tallaDiff > 5 ? Colors.red : Colors.orange;
    } else {
      tallaMsg = "[NORMAL] Talla superior";
      tallaColor = Colors.green;
    }

    return Row(children: [
      Expanded(
          child: _buildThermometer(
              label: "Peso actual",
              actual: pesoActual,
              ideal: pesoIdeal,
              unit: "kg",
              percentage: pesoPct,
              color: pesoColor,
              message: pesoMsg,
              icon: Icons.monitor_weight_outlined)),
      const SizedBox(width: 20),
      Expanded(
          child: _buildThermometer(
              label: "Talla actual",
              actual: tallaActual,
              ideal: tallaIdeal,
              unit: "cm",
              percentage: tallaPct,
              color: tallaColor,
              message: tallaMsg,
              icon: Icons.height_rounded)),
    ]);
  }

  Widget _buildThermometer(
      {required String label,
      required double actual,
      required double ideal,
      required String unit,
      required double percentage,
      required Color color,
      required String message,
      required IconData icon}) {
    double barHeight = percentage.clamp(0.0, 1.3) * 200;
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey,
                    letterSpacing: 0.5))
          ]),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
                width: 40,
                height: 220,
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300)),
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  Positioned(
                      bottom: 10,
                      child: Container(
                          width: 32,
                          height: barHeight.clamp(10, 200),
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(16))))
                ])),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text("Actual",
                      style: TextStyle(fontSize: 9, color: Colors.grey)),
                  Text("$actual $unit",
                      style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: color)),
                  const SizedBox(height: 8),
                  const Text("Ideal OMS",
                      style: TextStyle(fontSize: 9, color: Colors.grey)),
                  Text("$ideal $unit",
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.green)),
                  const SizedBox(height: 16),
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(message,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                    height: 1.4)))
                      ]))
                ]))
          ])
        ]));
  }

  Widget _buildSymptomsChart(List<dynamic> history) => Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(LineChartData(
          minY: 0,
          maxY: 10,
          titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(
                  axisNameWidget: Text("Escala 0-10",
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) =>
                          v.toInt() >= 0 && v.toInt() < history.length
                              ? Text(
                                  DateFormat('dd/MM').format(DateTime.parse(
                                      history[v.toInt()]['fecha_control'])),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold))
                              : const Text("")))),
          borderData:
              FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            LineChartBarData(
                spots: history
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(),
                        (e.value['puntos_dolor'] ?? 0).toDouble()))
                    .toList(),
                isCurved: true,
                color: Colors.red,
                barWidth: 4,
                dotData: const FlDotData(show: true)),
            LineChartBarData(
                spots: history
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(),
                        (e.value['nivel_fatiga'] ?? 10).toDouble()))
                    .toList(),
                isCurved: true,
                color: Colors.green,
                barWidth: 4,
                dotData: const FlDotData(show: true))
          ])));
  Widget _buildInflammationChart(List<dynamic> history) => Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(LineChartData(
          minY: 0,
          maxY: 3,
          titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                  axisNameWidget: const Text("Escala 0-3",
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 1,
                      getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                          style: const TextStyle(fontSize: 10)))),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) => v.toInt() >= 0 &&
                              v.toInt() < history.length
                          ? Text(DateFormat('dd/MM').format(DateTime.parse(history[v.toInt()]['fecha_control'])),
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold))
                          : const Text("")))),
          borderData: FlBorderData(
              show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            LineChartBarData(
                spots: history
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(),
                        (e.value['escala_inflamacion'] ?? 0).toDouble()))
                    .toList(),
                isCurved: true,
                color: Colors.purple,
                barWidth: 5,
                dotData: const FlDotData(show: true))
          ])));
  Widget _buildJointCountChart(List<dynamic> history) => Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(LineChartData(
          titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(
                  axisNameWidget: Text("Cantidad",
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) =>
                          v.toInt() >= 0 && v.toInt() < history.length
                              ? Text(
                                  DateFormat('dd/MM').format(DateTime.parse(
                                      history[v.toInt()]['fecha_control'])),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold))
                              : const Text("")))),
          borderData:
              FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            LineChartBarData(
                spots: history
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(),
                        (e.value['articulaciones_inflamadas'] ?? 0).toDouble()))
                    .toList(),
                isCurved: true,
                color: Colors.red,
                barWidth: 4,
                dotData: const FlDotData(show: true)),
            LineChartBarData(
                spots: history
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(),
                        (e.value['articulaciones_dolorosas'] ?? 0).toDouble()))
                    .toList(),
                isCurved: true,
                color: Colors.orange,
                barWidth: 4,
                dotData: const FlDotData(show: true))
          ])));
  Widget _buildLabTrendsChart(List<dynamic> history) {
    double maxV = 10.0;
    for (var h in history) {
      double p = (h['valor_pcr'] ?? 0).toDouble(),
          v = (h['valor_vsg'] ?? 0).toDouble();
      if (p > maxV) maxV = p;
      if (v > maxV) maxV = v;
    }
    return Container(
        height: 350,
        padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200)),
        child: LineChart(LineChartData(
            minY: 0,
            maxY: maxV * 1.1,
            titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                    axisNameWidget: const Text("Valor",
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) =>
                            v.toInt() >= 0 && v.toInt() < history.length
                                ? Text(
                                    DateFormat('dd/MM').format(DateTime.parse(
                                        history[v.toInt()]['fecha_control'])),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold))
                                : const Text("")))),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
            lineBarsData: [
              LineChartBarData(
                  spots: history
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(),
                          (e.value['valor_pcr'] ?? 0).toDouble()))
                      .toList(),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 4),
              LineChartBarData(
                  spots: history
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(),
                          (e.value['valor_vsg'] ?? 0).toDouble()))
                      .toList(),
                  isCurved: true,
                  color: Colors.purple,
                  barWidth: 4)
            ])));
  }

  Widget _buildDynamicConclusion(List<dynamic> history, String type) {
    if (history.isEmpty) return const SizedBox.shrink();
    String conclusion = "";
    IconData icon = Icons.info_outline;
    Color color = Colors.blueGrey;
    final ultimo = history.last;
    switch (type) {
      case "z_score":
        double z = (ultimo['z_score_bmi'] ?? 0).toDouble();
        if (z.abs() > 2) {
          conclusion =
              "[ALERTA] Z-Score alterado ($z). Intervención inmediata.";
          color = Colors.red;
        } else {
          conclusion = "[NORMAL] Z-Score saludable ($z).";
          color = Colors.green;
        }
        break;
      case "symptoms":
        int d = ultimo['puntos_dolor'] ?? 0, f = ultimo['nivel_fatiga'] ?? 10;
        if (d <= 2 && f >= 7) {
          conclusion = "OK Bienestar estable (Dolor: $d, Energía: $f).";
          color = Colors.green;
        } else {
          conclusion = "Alerta: síntomas presentes (dolor: $d).";
          color = Colors.orange;
        }
        break;
      default:
        conclusion = "Seguimiento clínico en curso.";
    }
    return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(conclusion,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: color)))
        ]));
  }

  Widget _buildHistoryItem(Map<String, dynamic> h) => InkWell(
        onTap: () => _mostrarDetalleModal(h),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: (h['en_brote'] ?? false)
                    ? Colors.red.shade100
                    : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              _dateBadge(DateTime.parse(h['fecha_control'])),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h['estado_nutricional'] ?? "Sin diagnóstico",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Peso: ${h['peso_kg']} kg | Talla: ${h['talla_cm']} cm | IMC: ${h['imc_calculado'] ?? '-'}",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                    Text(
                      "Dolor: ${h['puntos_dolor'] ?? '-'} | Inflamación: ${h['escala_inflamacion'] ?? '-'} | Fatiga: ${h['nivel_fatiga'] ?? '-'} | Rigidez: ${h['minutos_rigidez'] ?? '-'} min",
                      style:
                          const TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              if (h['en_brote'] == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text("Brote",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Editar",
                onPressed: () => _prepararEdicion(h),
                icon: const Icon(Icons.edit_note_rounded, color: greenBrand),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey),
            ],
          ),
        ),
      );

  void _mostrarDetalleModal(Map<String, dynamic> h) => showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            width: 650,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: greenBrand),
                    const SizedBox(width: 12),
                    Text("Resumen de valoración",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: greenBrand)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(height: 32),
                _infoModalRow(
                    "Fecha de control",
                    DateFormat('dd/MM/yyyy')
                        .format(DateTime.parse(h['fecha_control']))),
                _infoModalRow(
                    "Estado nutricional", h['estado_nutricional'] ?? "Normal",
                    isHighlight: true),
                _infoModalRow("Peso / Talla",
                    "${h['peso_kg'] ?? '-'} kg / ${h['talla_cm'] ?? '-'} cm"),
                _infoModalRow("IMC", h['imc_calculado']?.toString() ?? "-"),
                _infoModalRow("Actividad clínica",
                    "Dolor ${h['puntos_dolor'] ?? '-'} | Inflamación ${h['escala_inflamacion'] ?? '-'} | Fatiga ${h['nivel_fatiga'] ?? '-'} | Rigidez ${h['minutos_rigidez'] ?? '-'} min"),
                _infoModalRow("Estado de enfermedad",
                    h['estado_enfermedad'] ?? "Seguimiento"),
                _infoModalRow(
                    "Próxima cita", h['fecha_proxima_cita'] ?? "Sin fecha"),
                if ((h['nota_evolucion'] ?? '').toString().isNotEmpty)
                  _infoModalRow("Notas", h['nota_evolucion']),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _prepararEdicion(h);
                        },
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text("Editar valoración"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: greenBrand,
                          side: const BorderSide(color: greenBrand),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _infoModalRow(String l, String v, {bool isHighlight = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey)),
            const SizedBox(height: 2),
            Text(v,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
                    color: isHighlight ? greenBrand : const Color(0xFF1E293B)))
          ]));

  String _capitalize(String value) {
    final text = value.trim();
    return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
  }

  Widget _dateBadge(DateTime d) => Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: greenBrand.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(DateFormat('dd').format(d),
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 18, color: greenBrand)),
        Text(_capitalize(DateFormat('MMM').format(d)),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 9, color: greenBrand))
      ]));

  Widget _buildClinicalTimeline(List<dynamic> history) => Container(
      height: 180,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100)),
      child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(24),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final h = history[index];
            return SizedBox(
                width: 160,
                child: Column(children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color:
                              (h['en_brote'] == true) ? Colors.red : greenBrand,
                          shape: BoxShape.circle),
                      child: Icon(
                          (h['en_brote'] == true) ? Icons.warning : Icons.check,
                          color: Colors.white,
                          size: 18)),
                  const SizedBox(height: 12),
                  Text(
                      DateFormat('dd MMM yyyy')
                          .format(DateTime.parse(h['fecha_control'])),
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w900))
                ]));
          }));

  DateTime? _controlDate(Map<String, dynamic> c) {
    final raw = c['fecha_control']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  double _numValue(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _monthKey(DateTime d) => d.year * 100 + d.month;

  String _monthLabel(DateTime d, {bool withYear = false}) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    final label = months[d.month - 1];
    return withYear ? '$label ${d.year}' : label;
  }

  String _monthFullLabel(DateTime d, {bool withYear = false}) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    final label = months[d.month - 1];
    return withYear ? '$label ${d.year}' : label;
  }

  String _monthFullFromRaw(String raw) {
    final dt = DateTime.tryParse(raw);
    return dt == null ? _monthShort(raw) : _monthFullLabel(dt);
  }

  String _pointsText(double value) {
    final formatted = value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
    return "$formatted ${value.abs() == 1 ? 'punto' : 'puntos'}";
  }

  List<Map<String, dynamic>> _sortControlsByDate(
      List<Map<String, dynamic>> controls,
      {bool descending = false}) {
    final sorted = controls.map((c) => Map<String, dynamic>.from(c)).toList();
    sorted.sort((a, b) {
      final da = _controlDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = _controlDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return descending ? db.compareTo(da) : da.compareTo(db);
    });
    return sorted;
  }

  List<Map<String, dynamic>> _groupEvoControlsByMonth(
      List<Map<String, dynamic>> controls) {
    final sorted = _sortControlsByDate(controls);
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final c in sorted) {
      final dt = _controlDate(c);
      if (dt == null) continue;
      grouped.putIfAbsent(_monthKey(dt), () => <Map<String, dynamic>>[]).add(c);
    }

    return grouped.entries.map((entry) {
      final items = entry.value;
      final firstDate = _controlDate(items.first)!;
      final lastControl = items.last;
      final dolor = items
              .map((c) => _numValue(c['puntos_dolor'], 0))
              .reduce((a, b) => a + b) /
          items.length;
      final energia = items
              .map((c) => _numValue(c['nivel_fatiga'], 10))
              .reduce((a, b) => a + b) /
          items.length;
      final brotes = items.where((c) => c['en_brote'] == true).length;

      return {
        ...lastControl,
        'fecha_control':
            DateTime(firstDate.year, firstDate.month, 1).toIso8601String(),
        'fecha_control_real': lastControl['fecha_control'],
        'mes_label': _monthLabel(firstDate),
        'mes_label_largo': _monthLabel(firstDate, withYear: true),
        'controles_mes': items.length,
        'puntos_dolor': dolor,
        'nivel_fatiga': energia,
        'en_brote': brotes > 0,
        'brotes_mes': brotes,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _groupActivityControlsByMonth(
      List<Map<String, dynamic>> controls) {
    final sorted = _sortControlsByDate(controls);
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final c in sorted) {
      final dt = _controlDate(c);
      if (dt == null) continue;
      grouped.putIfAbsent(_monthKey(dt), () => <Map<String, dynamic>>[]).add(c);
    }

    return grouped.entries.map((entry) {
      final items = entry.value;
      final firstDate = _controlDate(items.first)!;
      final lastControl = items.last;
      double avg(String key) =>
          items.map((c) => _numValue(c[key], 0)).reduce((a, b) => a + b) /
          items.length;

      return {
        ...lastControl,
        'fecha_control':
            DateTime(firstDate.year, firstDate.month, 1).toIso8601String(),
        'fecha_control_real': lastControl['fecha_control'],
        'mes_label': _monthLabel(firstDate),
        'mes_label_largo': _monthLabel(firstDate, withYear: true),
        'controles_mes': items.length,
        'articulaciones_inflamadas': avg('articulaciones_inflamadas'),
        'articulaciones_dolorosas': avg('articulaciones_dolorosas'),
        'minutos_rigidez': avg('minutos_rigidez'),
      };
    }).toList();
  }

  Map<String, dynamic> _calculateEvoStats(List<Map<String, dynamic>> controls) {
    if (controls.isEmpty) return {};

    final orderedControls = _sortControlsByDate(controls);
    final last = orderedControls.last;
    final prev = orderedControls.length > 1
        ? orderedControls[orderedControls.length - 2]
        : null;
    final double ultimoDolor = _numValue(last['puntos_dolor'], 0);
    final double ultimaEnergia = _numValue(last['nivel_fatiga'], 10);
    final bool ultimoBrote = last['en_brote'] == true;

    final totalMeses = controls.length;
    final totalControles = controls.fold<int>(
        0, (sum, c) => sum + _numValue(c['controles_mes'], 1).round());
    final promedioDolor = controls
            .map((c) => _numValue(c['puntos_dolor'], 0))
            .reduce((a, b) => a + b) /
        totalMeses;
    final promedioEnergia = controls
            .map((c) => _numValue(c['nivel_fatiga'], 10))
            .reduce((a, b) => a + b) /
        totalMeses;
    final mesesConBrote = controls.where((c) => c['en_brote'] == true).length;
    final controlesConBrote = controls.fold<int>(
        0,
        (sum, c) =>
            sum +
            _numValue(c['brotes_mes'], c['en_brote'] == true ? 1 : 0).round());
    final dolorPrevio =
        prev == null ? ultimoDolor : _numValue(prev['puntos_dolor'], 0);
    final energiaPrevia =
        prev == null ? ultimaEnergia : _numValue(prev['nivel_fatiga'], 10);
    final deltaDolor = ultimoDolor - dolorPrevio;
    final deltaEnergia = ultimaEnergia - energiaPrevia;

    // Patrón clínico
    String patronClinico = "evolución en seguimiento";
    if (promedioDolor >= 7 && promedioEnergia <= 3) {
      patronClinico = "dolor persistente y energía baja";
    } else if (promedioDolor >= 7 && mesesConBrote > totalMeses / 2) {
      patronClinico = "alta actividad clínica sostenida";
    } else if (promedioDolor <= 3 && promedioEnergia >= 7) {
      patronClinico = "evolución favorable";
    } else if (totalMeses < 3) {
      patronClinico = "datos insuficientes";
    } else if (deltaDolor <= -2 && deltaEnergia >= 2) {
      patronClinico = "mejoría clínica reciente";
    } else if (deltaDolor >= 2 || deltaEnergia <= -2) {
      patronClinico = "deterioro clínico reciente";
    }

    // Interpretación
    String interpretacion = "";
    if (totalMeses < 3) {
      interpretacion =
          "Se requieren más registros para generar una interpretación clínica de la tendencia mensual.";
    } else {
      String dolorStr = promedioDolor >= 7
          ? "persistentemente alto"
          : (promedioDolor >= 3 ? "moderado" : "bajo");
      String energiaStr = promedioEnergia <= 3
          ? "consistentemente baja"
          : (promedioEnergia <= 6 ? "moderada" : "adecuada");
      final tendenciaDolor = deltaDolor <= -1
          ? "disminuye ${deltaDolor.abs().toStringAsFixed(1)} puntos"
          : (deltaDolor >= 1
              ? "aumenta ${deltaDolor.toStringAsFixed(1)} puntos"
              : "se mantiene estable");
      final tendenciaEnergia = deltaEnergia >= 1
          ? "mejora ${deltaEnergia.toStringAsFixed(1)} puntos"
          : (deltaEnergia <= -1
              ? "desciende ${deltaEnergia.abs().toStringAsFixed(1)} puntos"
              : "se mantiene estable");
      final broteLectura = mesesConBrote == 0
          ? "no hay meses con brote registrado"
          : "hay brote en $mesesConBrote de $totalMeses meses";
      interpretacion =
          "La gráfica mensual resume $totalControles controles en $totalMeses meses. El dolor es $dolorStr (promedio ${promedioDolor.toStringAsFixed(1)}/10) y la energía es $energiaStr (promedio ${promedioEnergia.toStringAsFixed(1)}/10). Frente al mes anterior, el dolor $tendenciaDolor y la energía $tendenciaEnergia; $broteLectura. Esto sugiere $patronClinico y debe correlacionarse con examen clínico, brotes y adherencia del paciente.";
    }

    return {
      'ultimoDolor': ultimoDolor,
      'ultimaEnergia': ultimaEnergia,
      'ultimoBrote': ultimoBrote,
      'totalControles': totalControles,
      'totalMeses': totalMeses,
      'promedioDolor': promedioDolor,
      'promedioEnergia': promedioEnergia,
      'controlesConBrote': controlesConBrote,
      'mesesConBrote': mesesConBrote,
      'deltaDolor': deltaDolor,
      'deltaEnergia': deltaEnergia,
      'patronClinico': patronClinico,
      'interpretacion': interpretacion,
      'ultimoControlFecha': last['fecha_control'],
      'altaActividad': promedioDolor >= 7 ||
          ultimoDolor >= 7 ||
          (mesesConBrote > totalMeses / 3),
    };
  }

  Widget _redesignHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Evolución mensual de síntomas", Icons.show_chart_rounded),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Text(
                "Seguimiento de dolor y energía reportados en los controles del paciente",
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B))),
          ),
        ],
      );

  Widget _redesignMetricCard(String title, String value, Color color,
          IconData icon, String status) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ]),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.08), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(status,
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ],
        ),
      );

  Widget _redesignSummaryCards(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
            child: _redesignMetricCard(
                "Dolor mensual",
                "${stats['ultimoDolor'].toStringAsFixed(1)}/10",
                _severityColor(stats['ultimoDolor'].round(), 0, 2, 6),
                Icons.track_changes_outlined,
                stats['deltaDolor'] < -0.5
                    ? "Bajó vs mes previo"
                    : (stats['deltaDolor'] > 0.5
                        ? "Subió vs mes previo"
                        : (stats['ultimoDolor'] >= 7
                            ? "Alta actividad"
                            : (stats['ultimoDolor'] >= 3
                                ? "Moderado"
                                : "Objetivo"))))),
        const SizedBox(width: 12),
        Expanded(
            child: _redesignMetricCard(
                "Energía mensual",
                "${stats['ultimaEnergia'].toStringAsFixed(1)}/10",
                stats['ultimaEnergia'] >= 7
                    ? Colors.green
                    : (stats['ultimaEnergia'] >= 4
                        ? Colors.orange
                        : Colors.red),
                Icons.bolt,
                stats['deltaEnergia'] > 0.5
                    ? "Mejoró vs mes previo"
                    : (stats['deltaEnergia'] < -0.5
                        ? "Bajó vs mes previo"
                        : (stats['ultimaEnergia'] >= 7
                            ? "Adecuada"
                            : (stats['ultimaEnergia'] >= 4
                                ? "Moderada"
                                : "Baja"))))),
        const SizedBox(width: 12),
        Expanded(
            child: _redesignMetricCard(
                "Periodo",
                "${stats['totalMeses']} meses",
                const Color(0xFF2563EB),
                Icons.assignment_outlined,
                "${stats['totalControles']} controles")),
        const SizedBox(width: 12),
        Expanded(
            child: _redesignMetricCard(
                "Brote",
                stats['ultimoBrote'] == true ? "Sí" : "No",
                stats['ultimoBrote'] == true ? Colors.red : Colors.green,
                Icons.warning_amber_rounded,
                "${stats['mesesConBrote']}/${stats['totalMeses']} meses")),
      ],
    );
  }

  Widget _redesignTendenciaClinica(List<Map<String, dynamic>> controls) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Tendencia clínica",
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A))),
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text("Pase el cursor para ver detalle",
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _redesignSingleChart("Dolor EVA (0-10)", controls,
              (c) => (c['puntos_dolor'] ?? 0).toDouble(), Colors.red, "pain"),
          const SizedBox(height: 20),
          _redesignSingleChart(
              "Energía (0-10)",
              controls,
              (c) => (c['nivel_fatiga'] ?? 10).toDouble(),
              Colors.green,
              "energy"),
        ],
      ),
    );
  }

  Widget _redesignSingleChart(
      String title,
      List<Map<String, dynamic>> controls,
      double Function(Map<String, dynamic>) getValue,
      Color color,
      String type) {
    final spots = controls
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), getValue(e.value)))
        .toList();
    final double maxVal =
        spots.isEmpty ? 10 : spots.map((s) => s.y).reduce(max);

    // Escala dinámica: se adapta pero mantiene bases lógicas para EVA (5 o 10)
    double calculatedMaxY = 10.0;
    if (maxVal <= 5) {
      calculatedMaxY = 5.0;
    } else if (maxVal <= 10) {
      calculatedMaxY = 10.0;
    } else {
      calculatedMaxY = (maxVal * 1.2).ceilToDouble();
    }

    final bool isPain = type == "pain";
    final List<(double, double, Color)> bands = isPain
        ? const [
            (0, 2, Color(0x0D2E7D32)),
            (3, 6, Color(0x0DF59E0B)),
            (7, 10, Color(0x0DF87171))
          ]
        : const [
            (0, 3, Color(0x0DF87171)),
            (4, 6, Color(0x0DF59E0B)),
            (7, 10, Color(0x0D2E7D32))
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155))),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: spots.length <= 1 ? 1 : (spots.length - 1).toDouble(),
              minY: 0,
              maxY: calculatedMaxY,
              rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
                for (final b in bands)
                  HorizontalRangeAnnotation(y1: b.$1, y2: b.$2, color: b.$3)
              ]),
              gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                      color: const Color(0xFFE2E8F0),
                      strokeWidth: 1,
                      dashArray: [4, 4])),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 2.5,
                  dotData:
                      const FlDotData(show: true, getDotPainter: _getSmallDot),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: calculatedMaxY / 2,
                        getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8))))),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final idx = v.round();
                          if ((v - idx).abs() > 0.01) {
                            return const SizedBox.shrink();
                          }
                          if (idx < 0 || idx >= controls.length)
                            return const SizedBox.shrink();
                          return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                  (controls[idx]['mes_label'] ??
                                          _monthShort(controls[idx]
                                                  ['fecha_control'] ??
                                              ""))
                                      .toString(),
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8))));
                        })),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
                    .map((i) => TouchedSpotIndicatorData(
                        FlLine(
                            color: color.withOpacity(0.15), strokeWidth: 1.5),
                        FlDotData(show: true, getDotPainter: _getSmallDot)))
                    .toList(),
                touchTooltipData: _redesignTooltipData(controls, type),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static FlDotPainter _getSmallDot(
          FlSpot spot, double xPercentage, LineChartBarData bar, int index) =>
      FlDotCirclePainter(
          radius: 3,
          color: bar.color ?? Colors.red,
          strokeWidth: 1,
          strokeColor: Colors.white);

  LineTouchTooltipData _redesignTooltipData(
      List<Map<String, dynamic>> controls, String type) {
    return LineTouchTooltipData(
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipColor: (_) => Colors.white,
      tooltipPadding: const EdgeInsets.all(8),
      tooltipBorder: const BorderSide(color: Color(0xFFE2E8F0)),
      getTooltipItems: (items) {
        if (items.isEmpty) return [];
        final idx = items.first.x.toInt();
        if (idx < 0 || idx >= controls.length) return [];
        final c = controls[idx];
        final bool isPain = type == "pain";
        final value = isPain
            ? _numValue(c['puntos_dolor'], 0)
            : _numValue(c['nivel_fatiga'], 10);
        final color = isPain ? Colors.red : Colors.green;
        final label = isPain ? "Dolor" : "Energía";

        String estado = "";
        if (isPain) {
          int v = value.round();
          if (v <= 2)
            estado = "Bajo";
          else if (v <= 6)
            estado = "Moderado";
          else
            estado = "Alta actividad";
        } else {
          int v = value.round();
          if (v <= 3)
            estado = "Baja";
          else if (v <= 6)
            estado = "Moderada";
          else
            estado = "Adecuada";
        }

        return [
          LineTooltipItem(
            "",
            const TextStyle(),
            children: [
              TextSpan(
                  text:
                      "${(c['mes_label_largo'] ?? _monthShort(c['fecha_control']?.toString() ?? '')).toString()}\n",
                  style: GoogleFonts.inter(
                      fontSize: 8,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600)),
              TextSpan(
                  text: "$label: ",
                  style: GoogleFonts.inter(
                      fontSize: 10, color: color, fontWeight: FontWeight.w900)),
              TextSpan(
                  text: "${value.toStringAsFixed(1)}/10\n",
                  style: GoogleFonts.inter(
                      fontSize: 10, color: color, fontWeight: FontWeight.w900)),
              TextSpan(
                  text: "Controles: ",
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800)),
              TextSpan(
                  text: "${c['controles_mes'] ?? 1}\n",
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w600)),
              TextSpan(
                  text: "Estado: ",
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800)),
              TextSpan(
                  text: "$estado\n",
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w600)),
              TextSpan(
                  text: "Brote: ",
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800)),
              TextSpan(
                  text: "${c['en_brote'] == true ? 'Sí' : 'No'}",
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: c['en_brote'] == true ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ];
      },
    );
  }

  Widget _redesignLecturaRapida(Map<String, dynamic> stats) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: const BoxDecoration(
                color: Color(0xFF004FC4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
            child: Text("Lectura clínica rápida",
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _lecturaItem(Icons.track_changes_outlined, "Promedio dolor:",
                    stats['promedioDolor'].toStringAsFixed(1), Colors.red),
                _lecturaItem(Icons.bolt, "Promedio energía:",
                    stats['promedioEnergia'].toStringAsFixed(1), Colors.green),
                _lecturaItem(
                    Icons.warning_amber_rounded,
                    "Brotes:",
                    "${stats['mesesConBrote']} meses / ${stats['controlesConBrote']} controles",
                    Colors.red),
                _lecturaItem(
                    Icons.calendar_today_outlined,
                    "Último mes:",
                    _monthShort(stats['ultimoControlFecha']?.toString() ?? ''),
                    const Color(0xFF004FC4)),
                _lecturaItem(Icons.show_chart_rounded, "Patrón clínico:",
                    stats['patronClinico'], const Color(0xFF004FC4),
                    isMultiLine: true),
                if (stats['altaActividad'] == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFEE2E2))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text("Alta actividad",
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lecturaItem(IconData icon, String label, String value, Color color,
          {bool isMultiLine = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: isMultiLine
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isMultiLine
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Flexible(
                      child: Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  Flexible(
                      child: Text(value,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isMultiLine
                                  ? const Color(0xFF0F172A)
                                  : color))),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _redesignUltimosControles(List<Map<String, dynamic>> controls) {
    final recent =
        _sortControlsByDate(controls, descending: true).take(3).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off_rounded,
                  size: 14, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Text("Top 3 controles recientes",
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.8),
              1: FlexColumnWidth(4),
              2: FlexColumnWidth(4),
              3: FlexColumnWidth(1)
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                children: [
                  _tableHeader("Fecha"),
                  _tableHeader("Dolor (0-10)"),
                  _tableHeader("Energía (0-10)"),
                  _tableHeader("Brote"),
                ],
              ),
              for (final c in recent)
                TableRow(
                  decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: Color(0xFFF8FAFC)))),
                  children: [
                    _tableCell(_formatIsoDate(c['fecha_control'])),
                    _tableBarCell((c['puntos_dolor'] ?? 0).toInt(), Colors.red),
                    _tableBarCell(
                        (c['nivel_fatiga'] ?? 10).toInt(), Colors.green),
                    _tableBadgeCell(c['en_brote'] == true),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(t,
          style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B))));
  Widget _tableCell(String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(t,
          style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A))));
  Widget _tableBarCell(int val, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
                width: 14,
                child: Text("$val",
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A)))),
            const SizedBox(width: 6),
            Expanded(
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                        value: val / 10,
                        minHeight: 3.5,
                        backgroundColor: color.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(color)))),
          ],
        ),
      );
  Widget _tableBadgeCell(bool brote) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color:
                    brote ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(4)),
            child: Text(brote ? "Sí" : "No",
                style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: brote ? Colors.red : Colors.green)),
          ),
        ),
      );

  Widget _redesignInterpretacion(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDBEAFE))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Color(0xFF004FC4), shape: BoxShape.circle),
                  child: const Icon(Icons.description_outlined,
                      color: Colors.white, size: 12)),
              const SizedBox(width: 10),
              Text("Interpretación",
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF004FC4))),
            ],
          ),
          const SizedBox(height: 8),
          Text(stats['interpretacion'],
              style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                  height: 1.3)),
          const SizedBox(height: 10),
          Row(
            children: [
              if (stats['altaActividad'] == true)
                _interpretPill("Alta actividad", Colors.red),
              if (stats['promedioDolor'] >= 7 || stats['controlesConBrote'] > 0)
                _interpretPill("Seguimiento estrecho", const Color(0xFF004FC4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _interpretPill(String t, Color color) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Text(t,
            style: GoogleFonts.inter(
                fontSize: 8, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _buildEvolutionDashboard(Map<String, dynamic>? evo) {
    if (evo == null) return const SizedBox.shrink();
    final controls = _evoFilteredControls(evo);
    if (controls.isEmpty) return const SizedBox.shrink();

    final monthlyControls = _groupEvoControlsByMonth(controls);
    if (monthlyControls.isEmpty) return const SizedBox.shrink();
    final stats = _calculateEvoStats(monthlyControls);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _redesignHeader(),
        const SizedBox(height: 14),
        _redesignSummaryCards(stats),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  flex: 2, child: _redesignTendenciaClinica(monthlyControls)),
              const SizedBox(width: 14),
              Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(child: _redesignLecturaRapida(stats)),
                      const SizedBox(height: 14),
                      _redesignInterpretacion(stats),
                    ],
                  )),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _redesignUltimosControles(controls),
        const SizedBox(height: 32),
        _buildEvoActivitySection(controls),
        const SizedBox(height: 10),
        _buildEvoInflammationSectionV2(controls),
        const SizedBox(height: 10),
        _buildEvoHeatmapSection(controls),
        const SizedBox(height: 10),
        _buildEvoGrowthSection(
            controls, Map<String, dynamic>.from(evo['paciente'] ?? {})),
        const SizedBox(height: 10),
        _buildEvoImpactSection(controls),
      ],
    );
  }

  List<Map<String, dynamic>> _evoFilteredControls(Map<String, dynamic> evo) {
    final raw = (evo['controles'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final ranges = {
      "6": 6,
      "12": 12,
      "24": 24,
    };
    var items = raw;
    if (_evoRango != "all" &&
        ranges.containsKey(_evoRango) &&
        raw.length > ranges[_evoRango]!) {
      items = raw.sublist(raw.length - ranges[_evoRango]!).toList();
    } else if (_evoRango == "year") {
      final currentYear = DateTime.now().year;
      items = raw
          .where((c) =>
              DateTime.tryParse((c['fecha_control'] ?? '').toString())?.year ==
              currentYear)
          .toList();
    } else if (_evoRango == "custom" && _expediente != null) {
      items = raw;
    }
    if (_evoEstadoEnfermedad != "todo") {
      items = items
          .where((c) =>
              (c['estado_enfermedad'] ?? '').toString().toLowerCase() ==
              _evoEstadoEnfermedad.toLowerCase())
          .toList();
    }
    if (_evoBrote != "todos") {
      final want = _evoBrote == "si";
      items = items
          .where((c) =>
              bool.tryParse(c['en_brote']?.toString() ?? "false") == want ||
              (c['en_brote'] == true) == want)
          .toList();
    }
    if (_evoEstadoNutricional != "todo") {
      items = items
          .where((c) =>
              (c['estado_nutricional'] ?? '').toString().toLowerCase() ==
              _evoEstadoNutricional.toLowerCase())
          .toList();
    }
    if (_evoSoloAlterados) {
      items = items.where((c) {
        final z = double.tryParse(
                (c['prediagnostico']?['z_score_bmi'] ?? c['z_score_bmi'] ?? 0)
                    .toString()) ??
            0;
        return (int.tryParse(c['puntos_dolor']?.toString() ?? "0") ?? 0) >= 5 ||
            (int.tryParse(c['nivel_fatiga']?.toString() ?? "10") ?? 10) <= 4 ||
            (int.tryParse(c['escala_inflamacion']?.toString() ?? "0") ?? 0) >=
                2 ||
            (int.tryParse(c['articulaciones_inflamadas']?.toString() ?? "0") ??
                    0) >
                0 ||
            (int.tryParse(c['articulaciones_dolorosas']?.toString() ?? "0") ??
                    0) >
                0 ||
            (int.tryParse(c['minutos_rigidez']?.toString() ?? "0") ?? 0) >=
                30 ||
            c['en_brote'] == true ||
            !["normal", "eutrófico", "eutrofico"].contains(
                (c['estado_nutricional'] ?? '').toString().toLowerCase()) ||
            z.abs() > 2;
      }).toList();
    }
    return _sortControlsByDate(items);
  }

  Widget _buildEvoFilterBar(Map<String, dynamic> evo) {
    final controls = (evo['controles'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final states = <String>{};
    final nutritions = <String>{};
    for (final c in controls) {
      if ((c['estado_enfermedad'] ?? '').toString().isNotEmpty)
        states.add(c['estado_enfermedad'].toString());
      if ((c['estado_nutricional'] ?? '').toString().isNotEmpty)
        nutritions.add(c['estado_nutricional'].toString());
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _evoDropdown(
            "Rango",
            _evoRango,
            {
              "6": "Últimos 6 controles",
              "12": "Últimos 12 controles",
              "24": "Últimos 24 controles",
              "year": "Año actual",
              "all": "Todo el historial",
            },
            (v) => setState(() => _evoRango = v)),
        _evoDropdown(
            "Estado",
            _evoEstadoEnfermedad,
            {
              "todo": "Todos",
              for (final s in states) s: s,
            },
            (v) => setState(() => _evoEstadoEnfermedad = v)),
        _evoDropdown(
            "Brote",
            _evoBrote,
            {
              "todos": "Todos",
              "si": "Solo con brote",
              "no": "Solo sin brote",
            },
            (v) => setState(() => _evoBrote = v)),
        _evoDropdown(
            "Nutrición",
            _evoEstadoNutricional,
            {
              "todo": "Todos",
              for (final s in nutritions) s: s,
            },
            (v) => setState(() => _evoEstadoNutricional = v)),
        FilterChip(
          label: const Text("Solo alterados"),
          selected: _evoSoloAlterados,
          onSelected: (v) => setState(() => _evoSoloAlterados = v),
          selectedColor: Colors.red.shade50,
          checkmarkColor: Colors.red,
        ),
      ],
    );
  }

  Widget _buildEvoTopBanner(
      Map<String, dynamic> selected, Map<String, dynamic> resumen) {
    final estado = (selected['estado_enfermedad'] ?? 'Seguimiento').toString();
    final dolor = (selected['puntos_dolor'] ?? 0).toString();
    final energia = (selected['nivel_fatiga'] ?? 10).toString();
    final inflamacion = (selected['escala_inflamacion'] ?? 0).toString();
    final brote = selected['en_brote'] == true;
    final z = _formatNum((selected['prediagnostico']?['z_score_bmi'] ??
        selected['z_score_bmi'] ??
        0));
    final info =
        "Dolor $dolor/10, energía $energia/10, inflamación $inflamacion/3, brote ${brote ? 'sí' : 'no'} y z-score $z.";
    final color = brote ||
            (int.tryParse(dolor) ?? 0) >= 7 ||
            (int.tryParse(inflamacion) ?? 0) >= 2
        ? Colors.red
        : ((int.tryParse(dolor) ?? 0) <= 2 && (int.tryParse(energia) ?? 10) >= 7
            ? Colors.green
            : Colors.orange);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FFFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Paciente en $estado. $info",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  height: 1.35),
            ),
          ),
          const SizedBox(width: 12),
          _stateChip(brote ? "Brote activo" : "Sin brote",
              brote ? Colors.red : Colors.green),
        ],
      ),
    );
  }

  Widget _evoDropdown(String label, String value, Map<String, String> options,
      void Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.containsKey(value) ? value : options.keys.first,
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          items: options.entries
              .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text("$label: ${e.value}",
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildEvoSummaryCards(
      List<Map<String, dynamic>> controls, Map<String, dynamic> resumen) {
    final last = controls.last;
    final z = double.tryParse(
            (last['prediagnostico']?['z_score_bmi'] ?? last['z_score_bmi'] ?? 0)
                .toString()) ??
        0;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _smallMetricCard("Dolor actual", "${last['puntos_dolor'] ?? 0}/10",
            _severityColor((last['puntos_dolor'] ?? 0).toInt(), 0, 2, 6)),
        _smallMetricCard("Energía", "${last['nivel_fatiga'] ?? 10}/10",
            _energyColor((last['nivel_fatiga'] ?? 10).toInt())),
        _smallMetricCard("Inflamación", "${last['escala_inflamacion'] ?? 0}/3",
            _inflammationColor((last['escala_inflamacion'] ?? 0).toInt())),
        _smallMetricCard("Art. inflamadas",
            "${last['articulaciones_inflamadas'] ?? 0}", Colors.blueGrey),
        _smallMetricCard(
            "Rigidez", "${last['minutos_rigidez'] ?? 0} min", Colors.indigo),
        _smallMetricCard(
            "Estado nut.",
            last['estado_nutricional']?.toString() ?? "-",
            _nutriColor(last['estado_nutricional']?.toString() ?? "")),
        _smallMetricCard("Z-score", z.toStringAsFixed(1), _zScoreColor(z)),
        _smallMetricCard("Brote", last['en_brote'] == true ? "Sí" : "No",
            last['en_brote'] == true ? Colors.red : Colors.green),
      ],
    );
  }

  Widget _smallMetricCard(String title, String value, Color color) => SizedBox(
        width: 150,
        child: _metricCard(title, value, color),
      );

  Widget _metricCard(String title, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.blueGrey)),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );

  Color _severityColor(int v, int low, int medium, int high) {
    if (v <= low) return Colors.green;
    if (v <= medium) return Colors.orange;
    return Colors.red;
  }

  Color _energyColor(int v) {
    if (v <= 3) return Colors.red;
    if (v <= 6) return Colors.orange;
    return Colors.green;
  }

  Color _inflammationColor(int v) {
    if (v == 0) return Colors.green;
    if (v == 1) return Colors.yellow.shade800;
    if (v == 2) return Colors.orange;
    return Colors.red;
  }

  Color _zScoreColor(double z) {
    if (z < -2 || z > 2) return Colors.red;
    if (z > 1) return Colors.orange;
    return Colors.green;
  }

  Widget _buildEvoSymptomsSection(List<Map<String, dynamic>> controls) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              "1. Evolución mensual de síntomas", Icons.healing_outlined),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _realLineChart(
                      "Dolor EVA 0-10",
                      controls,
                      (c) => (c['puntos_dolor'] ?? 0).toDouble(),
                      Colors.red,
                      (c) => _painTooltip(c),
                      bands: const [
                    (0, 2, Color(0x1A2E7D32)),
                    (3, 6, Color(0x1AF59E0B)),
                    (7, 10, Color(0x1AF87171))
                  ])),
              const SizedBox(width: 12),
              Expanded(
                  child: _realLineChart(
                      "Energía 0-10",
                      controls,
                      (c) => (c['nivel_fatiga'] ?? 10).toDouble(),
                      Colors.green,
                      (c) => _energyTooltip(c),
                      bands: const [
                    (0, 3, Color(0x1AF87171)),
                    (4, 6, Color(0x1AF59E0B)),
                    (7, 10, Color(0x1A2E7D32))
                  ])),
            ],
          ),
          const SizedBox(height: 10),
          _evoSummaryRow(controls, type: "symptoms"),
        ],
      ),
    );
  }

  Widget _buildEvoActivitySection(List<Map<String, dynamic>> controls) {
    if (controls.isEmpty) return const SizedBox.shrink();

    // Cálculos dinámicos
    final orderedControls = _sortControlsByDate(controls);
    final chartControls = _groupActivityControlsByMonth(orderedControls);
    final last = orderedControls.last;
    final prev = orderedControls.length > 1
        ? orderedControls[orderedControls.length - 2]
        : null;

    final int inflActual =
        _numValue(last['articulaciones_inflamadas'], 0).round();
    final int dolActual =
        _numValue(last['articulaciones_dolorosas'], 0).round();
    final int rigActual = _numValue(last['minutos_rigidez'], 0).round();
    final int inflPrev = prev == null
        ? inflActual
        : _numValue(prev['articulaciones_inflamadas'], 0).round();
    final int dolPrev = prev == null
        ? dolActual
        : _numValue(prev['articulaciones_dolorosas'], 0).round();
    final int rigPrev = prev == null
        ? rigActual
        : _numValue(prev['minutos_rigidez'], 0).round();

    final int inflMax = orderedControls
        .map((c) => _numValue(c['articulaciones_inflamadas'], 0))
        .reduce(max)
        .round();
    final int dolMax = orderedControls
        .map((c) => _numValue(c['articulaciones_dolorosas'], 0))
        .reduce(max)
        .round();
    final int rigMax = orderedControls
        .map((c) => _numValue(c['minutos_rigidez'], 0))
        .reduce(max)
        .round();

    final double rigAvg = orderedControls
            .map((c) => _numValue(c['minutos_rigidez'], 0))
            .reduce((a, b) => a + b) /
        orderedControls.length;
    final int rigCambio = rigActual - rigPrev;
    final int inflCambio = inflActual - inflPrev;
    final int dolCambio = dolActual - dolPrev;
    final String rigCambioTexto = prev == null
        ? "Sin control previo"
        : (rigCambio == 0
            ? "No hubo cambios (0 min)"
            : "${rigCambio > 0 ? '+' : ''}$rigCambio min");

    // Interpretación dinámica
    String cambioTexto(String label, int delta, String unit) {
      if (prev == null) return "$label sin control previo";
      if (delta == 0) return "$label sin cambios";
      return "$label ${delta < 0 ? 'mejoró' : 'empeoró'} ${delta.abs()} $unit";
    }

    final int actividadActual = inflActual + dolActual;
    final int actividadPrevia = inflPrev + dolPrev;
    final int actividadCambio = actividadActual - actividadPrevia;
    final String actividadLectura = actividadActual == 0
        ? "sin actividad articular registrada en el último control"
        : "$inflActual articulaciones inflamadas y $dolActual dolorosas en el último control";
    final String tendenciaLectura = prev == null
        ? "No hay control previo para establecer tendencia inmediata."
        : (actividadCambio == 0 && rigCambio == 0
            ? "No hubo cambios frente al control anterior."
            : [
                cambioTexto("inflamadas", inflCambio, "art."),
                cambioTexto("dolorosas", dolCambio, "art."),
                cambioTexto("rigidez", rigCambio, "min"),
              ].join("; "));
    final String rigidezLectura = rigCambio < 0
        ? "La rigidez mejoró ${rigCambio.abs()} minutos frente al control previo."
        : (rigCambio > 0
            ? "La rigidez empeoró $rigCambio minutos frente al control previo."
            : "La rigidez no cambió frente al control previo.");
    final String interpretacion =
        "En el periodo evaluado se analizaron ${orderedControls.length} controles en ${chartControls.length} meses. El último control muestra $actividadLectura, con rigidez matutina de $rigActual min. El máximo del periodo fue $inflMax inflamadas, $dolMax dolorosas y $rigMax min de rigidez; el promedio de rigidez fue ${rigAvg.toStringAsFixed(1)} min. $tendenciaLectura $rigidezLectura";
    /*
      String interpretacion =
          "Durante el periodo observado, el paciente presenta ";
    if (inflMax > 0 || dolMax > 0) {
      interpretacion +=
          "actividad articular ${inflActual > 5 ? 'persistente' : 'variable'}, con hasta $inflMax articulaciones inflamadas y $dolMax dolorosas. ";
    } else {
      interpretacion +=
          "ausencia de inflamación y dolor articular significativo. ";
    }
    interpretacion +=
        "La rigidez matutina alcanzó un máximo de $rigMax minutos. ";
    if (rigCambio < 0)
      interpretacion +=
          "Se observa una mejoría en la rigidez respecto al control anterior.";
    else if (rigCambio > 0)
      interpretacion +=
          "La rigidez ha aumentado, lo que sugiere mayor actividad matutina.";

    */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade100)),
              child: const Icon(Icons.accessibility_new_rounded,
                  color: Color(0xFF2E7D32), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("2. Actividad articular",
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A))),
                Text(
                    "Seguimiento de articulaciones inflamadas, dolorosas y rigidez matutina del paciente",
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Área principal de gráficas
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart_rounded,
                      size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text("Evolución articular",
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 12, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                        "Cada gráfica ajusta automáticamente su escala según el rango de valores del paciente.",
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1. Inflamadas
              _jointRowChart(
                  "Articulaciones inflamadas",
                  chartControls,
                  (c) => (c['articulaciones_inflamadas'] ?? 0).toDouble(),
                  Colors.green,
                  inflActual,
                  inflMax,
                  "inflamadas"),
              const Divider(height: 32, color: Color(0xFFF1F5F9)),

              // 2. Dolorosas
              _jointRowChart(
                  "Articulaciones dolorosas",
                  chartControls,
                  (c) => (c['articulaciones_dolorosas'] ?? 0).toDouble(),
                  Colors.orange,
                  dolActual,
                  dolMax,
                  "dolorosas"),
              const Divider(height: 32, color: Color(0xFFF1F5F9)),

              // 3. Rigidez
              _jointRowChart(
                  "Rigidez matutina (min)",
                  chartControls,
                  (c) => (c['minutos_rigidez'] ?? 0).toDouble(),
                  Colors.blue,
                  rigActual,
                  rigMax,
                  "rigidez"),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Footer de Resumen e Interpretación
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen del periodo
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.assignment_outlined,
                          size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text("Resumen del periodo",
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w800))
                    ]),
                    const SizedBox(height: 16),
                    _footerStatItem(Icons.analytics_outlined, "Prom. rigidez",
                        "${rigAvg.toStringAsFixed(1)} min"),
                    _footerStatItem(Icons.timer_outlined, "Última rigidez",
                        "$rigActual min"),
                    _footerStatItem(Icons.compare_arrows_rounded,
                        "Cambio vs anterior", rigCambioTexto),
                    _footerStatItem(Icons.fact_check_outlined,
                        "Controles analizados", "${orderedControls.length}"),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Interpretación
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.description_outlined,
                          size: 14, color: Colors.green),
                      const SizedBox(width: 8),
                      Text("Interpretación de la actividad articular",
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w800))
                    ]),
                    const SizedBox(height: 10),
                    Text(interpretacion,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF334155),
                            height: 1.4,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (inflActual > 0 || dolActual > 0)
                          _interpretPill("Actividad persistente", Colors.green),
                        _interpretPill("Seguimiento clínico", Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _jointRowChart(
      String title,
      List<Map<String, dynamic>> controls,
      double Function(Map<String, dynamic>) getValue,
      Color color,
      int actual,
      int maxVal,
      String type) {
    // Cálculo de escala dinámica con margen de seguridad
    double maxY = 5.0;
    if (type == "rigidez") {
      if (maxVal <= 30)
        maxY = 30;
      else if (maxVal <= 60)
        maxY = 60;
      else if (maxVal <= 120)
        maxY = 120;
      else
        maxY = ((maxVal / 30).ceil() * 30 + 30).toDouble();
    } else {
      if (maxVal < 5)
        maxY = 5;
      else if (maxVal < 10)
        maxY = 10;
      else if (maxVal < 20)
        maxY = 20;
      else
        maxY = ((maxVal / 5).ceil() * 5 + 5).toDouble();
    }

    final spots = controls
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), getValue(e.value)))
        .toList();

    return IntrinsicHeight(
      child: Row(
        children: [
          // Etiqueta lateral
          Container(
            width: 100,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(height: 6),
                Text(title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Gráfica
          Expanded(
            child: SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: spots.length <= 1 ? 1 : (spots.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(
                          color: const Color(0xFFF1F5F9), strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, p, bar, i) =>
                              FlDotCirclePainter(
                                  radius: 3,
                                  color: color,
                                  strokeWidth: 1,
                                  strokeColor: Colors.white)),
                      belowBarData: BarAreaData(
                          show: true, color: color.withOpacity(0.02)),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: maxY / 2,
                            getTitlesWidget: (v, meta) => Text(
                                v.toInt().toString(),
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF94A3B8))))),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            interval: 1,
                            getTitlesWidget: (v, meta) {
                              final idx = v.round();
                              if ((v - idx).abs() > 0.01) {
                                return const SizedBox.shrink();
                              }
                              if (idx < 0 || idx >= controls.length)
                                return const SizedBox.shrink();
                              return Text(
                                  (controls[idx]['mes_label'] ??
                                          _monthShort(controls[idx]
                                                  ['fecha_control'] ??
                                              ""))
                                      .toString(),
                                  style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8)));
                            })),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => Colors.white,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipBorder: BorderSide(color: color.withOpacity(0.2)),
                      getTooltipItems: (items) => items.map((it) {
                        final idx = it.x.round();
                        if (idx < 0 || idx >= controls.length) {
                          return null;
                        }
                        final c = controls[idx];
                        return LineTooltipItem("", const TextStyle(),
                            children: [
                              TextSpan(
                                  text:
                                      "${(c['mes_label_largo'] ?? _monthShort(c['fecha_control']?.toString() ?? '')).toString()}\n",
                                  style: GoogleFonts.inter(
                                      fontSize: 8,
                                      color: const Color(0xFF64748B))),
                              TextSpan(
                                  text:
                                      "${type == 'rigidez' ? 'Rigidez' : (type == 'inflamadas' ? 'Inflamadas' : 'Dolorosas')}: ",
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600)),
                              TextSpan(
                                  text:
                                      "${it.y.toStringAsFixed(type == 'rigidez' ? 0 : 1)}${type == 'rigidez' ? ' min' : ''}\n",
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: color)),
                              TextSpan(
                                  text:
                                      "Controles del mes: ${c['controles_mes'] ?? 1}",
                                  style: GoogleFonts.inter(
                                      fontSize: 8,
                                      color: const Color(0xFF64748B))),
                            ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Indicadores Actual/Máximo
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Actual",
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B))),
                Text("$actual",
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color)),
                const SizedBox(height: 6),
                Text("Máximo",
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B))),
                Text("$maxVal",
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerStatItem(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
            const Spacer(),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A))),
          ],
        ),
      );

  List<Map<String, dynamic>> _groupInflammationControlsByMonth(
      List<Map<String, dynamic>> controls) {
    final sorted = _sortControlsByDate(controls);
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final c in sorted) {
      final dt = _controlDate(c);
      if (dt == null) continue;
      grouped.putIfAbsent(_monthKey(dt), () => <Map<String, dynamic>>[]).add(c);
    }

    return grouped.entries.map((entry) {
      final items = entry.value;
      final firstDate = _controlDate(items.first)!;
      final lastControl = items.last;
      final infl = items
              .map((c) => _numValue(c['escala_inflamacion'], 0))
              .reduce((a, b) => a + b) /
          items.length;
      final brotes = items.where((c) => c['en_brote'] == true).length;
      return {
        ...lastControl,
        'fecha_control':
            DateTime(firstDate.year, firstDate.month, 1).toIso8601String(),
        'fecha_control_real': lastControl['fecha_control'],
        'mes_label': _monthLabel(firstDate),
        'mes_label_largo': _monthLabel(firstDate, withYear: true),
        'controles_mes': items.length,
        'escala_inflamacion': infl,
        'en_brote': brotes > 0,
        'brotes_mes': brotes,
      };
    }).toList();
  }

  Widget _buildEvoInflammationSectionV2(List<Map<String, dynamic>> controls) {
    if (controls.isEmpty) return const SizedBox.shrink();

    final orderedControls = _sortControlsByDate(controls);
    final monthlyControls = _groupInflammationControlsByMonth(orderedControls);
    if (monthlyControls.isEmpty) return const SizedBox.shrink();

    final last = orderedControls.last;
    final prev = orderedControls.length > 1
        ? orderedControls[orderedControls.length - 2]
        : null;
    final lastSix = orderedControls.length <= 6
        ? orderedControls
        : orderedControls.sublist(orderedControls.length - 6);

    final inflActual = _numValue(last['escala_inflamacion'], 0);
    final inflPrev =
        prev == null ? inflActual : _numValue(prev['escala_inflamacion'], 0);
    final inflCambio = inflActual - inflPrev;
    final inflMax = orderedControls
        .map((c) => _numValue(c['escala_inflamacion'], 0))
        .reduce(max);
    final inflAvg = orderedControls
            .map((c) => _numValue(c['escala_inflamacion'], 0))
            .reduce((a, b) => a + b) /
        orderedControls.length;
    final brotesTotal =
        orderedControls.where((c) => c['en_brote'] == true).length;
    final brotesUltimos6 = lastSix.where((c) => c['en_brote'] == true).length;
    final ultimoEstado =
        (last['estado_enfermedad'] ?? 'Seguimiento').toString();
    final ultimoMes =
        _monthFullFromRaw(last['fecha_control']?.toString() ?? '');
    final primerMes = _monthFullFromRaw(
        monthlyControls.first['fecha_control']?.toString() ?? '');
    final ultimoMesGrafica = _monthFullFromRaw(
        monthlyControls.last['fecha_control']?.toString() ?? '');
    final monthlyDelta =
        _numValue(monthlyControls.last['escala_inflamacion'], 0) -
            _numValue(monthlyControls.first['escala_inflamacion'], 0);

    final tendenciaTexto = monthlyControls.length < 2
        ? "no permite definir tendencia mensual"
        : (monthlyDelta < 0
            ? "muestra disminución mensual de la inflamación"
            : (monthlyDelta > 0
                ? "muestra aumento mensual de la inflamación"
                : "se mantiene estable entre $primerMes y $ultimoMesGrafica"));
    final broteTexto = brotesUltimos6 == 0
        ? "no se registran brotes en los últimos ${lastSix.length} controles"
        : "se registran $brotesUltimos6 brotes en los últimos ${lastSix.length} controles";
    final cambioClinicoTexto = inflCambio == 0
        ? "no hubo cambios"
        : (inflCambio > 0
            ? "empeoró ${_pointsText(inflCambio.abs())}"
            : "mejoró ${_pointsText(inflCambio.abs())}");
    final interpretacion =
        "La gráfica mensual $tendenciaTexto. La inflamación actual es ${inflActual.toStringAsFixed(0)}/3, con promedio del periodo ${inflAvg.toStringAsFixed(1)}/3 y máximo ${inflMax.toStringAsFixed(0)}/3. Frente al control anterior, $cambioClinicoTexto. En todo el periodo hay $brotesTotal controles con brote; en las últimas evaluaciones, $broteTexto. El estado clínico actual es $ultimoEstado en $ultimoMes.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.shade100)),
              child: const Icon(Icons.coronavirus_outlined,
                  color: Colors.purple, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("3. Inflamación y estado clínico",
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A))),
                Text(
                    "Seguimiento mensual de inflamación, estado clínico y brote",
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                  width: 190,
                  child: _footerMetricCard(
                      "Inflamación actual",
                      "${inflActual.toStringAsFixed(0)}/3",
                      _inflammationColor(inflActual.round()),
                      Icons.local_fire_department_rounded)),
              const SizedBox(width: 10),
              SizedBox(
                  width: 190,
                  child: _footerMetricCard(
                      "Brotes últimos 6",
                      "$brotesUltimos6/${lastSix.length}",
                      Colors.red,
                      Icons.warning_amber_rounded)),
              const SizedBox(width: 10),
              SizedBox(
                  width: 190,
                  child: _footerMetricCard("Estado actual", ultimoEstado,
                      _stateColor(ultimoEstado), Icons.verified_user_rounded)),
              const SizedBox(width: 10),
              SizedBox(
                  width: 190,
                  child: _footerMetricCard(
                      "Evaluaciones",
                      "${orderedControls.length}",
                      Colors.blueGrey,
                      Icons.fact_check_outlined)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _inflammationMonthlyChart(monthlyControls),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 1,
              child: _clinicalStateBroteTimeline(lastSix),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFFBFDFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.05),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.assignment_outlined,
                      size: 18, color: Color(0xFF0F172A))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Interpretación clínica",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Text(interpretacion,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF334155),
                            height: 1.4,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inflammationMonthlyChart(List<Map<String, dynamic>> controls) {
    final maxInfl =
        controls.map((c) => _numValue(c['escala_inflamacion'], 0)).reduce(max);
    final spots = controls
        .asMap()
        .entries
        .map((e) => FlSpot(
            e.key.toDouble(), _numValue(e.value['escala_inflamacion'], 0)))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Evolución mensual de inflamación (0-3)",
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  Text(
                      "Un punto por mes; valores agregados por promedio mensual",
                      style: GoogleFonts.inter(
                          fontSize: 9, color: Colors.blueGrey)),
                ],
              ),
              _legendItem("Inflamación", Colors.purple),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: spots.length <= 1 ? 1 : (spots.length - 1).toDouble(),
                minY: 0,
                maxY: max(3.0, maxInfl + 0.5),
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: const Color(0xFFF1F5F9),
                        strokeWidth: 1,
                        dashArray: [4, 4])),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.purple,
                    barWidth: 3,
                    dotData: const FlDotData(
                        show: true, getDotPainter: _getInflammationDot),
                    belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.purple.withOpacity(0.15),
                              Colors.purple.withOpacity(0.01)
                            ])),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (v, meta) => Text(
                              v.toInt().toString(),
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8))))),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 1,
                          getTitlesWidget: (v, meta) {
                            final idx = v.round();
                            if ((v - idx).abs() > 0.01 ||
                                idx < 0 ||
                                idx >= controls.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                    (controls[idx]['mes_label'] ??
                                            _monthShort(controls[idx]
                                                    ['fecha_control'] ??
                                                ""))
                                        .toString(),
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF94A3B8))));
                          })),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipBorder: const BorderSide(color: Color(0xFFE2E8F0)),
                    getTooltipItems: (items) => items.map((it) {
                      final idx = it.x.round();
                      if (idx < 0 || idx >= controls.length) return null;
                      final c = controls[idx];
                      return LineTooltipItem("", const TextStyle(), children: [
                        TextSpan(
                            text:
                                "${(c['mes_label_largo'] ?? _monthShort(c['fecha_control']?.toString() ?? '')).toString()}\n",
                            style: GoogleFonts.inter(
                                fontSize: 8, color: const Color(0xFF64748B))),
                        TextSpan(
                            text: "Inflamación: ",
                            style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w600)),
                        TextSpan(
                            text: "${it.y.toStringAsFixed(1)}/3\n",
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.purple)),
                        TextSpan(
                            text:
                                "Brotes del mes: ${c['brotes_mes'] ?? 0} | Controles: ${c['controles_mes'] ?? 1}",
                            style: GoogleFonts.inter(
                                fontSize: 8, color: const Color(0xFF64748B))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(_generateInflammationHint(controls),
              style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _clinicalStateBroteTimeline(List<Map<String, dynamic>> controls) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.timeline_rounded, size: 14, color: Colors.purple),
            const SizedBox(width: 8),
            Text("Estado y brote últimos 6 controles",
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w800))
          ]),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final count = max(1, controls.length);
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : count * 82.0;
            final nodeWidth = max(82.0, availableWidth / count);
            final totalWidth = nodeWidth * count;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 34,
                      child: Stack(
                        children: [
                          Positioned(
                            left: nodeWidth / 2,
                            right: nodeWidth / 2,
                            top: 15,
                            child: Container(
                                height: 2, color: const Color(0xFFE2E8F0)),
                          ),
                          Row(
                            children: [
                              for (final c in controls)
                                SizedBox(
                                  width: nodeWidth,
                                  child: Column(
                                    children: [
                                      Text(
                                          _monthShort(
                                              c['fecha_control']?.toString() ??
                                                  ''),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF64748B))),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                            color: c['en_brote'] == true
                                                ? Colors.red
                                                : Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2)),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final c in controls)
                          SizedBox(
                            width: nodeWidth,
                            child: Column(
                              children: [
                                Text(
                                  (c['estado_enfermedad'] ?? 'Seguimiento')
                                      .toString(),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w700,
                                      color: _stateColor(
                                          (c['estado_enfermedad'] ??
                                                  'Seguimiento')
                                              .toString())),
                                ),
                                const SizedBox(height: 6),
                                _broteSmallPill(c['en_brote'] == true),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEvoInflammationSection(List<Map<String, dynamic>> controls) {
    if (controls.isEmpty) return const SizedBox.shrink();

    // 1. Cálculos de estadísticas
    final int total = controls.length;
    final int conBrote = controls.where((c) => c['en_brote'] == true).length;

    int countAlta = 0, countMod = 0, countBaja = 0, countRem = 0;
    for (final c in controls) {
      final s = (c['estado_enfermedad'] ?? '').toString().toLowerCase();
      if (s.contains("alta") || s.contains("grave"))
        countAlta++;
      else if (s.contains("moderada"))
        countMod++;
      else if (s.contains("baja"))
        countBaja++;
      else if (s.contains("remisión") || s.contains("remision")) countRem++;
    }

    final last = controls.last;
    final String ultimoEstadoStr = last['estado_enfermedad'] ?? 'Seguimiento';
    final Color ultimoEstadoColor = _stateColor(ultimoEstadoStr);
    final String ultimoMes = _monthShort(last['fecha_control'] ?? '');

    // 2. Interpretación dinámica
    String interpretacion = "El paciente muestra una tendencia ";
    if (total >= 2) {
      final firstInfl = (controls.first['escala_inflamacion'] ?? 0) as num;
      final lastInfl = (last['escala_inflamacion'] ?? 0) as num;
      if (lastInfl < firstInfl)
        interpretacion += "general a la disminución de la inflamación. ";
      else if (lastInfl > firstInfl)
        interpretacion += "al aumento de la actividad inflamatoria. ";
      else
        interpretacion += "estable en sus niveles de inflamación. ";
    }
    interpretacion +=
        "Se han documentado $conBrote episodios con brote en el período evaluado. El estado actual es de $ultimoEstadoStr.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.shade100)),
              child: const Icon(Icons.coronavirus_outlined,
                  color: Colors.purple, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("3. Inflamación y estado clínico",
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A))),
                Text(
                    "Seguimiento del nivel de inflamación y actividad clínica a lo largo del tiempo",
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Panel Izquierdo: Gráfica
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Evolución de la inflamación (0-3)",
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                              Text("Puntuación de inflamación por visita",
                                  style: GoogleFonts.inter(
                                      fontSize: 9, color: Colors.blueGrey)),
                            ],
                          ),
                          _legendItem("Inflamación", Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: max(
                                3.0,
                                controls
                                        .map((c) => (c['escala_inflamacion'] ??
                                            0) as num)
                                        .reduce(max)
                                        .toDouble() +
                                    0.5),
                            gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (v) => FlLine(
                                    color: const Color(0xFFF1F5F9),
                                    strokeWidth: 1,
                                    dashArray: [4, 4])),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: controls
                                    .asMap()
                                    .entries
                                    .map((e) => FlSpot(
                                        e.key.toDouble(),
                                        (e.value['escala_inflamacion'] ?? 0)
                                            .toDouble()))
                                    .toList(),
                                isCurved: true,
                                color: Colors.purple,
                                barWidth: 3,
                                dotData: const FlDotData(
                                    show: true,
                                    getDotPainter: _getInflammationDot),
                                belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.purple.withOpacity(0.15),
                                          Colors.purple.withOpacity(0.01)
                                        ])),
                              ),
                            ],
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      interval: 1,
                                      getTitlesWidget: (v, meta) => Text(
                                          v.toInt().toString(),
                                          style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  const Color(0xFF94A3B8))))),
                              bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 24,
                                      getTitlesWidget: (v, meta) {
                                        int idx = v.toInt();
                                        if (idx < 0 || idx >= controls.length)
                                          return const SizedBox.shrink();
                                        return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                                _monthShort(controls[idx]
                                                        ['fecha_control'] ??
                                                    ""),
                                                style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(
                                                        0xFF94A3B8))));
                                      })),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            lineTouchData: LineTouchData(
                              handleBuiltInTouches: true,
                              touchTooltipData: LineTouchTooltipData(
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipColor: (_) => Colors.white,
                                tooltipPadding: const EdgeInsets.all(8),
                                tooltipBorder:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                                getTooltipItems: (items) => items
                                    .map((it) => LineTooltipItem(
                                            "", const TextStyle(),
                                            children: [
                                              TextSpan(
                                                  text:
                                                      "${_formatIsoDate(controls[it.x.toInt()]['fecha_control'])}\n",
                                                  style: GoogleFonts.inter(
                                                      fontSize: 8,
                                                      color: const Color(
                                                          0xFF64748B))),
                                              TextSpan(
                                                  text: "Inflamación: ",
                                                  style: GoogleFonts.inter(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              TextSpan(
                                                  text: "${it.y.toInt()}/3",
                                                  style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.purple)),
                                            ]))
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.purple.withOpacity(0.1))),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: Colors.purple),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_generateInflammationHint(controls),
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF334155)))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Panel Derecho: Distribución y Estado
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Distribución de estado
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.bar_chart_rounded,
                                size: 14, color: Color(0xFF004FC4)),
                            const SizedBox(width: 8),
                            Text("Estado de enfermedad",
                                style: GoogleFonts.inter(
                                    fontSize: 10, fontWeight: FontWeight.w800))
                          ]),
                          const SizedBox(height: 12),
                          _distRow(
                              "Actividad alta", countAlta, total, Colors.red),
                          _distRow("Actividad moderada", countMod, total,
                              Colors.orange),
                          _distRow(
                              "Actividad baja", countBaja, total, Colors.green),
                          _distRow(
                              "Remisión clínica", countRem, total, Colors.blue),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Último estado
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.2))),
                      child: Row(
                        children: [
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.verified_user_rounded,
                                  color: Colors.green, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Último estado",
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blueGrey)),
                                Text(ultimoEstadoStr,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: ultimoEstadoColor)),
                                Text("Evaluación en $ultimoMes",
                                    style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blueGrey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Brote Tracker
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.coronavirus_outlined,
                                size: 14, color: Colors.purple),
                            const SizedBox(width: 8),
                            Text("Brote (últimas evaluaciones)",
                                style: GoogleFonts.inter(
                                    fontSize: 10, fontWeight: FontWeight.w800))
                          ]),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final c in controls.reversed
                                  .take(6)
                                  .toList()
                                  .reversed)
                                _broteSmallPill(c['en_brote'] == true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Footer: Summary Cards
        Row(
          children: [
            Expanded(
                child: _footerMetricCard("Con brote", "$conBrote",
                    Colors.purple, Icons.coronavirus_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _footerMetricCard("Alta", "$countAlta", Colors.red,
                    Icons.trending_up_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _footerMetricCard("Moderada", "$countMod", Colors.orange,
                    Icons.bubble_chart_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _footerMetricCard("Baja", "$countBaja", Colors.green,
                    Icons.check_circle_outline_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _footerMetricCard("Remisión", "$countRem", Colors.blue,
                    Icons.shield_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _footerMetricCard("Total evaluaciones", "$total",
                    Colors.purple, Icons.calendar_today_outlined)),
          ],
        ),

        const SizedBox(height: 14),

        // Interpretación Final
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFFBFDFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.05),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.assignment_outlined,
                      size: 18, color: Color(0xFF0F172A))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Interpretación clínica",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Text(interpretacion,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF334155),
                            height: 1.4,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static FlDotPainter _getInflammationDot(
          FlSpot spot, double p, LineChartBarData bar, int index) =>
      FlDotCirclePainter(
          radius: 4,
          color: Colors.purple,
          strokeWidth: 2,
          strokeColor: Colors.white);

  Widget _legendItem(String text, Color color) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B)))
      ]);

  Widget _distRow(String label, int count, int total, Color color) {
    double pct = total > 0 ? count / total : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B)))),
          const SizedBox(width: 8),
          SizedBox(
              width: 60,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color)))),
          const SizedBox(width: 8),
          Text("$count",
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _broteSmallPill(bool isBrote) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: isBrote ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: (isBrote ? Colors.red : Colors.green).withOpacity(0.1))),
        child: Text(isBrote ? "Sí" : "No",
            style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: isBrote ? Colors.red : Colors.green)),
      );

  Widget _footerMetricCard(
          String title, String value, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color.withOpacity(0.6)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey)),
                  Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A))),
                ],
              ),
            ),
          ],
        ),
      );

  String _generateInflammationHint(List<Map<String, dynamic>> controls) {
    if (controls.isEmpty) return "Sin datos suficientes.";
    final last = controls.last;
    final val = (last['escala_inflamacion'] ?? 0) as num;
    final mes = _monthShort(last['fecha_control'] ?? '');
    return "La inflamación se encuentra en nivel $val en la evaluación de $mes.";
  }

  Widget _stateStrip(List<Map<String, dynamic>> controls) {
    final states = controls
        .map((c) => c['estado_enfermedad']?.toString() ?? 'Seguimiento')
        .toList();
    return Container(
      height: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Estado de enfermedad",
              style:
                  GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in states) _stateChip(s, _stateColor(s)),
            ],
          ),
          const SizedBox(height: 12),
          Text("Brote",
              style:
                  GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final c in controls)
                _stateChip(c['en_brote'] == true ? "Sí" : "No",
                    c['en_brote'] == true ? Colors.red : Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stateChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.22))),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );

  Color _stateColor(String s) {
    final e = s.toLowerCase();
    if (e.contains("remisión") || e.contains("remision")) return Colors.green;
    if (e.contains("baja")) return Colors.amber.shade700;
    if (e.contains("moderada")) return Colors.orange;
    if (e.contains("alta")) return Colors.red;
    return Colors.blueGrey;
  }

  Widget _buildEvoHeatmapSection(List<Map<String, dynamic>> controls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Mapa de calor mensual", Icons.grid_view_rounded),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Resumen de indicadores de salud",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          "Seguimiento de evolución mensual por indicadores",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.blueGrey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: _buildHeatmapLegend(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final double labelWidth =
                    constraints.maxWidth < 520 ? 108.0 : 140.0;
                const double minColumnWidth = 92.0;
                final double availableWidth =
                    (constraints.maxWidth - labelWidth)
                        .clamp(0.0, double.infinity);
                final double columnWidth = controls.isNotEmpty
                    ? (availableWidth / controls.length)
                        .clamp(minColumnWidth, double.infinity)
                    : minColumnWidth;
                final double heatmapWidth = controls.isNotEmpty
                    ? columnWidth * controls.length
                    : availableWidth;
                final double scrollContentWidth =
                    max(availableWidth, heatmapWidth);

                return SizedBox(
                  height: 298,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SizedBox(height: 32),
                            _HeatLabel(
                                "Dolor", Icons.sick_rounded, Colors.pinkAccent),
                            _HeatLabel("Energía", Icons.bolt_rounded,
                                Colors.orangeAccent),
                            _HeatLabel(
                                "Inflamación",
                                Icons.local_fire_department_rounded,
                                Colors.deepOrangeAccent),
                            _HeatLabel("Brote", Icons.coronavirus_rounded,
                                Colors.redAccent),
                            _HeatLabel("E. Nutricional",
                                Icons.monitor_weight_outlined, Colors.green),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: _heatmapScrollCtrl,
                          thumbVisibility: controls.length > 1,
                          trackVisibility: controls.length > 1,
                          notificationPredicate: (notification) =>
                              notification.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: _heatmapScrollCtrl,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: scrollContentWidth,
                              child: Row(
                                children: [
                                  for (final c in controls)
                                    _heatColumn(c, width: columnWidth),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 12, color: Colors.blueGrey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Colores reflejan el estado clínico: Verde (Favorable), Naranja (Medio), Rojo (Riesgo/Alto).",
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.blueGrey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInterpretation(List<Map<String, dynamic>> controls) {
    if (controls.isEmpty) return const SizedBox();

    String picosResumen = "Sin picos significativos de dolor.";
    String mejoriaResumen = "La energía se mantiene estable.";
    String nutriResumen = "Estado nutricional adecuado.";

    final maxDolor = controls
        .map((e) => _numValue(e['puntos_dolor'], 0))
        .reduce((a, b) => a > b ? a : b);
    if (maxDolor >= 7) {
      final mesesPicos = controls
          .where((e) => _numValue(e['puntos_dolor'], 0) == maxDolor)
          .map((e) => _monthShort(e['fecha_control']?.toString() ?? ''))
          .toList();
      picosResumen = "Picos de dolor y brotes en ${mesesPicos.join(", ")}.";
    }

    final mesesBrotes = controls
        .where((e) => e['en_brote'] == true)
        .map((e) => _monthShort(e['fecha_control']?.toString() ?? ''))
        .where((e) => e.isNotEmpty)
        .toList();
    if (mesesBrotes.isNotEmpty) {
      picosResumen =
          "$picosResumen Brote registrado en ${mesesBrotes.join(", ")}.";
    }

    final maxInflamacion = controls
        .map((e) => _numValue(e['escala_inflamacion'], 0))
        .reduce((a, b) => a > b ? a : b);
    if (maxInflamacion >= 3) {
      picosResumen = "$picosResumen Inflamacion alta maxima: $maxInflamacion.";
    }

    if (controls.length >= 2) {
      final last = controls.last;
      final prev = controls[controls.length - 2];
      final dolorDelta = _numValue(last['puntos_dolor'], 0) -
          _numValue(prev['puntos_dolor'], 0);
      final energiaDelta = _numValue(last['nivel_fatiga'], 10) -
          _numValue(prev['nivel_fatiga'], 10);
      if (dolorDelta < 0 && energiaDelta >= 0) {
        mejoriaResumen =
            "Energía mostró tendencia positiva vs el mes anterior.";
      }
    }

    if (controls.length >= 2) {
      final last = controls.last;
      final prev = controls[controls.length - 2];
      final dolorDelta = _numValue(last['puntos_dolor'], 0) -
          _numValue(prev['puntos_dolor'], 0);
      final energiaDelta = _numValue(last['nivel_fatiga'], 10) -
          _numValue(prev['nivel_fatiga'], 10);
      if (dolorDelta > 0 || energiaDelta < 0) {
        mejoriaResumen =
            "Atencion: dolor sube o energia baja vs el control previo.";
      } else if (dolorDelta == 0 && energiaDelta == 0) {
        mejoriaResumen = "Evolucion estable vs el control previo.";
      }
    }

    final alertasNutri = controls
        .where((e) => !['normal', 'eutrófico', 'eutrofico']
            .contains((e['estado_nutricional'] ?? '').toString().toLowerCase()))
        .toList();
    if (alertasNutri.isNotEmpty) {
      final ultimaAlerta = alertasNutri.last;
      nutriResumen =
          "Seguimiento por ${ultimaAlerta['estado_nutricional']} en ${_monthShort(ultimaAlerta['fecha_control'])}.";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_outlined,
                  color: Colors.blue, size: 14),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Interpretación / Resumen clínico",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  "Resumen clínico del periodo evaluado",
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.blueGrey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _interpretationCardCompact("Picos síntomas", picosResumen,
                Icons.trending_up_rounded, Colors.redAccent),
            const SizedBox(width: 8),
            _interpretationCardCompact("Mejoría sostenida", mejoriaResumen,
                Icons.show_chart_rounded, Colors.greenAccent),
            const SizedBox(width: 8),
            _interpretationCardCompact("Atención nutricional", nutriResumen,
                Icons.balance_rounded, Colors.orangeAccent),
          ],
        ),
      ],
    );
  }

  Widget _interpretationCardCompact(
      String title, String summary, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 12),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.blueGrey.shade700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heatColumn(Map<String, dynamic> c, {double? width}) {
    final label = _monthShort(c['fecha_control']?.toString() ?? '');
    final cellWidth = ((width ?? 85) - 4).clamp(80.0, double.infinity);

    // Estado nutricional resumido para que la celda sea legible.
    String rawNutri = (c['prediagnostico']?['diagnostico_combinado'] ??
            c['estado_nutricional'] ??
            "-")
        .toString();
    String nutriDisplay = rawNutri;
    String lower = rawNutri.toLowerCase();

    if (lower.contains("normal") ||
        lower.contains("eutrófico") ||
        lower.contains("eutrofico")) {
      nutriDisplay = "Normal";
    }

    return GestureDetector(
      onTap: () => setState(() => _controlSeleccionadoEvo = c),
      child: SizedBox(
        width: width ?? 85,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: [
              Container(
                width: cellWidth,
                height: 32,
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              _heatCell((c['puntos_dolor'] ?? 0).toString(),
                  _heatColor('dolor', _numValue(c['puntos_dolor'], 0)),
                  width: cellWidth),
              _heatCell((c['nivel_fatiga'] ?? 10).toString(),
                  _heatColor('energia', _numValue(c['nivel_fatiga'], 10)),
                  width: cellWidth),
              _heatCell(
                  (c['escala_inflamacion'] ?? 0).toString(),
                  _heatColor(
                      'inflamacion', _numValue(c['escala_inflamacion'], 0)),
                  width: cellWidth),
              _heatCell(c['en_brote'] == true ? "Sí" : "No",
                  c['en_brote'] == true ? Colors.red : Colors.green,
                  width: cellWidth),
              _heatCell(
                nutriDisplay,
                _nutriColor(rawNutri),
                isTextCell: true,
                width: cellWidth,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapLegend() {
    return Row(
      children: [
        _heatLegendItem("Alto", Colors.red.shade400),
        const SizedBox(width: 12),
        _heatLegendItem("Medio", Colors.orange.shade400),
        const SizedBox(width: 12),
        _heatLegendItem("Favor.", Colors.green.shade400),
      ],
    );
  }

  Widget _heatLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withOpacity(0.4),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _heatCell(String text, Color color,
      {bool isTextCell = false, double width = 80}) {
    return Container(
      width: width,
      height: 34,
      margin: const EdgeInsets.only(bottom: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.12), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: isTextCell ? 8 : 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }

  String _monthLong(String date) {
    if (date.isEmpty) return "";
    final dt = DateTime.tryParse(date);
    if (dt == null) return "";
    return DateFormat('MMMM').format(dt);
  }

  Color _heatColor(String tipo, double v) {
    switch (tipo) {
      case 'dolor':
        if (v <= 2) return Colors.green;
        if (v <= 6) return Colors.orange;
        return Colors.red;
      case 'energia':
        if (v >= 7) return Colors.green;
        if (v >= 4) return Colors.orange;
        return Colors.red;
      case 'inflamacion':
        if (v == 0) return Colors.green;
        if (v <= 2) return Colors.orange;
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color _nutriColor(String s) {
    final e = s.toLowerCase();
    if (e.contains("normal") ||
        e.contains("eutrófico") ||
        e.contains("eutrofico")) return Colors.green;
    if (e.contains("bajo")) return Colors.orange;
    if (e.contains("delg")) return Colors.orange;
    if (e.contains("sobre") || e.contains("obes")) return Colors.red;
    return Colors.orange;
  }

  Widget _buildEvoGrowthSection(
      List<Map<String, dynamic>> controls, Map<String, dynamic> paciente) {
    if (controls.isEmpty) return const SizedBox();
    final latest = controls.last;
    final latestImc = _controlImc(latest);
    final latestZScore = _controlZScoreBmi(latest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Crecimiento y nutrición", Icons.show_chart_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final cardWidth = constraints.maxWidth >= 760
              ? (constraints.maxWidth - 36) / 4
              : constraints.maxWidth >= 520
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: cardWidth,
                child: _growthSummaryCard(
                    "Peso actual",
                    "${latest['peso_kg'] ?? '-'} kg",
                    _getHistoryValues(controls, 'peso_kg'),
                    Colors.green),
              ),
              SizedBox(
                width: cardWidth,
                child: _growthSummaryCard(
                    "Talla actual",
                    "${latest['talla_cm'] ?? '-'} cm",
                    _getHistoryValues(controls, 'talla_cm'),
                    Colors.blue),
              ),
              SizedBox(
                width: cardWidth,
                child: _growthSummaryCard(
                    "IMC actual",
                    latestImc == null ? "-" : latestImc.toStringAsFixed(1),
                    _getHistoryValues(controls, 'bmi'),
                    Colors.purple),
              ),
              SizedBox(
                width: cardWidth,
                child: _growthSummaryCard(
                    "Z-score IMC",
                    latestZScore == null
                        ? "-"
                        : latestZScore.toStringAsFixed(1),
                    _getHistoryValues(controls, 'z_score_bmi'),
                    Colors.orange),
              ),
            ],
          );
        }),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: _growthChartCard(
                    "Peso mensual (kg)",
                    controls,
                    'peso_kg',
                    Colors.green,
                    "Datos reales de peso registrados")),
            const SizedBox(width: 16),
            Expanded(
                child: _growthChartCard(
                    "Talla mensual (cm)",
                    controls,
                    'talla_cm',
                    Colors.blue,
                    "Datos reales de talla registrados")),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _growthChartCard("IMC mensual", controls, 'bmi',
                    Colors.purple, "Referencia IMC/edad (OMS)")),
            const SizedBox(width: 16),
            Expanded(
                child: _growthChartCard("Z-score IMC", controls, 'z_score_bmi',
                    Colors.orange, "Interpretación Z-score (OMS)")),
          ],
        ),
        const SizedBox(height: 24),
        _buildGrowthInterpretationCards(controls),
      ],
    );
  }

  Widget _buildEvoImpactSection(List<Map<String, dynamic>> controls) {
    if (controls.isEmpty) return const SizedBox();

    // Cargar datos dinámicos
    final impactData = _buildImpactData(controls);
    final deltaPeso = impactData.fold<double>(
        0, (sum, item) => sum + (item['delta_peso'] as double));
    final maxCarga = impactData.fold<int>(
        0, (maxValue, item) => max(maxValue, item['inflamacion'] as int));
    final mesesEstables = impactData
        .where((item) =>
            item['en_brote'] != true && (item['inflamacion'] as int) <= 1)
        .length;
    final mesesBrote =
        impactData.where((item) => item['en_brote'] == true).length;
    final mesCritico = _criticalImpactMonth(impactData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
            "6. Impacto clínico-nutricional", Icons.analytics_outlined),
        const SizedBox(height: 16),

        // KPI'S EN LA PARTE SUPERIOR
        Row(
          children: [
            _impactStatCard(
                "Δ peso acumulado",
                "${deltaPeso >= 0 ? '+' : ''}${deltaPeso.toStringAsFixed(1)} kg",
                Icons.arrow_upward_rounded,
                Colors.blue),
            const SizedBox(width: 12),
            _impactStatCard("Mayor carga", maxCarga.toString(),
                Icons.local_fire_department_rounded, Colors.orange),
            const SizedBox(width: 12),
            _impactStatCard("Meses estables", mesesEstables.toString(),
                Icons.check_circle_rounded, Colors.green),
            const SizedBox(width: 12),
            _impactStatCard("Meses con brote", mesesBrote.toString(),
                Icons.coronavirus_rounded, Colors.red),
          ],
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Evolución de peso y carga inflamatoria",
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      _impactLegend(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 360,
                          width: double.infinity,
                          child: _buildImpactDualChart(impactData),
                        ),
                        const SizedBox(height: 16),
                        _impactSummaryFooter(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        _statusPanel(impactData, mesCritico),
                        const SizedBox(height: 16),
                        _buildImpactSummaryTable(impactData, mesCritico),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _actionCard("Hallazgo principal", _impactMainFinding(impactData),
                Icons.track_changes_rounded, Colors.blue),
            const SizedBox(width: 12),
            _actionCard(
                "Alerta",
                mesCritico != null
                    ? "${_monthLong((mesCritico['control'] as Map<String, dynamic>)['fecha_control'])} fue el mes critico por brote, inflamacion o desaceleracion del peso."
                    : "No se detectan alertas criticas en el periodo.",
                Icons.warning_amber_rounded,
                Colors.orange),
            const SizedBox(width: 12),
            _actionCard("Acción sugerida", _impactActionSuggestion(impactData),
                Icons.security_rounded, Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildImpactSummaryTable(
      List<Map<String, dynamic>> impactData, Map<String, dynamic>? mesCritico) {
    final risk = _impactRiskLabel(impactData);
    final riskColor = _impactRiskColor(risk);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Resumen de riesgo",
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey,
                letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              _impactTableRow("Tendencia peso", _impactWeightStatus(impactData),
                  Colors.blue),
              _impactTableRow("Progreso clínico",
                  _impactProgressStatus(impactData), Colors.orange),
              _impactTableRow("Recuperación",
                  _impactRecoveryStatus(impactData, mesCritico), Colors.green),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: riskColor.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Nivel de riesgo",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: riskColor)),
                    Text(risk,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: riskColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _impactTableRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade50)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4)),
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildImpactData(
      List<Map<String, dynamic>> controls) {
    final ordered = [...controls]..sort((a, b) {
        final dateA = DateTime.tryParse(a['fecha_control']?.toString() ?? '');
        final dateB = DateTime.tryParse(b['fecha_control']?.toString() ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

    final data = <Map<String, dynamic>>[];
    for (var i = 0; i < ordered.length; i++) {
      final control = ordered[i];
      final pesoActual = _growthValue(control, 'peso_kg');
      final pesoPrevio = i > 0 ? _growthValue(ordered[i - 1], 'peso_kg') : null;
      final deltaPeso = pesoActual != null && pesoPrevio != null
          ? pesoActual - pesoPrevio
          : 0.0;
      final inflamacion = _numValue(control['escala_inflamacion'], 0)
          .round()
          .clamp(0, 3)
          .toInt();

      data.add({
        'control': control,
        'delta_peso': deltaPeso,
        'inflamacion': inflamacion,
        'en_brote': control['en_brote'] == true,
      });
    }
    return data;
  }

  Map<String, dynamic>? _criticalImpactMonth(
      List<Map<String, dynamic>> impactData) {
    if (impactData.isEmpty) return null;
    Map<String, dynamic>? critical;
    double criticalScore = -1;
    for (final item in impactData) {
      final inflamacion = item['inflamacion'] as int;
      final deltaPeso = item['delta_peso'] as double;
      final enBrote = item['en_brote'] == true;
      final score = (inflamacion * 2) +
          (enBrote ? 2 : 0) +
          (deltaPeso < 0 ? 2 : 0) +
          (deltaPeso == 0 ? 0.5 : 0);
      if (score > criticalScore) {
        criticalScore = score.toDouble();
        critical = item;
      }
    }
    return critical;
  }

  String _impactMainFinding(List<Map<String, dynamic>> impactData) {
    final affectedMonths = impactData.where((item) =>
        (item['inflamacion'] as int) >= 2 &&
        ((item['delta_peso'] as double) <= 0 || item['en_brote'] == true));
    if (affectedMonths.isNotEmpty) {
      return "La carga inflamatoria elevada se asocia a menor ganancia de peso.";
    }
    return "El paciente mantiene estabilidad nutricional con baja actividad clinica.";
  }

  String _impactActionSuggestion(List<Map<String, dynamic>> impactData) {
    final needsSupport = impactData.any((item) =>
        item['en_brote'] == true &&
        ((item['inflamacion'] as int) >= 2 ||
            (item['delta_peso'] as double) <= 0));
    if (needsSupport) {
      return "Reforzar control de inflamacion y soporte nutricional para mantener el crecimiento.";
    }
    return "Mantener seguimiento mensual de peso, inflamacion y brotes.";
  }

  String _impactRiskLabel(List<Map<String, dynamic>> impactData) {
    final hasBrote = impactData.any((item) => item['en_brote'] == true);
    final hasHighInflammation =
        impactData.any((item) => (item['inflamacion'] as int) >= 3);
    final negativeMonths =
        impactData.where((item) => (item['delta_peso'] as double) < 0).length;
    if (hasHighInflammation && hasBrote && negativeMonths > 1) return "Alto";
    if (hasBrote || hasHighInflammation || negativeMonths == 1) {
      return "Moderado";
    }
    return "Bajo";
  }

  Color _impactRiskColor(String risk) {
    if (risk == "Alto") return Colors.red;
    if (risk == "Moderado") return Colors.orange;
    return Colors.green;
  }

  String _impactWeightStatus(List<Map<String, dynamic>> impactData) {
    final total = impactData.fold<double>(
        0, (sum, item) => sum + (item['delta_peso'] as double));
    final negativeMonths =
        impactData.where((item) => (item['delta_peso'] as double) < 0).length;
    if (total > 0 && negativeMonths <= 1) return "Adecuada";
    if (total > 0) return "Vigilancia";
    return "Revisar";
  }

  String _impactProgressStatus(List<Map<String, dynamic>> impactData) {
    final criticalPattern = impactData.any((item) =>
        item['en_brote'] == true &&
        (item['inflamacion'] as int) >= 2 &&
        (item['delta_peso'] as double) <= 0);
    return criticalPattern ? "Vigilancia" : "Adecuada";
  }

  String _impactRecoveryStatus(
      List<Map<String, dynamic>> impactData, Map<String, dynamic>? mesCritico) {
    if (mesCritico == null) return "-";
    final criticalIndex = impactData.indexOf(mesCritico);
    if (criticalIndex < 0 || criticalIndex >= impactData.length - 1) {
      return "Pendiente";
    }
    final posteriores = impactData.skip(criticalIndex + 1);
    final improves = posteriores.any((item) =>
        (item['inflamacion'] as int) <= 1 &&
        (item['delta_peso'] as double) > 0 &&
        item['en_brote'] != true);
    return improves ? "Adecuada" : "Vigilancia";
  }

  Widget _growthSummaryCard(
      String title, String value, List<double> history, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIconForGrowthTitle(title), color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SizedBox(
              height: 24,
              width: double.infinity,
              child: _buildSparkline(history, color)),
        ],
      ),
    );
  }

  Widget _growthChartCard(String title, List<Map<String, dynamic>> controls,
      String key, Color color, String refText) {
    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              child: ClipRect(
                child: _buildMainGrowthChart(controls, key, color),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(refText,
              style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGrowthInterpretationCards(List<Map<String, dynamic>> controls) {
    final first = controls.first;
    final last = controls.last;
    final pesoInicial = _growthValue(first, 'peso_kg');
    final pesoActual = _growthValue(last, 'peso_kg');
    final tallaInicial = _growthValue(first, 'talla_cm');
    final tallaActual = _growthValue(last, 'talla_cm');
    final imcInicial = _controlImc(first);
    final imcActual = _controlImc(last);
    final zActual = _controlZScoreBmi(last);

    final pesoDelta = (pesoInicial != null && pesoActual != null)
        ? pesoActual - pesoInicial
        : null;
    final tallaDelta = (tallaInicial != null && tallaActual != null)
        ? tallaActual - tallaInicial
        : null;
    final imcDelta = (imcInicial != null && imcActual != null)
        ? imcActual - imcInicial
        : null;

    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = constraints.maxWidth >= 760
          ? (constraints.maxWidth - 30) / 4
          : constraints.maxWidth >= 520
              ? (constraints.maxWidth - 10) / 2
              : constraints.maxWidth;

      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: cardWidth,
            child: _interpretationGrowthCard(
                "Peso",
                pesoDelta == null
                    ? "Sin datos suficientes para comparar peso."
                    : "${pesoDelta >= 0 ? '+' : ''}${pesoDelta.toStringAsFixed(1)} kg en el periodo.",
                _trendLabel(pesoDelta,
                    positiveLabel: "Ganancia", negativeLabel: "Descenso"),
                Colors.green),
          ),
          SizedBox(
            width: cardWidth,
            child: _interpretationGrowthCard(
                "Talla",
                tallaDelta == null
                    ? "Sin datos suficientes para comparar talla."
                    : "${tallaDelta >= 0 ? '+' : ''}${tallaDelta.toStringAsFixed(1)} cm en el periodo.",
                _trendLabel(tallaDelta,
                    positiveLabel: "Crecimiento",
                    negativeLabel: "Revisar dato"),
                Colors.blue),
          ),
          SizedBox(
            width: cardWidth,
            child: _interpretationGrowthCard(
                "IMC",
                imcActual == null
                    ? "No hay peso/talla suficiente para calcular IMC."
                    : "IMC actual ${imcActual.toStringAsFixed(1)}${imcDelta == null ? '' : ' (${imcDelta >= 0 ? '+' : ''}${imcDelta.toStringAsFixed(1)})'}.",
                _imcTrendLabel(imcDelta),
                Colors.purple),
          ),
          SizedBox(
            width: cardWidth,
            child: _interpretationGrowthCard(
                "Z-score",
                zActual == null
                    ? "Z-score IMC no disponible en los datos OMS."
                    : _zScoreInterpretation(zActual),
                _zScoreTrendLabel(zActual),
                _zScoreColor(zActual ?? 0)),
          ),
        ],
      );
    });
  }

  String _trendLabel(double? delta,
      {required String positiveLabel, required String negativeLabel}) {
    if (delta == null) return "Sin comparativo";
    if (delta > 0.05) return positiveLabel;
    if (delta < -0.05) return negativeLabel;
    return "Estable";
  }

  String _imcTrendLabel(double? delta) {
    if (delta == null) return "Sin comparativo";
    if (delta > 0.2) return "Aumento";
    if (delta < -0.2) return "Descenso";
    return "Estable";
  }

  String _zScoreInterpretation(double z) {
    if (z < -3) return "Delgadez severa: requiere seguimiento prioritario.";
    if (z < -2) return "Delgadez: vigilar ganancia ponderal.";
    if (z <= 1) return "Rango esperado para IMC/edad.";
    if (z <= 2) return "Riesgo de sobrepeso: vigilar tendencia.";
    if (z <= 3) return "Sobrepeso segun IMC/edad.";
    return "Obesidad segun IMC/edad.";
  }

  String _zScoreTrendLabel(double? z) {
    if (z == null) return "No disponible";
    if (z < -2 || z > 2) return "Alerta";
    if (z > 1) return "Vigilancia";
    return "Adecuada";
  }

  Widget _interpretationGrowthCard(
      String title, String desc, String trend, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIconForGrowthTitle(title), color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.blueGrey),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text("Tendencia: $trend",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _statusPanel(
      List<Map<String, dynamic>> impactData, Map<String, dynamic>? mesCritico) {
    final risk = _impactRiskLabel(impactData);
    final pesoStatus = _impactWeightStatus(impactData);
    final progressStatus = _impactProgressStatus(impactData);
    final recoveryStatus = _impactRecoveryStatus(impactData, mesCritico);
    final brotesRecientes =
        impactData.reversed.take(3).any((item) => item['en_brote'] == true);
    final mesCriticoControl = mesCritico?['control'] as Map<String, dynamic>?;

    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _statusRow("Riesgo clínico-nutri", risk, _impactRiskColor(risk)),
          _statusRow("Peso", pesoStatus,
              pesoStatus == "Adecuada" ? Colors.green : Colors.orange),
          _statusRow("IMC / progresión", progressStatus,
              progressStatus == "Adecuada" ? Colors.green : Colors.orange),
          _statusRow("Brotes recientes", brotesRecientes ? "Sí" : "No",
              brotesRecientes ? Colors.red : Colors.green),
          _statusRow(
              "Mes crítico",
              mesCriticoControl != null
                  ? _monthShort(mesCriticoControl['fecha_control'])
                  : "-",
              Colors.purple),
          _statusRow("Recuperación", recoveryStatus,
              recoveryStatus == "Adecuada" ? Colors.green : Colors.orange),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey)),
          Row(
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 6),
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _impactStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100)),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(String title, String desc, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(desc,
                style: GoogleFonts.inter(
                    fontSize: 10, color: Colors.blueGrey, height: 1.4)),
          ],
        ),
      ),
    );
  }

  IconData _getIconForGrowthTitle(String title) {
    if (title.contains("Peso")) return Icons.monitor_weight_outlined;
    if (title.contains("Talla")) return Icons.height_rounded;
    if (title.contains("IMC")) return Icons.speed_rounded;
    return Icons.show_chart_rounded;
  }

  List<double> _getHistoryValues(
      List<Map<String, dynamic>> controls, String key) {
    return controls
        .map((e) => _growthValue(e, key))
        .whereType<double>()
        .toList();
  }

  double? _growthValue(Map<String, dynamic> control, String key) {
    if (key == 'bmi') return _controlImc(control);
    if (key == 'z_score_bmi') return _controlZScoreBmi(control);
    final value = control[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double? _controlImc(Map<String, dynamic> control) {
    final pre = control['prediagnostico'];
    final fromPre = pre is Map ? pre['imc'] : null;
    final existing =
        fromPre ?? control['imc_calculado'] ?? control['bmi'] ?? control['imc'];
    final parsed = existing is num
        ? existing.toDouble()
        : double.tryParse(existing?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;

    final peso = _growthValueRaw(control['peso_kg']);
    final tallaCm = _growthValueRaw(control['talla_cm']);
    if (peso == null || tallaCm == null || peso <= 0 || tallaCm <= 0) {
      return null;
    }
    final tallaM = tallaCm / 100;
    return peso / (tallaM * tallaM);
  }

  double? _controlZScoreBmi(Map<String, dynamic> control) {
    final pre = control['prediagnostico'];
    final fromPre = pre is Map ? pre['z_score_bmi'] : null;
    final existing = fromPre ?? control['z_score_bmi'];
    if (existing is num) return existing.toDouble();
    return double.tryParse(existing?.toString() ?? '');
  }

  double? _growthValueRaw(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Widget _buildSparkline(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox();
    return CustomPaint(painter: _SparklinePainter(data, color));
  }

  Widget _buildMainGrowthChart(
      List<Map<String, dynamic>> controls, String key, Color color) {
    List<HorizontalRangeAnnotation> bands = [];
    if (key == 'z_score_bmi') {
      bands = [
        HorizontalRangeAnnotation(
            y1: -3, y2: -2, color: Colors.red.withOpacity(0.05)),
        HorizontalRangeAnnotation(
            y1: -2, y2: 1, color: Colors.green.withOpacity(0.05)),
        HorizontalRangeAnnotation(
            y1: 1, y2: 2, color: Colors.orange.withOpacity(0.05)),
        HorizontalRangeAnnotation(
            y1: 2, y2: 3, color: Colors.red.withOpacity(0.05)),
      ];
    }

    final spots = controls.asMap().entries.fold<List<FlSpot>>([], (acc, e) {
      final value = _growthValue(e.value, key);
      if (value != null) acc.add(FlSpot(e.key.toDouble(), value));
      return acc;
    });

    if (spots.isEmpty) {
      return Center(
        child: Text(
          "Sin datos suficientes",
          style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey),
        ),
      );
    }

    final values = spots.map((e) => e.y).toList();
    final rawMin = values.reduce(min);
    final rawMax = values.reduce(max);
    final range = rawMax - rawMin;
    final padding = range == 0 ? rawMax.abs() * 0.08 + 1 : range * 0.16;
    final minY = rawMin - padding;
    final maxY = rawMax + padding;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (controls.length - 1).toDouble().clamp(0, double.infinity),
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            belowBarData:
                BarAreaData(show: true, color: color.withOpacity(0.05)),
            dotData: const FlDotData(show: true),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
              .map((i) => TouchedSpotIndicatorData(
                    FlLine(color: color.withOpacity(0.16), strokeWidth: 1.4),
                    FlDotData(show: true, getDotPainter: _getSmallDot),
                  ))
              .toList(),
          touchTooltipData: _growthTooltipData(controls, key, color),
        ),
        rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: bands),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (v, m) => SizedBox(
                        width: 34,
                        child: Text(
                          v.toStringAsFixed(key == 'z_score_bmi' ? 1 : 0),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                              fontSize: 8, color: Color(0xFF64748B)),
                        ),
                      ))),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (v, m) {
                    final idx = v.round();
                    if ((v - idx).abs() > 0.01 ||
                        idx < 0 ||
                        idx >= controls.length) {
                      return const SizedBox();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: 40,
                        child: Text(
                          _monthShort(controls[idx]['fecha_control']),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 8, color: Color(0xFF64748B)),
                        ),
                      ),
                    );
                  })),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  LineTouchTooltipData _growthTooltipData(
      List<Map<String, dynamic>> controls, String key, Color color) {
    return LineTouchTooltipData(
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipColor: (_) => Colors.white,
      tooltipPadding: const EdgeInsets.all(8),
      tooltipBorder: const BorderSide(color: Color(0xFFE2E8F0)),
      getTooltipItems: (items) {
        return items.map((item) {
          final idx = item.x.round();
          if (idx < 0 || idx >= controls.length) {
            return null;
          }
          final c = controls[idx];
          final label = _growthTooltipLabel(key);
          final unit = _growthTooltipUnit(key);

          return LineTooltipItem(
            "",
            const TextStyle(),
            children: [
              TextSpan(
                  text:
                      "${(c['mes_label_largo'] ?? _monthShort(c['fecha_control']?.toString() ?? '')).toString()}\n",
                  style: GoogleFonts.inter(
                      fontSize: 8,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600)),
              TextSpan(
                  text: "$label: ",
                  style: GoogleFonts.inter(
                      fontSize: 10, color: color, fontWeight: FontWeight.w900)),
              TextSpan(
                  text:
                      "${item.y.toStringAsFixed(key == 'z_score_bmi' ? 1 : 1)}$unit",
                  style: GoogleFonts.inter(
                      fontSize: 10, color: color, fontWeight: FontWeight.w900)),
            ],
          );
        }).toList();
      },
    );
  }

  String _growthTooltipLabel(String key) {
    if (key == 'peso_kg') return "Peso";
    if (key == 'talla_cm') return "Talla";
    if (key == 'bmi') return "IMC";
    if (key == 'z_score_bmi') return "Z-score IMC";
    return "Valor";
  }

  String _growthTooltipUnit(String key) {
    if (key == 'peso_kg') return " kg";
    if (key == 'talla_cm') return " cm";
    return "";
  }

  Widget _impactLegend() {
    return Row(
      children: [
        _legendItemImpact("Cambio peso (kg)", Colors.blue),
        const SizedBox(width: 16),
        _legendItemImpact("Carga inflamatoria", Colors.orange),
      ],
    );
  }

  Widget _legendItemImpact(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 4,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _impactSummaryFooter() {
    return Row(
      children: [
        Icon(Icons.info_outline_rounded,
            size: 14, color: Colors.blueGrey.shade400),
        const SizedBox(width: 8),
        Text(
            "La carga inflamatoria aumenta durante brotes y afecta la ganancia de peso.",
            style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.blueGrey.shade600,
                fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildImpactDualChart(List<Map<String, dynamic>> impactData) {
    if (impactData.isEmpty) return const SizedBox();

    final deltas = impactData.map((e) => e['delta_peso'] as double).toList();
    final minDVal = deltas.reduce(min);
    final maxDVal = deltas.reduce(max);
    final deltaRange = maxDVal - minDVal;
    final deltaPadding =
        deltaRange == 0 ? max(maxDVal.abs(), 0.5) * 0.35 : deltaRange * 0.35;
    final dyMinY = min(-0.2, minDVal - deltaPadding);
    final dyMaxY = max(0.5, maxDVal + deltaPadding);

    final inflamaciones =
        impactData.map((e) => (e['inflamacion'] as int).toDouble()).toList();
    final minInfl = inflamaciones.reduce(min);
    final maxInfl = inflamaciones.reduce(max);
    final inflRange = maxInfl - minInfl;
    final inflPadding = inflRange == 0 ? 0.6 : max(0.35, inflRange * 0.18);
    final inflMinY = max(-0.35, minInfl - inflPadding);
    final inflMaxY = min(3.35, maxInfl + inflPadding);

    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: BarChart(
                BarChartData(
                  barGroups: impactData.asMap().entries.map((e) {
                    final delta = e.value['delta_peso'] as double;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: delta,
                          color: Colors.blue.withOpacity(0.6),
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        )
                      ],
                    );
                  }).toList(),
                  minY: dyMinY,
                  maxY: dyMaxY,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, m) => Text(v.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 8, color: Colors.blue))),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, m) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= impactData.length) {
                            return const SizedBox();
                          }
                          final control = impactData[idx]['control']
                              as Map<String, dynamic>;
                          return Text(_monthShort(control['fecha_control']),
                              style: const TextStyle(fontSize: 8));
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            Positioned.fill(
              child: LineChart(
                LineChartData(
                  clipData: const FlClipData.all(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: impactData.asMap().entries.map((e) {
                        final val = e.value['inflamacion'] as int;
                        return FlSpot(e.key.toDouble(), val.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isBrote = impactData[index]['en_brote'] == true;
                          return FlDotCirclePainter(
                            radius: isBrote ? 4 : 2,
                            color: isBrote ? Colors.red : Colors.orange,
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                  minY: inflMinY,
                  maxY: inflMaxY,
                  titlesData: FlTitlesData(
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (v, m) {
                            final rounded = v.round();
                            if ((v - rounded).abs() > 0.01 ||
                                rounded < 0 ||
                                rounded > 3) {
                              return const SizedBox.shrink();
                            }
                            return Text(rounded.toString(),
                                style: const TextStyle(
                                    fontSize: 8, color: Colors.orange));
                          }),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideStatCard(
          String title, String value, IconData icon, Color color) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.16))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.blueGrey)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );

  Widget _kv(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200)),
        child: RichText(
          text: TextSpan(
            style:
                GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155)),
            children: [
              TextSpan(
                  text: "$k: ",
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(
                  text: v, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  Widget _prediBlock(Map<String, dynamic> c) {
    final pre = Map<String, dynamic>.from(c['prediagnostico'] ?? {});
    final confirmado = c['validacion_confirmada'] == true;
    final resumenClinico = _asStringList(pre['resumen_clinico']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FFF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text("Diagnóstico nutricional OMS",
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey)),
            const SizedBox(width: 8),
            if (confirmado)
              _stateChip("Confirmado por nutrición", Colors.green),
          ]),
          const SizedBox(height: 6),
          Text(
              pre['diagnostico_combinado']?.toString() ??
                  c['estado_nutricional']?.toString() ??
                  "-",
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(
              "IMC ideal ${_formatNum(pre['imc'] ?? c['imc_calculado'])} · Z-score ${_formatNum(pre['z_score_bmi'] ?? c['z_score_bmi'])}",
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallInfoPill("Peso ideal", _formatNum(pre['peso_ideal'])),
              _smallInfoPill("Talla ideal", _formatNum(pre['talla_ideal'])),
              _smallInfoPill(
                  "Estado peso", pre['estado_peso']?.toString() ?? "-"),
            ],
          ),
          if (resumenClinico.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final item in resumenClinico.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: Icon(Icons.fiber_manual_record,
                          size: 6, color: Colors.green),
                    ),
                    Expanded(
                        child: Text(item,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.blueGrey.shade700,
                                height: 1.35))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _smallInfoPill(String title, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200)),
        child: RichText(
          text: TextSpan(
            style:
                GoogleFonts.inter(fontSize: 10, color: const Color(0xFF334155)),
            children: [
              TextSpan(
                  text: "$title: ",
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  List<String> _asStringList(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? const [] : [text];
    }
    if (value is List) {
      return value
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return [value.toString()];
  }

  String _formatNum(dynamic v) {
    final n = double.tryParse(v?.toString() ?? "");
    if (n == null) return "-";
    return n.toStringAsFixed(1);
  }

  Widget _buildEvoScatterSection(List<Map<String, dynamic>> controls) {
    final spots = <ScatterSpot>[];
    final hasBrote = controls.any((c) => c['en_brote'] == true);
    for (final c in controls) {
      final x = (c['puntos_dolor'] ?? 0).toDouble();
      final y = (c['nivel_fatiga'] ?? 10).toDouble();
      final size = 6 + ((c['articulaciones_inflamadas'] ?? 0).toDouble() * 3);
      final color = c['en_brote'] == true
          ? Colors.red.withOpacity(0.75)
          : Colors.green.withOpacity(0.65);
      spots.add(
        ScatterSpot(
          x,
          y,
          dotPainter: FlDotCirclePainter(
            radius: size.toDouble(),
            color: color,
          ),
        ),
      );
    }

    double maxX = 10;
    double maxY = 10;
    if (spots.isNotEmpty) {
      double curMaxX = spots.map((s) => s.x).reduce(max);
      double curMaxY = spots.map((s) => s.y).reduce(max);
      maxX = max(10, curMaxX + 2);
      maxY = max(10, curMaxY + 2);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Relación dolor - energía - brote",
              Icons.scatter_plot_rounded),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 320,
                  child: ScatterChart(
                    ScatterChartData(
                      scatterSpots: spots,
                      minX: 0,
                      maxX: maxX,
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (v) =>
                              FlLine(color: Colors.grey.withOpacity(0.05)),
                          getDrawingVerticalLine: (v) =>
                              FlLine(color: Colors.grey.withOpacity(0.05))),
                      borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: const Color(0xFFF1F5F9))),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                            axisNameWidget: const Text("Energía",
                                style: TextStyle(
                                    fontSize: 8, fontWeight: FontWeight.bold)),
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: maxY / 5)),
                        bottomTitles: AxisTitles(
                            axisNameWidget: const Text("Dolor",
                                style: TextStyle(
                                    fontSize: 8, fontWeight: FontWeight.bold)),
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: maxX / 5)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      scatterTouchData: ScatterTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          final spot = response?.touchedSpot;
                          if (spot == null) return;
                          final idx = spot.spotIndex;
                          if (idx >= 0 && idx < controls.length) {
                            setState(
                                () => _controlSeleccionadoEvo = controls[idx]);
                          }
                        },
                        touchTooltipData: ScatterTouchTooltipData(
                          getTooltipColor: (_) => Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendChip(
                        "Tamaño: Art. inflamadas", Colors.blueGrey, "0 - 3"),
                    const SizedBox(height: 10),
                    _legendChip("Color: Brote", Colors.red, "Sí"),
                    _legendChip("", Colors.green, "No"),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200)),
                      child: Text(
                        hasBrote
                            ? "Los controles con brote se concentran en mayor dolor y menor energía."
                            : "No se observa relación marcada entre dolor y energía en el período seleccionado.",
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade700,
                            height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendChip(String title, Color color, String value) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title.isEmpty ? value : "$title: $value",
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade700),
              ),
            ),
          ],
        ),
      );

  Widget _realLineChart(
    String title,
    List<Map<String, dynamic>> controls,
    double Function(Map<String, dynamic>) getValue,
    Color lineColor,
    String Function(Map<String, dynamic>) tooltipBuilder, {
    double minY = 0,
    double? maxY,
    List<(double, double, Color)> bands = const [],
  }) {
    final spots = <FlSpot>[];
    for (var i = 0; i < controls.length; i++) {
      spots.add(FlSpot(i.toDouble(), getValue(controls[i])));
    }

    // Escala dinámica automática: asegura que los puntos nunca se desborden arriba ni abajo
    double calculatedMaxY = 10.0;
    double calculatedMinY = minY;
    if (spots.isNotEmpty) {
      double maxVal = spots.map((s) => s.y).reduce(max);
      double minVal = spots.map((s) => s.y).reduce(min);

      double hintMaxY = maxY ?? (maxVal > 0 ? maxVal * 1.2 : 10.0);
      calculatedMaxY = max(hintMaxY, (maxVal * 1.2).ceilToDouble());

      // Ajuste dinámico para el mínimo (especialmente importante para Z-scores)
      if (minVal < minY) {
        calculatedMinY = (minVal * 1.2).floorToDouble();
      }

      if (calculatedMaxY <= calculatedMinY) calculatedMaxY = calculatedMinY + 1;
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFFBFDFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: calculatedMinY,
                maxY: calculatedMaxY,
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    for (final band in bands)
                      HorizontalRangeAnnotation(
                          y1: band.$1, y2: band.$2, color: band.$3),
                  ],
                ),
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                        show: true, color: lineColor.withOpacity(0.05)),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: calculatedMaxY > 0
                              ? (calculatedMaxY / 2).clamp(1, 100)
                              : 1,
                          getTitlesWidget: (v, meta) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 9)))),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= controls.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                              _monthShort(
                                  controls[idx]['fecha_control']?.toString() ??
                                      ''),
                              style: const TextStyle(fontSize: 9)),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchCallback: (event, response) {
                    final spotsTouched = response?.lineBarSpots;
                    if (spotsTouched == null || spotsTouched.isEmpty) return;
                    final idx = spotsTouched.first.spotIndex;
                    if (idx >= 0 && idx < controls.length) {
                      setState(() => _controlSeleccionadoEvo = controls[idx]);
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItems: (items) {
                      if (items.isEmpty) return [];
                      final idx = items.first.x.toInt();
                      if (idx < 0 || idx >= controls.length) return [];
                      final c = controls[idx];
                      return [
                        LineTooltipItem(
                          "${_formatIsoDate(c['fecha_control'])}\n${tooltipBuilder(c)}",
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ];
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _realStepChart(
    String title,
    List<Map<String, dynamic>> controls,
    double Function(Map<String, dynamic>) getValue,
    Color lineColor,
    String Function(Map<String, dynamic>) tooltipBuilder, {
    double minY = 0,
    double? maxY,
    List<(double, double, Color)> bands = const [],
  }) {
    final spots = <FlSpot>[];
    for (var i = 0; i < controls.length; i++) {
      spots.add(FlSpot(i.toDouble(), getValue(controls[i])));
    }

    double calculatedMaxY = 3.0;
    if (spots.isNotEmpty) {
      double maxVal = spots.map((s) => s.y).reduce(max);
      calculatedMaxY = maxY ?? (maxVal < 3 ? 3 : maxVal + 1);
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFFBFDFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: calculatedMaxY,
                rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
                  for (final band in bands)
                    HorizontalRangeAnnotation(
                        y1: band.$1, y2: band.$2, color: band.$3)
                ]),
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: lineColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  )
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (v, meta) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 9)))),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          getTitlesWidget: (v, meta) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= controls.length)
                              return const SizedBox.shrink();
                            return Text(
                                _monthShort(controls[idx]['fecha_control']
                                        ?.toString() ??
                                    ''),
                                style: const TextStyle(fontSize: 9));
                          })),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchCallback: (event, response) {
                    final spotsTouched = response?.lineBarSpots;
                    if (spotsTouched == null || spotsTouched.isEmpty) return;
                    final idx = spotsTouched.first.spotIndex;
                    if (idx >= 0 && idx < controls.length) {
                      setState(() => _controlSeleccionadoEvo = controls[idx]);
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItems: (items) {
                      if (items.isEmpty) return [];
                      final idx = items.first.x.toInt();
                      if (idx < 0 || idx >= controls.length) return [];
                      final c = controls[idx];
                      return [
                        LineTooltipItem(
                            "${_formatIsoDate(c['fecha_control'])}\n${tooltipBuilder(c)}",
                            const TextStyle(color: Colors.white, fontSize: 11))
                      ];
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _evoSummaryRow(List<Map<String, dynamic>> controls,
      {required String type}) {
    if (controls.isEmpty) return const SizedBox.shrink();
    if (type == "symptoms") {
      final dolor = <double>[
        for (final e in controls) (e['puntos_dolor'] ?? 0).toDouble()
      ];
      final energia = <double>[
        for (final e in controls) (e['nivel_fatiga'] ?? 10).toDouble()
      ];
      final brotes = controls.where((e) => e['en_brote'] == true).length;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _miniSummary("Promedio dolor", _avg(dolor).toStringAsFixed(1)),
          _miniSummary("Promedio energía", _avg(energia).toStringAsFixed(1)),
          _miniSummary(
              "Dolor máximo",
              dolor
                  .fold<double>(double.negativeInfinity, max)
                  .toStringAsFixed(0)),
          _miniSummary("Energía mínima",
              energia.fold<double>(double.infinity, min).toStringAsFixed(0)),
          _miniSummary("Cantidad controles", controls.length.toString()),
          _miniSummary("Con brote", brotes.toString()),
        ],
      );
    }
    if (type == "joints") {
      final infl = <double>[
        for (final e in controls)
          (e['articulaciones_inflamadas'] ?? 0).toDouble()
      ];
      final dolor = <double>[
        for (final e in controls)
          (e['articulaciones_dolorosas'] ?? 0).toDouble()
      ];
      final rig = <double>[
        for (final e in controls) (e['minutos_rigidez'] ?? 0).toDouble()
      ];
      final prev = controls.length > 1 ? controls[controls.length - 2] : null;
      final last = controls.last;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _miniSummary(
              "Máx. inflamadas",
              infl
                  .fold<double>(double.negativeInfinity, max)
                  .toStringAsFixed(0)),
          _miniSummary(
              "Máx. dolorosas",
              dolor
                  .fold<double>(double.negativeInfinity, max)
                  .toStringAsFixed(0)),
          _miniSummary(
              "Rigidez máxima",
              rig
                  .fold<double>(double.negativeInfinity, max)
                  .toStringAsFixed(0)),
          _miniSummary("Prom. rigidez", _avg(rig).toStringAsFixed(1)),
          _miniSummary(
              "Última rigidez", (last['minutos_rigidez'] ?? 0).toString()),
          _miniSummary(
              "Cambio vs anterior",
              prev == null
                  ? "-"
                  : "${((last['minutos_rigidez'] ?? 0) as num) - ((prev['minutos_rigidez'] ?? 0) as num)}"),
        ],
      );
    }
    if (type == "inflammation") {
      final estados = controls
          .map((e) => (e['estado_enfermedad'] ?? '').toString())
          .toList();
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _miniSummary(
              "Remisión",
              estados
                  .where((e) =>
                      e.toLowerCase().contains("remisión") ||
                      e.toLowerCase().contains("remision"))
                  .length
                  .toString()),
          _miniSummary(
              "Baja",
              estados
                  .where((e) => e.toLowerCase().contains("baja"))
                  .length
                  .toString()),
          _miniSummary(
              "Moderada",
              estados
                  .where((e) => e.toLowerCase().contains("moderada"))
                  .length
                  .toString()),
          _miniSummary(
              "Alta",
              estados
                  .where((e) => e.toLowerCase().contains("alta"))
                  .length
                  .toString()),
          _miniSummary("Con brote",
              controls.where((e) => e['en_brote'] == true).length.toString()),
          _miniSummary("Último estado",
              controls.last['estado_enfermedad']?.toString() ?? "-"),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _miniSummary(String title, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: RichText(
          text: TextSpan(
            style:
                GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155)),
            children: [
              TextSpan(
                  text: "$title: ",
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );

  double _avg(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  Widget _buildEvoDetailPanel(Map<String, dynamic> c) {
    final pre = Map<String, dynamic>.from(c['prediagnostico'] ?? {});
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF8ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.orange.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Text("Detalle del control seleccionado",
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w900))
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _miniSummary("Fecha", _formatIsoDate(c['fecha_control'])),
              _miniSummary("Dolor", "${c['puntos_dolor'] ?? '-'}"),
              _miniSummary("Energía", "${c['nivel_fatiga'] ?? '-'}"),
              _miniSummary("Inflamación", "${c['escala_inflamacion'] ?? '-'}"),
              _miniSummary("Art. inflamadas",
                  "${c['articulaciones_inflamadas'] ?? '-'}"),
              _miniSummary(
                  "Art. dolorosas", "${c['articulaciones_dolorosas'] ?? '-'}"),
              _miniSummary("Rigidez", "${c['minutos_rigidez'] ?? '-'} min"),
              _miniSummary("Brote", c['en_brote'] == true ? "Sí" : "No"),
              _miniSummary("Estado", c['estado_enfermedad']?.toString() ?? "-"),
              _miniSummary("Peso", "${c['peso_kg'] ?? '-'} kg"),
              _miniSummary("Talla", "${c['talla_cm'] ?? '-'} cm"),
              _miniSummary("IMC", _formatNum(pre['imc'] ?? c['imc_calculado'])),
              _miniSummary("Z-score",
                  _formatNum(pre['z_score_bmi'] ?? c['z_score_bmi'])),
              _miniSummary(
                  "Nutrición", c['estado_nutricional']?.toString() ?? "-"),
            ],
          ),
          const SizedBox(height: 10),
          if ((c['nota_evolucion'] ?? '').toString().isNotEmpty)
            Text("Nota: ${c['nota_evolucion']}",
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade700)),
        ],
      ),
    );
  }

  String _monthShort(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return _monthLabel(dt);
    } catch (_) {
      return raw.length >= 3 ? raw.substring(0, 3) : raw;
    }
  }

  String _painTooltip(Map<String, dynamic> c) =>
      "Dolor: ${c['puntos_dolor'] ?? 0}/10\nEstado: ${c['estado_enfermedad'] ?? '-'}\nBrote: ${c['en_brote'] == true ? 'Sí' : 'No'}\n${(c['nota_evolucion'] ?? '').toString()}";

  String _energyTooltip(Map<String, dynamic> c) =>
      "Energía: ${c['nivel_fatiga'] ?? 10}/10\nEstado: ${c['estado_enfermedad'] ?? '-'}\nBrote: ${c['en_brote'] == true ? 'Sí' : 'No'}\n${(c['nota_evolucion'] ?? '').toString()}";

  String _jointTooltip(Map<String, dynamic> c, String label) =>
      "$label: ${c[label == 'Inflamadas' ? 'articulaciones_inflamadas' : 'articulaciones_dolorosas'] ?? 0}\nEstado: ${c['estado_enfermedad'] ?? '-'}\nBrote: ${c['en_brote'] == true ? 'Sí' : 'No'}\n${(c['nota_evolucion'] ?? '').toString()}";

  String _rigidezTooltip(Map<String, dynamic> c) =>
      "Rigidez: ${c['minutos_rigidez'] ?? 0} min\nEstado: ${c['estado_enfermedad'] ?? '-'}\nBrote: ${c['en_brote'] == true ? 'Sí' : 'No'}\n${(c['nota_evolucion'] ?? '').toString()}";

  String _growthTooltip(Map<String, dynamic> c, String label) =>
      "$label: ${label == 'Peso' ? c['peso_kg'] : c['talla_cm']}\nPrediagnóstico: ${(c['prediagnostico']?['diagnostico_combinado'] ?? c['estado_nutricional'] ?? '-').toString()}\n${(c['nota_evolucion'] ?? '').toString()}";

  String _simpleControlTooltip(Map<String, dynamic> c) =>
      "Fecha: ${_formatIsoDate(c['fecha_control'])}\nEstado: ${c['estado_enfermedad'] ?? '-'}\nBrote: ${c['en_brote'] == true ? 'Sí' : 'No'}\n${(c['nota_evolucion'] ?? '').toString()}";

  Widget _buildFoodIntakeSection() {
    final data = _consumoAlimentario;
    if (data == null) return const SizedBox.shrink();

    final resumen = Map<String, dynamic>.from(data['resumen'] ?? {});
    final items = _foodFilteredItems();
    final total = items.length;
    final totalPages = max(1, (total / 8).ceil());
    final page = _foodPage.clamp(1, totalPages).toInt();
    final start = total == 0 ? 0 : ((page - 1) * 8);
    final end = min(start + 8, total);
    final visible =
        total == 0 ? <Map<String, dynamic>>[] : items.sublist(start, end);
    final adherence =
        (resumen['adherencia_porcentaje'] as num?)?.toDouble() ?? 0;
    final hasItems = total > 0;
    final impact = _foodRiskLabel(adherence, hasItems);
    final impactColor = _foodRiskColor(impact);
    final badCount = (resumen['total_mala_aceptacion'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Consumo alimentario y aceptación de recetas",
            Icons.restaurant_menu_rounded),
        const SizedBox(height: 12),
        Text(
          "Resumen clínico para relacionar adherencia, aceptación alimentaria y posibles impactos en la evolución del paciente.",
          style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Resumen clínico",
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    _foodSummaryBullet(
                        "Adherencia general: ${adherence.toStringAsFixed(0)}% durante el periodo evaluado."),
                    _foodSummaryBullet(badCount > 0
                        ? "Se registran $badCount recetas con mala aceptación."
                        : "No se registran recetas con mala aceptación en el periodo."),
                    _foodSummaryBullet(
                        "Correlacione con síntomas, brote y tolerancia alimentaria en la siguiente consulta."),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: impactColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: impactColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Posible impacto clínico:",
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: impactColor)),
                      const SizedBox(height: 6),
                      Text(
                        "$impact\n${impact == "Sin registro" ? "sin datos suficientes para estimar impacto." : impact == "Alto" ? "baja adherencia con riesgo de afectar la evolución nutricional y clínica." : impact == "Medio" ? "requiere seguimiento estrecho para evitar deterioro nutricional." : "adherencia aceptable, solo vigilancia rutinaria."}",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _foodPlanFilterChip(
                  "Plan",
                  _foodPlanFilter,
                  (value) => setState(() {
                        _foodPlanFilter = value;
                        _foodPage = 1;
                      })),
              _foodPlanFilterChip(
                  "Momento",
                  _foodMomentFilter,
                  (value) => setState(() {
                        _foodMomentFilter = value;
                        _foodPage = 1;
                      })),
              _foodPlanFilterChip(
                  "Estado",
                  _foodStateFilter,
                  (value) => setState(() {
                        _foodStateFilter = value;
                        _foodPage = 1;
                      })),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: _foodMetricCard(
                    "Adherencia",
                    "${adherence.toStringAsFixed(0)}%",
                    _foodAdherenceColor(adherence, hasItems),
                    subtitle: _foodStateLabel(adherence, hasItems))),
            const SizedBox(width: 12),
            Expanded(
                child: _foodMetricCard(
                    "Mala aceptación", badCount.toString(), Colors.red,
                    subtitle: badCount == 0
                        ? "Sin alertas"
                        : "Recetas con calificación baja")),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _foodHallazgosCard(resumen)),
            const SizedBox(width: 12),
            Expanded(child: _foodAlertsCard(resumen)),
          ],
        ),
        const SizedBox(height: 14),
        _foodTableHeader(),
        if (visible.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200)),
            child: Text("No hay comidas para los filtros aplicados.",
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600)),
          )
        else
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                for (int i = 0; i < visible.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                  _foodTableRow(visible[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 10),
        _foodPagination(total, start, end, totalPages),
      ],
    );
  }

  Widget _foodSummaryBullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.35,
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _foodMetricCard(String title, String value, Color color,
          {String? subtitle}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.w900, color: color)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      );

  Widget _foodPlanFilterChip(
      String label, String value, void Function(String) onChanged) {
    final options = label == "Estado"
        ? const [
            {"value": "todo", "label": "Todos"},
            {"value": "solo_rechazadas", "label": "Solo rechazadas"},
            {"value": "posible_reaccion", "label": "Posible reacción"},
            {"value": "sin_registro", "label": "Sin registro"},
          ]
        : _foodOptionsFor(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.any((o) => o['value'] == value) ? value : "todo",
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          items: options
              .map((opt) => DropdownMenuItem<String>(
                    value: opt['value'] as String,
                    child: Text("${label}: ${opt['label']}",
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }

  List<Map<String, String>> _foodOptionsFor(String label) {
    final data = _consumoAlimentario ?? {};
    final items = (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (label == "Plan") {
      final seen = <String>{};
      return [
        const {"value": "todo", "label": "Todos"},
        ...((data['planes'] as List? ?? []).whereType<Map>().map((p) {
          final id = p['id_plan']?.toString() ?? "";
          final text =
              "${_formatIsoDate(p['fecha_inicio'])} - ${_formatIsoDate(p['fecha_fin'])}";
          return {"value": id, "label": text};
        }).where((m) => seen.add(m['value'] ?? ""))),
      ];
    }
    if (label == "Momento") {
      final seen = <String>{};
      return [
        const {"value": "todo", "label": "Todos"},
        ...items.map((i) {
          final value = (i['momento'] ?? "").toString();
          return {"value": value, "label": value};
        }).where((m) => seen.add(m['value'] ?? "")),
      ];
    }
    return const [
      {"value": "todo", "label": "Todos"}
    ];
  }

  List<Map<String, dynamic>> _foodFilteredItems() {
    final data = _consumoAlimentario ?? {};
    final items = (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return items.where((item) {
      final planId = item['id_plan']?.toString() ?? "";
      final momento = (item['momento'] ?? "").toString();
      final stars = int.tryParse(item['estrellas']?.toString() ?? "");
      final reason = _foodReason(item).toLowerCase();
      if (_foodPlanFilter != "todo" && planId != _foodPlanFilter) return false;
      if (_foodMomentFilter != "todo" && momento != _foodMomentFilter)
        return false;
      switch (_foodStateFilter) {
        case "solo_rechazadas":
          return stars != null && stars <= 2;
        case "posible_reaccion":
          return reason.contains("reaccion") ||
              reason.contains("reacción") ||
              reason.contains("alerg") ||
              reason.contains("roncha") ||
              reason.contains("otro");
        case "sin_registro":
          return stars == null || stars <= 0;
      }
      return true;
    }).toList();
  }

  Widget _foodHallazgosCard(Map<String, dynamic> resumen) {
    final ingredients = (resumen['ingredientes_mas_consumidos'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Hallazgos clave",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2A5F))),
          const SizedBox(height: 10),
          Text("El paciente consumió con mayor frecuencia:",
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (ingredients.isEmpty)
            Text("Sin consumo suficiente para generar hallazgos.",
                style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ingredients.take(10).map((ing) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.green.shade100)),
                  child: Text((ing['nombre'] ?? "-").toString(),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade800)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _foodAlertsCard(Map<String, dynamic> resumen) {
    final alerts = (resumen['alertas_aceptacion'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) {
        int score(Map<String, dynamic> item) {
          final reason = _foodReason(item).toLowerCase();
          final stars = int.tryParse(item['estrellas']?.toString() ?? "") ?? 5;
          final hasOther = reason.contains("otro") ||
              (item['comentario'] ?? '').toString().trim().isNotEmpty;
          return (hasOther ? 0 : 10) + stars;
        }

        return score(a).compareTo(score(b));
      });

    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Alertas relevantes",
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.red.shade800)),
            const SizedBox(height: 8),
            Text("Sin alertas para el periodo evaluado.",
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final visibleHeight = alerts.length > 3 ? 132.0 : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text("Alertas relevantes",
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.red.shade800)),
              const Spacer(),
              if (alerts.length > 3)
                Text("${alerts.length} alertas",
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.red.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: visibleHeight,
            child: ListView.separated(
              shrinkWrap: true,
              physics: alerts.length > 3
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (_, index) {
                final item = alerts[index];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade100)),
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined,
                          color: Colors.red.shade700, size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${item['receta_consumida'] ?? item['receta_asignada'] ?? 'Receta'}: ${_starsText(item['estrellas'])} · ${_foodReason(item)}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _foodTableHeader() => Container(
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(flex: 2, child: _foodHeaderText("Fecha")),
            Expanded(flex: 2, child: _foodHeaderText("Momento")),
            Expanded(flex: 4, child: _foodHeaderText("Receta")),
            Expanded(flex: 2, child: _foodHeaderText("Consumo")),
            Expanded(flex: 2, child: _foodHeaderText("Calificación")),
            Expanded(flex: 3, child: _foodHeaderText("Motivo")),
            Expanded(flex: 2, child: Center(child: _foodHeaderText("Acción"))),
          ],
        ),
      );

  Widget _foodHeaderText(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF334155)));

  Widget _foodTableRow(Map<String, dynamic> item) {
    final estado = (item['estado_consumo'] ?? "No marcada").toString();
    final color = _foodStatusColor(estado);
    final motivo = _foodReason(item);
    final badRating = _isBadFoodRating(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: badRating ? Colors.red.shade50 : Colors.white,
        border: Border(
            bottom: BorderSide(
                color:
                    badRating ? Colors.red.shade100 : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _foodCell(_formatIsoDate(item['fecha']))),
          Expanded(
              flex: 2, child: _foodCell(item['momento']?.toString() ?? "-")),
          Expanded(
              flex: 4,
              child: _foodCell(
                  (item['receta_consumida'] ?? item['receta_asignada'] ?? "-")
                      .toString(),
                  weight: FontWeight.w800,
                  color: badRating
                      ? Colors.red.shade800
                      : const Color(0xFF334155))),
          Expanded(flex: 2, child: _foodBadge(estado, color)),
          Expanded(
              flex: 2,
              child: _foodCell(_starsText(item['estrellas']),
                  color: _ratingColor(item['estrellas']),
                  weight: badRating ? FontWeight.w900 : FontWeight.w700)),
          Expanded(
              flex: 3,
              child: _foodCell(motivo,
                  color:
                      motivo == "-" ? Colors.blueGrey : Colors.red.shade700)),
          Expanded(
            flex: 2,
            child: Center(
              child: TextButton.icon(
                onPressed: () => _showFoodRecipeModal(item),
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text("Ver"),
                style: TextButton.styleFrom(
                    textStyle: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foodCell(String text,
          {FontWeight weight = FontWeight.w600, Color? color}) =>
      Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: weight,
            color: color ?? const Color(0xFF334155),
            height: 1.3),
      );

  Widget _foodBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );

  String _starsText(dynamic value) {
    final stars = int.tryParse(value?.toString() ?? "");
    if (stars == null || stars <= 0) return "Sin calificación";
    return "$stars/5";
  }

  bool _isBadFoodRating(Map<String, dynamic> item) {
    final stars = int.tryParse(item['estrellas']?.toString() ?? "");
    return stars != null && stars <= 2;
  }

  Color _ratingColor(dynamic value) {
    final stars = int.tryParse(value?.toString() ?? "");
    if (stars == null) return Colors.blueGrey;
    if (stars <= 1) return Colors.red.shade900;
    if (stars <= 2) return Colors.red;
    if (stars == 3) return Colors.orange;
    return Colors.green;
  }

  Color _foodStatusColor(String estado) {
    final e = estado.toLowerCase();
    if (e.contains("rechaz")) return Colors.red;
    if (e.contains("consum")) return Colors.green;
    if (e.contains("program")) return Colors.blue;
    return Colors.blueGrey;
  }

  Color _foodAdherenceColor(double value, bool hasItems) {
    if (!hasItems) return Colors.blueGrey;
    if (value >= 80) return Colors.green;
    if (value >= 50) return Colors.orange;
    return Colors.red;
  }

  String _foodStateLabel(double adherence, bool hasItems) {
    if (!hasItems) return "Sin registro";
    if (adherence >= 80) return "Alta";
    if (adherence >= 50) return "Media";
    return "Baja";
  }

  String _foodRiskLabel(double adherence, bool hasItems) {
    if (!hasItems) return "Sin registro";
    if (adherence >= 80) return "Bajo";
    if (adherence >= 50) return "Medio";
    return "Alto";
  }

  Color _foodRiskColor(String label) {
    switch (label) {
      case "Alto":
        return Colors.red;
      case "Medio":
        return Colors.orange;
      case "Bajo":
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  String _foodReason(Map<String, dynamic> item) {
    final motive = (item['motivo_rechazo'] ?? "").toString().trim();
    if (motive.isNotEmpty) return motive;
    final comment = (item['comentario'] ?? "").toString().trim();
    if (comment.isNotEmpty) return comment;
    return "-";
  }

  void _showFoodRecipeModal(Map<String, dynamic> item) {
    final ingredientes = (item['ingredientes'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final recipeName =
        (item['receta_consumida'] ?? item['receta_asignada'] ?? "Receta")
            .toString();
    final description = (item['descripcion_receta'] ??
            item['descripcion_larga'] ??
            item['descripcion'] ??
            "Sin descripción registrada.")
        .toString();
    final state = (item['estado_consumo'] ?? "No marcada").toString();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.restaurant_menu_rounded,
                        color:
                            _isBadFoodRating(item) ? Colors.red : greenBrand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(recipeName,
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A))),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _foodBadge(state, _foodStatusColor(state)),
                    _foodBadge(_starsText(item['estrellas']),
                        _ratingColor(item['estrellas'])),
                    if (_foodReason(item) != "-")
                      _foodBadge(_foodReason(item), Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                Text("Resumen",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey)),
                const SizedBox(height: 6),
                Text(description,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 18),
                Text("Ingredientes",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Expanded(
                  child: ingredientes.isEmpty
                      ? Center(
                          child: Text(
                              "Sin ingredientes registrados para esta receta.",
                              style: GoogleFonts.inter(
                                  color: Colors.blueGrey,
                                  fontWeight: FontWeight.w700)))
                      : ListView.separated(
                          itemCount: ingredientes.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final ing = ingredientes[i];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                  ing['es_principal'] == true
                                      ? Icons.star_rounded
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: ing['es_principal'] == true
                                      ? Colors.orange
                                      : Colors.blueGrey),
                              title: Text(ing['nombre']?.toString() ?? "-",
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _foodPagination(int total, int start, int end, int totalPages) {
    final displayStart = total == 0 ? 0 : start + 1;
    final displayEnd = total == 0 ? 0 : end;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          total == 0
              ? "Sin comidas para los filtros aplicados."
              : "Mostrando $displayStart a $displayEnd de $total comidas",
          style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.blueGrey,
              fontWeight: FontWeight.w700),
        ),
        Row(
          children: [
            IconButton(
              tooltip: "Página anterior",
              onPressed:
                  _foodPage > 1 ? () => setState(() => _foodPage--) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text("$_foodPage / $totalPages",
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF334155))),
            IconButton(
              tooltip: "Página siguiente",
              onPressed: _foodPage < totalPages
                  ? () => setState(() => _foodPage++)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }

  String _formatIsoDate(dynamic raw) {
    final text = raw?.toString();
    if (text == null || text.isEmpty) return "-";
    try {
      final dt = DateTime.parse(text);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return text.length >= 10 ? text.substring(0, 10) : text;
    }
  }

  void _autoRecomendarDerivados(String nombreSeleccionado) {
    final n = nombreSeleccionado.toLowerCase().trim();
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
    final derivados = _ingredientesCat.where((i) {
      final iname = (i['nombre'] ?? "").toString().toLowerCase();
      final sinonimos = (i['sinonimos'] as List? ?? [])
          .map((s) => s.toString().toLowerCase())
          .toList();
      if (iname == n) return false;
      bool match(String source, String target) {
        final sw = source.split(' ');
        return words.any((w) => sw.contains(w)) ||
            sw.any((sw) => words.contains(sw));
      }

      if (match(iname, n)) return true;
      for (var s in sinonimos) {
        if (match(s, n)) return true;
      }
      return false;
    }).toList();
    for (var d in derivados) {
      if (!_recomendacionesIng.any((x) => x['id'] == d['id']))
        setState(() => _recomendacionesIng.add(Map<String, dynamic>.from(d)));
    }
  }

  Widget _buildRecomendacionesSelector() {
    if (_ingredientesCat.isEmpty) return const Text("Cargando...");
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      StatefulBuilder(builder: (context, setInternalState) {
        final q = _ingRecomSearchCtrl.text.toLowerCase().trim();
        final matches = _ingredientesCat.where((e) {
          if (q.isEmpty) return false;
          final name = (e['nombre'] ?? "").toString().toLowerCase();
          final syns = (e['sinonimos'] as List? ?? [])
              .map((s) => s.toString().toLowerCase())
              .toList();
          return name.contains(q) || syns.any((s) => s.contains(q));
        }).toList();
        return Column(children: [
          TextFormField(
              controller: _ingRecomSearchCtrl,
              focusNode: _ingRecomFocus,
              onChanged: (v) => setInternalState(() {}),
              decoration: const InputDecoration(
                  labelText: "Buscar ingrediente...",
                  prefixIcon: Icon(Icons.search))),
          if (matches.isNotEmpty && _ingRecomFocus.hasFocus)
            Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 10)
                    ]),
                child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: min(matches.length, 50),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = matches[i];
                      final isSel = _recomendacionesIng
                          .any((ing) => ing['id'] == item['id']);
                      return ListTile(
                          dense: true,
                          title: Text(item['nombre'] ?? ""),
                          trailing: Icon(
                              isSel
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isSel ? Colors.blue : null),
                          onTap: () {
                            setState(() {
                              if (!isSel) {
                                _recomendacionesIng
                                    .add(Map<String, dynamic>.from(item));
                                _autoRecomendarDerivados(item['nombre'] ?? "");
                              } else {
                                _recomendacionesIng.removeWhere(
                                    (ing) => ing['id'] == item['id']);
                              }
                            });
                            setInternalState(() {});
                          });
                    }))
        ]);
      }),
      const SizedBox(height: 16),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recomendacionesIng
              .map((e) => Chip(
                  label: Text(e['nombre'] ?? "",
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  onDeleted: () =>
                      setState(() => _recomendacionesIng.remove(e)),
                  backgroundColor: Colors.blue.shade50,
                  deleteIconColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))))
              .toList())
    ]);
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final maxVal = data.reduce(max);
    final minVal = data.reduce(min);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    for (var i = 0; i < data.length; i++) {
      final x = i * (size.width / (data.length - 1));
      final y = size.height - ((data[i] - minVal) / range * size.height);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
