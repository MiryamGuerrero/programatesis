import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:dio/dio.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";
import "widgets/receta_card.dart";
import "receta_detalle_page.dart";
import "receta_form_page.dart";

class RecetasPage extends ConsumerStatefulWidget {
  const RecetasPage({super.key});

  @override
  ConsumerState<RecetasPage> createState() => _RecetasPageState();
}

class _RecetasPageState extends ConsumerState<RecetasPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  bool _loading = false;
  bool _isDeleting = false;
  String? _error;
  List<Map<String, dynamic>> _recetas = const [];
  List<Map<String, dynamic>> _momentosComida = const [];
  List<Map<String, dynamic>> _tiposPlato = const [];
  int? _momentoSeleccionado;
  int? _tipoPlatoSeleccionado;
  
  // Estados de navegación interna
  Map<String, dynamic>? _selectedReceta;
  bool _isEditing = false;
  Map<String, dynamic>? _recetaParaEditar;
  
  // Paginación
  int _currentPage = 0;
  final int _pageSize = 12; // 3 columnas * 4 filas

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadRecetas);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecetas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        repo.fetchRecetas(),
        dio.get('crud/momentos'),
        dio.get('crud/tipos-plato'),
      ]);
      final data = results[0] as List<Map<String, dynamic>>;
      final momentos = _toRows((results[1] as Response).data);
      final tiposPlato = _toRows((results[2] as Response).data);
      if (!mounted) return;
      setState(() {
        _recetas = data;
        _momentosComida = momentos;
        _tiposPlato = tiposPlato;
        _currentPage = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _prepararEdicion(int id) async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('crud/recetas/$id');
      if (!mounted) return;
      setState(() {
        _recetaParaEditar = resp.data;
        _isEditing = true;
      });
    } catch (e) {
      NutriSnack.show(context, 'Error al cargar detalle para editar', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Vista de Formulario (Alta/Edición)
    if (_isEditing) {
      return RecetaFormPage(
        recetaInicial: _recetaParaEditar,
        onBack: () {
          setState(() {
            _isEditing = false;
            _recetaParaEditar = null;
          });
          _loadRecetas();
        },
      );
    }

    // 2. Vista de Detalle (Lectura)
    if (_selectedReceta != null) {
      return RecetaDetallePage(
        receta: _selectedReceta!,
        onBack: () => setState(() => _selectedReceta = null),
      );
    }

    // 3. Vista de Lista (Matriz)
    final filteredRecetas = _recetas.where((row) {
      final query = _query.trim().toLowerCase();
      final textoBusqueda = [
        row["nombre"],
        row["descripcion"],
        row["categoria"],
        row["momentos_nombres"],
        row["tipos_plato_nombres"],
      ].whereType<Object>().join(" ").toLowerCase();
      final coincideBusqueda = query.isEmpty || textoBusqueda.contains(query);
      final coincideMomento = _momentoSeleccionado == null ||
          _contieneId(row, ["momentos_ids", "momentos"], _momentoSeleccionado!);
      final coincideTipoPlato = _tipoPlatoSeleccionado == null ||
          _contieneId(row, ["tipos_plato_ids", "tipos_plato"], _tipoPlatoSeleccionado!);
      return coincideBusqueda && coincideMomento && coincideTipoPlato;
    }).toList();

    final totalItems = filteredRecetas.length;
    final totalPages = (totalItems / _pageSize).ceil();
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize < totalItems) ? startIndex + _pageSize : totalItems;
    final visibleRecetas = (startIndex < totalItems) ? filteredRecetas.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTema.grisLienzo,
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildStatsRow(totalItems),
                      const SizedBox(height: 32),
                      _buildToolbar(),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 32),
                      _buildGrid(visibleRecetas),
                    ],
                  ),
                ),
              ),
              if (totalPages > 1) _buildPaginationBar(totalPages),
            ],
          ),
        ),
        if (_isDeleting)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    "ELIMINANDO...",
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recetario Terapéutico", 
              style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
            Text("Administración de preparaciones y composición nutricional por plato.", 
              style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.sync_rounded, color: AppTema.azulPrincipal), 
          onPressed: _loadRecetas,
          tooltip: "Refrescar datos",
        ),
      ],
    );
  }

  Widget _buildStatsRow(int visibles) {
    final activas = _recetas.where((r) => r['activa'] == true).length;
    final inactivas = _recetas.length - activas;
    return Row(
      children: [
        Expanded(child: NutriResumenCard(titulo: "TOTAL RECETAS", valor: "${_recetas.length}", icon: Icons.menu_book_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "VISIBLES", valor: "$visibles", colorValor: AppTema.verdeSalud, icon: Icons.filter_list_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "ACTIVAS", valor: "$activas / $inactivas", colorValor: AppTema.azulOscuro, icon: Icons.check_circle_outline)),
      ],
    );
  }

  Widget _buildToolbar() {
    final filtrosActivos = _query.trim().isNotEmpty ||
        _momentoSeleccionado != null ||
        _tipoPlatoSeleccionado != null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre, momento o tipo de plato...",
                    hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTema.azulPrincipal),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onChanged: (v) => setState(() {
                    _query = v;
                    _currentPage = 0;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              height: 55,
              child: FilledButton.icon(
                onPressed: () => setState(() {
                  _isEditing = true;
                  _recetaParaEditar = null;
                }),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white),
                label: Text("NUEVA RECETA", 
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                label: "Momento de comida",
                value: _momentoSeleccionado,
                items: _momentosComida,
                icon: Icons.schedule_rounded,
                onChanged: (value) => setState(() {
                  _momentoSeleccionado = value;
                  _currentPage = 0;
                }),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFilterDropdown(
                label: "Tipo de plato",
                value: _tipoPlatoSeleccionado,
                items: _tiposPlato,
                icon: Icons.restaurant_menu_rounded,
                onChanged: (value) => setState(() {
                  _tipoPlatoSeleccionado = value;
                  _currentPage = 0;
                }),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 55,
              child: OutlinedButton.icon(
                onPressed: filtrosActivos
                    ? () => setState(() {
                          _searchController.clear();
                          _query = "";
                          _momentoSeleccionado = null;
                          _tipoPlatoSeleccionado = null;
                          _currentPage = 0;
                        })
                    : null,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade200),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
                label: Text(
                  "LIMPIAR",
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required IconData icon,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTema.azulPrincipal),
          hint: Row(
            children: [
              Icon(icon, size: 20, color: AppTema.azulPrincipal),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                "Todos",
                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            ...items.where((item) => _asInt(item["id"]) != null).map((item) {
              final id = _asInt(item["id"]);
              return DropdownMenuItem<int?>(
                value: id,
                child: Text(
                  item["nombre"]?.toString() ?? "Sin nombre",
                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> visible) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(100),
          child: NutriLoading(mensaje: "Consultando recetario..."),
        ),
      );
    }

    if (visible.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: Text("No se encontraron recetas."),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const int crossAxisCount = 3;
        const double spacing = 24.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: 480,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final r = visible[index];
            return RecetaCard(
              receta: r,
              onVer: () => _abrirDetalleCompleto(r['id']),
              onEditar: () => _prepararEdicion(r['id']),
              onEliminar: () => _confirmarEliminacion(r),
              onToggleActive: (valor) => _toggleActiva(r['id'], valor),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleActiva(int id, bool valor) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('crud/recetas/$id/estado', data: {'activa': valor});
      _loadRecetas();
    } catch (e) {
      NutriSnack.show(context, 'Error al cambiar estado: $e', isError: true);
    }
  }

  Future<void> _abrirDetalleCompleto(int id) async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('crud/recetas/$id');
      if (!mounted) return;
      setState(() => _selectedReceta = resp.data);
    } catch (e) {
      NutriSnack.show(context, 'Error al cargar detalle', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildPaginationBar(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Página ${_currentPage + 1} de $totalPages",
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey,
            ),
          ),
          Row(
            children: [
              _buildNavButton(
                Icons.chevron_left_rounded,
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              ),
              const SizedBox(width: 12),
              _buildNavButton(
                Icons.chevron_right_rounded,
                _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback? onPressed) {
    final bool disabled = onPressed == null;
    return Container(
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: disabled ? Colors.grey.shade100 : const Color(0xFFF1F5F9)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: disabled ? Colors.grey.shade300 : AppTema.azulPrincipal),
      ),
    );
  }

  void _confirmarEliminacion(Map<String, dynamic> r) async {
    // Eliminación directa con overlay según solicitud (sin Alert)
    setState(() => _isDeleting = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('crud/recetas/${r['id']}');
      if (!mounted) return;
      NutriSnack.show(context, "Receta eliminada correctamente");
      _loadRecetas();
    } catch (e) {
      if (!mounted) return;
      NutriSnack.show(context, "Error al eliminar: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  List<Map<String, dynamic>> _toRows(dynamic payload) {
    if (payload is! List) return const [];
    return payload
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  bool _contieneId(Map<String, dynamic> row, List<String> keys, int idBuscado) {
    for (final key in keys) {
      final value = row[key];
      if (value is List && value.any((item) => _asInt(item) == idBuscado)) {
        return true;
      }
      if (_asInt(value) == idBuscado) {
        return true;
      }
    }
    return false;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

