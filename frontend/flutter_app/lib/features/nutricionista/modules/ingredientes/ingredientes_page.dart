import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import '../../../../shared/widgets/shimmer_components.dart';
import 'ingrediente_detalle_page.dart';
import 'ingrediente_form_page.dart';

class IngredientesPage extends ConsumerStatefulWidget {
  const IngredientesPage({super.key});
  @override
  ConsumerState<IngredientesPage> createState() => _IngredientesPageState();
}

enum IngredienteView { list, detail, form }

class _IngredientesPageState extends ConsumerState<IngredientesPage> {
  final TextEditingController _searchController = TextEditingController();
  IngredienteView _currentView = IngredienteView.list;
  int? _activeId;

  List<dynamic> _items = [];
  List<dynamic> _groups = [];
  List<dynamic> _subgroups = [];
  List<dynamic> _subgroupsFiltrados = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingFilters = true;
  String _query = '';
  int? _groupId;
  int? _subgroupId;
  static const int _rowsPerPage = 5;
  int _offset = 0;
  Timer? _searchDebounce;

  bool get _filtrosActivos =>
      _query.isNotEmpty || _groupId != null || _subgroupId != null;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadFilters();
      _fetch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    setState(() => _loadingFilters = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final results = await Future.wait([
        repo.fetchCatalog('nutricion', 'grupo_alimentario'),
        repo.fetchCatalog('nutricion', 'subgrupo_alimentario'),
      ]);
      if (mounted) {
        setState(() {
          _groups = results[0];
          _subgroups = results[1];
          _subgroupsFiltrados = results[1];
          _loadingFilters = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingFilters = false);
      }
    }
  }

  void _onGroupChanged(int? id) {
    setState(() {
      _groupId = id;
      _subgroupId = null; // Reset subgroup when group changes
      if (id == null) {
        _subgroupsFiltrados = _subgroups;
      } else {
        _subgroupsFiltrados =
            _subgroups.where((s) => s['id_grupo_alimentario'] == id).toList();
      }
    });
    _fetch(offset: 0, updateStats: true);
  }

  void _limpiarFiltros() {
    _searchController.clear();
    setState(() {
      _query = '';
      _groupId = null;
      _subgroupId = null;
      _subgroupsFiltrados = _subgroups;
      _offset = 0;
    });
    _fetch(offset: 0, updateStats: true);
  }

