import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import 'tutor_receta_detalle_page.dart';

class TutorRecetasPage extends ConsumerStatefulWidget {
  const TutorRecetasPage({super.key});

  @override
  ConsumerState<TutorRecetasPage> createState() => _TutorRecetasPageState();
}

class _TutorRecetasPageState extends ConsumerState<TutorRecetasPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  int? _selectedMomentoId;
  List<Map<String, dynamic>> _recetas = [];
  List<Map<String, dynamic>> _momentos = [];
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 15;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _cargarDatosIniciales());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _cargarMasRecetas();
      }
    }
  }

  Future<void> _cargarDatosIniciales() async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    if (idPaciente == null) return;

    setState(() { _isLoading = true; _recetas.clear(); _offset = 0; _hasMore = true; });

    try {
      final dio = ref.read(dioProvider);
      
      // 1. Cargar Momentos
      final respMom = await dio.get('crud/momentos');
      _momentos = List<Map<String, dynamic>>.from(respMom.data);

      // 2. Cargar Primera Página de Recetas
      await _cargarPagina(idPaciente);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error inicial: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarMasRecetas() async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    if (idPaciente == null) return;

    setState(() => _isLoadingMore = true);
    _offset += _limit;
    await _cargarPagina(idPaciente);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _cargarPagina(String idPaciente) async {
    final dio = ref.read(dioProvider);
    final resp = await dio.post('recetas-permitidas', data: {
      "id_paciente": idPaciente,
      "id_momento": _selectedMomentoId,
      "consulta": _searchController.text.trim(),
      "limite": _limit,
      "offset": _offset
    });
    
    final List<Map<String, dynamic>> nuevas = List<Map<String, dynamic>>.from(resp.data['recetas'] ?? []);
    
    if (mounted) {
      setState(() {
        _recetas.addAll(nuevas);
        if (nuevas.length < _limit) _hasMore = false;
      });
    }
  }

  void _cambiarFiltro(int? id) {
    setState(() => _selectedMomentoId = id);
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header Fijo (Buscador y Filtros)
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          color: colorScheme.surface,
          child: Column(
            children: [
              SearchBar(
                controller: _searchController,
                hintText: "Buscar recetas seguras...",
                leading: const Icon(Icons.search),
                onSubmitted: (_) => _cargarDatosIniciales(),
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest.withOpacity(0.3)),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("Todas", null),
                    ..._momentos.map((m) => _buildFilterChip(m['nombre'], m['id'])),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Lista Scrollable con Paginación
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _recetas.isEmpty 
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      child: _RecipeCard(
                        receta: r,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TutorRecetaDetallePage(idReceta: r['id'])),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int? id) {
    final isSelected = _selectedMomentoId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _cambiarFiltro(id),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("No se encontraron recetas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
    final String semaforo = receta['semaforo'] ?? 'neutral';
    
    Color statusColor = const Color(0xFF64748B);
    IconData statusIcon = Icons.check_circle_outline_rounded;
    if (semaforo == 'verde') { statusColor = AppTema.verdeSalud; statusIcon = Icons.verified_user_rounded; }
    else if (semaforo == 'amarillo') { statusColor = Colors.orange; statusIcon = Icons.info_outline_rounded; }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: statusColor.withOpacity(0.2), width: 1.5)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 160, width: double.infinity, color: const Color(0xFFF1F5F9),
                  child: url.isNotEmpty
                      ? Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.restaurant, size: 48, color: Colors.grey))
                      : const Icon(Icons.restaurant, size: 48, color: Colors.grey),
                ),
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text("${receta['puntuacion_promedio'] ?? '0'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text(" (${receta['total_evaluaciones'] ?? '0'})", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(receta['clasificacion_recomendacion']?.toString().toUpperCase() ?? "SEGURA", style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: statusColor, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(receta['nombre'] ?? "Sin nombre", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                    child: Text(receta['mensaje_regla'] ?? "Segura para el paciente", style: theme.textTheme.bodySmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMeta(context, Icons.timer_outlined, "${receta['tiempo_total_min'] ?? 0} min"),
                      _buildMeta(context, Icons.local_fire_department_outlined, "${receta['calorias_por_porcion'] ?? 0} kcal"),
                      _buildMeta(context, Icons.auto_graph_rounded, receta['dificultad'] ?? "Media"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeta(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
      ],
    );
  }
}
