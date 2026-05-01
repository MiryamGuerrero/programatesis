import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";
import "package:fl_chart/fl_chart.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";

class ControlMensualPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> paciente;
  const ControlMensualPage({super.key, required this.paciente});

  @override
  ConsumerState<ControlMensualPage> createState() => _ControlMensualPageState();
}

class _ControlMensualPageState extends ConsumerState<ControlMensualPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  Map<String, dynamic>? _data;

  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();
  final _pcrCtrl = TextEditingController();
  final _vsgCtrl = TextEditingController();
  final _artInflamadasCtrl = TextEditingController();
  final _artDolorosasCtrl = TextEditingController();
  final _rigidezCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  
  double _dolor = 0;
  double _inflamacionEscala = 0;
  double _fatiga = 10;
  String _estadoEnfermedad = "Estable";
  DateTime _proximaCita = DateTime.now().add(const Duration(days: 30));
  final List<int> _condicionesTemporalesHoy = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExpedienteMaestro();
  }

  Future<void> _loadExpedienteMaestro() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final idPaciente = widget.paciente["id"].toString();
      final res = await dio.get("pacientes/$idPaciente/expediente-completo");
      if (mounted) {
        setState(() {
          _data = res.data;
          _clearForm(); 
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearForm() {
    _pesoCtrl.clear(); _tallaCtrl.clear(); _pcrCtrl.clear(); _vsgCtrl.clear();
    _artInflamadasCtrl.text = "0"; _artDolorosasCtrl.text = "0";
    _rigidezCtrl.clear(); _notaCtrl.clear();
    _dolor = 0; _inflamacionEscala = 0; _fatiga = 10;
    _estadoEnfermedad = "Estable"; _condicionesTemporalesHoy.clear();
  }

  void _cargarUltimasMetricas() {
    final ultimo = _data?['ultimo_control'];
    if (ultimo == null) return;
    setState(() {
      _pesoCtrl.text = ultimo['peso_kg']?.toString() ?? "";
      _tallaCtrl.text = ultimo['talla_cm']?.toString() ?? "";
      _pcrCtrl.text = ultimo['valor_pcr']?.toString() ?? "";
      _vsgCtrl.text = ultimo['valor_vsg']?.toString() ?? "";
      _artInflamadasCtrl.text = ultimo['articulaciones_inflamadas']?.toString() ?? "0";
      _artDolorosasCtrl.text = ultimo['articulaciones_dolorosas']?.toString() ?? "0";
      _rigidezCtrl.text = ultimo['minutos_rigidez']?.toString() ?? "";
      _dolor = (ultimo['puntos_dolor'] ?? 0).toDouble();
      _inflamacionEscala = (ultimo['escala_inflamacion'] ?? 0).toDouble();
      _fatiga = (ultimo['nivel_fatiga'] ?? 10).toDouble();
      _estadoEnfermedad = ultimo['estado_enfermedad'] ?? "Estable";
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: NutriLoading(mensaje: "Sincronizando expediente clínico..."));
    if (_data == null) return const Scaffold(body: Center(child: Text("Error al cargar expediente")));

    final pac = _data!['paciente'];
    final tutor = _data!['tutor'];
    final controles = (_data!['historial_controles'] as List);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          _buildLeftSidebar(pac, tutor),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 30, offset: const Offset(0, 10))]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Column(
                  children: [
                    _buildHeaderBar(),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabRegistroMensual(),
                          _buildTabEvolucionGrafica(controles),
                          _buildTabSeguridad(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar(Map pac, Map tutor) {
    final nombre = pac['nombre_completo'] ?? "Sin Nombre";
    final String edadStr = _calculateExactAge(pac['fecha_nacimiento']);

    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)]
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40, 
                  backgroundColor: AppTema.azulPrincipal.withOpacity(0.1), 
                  child: Text(_getInitials(nombre), style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, color: AppTema.azulPrincipal))
                ),
                const SizedBox(height: 20),
                Text(nombre.toString().toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), height: 1.2)),
                const SizedBox(height: 8),
                Text("PACIENTE PEDIÁTRICO", style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.blueGrey, letterSpacing: 1)),
                const SizedBox(height: 20),
                NutriBadge(label: pac['enfermedad_principal'] ?? "IAJ", type: "info"),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              children: [
                _sidebarSection("ESTADÍSTICAS VITALES"),
                _sidebarItem(Icons.fingerprint_rounded, "CÉDULA", pac['cedula'] ?? "S/N"),
                _sidebarItem(Icons.event_rounded, "EDAD EXACTA", edadStr),
                _sidebarItem(Icons.transgender_rounded, "GÉNERO", pac['sexo_nombre'] ?? "N/A"),
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
                _sidebarSection("SEGURIDAD ALIMENTARIA"),
                _buildClinicalAlerts(pac, _data!['alergias']),
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
                _sidebarSection("RESPONSABLE"),
                _sidebarItem(Icons.person_rounded, "NOMBRE", tutor['nombre_completo'] ?? "N/A"),
                _sidebarItem(Icons.family_restroom_rounded, "VÍNCULO", tutor['parentesco_nombre'] ?? "N/A"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalAlerts(Map pac, Map alergias) {
    final List subs = alergias['subgrupos'] ?? [];
    final List ings = alergias['ingredientes'] ?? [];
    
    // IDs de lácteos para filtrar de la lista general
    final lacteosIds = {20, 21, 22, 23, 66, 79, 39};
    bool esLactosa = subs.any((s) => lacteosIds.contains(s['id']));
    
    final otrosGrupos = subs.where((s) => !lacteosIds.contains(s['id'])).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (esLactosa) 
          _alertBadge("INTOLERANCIA A LA LACTOSA", Icons.warning_amber_rounded, Colors.red),
        
        if (otrosGrupos.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text("ALERGIA A GRUPOS:", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...otrosGrupos.map((s) => _simpleListBullet(s['nombre'], Colors.orange.shade800)),
        ],

        if (ings.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text("ALERGIAS ESPECÍFICAS:", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...ings.map((i) => _simpleListBullet(i['nombre'], Colors.deepOrange)),
        ],

        if (!esLactosa && otrosGrupos.isEmpty && ings.isEmpty)
          const Text("Sin restricciones detectadas", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _simpleListBullet(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF334155)))),
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

  Widget _buildHeaderBar() => Container(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28), decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade100))), child: Row(children: [IconButton.filledTonal(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16), onPressed: () => ref.read(medicoNavProvider.notifier).state = MedicoView.list), const SizedBox(width: 24), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text("Consola de Valoración Clínica", style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.5)), Text("Gestión integral de evolución pediátrica reumatológica.", style: GoogleFonts.montserrat(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500))])]));
  Widget _buildTabBar() => Container(height: 60, color: Colors.white, child: TabBar(controller: _tabController, labelColor: AppTema.azulPrincipal, unselectedLabelColor: const Color(0xFF94A3B8), indicator: const UnderlineTabIndicator(borderSide: BorderSide(width: 4, color: AppTema.azulPrincipal), insets: EdgeInsets.symmetric(horizontal: 60)), labelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5), tabs: const [Tab(text: "REGISTRO CLÍNICO"), Tab(text: "MONITOR DE EVOLUCIÓN"), Tab(text: "BIOSEGURIDAD")]));

  Widget _buildTabRegistroMensual() {
    final catTemp = (_data?['catalogo_condiciones_temp'] as List? ?? []);
    return SingleChildScrollView(padding: const EdgeInsets.all(40), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton.icon(onPressed: _clearForm, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text("LIMPIAR REGISTRO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        const SizedBox(width: 16),
        OutlinedButton.icon(onPressed: _cargarUltimasMetricas, icon: const Icon(Icons.history_rounded, size: 18), label: const Text("TRAER ÚLTIMO CONTROL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ]),
      const SizedBox(height: 24),
      _sectionHeader("1. PARÁMETROS ANTROPOMÉTRICOS", Icons.straighten_rounded),
      const SizedBox(height: 20),
      Row(children: [Expanded(child: _field(_pesoCtrl, "Masa Corporal (kg)*", Icons.monitor_weight_outlined)), const SizedBox(width: 24), Expanded(child: _field(_tallaCtrl, "Estatura (cm)*", Icons.height_rounded))]),
      const SizedBox(height: 48),
      _sectionHeader("2. EVALUACIÓN REUMATOLÓGICA (EVA)", Icons.medication_liquid_rounded),
      const SizedBox(height: 24),
      _buildMetricSlider("INTENSIDAD DEL DOLOR", _dolor, (v)=>setState(()=>_dolor=v), "DOLOR"),
      const SizedBox(height: 20),
      _buildMetricSlider("INFLAMACIÓN ARTICULAR", _inflamacionEscala, (v)=>setState(()=>_inflamacionEscala=v), "INFLAMACION_REUMA"),
      const SizedBox(height: 20),
      _buildMetricSlider("NIVEL DE ENERGÍA", _fatiga, (v)=>setState(()=>_fatiga=v), "FATIGA"),
      const SizedBox(height: 32),
      Row(children: [Expanded(child: _field(_artInflamadasCtrl, "Conteo Art. Inflamadas", Icons.adjust_rounded)), const SizedBox(width: 20), Expanded(child: _field(_artDolorosasCtrl, "Conteo Art. Dolorosas", Icons.pan_tool_alt_rounded))]),
      const SizedBox(height: 24),
      Row(children: [Expanded(child: _field(_pcrCtrl, "PCR (mg/L)*", Icons.biotech)), const SizedBox(width: 20), Expanded(child: _field(_vsgCtrl, "VSG (mm/h)", Icons.bloodtype_outlined)), const SizedBox(width: 20), Expanded(child: _field(_rigidezCtrl, "Rigidez (min)", Icons.timer_outlined))]),
      const SizedBox(height: 32),
      _sectionHeader("3. DIAGNÓSTICO DE ACTIVIDAD", Icons.analytics_outlined),
      const SizedBox(height: 16),
      _dropdownString("Actividad actual de la patología*", ["Estable", "Actividad Leve", "Actividad Moderada", "Actividad Alta"], _estadoEnfermedad, (v)=>setState(()=>_estadoEnfermedad=v!)),
      const SizedBox(height: 32),
      const Align(alignment: Alignment.centerLeft, child: Text("SÍNTOMAS AGUDOS DETECTADOS HOY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.5))),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 8, children: catTemp.map<Widget>((c) {
        final id = c['id'] as int;
        return FilterChip(label: Text(c['nombre'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), selected: _condicionesTemporalesHoy.contains(id), onSelected: (v) => setState(() => v ? _condicionesTemporalesHoy.add(id) : _condicionesTemporalesHoy.remove(id)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), selectedColor: AppTema.azulPrincipal.withOpacity(0.2), checkmarkColor: AppTema.azulPrincipal);
      }).toList())),
      const SizedBox(height: 32),
      _field(_notaCtrl, "Notas de evolución clínica...", Icons.description_outlined, maxLines: 4),
      const SizedBox(height: 48),
      _sectionHeader("4. AGENDA MÉDICA", Icons.event_note_rounded),
      const SizedBox(height: 16),
      Container(decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))), child: ListTile(leading: const Icon(Icons.calendar_today_rounded, color: AppTema.azulPrincipal), title: const Text("Próxima Cita Programada", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text(DateFormat('EEEE, d MMMM yyyy', 'es').format(_proximaCita).toUpperCase(), style: const TextStyle(fontSize: 11, color: AppTema.azulPrincipal, fontWeight: FontWeight.w800)), onTap: () async { final d = await showDatePicker(context: context, initialDate: _proximaCita, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90))); if (d != null) setState(() => _proximaCita = d); })),
      const SizedBox(height: 60),
      SizedBox(width: double.infinity, height: 65, child: FilledButton.icon(onPressed: _guardarConsulta, icon: const Icon(Icons.verified_user_rounded), label: const Text("FINALIZAR Y REGISTRAR VALORACIÓN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))))),
    ]));
  }

  Widget _buildTabEvolucionGrafica(List controles) {
    final ultimo = _data?['ultimo_control'] ?? {};
    final enBrote = ultimo['en_brote'] ?? false;
    return SingleChildScrollView(padding: const EdgeInsets.all(40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (enBrote) _buildBroteAlert(),
      if (enBrote) const SizedBox(height: 32),
      _buildMedicalDashboardSummary(ultimo),
      const SizedBox(height: 32),
      Row(children: [
        Expanded(child: _chartCard("DINÁMICA DE CRECIMIENTO", _buildChartOMS(controles))),
        const SizedBox(width: 24),
        Expanded(child: _chartCard("EVOLUCIÓN SEVERIDAD (EVA)", _buildChartEVA(controles))),
      ]),
      const SizedBox(height: 48),
      _sectionHeader("CRONOLOGÍA DE CONSULTAS", Icons.history_rounded),
      const SizedBox(height: 20),
      ...controles.reversed.map((c) => _buildConsultaItem(c)),
      const SizedBox(height: 40),
    ]));
  }

  Widget _buildBroteAlert() => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.red.withOpacity(0.1), width: 2)), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24)), const SizedBox(width: 20), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("SITUACIÓN DE BROTE ACTIVO", style: GoogleFonts.montserrat(color: Colors.red.shade900, fontWeight: FontWeight.w900, fontSize: 16)), Text("Se requiere intervención terapéutica inmediata y ajuste del plan nutricional de crisis.", style: GoogleFonts.montserrat(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w500))]))]));

  Widget _buildMedicalDashboardSummary(Map ctrl) {
    if (ctrl.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      _summaryTile("DOLOR", "${ctrl['puntos_dolor']}/10", _getColorEVA(ctrl['puntos_dolor']), Icons.mood_bad_rounded),
      const SizedBox(width: 16),
      _summaryTile("INFLAMACIÓN", "${ctrl['escala_inflamacion']}/3", _getColorInflamacion(ctrl['escala_inflamacion']), Icons.brightness_high_rounded),
      const SizedBox(width: 16),
      _summaryTile("FATIGA", "${ctrl['nivel_fatiga']}/10", _getColorFatiga(ctrl['nivel_fatiga']), Icons.battery_alert_rounded),
      const SizedBox(width: 16),
      _summaryTile("PCR", "${ctrl['valor_pcr']} mg/L", const Color(0xFF0F172A), Icons.biotech_rounded, isDark: true),
    ]);
  }

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
}
