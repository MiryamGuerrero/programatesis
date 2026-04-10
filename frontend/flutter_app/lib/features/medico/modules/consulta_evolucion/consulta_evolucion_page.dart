import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class ConsultaEvolucionPage extends ConsumerStatefulWidget {
  const ConsultaEvolucionPage({super.key});

  @override
  ConsumerState<ConsultaEvolucionPage> createState() => _ConsultaEvolucionPageState();
}

class _ConsultaEvolucionPageState extends ConsumerState<ConsultaEvolucionPage> {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _pacientes = [];
  String? _selectedPacienteId;
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
        _selectedPacienteId = rows.isEmpty ? null : rows.first["id"]?.toString();
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
      setState(() => _error = "Selecciona un paciente para consultar su evolución.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final resumen = await repo.fetchPatientEvolutionSummary(idPaciente: idPaciente);

      if (!mounted) {
        return;
      }
      setState(() {
        _resumen = resumen;
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
        ? List<Map<String, dynamic>>.from(resumen!["historial_controles"] as List)
        : <Map<String, dynamic>>[];
    final condicionesTemporales = (resumen?["condiciones_temporales_activas"] is List)
        ? List<Map<String, dynamic>>.from(resumen!["condiciones_temporales_activas"] as List)
        : <Map<String, dynamic>>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Consulta y Evolución",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                          child: Text(p["nombre_completo"]?.toString() ?? "Paciente"),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedPacienteId = value),
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
              _MetricCard(label: "Paciente", value: resumen["paciente_nombre"]?.toString() ?? "-"),
              _MetricCard(label: "Controles", value: resumen["total_controles"]?.toString() ?? "0"),
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
                value: resumen["adherencia_pct"] == null ? "-" : "${_fmtNum(resumen["adherencia_pct"])}%",
              ),
              _MetricCard(
                label: "Dolor Promedio",
                value: _fmtNum(resumen["dolor_promedio"]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Comparativa adherencia vs dolor", style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(resumen["comparacion_adherencia_dolor"]?.toString() ?? "Sin datos suficientes."),
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
                  Text("Condiciones temporales activas", style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (condicionesTemporales.isEmpty)
                    const Text("No hay condiciones temporales activas."),
                  if (condicionesTemporales.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: condicionesTemporales
                          .map(
                            (item) => Chip(label: Text(item["nombre"]?.toString() ?? "Condición")),
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
                  Text("Historial de controles", style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (historial.isEmpty)
                    const Text("No hay controles registrados para este paciente."),
                  ...historial.map(
                    (control) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timeline),
                      title: Text("Fecha: ${_fmtDate(control["fecha_control"])}"),
                      subtitle: Text(
                        "Peso: ${_fmtNum(control["peso_kg"])} kg | Talla: ${_fmtNum(control["talla_cm"])} cm | IMC: ${_fmtNum(control["imc_calculado"])}\n"
                        "Dolor EVA: ${control["nivel_dolor_eva"] ?? "-"} | Inflamación: ${control["nivel_inflamacion"] ?? "-"}",
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
