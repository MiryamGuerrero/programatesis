import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
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
  String _query = "";
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _recetas = const [];
  
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

  Future<void> _loadRecetas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final data = await repo.fetchRecetas();
      if (!mounted) return;
      setState(() {
        _recetas = data;
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
      final nombre = row["nombre"]?.toString().toLowerCase() ?? "";
      return nombre.contains(_query.toLowerCase());
    }).toList();

    final totalItems = filteredRecetas.length;
    final totalPages = (totalItems / _pageSize).ceil();
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize < totalItems) ? startIndex + _pageSize : totalItems;
    final visibleRecetas = (startIndex < totalItems) ? filteredRecetas.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return Scaffold(
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
    return Row(
      children: [
        Expanded(child: NutriResumenCard(titulo: "TOTAL RECETAS", valor: "${_recetas.length}", icon: Icons.menu_book_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "FILTRADAS", valor: "$visibles", colorValor: AppTema.verdeSalud, icon: Icons.filter_list_rounded)),
        const SizedBox(width: 20),
        const Expanded(child: NutriResumenCard(titulo: "ESTADO", valor: "ACTIVO", colorValor: AppTema.azulOscuro, icon: Icons.check_circle_outline)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
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
              style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar por nombre de receta...",
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
            );
          },
        );
      },
    );
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

  void _confirmarEliminacion(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("¿Eliminar receta?", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        content: Text("Esta acción no se puede deshacer. ¿Deseas eliminar '${r['nombre']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCELAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              try {
                final dio = ref.read(dioProvider);
                await dio.delete('crud/recetas/${r['id']}');
                if (!context.mounted) return;
                Navigator.pop(context);
                NutriSnack.show(context, "Receta eliminada correctamente");
                _loadRecetas();
              } catch (e) {
                NutriSnack.show(context, "Error al eliminar: $e", isError: true);
              }
            },
            child: Text("ELIMINAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

