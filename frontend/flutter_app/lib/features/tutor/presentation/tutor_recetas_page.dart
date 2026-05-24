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
  int? _selectedMomentoId; // null para "Todas"
  List<Map<String, dynamic>> _recetasOriginales = [];
  List<Map<String, dynamic>> _recetasFiltradas = [];
  List<Map<String, dynamic>> _momentos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _cargarDatos());
  }

  Future<void> _cargarDatos() async {
    final idPaciente = ref.read(selectedPatientIdProvider);
    if (idPaciente == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      
      // 1. Cargar Momentos para los filtros
      final respMom = await dio.get('crud/momentos');
      _momentos = List<Map<String, dynamic>>.from(respMom.data);

      // 2. Cargar Recetas Seguras (Algoritmo KBRS)
      // El backend ya tiene un endpoint /recetas-permitidas que aplica las reglas de seguridad
      final respRec = await dio.post('recetas-permitidas', data: {
        "id_paciente": idPaciente,
        "id_momento": null, // Traer todas las seguras inicialmente
        "id_tipo_plato": null
      });
      
      _recetasOriginales = List<Map<String, dynamic>>.from(respRec.data['recetas'] ?? []);
      _recetasFiltradas = List.from(_recetasOriginales);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error cargando recetas seguras: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _aplicarFiltros() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _recetasFiltradas = _recetasOriginales.where((r) {
        // Filtro por texto (Nombre de receta)
        final String nombre = (r['nombre'] ?? '').toString().toLowerCase();
        final bool coincideBusqueda = query.isEmpty || nombre.contains(query);

        // Filtro por Categoría (Momento de comida)
        // Ahora el backend devuelve 'momentos_ids' como una lista [1, 3, 5]
        final List<dynamic> momentosIds = r['momentos_ids'] ?? [];
        final bool coincideMomento = _selectedMomentoId == null || 
                                    momentosIds.contains(_selectedMomentoId);
        
        return coincideBusqueda && coincideMomento;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // SEARCH BAR
          SearchBar(
            controller: _searchController,
            hintText: "Buscar recetas seguras...",
            leading: const Icon(Icons.search),
            trailing: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _aplicarFiltros();
                  },
                ),
            ],
            onChanged: (_) => _aplicarFiltros(),
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest.withOpacity(0.3)),
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
          ),
          const SizedBox(height: 24),
          
          // CATEGORY FILTERS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, "Todas", null),
                ..._momentos.map((m) => _buildFilterChip(context, m['nombre'], m['id'])),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          if (_recetasFiltradas.isEmpty)
            _buildEmptyState()
          else
            ..._recetasFiltradas.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _RecipeCard(
                receta: r,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TutorRecetaDetallePage(idReceta: r['id'])),
                ),
              ),
            )),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, int? id) {
    final isSelected = _selectedMomentoId == id;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() => _selectedMomentoId = id);
          _aplicarFiltros();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("No se encontraron recetas seguras", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const Text("Intenta con otro filtro o término", style: TextStyle(color: Colors.grey)),
          ],
        ),
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
    final colorScheme = theme.colorScheme;
    final String url = receta['imagen_url'] ?? "";

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              color: const Color(0xFFF1F5F9),
              child: url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.restaurant, size: 48, color: Colors.grey))
                  : const Icon(Icons.restaurant, size: 48, color: Colors.grey),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          receta['nombre'] ?? "Sin nombre",
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTema.verdeSalud.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: AppTema.verdeSalud, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              "SEGURA",
                              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTema.verdeSalud),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
