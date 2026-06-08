import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fl_chart/fl_chart.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class ConsultaEvolucionPage extends ConsumerStatefulWidget {
  const ConsultaEvolucionPage({super.key});

  @override
  ConsumerState<ConsultaEvolucionPage> createState() =>
      _ConsultaEvolucionPageState();
}

class _ConsultaEvolucionPageState extends ConsumerState<ConsultaEvolucionPage> {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _pacientes = [];
  String? _selectedPacienteId;
  String? _selectedPacienteNombre;
  Map<String, dynamic>? _resumen;

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _fmtDate(dynamic value) {
    final text = value?.toString() ?? "";
    if (text.length >= 10) {
      return text.substring(0, 10);
    }
    return text.isEmpty ? "-" : text;
  }

  String _fmtNum(dynamic value, {int decimals = 1}) {
    if (value == null) {
      return "-";
    }
    if (value is num) {
      return value.toStringAsFixed(decimals);
    }
    return value.toString();
  }

  Future<void> _buscarPacientes() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _pacientes = [];
        _selectedPacienteId = null;
      });
      return;
    }

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final rows = await repo.searchPatients(query: query, limit: 10);
      if (!mounted) {
        return;
      }
      setState(() {
        _pacientes = rows;
        _selectedPacienteId =
            rows.isEmpty ? null : rows.first["id"]?.toString();
        _selectedPacienteNombre =
            rows.isEmpty ? null : rows.first["nombre_completo"]?.toString();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  Future<void> _cargarResumen() async {
    final idPaciente = _selectedPacienteId;
    if (idPaciente == null || idPaciente.isEmpty) {
      setState(
          () => _error = "Selecciona un paciente para consultar su evolución.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final resultados = await Future.wait([
        repo.fetchPatientEvolutionSummary(idPaciente),
        repo.fetchExpedienteCompleto(idPaciente),
      ]);
      final historial = List<Map<String, dynamic>>.from(resultados[0] as List);
      final expediente = Map<String, dynamic>.from(resultados[1] as Map);
      final paciente = expediente["paciente"] is Map
          ? Map<String, dynamic>.from(expediente["paciente"])
          : <String, dynamic>{};

      if (!mounted) {
        return;
      }
      final dolorPromedio = historial.isEmpty
          ? null
          : historial
                  .map((h) => (h["puntos_dolor"] as num? ?? 0).toDouble())
                  .reduce((a, b) => a + b) /
              historial.length;
      setState(() {
        _resumen = {
          "paciente_nombre": _selectedPacienteNombre ??
              paciente["nombre_completo"]?.toString() ??
              "-",
          "historial_controles": historial,
          "total_controles": historial.length,
          "total_alergias_ingrediente":
              ((expediente["alergias"]?["ingredientes"] as List?)?.length ?? 0),
          "total_alergias_grupo":
              ((expediente["alergias"]?["subgrupos"] as List?)?.length ?? 0),
          "adherencia_pct": historial.isEmpty
              ? null
              : ((historial
                          .where((h) => (h["en_brote"] ?? false) != true)
                          .length /
                      historial.length) *
                  100),
          "dolor_promedio": dolorPromedio,
          "comparacion_adherencia_dolor": historial.isEmpty
              ? "Sin datos suficientes."
              : "Tendencia clínica disponible: revise dolor, inflamación, articulaciones y brotes.",
        };
        _resumen!["condiciones_temporales_activas"] =
            expediente["condiciones_temporales_activas"] ??
                expediente["condiciones_temporales"] ??
                [];
        _resultado = "Resumen cargado correctamente.";
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;
    final historial = (resumen?["historial_controles"] is List)
        ? List<Map<String, dynamic>>.from(
            resumen!["historial_controles"] as List)
        : <Map<String, dynamic>>[];
    final condicionesTemporales =
        (resumen?["condiciones_temporales_activas"] is List)
            ? List<Map<String, dynamic>>.from(
                resumen!["condiciones_temporales_activas"] as List)
            : <Map<String, dynamic>>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Consulta y Evolución",
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: "Buscar paciente por nombre",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => _buscarPacientes(),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPacienteId,
                  decoration: const InputDecoration(labelText: "Paciente"),
                  items: _pacientes
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p["id"]?.toString(),
                          child: Text(
                              p["nombre_completo"]?.toString() ?? "Paciente"),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPacienteId = value;
                      final match = _pacientes
                          .where((p) => p["id"]?.toString() == value)
                          .toList();
                      _selectedPacienteNombre = match.isEmpty
                          ? null
                          : match.first["nombre_completo"]?.toString();
                    });
                  },
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _loading ? null : _cargarResumen,
                  icon: const Icon(Icons.insights),
                  label: const Text("Consultar evolución"),
                ),
              ],
            ),
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
        if (resumen != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricCard(
                  label: "Paciente",
                  value: resumen["paciente_nombre"]?.toString() ?? "-"),
              _MetricCard(
                  label: "Controles",
                  value: resumen["total_controles"]?.toString() ?? "0"),
              _MetricCard(
                label: "Alergias Ingredientes",
                value: resumen["total_alergias_ingrediente"]?.toString() ?? "0",
              ),
              _MetricCard(
                label: "Alergias Grupos",
                value: resumen["total_alergias_grupo"]?.toString() ?? "0",
              ),
              _MetricCard(
                label: "Adherencia",
                value: resumen["adherencia_pct"] == null
                    ? "-"
                    : "${_fmtNum(resumen["adherencia_pct"])}%",
              ),
              _MetricCard(
                label: "Dolor Promedio",
                value: _fmtNum(resumen["dolor_promedio"]),
              ),
            ],
          ),
          if (historial.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChartCard(
              title: "Actividad clínica",
              child: SizedBox(
                  height: 280, child: _buildClinicalActivityChart(historial)),
            ),
            const SizedBox(height: 12),
            _ChartCard(
              title: "Compromiso articular",
              child: SizedBox(
                  height: 280, child: _buildJointImpactChart(historial)),
            ),
            const SizedBox(height: 12),
            _ChartCard(
              title: "Peso e IMC",
              child: SizedBox(
                  height: 260, child: _buildAnthropometryChart(historial)),
            ),
            const SizedBox(height: 12),
            _ChartCard(
              title: "Talla",
              child: SizedBox(height: 220, child: _buildHeightChart(historial)),
            ),
            const SizedBox(height: 12),
            _ChartCard(
              title: "Brote y evolución",
              child: _buildTimeline(historial),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Comparativa adherencia vs dolor",
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(resumen["comparacion_adherencia_dolor"]?.toString() ??
                      "Sin datos suficientes."),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Condiciones temporales activas",
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (condicionesTemporales.isEmpty)
                    const Text("No hay condiciones temporales activas."),
                  if (condicionesTemporales.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: condicionesTemporales
                          .map(
                            (item) => Chip(
                                label: Text(
                                    item["nombre"]?.toString() ?? "Condición")),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Historial de controles",
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (historial.isEmpty)
                    const Text(
                        "No hay controles registrados para este paciente."),
                  ...historial.map(
                    (control) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timeline),
                      title:
                          Text("Fecha: ${_fmtDate(control["fecha_control"])}"),
                      subtitle: Text(
                        "Peso: ${_fmtNum(control["peso_kg"])} kg | Talla: ${_fmtNum(control["talla_cm"])} cm | IMC: ${_fmtNum(control["imc_calculado"])}\n"
                        "Dolor EVA: ${control["puntos_dolor"] ?? "-"} | Inflamación: ${control["escala_inflamacion"] ?? "-"} | Fatiga: ${control["nivel_fatiga"] ?? "-"}",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_resultado != null) ...[
          const SizedBox(height: 10),
          Text(
            _resultado!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

extension _EvolutionCharts on _ConsultaEvolucionPageState {
  Widget _buildDualLineChart(
    List<Map<String, dynamic>> historial,
    String keyA,
    String keyB,
    Color colorA,
    Color colorB,
  ) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= historial.length)
                  return const SizedBox.shrink();
                return Text(_fmtDate(historial[idx]["fecha_control"]),
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
                historial.length,
                (i) => FlSpot(i.toDouble(),
                    (historial[i][keyA] as num? ?? 0).toDouble())),
            isCurved: true,
            color: colorA,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: List.generate(
                historial.length,
                (i) => FlSpot(i.toDouble(),
                    (historial[i][keyB] as num? ?? 0).toDouble())),
            isCurved: true,
            color: colorB,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChart(List<Map<String, dynamic>> historial) {
    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= historial.length)
                  return const SizedBox.shrink();
                return Text(_fmtDate(historial[idx]["fecha_control"]),
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
                historial.length,
                (i) => FlSpot(i.toDouble(),
                    (historial[i]["peso_kg"] as num? ?? 0).toDouble())),
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: List.generate(
                historial.length,
                (i) => FlSpot(i.toDouble(),
                    (historial[i]["talla_cm"] as num? ?? 0).toDouble())),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: List.generate(
                historial.length,
                (i) => FlSpot(i.toDouble(),
                    (historial[i]["z_score_bmi"] as num? ?? 0).toDouble())),
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalActivityChart(List<Map<String, dynamic>> historial) {
    return _buildMultiMetricChart(
      historial,
      maxY: 10,
      series: const [
        _SeriesConfig("puntos_dolor", Colors.red),
        _SeriesConfig("nivel_fatiga", Colors.green),
        _SeriesConfig("escala_inflamacion", Colors.purple),
      ],
      leftLabelBuilder: (value) => value.toStringAsFixed(0),
    );
  }

  Widget _buildJointImpactChart(List<Map<String, dynamic>> historial) {
    final maxY = historial.fold<double>(10, (acc, h) {
      final infl = (h["articulaciones_inflamadas"] as num? ?? 0).toDouble();
      final dolor = (h["articulaciones_dolorosas"] as num? ?? 0).toDouble();
      final rigidez = (h["minutos_rigidez"] as num? ?? 0).toDouble();
      return [acc, infl, dolor, rigidez].reduce((a, b) => a > b ? a : b);
    });
    return _buildMultiMetricChart(
      historial,
      maxY: maxY <= 0 ? 10 : maxY,
      series: const [
        _SeriesConfig("articulaciones_inflamadas", Colors.orange),
        _SeriesConfig("articulaciones_dolorosas", Colors.blue),
        _SeriesConfig("minutos_rigidez", Colors.redAccent),
      ],
      leftLabelBuilder: (value) => value.toStringAsFixed(0),
    );
  }

  Widget _buildAnthropometryChart(List<Map<String, dynamic>> historial) {
    final maxY = historial.fold<double>(1, (acc, h) {
      final peso = (h["peso_kg"] as num? ?? 0).toDouble();
      final imc = (h["imc_calculado"] as num? ?? 0).toDouble();
      return [acc, peso, imc].reduce((a, b) => a > b ? a : b);
    });
    return _buildMultiMetricChart(
      historial,
      maxY: maxY * 1.1,
      series: const [
        _SeriesConfig("peso_kg", Colors.green),
        _SeriesConfig("imc_calculado", Colors.indigo),
      ],
      leftLabelBuilder: (value) => value.toStringAsFixed(1),
    );
  }

  Widget _buildHeightChart(List<Map<String, dynamic>> historial) {
    final maxY = historial.fold<double>(1, (acc, h) {
      final talla = (h["talla_cm"] as num? ?? 0).toDouble();
      return talla > acc ? talla : acc;
    });
    return _buildMultiMetricChart(
      historial,
      maxY: maxY * 1.1,
      series: const [
        _SeriesConfig("talla_cm", Colors.indigo),
      ],
      leftLabelBuilder: (value) => "${value.toStringAsFixed(0)} cm",
    );
  }

  Widget _buildMultiMetricChart(
    List<Map<String, dynamic>> historial, {
    required double maxY,
    required List<_SeriesConfig> series,
    required String Function(double) leftLabelBuilder,
  }) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY.isFinite && maxY > 0 ? maxY : 10,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(leftLabelBuilder(value),
                  style: const TextStyle(fontSize: 9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= historial.length)
                  return const SizedBox.shrink();
                return Text(_fmtDate(historial[idx]["fecha_control"]),
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
        lineBarsData: series
            .map(
              (cfg) => LineChartBarData(
                spots: List.generate(
                  historial.length,
                  (i) => FlSpot(i.toDouble(),
                      (historial[i][cfg.key] as num? ?? 0).toDouble()),
                ),
                isCurved: true,
                color: cfg.color,
                barWidth: 3,
                dotData: const FlDotData(show: false),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> historial) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: historial.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final h = historial[index];
          return Container(
            width: 190,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtDate(h["fecha_control"]),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text("Peso: ${_fmtNum(h["peso_kg"])} kg"),
                Text("IMC: ${_fmtNum(h["imc_calculado"])}"),
                Text("Dolor: ${h["puntos_dolor"] ?? "-"}"),
                Text("Inflamación: ${h["escala_inflamacion"] ?? "-"}"),
                Text("Fatiga: ${h["nivel_fatiga"] ?? "-"}"),
                if (h["en_brote"] == true)
                  const Text("Brote activo",
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SeriesConfig {
  const _SeriesConfig(this.key, this.color);

  final String key;
  final Color color;
}
