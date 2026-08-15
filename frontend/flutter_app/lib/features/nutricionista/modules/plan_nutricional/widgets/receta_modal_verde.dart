import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/state/app_providers.dart';

Future<void> mostrarDetalleRecetaVerde(
  BuildContext context,
  int idReceta,
  WidgetRef ref, {
  VoidCallback? onSelect,
}) async {
  if (idReceta <= 0) return;

  showDialog(
    context: context,
    barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
    builder: (ctx) => _ModalRecetaContenido(
      idReceta: idReceta,
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

  const _ModalRecetaContenido({required this.idReceta, this.onSelect});

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
      final res = await dio.get("crud/recetas/${widget.idReceta}");
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
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
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
                    const Icon(Icons.local_dining, color: Colors.green, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receta!["nombre"] ?? "Receta sin nombre",
                            style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.blueGrey.shade900),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Detalles Nutricionales",
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13),
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
                      color: Colors.green.shade50.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade100),
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
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.eco,
                                  color: Colors.green, size: 16),
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
                        backgroundColor: Colors.green.shade600,
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