  Future<void> _fetch({int? offset, bool updateStats = false}) async {
    final nextOffset = offset ?? _offset;
    if (mounted) {
      setState(() {
        _offset = nextOffset;
        _loading = true;
        if (updateStats) {
          _loadingFilters = true;
        }
      });
    }
    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final data = await repo.ingredientesLista(
          q: _query,
          cat: _groupId,
          subcat: _subgroupId,
          limit: _rowsPerPage,
          offset: nextOffset);
      if (mounted) {
        setState(() {
          _items = data['items'] ?? [];
          _total = data['total'] ?? 0;
          _loading = false;
          _loadingFilters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingFilters = false;
        });
      }
    }
  }

  void _scheduleSearch(String value) {
    _query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetch(offset: 0, updateStats: true),
    );
  }

  void _showDetail(int id) {
    if (id == -1) {
      _fetch();
      return;
    }
    setState(() {
      _activeId = id;
      _currentView = IngredienteView.detail;
    });
  }

  void _showForm([int? id]) {
    setState(() {
      _activeId = id;
      _currentView = IngredienteView.form;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentView == IngredienteView.detail) {
      return IngredienteDetallePage(
        idIngrediente: _activeId!,
        onBack: () {
          if (mounted) {
            setState(() {
              _currentView = IngredienteView.list;
            });
          }
        },
        onEdit: () => _showForm(_activeId!),
      );
    }
    if (_currentView == IngredienteView.form) {
      return IngredienteFormPage(
        idIngrediente: _activeId,
        onBack: () {
          if (mounted) {
            setState(() {
              _currentView = IngredienteView.list;
            });
          }
        },
        onSaved: () {
          if (mounted) {
            setState(() {
              _currentView = IngredienteView.list;
            });
          }
          _fetch(offset: _offset);
        },
      );
    }

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildStatsRow(),
            const SizedBox(height: 32),
            _buildToolbar(),
            const SizedBox(height: 24),
            _buildTableContainer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión de Alimentos",
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Gestión maestra de ingredientes, grupos alimentarios y valores nutricionales.",
            style: GoogleFonts.inter(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsRow() {
    if (_loadingFilters) {
      return const Row(
        children: [
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
          Expanded(child: NutriResumenCardShimmer()),
          SizedBox(width: 20),
          Expanded(child: NutriResumenCardShimmer()),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
            child: NutriResumenCard(
                titulo: "Total alimentos",
                valor: "$_total",
                icon: Icons.restaurant_menu_rounded)),
        const SizedBox(width: 20),
        Expanded(
            child: NutriResumenCard(
                titulo: "Grupos",
                valor: "${_groups.length}",
                colorValor: AppTema.verdeSalud,
                icon: Icons.category_rounded)),
        const SizedBox(width: 20),
        Expanded(
            child: NutriResumenCard(
                titulo: "Subgrupos",
                valor: "${_subgroups.length}",
                colorValor: AppTema.azulOscuro,
                icon: Icons.layers_rounded)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre de alimento...",
                    hintStyle: GoogleFonts.inter(
                        color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: Colors.grey),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: _scheduleSearch,
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _showForm(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: Text("Nuevo alimento",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              _buildFilterDropdown("Grupo", _groups, _groupId, _onGroupChanged),
              const SizedBox(width: 12),
              _buildFilterDropdown("Subgrupo", _subgroupsFiltrados, _subgroupId,
                  (v) {
                setState(() {
                  _subgroupId = v;
                  _offset = 0;
                });
                _fetch(offset: 0, updateStats: true);
              }),
              const SizedBox(width: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _filtrosActivos ? _limpiarFiltros : null,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    side: BorderSide(color: Colors.grey.shade200),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
                  label: Text(
                    "Limpiar",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    size: 22, color: AppTema.azulPrincipal),
                onPressed: () => _fetch(offset: _offset, updateStats: true),
                tooltip: "Actualizar catálogo",
                style: IconButton.styleFrom(
                  backgroundColor: AppTema.azulPrincipal.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
      String label, List<dynamic> items, int? value, Function(int?) onChanged) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: AppTema.grisLienzo.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          hint: Text(label,
              style: GoogleFonts.montserrat(
                  fontSize: 11, fontWeight: FontWeight.w700)),
          items: [
            DropdownMenuItem(
                value: null,
                child: Text("Todos los ${label.toLowerCase()}s",
                    style: GoogleFonts.montserrat(
                        fontSize: 11, fontWeight: FontWeight.w700))),
            ...items.map((e) => DropdownMenuItem(
                value: e['id'],
                child: Text(
                    e['nombre']?.toString() ?? "Ingrediente",
                    style: GoogleFonts.montserrat(
                        fontSize: 11, fontWeight: FontWeight.w600)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _toggleActivo(int id, bool valor) async {
    final index = _items.indexWhere((item) => item['id'] == id);
    if (index != -1) {
      final oldItem = _items[index];
      setState(() {
        _items[index] = {...oldItem, 'activo': valor};
      });

      try {
        final dio = ref.read(dioProvider);
        await dio.patch("crud/ingredientes/$id/estado", data: {"activa": valor});
      } catch (e) {
        setState(() {
          _items[index] = oldItem;
        });
        if (mounted) {
          NutriSnack.show(context, "Error al cambiar estado: $e",
              isError: true, ref: ref);
        }
      }
    }
  }

  Future<void> _eliminar(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar alimento"),
        content: const Text(
            "¿Estás seguro de eliminar este registro? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("Eliminar")),
        ],
      ),
    );

    if (confirm == true) {
      final oldItems = List<dynamic>.from(_items);
      final oldTotal = _total;

      setState(() {
        _items.removeWhere((item) => item['id'] == id);
        if (oldItems.length != _items.length) {
          _total--;
        }
      });

      try {
        final repo = ref.read(inteligenciaRepositoryProvider);
        await repo.eliminarIngrediente(id);
        if (mounted) {
          NutriSnack.show(context, "Alimento eliminado", ref: ref);
        }
      } catch (e) {
        setState(() {
          _items = oldItems;
          _total = oldTotal;
        });
        if (mounted) {
          NutriSnack.show(context, "Error al eliminar: $e",
              isError: true, ref: ref);
        }
      }
    }
  }

  Widget _buildTableContainer() {
    if (!_loading && _items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.find_in_page_outlined, size: 48, color: Colors.blueGrey.shade300),
            const SizedBox(height: 16),
            Text(
              "No se encontraron alimentos",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTema.azulOscuro,
              ),
            ),
          ],
        ),
      );
    }

    return NutriTableContainer(
      child: LayoutBuilder(builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final usableWidth = totalWidth - 20;
        final currentRowsPerPage = _items.isEmpty
            ? 5
            : (_items.length < _rowsPerPage
                ? _items.length
                : _rowsPerPage);

        return Theme(
          data: Theme.of(context).copyWith(
            cardTheme: const CardThemeData(
                elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
            dividerColor: Colors.transparent,
          ),
          child: PaginatedDataTable(
            header: null,
            rowsPerPage: currentRowsPerPage,
            availableRowsPerPage: [currentRowsPerPage],
            onPageChanged: (firstRowIndex) => _fetch(offset: firstRowIndex),
            showFirstLastButtons: true,
            columnSpacing: 0,
            horizontalMargin: 10,
            dividerThickness: 0.0,
            headingRowColor: WidgetStateProperty.all(AppTema.azulPrincipal),
            columns: [
              _col("ALIMENTO", width: usableWidth * 0.30),
              _col("CATEGORÍA", width: usableWidth * 0.15),
              _col("SUBGRUPO", width: usableWidth * 0.15),
              _col("ACTIVO", width: usableWidth * 0.15),
              _col("KCAL/100G", width: usableWidth * 0.12),
              _col("ACCIONES", width: usableWidth * 0.13),
            ],
            source: _IngredientesDataSource(
              items: _items,
              totalRows: _total,
              offset: _offset,
              isLoading: _loading,
              onView: (id) => _showDetail(id),
              onEdit: (id) => _showForm(id),
              onDelete: (id) => _eliminar(id),
              onToggleStatus: (id, val) => _toggleActivo(id, val),
              totalWidth: usableWidth,
              context: context,
            ),
          ),
        );
      }),
    );
  }

  DataColumn _col(String label, {required double width, bool center = false}) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Container(
          alignment: center ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

class _IngredientesDataSource extends DataTableSource {
  final List<dynamic> items;
  final int totalRows;
  final int offset;
  final bool isLoading;
  final Function(int) onView;
  final Function(int) onEdit;
  final Function(int) onDelete;
  final Function(int, bool) onToggleStatus;
  final double totalWidth;
  final BuildContext context;

  _IngredientesDataSource({
    required this.items,
    required this.totalRows,
    required this.offset,
    required this.isLoading,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
    required this.totalWidth,
    required this.context,
  });

  String _capitalize(String? text) {
    if (text == null || text.isEmpty) return '-';
    String raw = text.trim();
    if (raw.isEmpty) return '-';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    double val =
        (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val == val.toInt().toDouble()) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  @override
  DataRow? getRow(int index) {
    final rowColor = index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC);

    if (isLoading) {
      return DataRow(
        color: WidgetStateProperty.all(rowColor),
        cells: [
          DataCell(SizedBox(
              width: totalWidth * 0.30,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 150, height: 10),
              ))),
          DataCell(SizedBox(
              width: totalWidth * 0.15,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 100, height: 10),
              ))),
          DataCell(SizedBox(
              width: totalWidth * 0.15,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 80, height: 20),
              ))),
          DataCell(SizedBox(
              width: totalWidth * 0.15,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 40, height: 10),
              ))),
          DataCell(SizedBox(
              width: totalWidth * 0.12,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: NutriShimmer(width: 60, height: 10),
              ))),
          DataCell(SizedBox(
            width: totalWidth * 0.13,
            child: Row(
              children: [
                NutriShimmer(
                    width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 8),
                NutriShimmer(
                    width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
              ],
            ),
          )),
        ],
      );
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= items.length) return null;
    final ing = items[localIndex];

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
        DataCell(SizedBox(
          width: totalWidth * 0.30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(ing['nombre']?.toString() ?? "Ingrediente",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppTema.azulPrincipal)),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_capitalize(ing['categoria']?.toString()),
                style: GoogleFonts.inter(fontSize: 12)),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTema.azulPrincipal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(_capitalize(ing['subgrupo']?.toString()),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTema.azulPrincipal)),
              ),
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.15,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Switch(
                value: ing['activo'] ?? true,
                activeColor: AppTema.verdeSalud,
                onChanged: (v) => onToggleStatus(ing['id'], v),
              ),
            ),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.12,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text("${_fmt(ing['energia_kcal'])} kcal",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppTema.verdeSalud)),
          ),
        )),
        DataCell(SizedBox(
          width: totalWidth * 0.13,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                _HoverActionButton(
                    icon: Icons.visibility_outlined,
                    label: "Ver",
                    color: AppTema.azulPrincipal,
                    onTap: () => onView(ing['id'])),
                const SizedBox(width: 8),
                _HoverActionButton(
                    icon: Icons.edit_note_rounded,
                    label: "Editar",
                    color: Colors.orange,
                    onTap: () => onEdit(ing['id'])),
                const SizedBox(width: 8),
                _HoverActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: "Borrar",
                    color: Colors.redAccent,
                    onTap: () => onDelete(ing['id'])),
              ],
            ),
          ),
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => (isLoading && totalRows == 0) ? 5 : totalRows;
  @override
  int get selectedRowCount => 0;
}

class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HoverActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onHover: (hovered) {
        setState(() {
          _isHovered = hovered;
        });
      },
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      hoverColor: Colors.transparent,
      splashColor: widget.color.withValues(alpha: 0.2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.2)
                  : Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: widget.color, size: 18),
            const SizedBox(height: 4),
            Text(widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                    height: 1.0)),
          ],
        ),
      ),
    );
  }
}
