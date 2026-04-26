import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";
import "package:reuma_nutri_app/shared/widgets/module_ux.dart";

class DiagnosticoPage extends ConsumerStatefulWidget {
  const DiagnosticoPage({super.key});

  @override
  ConsumerState<DiagnosticoPage> createState() => _DiagnosticoPageState();
}

class _DiagnosticoPageState extends ConsumerState<DiagnosticoPage> {
  final _indicadorController = TextEditingController(text: "IMC_EDAD");
  final _sexoController = TextEditingController(text: "1");
  final _edadController = TextEditingController();
  final _valorController = TextEditingController();

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void dispose() {
    _indicadorController.dispose();
    _sexoController.dispose();
    _edadController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _diagnosticar() async {
    final idSexo = int.tryParse(_sexoController.text);
    final edad = int.tryParse(_edadController.text);
    final valor = double.tryParse(_valorController.text);

    if (idSexo == null || edad == null || valor == null) {
      setState(() => _error = "Completa sexo, edad y valor");
      return;
    }

    setState(() {
      _loading = true;
      _resultado = null;
      _error = null;
    });

    try {
      final api = ref.read(inteligenciaRepositoryProvider);
      final data = await api.diagnosticoOms(
        indicadorCodigo: _indicadorController.text.trim(),
        idSexo: idSexo,
        edadMeses: edad,
        valor: valor,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _resultado =
            "Z-score: ${data["z_score"]} | Diagnostico: ${data["diagnostico"]}";
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
    return ModuleViewport(
      child: ListView(
        children: [
          const ModuleHeaderCard(
            title: "Diagnostico OMS",
            subtitle:
                "Calcula z-score y clasificacion nutricional segun indicador antropometrico.",
            icon: Icons.biotech_rounded,
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _text(_indicadorController, "Indicador codigo"),
          const SizedBox(height: 12),
          _text(_sexoController, "ID Sexo", number: true),
          const SizedBox(height: 12),
          _text(_edadController, "Edad meses", number: true),
          const SizedBox(height: 12),
          _text(_valorController, "Valor antropometrico", number: true),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _diagnosticar,
            icon: const Icon(Icons.biotech),
            label: const Text("Calcular diagnostico"),
          ),
          if (_resultado != null) ...[
            const SizedBox(height: 12),
            ModuleNotice.success(_resultado!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ModuleNotice.error(_error!),
          ],
        ],
      ),
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
