import "dart:async";
import "package:dio/dio.dart";
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
  List<Map<String, dynamic>> _condicionesTemp = [];
  
  String _omsStatusPeso = "PENDIENTE";
  String _omsStatusTalla = "PENDIENTE";
  Color _omsColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarExpediente();
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
      
      // Comprobar si ya existe un control con la fecha de hoy
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
      // Aseguramos que la fecha sea YYYY-MM-DD
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
          final combined = "${_omsStatusPeso} ${_omsStatusTalla}";
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
      
      // REFRESCAR LISTA GLOBAL DE PACIENTES
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
    return Scaffold(
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
    );
  }

  Widget _buildLeftSummary() {
    if (_expediente == null) return const SizedBox(width: 350, child: Center(child: CircularProgressIndicator()));
    
    final p = _expediente!['paciente'] ?? {};
    final d = _expediente!['diagnostico'] ?? {};
    final c = _expediente!['ultimo_control'] ?? {};
    final al = _expediente!['alergias'] ?? {};
    
    // CORRECCIÓN: La intolerancia viene en la raíz del objeto, no en salud
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
                icon: const Icon(Icons.visibility_outlined),
                label: const Text("EXPEDIENTE MAESTRO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(selectedPatientProvider.notifier).state = widget.paciente;
                  ref.read(medicoNavProvider.notifier).state = MedicoView.register;
                },
                icon: const Icon(Icons.edit_document),
                label: const Text("EDITAR COMPLETO"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueGrey,
                  side: const BorderSide(color: Colors.blueGrey),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          width: 800,
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.assignment_ind_outlined, color: greenBrand, size: 28),
                const SizedBox(width: 16),
                Text("EXPEDIENTE MAESTRO INTEGRAL", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 20)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close))
              ]),
              const Divider(height: 48),
              Expanded(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildExpSection("DATOS DEL PACIENTE", [
                        _expItem("Nombre", p['nombre_completo']),
                        _expItem("Cédula", p['cedula']),
                        _expItem("F. Nacimiento", p['fecha_nacimiento']),
                        _expItem("Sexo", p['sexo_nombre']),
                        _expItem("Provincia", p['provincia_nombre']),
                      ])),
                      const SizedBox(width: 40),
                      Expanded(child: _buildExpSection("DATOS DEL TUTOR", [
                        _expItem("Nombre", t['nombre_completo']),
                        _expItem("Cédula", t['cedula']),
                        _expItem("Email", t['email']),
                        _expItem("Parentesco", t['parentesco_nombre']),
                      ])),
                      const SizedBox(width: 40),
                      Expanded(child: _buildExpSection("ÚLTIMA VALORACIÓN", [
                        _expItem("Patología", d['condicion_nombre'] ?? "AIJ"),
                        _expItem("Estado Nutri.", c['estado_nutricional']),
                        _expItem("Peso / Talla", "${c['peso_kg']} kg / ${c['talla_cm']} cm"),
                        _expItem("PCR / VSG", "${c['valor_pcr']} / ${c['valor_vsg']}"),
                        _expItem("Próxima Cita", c['fecha_proxima_cita']),
                      ])),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(children: [
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx), style: FilledButton.styleFrom(backgroundColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("CERRAR VISTA"))),
              ])
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpSection(String title, List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: greenBrand, letterSpacing: 1)), const SizedBox(height: 16), ...items]);
  Widget _expItem(String l, dynamic v) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold)), Text(v?.toString() ?? "-", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600))]));

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

