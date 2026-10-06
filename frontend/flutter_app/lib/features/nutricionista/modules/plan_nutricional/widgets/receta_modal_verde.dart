import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/state/app_providers.dart';
import '../../../../../shared/widgets/foquito_semaforo.dart';

Future<void> mostrarDetalleRecetaVerde(
  BuildContext context,
  int idReceta,
  WidgetRef ref, {
  VoidCallback? onSelect,
  String? semaforo,
  String? idPaciente,
  String? mensajeRegla,
}) async {
  if (idReceta <= 0) return;

  showDialog(
    context: context,
    barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
    builder: (ctx) => _ModalRecetaContenido(
      idReceta: idReceta,
      semaforoInicial: semaforo,
      idPaciente: idPaciente,
      mensajeReglaInicial: mensajeRegla,
      onSelect: onSelect != null
          ? () {
              Navigator.pop(ctx);
              onSelect();
            }
          : null,
    ),
  );
}

class _ModalRecetaContenido extends ConsumerStatefulWidget {
  final int idReceta;
  final VoidCallback? onSelect;
  final String? semaforoInicial;
  final String? idPaciente;
  final String? mensajeReglaInicial;

  const _ModalRecetaContenido({
    required this.idReceta,
    this.onSelect,
    this.semaforoInicial,
    this.idPaciente,
    this.mensajeReglaInicial,
  });

  @override
  ConsumerState<_ModalRecetaContenido> createState() =>
      _ModalRecetaContenidoState();
}

class _ModalRecetaContenidoState
    extends ConsumerState<_ModalRecetaContenido> {
  Map<String, dynamic>? receta;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargarReceta();
  }

  Future<void> _cargarReceta() async {
    try {
      final dio = ref.read(dioProvider);
      final Map<String, dynamic> queryParams = {};
      if (widget.idPaciente != null) {
        queryParams["id_paciente"] = widget.idPaciente;
      }
      final res = await dio.get(
        "crud/recetas/${widget.idReceta}",
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (mounted) {
        setState(() {
          receta = Map<String, dynamic>.from(res.data ?? {});
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = "Error al cargar la receta";
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 850,
        height: 600,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final String? imgUrl = receta!["imagen_url"];
    final ingredientes =
        List<Map<String, dynamic>>.from(receta!["ingredientes"] ?? []);

    final String semInicial = (widget.semaforoInicial ?? "").trim().toLowerCase();
    final String semReceta = (receta?["semaforo"] ?? "").trim().toLowerCase();
    final String sem = (semInicial.isNotEmpty && semInicial != "neutral")
        ? semInicial
        : (semReceta.isNotEmpty ? semReceta : (semInicial.isNotEmpty ? semInicial : "neutral"));

    final String msjInicial = (widget.mensajeReglaInicial ?? "").trim();
    final String msjReceta = (receta?["mensaje_regla"] ?? "").trim();
    final String mensajeRegla = msjInicial.isNotEmpty
        ? msjInicial
        : (msjReceta.isNotEmpty
            ? msjReceta
            : (sem == "verde"
                ? "PRIORIZAR: rica en Omega-3 / antiinflamatoria"
                : (sem == "amarillo"
                    ? "DISMINUIR: consumo moderado (máx. 2 veces por semana)"
                    : "Segura y balanceada para el paciente")));

    final Color primaryColor;
    final Color bgColor;
    final Color borderColor;
    final IconData headerIcon;
    final String semaforoLabel;

    if (sem == "amarillo") {
      primaryColor = const Color(0xFFD97706); // Amber 600
      bgColor = const Color(0xFFFEF3C7); // Amber 100
      borderColor = const Color(0xFFFDE68A); // Amber 200
      headerIcon = Icons.lightbulb_rounded;
      semaforoLabel = "Consumo moderado (máx. 2 por semana)";
    } else if (sem == "verde") {
      primaryColor = const Color(0xFF16A34A); // Green 600
      bgColor = const Color(0xFFDCFCE7); // Green 100
      borderColor = const Color(0xFFBBF7D0); // Green 200
      headerIcon = Icons.eco_rounded;
      semaforoLabel = "Recomendada / Potenciada";
    } else {
      primaryColor = const Color(0xFF0284C7); // Sky 600
      bgColor = const Color(0xFFE0F2FE); // Sky 100
      borderColor = const Color(0xFFBAE6FD); // Sky 200
      headerIcon = Icons.restaurant_rounded;
      semaforoLabel = "Segura y balanceada";
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left side: Large Image
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey.shade100,
            child: imgUrl != null && imgUrl.isNotEmpty
                ? Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
                  )
                : const Center(
                    child: Icon(Icons.restaurant, size: 80, color: Colors.grey)),
          ),
        ),
        // Right side: Info
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(headerIcon, color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  receta!["nombre"] ?? "Receta sin nombre",
                                  style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      color: Colors.blueGrey.shade900),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FoquitoSemaforo(
                                semaforo: sem,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: borderColor, width: 0.8),
                                ),
                                child: Text(
                                  semaforoLabel,
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (mensajeRegla.isNotEmpty)
                                Text(
                                  mensajeRegla,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                // Macronutrients Cards
                Row(
                  children: [
                    _buildMacroCard(
                        Icons.local_fire_department,
                        "Calorías",
                        "${receta!["calorias_totales"] ?? 0} kcal",
                        Colors.orange),
                    const SizedBox(width: 16),
                    _buildMacroCard(
                        Icons.fitness_center,
                        "Proteínas",
                        "${receta!["proteinas_totales"] ?? 0} g",
                        Colors.blue),
                  ],
                ),
                const SizedBox(height: 32),
                const Text("Ingredientes",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                // Ingredients List
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: ListView.separated(
                      itemCount: ingredientes.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 16, color: Colors.black12),
                      itemBuilder: (ctx, idx) {
                        final i = ingredientes[idx];
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_circle_outline,
                                  color: primaryColor, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                i["nombre"] ?? "Ingrediente desconocido",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                            ),
                            Text(
                              "${i["cantidad"] ?? ""} ${i["unidad"] ?? ""}",
                              style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500),
                            )
                          ],
                        );
                      },
                    ),
                  ),
                ),
                // Action Button (if selectable)
                if (widget.onSelect != null) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.onSelect,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        "Seleccionar esta receta",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroCard(
      IconData icon, String title, String value, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade100),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(color: color.shade700, fontSize: 12)),
                Text(value,
                    style: TextStyle(
                        color: color.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
