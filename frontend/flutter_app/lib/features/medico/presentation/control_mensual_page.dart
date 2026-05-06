import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";
import "package:fl_chart/fl_chart.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";
import "../../../shared/widgets/nutri_avatar.dart";

class ControlMensualPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> paciente;
  const ControlMensualPage({super.key, required this.paciente});

  @override
  ConsumerState<ControlMensualPage> createState() => _ControlMensualPageState();
}

class _ControlMensualPageState extends ConsumerState<ControlMensualPage> with SingleTickerProviderStateMixin {
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
  DateTime _proximaCita = DateTime.now().add(const Duration(days: 30));
  final List<Map<String, dynamic>> _condicionesTemp = [];
  List<dynamic> _condicionesTemporalesCat = [];
  
  String _omsStatusPeso = "PENDIENTE";
  String _omsStatusTalla = "PENDIENTE";
  Color _omsColor = Colors.grey;

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
      if (mounted) {
        setState(() {
          _condicionesTemporalesCat = (res.data as List).where((e) => (e['id_tipo'] ?? e['id_tipo_condicion']) == 2).toList();
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
        _loading = false; 
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _debouncedOMS() {
    _debounceOMS?.cancel();
    _debounceOMS = Timer(const Duration(milliseconds: 500), () => _calculateOMS());
  }

  Future<void> _calculateOMS() async {
    double p = double.tryParse(_peso.text) ?? 0;
    double t = double.tryParse(_talla.text) ?? 0;
    if (p < 1 || t < 30) return;
     
    final fnac = widget.paciente['fecha_nacimiento'];
    final idSexo = widget.paciente['id_sexo'];
     
    if (fnac == null || idSexo == null) return;

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
          final combined = "$_omsStatusPeso $_omsStatusTalla";
          if (combined.contains("Severa") || combined.contains("Obesidad") || combined.contains("Bajo peso")) {
            _omsColor = Colors.red;
          } else if (combined.contains("Normal")) {
            _omsColor = greenBrand;
          } else {
            _omsColor = Colors.orange;
          }
        });
      }
    } catch (e) { 
      debugPrint("Error en pre-diagnóstico: $e");
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
      _proximaCita = DateTime.tryParse(h['fecha_proxima_cita'] ?? "") ?? DateTime.now().add(const Duration(days: 30));
    });
    _calculateOMS();
    _tabController.animateTo(0);
  }

  Future<void> _guardarConsulta() async {
    if (_peso.text.isEmpty || _talla.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        "peso_kg": _peso.text, "talla_cm": _talla.text,
        "puntos_dolor": _dolor.toInt(), "escala_inflamacion": _inflamacion.toInt(), "fatiga": _fatiga.toInt(),
        "valor_pcr": _pcr.text, "valor_vsg": _vsg.text, "articulaciones_inflamadas": _artInflam.text,
        "articulaciones_dolorosas": _artDolor.text, "minutos_rigidez": _rigidez.text,
        "en_brote": _brote, "estado_enfermedad": "Seguimiento",
        "nota_evolucion": _notas.text, "fecha_proxima_cita": _proximaCita.toIso8601String().split("T").first,
        "condiciones_temporales": _condicionesTemp
      };
      if (_idControlEditando == null) {
        await dio.post("pacientes/${widget.paciente['id']}/control-mensual", data: payload);
      } else {
        await dio.put("pacientes/control-mensual/$_idControlEditando", data: payload);
      }
      if (mounted) NutriSnack.show(context, "✅ Se han actualizado los campos de Peso, Talla y Evaluación correctamente", ref: ref);
       
      ref.invalidate(patientsListProvider);
       
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
                child: Column(children: [
                  _buildTopBar(),
                  Expanded(child: TabBarView(controller: _tabController, children: [_buildFormTab(), _buildHistoryTab()]))
                ]),
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
  Widget _buildLeftSummary() {
    if (_expediente == null) return const SizedBox(width: 350, child: Center(child: CircularProgressIndicator()));
     
    final p = _expediente!['paciente'] ?? {};
    final d = _expediente!['diagnostico'] ?? {};
    final c = _expediente!['ultimo_control'] ?? {};
    final al = _expediente!['alergias'] ?? {};
     
    final lactosa = _expediente!['es_intolerante_lactosa'] == true;
    final subgrupos = (al['subgrupos'] as List? ?? []).map((e) => e['nombre']).join(", ");
    final ingredientes = (al['ingredientes'] as List? ?? []).map((e) => e['nombre']).join(", ");
     
    return Container(
      width: 350,
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  NutriAvatar(nombreCompleto: p['nombre_completo'] ?? "P", radio: 40),
                  const SizedBox(height: 16),
                  Text("RESUMEN CLÍNICO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 10, color: greenBrand, letterSpacing: 2)),
                ],
              ),
            ),
            const Divider(height: 48),
            _summaryItem("ENFERMEDAD PRINCIPAL", d['condicion_nombre'] ?? d['nombre_condicion'] ?? "-", Icons.medical_services_outlined),
            _summaryItem("EDAD", _formatEdad(p['fecha_nacimiento']), Icons.cake_outlined),
            _summaryItem("ESTADO NUTRICIONAL", c['estado_nutricional'] ?? "PENDIENTE", Icons.analytics_outlined, color: greenBrand),
            _summaryItem("TALLA ACTUAL", "${c['talla_cm'] ?? '-'} cm", Icons.height_rounded),
            const Divider(height: 48),
            _summaryItem("INTOLERANTE A LACTOSA", lactosa ? "SÍ" : "NO", Icons.opacity, color: lactosa ? Colors.red : greenBrand),
            _summaryItem("ALERGIAS (SUBGRUPOS)", subgrupos.isEmpty ? "NINGUNA" : subgrupos, Icons.warning_amber_rounded, color: subgrupos.isEmpty ? Colors.grey : Colors.orange),
            _summaryItem("ALERGIAS (ESPECÍFICAS)", ingredientes.isEmpty ? "NINGUNA" : ingredientes, Icons.security_rounded, color: ingredientes.isEmpty ? Colors.grey : Colors.orange),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _mostrarExpedienteMaestroDialog(),
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text("VER EXPEDIENTE MAESTRO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenBrand,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarExpedienteMaestroDialog() {
    if (_expediente == null) return;
    final p = _expediente!['paciente'] ?? {};
    final t = _expediente!['tutor'] ?? {};
    final d = _expediente!['diagnostico'] ?? {};
    final c = _expediente!['ultimo_control'] ?? {};
    final al = _expediente!['alergias'] ?? {};
     
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: 900,
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.assignment_ind_outlined, color: greenBrand, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("EXPEDIENTE MAESTRO INTEGRAL", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 20)),
                  Text("Registro oficial del paciente en el sistema ReumaNutri", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
                    // 1. PACIENTE
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
                    // 2. TUTOR
                    Expanded(child: _buildExpSection("2. REPRESENTANTE LEGAL", [
                      _expItem("Nombre del Tutor", t['nombre_completo']),
                      _expItem("Cédula del Tutor", t['cedula']),
                      _expItem("Parentesco", t['parentesco_nombre']),
                      const SizedBox(height: 16),
                      const Text("CONTACTO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _expItem("Correo Electrónico", t['email']),
                      _expItem("Teléfono / Móvil", t['telefono']),
                      _expItem("Dirección de Domicilio", t['direccion']),
                    ])),
                    const SizedBox(width: 40),
                    // 3. ESTADO ACTUAL
                    Expanded(child: _buildExpSection("3. ESTADO CLÍNICO ACTUAL", [
                      _expItem("Diagnóstico Principal", d['condicion_nombre'] ?? "AIJ"),
                      _expItem("Estado Nutricional (OMS)", c['estado_nutricional'], isBold: true),
                      _expItem("Peso / Talla", "${c['peso_kg'] ?? '-'} kg / ${c['talla_cm'] ?? '-'} cm"),
                      _expItem("Inflamación Actual", "${c['escala_inflamacion'] ?? 0}/3"),
                      _expItem("Brote Activo", (c['en_brote'] == true) ? "SÍ (ACTIVO)" : "NO", isAlert: c['en_brote'] == true),
                      const SizedBox(height: 16),
                      const Text("SÍNTOMAS TEMPORALES ACTIVOS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      ...(_expediente!['condiciones_temporales'] as List? ?? []).map((ct) => _expItem(ct['nombre'], "Hasta: ${ct['fecha_fin']}", isHighlight: true)),
                      if ((_expediente!['condiciones_temporales'] as List? ?? []).isEmpty)
                        Text("Ninguno reportado", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      const Text("SEGUIMIENTO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _expItem("Fecha de Último Control", c['fecha_control']),
                      _expItem("Próxima Cita Programada", c['fecha_proxima_cita']),
                    ])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.check_circle_outline), label: const Text("ENTENDIDO, VOLVER A ANALÍTICA"), style: FilledButton.styleFrom(backgroundColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 20)))),
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

  Widget _summaryItem(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.blueGrey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertBadge(String text, IconData icon, Color color) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))), child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w900, color: color)))]));
  
  Widget _sidebarSection(String t) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(t, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1.5)));
  Widget _sidebarItem(IconData i, String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)), child: Icon(i, size: 14, color: AppTema.azulPrincipal)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w800)), Text(v, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155)))]))]));
  
  String _getInitials(String n) => n.split(" ").where((e)=>e.isNotEmpty).take(2).map((e)=>e[0]).join().toUpperCase();
  String _calculateExactAge(String? birthStr) {
    if (birthStr == null) return "N/A";
    final birth = DateTime.parse(birthStr);
    final now = DateTime.now();
    int years = now.year - birth.year;
    int months = now.month - birth.month;
    if (months < 0) { years--; months += 12; }
    if (years == 0) return "$months meses";
    return "$years años, $months m.";
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
        Text("Consola de Valoración Clínica", style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.5)),
        Text("Gestión integral de evolución pediátrica reumatológica.", style: GoogleFonts.montserrat(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500))
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
    if (_yaEvaluadoHoy && _idControlEditando == null) {
      return Container(
        padding: const EdgeInsets.all(60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: Icon(Icons.verified_user_rounded, color: Colors.orange.shade800, size: 64),
              ),
              const SizedBox(height: 32),
              Text("PACIENTE YA EVALUADO HOY", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 20, color: const Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Text(
                "Este paciente ya cuenta con un registro de control para la fecha actual (${DateFormat('dd/MM/yyyy').format(DateTime.now())}).",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueGrey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.history_edu_rounded),
                    label: const Text("IR A EVALUACIÓN Y EDICIÓN"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: greenBrand,
                      side: const BorderSide(color: greenBrand),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildOMSStatusCard(),
        const SizedBox(height: 48),
        _sectionHeader("1. SIGNOS VITALES Y ANTROPOMETRÍA", Icons.monitor_weight_outlined),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _field(_peso, "Peso Actual (kg)*", Icons.scale_outlined, onChanged: (_) => _debouncedOMS())),
          const SizedBox(width: 20),
          Expanded(child: _field(_talla, "Talla Actual (cm)*", Icons.height_rounded, onChanged: (_) => _debouncedOMS())),
        ]),
        const SizedBox(height: 48),
        _sectionHeader("2. EVALUACIÓN DE ACTIVIDAD REUMÁTICA", Icons.healing_outlined),
        const SizedBox(height: 24),
        _buildMetricSlider("DOLOR (EVA)", _dolor, (v) => setState(() => _dolor = v), "DOLOR"),
        const SizedBox(height: 32),
        _buildMetricSlider("INFLAMACIÓN ARTICULAR", _inflamacion, (v) => setState(() => _inflamacion = v), "INFLAMACION"),
        const SizedBox(height: 32),
        _buildMetricSlider("NIVEL DE ENERGÍA / FATIGA", _fatiga, (v) => setState(() => _fatiga = v), "FATIGA"),
        const SizedBox(height: 48),
        Row(children: [
          Expanded(child: _field(_artInflam, "Art. Inflamadas", Icons.adjust)),
          const SizedBox(width: 16),
          Expanded(child: _field(_artDolor, "Art. Dolorosas", Icons.pan_tool_alt)),
          const SizedBox(width: 16),
          Expanded(child: _field(_rigidez, "Rigidez (min)", Icons.timer)),
        ]),
        const SizedBox(height: 32),
        _sectionHeader("3. LABORATORIO Y ESTADO CLÍNICO", Icons.biotech_outlined),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _field(_pcr, "PCR (mg/L)", Icons.science_outlined, helper: "Normal < 5")),
          const SizedBox(width: 20),
          Expanded(child: _field(_vsg, "VSG (mm/h)", Icons.bloodtype_outlined, helper: "Normal < 15")),
        ]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _brote ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: _brote ? Colors.red : greenBrand)),
          child: SwitchListTile(title: Text(_brote ? "BROTE ACTIVO DETECTADO" : "SIN BROTE ACTIVO", style: TextStyle(fontWeight: FontWeight.w900, color: _brote ? Colors.red : greenBrand)), subtitle: const Text("Indique si el paciente presenta crisis hoy"), value: _brote, onChanged: (v) => setState(() => _brote = v), activeThumbColor: Colors.red),
        ),
        const SizedBox(height: 48),
        _sectionHeader("4. SÍNTOMAS AGUDOS TEMPORALES", Icons.event_note_rounded),
        const SizedBox(height: 24),
        _buildSintomasTemporalesGrid(),
        const SizedBox(height: 48),
        _sectionHeader("5. SEGUIMIENTO Y OBSERVACIONES", Icons.event_note_rounded),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: ListTile(leading: const Icon(Icons.calendar_month, color: greenBrand), title: const Text("Próxima Cita*", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), subtitle: Text(DateFormat('EEEE, dd/MM/yyyy', 'es').format(_proximaCita).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: greenBrand)), onTap: () async { final d = await showDatePicker(context: context, initialDate: _proximaCita, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180))); if (d != null) setState(() => _proximaCita = d); })
        ),
        const SizedBox(height: 24),
        _field(_notas, "Observaciones Médicas", Icons.edit_note, maxLines: 4),
        const SizedBox(height: 48),
        SizedBox(width: double.infinity, height: 60, child: FilledButton.icon(onPressed: _loading ? null : _guardarConsulta, icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded), label: Text(_idControlEditando == null ? "REGISTRAR VALORACIÓN" : "GUARDAR CAMBIOS", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), style: FilledButton.styleFrom(backgroundColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
      ]),
    );
  }

  Widget _buildSintomasTemporalesGrid() {
    if (_condicionesTemporalesCat.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: const Center(child: Text("Cargando catálogo de síntomas...", style: TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }

    return Column(
      children: _condicionesTemporalesCat.map<Widget>((c) {
        final id = c['id'] as int;
        final index = _condicionesTemp.indexWhere((s) => s['id'] == id);
        final sel = index != -1;
        final duracionSugerida = c['duracion_dias_sugerida'] ?? 7;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: sel ? greenBrand.withOpacity(0.02) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? greenBrand.withOpacity(0.3) : const Color(0xFFE2E8F0)),
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
                  setState(() {
                    _condicionesTemp.add({
                      "id": id,
                      "nombre": c['nombre'],
                      "fecha_inicio": ini.toIso8601String().split('T')[0],
                      "fecha_fin": ini.add(Duration(days: duracionSugerida)).toIso8601String().split('T')[0]
                    });
                  });
                } else {
                  setState(() => _condicionesTemp.removeAt(index));
                }
              },
            ),
            title: Text(
              c['nombre'],
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                color: sel ? greenBrand : const Color(0xFF1E293B),
              ),
            ),
            subtitle: Text(
              sel ? "Activa por $duracionSugerida días sugeridos" : "Sugerencia: $duracionSugerida días",
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            ),
            children: sel
                ? [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _datePickerSmall("DESDE", _condicionesTemp[index]['fecha_inicio'], (d) {
                              setState(() {
                                _condicionesTemp[index]['fecha_inicio'] = d.toIso8601String().split('T')[0];
                                _condicionesTemp[index]['fecha_fin'] = d.add(Duration(days: duracionSugerida)).toIso8601String().split('T')[0];
                              });
                            }),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _datePickerSmall("HASTA (ESTIMADO)", _condicionesTemp[index]['fecha_fin'], (d) {
                              setState(() {
                                _condicionesTemp[index]['fecha_fin'] = d.toIso8601String().split('T')[0];
                              });
                            }),
                          ),
                        ],
                      ),
                    )
                  ]
                : [],
          ),
        );
      }).toList(),
    );
  }

  Widget _datePickerSmall(String l, String v, Function(DateTime) onP) => InkWell(
    onTap: () async { 
      final d = await showDatePicker(
        context: context, 
        initialDate: DateTime.parse(v), 
        firstDate: DateTime.now().subtract(const Duration(days: 30)), 
        lastDate: DateTime.now().add(const Duration(days: 90))
      ); 
      if (d != null) onP(d); 
    }, 
    child: Container(
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))), 
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 4),
        Text(v, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: greenBrand))
      ])
    )
  );

  Widget _buildOMSStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _omsColor.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: _omsColor.withOpacity(0.3))),
      child: Row(children: [
        Icon(Icons.analytics_rounded, color: _omsColor, size: 32), const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ESTADO NUTRICIONAL ACTUAL (OMS)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey)), Text("$_omsStatusPeso | $_omsStatusTalla".toUpperCase(), style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)))]))
      ]),
    );
  }

  Widget _buildHistoryTab() {
    if (_loading && _expediente == null) return const Center(child: CircularProgressIndicator());
    final historial = _expediente?['historial_controles'] as List? ?? [];
    if (historial.isEmpty) return const Center(child: Text("No hay registros previos para graficar."));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("CENTRO DE ANÁLISIS CLÍNICA", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A))),
        const SizedBox(height: 8),
        const Text("Prioridad Reumatológica: Monitoreo de actividad de enfermedad AIJ + Estado nutricional integral.", style: TextStyle(color: Colors.blueGrey, fontSize: 13)),

        // ✅ SECCIÓN REUMATOLOGÍA (PRIMERO - PRIORIDAD)
        const SizedBox(height: 40),
        _buildSectionHeader("REUMATOLOGÍA", "Actividad de enfermedad AIJ, marcadores inflamatorios y conteo articular", Icons.medical_services, Colors.red),
        
        const SizedBox(height: 24),
        _sectionHeader("1. MONITOREO DE SÍNTOMAS (EVA 0-10) - DOLOR Y ENERGÍA", Icons.healing_outlined),
        const SizedBox(height: 16),
        _buildSymptomsChart(historial),
        const SizedBox(height: 12),
        _buildDynamicConclusion(historial, "symptoms"),
        _buildChartExplanation(
          "¿Qué significa esta gráfica?",
          "• DOLOR (EVA 0-10): 0=Sin dolor, 10=Dolor insoportable. En AIJ, dolor >5 requiere ajuste terapéutico inmediato.\n"
          "• ENERGÍA / FATIGA (0-10): 10=Energía máxima, 0=Agotado. La fatiga severa en AIJ es un criterio de actividad clínica.\n"
          "✅ OBJETIVO: Remisión de síntomas (Dolor <=2, Energía/Bienestar >=7).",
          Colors.orange,
        ),

        const SizedBox(height: 40),
        _sectionHeader("2. ACTIVIDAD DE LA ENFERMEDAD (0-10) - INFLAMACIÓN ARTICULAR", Icons.coronavirus_outlined),
        const SizedBox(height: 16),
        _buildInflammationChart(historial),
        const SizedBox(height: 12),
        _buildDynamicConclusion(historial, "inflammation_scale"),
        _buildChartExplanation(
          "¿Qué significa esta gráfica?",
          "• INFLAMACIÓN (0-10): Grado de actividad inflamatoria sistémica percibida y detectada. 0=Sin signos, 10=Inflamación severa.\n"
          "⚠️ ALERTA: Una tendencia ascendente en inflamación precede usualmente a un brote clínico.\n"
          "✅ OBJETIVO: Mantener nivel de inflamación en 0 (Enfermedad inactivada).",
          Colors.red,
        ),

        const SizedBox(height: 40),
        _sectionHeader("3. CONTEOS ARTICULARES - AIJ", Icons.adjust),
        const SizedBox(height: 16),
        _buildJointCountChart(historial),
        const SizedBox(height: 12),
        _buildDynamicConclusion(historial, "joints"),
        _buildChartExplanation(
          "¿Qué significa esta gráfica?",
          "• ARTICULACIONES INFLAMADAS: Articulaciones con signos visibles de inflamación (calor, rubor, edema). En AIJ oligoarticular <5, poliarticular >=5.\n"
          "• ARTICULACIONES DOLOROSAS: Articulaciones que duelen al movimiento pero pueden no estar inflamadas.\n"
          "⚠️ ALERTA: >5 articulaciones inflamadas sugiere poliartritis activa que requiere tratamiento con biológicos (anti-TNF).\n"
          "✅ OBJETIVO: Cero articulaciones inflamadas (remisión clínica).",
          Colors.red,
        ),

        const SizedBox(height: 40),
        _sectionHeader("3. MARCADORES DE LABORATORIO - PCR Y VSG", Icons.biotech_outlined),
        const SizedBox(height: 16),
        _buildLabTrendsChart(historial),
        const SizedBox(height: 12),
        _buildDynamicConclusion(historial, "labs"),
        _buildChartExplanation(
          "¿Qué significa esta gráfica?",
          "• PCR (Normal <5 mg/L): Proteína C-reactiva. Marcador sensible de inflamación sistémica. PCR >10 mg/L indica brote activo de AIJ.\n"
          "• VSG (Normal <15 mm/h): Velocidad de Sedimentación Globular. Menos sensible que PCR pero Áºtil para monitoreo crónico.\n"
          "📋 Líneas punteadas: Límites superiores normales (PCR=5, VSG=15).\n"
          "✅ OBJETIVO: PCR <3 mg/L y VSG <10 mm/h (remisión biológica).",
          Colors.red,
        ),

        // ✅ SECCIÓN NUTRICIÓN (SEGUNDO)
        const SizedBox(height: 56),
        _buildSectionHeader("NUTRICIÓN", "Estado nutricional segÁºn OMS, objetivos de peso y talla para el crecimiento", Icons.restaurant_menu, Colors.green),
        
        const SizedBox(height: 24),
        _sectionHeader("4. MONITOR Z-SCORE BMI/EDAD (OMS)", Icons.analytics_outlined),
        const SizedBox(height: 16),
        _buildZScoreChart(historial),
        const SizedBox(height: 12),
        _buildDynamicConclusion(historial, "z_score"),
        _buildChartExplanation(
          "¿Qué significa esta gráfica?",
          "• Z-SCORE BMI/EDAD: Indica cuántas desviaciones estándar se aleja el paciente del promedio OMS (0 = promedio).\n"
          "• Rango NORMAL: -2.0 a +2.0 (zona verde). Z-Score >2 sugiere sobrepeso/obesidad. Z-Score <-2 sugiere desnutrición.\n"
          "• Líneas punteadas: Límites de alerta (Â±2 y Â±3 desviaciones).\n"
          "✅ OBJETIVO: Mantener Z-Score entre -1 y +1 para crecimiento saludable.",
          Colors.green,
        ),

        const SizedBox(height: 40),
        _sectionHeader("5. TERMÓMETROS DE PROGRESO - PESO Y TALLA", Icons.thermostat_rounded),
        const SizedBox(height: 16),
        _buildThermometerGauges(historial),
        const SizedBox(height: 12),
        _buildDynamicConclusion(historial, "thermometers"),
        _buildChartExplanation(
          "¿Qué significa esta gráfica?",
          "• TERMÓMETRO DE PESO: Compara peso actual vs peso ideal OMS segÁºn edad y sexo. El termómetro visualiza el porcentaje de cumplimiento.\n"
          "• TERMÓMETRO DE TALLA: La talla NO debe decrecer. Solo debe crecer hasta alcanzar la talla ideal OMS. Si el paciente es más alto que el ideal, es favorable.\n"
          "⚠️ NOTA: En niños con AIJ, el retraso en crecimiento (talla baja) puede indicar inflamación sistémica crónica.\n"
          "✅ OBJETIVO: Alcanzar peso ideal y mantener crecimiento de talla normal.",
          Colors.green,
        ),

        const SizedBox(height: 56),
        _sectionHeader("LÍNEA DE TIEMPO DE EVENTOS CLÍNICOS", Icons.timeline_rounded),
        const SizedBox(height: 24),
        _buildClinicalTimeline(historial),

        const SizedBox(height: 56),
        _sectionHeader("REGISTROS CRONOLÓGICOS", Icons.list_alt_rounded),
        const SizedBox(height: 24),
        ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: historial.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (context, index) => _buildHistoryItem(historial[historial.length - 1 - index])),
      ]),
    );
  }

  Widget _buildChartExplanation(String title, String content, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.15))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lightbulb_outline, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.blueGrey, height: 1.6)),
        ])),
      ]),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        ])),
      ]),
    );
  }

  Widget _sectionHeader(String t, IconData i) => Row(children: [Icon(i, size: 18, color: greenBrand), const SizedBox(width: 12), Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0F172A), letterSpacing: 0.5))]);

  Widget _chartLegend(String t) => Row(children: [const Icon(Icons.info_outline, size: 14, color: Colors.blueGrey), const SizedBox(width: 8), Text(t, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic))]);

  Widget _buildZScoreChart(List<dynamic> history) {
    return Container(
      height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(
        LineChartData(
          minY: -3, maxY: 3,
          gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) {
            if (v == 0) return FlLine(color: Colors.green.withOpacity(0.5), strokeWidth: 2);
            if (v.abs() == 2) return FlLine(color: Colors.orange.withOpacity(0.3), strokeWidth: 1, dashArray: [5, 5]);
            if (v.abs() == 3) return FlLine(color: Colors.red.withOpacity(0.3), strokeWidth: 1, dashArray: [5, 5]);
            return FlLine(color: Colors.grey.shade100, strokeWidth: 1);
          }),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, meta) {
              if (v.toInt() >= 0 && v.toInt() < history.length) {
                final d = DateTime.parse(history[v.toInt()]['fecha_control']);
                return Text(DateFormat('dd/MM').format(d), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey));
              }
              return const Text("");
            })),
            leftTitles: AxisTitles(axisNameWidget: const Text("Z-SCORE BMI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) {
              Color c = Colors.grey;
              if (v == 0) c = Colors.green;
              if (v.abs() == 2) c = Colors.orange;
              if (v.abs() == 3) c = Colors.red;
              return Text(v.toStringAsFixed(1), style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold));
            })),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['z_score_bmi'] ?? 0).toDouble())).toList(),
              isCurved: true, color: const Color(0xFF2563EB), barWidth: 4, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF2563EB).withOpacity(0.05)),
            )
          ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => const Color(0xFF0F172A),
                getTooltipItems: (spots) => spots.map((s) {
                  final data = history[s.x.toInt()];
                  final fecha = DateFormat('dd/MM/yyyy').format(DateTime.parse(data['fecha_control']));
                  String diagnosis = "Normal";
                  Color diagColor = Colors.greenAccent;
                  if (s.y > 2) { diagnosis = "Sobrepeso/Obesidad"; diagColor = Colors.redAccent; }
                  else if (s.y < -2) { diagnosis = "Desnutrición"; diagColor = Colors.redAccent; }
                  else if (s.y > 1) { diagnosis = "Riesgo sobrepeso"; diagColor = Colors.orangeAccent; }
                  else if (s.y < -1) { diagnosis = "Riesgo desnutrición"; diagColor = Colors.orangeAccent; }
                  
                  return LineTooltipItem(
                    "Z-SCORE BMI/EDAD (OMS) - $fecha\n",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    children: [
                      TextSpan(text: "Z-SCORE: ${s.y.toStringAsFixed(2)}\n", style: TextStyle(color: diagColor, fontWeight: FontWeight.w900, fontSize: 16)),
                      TextSpan(text: "Diagnóstico: $diagnosis\n", style: const TextStyle(color: Colors.white, fontSize: 11)),
                      TextSpan(text: "Peso: ${data['peso_kg']}kg | Talla: ${data['talla_cm']}cm\n", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      const TextSpan(text: "Rango normal: -2.0 a +2.0 desviaciones estándar\n", style: TextStyle(color: Colors.white54, fontSize: 9, fontStyle: FontStyle.italic)),
                      const TextSpan(text: "0 = Promedio OMS segÁºn edad y sexo", style: TextStyle(color: Colors.white54, fontSize: 9, fontStyle: FontStyle.italic)),
                    ]
                  );
                }).toList(),
              )
            ),
        ),
      ),
    );
  }

  Widget _buildThermometerGauges(List<dynamic> history) {
    if (history.isEmpty) return const SizedBox.shrink();
    final ultimo = history.last;
    final pesoActual = (ultimo['peso_kg'] ?? 0).toDouble();
    final pesoIdeal = (ultimo['peso_ideal'] ?? pesoActual).toDouble();
    final tallaActual = (ultimo['talla_cm'] ?? 0).toDouble();
    final tallaIdeal = (ultimo['talla_ideal'] ?? tallaActual).toDouble();
    
    double pesoPct = pesoIdeal > 0 ? (pesoActual / pesoIdeal).clamp(0.7, 1.3) : 1.0;
    double tallaPct = tallaIdeal > 0 ? (tallaActual / tallaIdeal).clamp(0.85, 1.15) : 1.0;
    
    String pesoMsg = "";
    Color pesoColor = Colors.green;
    double pesoDiff = pesoActual - pesoIdeal;
    
    if (pesoDiff.abs() < 0.5) {
      pesoMsg = "[NORMAL] Peso óptimo para su edad y sexo";
      pesoColor = Colors.green;
    } else if (pesoDiff > 0) {
      pesoMsg = "[ALERTA] Debe bajar ${pesoDiff.toStringAsFixed(1)}kg para alcanzar su peso ideal OMS";
      pesoColor = pesoDiff > 3 ? Colors.red : Colors.orange;
    } else {
      pesoMsg = "[ATENCIÓN] Debe subir ${pesoDiff.abs().toStringAsFixed(1)}kg para alcanzar su peso ideal OMS";
      pesoColor = pesoDiff.abs() > 3 ? Colors.red : Colors.orange;
    }

    String tallaMsg = "";
    Color tallaColor = Colors.green;
    double tallaDiff = tallaIdeal - tallaActual;
    
    if (tallaDiff.abs() < 1) {
      tallaMsg = "[NORMAL] Talla adecuada segÁºn curvas OMS";
      tallaColor = Colors.green;
    } else if (tallaDiff > 0) {
      tallaMsg = "[ALERTA] Debería medir ${tallaIdeal.toStringAsFixed(1)}cm. Necesita crecer ${tallaDiff.toStringAsFixed(1)}cm (no descrecer)";
      tallaColor = tallaDiff > 5 ? Colors.red : Colors.orange;
    } else {
      tallaMsg = "[NORMAL] Talla superior al ideal OMS. Mantener crecimiento normal.";
      tallaColor = Colors.green;
    }

    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Tooltip(
          message: "Peso ideal OMS segÁºn edad y sexo.\nActual: ${pesoActual}kg | Ideal: ${pesoIdeal}kg\nDiferencia: ${pesoDiff > 0 ? '+' : ''}${pesoDiff.toStringAsFixed(1)}kg\n${pesoDiff.abs() < 0.5 ? 'Peso correcto' : 'Requiere ajuste nutricional'}",
          textStyle: const TextStyle(fontSize: 11, color: Colors.white),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
          child: _buildThermometer(
            label: "PESO ACTUAL",
            actual: pesoActual,
            ideal: pesoIdeal,
            unit: "kg",
            percentage: pesoPct,
            color: pesoColor,
            message: pesoMsg,
            icon: Icons.monitor_weight_outlined,
          ),
        )),
        const SizedBox(width: 20),
        Expanded(child: Tooltip(
          message: "Talla ideal OMS segÁºn edad y sexo.\nActual: ${tallaActual}cm | Ideal: ${tallaIdeal}cm\nDiferencia: ${tallaDiff > 0 ? '+' : ''}${tallaDiff.toStringAsFixed(1)}cm\n📋 La talla NO debe decrecer, solo crecer hasta el ideal",
          textStyle: const TextStyle(fontSize: 11, color: Colors.white),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
          child: _buildThermometer(
            label: "TALLA ACTUAL",
            actual: tallaActual,
            ideal: tallaIdeal,
            unit: "cm",
            percentage: tallaPct,
            color: tallaColor,
            message: tallaMsg,
            icon: Icons.height_rounded,
          ),
        )),
      ]),
    ]);
  }

  Widget _buildThermometer({
    required String label,
    required double actual,
    required double ideal,
    required String unit,
    required double percentage,
    required Color color,
    required String message,
    required IconData icon,
  }) {
    double clampedPct = percentage.clamp(0.0, 1.3);
    double barHeight = clampedPct * 200;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            width: 40, height: 220,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
            child: Stack(alignment: Alignment.bottomCenter, children: [
              Container(width: 40, height: 220, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20))),
              Positioned(
                bottom: 10,
                child: Container(width: 32, height: barHeight.clamp(10, 200), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16))),
              ),
              Positioned(
                bottom: (ideal / actual * 200).clamp(10, 200),
                child: Container(width: 40, height: 3, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2))),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("ACTUAL", style: TextStyle(fontSize: 9, color: Colors.grey)),
            Text("$actual $unit", style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 8),
            const Text("IDEAL OMS", style: TextStyle(fontSize: 9, color: Colors.grey)),
            Text("$ideal $unit", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.green)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.info_outline, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(message, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, height: 1.4))),
              ]),
            ),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildSymptomsChart(List<dynamic> history) {
    return Container(
      height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(
        LineChartData(
          minY: 0, maxY: 10,
          gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => FlLine(color: v == 0 ? Colors.green.withOpacity(0.3) : (v == 5 ? Colors.orange.withOpacity(0.2) : Colors.grey.shade100), strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(axisNameWidget: Text("ESCALA 0-10", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
              if (v.toInt() >= 0 && v.toInt() < history.length) {
                final d = DateTime.parse(history[v.toInt()]['fecha_control']);
                return Text(DateFormat('dd/MM').format(d), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
              }
              return const Text("");
            })),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['puntos_dolor'] ?? 0).toDouble())).toList(),
              isCurved: true, color: Colors.red, barWidth: 4, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.05)),
            ),
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['nivel_fatiga'] ?? 10).toDouble())).toList(),
              isCurved: true, color: Colors.green, barWidth: 4, dotData: const FlDotData(show: true),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => const Color(0xFF0F172A),
              getTooltipItems: (spots) => spots.map((s) {
                final data = history[s.x.toInt()];
                final isPain = s.barIndex == 0;
                final val = s.y.toInt();
                return LineTooltipItem(
                  "${isPain ? '🔴 DOLOR' : '🟢 ENERGÍA'}: $val/10",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList(),
            )
          )
        ),
      ),
    );
  }

  Widget _buildInflammationChart(List<dynamic> history) {
    return Container(
      height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(
        LineChartData(
          minY: 0, maxY: 3,
          gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => FlLine(color: v == 0 ? Colors.green.withOpacity(0.3) : Colors.grey.shade100, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(axisNameWidget: const Text("ESCALA 0-3", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: 1, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
              if (v.toInt() >= 0 && v.toInt() < history.length) {
                final d = DateTime.parse(history[v.toInt()]['fecha_control']);
                return Text(DateFormat('dd/MM').format(d), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
              }
              return const Text("");
            })),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['escala_inflamacion'] ?? 0).toDouble())).toList(),
              isCurved: true, color: Colors.purple, barWidth: 5, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.purple.withOpacity(0.1)),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => const Color(0xFF0F172A),
              getTooltipItems: (spots) {
                final data = history[spots.first.x.toInt()];
                final val = (data['escala_inflamacion'] ?? 0).toInt();
                final fecha = DateFormat('dd/MM/yyyy').format(DateTime.parse(data['fecha_control']));
                String desc = ""; Color col = Colors.white;
                if (val == 0) { desc = "Sin inflamación"; col = Colors.greenAccent; }
                else if (val == 1) { desc = "Leve / Discreta"; col = Colors.blueAccent; }
                else if (val == 2) { desc = "Moderada"; col = Colors.orangeAccent; }
                else { desc = "Severa / Activa"; col = Colors.redAccent; }
                
                return [
                  LineTooltipItem(
                    "ACTIVIDAD INFLAMATORIA - $fecha\n",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    children: [
                      TextSpan(text: "🟣 NIVEL: $val/3\n", style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 16)),
                      TextSpan(text: "Estado: $desc", style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ]
                  )
                ];
              },
            )
          )
        ),
      ),
    );
  }

  Widget _buildJointCountChart(List<dynamic> history) {
    return Container(
      height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => FlLine(color: v == 0 ? Colors.green.withOpacity(0.3) : Colors.grey.shade100, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(axisNameWidget: Text("CANTIDAD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
              if (v.toInt() >= 0 && v.toInt() < history.length) {
                final d = DateTime.parse(history[v.toInt()]['fecha_control']);
                return Text(DateFormat('dd/MM').format(d), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
              }
              return const Text("");
            })),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['articulaciones_inflamadas'] ?? 0).toDouble())).toList(),
              isCurved: true, color: Colors.red, barWidth: 4, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.1)),
            ),
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['articulaciones_dolorosas'] ?? 0).toDouble())).toList(),
              isCurved: true, color: Colors.orange, barWidth: 4, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
            ),
          ],
            lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => const Color(0xFF1E293B),
              maxContentWidth: 300,
              getTooltipItems: (spots) {
                final data = history[spots.first.x.toInt()];
                final fecha = DateFormat('dd/MM/yyyy').format(DateTime.parse(data['fecha_control']));
                final inf = (data['articulaciones_inflamadas'] ?? 0);
                final dor = (data['articulaciones_dolorosas'] ?? 0);
                final brote = data['en_brote'] ?? false;
                
                String diagnosis = "";
                if (inf == 0 && dor == 0) {
                  diagnosis = "✅ SIN AFECTACIÓN (Remisión clínica)";
                } else if (inf <= 4) {
                  diagnosis = "⚠️ OLIGOARTRITIS ($inf articulaciones <5)";
                } else {
                  diagnosis = "🔴 POLIARTRITIS ($inf articulaciones >=5)";
                }
                
                return [
                  LineTooltipItem(
                    "CONTEOS ARTICULARES AIJ - $fecha\n",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    children: [
                      TextSpan(text: "🔴 INFLAMADAS: $inf articulaciones\n", style: const TextStyle(color: Colors.redAccent, height: 1.5, fontWeight: FontWeight.w900, fontSize: 14)),
                      const TextSpan(text: "   👉 Signos visibles: calor, rubor, edema\n", style: TextStyle(color: Colors.white70, fontSize: 9, fontStyle: FontStyle.italic)),
                      
                      TextSpan(text: "🟠 DOLOROSAS: $dor articulaciones\n", style: const TextStyle(color: Colors.orangeAccent, height: 1.5, fontWeight: FontWeight.w900, fontSize: 14)),
                      const TextSpan(text: "   👉 Dolor al movimiento (puede no estar inflamada)\n", style: TextStyle(color: Colors.white70, fontSize: 9, fontStyle: FontStyle.italic)),
                      
                      TextSpan(text: "📋 $diagnosis\n", style: const TextStyle(color: Colors.white, height: 1.5)),
                      TextSpan(text: "   ${brote ? '⚠️ BROTE ACTIVO DETECTADO' : '✅ Sin brote activo'}", style: TextStyle(color: brote ? Colors.redAccent : Colors.greenAccent, height: 1.5)),
                    ]
                  )
                ];
              }
            )
          )
        ),
      ),
    );
  }

  Widget _buildLabTrendsChart(List<dynamic> history) {
    double maxPcr = 1, maxVsg = 1;
    for (var h in history) {
      double pcr = (h['valor_pcr'] ?? 0).toDouble();
      double vsg = (h['valor_vsg'] ?? 0).toDouble();
      if (pcr > maxPcr) maxPcr = pcr;
      if (vsg > maxVsg) maxVsg = vsg;
    }
    double maxVal = (maxPcr > maxVsg ? maxPcr : maxVsg) * 1.1;
    if (maxVal < 10) maxVal = 10;

    return Container(
      height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(
        LineChartData(
          minY: 0, maxY: maxVal,
          gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) {
            if (v == 5) return FlLine(color: Colors.orange.withOpacity(0.3), strokeWidth: 2, dashArray: [5, 5]);
            if (v == 15) return FlLine(color: Colors.red.withOpacity(0.3), strokeWidth: 2, dashArray: [5, 5]);
            return FlLine(color: Colors.grey.shade100, strokeWidth: 1);
          }),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(axisNameWidget: const Text("VALOR LABORATORIO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
              if (v.toInt() >= 0 && v.toInt() < history.length) {
                final d = DateTime.parse(history[v.toInt()]['fecha_control']);
                return Text(DateFormat('dd/MM').format(d), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
              }
              return const Text("");
            })),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['valor_pcr'] ?? 0).toDouble())).toList(),
              isCurved: true, color: Colors.blue, barWidth: 4, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
            ),
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['valor_vsg'] ?? 0).toDouble())).toList(),
              isCurved: true, color: Colors.purple, barWidth: 4, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.purple.withOpacity(0.1)),
            ),
          ],
            lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => const Color(0xFF0F172A),
              maxContentWidth: 350,
              getTooltipItems: (spots) {
                final data = history[spots.first.x.toInt()];
                final fecha = DateFormat('dd/MM/yyyy').format(DateTime.parse(data['fecha_control']));
                final pcr = (data['valor_pcr'] ?? 0);
                final vsg = (data['valor_vsg'] ?? 0);
                
                String pcrMsg = "";
                if ((pcr as num) < 3) {
                  pcrMsg = "Remisión biológica";
                } else if (pcr < 5) pcrMsg = "Normal";
                else if (pcr < 10) pcrMsg = "Elevada - Monitoreo";
                else pcrMsg = "Muy alta - Brote activo";
                
                String vsgMsg = "";
                if ((vsg as num) < 10) {
                  vsgMsg = "✅ Normal";
                } else if (vsg < 20) vsgMsg = "⚠️ Elevada";
                else vsgMsg = "🔴 Muy alta - Inflamación sistémica";
                
                return [
                  LineTooltipItem(
                    "MARCADORES DE LABORATORIO - $fecha\n",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    children: [
                      TextSpan(text: "🔵 PCR (Proteína C-Reactiva): $pcr mg/L\n", style: const TextStyle(color: Colors.lightBlueAccent, height: 1.5, fontWeight: FontWeight.w900, fontSize: 14)),
                      TextSpan(text: "   $pcrMsg\n", style: const TextStyle(color: Colors.white, height: 1.5)),
                      const TextSpan(text: "📋 Normal < 5 mg/L | Línea punteada azul\n", style: TextStyle(color: Colors.white70, fontSize: 9, fontStyle: FontStyle.italic)),
                      
                      TextSpan(text: "🟣 VSG (Velocidad Sedimentación): $vsg mm/h\n", style: const TextStyle(color: Colors.purpleAccent, height: 1.5, fontWeight: FontWeight.w900, fontSize: 14)),
                      TextSpan(text: "   $vsgMsg\n", style: const TextStyle(color: Colors.white, height: 1.5)),
                      const TextSpan(text: "📋 Normal < 15 mm/h | Línea punteada morada\n", style: TextStyle(color: Colors.white70, fontSize: 9, fontStyle: FontStyle.italic)),
                      
                      const TextSpan(text: "ℹ️ La PCR es más sensible que VSG para detectar brotes de AIJ", style: TextStyle(color: Colors.white54, fontSize: 9, fontStyle: FontStyle.italic)),
                    ]
                  )
                ];
              }
            )
          )
        ),
      ),
    );
  }

  Widget _buildDynamicConclusion(List<dynamic> history, String type) {
    if (history.isEmpty) return const SizedBox.shrink();
    
    String conclusion = "";
    IconData icon = Icons.info_outline;
    Color color = Colors.blueGrey;
    
    switch (type) {
      case "z_score":
        final ultimo = history.last;
        final z = (ultimo['z_score_bmi'] ?? 0).toDouble();
        if (z.abs() > 2) {
          conclusion = "[ALERTA] Z-Score fuera de rango normal (${z.toStringAsFixed(2)}). ${z > 0 ? 'Riesgo de sobrepeso/obesidad. Requiere intervención nutricional inmediata.' : 'Riesgo de desnutrición. Evaluar ingesta calórica y absorción.'}";
          color = Colors.red;
          icon = Icons.warning_amber_rounded;
        } else if (z.abs() > 1) {
          conclusion = "[ATENCIÓN] Z-Score ligeramente alterado (${z.toStringAsFixed(2)}). Monitoreo nutricional estrecho. Mantener dieta equilibrada según OMS.";
          color = Colors.orange;
          icon = Icons.trending_up;
        } else {
          conclusion = "[NORMAL] Z-Score dentro de rango saludable (${z.toStringAsFixed(2)}). Estado nutricional adecuado para su edad y sexo. Continuar con seguimiento mensual.";
          color = Colors.green;
          icon = Icons.check_circle;
        }
        break;
        
      case "thermometers":
        final ultimo = history.last;
        final pesoActual = (ultimo['peso_kg'] ?? 0).toDouble();
        final pesoIdeal = (ultimo['peso_ideal'] ?? pesoActual).toDouble();
        final tallaActual = (ultimo['talla_cm'] ?? 0).toDouble();
        final tallaIdeal = (ultimo['talla_ideal'] ?? tallaActual).toDouble();
        double pesoDiff = pesoActual - pesoIdeal;
        double tallaDiff = tallaIdeal - tallaActual;
        
        String pesoRec = pesoDiff.abs() < 0.5 ? "✅ Peso óptimo." : (pesoDiff > 0 ? "⬇️ Debe bajar ${pesoDiff.toStringAsFixed(1)}kg." : "⬆️ Debe subir ${pesoDiff.abs().toStringAsFixed(1)}kg.");
        String tallaRec = tallaDiff.abs() < 1 ? "✅ Talla adecuada." : (tallaDiff > 0 ? "📏 Debe crecer ${tallaDiff.toStringAsFixed(1)}cm (no descrecer)." : "✅ Talla superior al ideal.");
        
        conclusion = "OBJETIVOS NUTRICIONALES:\n• Peso actual: ${pesoActual}kg (Ideal: ${pesoIdeal.toStringAsFixed(1)}kg) - $pesoRec\n• Talla actual: ${tallaActual}cm (Ideal: ${tallaIdeal.toStringAsFixed(1)}cm) - $tallaRec";
        color = (pesoDiff.abs() > 3 || tallaDiff > 5) ? Colors.red : (pesoDiff.abs() > 1 || tallaDiff > 2) ? Colors.orange : Colors.green;
        icon = color == Colors.green ? Icons.check_circle : Icons.trending_up;
        break;
        
      case "symptoms":
        final ultimo = history.last;
        final dolor = (ultimo['puntos_dolor'] ?? 0);
        final fatiga = (ultimo['nivel_fatiga'] ?? 10);
        
        if (dolor <= 2 && fatiga >= 7) {
          conclusion = "✅ CALIDAD DE VIDA: Paciente reporta bienestar estable (Dolor: $dolor/10, Energía: $fatiga/10).";
          color = Colors.green;
          icon = Icons.sentiment_satisfied_alt_rounded;
        } else if (dolor > 7 || fatiga < 4) {
          conclusion = "🔴 IMPACTO SEVERO: Alto nivel de dolor ($dolor/10) o fatiga extrema. Afectación importante en la vida diaria.";
          color = Colors.red;
          icon = Icons.warning_rounded;
        } else {
          conclusion = "⚠️ SÍNTOMAS PRESENTES: Nivel moderado de dolor ($dolor/10). Vigilar patrones de sueño y actividad física.";
          color = Colors.orange;
          icon = Icons.info_outline;
        }
        break;

      case "inflammation_scale":
        final ultimo = history.last;
        final inflam = (ultimo['escala_inflamacion'] ?? 0);
        
        if (inflam == 0) {
          conclusion = "✅ ACTIVIDAD BAJA: Sin inflamación articular reportada ($inflam/3).";
          color = Colors.green;
          icon = Icons.verified_rounded;
        } else if (inflam == 3) {
          conclusion = "🔴 ACTIVIDAD ALTA: Inflamación articular severa ($inflam/3). Posible fallo terapéutico o falta de adherencia.";
          color = Colors.red;
          icon = Icons.gpp_bad_rounded;
        } else {
          conclusion = "⚠️ ACTIVIDAD MODERADA: Inflamación en rango intermedio ($inflam/3). Monitorear en el próximo control.";
          color = Colors.orange;
          icon = Icons.coronavirus_outlined;
        }
        break;
        
      case "joints":
        final ultimo = history.last;
        final inf = (ultimo['articulaciones_inflamadas'] ?? 0);
        final dor = (ultimo['articulaciones_dolorosas'] ?? 0);
        final brote = ultimo['en_brote'] ?? false;
        
        if (inf == 0 && dor == 0 && !brote) {
          conclusion = "[SIN AFECTACIÓN] ARTICULAR: Cero articulaciones inflamadas o dolorosas. Enfermedad quiescente. Excelente respuesta al tratamiento.";
          color = Colors.green;
          icon = Icons.check_circle;
        } else if (inf > 5 || dor > 10 || brote) {
          conclusion = "[POLIARTRITIS] ACTIVA: $inf articulaciones inflamadas, $dor dolorosas. ${brote ? 'Paciente en brote. ' : ''}Requiere tratamiento agresivo y posible biológica.";
          color = Colors.red;
          icon = Icons.emergency;
        } else {
          conclusion = "[ARTRITIS] LEVE-MODERADA: $inf articulaciones inflamadas, $dor dolorosas. Evaluar radiológicamente y considerar ajuste de FAME.";
          color = Colors.orange;
          icon = Icons.trending_up;
        }
        break;
        
      case "labs":
        final ultimo = history.last;
        final pcr = (ultimo['valor_pcr'] ?? 0).toDouble();
        final vsg = (ultimo['valor_vsg'] ?? 0).toDouble();
        
        String pcrStatus = pcr < 5 ? "normal" : (pcr < 10 ? "elevada" : "muy alta");
        String vsgStatus = vsg < 15 ? "normal" : (vsg < 30 ? "elevada" : "muy alta");
        
        if (pcr < 5 && vsg < 15) {
          conclusion = "[NORMAL] LABORATORIO: PCR ${pcr}mg/L y VSG ${vsg}mm/h dentro de rangos normales. Sin evidencia de actividad inflamatoria sistémica.";
          color = Colors.green;
          icon = Icons.check_circle;
        } else if (pcr > 10 || vsg > 30) {
          conclusion = "[ALERTA] INFLAMACIÓN SISTÉMICA: PCR ${pcr}mg/L ($pcrStatus) y VSG ${vsg}mm/h ($vsgStatus). Correlacionar con clínica. Posible brote de AIJ activo.";
          color = Colors.red;
          icon = Icons.emergency;
        } else {
          conclusion = "[ATENCIÓN] INFLAMACIÓN LEVE: PCR ${pcr}mg/L ($pcrStatus), VSG ${vsg}mm/h ($vsgStatus). Monitoreo cercano. Considerar analítica en 15 días.";
          color = Colors.orange;
          icon = Icons.trending_up;
        }
        break;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(conclusion, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, height: 1.5))),
      ]),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> h) {
    final fecha = DateTime.parse(h['fecha_control']); final isBrote = h['en_brote'] ?? false;
    return InkWell(
      onTap: () => _mostrarDetalleModal(h),
      child: Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isBrote ? Colors.red.shade100 : Colors.grey.shade200)),
        child: Row(children: [
          _dateBadge(fecha), const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(h['estado_nutricional'] ?? "SIN DIAGNÓSTICO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF0F172A))), Text("Peso: ${h['peso_kg']} kg | Talla: ${h['talla_cm']} cm", style: const TextStyle(fontSize: 12, color: Colors.blueGrey))])),
          if (isBrote) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Text("BROTE", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12), const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ]),
      ),
    );
  }

  void _mostrarDetalleModal(Map<String, dynamic> h) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: 550, padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.analytics_outlined, color: greenBrand, size: 24),
              const SizedBox(width: 12),
              Text("RESUMEN DE VALORACIÓN", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: greenBrand)),
              const Spacer(), IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close))
            ]),
            const Divider(height: 32),
            Row(children: [
              Expanded(child: _infoModalRow("Fecha de Control", DateFormat('dd/MM/yyyy').format(DateTime.parse(h['fecha_control'])), icon: Icons.calendar_today)),
              Expanded(child: _infoModalRow("Estado Nutricional", h['estado_nutricional'] ?? "Normal", isHighlight: true, icon: Icons.person_search)),
            ]),
            const SizedBox(height: 16),
            _sectionModalHeader("VARIABLES ANTROPOMÉTRICAS Y LABORATORIO"),
            Row(children: [
              Expanded(child: _infoModalRow("Peso / Talla", "${h['peso_kg']} kg / ${h['talla_cm']} cm", icon: Icons.monitor_weight_outlined)),
              Expanded(child: _infoModalRow("PCR / VSG", "${h['valor_pcr'] ?? '-'} / ${h['valor_vsg'] ?? '-'}", icon: Icons.biotech_outlined))
            ]),
            const SizedBox(height: 16),
            _sectionModalHeader("ÍNDICES DE ACTIVIDAD REUMÁTICA"),
            Row(children: [
              Expanded(child: _infoModalRow("Dolor (EVA)", "${h['puntos_dolor']}/10", icon: Icons.healing_outlined)),
              Expanded(child: _infoModalRow("Inflamación", "${h['escala_inflamacion']}/3", icon: Icons.coronavirus_outlined))
            ]),
            Row(children: [
              Expanded(child: _infoModalRow("Rigidez Matinal", "${h['minutos_rigidez'] ?? 0} min", icon: Icons.timer_outlined)),
              Expanded(child: _infoModalRow("Nivel de Fatiga", "${h['nivel_fatiga'] ?? 10}/10", icon: Icons.battery_charging_full_outlined))
            ]),
            Row(children: [
              Expanded(child: _infoModalRow("Art. Inflam / Dolor", "${h['articulaciones_inflamadas'] ?? 0} / ${h['articulaciones_dolorosas'] ?? 0}", icon: Icons.adjust)),
              Expanded(child: _infoModalRow("Brote Activo", (h['en_brote'] ?? false) ? "SÍ" : "NO", icon: Icons.warning_amber_rounded, isHighlight: h['en_brote'] == true))
            ]),
            const SizedBox(height: 16),
            _sectionModalHeader("OBSERVACIONES MÉDICAS"),
            _infoModalRow("", h['nota_evolucion'] ?? "Sin notas adicionales registradas.", isMultiline: true),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _prepararEdicion(h); }, icon: const Icon(Icons.edit_note_rounded), label: const Text("EDITAR ESTA VALORACIÓN"), style: OutlinedButton.styleFrom(foregroundColor: greenBrand, side: const BorderSide(color: greenBrand), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))
          ]),
        ),
      ),
    );
  }

  Widget _sectionModalHeader(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5)));

  Widget _infoModalRow(String l, String v, {bool isHighlight = false, bool isMultiline = false, IconData? icon}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8), 
    child: Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: isHighlight ? (v == "SÍ" ? Colors.red : greenBrand) : Colors.blueGrey), const SizedBox(width: 8)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (l.isNotEmpty) Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 2), 
            Text(v, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600, color: isHighlight ? (v == "SÍ" ? Colors.red : greenBrand) : const Color(0xFF1E293B)))
          ]),
        ),
      ],
    )
  );

  Widget _dateBadge(DateTime d) => Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: greenBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(DateFormat('dd').format(d), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: greenBrand)), Text(DateFormat('MMM').format(d).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: greenBrand))]));

  Widget _field(TextEditingController c, String l, IconData i, {int maxLines = 1, Function(String)? onChanged, bool enabled = true, String? helper}) {
    bool n = l.contains("Peso") || l.contains("Talla") || l.contains("PCR") || l.contains("VSG") || l.contains("min") || l.contains("Artic");
    return TextFormField(controller: c, maxLines: maxLines, enabled: enabled, onChanged: onChanged, textInputAction: TextInputAction.next, keyboardType: n ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: l, helperText: helper, prefixIcon: Icon(i, size: 18), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
  }

  Widget _buildClinicalTimeline(List<dynamic> history) {
    if (history.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 180,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(24),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final h = history[index];
          final date = DateTime.parse(h['fecha_control']);
          final isBrote = h['en_brote'] == true;
          final isFirst = index == 0;
          final isLast = index == history.length - 1;

          return SizedBox(
            width: 160,
            child: Stack(
              children: [
                // Línea conectora
                Positioned(
                  top: 20, left: isFirst ? 80 : 0, right: isLast ? 80 : 0,
                  child: Container(height: 2, color: Colors.grey.shade200),
                ),
                // Evento
                Column(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isBrote ? Colors.red : greenBrand,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [BoxShadow(color: (isBrote ? Colors.red : greenBrand).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                      ),
                      child: Icon(isBrote ? Icons.warning_amber_rounded : Icons.check_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(DateFormat('dd MMM yyyy', 'es').format(date).toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: (isBrote ? Colors.red : greenBrand).withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        isBrote ? "BROTE ACTIVO" : "CONTROL ESTABLE",
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isBrote ? Colors.red : greenBrand),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("${h['peso_kg']} kg | ${h['talla_cm']} cm", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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