<<<<<<< HEAD
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

  Widget _buildHeaderBar() => Container(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28), decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade100))), child: Row(children: [IconButton.filledTonal(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16), onPressed: () => ref.read(medicoNavProvider.notifier).state = MedicoView.list), const SizedBox(width: 24), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text("Consola de Valoración Clínica", style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.5)), Text("Gestión integral de evolución pediátrica reumatológica.", style: GoogleFonts.montserrat(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500))])]));
  Widget _buildTabBar() => Container(height: 60, color: Colors.white, child: TabBar(controller: _tabController, labelColor: AppTema.azulPrincipal, unselectedLabelColor: const Color(0xFF94A3B8), indicator: const UnderlineTabIndicator(borderSide: BorderSide(width: 4, color: AppTema.azulPrincipal), insets: EdgeInsets.symmetric(horizontal: 60)), labelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5), tabs: const [Tab(text: "REGISTRO CLÍNICO"), Tab(text: "MONITOR DE EVOLUCIÓN"), Tab(text: "BIOSEGURIDAD")]));

  Widget _buildTabRegistroMensual() {
    final catTemp = (_data?['catalogo_condiciones_temp'] as List? ?? []);
    return SingleChildScrollView(padding: const EdgeInsets.all(40), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton.icon(onPressed: _clearForm, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text("LIMPIAR REGISTRO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        const SizedBox(width: 16),
        OutlinedButton.icon(onPressed: _cargarUltimasMetricas, icon: const Icon(Icons.history_rounded, size: 18), label: const Text("TRAER ÚLTIMO CONTROL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
=======
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 0), color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton.filledTonal(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16), onPressed: () => ref.read(medicoNavProvider.notifier).state = MedicoView.list),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.paciente['nombre_completo']?.toString().toUpperCase() ?? "PACIENTE", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A))),
            Text("Cédula: ${widget.paciente['cedula']} | Gestión Analítica Mensual", style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ]),
          const Spacer(),
          if (_idControlEditando != null) TextButton.icon(onPressed: _limpiarForm, icon: const Icon(Icons.close, color: Colors.red), label: const Text("CANCELAR EDICIÓN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 24),
        TabBar(controller: _tabController, labelColor: greenBrand, unselectedLabelColor: Colors.grey, indicatorColor: greenBrand, indicatorWeight: 4, labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13), tabs: const [Tab(text: "NUEVA VALORACIÓN", icon: Icon(Icons.add_chart_rounded, size: 20)), Tab(text: "HISTORIAL Y ANALÍTICA", icon: Icon(Icons.history_edu_rounded, size: 20))]),
>>>>>>> 2edcf3d250cf373f9154be700626648a8741fc40
      ]),
    );
  }

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
        _sectionHeader("2. EVALUACIÓN DE ACTIVIDAD REUMÁTICA", Icons.healing_outlined),
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
          child: SwitchListTile(title: Text(_brote ? "BROTE ACTIVO DETECTADO" : "SIN BROTE ACTIVO", style: TextStyle(fontWeight: FontWeight.w900, color: _brote ? Colors.red : greenBrand)), subtitle: const Text("Indique si el paciente presenta crisis hoy"), value: _brote, onChanged: (v) => setState(() => _brote = v), activeColor: Colors.red),
        ),
        const SizedBox(height: 48),
        _sectionHeader("4. SEGUIMIENTO Y OBSERVACIONES", Icons.event_note_rounded),
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
<<<<<<< HEAD
      const SizedBox(height: 48),
      _sectionHeader("CRONOLOGÍA DE CONSULTAS", Icons.history_rounded),
      const SizedBox(height: 20),
      ...controles.reversed.map((c) => _buildConsultaItem(c)),
      const SizedBox(height: 40),
    ]));
=======
    );
