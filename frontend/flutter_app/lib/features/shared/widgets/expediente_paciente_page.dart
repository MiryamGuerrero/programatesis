import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fl_chart/fl_chart.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";

class ExpedientePacientePage extends ConsumerStatefulWidget {
  final String idPaciente;
  final String nombrePaciente;
  final VoidCallback onBack;

  const ExpedientePacientePage({super.key, required this.idPaciente, required this.nombrePaciente, required this.onBack});

  @override
  ConsumerState<ExpedientePacientePage> createState() => _ExpedientePacientePageState();
}

class _ExpedientePacientePageState extends ConsumerState<ExpedientePacientePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  Map<String, dynamic>? _data;
  
  // Control de Cita
  int _diasParaCita = 0;
  bool _puedeRegistrarControl = false;

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
      // Endpoint nuevo que extrae perfil 360
      final res = await dio.get("pacientes/${widget.idPaciente}/expediente-completo");
      
      setState(() {
        _data = res.data;
        _diasParaCita = _data?['ultimo_control']?['dias_para_cita'] ?? 0;
        // Permitir si faltan 2 días o ya pasó
        _puedeRegistrarControl = _diasParaCita <= 2;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_data == null) return const Scaffold(body: Center(child: Text("Error al cargar expediente")));

    final pac = _data!['paciente'];
    final tutor = _data!['tutor'];
    final ctrl = _data!['ultimo_control'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_ios_new, color: Colors.blueGrey, size: 20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pac['nombre_completo'].toString().toUpperCase(), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: AppTema.azulPrincipal)),
            Text("Expediente: ${widget.idPaciente}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          _buildStatusCitaBadge(),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // PANEL LATERAL IZQUIERDO (RESUMEN FIJO)
          _buildSidebar(pac, ctrl),
          
          // CUERPO CENTRAL (TABS)
          Expanded(
            child: Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabIdentidad(pac, tutor),
                      _buildTabSeguridad(),
                      _buildTabHistorial(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _puedeRegistrarControl 
        ? FloatingActionButton.extended(
            onPressed: () => _abrirFormularioControl(context),
            backgroundColor: AppTema.azulPrincipal,
            icon: const Icon(Icons.add_chart_rounded, color: Colors.white),
            label: const Text("NUEVA CONSULTA MENSUAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        : null,
    );
  }

  Widget _buildStatusCitaBadge() {
    Color bg = _diasParaCita > 0 ? Colors.green.shade50 : Colors.red.shade50;
    Color tx = _diasParaCita > 0 ? Colors.green.shade700 : Colors.red.shade700;
    String label = _diasParaCita > 0 ? "Próxima cita en $_diasParaCita días" : "CITA PENDIENTE / VENCIDA";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: tx.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(Icons.calendar_month, size: 16, color: tx),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: tx, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSidebar(Map pac, Map ctrl) {
    return Container(
      width: 300,
      color: Colors.white,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.person, size: 50, color: Colors.blueGrey)),
          const SizedBox(height: 24),
          _sidebarItem("PATOLOGÍA BASE", pac['enfermedad_principal'] ?? "No registrada", isHigh: true),
          _sidebarItem("SEXO", pac['sexo_nombre'] ?? "N/A"),
          _sidebarItem("CANTÓN", pac['canton_nombre'] ?? "N/A"),
          _sidebarItem("PARROQUIA", pac['parroquia_nombre'] ?? "N/A"),
          const Divider(height: 40),
          _sidebarItem("ESTADO OMS", ctrl['diagnostico_oms_texto'] ?? "PENDIENTE"),
          const Spacer(),
          if (!_puedeRegistrarControl)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Text("⚠️ El control mensual se habilitará automáticamente al cumplirse la fecha de cita.", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            )
        ],
      ),
    );
  }

  Widget _sidebarItem(String label, String value, {bool isHigh = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.lato(fontSize: 13, fontWeight: isHigh ? FontWeight.w800 : FontWeight.w600, color: isHigh ? AppTema.azulPrincipal : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTema.azulPrincipal,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppTema.azulPrincipal,
        tabs: const [
          Tab(text: "IDENTIDAD & TUTOR"),
          Tab(text: "SEGURIDAD ALIMENTARIA"),
          Tab(text: "HISTORIAL CLÍNICO"),
        ],
      ),
    );
  }

  Widget _buildTabIdentidad(Map pac, Map tutor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          NutriTableContainer(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DATOS DEL PACIENTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 24),
                  _editableField("Nombre Completo", pac['nombre_completo']),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _editableField("Cédula", pac['cedula'] ?? "S/N")),
                      const SizedBox(width: 16),
                      Expanded(child: _editableField("Fecha Nacimiento", pac['fecha_nacimiento'])),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          NutriTableContainer(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("REPRESENTANTE LEGAL (TUTOR)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 24),
                  _editableField("Nombre Tutor", tutor['nombre_completo']),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _editableField("Cédula Tutor", tutor['cedula'])),
                      const SizedBox(width: 16),
                      Expanded(child: _editableField("Parentesco", tutor['parentesco_nombre'])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _editableField("Correo Electrónico", tutor['email'])),
                      const SizedBox(width: 16),
                      Expanded(child: _editableField("Teléfono / Celular", tutor['telefono'])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _editableField("Dirección de Domicilio", tutor['direccion']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSeguridad() {
    final alergias = _data!['alergias'];
    final subgrupos = (alergias['subgrupos'] as List);
    final ingredientes = (alergias['ingredientes'] as List);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          NutriTableContainer(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 12),
                      const Text("ALERGIAS A GRUPOS BLOQUEADOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      TextButton.icon(onPressed: (){}, icon: const Icon(Icons.add), label: const Text("Gestionar"))
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: subgrupos.map((s) => Chip(
                      label: Text(s['nombre'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.orange.shade50,
                      side: BorderSide(color: Colors.orange.shade200),
                    )).toList(),
                  ),
                  if (subgrupos.isEmpty) const Text("Sin bloqueos de grupos.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          NutriTableContainer(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.block_flipped, color: Colors.red),
                      const SizedBox(width: 12),
                      const Text("INGREDIENTES PROHIBIDOS ESPECÍFICOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      TextButton.icon(onPressed: (){}, icon: const Icon(Icons.add), label: const Text("Gestionar"))
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ingredientes.map((i) => Chip(
                      label: Text(i['nombre'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.red.shade50,
                      side: BorderSide(color: Colors.red.shade200),
                    )).toList(),
                  ),
                  if (ingredientes.isEmpty) const Text("Sin ingredientes prohibidos.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHistorial() {
    final historial = (_data!['historial_controles'] as List? ?? []);
    if (historial.isEmpty) return const Center(child: Text("Sin historial clínico registrado."));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("EVOLUCIÓN DE CRECIMIENTO (PESO)", Icons.monitor_weight_outlined),
          const SizedBox(height: 24),
          _buildChartPeso(historial),
          
          const SizedBox(height: 48),
          _sectionTitle("ACTIVIDAD DE LA ENFERMEDAD (MÉTRICAS EVA)", Icons.analytics_outlined),
          const SizedBox(height: 24),
          _buildChartEVA(historial),

          const SizedBox(height: 48),
          _sectionTitle("LISTADO DE CONSULTAS", Icons.list_alt_rounded),
          const SizedBox(height: 16),
          ...historial.reversed.map((h) => _buildConsultaItem(h)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: AppTema.azulPrincipal, size: 20),
      const SizedBox(width: 12),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
    ]);
  }

  Widget _buildChartEVA(List historial) {
    return Container(
      height: 300, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: LineChart(
        LineChartData(
          minY: 0, maxY: 10,
          gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => FlLine(color: v == 0 ? Colors.green.withOpacity(0.3) : Colors.grey.shade100, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(axisNameWidget: Text("ESCALA 0-10", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
              if (v.toInt() >= historial.length) return const SizedBox.shrink();
              final fecha = DateTime.parse(historial[v.toInt()]['fecha_control']);
              return Text(DateFormat('dd/MM').format(fecha), style: const TextStyle(fontSize: 10, color: Colors.grey));
            })),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            // DOLOR (EVA) - Rojo
            LineChartBarData(
              spots: List.generate(historial.length, (i) => FlSpot(i.toDouble(), (historial[i]['puntos_dolor'] as num? ?? 0).toDouble())),
              isCurved: true, color: Colors.red, barWidth: 3, dotData: const FlDotData(show: true),
            ),
            // INFLAMACIÓN - Morado
            LineChartBarData(
              spots: List.generate(historial.length, (i) => FlSpot(i.toDouble(), (historial[i]['escala_inflamacion'] as num? ?? 0).toDouble())),
              isCurved: true, color: Colors.purple, barWidth: 3, dotData: const FlDotData(show: true),
            ),
            // FATIGA - Verde (invertido: 10=energía máxima)
            LineChartBarData(
              spots: List.generate(historial.length, (i) => FlSpot(i.toDouble(), (historial[i]['nivel_fatiga'] as num? ?? 10).toDouble())),
              isCurved: true, color: Colors.green, barWidth: 3, dotData: const FlDotData(show: true),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => const Color(0xFF1E293B),
              getTooltipItems: (spots) {
                final data = historial[spots.first.x.toInt()];
                return [
                  LineTooltipItem(
                    "ACTIVIDAD CLÍNICA\n",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    children: [
                      TextSpan(text: "🔴 Dolor (EVA): ${data['puntos_dolor'] ?? 0}/10\n", style: const TextStyle(color: Colors.redAccent, height: 1.5)),
                      TextSpan(text: "🟣 Inflamación: ${data['escala_inflamacion'] ?? 0}/3\n", style: const TextStyle(color: Colors.purpleAccent, height: 1.5)),
                      TextSpan(text: "🟢 Energía: ${data['nivel_fatiga'] ?? 10}/10", style: const TextStyle(color: Colors.greenAccent, height: 1.5)),
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

  Widget _buildChartPeso(List historial) {
    return Container(
      height: 300, padding: const EdgeInsets.fromLTRB(10, 32, 32, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => FlLine(color: v == 0 ? Colors.blue.withOpacity(0.3) : Colors.grey.shade100, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(axisNameWidget: Text("PESO (kg)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
              if (v.toInt() >= historial.length) return const SizedBox.shrink();
              final fecha = DateTime.parse(historial[v.toInt()]['fecha_control']);
              return Text(DateFormat('dd/MM').format(fecha), style: const TextStyle(fontSize: 10, color: Colors.grey));
            })),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
          lineBarsData: [
            // PESO ACTUAL
            LineChartBarData(
              spots: List.generate(historial.length, (i) => FlSpot(i.toDouble(), (historial[i]['peso_kg'] as num).toDouble())),
              isCurved: true, color: Colors.blue, barWidth: 4, dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
            ),
            // PESO IDEAL (línea punteada)
            LineChartBarData(
              spots: List.generate(historial.length, (i) => FlSpot(i.toDouble(), (historial[i]['peso_ideal'] as num? ?? 0).toDouble())),
              isCurved: true, color: Colors.blue.shade200, barWidth: 2, dashArray: [5, 5], dotData: const FlDotData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => const Color(0xFF1E293B),
              getTooltipItems: (spots) {
                final data = historial[spots.first.x.toInt()];
                final actual = (data['peso_kg'] as num).toDouble();
                final ideal = (data['peso_ideal'] as num? ?? 0).toDouble();
                final diff = actual - ideal;
                String msg = diff.abs() < 0.5 ? "✅ Peso óptimo" : (diff > 0 ? "⬇️ Debe bajar ${diff.toStringAsFixed(1)}kg" : "⬆️ Debe subir ${diff.abs().toStringAsFixed(1)}kg");
                return [
                  LineTooltipItem(
                    "EVOLUCIÓN DE PESO\n",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    children: [
                      TextSpan(text: "Actual: ${actual}kg\n", style: const TextStyle(color: Colors.lightBlueAccent, height: 1.5)),
                      TextSpan(text: "Ideal OMS: ${ideal.toStringAsFixed(1)}kg\n", style: const TextStyle(color: Colors.blueAccent, height: 1.5)),
                      TextSpan(text: msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, height: 1.5)),
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

  Widget _buildConsultaItem(Map h) {
    final fecha = DateTime.parse(h['fecha_control']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0, borderOnForeground: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: AppTema.azulPrincipal.withOpacity(0.1), child: Text(DateFormat('dd').format(fecha), style: const TextStyle(color: AppTema.azulPrincipal, fontWeight: FontWeight.bold))),
        title: Text(DateFormat('MMMM yyyy', 'es').format(fecha).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text("Peso: ${h['peso_kg']}kg | PCR: ${h['inflamacion_pcr'] ?? '-'} | Status: ${h['diagnostico_oms_texto']}"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _editableField(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Text(value?.toString() ?? "-", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  void _abrirFormularioControl(BuildContext context) {
    final pac = _data!['paciente'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioControlMensual(
        idPaciente: widget.idPaciente,
        fechaNacimiento: pac['fecha_nacimiento'],
        idSexo: pac['id_sexo'],
        onSuccess: () {
          Navigator.pop(context);
          _loadExpedienteMaestro();
          NutriSnack.show(context, "✅ Control Mensual Registrado", ref: ref);
        },
      ),
    );
  }
}

class _FormularioControlMensual extends ConsumerStatefulWidget {
  final String idPaciente;
  final String fechaNacimiento;
  final int idSexo;
  final VoidCallback onSuccess;
  const _FormularioControlMensual({required this.idPaciente, required this.fechaNacimiento, required this.idSexo, required this.onSuccess});

  @override
  ConsumerState<_FormularioControlMensual> createState() => _FormularioControlMensualState();
}

class _FormularioControlMensualState extends ConsumerState<_FormularioControlMensual> {
  int _step = 0;
  bool _saving = false;

  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();
  final _pcrCtrl = TextEditingController();
  final _rigidezCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  double _dolor = 0;
  double _inflamacion = 0;
  double _fatiga = 10;
  final bool _brote = false;
  DateTime _proximaCita = DateTime.now().add(const Duration(days: 30));

  String _omsStatus = "PENDIENTE";
  Color _omsColor = Colors.grey;
  List<dynamic> _condicionesTemp = [];
  final Map<int, DateTime> _condicionesTemporalesSeleccionadas = {};

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final results = await repo.fetchCatalog("heuristico", "condicion");
      if (mounted) {
        setState(() {
          _condicionesTemp = results.where((c) => (c["id_tipo"] ?? c["id_tipo_condicion"]) == 2).toList();
        });
      }
    } catch (_) {}
  }

  void _calculateOMS() {
    double p = double.tryParse(_pesoCtrl.text) ?? 0;
    double t = double.tryParse(_tallaCtrl.text) ?? 0;
    if (p > 0 && t > 0) {
      double imc = p / ((t / 100) * (t / 100));
      setState(() {
        if (imc < 13) { _omsStatus = "DELGADEZ SEVERA"; _omsColor = Colors.red; }
        else if (imc < 14.5) { _omsStatus = "DELGADEZ"; _omsColor = Colors.orange; }
        else if (imc < 18.5) { _omsStatus = "RIESGO DESNUTRICIÓN"; _omsColor = Colors.amber; }
        else if (imc < 25) { _omsStatus = "EUTRÓFICO (NORMAL)"; _omsColor = Colors.green; }
        else if (imc < 30) { _omsStatus = "SOBREPESO"; _omsColor = Colors.orange; }
        else { _omsStatus = "OBESIDAD"; _omsColor = Colors.red; }
      });
    }
  }

  Widget _buildRealtimeOMS() => Container(
    width: double.infinity, padding: const EdgeInsets.all(20), 
    decoration: BoxDecoration(color: _omsColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _omsColor.withOpacity(0.3))), 
    child: Column(children: [
      const Text("ESTADO NUTRICIONAL ACTUAL (OMS)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), 
      const SizedBox(height: 8), 
      Text(_omsStatus, style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900, color: _omsColor))
    ])
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: IndexedStack(
              index: _step,
              children: [
                _stepMedidas(),
                _stepClinico(),
                _stepCita(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("CONSULTA DE SEGUIMIENTO", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: AppTema.azulPrincipal)),
          const Text("Evolución clínica mensual obligatoria.", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        const Spacer(),
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
      ],
    );
  }

  Widget _stepMedidas() {
    return Column(
      children: [
        _field(_pesoCtrl, "Peso Actual (kg)*", Icons.monitor_weight_outlined, onChanged: (_) => _calculateOMS()),
        const SizedBox(height: 16),
        _field(_tallaCtrl, "Talla Actual (cm)*", Icons.height_rounded, onChanged: (_) => _calculateOMS()),
        const SizedBox(height: 32),
        _buildRealtimeOMS(),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
          child: const Row(children: [
            Icon(Icons.auto_graph_rounded, color: Colors.blue),
            SizedBox(width: 16),
            Expanded(child: Text("El sistema recalculará automáticamente el estado nutricional del niño basado en las curvas OMS.", style: TextStyle(fontSize: 12, color: Colors.blue))),
          ]),
        )
      ],
    );
  }

  Widget _stepClinico() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricSlider("ESCALA DE DOLOR", _dolor, (v) => setState(() => _dolor = v), "DOLOR"),
          const SizedBox(height: 16),
          _buildMetricSlider("NIVEL DE INFLAMACIÓN", _inflamacion, (v) => setState(() => _inflamacion = v), "INFLAMACION"),
          const SizedBox(height: 16),
          _buildMetricSlider("NIVEL DE ENERGÍA", _fatiga, (v) => setState(() => _fatiga = v), "FATIGA"),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _field(_pcrCtrl, "PCR*", Icons.biotech)),
            const SizedBox(width: 16),
            Expanded(child: _field(_rigidezCtrl, "Rigidez (min)", Icons.timer_outlined)),
          ]),
          const SizedBox(height: 24),
          const Text("CONDICIONES TEMPORALES ACTIVAS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTema.azulPrincipal)),
          const Text("Seleccione síntomas actuales y su fecha de inicio:", style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _condicionesTemp.map((c) {
            final id = c["id"] as int;
            final isSelected = _condicionesTemporalesSeleccionadas.containsKey(id);
            return FilterChip(
              label: Text(c["nombre"]), 
              selected: isSelected,
              onSelected: (v) async {
                if (v) {
                  final f = await showDatePicker(
                    context: context, 
                    helpText: "FECHA DE INICIO DEL SÍNTOMA",
                    initialDate: DateTime.now(), 
                    firstDate: DateTime.now().subtract(const Duration(days: 30)), 
                    lastDate: DateTime.now()
                  );
                  if (f != null) setState(() => _condicionesTemporalesSeleccionadas[id] = f);
                } else { 
                  setState(() => _condicionesTemporalesSeleccionadas.remove(id)); 
                }
              },
            );
          }).toList()),
          if (_condicionesTemporalesSeleccionadas.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._condicionesTemporalesSeleccionadas.entries.map((e) {
              final nombre = _condicionesTemp.firstWhere((c) => c["id"] == e.key)["nombre"];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Expanded(child: Text(nombre, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  const Text("Desde:", style: TextStyle(fontSize: 10)),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: e.value, firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now());
                      if (d != null) setState(() => _condicionesTemporalesSeleccionadas[e.key] = d);
                    },
                    child: Text(DateFormat('dd/MM/yy').format(e.value), style: const TextStyle(fontSize: 11)),
                  ),
                ]),
              );
            }),
          ],
          const SizedBox(height: 24),
          _field(_notaCtrl, "Notas de evolución...", Icons.edit_note, maxLines: 2),
        ],
      ),
    );
  }

  Widget _stepCita() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.event_available_rounded, size: 60, color: AppTema.azulPrincipal),
        const SizedBox(height: 16),
        const Text("AGENDAR PRÓXIMA CITA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Text("Se recomienda un seguimiento cada 30 días.", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 32),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          leading: const Icon(Icons.calendar_today),
          title: const Text("Fecha Programada"),
          subtitle: Text(DateFormat('EEEE, d MMMM yyyy', 'es').format(_proximaCita).toUpperCase()),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _proximaCita, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
            if (d != null) setState(() => _proximaCita = d);
          },
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        if (_step > 0) OutlinedButton(onPressed: () => setState(() => _step--), child: const Text("ANTERIOR")),
        const Spacer(),
        FilledButton(
          onPressed: _saving ? null : () {
            if (_step < 2) {
              setState(() => _step++);
            } else {
              _guardarControl();
            }
          },
          child: Text(_saving ? "GUARDANDO..." : (_step < 2 ? "CONTINUAR" : "FINALIZAR CONSULTA")),
        ),
      ],
    );
  }

  Future<void> _guardarControl() async {
    if (_pesoCtrl.text.isEmpty || _tallaCtrl.text.isEmpty || _pcrCtrl.text.isEmpty) {
      NutriSnack.show(context, "Faltan datos obligatorios", isError: true, ref: ref);
      return;
    }
    setState(() => _saving = true);
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
        "brote_activo": _dolor > 7 || _inflamacion >= 2, // Lógica automática de sugerencia de brote (Inflamación >= 2 de 3)
        "nota_evolucion": _notaCtrl.text,
        "fecha_proxima_cita": _proximaCita.toIso8601String().split('T')[0],
        "condiciones_temporales": _condicionesTemporalesSeleccionadas.entries.map((e) => {
          "id": e.key,
          "fecha_inicio": e.value.toIso8601String().split('T')[0]
        }).toList(),
      };
      await dio.post("pacientes/${widget.idPaciente}/control-mensual", data: payload);
      widget.onSuccess();
    } catch (e) {
      NutriSnack.show(context, "Error al registrar control", isError: true, ref: ref);
    } finally { setState(() => _saving = false); }
  }

  // REUTILIZAR WIDGETS DE ESCALAS Y CAMPOS (Iguales a los del registro para consistencia)
  Widget _field(TextEditingController c, String l, IconData i, {int maxLines = 1, Function(String)? onChanged}) {
    bool n = l.contains("kg") || l.contains("cm") || l.contains("PCR") || l.contains("min");
    return TextFormField(
      controller: c, maxLines: maxLines,
      onChanged: onChanged,
      keyboardType: n ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: n ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null,
      decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))
    );
  }

  Widget _buildMetricSlider(String title, double val, Function(double) onC, String type) {
    String desc = ""; String emoji = ""; Color color = Colors.grey; double maxV = 10;
    if (type == "DOLOR") {
      if (val == 0) { desc = "SIN DOLOR: Sin molestias."; emoji = "😀"; color = Colors.green; }
      else if (val <= 2) { desc = "POCO DOLOR: Molestia leve."; emoji = "🙂"; color = Colors.lightGreen; }
      else if (val <= 4) { desc = "MODERADO: Percibe incomodidad."; emoji = "😐"; color = Colors.amber; }
      else if (val <= 6) { desc = "FUERTE: Afecta bienestar."; emoji = "😟"; color = Colors.orange; }
      else if (val <= 8) { desc = "MUY FUERTE: Limita movimiento."; emoji = "😫"; color = Colors.redAccent; }
      else { desc = "INSOPORTABLE: Urgencia clínica."; emoji = "😭"; color = Colors.red.shade900; }
    } else if (type == "INFLAMACION") {
      maxV = 3;
      if (val == 0) { desc = "NORMAL: Sin signos."; emoji = "💪"; color = Colors.green; }
      else if (val == 1) { desc = "MÍNIMA: Hinchazón leve."; emoji = "🙂"; color = Colors.lightGreen; }
      else if (val == 2) { desc = "MODERADA: Visible y limitante."; emoji = "😟"; color = Colors.orange; }
      else { desc = "CRÍTICA: Inflamación sistémica."; emoji = "🔥"; color = Colors.red; }
    } else {
      if (val == 10) { desc = "ENÉRGICO: Energía máxima."; emoji = "⚡"; color = Colors.green; }
      else if (val >= 7) { desc = "BUENO: Energía estable."; emoji = "🔋"; color = Colors.lightGreen; }
      else if (val >= 4) { desc = "REGULAR: Cansancio moderado."; emoji = "🥱"; color = Colors.orange; }
      else { desc = "AGOTADO: Sin energía basal."; emoji = "🪫"; color = Colors.red; }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text("${val.toInt()}/${maxV.toInt()}", style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
      Container(
        margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Row(children: [Text(emoji, style: const TextStyle(fontSize: 24)), const SizedBox(width: 12), Expanded(child: Text(desc, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))]),
          SliderTheme(data: SliderThemeData(activeTrackColor: color, inactiveTrackColor: Colors.black12, thumbColor: color, trackHeight: 4), child: Slider(value: val, min: 0, max: maxV, divisions: maxV.toInt(), onChanged: onC)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(maxV.toInt() + 1, (i) => Text("$i", style: TextStyle(fontSize: 8, color: val.toInt() == i ? color : Colors.grey))))),
        ]),
      ),
    ]);
  }
}
