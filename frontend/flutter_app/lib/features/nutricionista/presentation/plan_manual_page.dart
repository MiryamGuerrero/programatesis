import "package:flutter/material.dart";

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
    return ListView(
      children: [
        Text("Plan manual", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text("Escribe recetas o IDs por dia. Usa replicacion para semana tipo."),
        const SizedBox(height: 12),
        for (final day in _plan.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              initialValue: _plan[day],
              decoration: InputDecoration(
                labelText: day,
                border: const OutlineInputBorder(),
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
            child: Text(_plan.entries.map((e) => "${e.key}: ${e.value}").join("\n")),
          ),
        ),
      ],
    );
  }
}
