import "package:flutter/material.dart";
import "package:reuma_nutri_app/shared/widgets/module_ux.dart";

class PlanManualPage extends StatefulWidget {
  const PlanManualPage({super.key});

  @override
  State<PlanManualPage> createState() => _PlanManualPageState();
}

class _PlanManualPageState extends State<PlanManualPage> {
  final Map<String, String> _plan = {
    "Lunes": "",
    "Martes": "",
    "Miercoles": "",
    "Jueves": "",
    "Viernes": "",
    "Sabado": "",
    "Domingo": "",
  };

  void _replicarSemanaTipo() {
    final lunes = _plan["Lunes"] ?? "";
    setState(() {
      for (final day in _plan.keys) {
        if (day != "Lunes") {
          _plan[day] = lunes;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModuleViewport(
      child: ListView(
        children: [
          const ModuleHeaderCard(
            title: "Plan manual",
            subtitle:
                "Construye una semana tipo y replica ajustes en segundos.",
            icon: Icons.calendar_view_week_rounded,
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          for (final day in _plan.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                initialValue: _plan[day],
                decoration: InputDecoration(
                  labelText: day,
                ),
                onChanged: (value) => _plan[day] = value,
              ),
            ),
          FilledButton.icon(
            onPressed: _replicarSemanaTipo,
            icon: const Icon(Icons.copy_all),
            label: const Text("Replicar lunes a toda la semana"),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                  _plan.entries.map((e) => "${e.key}: ${e.value}").join("\n")),
            ),
          ),
        ],
      ),
    );
  }
}
