import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';

class TutorRecetaDetallePage extends ConsumerStatefulWidget {
  final int idReceta;
  const TutorRecetaDetallePage({super.key, required this.idReceta});

  @override
  ConsumerState<TutorRecetaDetallePage> createState() => _TutorRecetaDetallePageState();
}

class _TutorRecetaDetallePageState extends ConsumerState<TutorRecetaDetallePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _receta;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('crud/recetas/${widget.idReceta}');
      if (mounted) {
        setState(() {
          _receta = resp.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar receta: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_receta == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("No se pudo cargar la información de la receta.")),
      );
    }

    final r = _receta!;
    final String url = r['imagen_url'] ?? "";

    return Scaffold(
      bottomNavigationBar: _buildBottomTabs(colorScheme),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(r, url, colorScheme),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chips de resumen
                    _buildSummarySection(r),
                    const SizedBox(height: 32),
                    
                    // Descripción Larga
                    Text(
                      "Sobre esta receta",
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      (r['descripcion_larga'] != null && r['descripcion_larga'].toString().isNotEmpty)
                          ? r['descripcion_larga']
                          : (r['descripcion'] ?? "Sin descripción disponible."),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade700, 
                        height: 1.6,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildIngredientesTab(r),
            _buildPreparacionTab(r),
            _buildNutricionTab(r),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> r, String url, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppTema.azulOscuro,
      surfaceTintColor: AppTema.azulOscuro,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 20), // Evita solapamiento con el botón atrás
        title: Text(
          r['nombre'] ?? 'Receta',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
            shadows: [const Shadow(blurRadius: 8, color: Colors.black)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isNotEmpty)
              Image.network(url, fit: BoxFit.cover)
            else
              Container(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(Icons.restaurant, size: 80, color: colorScheme.onSurfaceVariant.withOpacity(0.3)),
              ),
            // Gradiente oscuro para legibilidad (más intenso)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTabs(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.primary,
            ),
            dividerColor: Colors.transparent,
            labelColor: colorScheme.onPrimary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(text: "Ingredientes"),
              Tab(text: "Preparación"),
              Tab(text: "Nutrición"),
            ],          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(Map<String, dynamic> r) {
    // Uso de la nueva columna pre-calculada en DB con fallback manual por seguridad
    final int tTotal = r['tiempo_total_min'] ?? 
                      ((r['tiempo_preparacion_min'] ?? r['tiempo_preparacion'] ?? 0) + 
                       (r['tiempo_coccion_min'] ?? r['tiempo_coccion'] ?? 0));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.people_outline, "${r['porciones'] ?? 1}", "Porciones"),
          _buildStatItem(Icons.timer_outlined, "$tTotal min", "Tiempo"),
          _buildStatItem(Icons.local_fire_department_outlined, "${r['calorias_por_porcion'] ?? 0}", "Kcal"),
          _buildStatItem(Icons.bar_chart_rounded, r['dificultad'] ?? "Media", "Dificultad"),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTema.azulPrincipal, size: 22),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildNutricionTab(Map<String, dynamic> r) {
    final double prot = (r['proteinas_totales'] ?? 0).toDouble();
    final double carb = (r['carbohidratos_totales'] ?? 0).toDouble();
    final double fat = (r['grasas_totales'] ?? 0).toDouble();
    final double total = prot + carb + fat;
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Comparativa de Macronutrientes', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppTema.azulOscuro)),
        const SizedBox(height: 24),
        
        _buildProgressBar('Proteínas', total > 0 ? prot / total : 0, AppTema.azulPrincipal, '${prot}g'),
        const SizedBox(height: 16),
        _buildProgressBar('Carbohidratos', total > 0 ? carb / total : 0, Colors.orange, '${carb}g'),
        const SizedBox(height: 16),
        _buildProgressBar('Grasas', total > 0 ? fat / total : 0, Colors.redAccent, '${fat}g'),
        
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        
        _buildNutriRow("Energía Total", "${r['calorias_totales'] ?? 0} kcal"),
        _buildNutriRow("Fibra", "${r['fibra_totales'] ?? 0}g"),
        _buildNutriRow("Peso Estimado", "${r['peso_total'] ?? 0} g"),
      ],
    );
  }

  Widget _buildProgressBar(String label, double percent, Color color, String value) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
            Text(value, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percent,
          minHeight: 10,
          backgroundColor: const Color(0xFFF1F5F9),
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }

  Widget _buildNutriRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTema.azulOscuro)),
        ],
      ),
    );
  }

  Widget _buildIngredientesTab(Map<String, dynamic> r) {
    final List<dynamic> ing = r['ingredientes'] ?? [];
    if (ing.isEmpty) return const Center(child: Text("No hay ingredientes registrados."));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: ing.length,
      itemBuilder: (context, index) {
        final i = ing[index];
        return Card(
          elevation: 0,
          color: Colors.grey.shade50,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: AppTema.verdeSalud, size: 20),
            title: Text(i['nombre'] ?? "-", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            trailing: Text(
              "${i['cantidad']} ${i['unidad']}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTema.azulPrincipal),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreparacionTab(Map<String, dynamic> r) {
    final List<dynamic> pasos = r['preparacion'] ?? [];
    if (pasos.isEmpty) return const Center(child: Text("No hay instrucciones registradas."));

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: pasos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final p = pasos[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(color: AppTema.azulPrincipal, shape: BoxShape.circle),
              child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Paso ${index + 1}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppTema.azulOscuro)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p['descripcion'] ?? "-",
                    style: GoogleFonts.montserrat(fontSize: 14, color: Colors.blueGrey.shade700, height: 1.5),
                  ),
                  if (p['nota'] != null && p['nota'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTema.verdeSalud.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTema.verdeSalud.withOpacity(0.1))),
                      child: Text(
                        'Nota: ${p['nota']}',
                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: AppTema.verdeSalud, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
