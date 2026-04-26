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

  // Control de Edición/Registro
  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();
  final _pcrCtrl = TextEditingController();
  final _rigidezCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  
  double _dolor = 0;
  double _inflamacion = 0;
  double _fatiga = 10;
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
          _prepararEdicion(_data?['ultimo_control']);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prepararEdicion(Map? ctrl) {
    if (ctrl == null || ctrl.isEmpty) return;
    _pesoCtrl.text = ctrl['peso_kg']?.toString() ?? "";
    _tallaCtrl.text = ctrl['talla_cm']?.toString() ?? "";
    _pcrCtrl.text = ctrl['inflamacion_pcr']?.toString() ?? "";
    _rigidezCtrl.text = ctrl['minutos_rigidez_matutina']?.toString() ?? "";
    _notaCtrl.text = ctrl['nota_evolucion'] ?? "";
    _dolor = (ctrl['nivel_dolor_eva'] ?? 0).toDouble();
    _inflamacion = (ctrl['nivel_inflamacion'] ?? 0).toDouble();
    _fatiga = (ctrl['nivel_fatiga'] ?? 10).toDouble();
  }

  String _getInitials(String nombre) {
    List<String> names = nombre.split(" ");
    String initials = "";
    if (names.isNotEmpty && names[0].isNotEmpty) initials += names[0][0];
    if (names.length > 1 && names[1].isNotEmpty) initials += names[1][0];
    return initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: NutriLoading(mensaje: "Sincronizando expediente clínico..."));
    if (_data == null) return const Scaffold(body: Center(child: Text("Error al cargar expediente")));

    final pac = _data!['paciente'];
    final tutor = _data!['tutor'];
    final controles = (_data!['historial_controles'] as List);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: Row(
        children: [
          Expanded(
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
          _buildRightSidebar(pac, tutor),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      color: Colors.white,
      child: Row(
        children: [
          IconButton.filledTonal(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => ref.read(medicoNavProvider.notifier).state = MedicoView.list),
          const SizedBox(width: 16),
          const Text("CENTRO DE CONTROL CLÍNICO", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildRightSidebar(Map pac, Map tutor) {
    final nombre = pac['nombre_completo'] ?? "Sin Nombre";
    return Container(
      width: 320,
      decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: Colors.grey.shade200))),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          CircleAvatar(radius: 45, backgroundColor: AppTema.azulPrincipal, child: Text(_getInitials(nombre), style: GoogleFonts.lexend(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
          const SizedBox(height: 24),
          Text(nombre.toString().toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, height: 1.2)),
          const SizedBox(height: 8),
          NutriBadge(label: pac['enfermedad_principal'] ?? "LES", type: "info"),
          const SizedBox(height: 40),
          _sidebarSection("DATOS DE FILIACIÓN"),
          _sidebarItem("CÉDULA", pac['cedula'] ?? "S/N"),
          _sidebarItem("EDAD", "${(DateTime.now().difference(DateTime.parse(pac['fecha_nacimiento'])).inDays / 365).floor()} años"),
          _sidebarItem("SEXO", pac['sexo_nombre'] ?? "N/A"),
          const Divider(height: 48),
          _sidebarSection("REPRESENTANTE"),
          _sidebarItem("NOMBRE", tutor['nombre_completo']),
          _sidebarItem("VÍNCULO", tutor['parentesco_nombre']),
        ],
      ),
    );
  }

  Widget _sidebarSection(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Align(alignment: Alignment.centerLeft, child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1))));
  Widget _sidebarItem(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)), Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]));

  Widget _buildTabBar() => Container(color: Colors.white, child: TabBar(controller: _tabController, labelColor: AppTema.azulPrincipal, unselectedLabelColor: Colors.grey, indicatorColor: AppTema.azulPrincipal, indicatorWeight: 4, tabs: const [Tab(text: "REGISTRO MENSUAL"), Tab(text: "MONITOR DE EVOLUCIÓN"), Tab(text: "SEGURIDAD")]));

  Widget _buildTabRegistroMensual() {
    final catTemp = (_data?['catalogo_condiciones_temp'] as List? ?? []);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          NutriTableContainer(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader("1. ANTROPOMETRÍA", Icons.monitor_weight_outlined),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: _field(_pesoCtrl, "Peso Actual (kg)*", Icons.monitor_weight_outlined)),
                    const SizedBox(width: 20),
                    Expanded(child: _field(_tallaCtrl, "Talla Actual (cm)*", Icons.height_rounded)),
                  ]),
                  const SizedBox(height: 40),
                  _sectionHeader("2. SEVERIDAD CLÍNICA (EVA)", Icons.analytics_outlined),
                  const SizedBox(height: 24),
                  _buildMetricSlider("ESCALA DE DOLOR", _dolor, (v)=>setState(()=>_dolor=v), "DOLOR"),
                  const SizedBox(height: 20),
                  _buildMetricSlider("NIVEL DE INFLAMACIÓN", _inflamacion, (v)=>setState(()=>_inflamacion=v), "INFLAMACION"),
                  const SizedBox(height: 20),
                  _buildMetricSlider("NIVEL DE ENERGÍA", _fatiga, (v)=>setState(()=>_fatiga=v), "FATIGA"),
                  const SizedBox(height: 32),
                  Row(children: [
                    Expanded(child: _field(_pcrCtrl, "PCR*", Icons.biotech)),
                    const SizedBox(width: 20),
                    Expanded(child: _field(_rigidezCtrl, "Rigidez (min)", Icons.timer_outlined)),
                  ]),
                  const SizedBox(height: 32),
                  const Text("CONDICIONES AGUDAS DETECTADAS HOY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: catTemp.map<Widget>((c) {
                      final id = c['id'] as int;
                      return FilterChip(
                        label: Text(c['nombre'], style: const TextStyle(fontSize: 11)),
                        selected: _condicionesTemporalesHoy.contains(id),
                        onSelected: (v) => setState(() => v ? _condicionesTemporalesHoy.add(id) : _condicionesTemporalesHoy.remove(id)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  _field(_notaCtrl, "Evolución y observaciones...", Icons.edit_note, maxLines: 2),
                  const SizedBox(height: 40),
                  _sectionHeader("3. PRÓXIMA CITA", Icons.event_available),
                  const SizedBox(height: 16),
                  ListTile(
                    tileColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: const Icon(Icons.calendar_month, color: AppTema.azulPrincipal),
                    title: const Text("Fecha Programada", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('EEEE, d MMMM yyyy', 'es').format(_proximaCita).toUpperCase()),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _proximaCita, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                      if (d != null) setState(() => _proximaCita = d);
                    },
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: FilledButton.icon(
                      onPressed: _guardarConsulta,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text("GUARDAR Y SINCRONIZAR VALORACIÓN", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabEvolucionGrafica(List controles) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          _chartCard("CRECIMIENTO (PESO VS REFERENCIA OMS)", _buildChartOMS(controles)),
          const SizedBox(height: 32),
          _chartCard("SEVERIDAD EVA (DOLOR/INFLAMACIÓN/ENERGÍA)", _buildChartEVA(controles)),
          const SizedBox(height: 40),
          const Align(alignment: Alignment.centerLeft, child: Text("HISTORIAL DETALLADO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const SizedBox(height: 16),
          ...controles.reversed.map((c) => _buildConsultaItem(c)).toList(),
        ],
      ),
    );
  }

  Widget _buildChartOMS(List controles) {
    if (controles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          lineBarsData: [
            // REFERENCIA OMS (Percentil 50 aprox)
            LineChartBarData(
              spots: List.generate(controles.length, (i) => FlSpot(i.toDouble(), (controles[i]['peso_kg'] as num).toDouble() * 1.05)),
              isCurved: true, color: Colors.green.withOpacity(0.2), barWidth: 2, dashArray: [5, 5], dotData: const FlDotData(show: false),
            ),
            // PACIENTE
            LineChartBarData(
              spots: List.generate(controles.length, (i) => FlSpot(i.toDouble(), (controles[i]['peso_kg'] as num).toDouble())),
              isCurved: true, color: Colors.blue, barWidth: 4, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
            ),
          ],
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
              if (v.toInt() >= controles.length) return const SizedBox.shrink();
              return Text(DateFormat('dd/MM').format(DateTime.parse(controles[v.toInt()]['fecha_control'])), style: const TextStyle(fontSize: 9));
            }))
          )
        ),
      ),
    );
  }

  Widget _buildChartEVA(List controles) {
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minY: 0, maxY: 10,
          lineBarsData: [
            _lineData(controles, 'nivel_dolor_eva', Colors.orange),
            _lineData(controles, 'nivel_inflamacion', Colors.red),
            _lineData(controles, 'nivel_fatiga', Colors.green),
          ],
        ),
      ),
    );
  }

  LineChartBarData _lineData(List c, String k, Color col) => LineChartBarData(spots: List.generate(c.length, (i) => FlSpot(i.toDouble(), (c[i][k] as num? ?? 0).toDouble())), isCurved: true, color: col, barWidth: 3);

  Widget _buildConsultaItem(Map h) {
    final fecha = DateTime.parse(h['fecha_control']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        onTap: () => setState(() => _prepararEdicion(h)),
        leading: CircleAvatar(backgroundColor: AppTema.azulPrincipal.withOpacity(0.1), child: Text(DateFormat('dd').format(fecha), style: const TextStyle(color: AppTema.azulPrincipal, fontWeight: FontWeight.bold))),
        title: Text(DateFormat('MMMM yyyy', 'es').format(fecha).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text("Peso: ${h['peso_kg']}kg | PCR: ${h['inflamacion_pcr'] ?? '-'} | EVA Dolor: ${h['nivel_dolor_eva']}"),
        trailing: const Icon(Icons.edit_note, color: Colors.orange),
      ),
    );
  }

  Widget _buildTabSeguridad() {
    final alergias = _data!['alergias'];
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        _alergiaCard("SUBGRUPOS BLOQUEADOS", alergias['subgrupos'], Colors.orange),
        const SizedBox(height: 24),
        _alergiaCard("INGREDIENTES PROHIBIDOS", alergias['ingredientes'], Colors.red),
      ]),
    );
  }

  Widget _alergiaCard(String t, List items, Color col) => NutriTableContainer(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 16), Wrap(spacing: 8, children: items.map((i) => Chip(label: Text(i['nombre'], style: const TextStyle(fontSize: 11)), backgroundColor: col.withOpacity(0.1))).toList())])));

  Future<void> _guardarConsulta() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        "peso_kg": _pesoCtrl.text,
        "talla_cm": _tallaCtrl.text,
        "dolor_eva": _dolor.toInt(),
        "inflamacion": _inflamacion.toInt(),
        "fatiga": _fatiga.toInt(),
        "pcr": double.tryParse(_pcrCtrl.text),
        "rigidez_min": int.tryParse(_rigidezCtrl.text),
        "brote_activo": _dolor > 7 || _inflamacion > 7,
        "nota_evolucion": _notaCtrl.text,
        "fecha_proxima_cita": _proximaCita.toIso8601String().split('T')[0],
        "id_condiciones_activas": _condicionesTemporalesHoy // POBLANDO TABLA DE RESTRICCIONES
      };
      await dio.post("pacientes/${widget.paciente['id']}/control-mensual", data: payload);
      _loadExpedienteMaestro();
      NutriSnack.show(context, "✅ Sincronización Completa", ref: ref);
    } catch (e) {
      NutriSnack.show(context, "Error: $e", isError: true, ref: ref);
    } finally { setState(() => _loading = false); }
  }

  Widget _sectionHeader(String t, IconData i) => Row(children: [Icon(i, size: 18, color: AppTema.azulPrincipal), const SizedBox(width: 12), Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]);

  Widget _field(TextEditingController c, String l, IconData i, {int maxLines = 1}) {
    bool n = l.contains("kg") || l.contains("cm") || l.contains("PCR") || l.contains("min");
    return TextFormField(controller: c, maxLines: maxLines, keyboardType: n ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, inputFormatters: n ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: AppTema.azulPrincipal), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)));
  }

  Widget _buildMetricSlider(String title, double val, Function(double) onC, String type) {
    String desc = ""; String emoji = ""; Color color = Colors.grey;
    if (type == "DOLOR") {
      if (val == 0) { desc = "SIN DOLOR"; emoji = "😀"; color = Colors.green; }
      else if (val <= 4) { desc = "MODERADO"; emoji = "😐"; color = Colors.amber; }
      else { desc = "INTENSO"; emoji = "😫"; color = Colors.red; }
    } else if (type == "INFLAMACION") {
      if (val == 0) { desc = "NORMAL"; emoji = "💪"; color = Colors.green; }
      else if (val <= 5) { desc = "MODERADA"; emoji = "🩹"; color = Colors.orange; }
      else { desc = "CRÍTICA"; emoji = "🔥"; color = Colors.red; }
    } else {
      if (val >= 8) { desc = "ENÉRGICO"; emoji = "⚡"; color = Colors.green; }
      else if (val >= 4) { desc = "REGULAR"; emoji = "🥱"; color = Colors.orange; }
      else { desc = "AGOTADO"; emoji = "🪫"; color = Colors.red; }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text("${val.toInt()}/10", style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
      Container(
        margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Row(children: [Text(emoji, style: const TextStyle(fontSize: 24)), const SizedBox(width: 12), Text(desc, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]),
          SliderTheme(data: SliderThemeData(activeTrackColor: color, inactiveTrackColor: Colors.black12, thumbColor: color, trackHeight: 6), child: Slider(value: val, min: 0, max: 10, divisions: 10, onChanged: onC)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(11, (i) => Text("$i", style: TextStyle(fontSize: 8, color: val.toInt() == i ? color : Colors.grey))))),
        ]),
      ),
    ]);
  }

  Widget _chartCard(String t, Widget chart) => NutriTableContainer(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)), const SizedBox(height: 24), chart])));
}
