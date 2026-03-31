import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class RegistroClinicoPage extends ConsumerStatefulWidget {
  const RegistroClinicoPage({super.key});

  @override
  ConsumerState<RegistroClinicoPage> createState() =>
      _RegistroClinicoPageState();
}

class _RegistroClinicoPageState extends ConsumerState<RegistroClinicoPage> {
  final _pacienteController = TextEditingController();
  final _pesoController = TextEditingController();
  final _tallaController = TextEditingController();
  final _edadMesesController = TextEditingController();
  final _dolorController = TextEditingController();
  final _inflamacionController = TextEditingController();

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void dispose() {
    _pacienteController.dispose();
    _pesoController.dispose();
    _tallaController.dispose();
    _edadMesesController.dispose();
    _dolorController.dispose();
    _inflamacionController.dispose();
    super.dispose();
  }

  Future<void> _registrarControl() async {
    final peso = double.tryParse(_pesoController.text);
    final talla = double.tryParse(_tallaController.text);
    final edadMeses = int.tryParse(_edadMesesController.text);

    if (peso == null || talla == null || edadMeses == null) {
      setState(() => _error = "Peso, talla y edad en meses son obligatorios");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final api = ref.read(inteligenciaRepositoryProvider);
      final repo = ref.read(supabaseCrudRepositoryProvider);

      final imcPayload = await api.calcularImc(
        pesoKg: peso,
        tallaCm: talla,
      );

      final imc = (imcPayload["imc"] as num).toDouble();
      await repo.createClinicalControl(
        idPaciente: _pacienteController.text.trim(),
        pesoKg: peso,
        tallaCm: talla,
        edadMeses: edadMeses,
        dolor: int.tryParse(_dolorController.text),
        inflamacion: int.tryParse(_inflamacionController.text),
        imc: imc,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _resultado =
            "Control registrado. IMC: $imc (${imcPayload["clasificacion"]})";
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
    return ListView(
      children: [
        Text(
          "Registro clinico",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _text(_pacienteController, "ID Paciente (UUID)"),
        const SizedBox(height: 12),
        _text(_pesoController, "Peso kg", number: true),
        const SizedBox(height: 12),
        _text(_tallaController, "Talla cm", number: true),
        const SizedBox(height: 12),
        _text(_edadMesesController, "Edad meses", number: true),
        const SizedBox(height: 12),
        _text(_dolorController, "Dolor EVA (0-10)", number: true),
        const SizedBox(height: 12),
        _text(_inflamacionController, "Inflamacion (0-10)", number: true),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _registrarControl,
          icon: const Icon(Icons.save),
          label: const Text("Guardar control"),
        ),
        if (_resultado != null) ...[
          const SizedBox(height: 12),
          Text(
            _resultado!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
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

  Widget _text(TextEditingController controller, String label,
      {bool number = false}) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}

