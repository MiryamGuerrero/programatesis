import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class AdminCatalogsPage extends ConsumerStatefulWidget {
  const AdminCatalogsPage({super.key});

  @override
  ConsumerState<AdminCatalogsPage> createState() => _AdminCatalogsPageState();
}

class _AdminCatalogsPageState extends ConsumerState<AdminCatalogsPage> {
  static const _catalogs = [
    ("usuarios", "rol"),
    ("usuarios", "catalogo_sexo"),
    ("usuarios", "catalogo_canton"),
    ("usuarios", "catalogo_parroquia"),
    ("nutricion", "condiciones_clinicas"),
    ("heuristico", "condicion"),
    ("heuristico", "catalogo_accion"),
    ("heuristico", "catalogo_objetivo_regla"),
    ("interaccion", "catalogo_estado_plan"),
    ("interaccion", "catalogo_tipo_plan"),
    ("interaccion", "catalogo_origen_plan"),
    ("interaccion", "catalogo_estado_consumo"),
  ];

  String _schema = _catalogs.first.$1;
  String _table = _catalogs.first.$2;

  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCatalog);
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final rows = await repo.fetchCatalog(_schema, _table);
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo, 
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildToolbar(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.2))),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
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
        Text("Configuración de Catálogos", 
          style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text("Administración de tablas maestras del sistema.", 
          style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: "$_schema.$_table",
              decoration: InputDecoration(
                labelText: "Seleccionar Catálogo",
                labelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal),
                filled: true,
                fillColor: AppTema.grisLienzo.withOpacity(0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: [
                for (final item in _catalogs)
                  DropdownMenuItem(
                    value: "${item.$1}.${item.$2}",
                    child: Text("${item.$1}.${item.$2}".toUpperCase(), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                final parts = value.split(".");
                setState(() {
                  _schema = parts[0];
                  _table = parts[1];
                });
                _loadCatalog();
              },
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 55,
            child: FilledButton.icon(
              onPressed: _loading ? null : _loadCatalog,
              style: FilledButton.styleFrom(
                backgroundColor: AppTema.azulPrincipal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              icon: _loading 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, size: 20),
              label: Text(_loading ? "CARGANDO..." : "RECARGAR", 
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableContainer() {
    return NutriTableContainer(
      child: _loading
        ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Sincronizando registros..."))
        : _rows.isEmpty
          ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No hay registros en este catálogo.")))
          : Theme(
              data: Theme.of(context).copyWith(
                cardTheme: const CardThemeData(elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
              ),
              child: PaginatedDataTable(
                header: null,
                rowsPerPage: 5,
                showFirstLastButtons: true,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                columns: [
                  DataColumn(label: Text("ID", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
                  DataColumn(label: Text("CONTENIDO DEL REGISTRO (JSON)", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: AppTema.azulOscuro))),
                ],
                source: _CatalogDataSource(rows: _rows),
              ),
            ),
    );
  }
}

class _CatalogDataSource extends DataTableSource {
  final List<Map<String, dynamic>> rows;

  _CatalogDataSource({required this.rows});

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final row = rows[index];
    return DataRow(cells: [
      DataCell(Text(row["id"]?.toString() ?? "-", style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600))),
      DataCell(SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(row.toString(), style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600)),
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => rows.length;
  @override
  int get selectedRowCount => 0;
}
