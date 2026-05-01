import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';
import 'sustituto_form_page.dart';

class SustitutosPage extends ConsumerStatefulWidget {
  const SustitutosPage({super.key});

  @override
  ConsumerState<SustitutosPage> createState() => _SustitutosPageState();
}

class _SustitutosPageState extends ConsumerState<SustitutosPage> {
  bool _loading = false;
  List<dynamic> _items = [];
  String _query = '';
  Map<String, dynamic>? _selectedItem;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('nutricionista/sustitutos', queryParameters: {'q': _query});
      if (mounted) {
        setState(() {
          _items = resp.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: Row(
        children: [
          Expanded(
            flex: _selectedItem != null || _isEditing ? 3 : 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
          ),
          if (_selectedItem != null || _isEditing)
            Expanded(
              flex: 2,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: Color(0xFFEEEEEE))),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(-5, 0))],
                ),
                child: SustitutoFormPage(
                  sustitutoInicial: _selectedItem,
                  onBack: () {
                    setState(() {
                      _selectedItem = null;
                      _isEditing = false;
                    });
                    _fetch();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión de Sustitutos",
            style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text("Administra alternativas de alimentos para pacientes con restricciones o preferencias.",
            style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatsRow() {
    final activos = _items.where((e) => e['activo'] == true).length;
    return Row(
      children: [
        Expanded(child: NutriResumenCard(titulo: "TOTAL SUSTITUTOS", valor: "${_items.length}", icon: Icons.swap_horiz_rounded)),
        const SizedBox(width: 20),
        Expanded(child: NutriResumenCard(titulo: "ACTIVOS", valor: "$activos", colorValor: AppTema.verdeSalud, icon: Icons.check_circle_rounded)),
      ],
    );
  }

  Widget _buildToolbar() {
    return NutriTableToolbar(
      onSearch: (v) {
        _query = v;
        _fetch();
      },
      onAction: () => setState(() {
        _selectedItem = null;
        _isEditing = true;
      }),
      actionLabel: "NUEVO SUSTITUTO",
    );
  }

  Widget _buildTableContainer() {
    return NutriTableContainer(
      child: _loading && _items.isEmpty
          ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Cargando sustitutos..."))
          : _items.isEmpty
              ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No se encontraron sustitutos.")))
              : Theme(
                  data: Theme.of(context).copyWith(
                    cardTheme: const CardThemeData(elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
                  ),
                  child: PaginatedDataTable(
                    header: null,
                    rowsPerPage: 10,
                    showFirstLastButtons: true,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                    columns: [
                      _col("ORIGINAL"),
                      _col("REEMPLAZO"),
                      _col("RATIO"),
                      _col("ESTADO"),
                      _col("ACCIONES"),
                    ],
                    source: _SustitutosDataSource(
                      items: _items,
                      onEdit: (item) => setState(() {
                        _selectedItem = item;
                        _isEditing = true;
                      }),
                      onDelete: _confirmDelete,
                      context: context,
                    ),
                  ),
                ),
    );
  }

  DataColumn _col(String l) => DataColumn(label: Text(l, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro)));

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Sustituto"),
        content: const Text("¿Estás seguro de que deseas eliminar este vínculo de sustitución?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () async {
              try {
                final dio = ref.read(dioProvider);
                await dio.delete('nutricionista/sustitutos/$id');
                if (!mounted) return;
                Navigator.pop(context);
                NutriSnack.show(context, "Sustituto eliminado");
                _fetch();
              } catch (e) {
                Navigator.pop(context);
                NutriSnack.show(context, "Error al eliminar", isError: true);
              }
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SustitutosDataSource extends DataTableSource {
  final List<dynamic> items;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;
  final BuildContext context;

  _SustitutosDataSource({
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= items.length) return null;
    final item = items[index];
    return DataRow(cells: [
      DataCell(Text(item['nombre_original'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(item['nombre_reemplazo'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTema.azulPrincipal))),
      DataCell(Text("x${item['ratio_conversion']}")),
      DataCell(NutriBadge(label: item['activo'] ? 'Activo' : 'Inactivo', type: item['activo'] ? 'success' : 'danger')),
      DataCell(Row(
        children: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey), onPressed: () => onEdit(item)),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent), onPressed: () => onDelete(item['id'])),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => items.length;
  @override
  int get selectedRowCount => 0;
}
