import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "../../../core/theme/app_theme.dart";
import "../data/seguimiento_provider.dart";
import "../data/repositorio_tutor.dart";

class PlanDiarioPage extends ConsumerWidget {
  final String idPaciente;
  final DateTime fecha;

  const PlanDiarioPage({
    super.key,
    required this.idPaciente,
    required this.fecha,
  });

  String get _fechaApi =>
      "${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";

  Future<void> _marcarConsumido(
      BuildContext context, WidgetRef ref, int idPlanItem) async {
    try {
      final repo = ref.read(repositorioTutorProvider);
      await repo.registrarConsumo(idPlanItem, 1);
      ref.invalidate(
          planDiarioProvider((idPaciente: idPaciente, fecha: _fechaApi)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _intercambiarReceta(
      BuildContext context, WidgetRef ref, int idPlanItem) async {
    try {
      final repo = ref.read(repositorioTutorProvider);
      await repo.intercambiarRecetaPlan(idPlanItem);
      ref.invalidate(
          planDiarioProvider((idPaciente: idPaciente, fecha: _fechaApi)));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Receta intercambiada con éxito")),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref
        .watch(planDiarioProvider((idPaciente: idPaciente, fecha: _fechaApi)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Plan del Día",
          style:
              GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: planAsync.when(
        data: (comidas) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(
                planDiarioProvider((idPaciente: idPaciente, fecha: _fechaApi)));
            return ref.read(
                planDiarioProvider((idPaciente: idPaciente, fecha: _fechaApi))
                    .future);
          },
          child: comidas.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    _buildEmptyState()
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  itemCount: comidas.length,
                  itemBuilder: (context, index) {
                    final item = comidas[index];
                    return _MealCard(
                      item: item,
                      onMarcar: () =>
                          _marcarConsumido(context, ref, item["id_plan_item"]),
                      onCambiar: item["id_origen_plan"] == 2
                          ? () => _intercambiarReceta(
                              context, ref, item["id_plan_item"])
                          : null,
                    );
                  },
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text(
            "No hay plan asignado",
            style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final Future<void> Function() onMarcar;
  final Future<void> Function()? onCambiar;

  const _MealCard({
    super.key,
    required this.item,
    required this.onMarcar,
    this.onCambiar,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _isChanging = false;
  bool _isMarking = false;

  Future<void> _handleCambiar() async {
    if (widget.onCambiar == null) return;
    setState(() => _isChanging = true);
    try {
      await widget.onCambiar!();
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  Future<void> _handleMarcar() async {
    setState(() => _isMarking = true);
    try {
      await widget.onMarcar();
    } finally {
      if (mounted) setState(() => _isMarking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool consumido = widget.item["id_estado_consumo"] == 1;
    final String momento = widget.item["momento_nombre"] ?? "Comida";
    final String receta = widget.item["receta_nombre"] ?? "Cargando receta...";
    final String calorias = "${widget.item["calorias_totales"] ?? 0} kcal";

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
                            const Icon(Icons.check_circle_rounded,
                                color: AppTema.verdeSalud, size: 24),
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
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: (_isChanging || _isMarking)
                                    ? null
                                    : _handleMarcar,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: AppTema.azulPrincipal),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: _isMarking
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTema.azulPrincipal),
                                      )
                                    : Text(
                                        "MARCAR CONSUMIDO",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTema.azulPrincipal,
                                        ),
                                      ),
                              ),
                            ),
                            if (widget.onCambiar != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed:
                                      _isChanging ? null : _handleCambiar,
                                  style: OutlinedButton.styleFrom(
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  child: _isChanging
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.grey),
                                        )
                                      : const Icon(Icons.autorenew,
                                          size: 18, color: Colors.grey),
                                ),
                              ),
                            ],
                          ],
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
