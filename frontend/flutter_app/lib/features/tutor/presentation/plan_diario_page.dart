import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../data/seguimiento_provider.dart";

class PlanDiarioPage extends ConsumerWidget {
  final String idPaciente;
  final String fecha; // Formato YYYY-MM-DD

  const PlanDiarioPage({
    super.key,
    required this.idPaciente,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planDiarioProvider((idPaciente: idPaciente, fecha: fecha)));

    return Scaffold(
      appBar: AppBar(
        title: Text("Plan del día: $fecha"),
        centerTitle: true,
      ),
      body: planAsync.when(
        data: (comidas) => comidas.isEmpty
            ? const Center(child: Text("No hay un plan generado para hoy."))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: comidas.length,
                itemBuilder: (context, index) {
                  final item = comidas[index];
                  final bool consumido = item["id_estado_consumo"] == 1;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: consumido ? Colors.green : Colors.orangeAccent,
                        child: Icon(
                          consumido ? Icons.check : Icons.restaurant,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        item["receta_nombre"] ?? "Receta sin nombre",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Momento: ${item["momento_nombre"]}"),
                      trailing: consumido
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                              onPressed: () {
                                ref.read(seguimientoNotifierProvider.notifier).marcarConsumido(
                                      item["id_plan_item"],
                                      ref,
                                      idPaciente: idPaciente,
                                      fecha: fecha,
                                    );
                              },
                              child: const Text("Marcar"),
                            ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }
}
