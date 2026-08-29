import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_responsive.dart';
import '../data/seguimiento_provider.dart';
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

  String? _lastLoadedId;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    final idPaciente = ref.watch(selectedPatientIdProvider);

    final momentosAsync = ref.watch(momentosComidaProvider);
    final tiposPlatoAsync = ref.watch(tiposPlatoProvider);
    final recetasInicialesAsync = idPaciente != null
        ? ref.watch(recetasSegurasInicialesProvider(idPaciente))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    _momentos =
        momentosAsync.maybeWhen(data: (d) => d, orElse: () => _momentos);
    _tiposPlato =
        tiposPlatoAsync.maybeWhen(data: (d) => d, orElse: () => _tiposPlato);

    if (_lastLoadedId != idPaciente && idPaciente != null) {
      recetasInicialesAsync.whenData((data) {
        if (_searchController.text.isEmpty &&
            _idMomento == null &&
            _idTipoPlato == null) {
          _recetas = List<Map<String, dynamic>>.from(data);
          _offset = 20;
          _hasMore = data.length == 20;
          _isLoading = false;
          _lastLoadedId = idPaciente;
        }
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          _buildSearchAndFilters(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (idPaciente != null) {
                  setState(() => _isLoading = true);
                  ref.invalidate(momentosComidaProvider);
                  ref.invalidate(tiposPlatoProvider);
                  ref.invalidate(recetasSegurasInicialesProvider(idPaciente));
                  _lastLoadedId = null;
                  await _cargarDatosIniciales();
                }
              },
              child: _isLoading
                  ? _buildRecetasShimmer(context)
                  : _recetas.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 400,
                            alignment: Alignment.center,
                            child: _buildEmptyState(),
                          ),
                        )
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
          ),
        ],
      ),
    );
  }

  Widget _buildRecetasShimmer(BuildContext context) {
    final double cardHeight =
        context.responsiveValue(mobile: 136.0, tablet: 156.0);
    final double imageWidth =
        context.responsiveValue(mobile: 125.0, tablet: 155.0);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveSpacing(AppSpacing.md),
        vertical: AppSpacing.sm,
      ),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE2E8F0),
        highlightColor: const Color(0xFFF8FAFC),
        child: Column(
          children: List.generate(5, (index) {
            return Container(
              height: cardHeight,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: imageWidth,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.horizontal(left: Radius.circular(19)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            context.responsiveSpacing(AppSpacing.md),
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 130,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 180,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 52,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
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
    final bool isMomento = title.toLowerCase().contains("momento");
    final IconData headerIcon = isMomento
        ? Icons.access_time_filled_rounded
        : Icons.restaurant_menu_rounded;
    final Color accentColor =
        isMomento ? AppTema.azulPrincipal : const Color(0xFFEA580C);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tirador central
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Cabecera del modal con icono y título
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(headerIcon, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isMomento
                                ? "Filtra recetas por momento del día"
                                : "Filtra recetas por categoría de plato",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                // Lista de opciones
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Opción: Mostrar todos
                      _buildFilterOptionCard(
                        context: context,
                        title: isMomento
                            ? "Cualquier momento"
                            : "Todos los platos",
                        icon: Icons.all_inclusive_rounded,
                        isSelected: currentVal == null,
                        accentColor: accentColor,
                        onTap: () {
                          onSelected(null);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 10),
                      // Opciones dinámicas
                      ...options.map((opt) {
                        final bool isSelected = currentVal == opt['id'];
                        final String nombre = opt['nombre'] ?? "";
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildFilterOptionCard(
                            context: context,
                            title: nombre,
                            icon: _getFilterOptionIcon(title, nombre),
                            isSelected: isSelected,
                            accentColor: accentColor,
                            onTap: () {
                              onSelected(opt['id']);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOptionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withOpacity(0.15)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? accentColor : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? accentColor : const Color(0xFF334155),
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: accentColor,
                size: 22,
              )
            else
              const Icon(
                Icons.radio_button_off_rounded,
                color: Color(0xFFCBD5E1),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getFilterOptionIcon(String filterType, String nombre) {
    final n = nombre.toLowerCase();
    if (filterType.toLowerCase().contains("momento")) {
      if (n.contains("desayuno")) return Icons.coffee_rounded;
      if (n.contains("almuerzo")) return Icons.restaurant_rounded;
      if (n.contains("merienda") || n.contains("cena")) {
        return Icons.nights_stay_rounded;
      }
      if (n.contains("mañana")) return Icons.wb_sunny_rounded;
      if (n.contains("tarde")) return Icons.wb_twilight_rounded;
      return Icons.access_time_rounded;
    } else {
      if (n.contains("sopa") || n.contains("crema") || n.contains("caldo")) {
        return Icons.soup_kitchen_rounded;
      }
      if (n.contains("fuerte") ||
          n.contains("principal") ||
          n.contains("segundo")) {
        return Icons.dinner_dining_rounded;
      }
      if (n.contains("ensalada") || n.contains("verde")) {
        return Icons.eco_rounded;
      }
      if (n.contains("postre") || n.contains("dulce")) {
        return Icons.icecream_rounded;
      }
      if (n.contains("bebida") ||
          n.contains("jugo") ||
          n.contains("infusion") ||
          n.contains("agua")) {
        return Icons.local_cafe_rounded;
      }
      if (n.contains("snack") ||
          n.contains("colacion") ||
          n.contains("merienda")) {
        return Icons.fastfood_rounded;
      }
      return Icons.restaurant_menu_rounded;
    }
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

    final double cardHeight =
        context.responsiveValue(mobile: 136.0, tablet: 156.0);
    final double imageWidth =
        context.responsiveValue(mobile: 125.0, tablet: 155.0);

    return SizedBox(
      height: cardHeight,
      child: Card(
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.04),
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Contenedor de imagen fija con altura completa
              SizedBox(
                width: imageWidth,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF1F5F9),
                      child: url.isNotEmpty
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Center(
                                child: Icon(Icons.restaurant_rounded,
                                    color: Color(0xFF94A3B8), size: 36),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.restaurant_rounded,
                                  color: Color(0xFF94A3B8), size: 36),
                            ),
                    ),
                    if (rating > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFBBF24), size: 13),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Contenido informativo distribuido de manera uniforme
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.responsiveSpacing(AppSpacing.md),
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Encabezado: Título y descripción
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            receta['nombre'] ?? "Sin nombre",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              height: 1.2,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (receta['descripcion'] != null &&
                                    receta['descripcion']
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                ? receta['descripcion'].toString().trim()
                                : "Receta balanceada y segura para el paciente",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                      // Pie de tarjeta: Etiquetas informativas
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildBadge(
                              context,
                              Icons.local_fire_department_rounded,
                              "${(receta['calorias_por_porcion'] ?? receta['calorias_kcal'] ?? receta['calorias_totales'] ?? 0).toInt()} kcal",
                              const Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 8),
                            _buildBadge(
                              context,
                              Icons.timer_outlined,
                              "${receta['tiempo_total_min'] ?? ((receta['tiempo_preparacion_min'] ?? receta['tiempo_preparacion'] ?? 0) + (receta['tiempo_coccion_min'] ?? receta['tiempo_coccion'] ?? 0))} min",
                              AppTema.azulPrincipal,
                            ),
                            const SizedBox(width: 8),
                            _buildBadge(
                              context,
                              Icons.bar_chart_rounded,
                              "${receta['dificultad'] ?? 'Media'}",
                              AppTema.verdeSalud,
                            ),
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
      ),
    );
  }

  Widget _buildBadge(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
