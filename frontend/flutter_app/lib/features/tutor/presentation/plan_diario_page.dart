import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "../../../core/theme/app_theme.dart";
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Plan del Día",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: planAsync.when(
        data: (comidas) => comidas.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                itemCount: comidas.length,
                itemBuilder: (context, index) {
                  final item = comidas[index];
                  return _MealCard(
                    item: item,
                    onMarcar: () => _marcarConsumido(context, ref, item["id_plan_item"]),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text("Error: $err", textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_meals_rounded, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            "Sin plan asignado",
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          const Text("No hay un plan generado para esta fecha.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _marcarConsumido(BuildContext context, WidgetRef ref, int idPlanItem) async {
    try {
      await ref.read(seguimientoNotifierProvider.notifier).marcarConsumido(
            idPlanItem,
            ref,
            idPaciente: idPaciente,
            fecha: fecha,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Comida registrada con éxito")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _MealCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onMarcar;

  const _MealCard({required this.item, required this.onMarcar});

  @override
  Widget build(BuildContext context) {
    final bool consumido = item["id_estado_consumo"] == 1;
    final String momento = item["momento_nombre"] ?? "Comida";
    final String receta = item["receta_nombre"] ?? "Cargando receta...";
    final String calorias = "${item["calorias_totales"] ?? 0} kcal";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: consumido ? AppTema.verdeSalud : AppTema.azulPrincipal,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMomentoTag(momento),
                          if (consumido)
                            const Icon(Icons.check_circle_rounded, color: AppTema.verdeSalud, size: 24),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        receta,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        calorias,
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!consumido) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: onMarcar,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTema.azulPrincipal),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              "MARCAR CONSUMIDO",
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTema.azulPrincipal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMomentoTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
