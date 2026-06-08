import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "../../../../core/theme/app_theme.dart";
import "../../data/repositorio_tutor.dart";
import "../../../../core/state/app_providers.dart";

class GenerarPlanAutomaticoModal extends ConsumerStatefulWidget {
  final String idPaciente;
  const GenerarPlanAutomaticoModal({super.key, required this.idPaciente});

  @override
  ConsumerState<GenerarPlanAutomaticoModal> createState() =>
      _GenerarPlanAutomaticoModalState();
}

class _GenerarPlanAutomaticoModalState
    extends ConsumerState<GenerarPlanAutomaticoModal> {
  String _durationType = "una semana";
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 6));
  bool _morningSnackEnabled = false;
  bool _afternoonSnackEnabled = false;

  bool _isLoading = false;

  void _updateEndDate() {
    setState(() {
      if (_durationType == "un día") {
        _endDate = _startDate;
      } else if (_durationType == "una semana") {
        _endDate = _startDate.add(const Duration(days: 6));
      } else if (_durationType == "un mes") {
        _endDate = _startDate.add(const Duration(days: 30));
      }
    });
  }

  Future<void> _generar() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(repositorioTutorProvider);

      final List<int> momentosObligatorios = [
        1,
        3,
        5
      ]; // Desayuno, Almuerzo, Merienda
      final List<int> momentosOpcionales = [];
      if (_morningSnackEnabled) momentosOpcionales.add(2);
      if (_afternoonSnackEnabled) momentosOpcionales.add(4);

      final totalDias = _endDate.difference(_startDate).inDays + 1;

      await repo.generarPlanAutomatico(
        idPaciente: widget.idPaciente,
        dias: totalDias,
        fechaInicio: _startDate,
        momentosObligatorios: momentosObligatorios,
        momentosOpcionales: momentosOpcionales,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al generar plan: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 40, color: Colors.blue),
          const SizedBox(height: 12),
          const Text("Configurar Plan",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: screenHeight * 0.55, // Altura restringida para móvil
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModalSectionTitle("Duración"),
              DropdownButtonFormField<String>(
                value: _durationType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: "un día", child: Text("Un día")),
                  DropdownMenuItem(
                      value: "una semana", child: Text("Una semana")),
                  DropdownMenuItem(value: "un mes", child: Text("Un mes")),
                ],
                onChanged: (v) {
                  _durationType = v!;
                  _updateEndDate();
                },
              ),
              const SizedBox(height: 20),
              _buildModalSectionTitle("Resumen"),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Text(
                      "${DateFormat('d MMM', 'es_EC').format(_startDate)} - ${DateFormat('d MMM', 'es_EC').format(_endDate)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_endDate.difference(_startDate).inDays + 1} días de vigencia",
                      style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Divider(height: 40, thickness: 1),
              _buildModalSectionTitle("Comidas base"),
              const Text("Se establecerán Desayuno, Almuerzo y Merienda.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: Colors.blueGrey, height: 1.4)),
              const SizedBox(height: 16),
              _buildModalSectionTitle("Snacks opcionales"),
              _buildConfigTile(
                  "Media mañana",
                  "Entre desayuno y almuerzo",
                  Icons.coffee,
                  _morningSnackEnabled,
                  (v) => setState(() => _morningSnackEnabled = v!)),
              _buildConfigTile(
                  "Media tarde",
                  "Entre almuerzo y cena",
                  Icons.apple,
                  _afternoonSnackEnabled,
                  (v) => setState(() => _afternoonSnackEnabled = v!)),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _generar,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Generar"),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildModalSectionTitle(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
            letterSpacing: 1.1),
      ),
    );
  }

  Widget _buildConfigTile(String title, String subtitle, IconData icon,
      bool value, Function(bool?)? onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? Colors.blue.withOpacity(0.03) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? Colors.blue.withOpacity(0.2) : Colors.grey.shade200,
        ),
      ),
      child: CheckboxListTile(
        secondary: Icon(icon, color: value ? Colors.blue : Colors.grey),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: value ? Colors.blue.shade900 : Colors.grey.shade700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        activeColor: Colors.blue,
      ),
    );
  }
}