>>>>>>> 2edcf3d250cf373f9154be700626648a8741fc40
  }

  Widget _buildOMSStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _omsColor.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: _omsColor.withOpacity(0.3))),
      child: Row(children: [
        Icon(Icons.analytics_rounded, color: _omsColor, size: 32), const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ESTADO NUTRICIONAL ACTUAL (OMS)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey)), Text("${_omsStatusPeso} | ${_omsStatusTalla}".toUpperCase(), style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)))]))
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
        Text("ANALÍTICA DE EVOLUCIÓN PEDIÁTRICA", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A))),
        const SizedBox(height: 8),
        const Text("Comparativa de métricas actuales frente a estándares de referencia OMS 2024.", style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
        
        const SizedBox(height: 40),
        _sectionHeader("1. MONITOR DE ESTADO NUTRICIONAL (Z-SCORE BMI/EDAD)", Icons.analytics_outlined),
        const SizedBox(height: 16),
        _buildZScoreChart(historial),
        const SizedBox(height: 12),
        _chartLegend("Indica qué tan alejado está el paciente del promedio (0). Rango normal: -2 a +2."),

        const SizedBox(height: 56),
        _sectionHeader("2. CRECIMIENTO Y PESO VS. IDEALES OMS", Icons.straighten_rounded),
        const SizedBox(height: 16),
        _buildGrowthChart(historial),
        const SizedBox(height: 12),
        _chartLegend("Línea continua: Valor actual | Línea punteada: Ideal según edad y sexo."),

        const SizedBox(height: 56),
        _sectionHeader("3. EVOLUCIÓN DE ACTIVIDAD REUMÁTICA (MÉDICO)", Icons.monitor_heart_outlined),
        const SizedBox(height: 16),
        _buildClinicalActivityChart(historial),
        const SizedBox(height: 12),
        _chartLegend("Seguimiento de Índices de Dolor, Inflamación y marcadores de laboratorio (PCR)."),

        const SizedBox(height: 56),
        _sectionHeader("REGISTROS CRONOLÓGICOS", Icons.list_alt_rounded),
        const SizedBox(height: 24),
        ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: historial.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (context, index) => _buildHistoryItem(historial[historial.length - 1 - index])),
      ]),
    );
  }

  Widget _chartLegend(String t) => Row(children: [const Icon(Icons.info_outline, size: 14, color: Colors.blueGrey), const SizedBox(width: 8), Text(t, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic))]);

  Widget _buildZScoreChart(List<dynamic> history) {
    return Container(
      height: 350, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => FlLine(color: v == 0 ? Colors.green.withOpacity(0.5) : (v.abs() == 2 ? Colors.orange.withOpacity(0.3) : Colors.grey.shade100), strokeWidth: v == 0 ? 2 : 1)),
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
            leftTitles: AxisTitles(axisNameWidget: const Text("Z-SCORE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 10)))),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade100)),
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
                return LineTooltipItem(
                  "Control: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data['fecha_control']))}\n",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  children: [
                    TextSpan(text: "Z-Score: ${s.y.toStringAsFixed(2)}\n", style: TextStyle(color: s.y.abs() > 2 ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.w900)),
                    TextSpan(text: "Estado: ${data['estado_nutricional'] ?? 'N/A'}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ]
                );
              }).toList(),
            )
          ),
        ),
      ),
    );
  }

  Widget _buildGrowthChart(List<dynamic> history) {
    return Container(
      height: 400, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
              if (v.toInt() >= 0 && v.toInt() < history.length) {
                final d = DateTime.parse(history[v.toInt()]['fecha_control']);
                return Text(DateFormat('dd/MM').format(d), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
              }
              return const Text("");
            })),
          ),
          lineBarsData: [
            // PESO ACTUAL
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['peso_kg'] ?? 0).toDouble())).toList(),
              color: Colors.orange.shade700, barWidth: 3, dotData: const FlDotData(show: true),
            ),
            // PESO IDEAL (Punteado)
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['peso_ideal'] ?? 0).toDouble())).toList(),
              color: Colors.orange.shade200, barWidth: 2, dashArray: [5, 5], dotData: const FlDotData(show: false),
            ),
            // TALLA ACTUAL
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['talla_cm'] ?? 0).toDouble())).toList(),
              color: Colors.teal.shade700, barWidth: 3, dotData: const FlDotData(show: true),
            ),
            // TALLA IDEAL (Punteado)
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['talla_ideal'] ?? 0).toDouble())).toList(),
              color: Colors.teal.shade200, barWidth: 2, dashArray: [5, 5], dotData: const FlDotData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => const Color(0xFF1E293B),
              maxContentWidth: 250,
              getTooltipItems: (spots) {
                final data = history[spots.first.x.toInt()];
                final pActual = (data['peso_kg'] ?? 0).toDouble();
                final pIdeal = (data['peso_ideal'] ?? 0).toDouble();
                final tActual = (data['talla_cm'] ?? 0).toDouble();
                final tIdeal = (data['talla_ideal'] ?? 0).toDouble();
                
                final pDiff = pActual - pIdeal;
                final tDiff = tIdeal - tActual;

                String pMsg = pDiff > 0 ? "Bajar ${pDiff.toStringAsFixed(1)}kg" : "Subir ${pDiff.abs().toStringAsFixed(1)}kg";
                if (pDiff.abs() < 0.5) pMsg = "Peso Óptimo";

                String tMsg = tDiff > 0 ? "Faltan ${tDiff.toStringAsFixed(1)}cm" : "Talla Óptima";

                return [
                  LineTooltipItem(
                    "VALORACIÓN ANTROPOMÉTRICA\n",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    children: [
                      TextSpan(text: "PESO: ${pActual}kg (Ideal: ${pIdeal.toStringAsFixed(1)})\n", style: TextStyle(color: Colors.orange.shade300, height: 1.5)),
                      TextSpan(text: "👉 OBJETIVO: $pMsg\n", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      const TextSpan(text: "--------------------------\n"),
                      TextSpan(text: "TALLA: ${tActual}cm (Ideal: ${tIdeal.toStringAsFixed(1)})\n", style: TextStyle(color: Colors.teal.shade300, height: 1.5)),
                      TextSpan(text: "👉 OBJETIVO: $tMsg", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ]
                  )
                ];
              }
            )
          )
        )
      ),
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

  Widget _buildClinicalActivityChart(List<dynamic> history) {
    return Container(
      height: 400, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(axisNameWidget: const Text("NIVEL / VALOR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: const SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(axisNameWidget: const Text("FECHA DE CONTROL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
              if (v.toInt() >= 0 && v.toInt() < history.length) {
                final d = DateTime.parse(history[v.toInt()]['fecha_control']);
                return Text(DateFormat('dd/MM').format(d), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
              }
              return const Text("");
            })),
          ),
          lineBarsData: [
            // DOLOR (EVA) - Rojo
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['puntos_dolor'] ?? 0).toDouble())).toList(),
              color: Colors.red, barWidth: 3, dotData: const FlDotData(show: true),
            ),
            // INFLAMACIÓN - Morado
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['escala_inflamacion'] ?? 0).toDouble())).toList(),
              color: Colors.purple, barWidth: 3, dotData: const FlDotData(show: true),
            ),
            // PCR - Azul
            LineChartBarData(
              spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['valor_pcr'] ?? 0).toDouble())).toList(),
              color: Colors.blue, barWidth: 3, dotData: const FlDotData(show: true),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => const Color(0xFF1E293B),
              maxContentWidth: 200,
              getTooltipItems: (spots) {
                final data = history[spots.first.x.toInt()];
                return [
                  LineTooltipItem(
                    "ACTIVIDAD CLÍNICA\n",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(text: "🔴 Dolor (EVA): ${data['puntos_dolor']}/10\n", style: const TextStyle(color: Colors.redAccent, height: 1.5)),
                      TextSpan(text: "🟣 Inflamación: ${data['escala_inflamacion']}/3\n", style: const TextStyle(color: Colors.purpleAccent, height: 1.5)),
                      TextSpan(text: "🔵 PCR: ${data['valor_pcr']} mg/L\n", style: const TextStyle(color: Colors.blueAccent, height: 1.5)),
                      TextSpan(text: "⚠️ Brote: ${(data['en_brote'] ?? false) ? 'SÍ' : 'NO'}", style: TextStyle(color: (data['en_brote'] ?? false) ? Colors.red : Colors.greenAccent, fontWeight: FontWeight.bold)),
                    ]
                  )
                ];
              }
            )
          )
        )
      ),
    );
  }

  Widget _sectionHeader(String t, IconData i) => Row(children: [Icon(i, size: 18, color: greenBrand), const SizedBox(width: 12), Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0F172A), letterSpacing: 0.5))]);

  Widget _field(TextEditingController c, String l, IconData i, {int maxLines = 1, Function(String)? onChanged, bool enabled = true, String? helper}) {
    bool n = l.contains("Peso") || l.contains("Talla") || l.contains("PCR") || l.contains("VSG") || l.contains("min") || l.contains("Artic");
    return TextFormField(controller: c, maxLines: maxLines, enabled: enabled, onChanged: onChanged, textInputAction: TextInputAction.next, keyboardType: n ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: l, helperText: helper, prefixIcon: Icon(i, size: 18), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
  }

  Widget _buildMetricSlider(String title, double val, Function(double) onC, String type) {
    String desc = ""; Color color = Colors.grey; double maxV = 10;
    if (type == "DOLOR") { color = val > 7 ? Colors.red : (val > 3 ? Colors.orange : greenBrand); desc = val == 0 ? "SIN DOLOR" : (val > 7 ? "INTENSO" : "MODERADO"); }
    else if (type == "INFLAMACION") { maxV = 3; color = val == 0 ? greenBrand : (val == 3 ? Colors.red : Colors.orange); desc = val == 0 ? "NORMAL" : "INFLAMADO"; }
    else if (type == "FATIGA") { color = val < 4 ? Colors.red : (val > 7 ? greenBrand : Colors.orange); desc = val < 4 ? "AGOTADO" : "ENÉRGICO"; }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.blueGrey)), Text("${val.toInt()}/${maxV.toInt()}", style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
      Slider(value: val, min: 0, max: maxV, divisions: maxV.toInt(), activeColor: color, onChanged: onC),
      Text(desc, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
<<<<<<< HEAD

  Widget _summaryTile(String l, String v, Color c, IconData i, {bool isDark = false}) => Expanded(child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: c.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: isDark ? Colors.transparent : const Color(0xFFF1F5F9))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.blueGrey, letterSpacing: 1)), Icon(i, size: 16, color: isDark ? Colors.white30 : c)]), const SizedBox(height: 12), Text(v, style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : c))])));

  Widget _buildChartOMS(List controles) {
    if (controles.isEmpty) return const Center(child: Text("Sin datos históricos"));
    return SizedBox(height: 280, child: LineChart(LineChartData(gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v)=>FlLine(color: Colors.grey.shade100, strokeWidth: 1)), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(spots: List.generate(controles.length, (i) => FlSpot(i.toDouble(), (controles[i]['peso_kg'] as num).toDouble())), isCurved: true, color: AppTema.azulPrincipal, barWidth: 6, isStrokeCapRound: true, dotData: FlDotData(show: true, getDotPainter: (s, p, b, d) => FlDotCirclePainter(radius: 6, color: Colors.white, strokeWidth: 4, strokeColor: AppTema.azulPrincipal)), belowBarData: BarAreaData(show: true, color: AppTema.azulPrincipal.withOpacity(0.05)))], titlesData: FlTitlesData(rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) { if (v.toInt() >= controles.length) return const SizedBox.shrink(); return Padding(padding: const EdgeInsets.only(top: 10), child: Text(DateFormat('MMM').format(DateTime.parse(controles[v.toInt()]['fecha_control'])), style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold))); }))))));
  }

  Widget _buildChartEVA(List controles) => SizedBox(height: 280, child: LineChart(LineChartData(minY: 0, maxY: 10, gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v)=>FlLine(color: Colors.grey.shade100, strokeWidth: 1)), borderData: FlBorderData(show: false), lineBarsData: [_lineData(controles, 'puntos_dolor', Colors.orange), _lineData(controles, 'escala_inflamacion', Colors.red), _lineData(controles, 'nivel_fatiga', Colors.green)], titlesData: const FlTitlesData(rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))))));
  LineChartBarData _lineData(List c, String k, Color col) => LineChartBarData(spots: List.generate(c.length, (i) => FlSpot(i.toDouble(), (c[i][k] as num? ?? 0).toDouble())), isCurved: true, color: col, barWidth: 4, dotData: const FlDotData(show: false));

  Widget _buildConsultaItem(Map h) {
    final fecha = DateTime.parse(h['fecha_control']);
    return Container(margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9))), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), onTap: () => _verDetalleConsulta(h), leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(DateFormat('dd').format(fecha), style: const TextStyle(color: AppTema.azulPrincipal, fontWeight: FontWeight.w900, fontSize: 18)))), title: Text(DateFormat('MMMM yyyy', 'es').format(fecha).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A))), subtitle: const Text("Registro clínico de seguimiento reumatológico", style: TextStyle(fontSize: 10, color: Colors.blueGrey)), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFCBD5E1))));
  }

  void _verDetalleConsulta(Map h) {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: Colors.white, surfaceTintColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)), title: Row(children: [const Icon(Icons.assignment_ind_rounded, color: AppTema.azulPrincipal, size: 28), const SizedBox(width: 16), Text("REPORTE MÉDICO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18))]), content: SizedBox(width: 550, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildReportSection("ANTROPOMETRÍA", [_reportItem("Peso Actual", "${h['peso_kg']} kg"), _reportItem("Talla Actual", "${h['talla_cm']} cm"), _reportItem("IMC Calculado", "${h['imc_calculado']}"), _reportItem("Condición OMS", "${h['estado_nutricional']}")]), _buildReportSection("VALORACIÓN EVA", [_reportItem("Dolor", "${h['puntos_dolor']}/10"), _reportItem("Inflamación", "${h['escala_inflamacion']}/3"), _reportItem("Fatiga", "${h['nivel_fatiga']}/10"), _reportItem("Rigidez", "${h['minutos_rigidez']} min")]), _buildReportSection("LABORATORIO Y CLÍNICA", [_reportItem("PCR Aguda", "${h['valor_pcr']} mg/L"), _reportItem("VSG Crónica", "${h['valor_vsg'] ?? 'N/A'} mm/h"), _reportItem("Art. Inflamadas", "${h['articulaciones_inflamadas']}"), _reportItem("Art. Dolorosas", "${h['articulaciones_dolorosas']}")]), _buildReportSection("NOTAS DE EVOLUCIÓN", [_reportItem("Estado AIJ", "${h['estado_enfermedad']}"), _reportItem("Comentarios Médicos", h['nota_evolucion'] ?? "Sin observaciones adicionales", fullWidth: true)])]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CERRAR EXPEDIENTE")), FilledButton(onPressed: () { Navigator.pop(ctx); _tabController.animateTo(0); setState(() => _prepararEdicionParaAjuste(h)); }, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("EDITAR ESTA VALORACIÓN"))]));
  }

  void _prepararEdicionParaAjuste(Map h) { _pesoCtrl.text = h['peso_kg']?.toString() ?? ""; _tallaCtrl.text = h['talla_cm']?.toString() ?? ""; _pcrCtrl.text = h['valor_pcr']?.toString() ?? ""; _vsgCtrl.text = h['valor_vsg']?.toString() ?? ""; _artInflamadasCtrl.text = h['articulaciones_inflamadas']?.toString() ?? "0"; _artDolorosasCtrl.text = h['articulaciones_dolorosas']?.toString() ?? "0"; _rigidezCtrl.text = h['minutos_rigidez']?.toString() ?? ""; _notaCtrl.text = h['nota_evolucion'] ?? ""; _dolor = (h['puntos_dolor'] ?? 0).toDouble(); _inflamacionEscala = (h['escala_inflamacion'] ?? 0).toDouble(); _fatiga = (h['nivel_fatiga'] ?? 10).toDouble(); _estadoEnfermedad = h['estado_enfermedad'] ?? "Estable"; }
  Widget _buildReportSection(String t, List<Widget> i) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(top: 8, bottom: 16), child: Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 10, color: AppTema.azulPrincipal, letterSpacing: 2))), Wrap(spacing: 32, runSpacing: 16, children: i), const SizedBox(height: 24), const Divider(height: 1, thickness: 0.5), const SizedBox(height: 16)]);
  Widget _reportItem(String l, String v, {bool fullWidth = false}) => SizedBox(width: fullWidth ? 500 : 110, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 0.5)), const SizedBox(height: 6), Text(v, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)))]));

  Widget _buildTabSeguridad() { final alergias = _data!['alergias']; return Padding(padding: const EdgeInsets.all(40), child: Column(children: [_alergiaCard("SUBGRUPOS BLOQUEADOS", alergias['subgrupos'], Colors.orange, Icons.block_flipped), const SizedBox(height: 32), _alergiaCard("INGREDIENTES PROHIBIDOS", alergias['ingredientes'], Colors.red, Icons.no_food_rounded)])); }
  Widget _alergiaCard(String t, List items, Color col, IconData ic) => Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFF1F5F9))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(ic, size: 20, color: col), const SizedBox(width: 12), Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)))]), const SizedBox(height: 24), Wrap(spacing: 10, runSpacing: 10, children: items.map((i) => Chip(label: Text(i['nombre'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), backgroundColor: col.withOpacity(0.05), side: BorderSide(color: col.withOpacity(0.1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))).toList())]));

  Future<void> _guardarConsulta() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {"peso_kg": _pesoCtrl.text, "talla_cm": _tallaCtrl.text, "puntos_dolor": _dolor.toInt(), "escala_inflamacion": _inflamacionEscala.toInt(), "fatiga": _fatiga.toInt(), "valor_pcr": double.tryParse(_pcrCtrl.text), "valor_vsg": double.tryParse(_vsgCtrl.text), "articulaciones_inflamadas": int.tryParse(_artInflamadasCtrl.text), "articulaciones_dolorosas": int.tryParse(_artDolorosasCtrl.text), "estado_enfermedad": _estadoEnfermedad, "en_brote": _dolor > 7 || _inflamacionEscala > 2, "nota_evolucion": _notaCtrl.text, "fecha_proxima_cita": _proximaCita.toIso8601String().split('T')[0], "id_condiciones_activas": _condicionesTemporalesHoy};
      await dio.post("pacientes/${widget.paciente['id']}/control-mensual", data: payload);
      _loadExpedienteMaestro();
       NutriSnack.show(context, "✅ Sincronización Completa", ref: ref);
    } catch (e) { NutriSnack.show(context, "Error: $e", isError: true, ref: ref); } finally { setState(() => _loading = false); }
  }

  Widget _sectionHeader(String t, IconData i) => Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTema.azulPrincipal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(i, size: 18, color: AppTema.azulPrincipal)), const SizedBox(width: 16), Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0F172A), letterSpacing: 0.5))]);
  Widget _field(TextEditingController c, String l, IconData i, {int maxLines = 1}) { bool n = l.contains("kg") || l.contains("cm") || l.contains("PCR") || l.contains("VSG") || l.contains("min") || l.contains("Artic"); return TextFormField(controller: c, maxLines: maxLines, keyboardType: n ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, inputFormatters: n ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null, decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold), prefixIcon: Icon(i, color: AppTema.azulPrincipal, size: 18), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTema.azulPrincipal, width: 2)))); }
  Widget _dropdownString(String l, List<String> items, String val, Function(String?) onC) => DropdownButtonFormField<String>(initialValue: val, items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))).toList(), onChanged: onC, decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0)))));
  Widget _buildMetricSlider(String title, double val, Function(double) onC, String type) { String desc = ""; String emoji = ""; Color color = Colors.grey; double maxV = 10; int divisions = 10; if (type == "DOLOR") { if (val == 0) { desc = "SIN DOLOR"; emoji = "😀"; color = Colors.green; } else if (val <= 4) { desc = "MODERADO"; emoji = "😐"; color = Colors.amber; } else { desc = "INTENSO"; emoji = "😫"; color = Colors.red; } } else if (type == "INFLAMACION_REUMA") { maxV = 3; divisions = 3; if (val == 0) { desc = "SIN INFLAMACIÓN"; emoji = "💪"; color = Colors.green; } else if (val == 1) { desc = "LEVE"; emoji = "🩹"; color = Colors.blue; } else if (val == 2) { desc = "MODERADA"; emoji = "🟠"; color = Colors.orange; } else { desc = "SEVERA"; emoji = "🔥"; color = Colors.red; } } else { if (val >= 8) { desc = "ENÉRGICO"; emoji = "⚡"; color = Colors.green; } else if (val >= 4) { desc = "REGULAR"; emoji = "🥱"; color = Colors.orange; } else { desc = "AGOTADO"; emoji = "🪫"; color = Colors.red; } } return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF475569), letterSpacing: 0.5)), Text("${val.toInt()}/${maxV.toInt()}", style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12))]), Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.1), width: 2)), child: Column(children: [Row(children: [Text(emoji, style: const TextStyle(fontSize: 32)), const SizedBox(width: 16), Text(desc, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 1))]), SliderTheme(data: SliderThemeData(activeTrackColor: color, inactiveTrackColor: const Color(0xFFF1F5F9), thumbColor: color, trackHeight: 10, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12), overlayColor: color.withOpacity(0.1)), child: Slider(value: val, min: 0, max: maxV, divisions: divisions, onChanged: onC)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(maxV.toInt() + 1, (i) => Text("$i", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: val.toInt() == i ? color : const Color(0xFFCBD5E1))))))]))]); }
  Widget _chartCard(String t, Widget chart) => Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 11, color: const Color(0xFF94A3B8), letterSpacing: 1.5)), const SizedBox(height: 28), chart]));

  Color _getColorEVA(dynamic v) { double val = (v ?? 0).toDouble(); if (val <= 3) return Colors.green; if (val <= 6) return Colors.orange; return Colors.red; }
  Color _getColorInflamacion(dynamic v) { int val = (v ?? 0).toInt(); if (val == 0) return Colors.green; if (val == 1) return Colors.blue; if (val == 2) return Colors.orange; return Colors.red; }
  Color _getColorFatiga(dynamic v) { double val = (v ?? 0).toDouble(); if (val >= 7) return Colors.green; if (val >= 4) return Colors.orange; return Colors.red; }
=======
>>>>>>> 2edcf3d250cf373f9154be700626648a8741fc40
}
