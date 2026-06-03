import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_responsive.dart';

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
  bool _isActionLoading = false;
  int _userRating = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('tutor/receta-detalle/${widget.idReceta}', queryParameters: {
        'id_paciente': idPaciente,
      });
      if (mounted) {
        setState(() {
          _receta = resp.data;
          _userRating = (_receta!['calificacion_personal'] ?? 0).toInt();
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

  Future<void> _toggleConsumida() async {
    if (_receta == null || _receta!['en_plan_hoy'] != true) return;
    
    final idPlanItem = _receta!['id_plan_item_hoy'];
    final bool currentStatus = _receta!['consumida_hoy'] == true;
    
    setState(() => _isActionLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('tutor/marcar-consumida', data: {
        "id_plan_item": idPlanItem,
        "consumida": !currentStatus,
      });
      
      setState(() {
        _receta!['consumida_hoy'] = !currentStatus;
      });
      ref.invalidate(planDiarioProvider);
    } catch (e) {
      debugPrint("Error marcando consumo: $e");
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
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
      bottomNavigationBar: _buildBottomTabs(context, colorScheme),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(context, r, url, colorScheme),
            SliverToBoxAdapter(
              child: ResponsiveMaxConstraints(
                child: Padding(
                  padding: EdgeInsets.all(context.responsiveSpacing(AppSpacing.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummarySection(context, r),
                      const SizedBox(height: 24),
                      
                      if (r['en_plan_hoy'] == true) ...[
                        _buildConsumidaSection(context, r),
                        const SizedBox(height: 24),
                      ],

                      _buildRatingSection(context, theme, r['id']),
                      const SizedBox(height: 32),
                      
                      Text(
                        "Sobre esta receta",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: AppTextSizes.title(context.screenWidth)
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        r['descripcion'] ?? "Sin descripción disponible.",
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade700, 
                          height: 1.6,
                          fontSize: AppTextSizes.body(context.screenWidth),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: ResponsiveMaxConstraints(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildIngredientesTab(context, r),
              _buildPreparacionTab(context, r),
              _buildNutricionTab(context, r),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsumidaSection(BuildContext context, Map<String, dynamic> r) {
    final bool isConsumida = r['consumida_hoy'] == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConsumida ? AppTema.verdeSalud.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isConsumida ? AppTema.verdeSalud.withOpacity(0.3) : Colors.grey.shade200),
        boxShadow: isConsumida ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isConsumida ? AppTema.verdeSalud : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConsumida ? Icons.check_rounded : Icons.restaurant_rounded,
              color: isConsumida ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Plan de Hoy",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTextSizes.bodySmall(context.screenWidth),
                    color: AppTema.azulOscuro,
                  ),
                ),
                Text(
                  isConsumida ? "Consumida" : "¿Ya la preparaste?",
                  style: TextStyle(
                    fontSize: AppTextSizes.caption(context.screenWidth),
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            height: 40,
            child: FilledButton.tonal(
              onPressed: _isActionLoading ? null : _toggleConsumida,
              style: FilledButton.styleFrom(
                backgroundColor: isConsumida ? Colors.grey.shade100 : AppTema.verdeSalud,
                foregroundColor: isConsumida ? Colors.grey.shade700 : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isActionLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                  : Text(isConsumida ? "Desmarcar" : "Marcar", style: TextStyle(fontSize: AppTextSizes.caption(context.screenWidth), fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context, ThemeData theme, int recetaId) {
    final double promedio = double.tryParse(_receta!['puntuacion_promedio']?.toString() ?? "0") ?? 0;
    final int total = _receta!['total_evaluaciones'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTema.verdeSalud.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTema.verdeSalud.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "¿Qué te pareció?",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700, 
                  fontSize: AppTextSizes.bodySmall(context.screenWidth), 
                  color: AppTema.azulOscuro
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "$promedio",
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: AppTextSizes.bodySmall(context.screenWidth)
                    ),
                  ),
                  Text(
                    " ($total)",
                    style: TextStyle(
                      color: Colors.grey.shade500, 
                      fontSize: AppTextSizes.caption(context.screenWidth)
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                onPressed: () => _handleRating(starValue, recetaId),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                icon: Icon(
                  starValue <= _userRating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: context.responsiveValue(mobile: 32, tablet: 40),
                  color: starValue <= _userRating ? Colors.amber : Colors.amber.withOpacity(0.3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRating(int rating, int recetaId) async {
    setState(() => _userRating = rating);
    if (rating <= 2) {
      _showFeedbackDialog(rating, recetaId);
    } else {
      _submitRating(rating, recetaId, null, null);
    }
  }

  Future<void> _showFeedbackDialog(int stars, int recetaId) async {
    final dio = ref.read(dioProvider);
    List<dynamic> motivos = [];
    try {
      final resp = await dio.get('tutor/motivos-rechazo');
      motivos = resp.data;
    } catch (e) {
      debugPrint("Error cargando motivos: $e");
    }

    if (!mounted) return;

    int? selectedMotivoId;
    final commentController = TextEditingController();
    bool showOtherField = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Ayúdanos a mejorar", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Lamentamos que no te haya gustado. ¿Podrías indicarnos el motivo?"),
                const SizedBox(height: 16),
                ...motivos.map((m) => RadioListTile<int>(
                  title: Text(m['nombre'], style: const TextStyle(fontSize: 14)),
                  value: m['id'],
                  groupValue: selectedMotivoId,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() {
                      selectedMotivoId = val;
                      showOtherField = m['nombre'].toString().toLowerCase().contains("otro");
                    });
                  },
                )),
                if (showOtherField)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        hintText: "Describe el motivo...",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _userRating = 0);
                Navigator.pop(context);
              }, 
              child: const Text("Cancelar")
            ),
            FilledButton(
              onPressed: selectedMotivoId == null ? null : () {
                Navigator.pop(context);
                _submitRating(stars, recetaId, selectedMotivoId, commentController.text);
              },
              child: const Text("Enviar"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(int stars, int recetaId, int? motivoId, String? comentario) async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    if (idPaciente == null) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.post('tutor/evaluar-receta', data: {
        "id_paciente": idPaciente,
        "id_receta": recetaId,
        "estrellas": stars,
        "id_motivo_rechazo": motivoId,
        "comentario": comentario,
      });
      
      _cargarDetalle(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Gracias por tu evaluación!"), backgroundColor: AppTema.verdeSalud),
        );
      }
    } catch (e) {
      debugPrint("Error enviando evaluación: $e");
    }
  }

  Widget _buildSliverAppBar(BuildContext context, Map<String, dynamic> r, String url, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: context.responsiveValue(mobile: 280, tablet: 400),
      pinned: true,
      backgroundColor: AppTema.azulOscuro,
      surfaceTintColor: AppTema.azulOscuro,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 20),
        title: Text(
          r['nombre'] ?? 'Receta',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: AppTextSizes.title(context.screenWidth),
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
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.black87],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTabs(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveSpacing(AppSpacing.md), 
        vertical: context.responsiveSpacing(AppSpacing.sm)
      ),
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
            labelStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold, 
              fontSize: context.responsiveValue(mobile: 12, tablet: 14)
            ),
            tabs: const [
              Tab(text: "Ingredientes"),
              Tab(text: "Preparación"),
              Tab(text: "Nutrición"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, Map<String, dynamic> r) {
    final int tTotal = r['tiempo_total_min'] ??
                      ((r['tiempo_preparacion_min'] ?? r['tiempo_preparacion'] ?? 0) +
                       (r['tiempo_coccion_min'] ?? r['tiempo_coccion'] ?? 0));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: context.responsiveSpacing(AppSpacing.md), 
        horizontal: context.responsiveSpacing(AppSpacing.sm)
      ),
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
          _buildStatItem(context, Icons.people_outline, "${r['porciones'] ?? 1}", "Porciones"),
          _buildStatItem(context, Icons.timer_outlined, "$tTotal min", "Tiempo"),
          _buildStatItem(context, Icons.local_fire_department_rounded, "${r['calorias_kcal'] ?? r['calorias_totales'] ?? 0}", "Kcal"),
          _buildStatItem(context, Icons.bar_chart_rounded, r['dificultad'] ?? "Media", "Dificultad"),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Icon(icon, color: AppTema.azulPrincipal, size: context.responsiveValue(mobile: 22, tablet: 28)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: AppTextSizes.body(context.screenWidth))),
          Text(label, style: TextStyle(color: Colors.grey, fontSize: AppTextSizes.caption(context.screenWidth), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNutricionTab(BuildContext context, Map<String, dynamic> r) {
    final double prot = (r['proteinas_totales'] ?? 0).toDouble();
    final double carb = (r['carbohidratos_totales'] ?? 0).toDouble();
    final double fat = (r['grasas_totales'] ?? 0).toDouble();
    final double total = prot + carb + fat;
    
    return ListView(
      padding: EdgeInsets.all(context.responsiveSpacing(AppSpacing.lg)),
      children: [
        Text('Comparativa de Macronutrientes', 
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800, 
            fontSize: AppTextSizes.bodyLarge(context.screenWidth), 
            color: AppTema.azulOscuro
          )),
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

  Widget _buildIngredientesTab(BuildContext context, Map<String, dynamic> r) {
    final List<dynamic> ing = r['ingredientes'] ?? [];
    if (ing.isEmpty) return const Center(child: Text("No hay ingredientes registrados."));

    return ListView.builder(
      padding: EdgeInsets.all(context.responsiveSpacing(AppSpacing.lg)),
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
            title: Text(i['nombre'] ?? "-", 
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                fontSize: AppTextSizes.body(context.screenWidth)
              )),
            trailing: Text(
              "${i['cantidad']} ${i['unidad']}",
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: AppTema.azulPrincipal,
                fontSize: AppTextSizes.bodySmall(context.screenWidth)
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreparacionTab(BuildContext context, Map<String, dynamic> r) {
    final List<dynamic> pasos = r['preparacion'] ?? [];
    if (pasos.isEmpty) return const Center(child: Text("No hay instrucciones registradas."));

    return ListView.separated(
      padding: EdgeInsets.all(context.responsiveSpacing(AppSpacing.lg)),
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
                  Text('Paso ${index + 1}', 
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800, 
                      fontSize: AppTextSizes.body(context.screenWidth), 
                      color: AppTema.azulOscuro
                    )),
                  const SizedBox(height: 8),
                  Text(
                    p['descripcion'] ?? "-",
                    style: GoogleFonts.montserrat(
                      fontSize: AppTextSizes.body(context.screenWidth), 
                      color: Colors.blueGrey.shade700, 
                      height: 1.5
                    ),
                  ),
                  if (p['nota'] != null && p['nota'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTema.verdeSalud.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTema.verdeSalud.withOpacity(0.1))),
                      child: Text(
                        'Nota: ${p['nota']}',
                        style: GoogleFonts.montserrat(
                          fontSize: AppTextSizes.bodySmall(context.screenWidth), 
                          fontWeight: FontWeight.w600, 
                          color: AppTema.verdeSalud, 
                          fontStyle: FontStyle.italic
                        ),
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
