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
import "../../../shared/widgets/nutri_avatar.dart";
import "../data/supervision_provider.dart";

import '../../../shared/widgets/escalas/escala_selector.dart';

class RegistroMensualPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> paciente;
  const RegistroMensualPage({super.key, required this.paciente});

  @override
  ConsumerState<RegistroMensualPage> createState() => _RegistroMensualPageState();
}

class _RegistroMensualPageState extends ConsumerState<RegistroMensualPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  bool _yaEvaluadoHoy = false;
  Map<String, dynamic>? _expediente;
  int? _idControlEditando;
  Timer? _debounceOMS;

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
  final List<Map<String, dynamic>> _condicionesTemp = [];
  List<Map<String, dynamic>> _recomendacionesIng = [];
  List<dynamic> _condicionesTemporalesCat = [];
  List<dynamic> _patologiasCat = [];
  List<dynamic> _ingredientesCat = [];
  List<dynamic> _subgruposCat = [];
  List<dynamic> _restriccionesAlimentariasCat = [];

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
    _tabController = TabController(length: 2, vsync: this);
    _cargarExpediente();
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("catalogos/condiciones");
      final resRegistro = await dio.get("registro/paciente-integral/catalogos");
      final resIng = await dio.get("nutricionista/ingredientes/catalogo-simple");
      final resSubs = await dio.get("nutricionista/subgrupos/catalogo-simple");
      
      if (mounted) {
        setState(() {
          final allCond = res.data as List;
          _condicionesTemporalesCat = allCond.where((e) => (e['id_tipo'] ?? e['id_tipo_condicion']) == 2).toList();
          _patologiasCat = allCond.where((e) => (e['id_tipo'] ?? e['id_tipo_condicion']) == 1).toList();
          _ingredientesCat = resIng.data as List? ?? [];
          _subgruposCat = resSubs.data as List? ?? [];
          _restriccionesAlimentariasCat = (resRegistro.data as Map<String, dynamic>)["restricciones_alimentarias"] as List? ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error cargando catálogo: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounceOMS?.cancel();
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

  Future<void> _cargarExpediente() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("pacientes/${widget.paciente['id']}/expediente-completo");
      final data = res.data;
       
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final historial = data['historial_controles'] as List? ?? [];
      final evaluadoHoy = historial.any((c) => c['fecha_control'] == hoy);

      setState(() { 
        _expediente = data; 
        _yaEvaluadoHoy = evaluadoHoy;
        _idPatologiaBase = data['diagnostico']?['id_condicion'];
        
        final al = data['alergias'] ?? {};
        _alergiasSubgrupos = List<Map<String, dynamic>>.from(al['subgrupos'] ?? []);
        _alergiasIngredientes = List<Map<String, dynamic>>.from(al['ingredientes'] ?? []);
        _restriccionesAlimentarias = List<String>.from(al['restricciones_codigos'] ?? []);
        _lactosa = _restriccionesAlimentarias.contains("INTOLERANCIA_LACTOSA");
        
        _loading = false; 
      });
    } catch (e) {
      setState(() => _loading = false);
    }
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
     
    final fnac = widget.paciente['fecha_nacimiento'];
    final idSexo = widget.paciente['id_sexo'];
     
    if (fnac == null || idSexo == null) return;

    setState(() => _calculandoOMS = true);
    try {
      final dio = ref.read(dioProvider);
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
          _gananciaPeso = (res.data['ganancia_peso_necesaria'] ?? 0).toDouble();
          _gananciaTalla = (res.data['ganancia_talla_necesaria'] ?? 0).toDouble();
          _estadoPeso = res.data['estado_peso'] ?? "mantener";
          _pesoIdeal = (res.data['peso_ideal'] ?? 0).toDouble();
          _tallaIdeal = (res.data['talla_ideal'] ?? 0).toDouble();
          
          final String combined = (res.data['diagnostico_combinado'] ?? "$_omsStatusPeso / $_omsStatusTalla").toString().toLowerCase();
          
          if (combined.contains("severa") || combined.contains("emaciación") || combined.contains("obesidad") || combined.contains("desnutrición")) {
            _omsColor = Colors.red;
          } else if (combined.contains("sobrepeso") || combined.contains("baja") || combined.contains("delgadez") || combined.contains("bajo peso") || combined.contains("riesgo")) {
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
    setState(() {
      _idControlEditando = h['id'];
      _peso.text = h['peso_kg']?.toString() ?? "";
      _talla.text = h['talla_cm']?.toString() ?? "";
      _pcr.text = h['valor_pcr']?.toString() ?? "";
      _vsg.text = h['valor_vsg']?.toString() ?? "";
      _artInflam.text = h['articulaciones_inflamadas']?.toString() ?? "0";
      _artDolor.text = h['articulaciones_dolorosas']?.toString() ?? "0";
      _rigidez.text = h['minutos_rigidez']?.toString() ?? "";
      _notas.text = h['nota_evolucion'] ?? "";
      _dolor = (h['puntos_dolor'] ?? 0).toDouble();
      _inflamacion = (h['escala_inflamacion'] ?? 0).toDouble();
      _fatiga = (h['nivel_fatiga'] ?? 10).toDouble();
      _brote = h['en_brote'] ?? false;
      _estadoEnfermedad = h['estado_enfermedad'] ?? "Seguimiento";
      _proximaCita = DateTime.tryParse(h['fecha_proxima_cita'] ?? "") ?? DateTime.now().add(const Duration(days: 30));
      
      if (_expediente != null && _expediente!['recomendaciones'] != null) {
        _recomendacionesIng = List<Map<String, dynamic>>.from(_expediente!['recomendaciones']['ingredientes'] ?? []);
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
        "valor_pcr": _pcr.text, 
        "valor_vsg": _vsg.text, 
        "articulaciones_inflamadas": _artInflam.text,
        "articulaciones_dolorosas": _artDolor.text, 
        "minutos_rigidez": _rigidez.text,
        "en_brote": _brote, 
        "estado_enfermedad": _estadoEnfermedad,
        "nota_evolucion": _notas.text, 
        "fecha_proxima_cita": _proximaCita.toIso8601String().split("T").first,
        "condiciones_temporales": _condicionesTemp,
        "recomendaciones_ingredientes": _recomendacionesIng.map((e) => e['id']).toList(),
        
        // Nuevos campos de Alergias e Intolerancias (para actualizar record permanente)
        "alergias_subgrupos": _alergiasSubgrupos.map((e) => e['id']).toList(),
        "alergias_ingredientes": _alergiasIngredientes.map((e) => e['id']).toList(),
        "restricciones_alimentarias": sanitizedRestricciones,
        "es_intolerante_lactosa": _lactosa
      };
      if (_idControlEditando == null) {
        await dio.post("pacientes/${widget.paciente['id']}/control-mensual", data: payload);
      } else {
        await dio.put("pacientes/control-mensual/$_idControlEditando", data: payload);
      }
      if (mounted) NutriSnack.show(context, "✅ Se han actualizado los campos de Peso, Talla y Evaluación correctamente", ref: ref);
       
      ref.invalidate(medicoPatientsProvider);
       
      _limpiarForm(); _cargarExpediente();
    } catch (e) {
      if (mounted) NutriSnack.show(context, "Error: $e", isError: true, ref: ref);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _limpiarForm() {
    _peso.clear(); _talla.clear(); _pcr.clear(); _vsg.clear(); _artInflam.text="0"; _artDolor.text="0"; _rigidez.clear(); _notas.clear();
    setState(() { _dolor=0; _inflamacion=0; _fatiga=10; _brote=false; _idControlEditando=null; _omsStatusPeso="PENDIENTE"; });
  }

  String _formatEdad(String? fechaNac) {
    if (fechaNac == null) return "-";
    try {
      final birthDate = DateTime.parse(fechaNac);
      final now = DateTime.now();
      int years = now.year - birthDate.year;
      int months = now.month - birthDate.month;
      if (now.day < birthDate.day) months--;
      if (months < 0) { years--; months += 12; }
      return "$years años y $months meses";
    } catch (_) { return "-"; }
  }

  Widget _buildLeftSummary() {
    if (_expediente == null) return const SizedBox(width: 350, child: Center(child: CircularProgressIndicator()));
     
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
    final bool esIntolerante = (al['subgrupos'] as List? ?? []).any((a) => idsLacteos.contains(a['id']));
     
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: 1000,
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.assignment_ind_outlined, color: greenBrand, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("EXPEDIENTE MAESTRO INTEGRAL", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 20)),
                  Text("Registro oficial del paciente y soporte legal en el sistema ReumaNutri", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
              const Spacer(),
              IconButton.filledTonal(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close))
            ]),
            const Divider(height: 48),
            Flexible(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildExpSection("1. IDENTIDAD DEL PACIENTE", [
                      _expItem("Nombres Completos", p['nombre_completo']),
                      _expItem("Cédula / ID", p['cedula']),
                      _expItem("Fecha de Nacimiento", p['fecha_nacimiento']),
                      _expItem("Sexo Biológico", p['sexo_nombre']),
                      const SizedBox(height: 16),
                      const Text("LOCALIZACIÓN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _expItem("Cantón de Residencia", p['canton_nombre']),
                      _expItem("Parroquia", p['parroquia_nombre']),
                    ])),
                    const SizedBox(width: 40),
                    Expanded(child: _buildExpSection("2. REPRESENTANTE LEGAL", [
                      _expItem("Nombre Completo", t['nombre_completo']),
                      _expItem("Cédula del Tutor", t['cedula']),
                      _expItem("Relación / Parentesco", t['parentesco_nombre'], isBold: true),
                      const SizedBox(height: 16),
                      const Text("DATOS DE CONTACTO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _expItem("Correo Electrónico", t['email']),
                      _expItem("Teléfono / Móvil", t['telefono']),
                      _expItem("Dirección Domiciliaria", t['direccion']),
                    ])),
                    const SizedBox(width: 40),
                    Expanded(child: _buildExpSection("3. ESTADO CLÍNICO ACTUAL", [
                      _expItem("Enfermedad Autoinmune", d['condicion_nombre'] ?? "No registrada", isHighlight: true),
                      _expItem("Estado Nutricional (OMS)", c['estado_nutricional'], isBold: true),
                      _expItem("Relación Peso / Talla", "${c['peso_kg'] ?? '-'} kg / ${c['talla_cm'] ?? '-'} cm"),
                      const SizedBox(height: 16),
                      const Text("SEGURIDAD ALIMENTARIA", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.orange, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _expItem("Intolerancia a Lactosa", esIntolerante ? "SÍ (RESTRICCIÓN ACTIVA)" : "NO DETECTADA", isAlert: esIntolerante),
                      _expItem("Alergias Detectadas", (al['subgrupos'] as List? ?? []).map((e) => e['nombre']).join(", ").isEmpty ? "Ninguna" : (al['subgrupos'] as List? ?? []).map((e) => e['nombre']).join(", ")),
                      const SizedBox(height: 16),
                      const Text("PRÓXIMOS EVENTOS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _expItem("Último Registro", c['fecha_control']),
                      _expItem("Cita Programada", c['fecha_proxima_cita'], isHighlight: true),
                    ])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.check_circle_outline), label: const Text("CERRAR EXPEDIENTE MAESTRO"), style: FilledButton.styleFrom(backgroundColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 20)))),
            ])
          ]),
        ),
      ),
    );
  }

  Widget _buildExpSection(String title, List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: greenBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: greenBrand, letterSpacing: 0.5)),
    ),
    const SizedBox(height: 24), 
    ...items
  ]);

  Widget _expItem(String l, dynamic v, {bool isBold = false, bool isAlert = false, bool isHighlight = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 16), 
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(l, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.2)), 
        const SizedBox(height: 4),
        Text(
          v?.toString() ?? "NO REGISTRADO", 
          style: GoogleFonts.montserrat(
            fontSize: 13, 
            fontWeight: (isBold || isAlert) ? FontWeight.w900 : FontWeight.w600,
            color: isAlert ? Colors.red : (isHighlight ? greenBrand : const Color(0xFF1E293B)),
          )
        )
      ]
    )
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTema.grisLienzo,
          body: Row(
            children: [
              _buildLeftSummary(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [_buildFormTab(), _buildHistoryTab()]
                      )
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_loading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: greenBrand, strokeWidth: 4),
            const SizedBox(height: 24),
            Text(
              "CARGANDO CONTROL MENSUAL...",
              style: GoogleFonts.montserrat(color: const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
          ],
        ),
      ),
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

  Widget _buildHeaderBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
    decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
    child: Row(children: [
      IconButton.filledTonal(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16), onPressed: () => ref.read(medicoNavProvider.notifier).state = MedicoView.list),
      const SizedBox(width: 24),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text("Seguimiento Clínico del Paciente", style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.5)),
        Text("Módulo para registro mensual y monitoreo de evolución del paciente pediátrico reumatológico.", style: GoogleFonts.montserrat(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500))
      ])
    ])
  );
  
  Widget _buildTabBar() => Container(
    height: 60,
    color: Colors.white,
    child: TabBar(
      controller: _tabController,
      labelColor: greenBrand,
      unselectedLabelColor: const Color(0xFF94A3B8),
      indicator: const UnderlineTabIndicator(borderSide: BorderSide(width: 4, color: greenBrand), insets: EdgeInsets.symmetric(horizontal: 60)),
      labelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      tabs: const [Tab(text: "REGISTRO CLÍNICO"), Tab(text: "MONITOR DE EVOLUCIÓN")]
    )
  );

  Widget _buildFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_yaEvaluadoHoy && _idControlEditando == null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(child: Text("PACIENTE YA EVALUADO HOY. Si registra una nueva valoración, se sobreescribirá el control de esta fecha.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange))),
            ]),
          ),
        ],
        
        // 1. SIGNOS VITALES Y ANTROPOMETRÍA
        _sectionHeader("1. SIGNOS VITALES Y ANTROPOMETRÍA", Icons.monitor_weight_outlined),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(children: [
            Row(children: [
              Expanded(child: _field(_peso, "Peso Actual (kg)*", Icons.scale_outlined, onChanged: (_) => _debouncedOMS())),
              const SizedBox(width: 20),
              Expanded(child: _field(_talla, "Talla Actual (cm)*", Icons.height_rounded, onChanged: (_) => _debouncedOMS())),
            ]),
            const SizedBox(height: 24),
            _buildOMSDiagnosisRow(),
          ]),
        ),
        const SizedBox(height: 48),

        // 2. EVALUACIÓN DE ACTIVIDAD REUMÁTICA
        _sectionHeader("2. EVALUACIÓN DE ACTIVIDAD REUMÁTICA", Icons.healing_outlined),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EscalaSelector(
                titulo: "DOLOR",
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
                etiquetas: [EscalaEtiqueta("Leve", 3), EscalaEtiqueta("Moderado", 4), EscalaEtiqueta("Severo", 4)],
                colorActivo: Colors.red,
                colorFondoActivo: Colors.red,
                backgroundColor: const Color(0xFFF8FAFC),
                showIdentityRow: false,
                onChanged: (v) => setState(() => _dolor = v.toDouble()),
                puntajeLabel: "${_dolor.toInt()}/10",
                headerIcon: const Icon(Icons.healing_rounded, color: Colors.red, size: 28),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildEVACard(
                "INFLAMACIÓN",
                _inflamacion,
                3,
                (v) => setState(() => _inflamacion = v),
                icon: Icons.verified_user_outlined,
                labels: ["0 = Sin inflamación", "1 = Leve", "2 = Moderada", "3 = Severa / Activa"],
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
                "FATIGA",
                _fatiga,
                10,
                (v) => setState(() => _fatiga = v),
                icon: Icons.battery_full_rounded,
                labels: ["0-3 = Agotamiento", "4-7 = Intermedio", "8-10 = Alta energía"],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: _buildCounterField("Art. Inflamadas", _artInflam, Icons.track_changes_outlined)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildCounterField("Art. Dolorosas", _artDolor, Icons.back_hand_outlined)),
                  ]),
                  const SizedBox(height: 24),
                  _buildBroteToggle(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const SizedBox(height: 48),

        _sectionHeader("3. SÍNTOMAS AGUDOS TEMPORALES", Icons.event_note_rounded),
        const SizedBox(height: 24),
        _buildSintomasTemporalesGrid(),
        const SizedBox(height: 48),

        _sectionHeader("4. RECOMENDACIÓN DE INGREDIENTES", Icons.thumb_up_alt_outlined),
        const SizedBox(height: 24),
        _buildRecomendacionesSelector(),
        const SizedBox(height: 48),

        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader("5. SEGUIMIENTO Y OBSERVACIONES", Icons.event_note_rounded),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: ListTile(leading: const Icon(Icons.calendar_month, color: greenBrand), title: const Text("Próxima Cita*", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), subtitle: Text(DateFormat('EEEE, dd/MM/yyyy', 'es').format(_proximaCita).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: greenBrand)), onTap: () async { final d = await showDatePicker(context: context, initialDate: _proximaCita, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180))); if (d != null) setState(() => _proximaCita = d); })
            ),
          ])),
        ]),
        const SizedBox(height: 24),
        _field(_notas, "Observaciones Médicas", Icons.edit_note, maxLines: 4),
        const SizedBox(height: 48),

        SizedBox(width: double.infinity, height: 60, child: FilledButton.icon(onPressed: _loading ? null : _guardarConsulta, icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded), label: Text(_idControlEditando == null ? "REGISTRAR VALORACIÓN" : "GUARDAR CAMBIOS", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), style: FilledButton.styleFrom(backgroundColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
      ]),
    );
  }

  Widget _lactoseCard(bool val, String title, String desc) {
    final bool sel = _lactosa == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _lactosa = val;
          if (val) { if (!_restriccionesAlimentarias.contains("INTOLERANCIA_LACTOSA")) _restriccionesAlimentarias.add("INTOLERANCIA_LACTOSA"); }
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
                    Text(title, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? greenBrand : const Color(0xFF0F172A))),
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
          color: isSel ? greenBrand.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSel ? greenBrand : Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSel ? greenBrand : Colors.blueGrey),
            const SizedBox(width: 10),
            Text(name, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? greenBrand : Colors.blueGrey)),
            if (isSel) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 14, color: greenBrand),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelector(String label, List items, List<Map<String, dynamic>> selectedList, TextEditingController searchCtrl, FocusNode focusNode) {
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
            controller: searchCtrl, focusNode: focusNode, 
            onChanged: (v) => setInternalState(() {}), 
            decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.search))
          ),
          if (matches.isNotEmpty && focusNode.hasFocus) Container(
            constraints: const BoxConstraints(maxHeight: 200), 
            margin: const EdgeInsets.only(top: 8), 
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), 
            child: ListView.separated(
              shrinkWrap: true, itemCount: min(matches.length, 50), 
              separatorBuilder: (_, __) => const Divider(height: 1), 
              itemBuilder: (ctx, i) {
                final item = matches[i]; final id = item['id'];
                final isSel = selectedList.any((ing) => ing['id'] == id);
                return ListTile(
                  dense: true, title: Text(item['nombre'] ?? ""), 
                  trailing: Icon(isSel ? Icons.check_circle : Icons.add_circle_outline, color: isSel ? Colors.red : null), 
                  onTap: () { 
                    setState(() { 
                      if (!isSel) selectedList.add(Map<String, dynamic>.from(item)); 
                      else selectedList.removeWhere((ing) => ing['id'] == id); 
                    }); 
                    setInternalState(() {}); 
                  }
                );
              }
            )
          )
        ]);
      }),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: selectedList.map((e) => Chip(
        label: Text(e['nombre'] ?? "", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)), 
        onDeleted: () => setState(() => selectedList.remove(e)), 
        backgroundColor: Colors.red.shade50, deleteIconColor: Colors.red, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
      )).toList())
    ]);
  }

  Widget _buildSintomasTemporalesGrid() {
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
                border: Border.all(color: sel ? greenBrand.withOpacity(0.3) : const Color(0xFFE2E8F0))
              ),
              child: ExpansionTile(
                key: Key("temp_ctrl_$id"), 
                initiallyExpanded: sel, 
                shape: const Border(),
                leading: Checkbox(
                  activeColor: greenBrand, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), 
                  value: sel, 
                  onChanged: (v) {
                    if (v == true) {
                      final ini = DateTime.now();
                      setState(() => _condicionesTemp.add({
                        "id": id, 
                        "nombre": c['nombre'], 
                        "fecha_inicio": ini.toIso8601String().split('T')[0], 
                        "fecha_fin": ini.add(Duration(days: duracionSugerida)).toIso8601String().split('T')[0]
                      }));
                    } else { 
                      setState(() => _condicionesTemp.removeAt(index)); 
                    }
                  }
                ),
                title: Text(c['nombre']?.toString() ?? "Condición", 
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: sel ? FontWeight.w700 : FontWeight.w600, color: sel ? greenBrand : const Color(0xFF1E293B))),
                subtitle: Text(sel ? "Activa por $duracionSugerida días" : "Sugerencia: $duracionSugerida días", 
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                children: sel ? [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildTemporalDatesRow(index, duracionSugerida),
                  )
                ] : [],
              ),
            );
          }).toList(),
        );
      }
    );
  }

  Widget _buildTemporalDatesRow(int index, int duracionSugerida) {
    final inicio = _condicionesTemp[index]['fecha_inicio']?.toString() ?? DateTime.now().toIso8601String().split('T')[0];
    final fin = _condicionesTemp[index]['fecha_fin']?.toString() ?? DateTime.now().add(Duration(days: duracionSugerida)).toIso8601String().split('T')[0];
    final finDate = DateTime.tryParse(fin) ?? DateTime.now();
    final restantes = finDate.difference(DateTime.now()).inDays;
    final diasRestantes = restantes < 0 ? 0 : restantes;
    return Row(
      children: [
        Expanded(
          child: _datePickerSmall("INICIO", inicio, (d) => setState(() {
            _condicionesTemp[index]['fecha_inicio'] = d.toIso8601String().split('T')[0];
            _condicionesTemp[index]['fecha_fin'] = d.add(Duration(days: duracionSugerida)).toIso8601String().split('T')[0];
          })),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dateStaticSmall("FIN", fin),
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
              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOMSDiagnosisRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("DIAGNÓSTICO NUTRICIONAL OMS", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF475569))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _omsDiagItem("Diagnóstico de peso", _omsStatusPeso, Icons.scale_rounded)),
          const SizedBox(width: 20),
          Expanded(child: _omsDiagItem("Diagnóstico de talla", _omsStatusTalla, Icons.height_rounded)),
        ]),
        if (_resumenClinico.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _omsColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: _omsColor.withOpacity(0.1))),
            child: _richSummary(_resumenClinico, _omsColor),
          )
        ]
      ],
    );
  }

  Widget _omsDiagItem(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
    child: Row(children: [
      Icon(icon, size: 18, color: Colors.blueGrey),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        Text(value.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
      ]),
      const Spacer(),
      if (_calculandoOMS) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: greenBrand))
      else Container(width: 12, height: 12, decoration: BoxDecoration(color: _omsColor, shape: BoxShape.circle))
    ]),
  );

  Widget _subHeader(String t, IconData i) => Row(children: [Icon(i, size: 18, color: greenBrand), const SizedBox(width: 12), Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0F172A), letterSpacing: 0.5))]);

  Widget _buildEVACard(String title, double val, int max, Function(double) onC, {required IconData icon, required List<String> labels}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: greenBrand.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: greenBrand, size: 20)),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          ]),
          Text("${val.toInt()}/$max", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: greenBrand)),
        ]),
        const SizedBox(height: 24),
        Row(children: List.generate(max + 1, (index) {
          final isSel = val.toInt() == index;
          return Expanded(child: InkWell(onTap: () => onC(index.toDouble()), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 2), height: 36, decoration: BoxDecoration(color: isSel ? greenBrand : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: isSel ? greenBrand : Colors.grey.shade200)), child: Center(child: Text("$index", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: isSel ? Colors.white : Colors.blueGrey))))));
        })),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: labels.map((l) => Text(l, style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.blueGrey))).toList()),
      ]),
    );
  }

  Widget _buildCounterField(String label, TextEditingController ctrl, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
      const SizedBox(height: 8),
      Container(height: 48, decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: Row(children: [
        const SizedBox(width: 12),
        Icon(icon, size: 18, color: Colors.blueGrey),
        Expanded(child: TextField(controller: ctrl, textAlign: TextAlign.center, keyboardType: TextInputType.number, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700), decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.zero))),
        IconButton(onPressed: () { int v = int.tryParse(ctrl.text) ?? 0; if (v > 0) ctrl.text = (v - 1).toString(); setState(() {}); }, icon: const Icon(Icons.remove, size: 16)),
        IconButton(onPressed: () { int v = int.tryParse(ctrl.text) ?? 0; ctrl.text = (v + 1).toString(); setState(() {}); }, icon: const Icon(Icons.add, size: 16)),
      ])),
    ]);
  }

  Widget _buildBroteToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _brote ? Colors.red.withOpacity(0.05) : greenBrand.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: _brote ? Colors.red.withOpacity(0.1) : greenBrand.withOpacity(0.1))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _brote ? Colors.red : greenBrand, shape: BoxShape.circle), child: Icon(_brote ? Icons.warning_amber_rounded : Icons.check_rounded, color: Colors.white, size: 20)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("¿TIENE BROTE ACTIVO?", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: _brote ? Colors.red.shade900 : Colors.green.shade900)),
          Text("Indique si el paciente presenta un brote en este momento.", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
        ])),
        Switch.adaptive(value: _brote, activeColor: Colors.red, onChanged: (v) => setState(() => _brote = v)),
      ]),
    );
  }

  Widget _buildActiveStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(color: _brote ? Colors.red.withOpacity(0.1) : greenBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _brote ? Colors.red.withOpacity(0.2) : greenBrand.withOpacity(0.2))),
      child: Row(children: [
        Icon(_brote ? Icons.error_outline : Icons.verified_outlined, color: _brote ? Colors.red : greenBrand),
        const SizedBox(width: 16),
        Text(_brote ? "BROTE ACTIVO DETECTADO" : "SIN BROTE ACTIVO", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w900, color: _brote ? Colors.red : greenBrand)),
        const Spacer(),
        Switch.adaptive(value: _brote, activeColor: Colors.red, onChanged: (v) => setState(() => _brote = v)),
      ]),
    );
  }

  Widget _dropdown(String l, List items, int? val, Function(int?) onC, {String? hint}) => DropdownButtonFormField<int>(
    value: val, 
    isExpanded: true,
    hint: hint != null ? Text(hint, style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w500)) : null,
    items: items.map((e) => DropdownMenuItem<int>(
      value: e['id'], 
      child: Text(e['nombre'] ?? e['descripcion'] ?? "", 
        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))
    )).toList(), 
    onChanged: onC, 
    decoration: InputDecoration(labelText: l)
  );

  Widget _datePickerSmall(String l, String v, Function(DateTime) onP) => InkWell(
    onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.parse(v), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 90))); if (d != null) onP(d); }, 
    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(v, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: greenBrand))]))
  );

  Widget _dateStaticSmall(String l, String v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Row(children: [
      const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF64748B)),
      const SizedBox(width: 6),
      Expanded(child: Text("$l: ${DateFormat('EEEE, d MMMM y', 'es').format(DateTime.tryParse(v) ?? DateTime.now())}", style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155), fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _richSummary(String text, Color color) {
    List<TextSpan> spans = [];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) spans.add(TextSpan(text: parts[i], style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)));
      else spans.add(TextSpan(text: parts[i]));
    }
    return RichText(text: TextSpan(style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, height: 1.4, fontFamily: GoogleFonts.montserrat().fontFamily), children: spans));
  }

  Widget _sectionHeader(String t, IconData i) => Row(children: [Icon(i, size: 18, color: greenBrand), const SizedBox(width: 12), Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0F172A), letterSpacing: 0.5))]);

  Widget _field(TextEditingController c, String l, IconData i, {int maxLines = 1, Function(String)? onChanged, bool enabled = true, String? helper}) => TextFormField(controller: c, maxLines: maxLines, enabled: enabled, onChanged: onChanged, decoration: InputDecoration(labelText: l, helperText: helper, prefixIcon: Icon(i, size: 18), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))));

  Widget _buildHistoryTab() {
    if (_loading && _expediente == null) return const Center(child: CircularProgressIndicator());
    final historial = _expediente?['historial_controles'] as List? ?? [];
    if (historial.isEmpty) return const Center(child: Text("No hay registros previos para graficar."));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("CENTRO DE ANÁLISIS CLÍNICA", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A))), const SizedBox(height: 8), const Text("Prioridad Reumatológica: Monitoreo de actividad de enfermedad AIJ + Estado nutricional integral.", style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
        const SizedBox(height: 40), _buildSectionHeader("REUMATOLOGÍA", "Actividad de enfermedad AIJ, marcadores inflamatorios y conteo articular", Icons.medical_services, Colors.red),
        const SizedBox(height: 24), _sectionHeader("1. MONITOREO DE SÍNTOMAS (EVA 0-10) - DOLOR Y ENERGÍA", Icons.healing_outlined), const SizedBox(height: 16), _buildSymptomsChart(historial), const SizedBox(height: 12), _buildDynamicConclusion(historial, "symptoms"), _buildChartExplanation("¿Qué significa esta gráfica?", "• DOLOR (EVA 0-10): 0=Sin dolor, 10=Dolor insoportable.\n• ENERGÍA / FATIGA (0-10): 10=Energía máxima, 0=Agotado.\n✅ OBJETIVO: Remisión de síntomas (Dolor <=2, Energía/Bienestar >=7).", Colors.orange),
        const SizedBox(height: 40), _sectionHeader("2. ACTIVIDAD DE LA ENFERMEDAD (0-10) - INFLAMACIÓN ARTICULAR", Icons.coronavirus_outlined), const SizedBox(height: 16), _buildInflammationChart(historial), const SizedBox(height: 12), _buildDynamicConclusion(historial, "inflammation_scale"), _buildChartExplanation("¿Qué significa esta gráfica?", "• INFLAMACIÓN (0-10): Grado de actividad inflamatoria sistémica percibida.\n✅ OBJETIVO: Mantener nivel de inflamación en 0.", Colors.red),
        const SizedBox(height: 40), _sectionHeader("3. CONTEOS ARTICULARES - AIJ", Icons.adjust), const SizedBox(height: 16), _buildJointCountChart(historial), const SizedBox(height: 12), _buildDynamicConclusion(historial, "joints"), _buildChartExplanation("¿Qué significa esta gráfica?", "• ARTICULACIONES INFLAMADAS/DOLOROSAS: Signos de sinovitis activa.\n✅ OBJETIVO: Cero articulaciones inflamadas.", Colors.red),
        const SizedBox(height: 56), _buildSectionHeader("NUTRICIÓN", "Estado nutricional según OMS, objetivos de peso y talla para el crecimiento", Icons.restaurant_menu, Colors.green),
        const SizedBox(height: 24), _sectionHeader("4. MONITOR Z-SCORE BMI/EDAD (OMS)", Icons.analytics_outlined), const SizedBox(height: 16), _buildZScoreChart(historial), const SizedBox(height: 12), _buildDynamicConclusion(historial, "z_score"), _buildChartExplanation("¿Qué significa esta gráfica?", "• Z-SCORE BMI/EDAD: 0 = promedio. Rango normal: -2.0 a +2.0.\n✅ OBJETIVO: Mantener Z-Score entre -1 y +1.", Colors.green),
        const SizedBox(height: 40), _sectionHeader("5. TERMÓMETROS DE PROGRESO - PESO Y TALLA", Icons.thermostat_rounded), const SizedBox(height: 16), _buildThermometerGauges(historial), const SizedBox(height: 12), _buildDynamicConclusion(historial, "thermometers"),
        const SizedBox(height: 56), _sectionHeader("LÍNEA DE TIEMPO DE EVENTOS CLÍNICOS", Icons.timeline_rounded), const SizedBox(height: 24), _buildClinicalTimeline(historial),
        const SizedBox(height: 56), _sectionHeader("REGISTROS CRONOLÓGICOS", Icons.list_alt_rounded), const SizedBox(height: 24), ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: historial.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (context, index) => _buildHistoryItem(historial[historial.length - 1 - index])),
      ]),
    );
  }

  Widget _buildChartExplanation(String title, String content, Color color) => Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.15))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lightbulb_outline, color: color, size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)), const SizedBox(height: 8), Text(content, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.blueGrey, height: 1.6))]))]));
  Widget _buildSectionHeader(String title, String subtitle, IconData icon, Color color) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))), child: Row(children: [Icon(icon, color: color, size: 28), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: color)), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.blueGrey))]))]));

  Widget _buildZScoreChart(List<dynamic> history) => Container(height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)), child: LineChart(LineChartData(minY: -3, maxY: 3, gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => v == 0 ? FlLine(color: Colors.green.withOpacity(0.5), strokeWidth: 2) : (v.abs() == 2 ? FlLine(color: Colors.orange.withOpacity(0.3), strokeWidth: 1, dashArray: [5, 5]) : (v.abs() == 3 ? FlLine(color: Colors.red.withOpacity(0.3), strokeWidth: 1, dashArray: [5, 5]) : FlLine(color: Colors.grey.shade100, strokeWidth: 1)))), titlesData: FlTitlesData(rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, meta) => v.toInt() >= 0 && v.toInt() < history.length ? Text(DateFormat('dd/MM').format(DateTime.parse(history[v.toInt()]['fecha_control'])), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)) : const Text(""))), leftTitles: AxisTitles(axisNameWidget: const Text("Z-SCORE BMI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(1), style: TextStyle(fontSize: 10, color: v == 0 ? Colors.green : (v.abs() == 2 ? Colors.orange : (v.abs() == 3 ? Colors.red : Colors.grey)), fontWeight: FontWeight.bold))))), borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)), lineBarsData: [LineChartBarData(spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['z_score_bmi'] ?? 0).toDouble())).toList(), isCurved: true, color: const Color(0xFF2563EB), barWidth: 4, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: const Color(0xFF2563EB).withOpacity(0.05)))])));

  Widget _buildThermometerGauges(List<dynamic> history) {
    if (history.isEmpty) return const SizedBox.shrink();
    final ultimo = history.last;
    final pesoActual = (ultimo['peso_kg'] ?? 0).toDouble();
    final pesoIdeal = (ultimo['peso_ideal'] ?? pesoActual).toDouble();
    final tallaActual = (ultimo['talla_cm'] ?? 0).toDouble();
    final tallaIdeal = (ultimo['talla_ideal'] ?? tallaActual).toDouble();
    double pesoPct = pesoIdeal > 0 ? (pesoActual / pesoIdeal).clamp(0.7, 1.3) : 1.0;
    double tallaPct = tallaIdeal > 0 ? (tallaActual / tallaIdeal).clamp(0.85, 1.15) : 1.0;
    
    String pesoMsg = ""; Color pesoColor = Colors.green; double pesoDiff = pesoActual - pesoIdeal;
    if (pesoDiff.abs() < 0.5) { pesoMsg = "[NORMAL] Peso óptimo"; pesoColor = Colors.green; }
    else if (pesoDiff > 0) { pesoMsg = "[ALERTA] Bajar ${pesoDiff.toStringAsFixed(1)}kg"; pesoColor = pesoDiff > 3 ? Colors.red : Colors.orange; }
    else { pesoMsg = "[ATENCIÓN] Subir ${pesoDiff.abs().toStringAsFixed(1)}kg"; pesoColor = pesoDiff.abs() > 3 ? Colors.red : Colors.orange; }

    String tallaMsg = ""; Color tallaColor = Colors.green; double tallaDiff = tallaIdeal - tallaActual;
    if (tallaDiff.abs() < 1) { tallaMsg = "[NORMAL] Talla adecuada"; tallaColor = Colors.green; }
    else if (tallaDiff > 0) { tallaMsg = "[ALERTA] Crecer ${tallaDiff.toStringAsFixed(1)}cm"; tallaColor = tallaDiff > 5 ? Colors.red : Colors.orange; }
    else { tallaMsg = "[NORMAL] Talla superior"; tallaColor = Colors.green; }

    return Row(children: [
      Expanded(child: _buildThermometer(label: "PESO ACTUAL", actual: pesoActual, ideal: pesoIdeal, unit: "kg", percentage: pesoPct, color: pesoColor, message: pesoMsg, icon: Icons.monitor_weight_outlined)),
      const SizedBox(width: 20),
      Expanded(child: _buildThermometer(label: "TALLA ACTUAL", actual: tallaActual, ideal: tallaIdeal, unit: "cm", percentage: tallaPct, color: tallaColor, message: tallaMsg, icon: Icons.height_rounded)),
    ]);
  }

  Widget _buildThermometer({required String label, required double actual, required double ideal, required String unit, required double percentage, required Color color, required String message, required IconData icon}) {
    double barHeight = percentage.clamp(0.0, 1.3) * 200;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5))]),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 40, height: 220, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)), child: Stack(alignment: Alignment.bottomCenter, children: [Positioned(bottom: 10, child: Container(width: 32, height: barHeight.clamp(10, 200), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16))))])),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ACTUAL", style: TextStyle(fontSize: 9, color: Colors.grey)), Text("$actual $unit", style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, color: color)), const SizedBox(height: 8), const Text("IDEAL OMS", style: TextStyle(fontSize: 9, color: Colors.grey)), Text("$ideal $unit", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.green)), const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.info_outline, size: 16, color: color), const SizedBox(width: 8), Expanded(child: Text(message, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, height: 1.4)))]))]))
      ])
    ]));
  }

  Widget _buildSymptomsChart(List<dynamic> history) => Container(height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)), child: LineChart(LineChartData(minY: 0, maxY: 10, titlesData: FlTitlesData(rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: const AxisTitles(axisNameWidget: Text("ESCALA 0-10", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) => v.toInt() >= 0 && v.toInt() < history.length ? Text(DateFormat('dd/MM').format(DateTime.parse(history[v.toInt()]['fecha_control'])), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)) : const Text("")))), borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)), lineBarsData: [LineChartBarData(spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['puntos_dolor'] ?? 0).toDouble())).toList(), isCurved: true, color: Colors.red, barWidth: 4, dotData: const FlDotData(show: true)), LineChartBarData(spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['nivel_fatiga'] ?? 10).toDouble())).toList(), isCurved: true, color: Colors.green, barWidth: 4, dotData: const FlDotData(show: true))])));
  Widget _buildInflammationChart(List<dynamic> history) => Container(height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)), child: LineChart(LineChartData(minY: 0, maxY: 3, titlesData: FlTitlesData(rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: AxisTitles(axisNameWidget: const Text("ESCALA 0-3", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: 1, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) => v.toInt() >= 0 && v.toInt() < history.length ? Text(DateFormat('dd/MM').format(DateTime.parse(history[v.toInt()]['fecha_control'])), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)) : const Text("")))), borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)), lineBarsData: [LineChartBarData(spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['escala_inflamacion'] ?? 0).toDouble())).toList(), isCurved: true, color: Colors.purple, barWidth: 5, dotData: const FlDotData(show: true))])));
  Widget _buildJointCountChart(List<dynamic> history) => Container(height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)), child: LineChart(LineChartData(titlesData: FlTitlesData(rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: const AxisTitles(axisNameWidget: Text("CANTIDAD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) => v.toInt() >= 0 && v.toInt() < history.length ? Text(DateFormat('dd/MM').format(DateTime.parse(history[v.toInt()]['fecha_control'])), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)) : const Text("")))), borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)), lineBarsData: [LineChartBarData(spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['articulaciones_inflamadas'] ?? 0).toDouble())).toList(), isCurved: true, color: Colors.red, barWidth: 4, dotData: const FlDotData(show: true)), LineChartBarData(spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['articulaciones_dolorosas'] ?? 0).toDouble())).toList(), isCurved: true, color: Colors.orange, barWidth: 4, dotData: const FlDotData(show: true))])));
  Widget _buildLabTrendsChart(List<dynamic> history) {
    double maxV = 10.0; for (var h in history) { double p = (h['valor_pcr'] ?? 0).toDouble(), v = (h['valor_vsg'] ?? 0).toDouble(); if (p > maxV) maxV = p; if (v > maxV) maxV = v; }
    return Container(height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)), child: LineChart(LineChartData(minY: 0, maxY: maxV * 1.1, titlesData: FlTitlesData(rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: AxisTitles(axisNameWidget: const Text("VALOR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 50)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) => v.toInt() >= 0 && v.toInt() < history.length ? Text(DateFormat('dd/MM').format(DateTime.parse(history[v.toInt()]['fecha_control'])), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)) : const Text("")))), borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)), lineBarsData: [LineChartBarData(spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['valor_pcr'] ?? 0).toDouble())).toList(), isCurved: true, color: Colors.blue, barWidth: 4), LineChartBarData(spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['valor_vsg'] ?? 0).toDouble())).toList(), isCurved: true, color: Colors.purple, barWidth: 4)])));
  }

  Widget _buildDynamicConclusion(List<dynamic> history, String type) {
    if (history.isEmpty) return const SizedBox.shrink();
    String conclusion = ""; IconData icon = Icons.info_outline; Color color = Colors.blueGrey;
    final ultimo = history.last;
    switch (type) {
      case "z_score":
        double z = (ultimo['z_score_bmi'] ?? 0).toDouble();
        if (z.abs() > 2) { conclusion = "[ALERTA] Z-Score alterado ($z). Intervención inmediata."; color = Colors.red; }
        else { conclusion = "[NORMAL] Z-Score saludable ($z)."; color = Colors.green; }
        break;
      case "symptoms":
        int d = ultimo['puntos_dolor'] ?? 0, f = ultimo['nivel_fatiga'] ?? 10;
        if (d <= 2 && f >= 7) { conclusion = "✅ Bienestar estable (Dolor: $d, Energía: $f)."; color = Colors.green; }
        else { conclusion = "⚠️ Síntomas presentes (Dolor: $d)."; color = Colors.orange; }
        break;
      default: conclusion = "Seguimiento clínico en curso.";
    }
    return Container(margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 12), Expanded(child: Text(conclusion, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)))]));
  }

  Widget _buildHistoryItem(Map<String, dynamic> h) => InkWell(onTap: () => _mostrarDetalleModal(h), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: (h['en_brote'] ?? false) ? Colors.red.shade100 : Colors.grey.shade200)), child: Row(children: [_dateBadge(DateTime.parse(h['fecha_control'])), const SizedBox(width: 20), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(h['estado_nutricional'] ?? "SIN DIAGNÓSTICO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF0F172A))), Text("Peso: ${h['peso_kg']} kg | Talla: ${h['talla_cm']} cm", style: const TextStyle(fontSize: 12, color: Colors.blueGrey))])), if (h['en_brote'] == true) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Text("BROTE", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))), const SizedBox(width: 12), const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey)])));

  void _mostrarDetalleModal(Map<String, dynamic> h) => showDialog(context: context, builder: (ctx) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), child: Container(width: 550, padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.analytics_outlined, color: greenBrand), const SizedBox(width: 12), Text("RESUMEN DE VALORACIÓN", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: greenBrand)), const Spacer(), IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close))]), const Divider(height: 32), _infoModalRow("Fecha de Control", DateFormat('dd/MM/yyyy').format(DateTime.parse(h['fecha_control']))), _infoModalRow("Estado Nutricional", h['estado_nutricional'] ?? "Normal", isHighlight: true), const SizedBox(height: 32), SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _prepararEdicion(h); }, icon: const Icon(Icons.edit_note_rounded), label: const Text("EDITAR VALORACIÓN"), style: OutlinedButton.styleFrom(foregroundColor: greenBrand, side: const BorderSide(color: greenBrand), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))]))));

  Widget _infoModalRow(String l, String v, {bool isHighlight = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)), const SizedBox(height: 2), Text(v, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600, color: isHighlight ? greenBrand : const Color(0xFF1E293B)))]));

  Widget _dateBadge(DateTime d) => Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: greenBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(DateFormat('dd').format(d), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: greenBrand)), Text(DateFormat('MMM').format(d).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: greenBrand))]));

  Widget _buildClinicalTimeline(List<dynamic> history) => Container(height: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)), child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(24), itemCount: history.length, itemBuilder: (context, index) { final h = history[index]; return SizedBox(width: 160, child: Column(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: (h['en_brote'] == true) ? Colors.red : greenBrand, shape: BoxShape.circle), child: Icon((h['en_brote'] == true) ? Icons.warning : Icons.check, color: Colors.white, size: 18)), const SizedBox(height: 12), Text(DateFormat('dd MMM yyyy').format(DateTime.parse(h['fecha_control'])), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))])); }));

  void _autoRecomendarDerivados(String nombreSeleccionado) {
    final n = nombreSeleccionado.toLowerCase().trim();
    if (n.length < 3) return;
    final stopWords = {'de', 'con', 'en', 'el', 'la', 'los', 'las', 'un', 'una', 'para', 'sin', 'y', 'del'};
    final words = n.split(' ').where((w) => w.length > 2 && !stopWords.contains(w)).toList();
    if (words.isEmpty && n.isNotEmpty) words.add(n);
    final derivados = _ingredientesCat.where((i) {
      final iname = (i['nombre'] ?? "").toString().toLowerCase();
      final sinonimos = (i['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
      if (iname == n) return false;
      bool match(String source, String target) {
        final sw = source.split(' '); return words.any((w) => sw.contains(w)) || sw.any((sw) => words.contains(sw));
      }
      if (match(iname, n)) return true;
      for (var s in sinonimos) { if (match(s, n)) return true; }
      return false;
    }).toList();
    for (var d in derivados) { if (!_recomendacionesIng.any((x) => x['id'] == d['id'])) setState(() => _recomendacionesIng.add(Map<String, dynamic>.from(d))); }
  }

  Widget _buildRecomendacionesSelector() {
    if (_ingredientesCat.isEmpty) return const Text("Cargando...");
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      StatefulBuilder(builder: (context, setInternalState) {
        final q = _ingRecomSearchCtrl.text.toLowerCase().trim();
        final matches = _ingredientesCat.where((e) {
          if (q.isEmpty) return false;
          final name = (e['nombre'] ?? "").toString().toLowerCase();
          final syns = (e['sinonimos'] as List? ?? []).map((s) => s.toString().toLowerCase()).toList();
          return name.contains(q) || syns.any((s) => s.contains(q));
        }).toList();
        return Column(children: [
          TextFormField(controller: _ingRecomSearchCtrl, focusNode: _ingRecomFocus, onChanged: (v) => setInternalState(() {}), decoration: const InputDecoration(labelText: "Buscar ingrediente...", prefixIcon: Icon(Icons.search))),
          if (matches.isNotEmpty && _ingRecomFocus.hasFocus) Container(constraints: const BoxConstraints(maxHeight: 200), margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: ListView.separated(shrinkWrap: true, itemCount: min(matches.length, 50), separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (ctx, i) {
            final item = matches[i]; final isSel = _recomendacionesIng.any((ing) => ing['id'] == item['id']);
            return ListTile(dense: true, title: Text(item['nombre'] ?? ""), trailing: Icon(isSel ? Icons.check_circle : Icons.add_circle_outline, color: isSel ? Colors.blue : null), onTap: () { setState(() { if (!isSel) { _recomendacionesIng.add(Map<String, dynamic>.from(item)); _autoRecomendarDerivados(item['nombre'] ?? ""); } else { _recomendacionesIng.removeWhere((ing) => ing['id'] == item['id']); } }); setInternalState(() {}); });
          }))
        ]);
      }),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: _recomendacionesIng.map((e) => Chip(label: Text(e['nombre'] ?? "", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)), onDeleted: () => setState(() => _recomendacionesIng.remove(e)), backgroundColor: Colors.blue.shade50, deleteIconColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))).toList())
    ]);
  }
}




