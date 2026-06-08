import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_responsive.dart';
import 'tutor_receta_detalle_page.dart';

class TutorRecetasPage extends ConsumerStatefulWidget {
  const TutorRecetasPage({super.key});

  @override
  ConsumerState<TutorRecetasPage> createState() => _TutorRecetasPageState();
}

class _TutorRecetasPageState extends ConsumerState<TutorRecetasPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _recetas = [];
  List<Map<String, dynamic>> _momentos = [];
  List<Map<String, dynamic>> _tiposPlato = [];

  int? _idMomento;
  int? _idTipoPlato;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
    _cargarDatosIniciales();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get('tutor/momentos-comida'),
        dio.get('tutor/tipos-plato'),
      ]);
      if (mounted) {
        setState(() {
          _momentos = List<Map<String, dynamic>>.from(results[0].data);
          _tiposPlato = List<Map<String, dynamic>>.from(results[1].data);
        });
      }
    } catch (e) {
      debugPrint("Error cargando catálogos: $e");
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _cargarMasRecetas();
      }
    }
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() {
      _isLoading = true;
      _offset = 0;
      _recetas = [];
      _hasMore = true;
    });
    await _cargarRecetas();
  }

  Future<void> _cargarMasRecetas() async {
    setState(() => _isLoadingMore = true);
    await _cargarRecetas();
    setState(() => _isLoadingMore = false);
  }

  Future<void> _cargarRecetas() async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    if (idPaciente == null) return;

    try {
      final dio = ref.read(dioProvider);

      final queryParams = {
        'consulta': _searchController.text,
        'limite': _limit,
        'offset': _offset,
      };

      if (_idMomento != null) queryParams['id_momento'] = _idMomento!;
      if (_idTipoPlato != null) queryParams['id_tipo_plato'] = _idTipoPlato!;

      final resp = await dio.get('tutor/recetas-seguras/$idPaciente',
          queryParameters: queryParams);

      final List<dynamic> nuevas = resp.data;
      if (mounted) {
        setState(() {
          _recetas.addAll(List<Map<String, dynamic>>.from(nuevas));
          _offset += _limit;
          _hasMore = nuevas.length == _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando recetas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          _buildSearchAndFilters(context),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recetas.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                            horizontal:
                                context.responsiveSpacing(AppSpacing.md),
                            vertical: AppSpacing.sm),
                        itemCount: _recetas.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _recetas.length) {
                            return const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final r = _recetas[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ResponsiveMaxConstraints(
                              maxWidth: 800,
                              child: _RecipeCard(
                                receta: r,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          TutorRecetaDetallePage(
                                              idReceta: r['id'])),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          context.responsiveSpacing(AppSpacing.md),
          context.responsiveSpacing(AppSpacing.md),
          context.responsiveSpacing(AppSpacing.md),
          AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ResponsiveMaxConstraints(
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onSubmitted: (v) => _cargarDatosIniciales(),
              decoration: InputDecoration(
                hintText: "Buscar recetas seguras...",
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _cargarDatosIniciales();
                        })
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: _idMomento == null
                        ? "Cualquier momento"
                        : _momentos
                            .firstWhere((m) => m['id'] == _idMomento)['nombre'],
                    icon: Icons.access_time_rounded,
                    onTap: () => _showFilterPicker(
                        "Momento de comida", _momentos, _idMomento, (val) {
                      setState(() => _idMomento = val);
                      _cargarDatosIniciales();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: _idTipoPlato == null
                        ? "Todos los platos"
                        : _tiposPlato.firstWhere(
                            (t) => t['id'] == _idTipoPlato)['nombre'],
                    icon: Icons.restaurant_menu_rounded,
                    onTap: () => _showFilterPicker(
                        "Tipo de plato", _tiposPlato, _idTipoPlato, (val) {
                      setState(() => _idTipoPlato = val);
                      _cargarDatosIniciales();
                    }),
                  ),
                  if (_idMomento != null || _idTipoPlato != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _idMomento = null;
                          _idTipoPlato = null;
                        });
                        _cargarDatosIniciales();
                      },
                      icon: const Icon(Icons.filter_alt_off_rounded,
                          color: Colors.redAccent, size: 20),
                      tooltip: "Limpiar filtros",
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    final bool isActive =
        !label.contains("Cualquier") && !label.contains("Todos");
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTema.azulPrincipal.withOpacity(0.1)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive
                  ? AppTema.azulPrincipal.withOpacity(0.2)
                  : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color:
                    isActive ? AppTema.azulPrincipal : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color:
                    isActive ? AppTema.azulPrincipal : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _showFilterPicker(String title, List<Map<String, dynamic>> options,
      int? currentVal, Function(int?) onSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(title,
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text("Mostrar todos"),
                  leading: const Icon(Icons.all_inclusive_rounded),
                  selected: currentVal == null,
                  onTap: () {
                    onSelected(null);
                    Navigator.pop(context);
                  },
                ),
                ...options.map((opt) => ListTile(
                      title: Text(opt['nombre']),
                      selected: currentVal == opt['id'],
                      onTap: () {
                        onSelected(opt['id']);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No se encontraron recetas seguras",
              style:
                  TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Map<String, dynamic> receta;
  final VoidCallback onTap;

  const _RecipeCard({required this.receta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String url = receta['imagen_url'] ?? "";
    final double rating =
        double.tryParse(receta['puntuacion_promedio']?.toString() ?? "0") ?? 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.responsiveValue(mobile: 110, tablet: 150),
              height: context.responsiveValue(mobile: 110, tablet: 150),
              color: const Color(0xFFF1F5F9),
              child: url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover)
                  : const Icon(Icons.restaurant, color: Colors.grey),
            ),
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.all(context.responsiveSpacing(AppSpacing.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receta['nombre'] ?? "Sin nombre",
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize:
                              AppTextSizes.bodyLarge(context.screenWidth)),
                    ),
                    const SizedBox(height: 6),
                    if (receta['descripcion'] != null)
                      Text(
                        receta['descripcion'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppTextSizes.caption(context.screenWidth),
                            color: const Color(0xFF64748B),
                            height: 1.3),
                      ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildBadge(
                              context,
                              Icons.local_fire_department_rounded,
                              "${(receta['calorias_por_porcion'] ?? receta['calorias_kcal'] ?? receta['calorias_totales'] ?? 0).toInt()} kcal",
                              Colors.orange),
                          const SizedBox(width: 12),
                          _buildBadge(
                              context,
                              Icons.timer_outlined,
                              "${receta['tiempo_total_min'] ?? ((receta['tiempo_preparacion_min'] ?? receta['tiempo_preparacion'] ?? 0) + (receta['tiempo_coccion_min'] ?? receta['tiempo_coccion'] ?? 0))} min",
                              AppTema.azulPrincipal),
                          const SizedBox(width: 12),
                          _buildBadge(
                              context,
                              Icons.bar_chart_rounded,
                              "${receta['dificultad'] ?? 'Media'}",
                              AppTema.verdeSalud),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
      BuildContext context, IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: AppTextSizes.caption(context.screenWidth),
                color: const Color(0xFF475569),
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
