import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/layout_components.dart';

class RecetaDetallePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> receta;
  final VoidCallback onBack;

  const RecetaDetallePage({
    super.key,
    required this.receta,
    required this.onBack,
  });

  @override
  ConsumerState<RecetaDetallePage> createState() => _RecetaDetallePageState();
}

class _RecetaDetallePageState extends ConsumerState<RecetaDetallePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _recetaData;
  bool _loadingEtiquetas = false;
  List<dynamic> _etiquetasDisponibles = [];
  String _tagQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _recetaData = widget.receta;
    _cargarDetalleActualizado();
  }

  Future<void> _cargarDetalleActualizado() async {
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('crud/recetas/${_recetaData['id']}');
      if (mounted) {
        setState(() {
          _recetaData = resp.data;
        });
      }
    } catch (e) {
      debugPrint("Error al recargar receta: $e");
    }
  }

  Future<void> _buscarEtiquetas(String q) async {
    if (q.isEmpty) {
      setState(() => _etiquetasDisponibles = []);
      return;
    }
    setState(() => _loadingEtiquetas = true);
    try {
      final dio = ref.read(dioProvider);
      final resp = await dio.get('nutricionista/etiquetas', queryParameters: {'q': q});
      if (mounted) {
        setState(() {
          _etiquetasDisponibles = resp.data;
          _loadingEtiquetas = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingEtiquetas = false);
    }
  }

  Future<void> _vincularEtiqueta(int idEtiqueta) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('crud/recetas/${_recetaData['id']}/etiquetas/$idEtiqueta');
      await _cargarDetalleActualizado();
      if (mounted) {
        NutriSnack.show(context, 'Etiqueta vinculada');
        setState(() {
          _tagQuery = "";
          _etiquetasDisponibles = [];
        });
      }
    } catch (e) {
      if (mounted) NutriSnack.show(context, 'Error al vincular etiqueta', isError: true);
    }
  }

  Future<void> _desvincularEtiqueta(int idEtiqueta) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('crud/recetas/${_recetaData['id']}/etiquetas/$idEtiqueta');
      await _cargarDetalleActualizado();
      if (mounted) { NutriSnack.show(context, 'Etiqueta eliminada'); }
    } catch (e) {
      if (mounted) NutriSnack.show(context, 'Error al desvincular etiqueta', isError: true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _recetaData;

    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTema.azulPrincipal, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text(
          r['nombre'] ?? 'Detalle de Receta',
          style: GoogleFonts.montserrat(
            color: AppTema.azulOscuro,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Cabecera: Imagen + Resumen de Datos
            _buildHeaderSection(r),
            const SizedBox(height: 32),
            _buildDescriptionBlock(r),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  _buildTabBar(),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  SizedBox(
                    height: 600, 
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoGeneral(r),
                        _buildIngredientes(r),
                        _buildPreparacion(r),
                        _buildGestionEtiquetas(r),
                        _buildNutricion(r),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Map<String, dynamic> r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lado Izquierdo: Imagen de la receta
        Expanded(
          flex: 4,
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: (r['imagen_url'] != null && r['imagen_url'].toString().isNotEmpty)
                  ? Image.network(
                      r['imagen_url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      key: ValueKey(r['imagen_url']), // Forzar actualización visual
                      errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
          ),
        ),
        const SizedBox(width: 32),
        // Lado Derecho: Datos clave en recuadros
        Expanded(
          flex: 5,
          child: Container(
            height: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    _buildCompactStat(Icons.people_outline_rounded, '${r['porciones'] ?? 0}', 'Porciones'),
                    _buildCompactStat(Icons.access_time_rounded, '${r['tiempo_total'] ?? r['tiempo_preparacion'] ?? 0} min', 'Tiempo Total'),
                  ],
                ),
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    _buildCompactStat(Icons.bar_chart_rounded, '${r['dificultad'] ?? 'Media'}', 'Dificultad'),
                    _buildCompactStat(Icons.local_fire_department_rounded, '${r['calorias_por_porcion'] ?? 0} kcal', 'Cal / Porción'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStat(IconData icon, String valor, String label) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTema.pastelCeleste.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTema.azulPrincipal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(valor, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, color: AppTema.azulOscuro)),
                Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blueGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text('Sin imagen de referencia', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionBlock(Map<String, dynamic> r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Descripción', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, color: AppTema.azulOscuro)),
          const SizedBox(height: 12),
          Text(
            r['descripcion_larga'] ?? r['descripcion'] ?? 'No hay una descripción detallada disponible para esta receta.',
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.blueGrey.shade700, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppTema.azulPrincipal,
      unselectedLabelColor: Colors.blueGrey,
      indicatorColor: AppTema.azulPrincipal,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13),
      tabs: const [
        Tab(text: 'Información Básica'),
        Tab(text: 'Ingredientes'),
        Tab(text: 'Preparación'),
        Tab(text: 'Etiquetas'),
        Tab(text: 'Nutrición'),
      ],
    );
  }

  Widget _buildInfoGeneral(Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoItem('Momento de comida', r['categoria'] ?? 'No definido'),
                  const SizedBox(height: 24),
                  _buildInfoItem('Dificultad', r['dificultad']),
                  const SizedBox(height: 24),
                  _buildInfoItem('Tiempo Preparación', '${r['tiempo_preparacion_min'] ?? r['tiempo_preparacion'] ?? 0} min'),
                ],
              )),
              const VerticalDivider(width: 64, color: Color(0xFFF1F5F9)),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoItem('Porciones', r['porciones']),
                  const SizedBox(height: 24),
                  _buildInfoItem('Tiempo Cocción', '${r['tiempo_coccion_min'] ?? r['tiempo_coccion'] ?? 0} min'),
                  const SizedBox(height: 24),
                  _buildInfoItem('Estado', r['activa'] == true ? 'ACTIVA' : 'INACTIVA'),
                ],
              )),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          _buildInfoItem('Peso Total Estimado', '${r['peso_total'] ?? 0} g'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 4),
        Text(value?.toString() ?? '-', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
      ],
    );
  }

  Widget _buildIngredientes(Map<String, dynamic> r) {
    final List<dynamic> ing = r['ingredientes'] ?? [];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ing.isEmpty 
        ? const Center(child: Text('No hay ingredientes registrados.'))
        : SingleChildScrollView(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(4),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(2),
                5: FlexColumnWidth(4),
              },
              children: [
                _buildTableHeader(['#', 'Ingrediente', 'Cant.', 'Unidad', 'Gramos', 'Observaciones']),
                ...ing.asMap().entries.map((entry) {
                  final i = entry.value;
                  return _buildTableRow([
                    (entry.key + 1).toString(),
                    i['nombre']?.toString() ?? '-',
                    i['cantidad']?.toString() ?? '-',
                    i['unidad']?.toString() ?? '-',
                    '${i['gramos'] ?? 0}g',
                    i['observaciones']?.toString() ?? '-',
                  ]);
                }),
              ],
            ),
          ),
    );
  }

  TableRow _buildTableHeader(List<String> cells) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
      children: cells.map((c) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(c, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.blueGrey)),
      )).toList(),
    );
  }

  TableRow _buildTableRow(List<String> cells) {
    return TableRow(
      children: cells.map((c) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(c, style: GoogleFonts.montserrat(fontSize: 13, color: AppTema.azulOscuro, fontWeight: FontWeight.w500)),
      )).toList(),
    );
  }

  Widget _buildPreparacion(Map<String, dynamic> r) {
    final List<dynamic> pasos = r['preparacion'] ?? [];
    return ListView.separated(
      padding: const EdgeInsets.all(32),
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
              child: Center(child: Text('${p['paso']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Paso ${p['paso']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: AppTema.azulOscuro)),
                      if (p['tiempo'] != null && p['tiempo'].toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTema.pastelCeleste, borderRadius: BorderRadius.circular(6)),
                          child: Text(p['tiempo'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(p['descripcion'] ?? '', style: GoogleFonts.montserrat(fontSize: 14, color: Colors.blueGrey.shade700, height: 1.5)),
                  if (p['nota'] != null && p['nota'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Nota: ${p['nota']}', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: AppTema.verdeSalud, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNutricion(Map<String, dynamic> r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comparativa de Macronutrientes', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppTema.azulOscuro)),
          const SizedBox(height: 24),
          _buildBarChart(r),
          const SizedBox(height: 48),
          Text('Desglose Detallado', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppTema.azulOscuro)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildNutriTable('Macronutrientes', [
                {'nombre': 'Calorías', 'valor': r['calorias_totales'], 'unidad': 'kcal'},
                {'nombre': 'Proteínas', 'valor': r['proteinas_totales'], 'unidad': 'g'},
                {'nombre': 'Carbohidratos', 'valor': r['carbohidratos_totales'], 'unidad': 'g'},
                {'nombre': 'Grasas', 'valor': r['grasas_totales'] ?? 0, 'unidad': 'g'},
                {'nombre': 'Fibra', 'valor': r['fibra_totales'] ?? 0, 'unidad': 'g'},
              ])),
              const SizedBox(width: 32),
              Expanded(child: _buildNutriTable('Vitaminas', r['nutricion_detallada']?['vitaminas'] ?? [])),
              const SizedBox(width: 32),
              Expanded(child: _buildNutriTable('Minerales', r['nutricion_detallada']?['minerales'] ?? [])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> r) {
    final double prot = (r['proteinas_totales'] ?? 0).toDouble();
    final double carb = (r['carbohidratos_totales'] ?? 0).toDouble();
    final double fat = (r['grasas_totales'] ?? 0).toDouble();
    final double total = prot + carb + fat;

    return Column(
      children: [
        _buildProgressBar('Proteínas', prot / (total > 0 ? total : 1), AppTema.azulPrincipal, '${prot}g'),
        const SizedBox(height: 16),
        _buildProgressBar('Carbohidratos', carb / (total > 0 ? total : 1), Colors.orange, '${carb}g'),
        const SizedBox(height: 16),
        _buildProgressBar('Grasas', fat / (total > 0 ? total : 1), Colors.redAccent, '${fat}g'),
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
          minHeight: 12,
          backgroundColor: const Color(0xFFF1F5F9),
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }

  Widget _buildNutriTable(String title, List<dynamic> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rows.isNotEmpty) ...[
          Text(title.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1)),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(row['nombre'], style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade600)),
                Text('${row['valor']} ${row['unidad']}', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
              ],
            ),
          )),
        ]
      ],
    );
  }

  Widget _buildGestionEtiquetas(Map<String, dynamic> r) {
    final List<dynamic> etiquetasActuales = r['etiquetas_salud'] ?? [];
    
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Asignar Etiquetas Nutricionales', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: AppTema.azulOscuro)),
          const SizedBox(height: 8),
          Text('Busca y selecciona etiquetas para clasificar esta receta.', style: GoogleFonts.inter(fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 24),
          
          // Buscador de Etiquetas
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar etiqueta...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                  onChanged: (v) {
                    _tagQuery = v;
                    _buscarEtiquetas(v);
                  },
                ),
              ),
              if (_loadingEtiquetas) 
                const Padding(padding: EdgeInsets.only(left: 16), child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          
          // Resultados de Búsqueda
          if (_etiquetasDisponibles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _etiquetasDisponibles.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final tag = _etiquetasDisponibles[index];
                  final yaAsignada = etiquetasActuales.any((e) => e['id'] == tag['id']);
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: yaAsignada ? Colors.green.withOpacity(0.1) : AppTema.pastelCeleste.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        yaAsignada ? Icons.check_circle_rounded : Icons.label_outline_rounded,
                        size: 18,
                        color: yaAsignada ? Colors.green : AppTema.azulPrincipal,
                      ),
                    ),
                    title: Text(
                      tag['nombre_visible'], 
                      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)
                    ),
                    subtitle: Text(
                      tag['codigo'], 
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey.shade400)
                    ),
                    trailing: yaAsignada 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          icon: const Icon(Icons.add_circle_rounded, color: AppTema.azulPrincipal, size: 28),
                          onPressed: () => _vincularEtiqueta(tag['id']),
                        ),
                  );
                },
              ),
            ),
          ],
          
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 24),
          
          Row(
            children: [
              const Icon(Icons.bookmarks_rounded, color: AppTema.azulPrincipal, size: 18),
              const SizedBox(width: 12),
              Text('Etiquetas Actuales (${etiquetasActuales.length})', 
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15, color: AppTema.azulOscuro)),
            ],
          ),
          const SizedBox(height: 24),
          
          if (etiquetasActuales.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100, style: BorderStyle.solid),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.label_off_outlined, color: Colors.grey.shade300, size: 40),
                    const SizedBox(height: 12),
                    Text('No hay etiquetas asignadas.', 
                      style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: etiquetasActuales.map((e) => _buildTagChip(e)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag_rounded, size: 14, color: AppTema.azulPrincipal.withOpacity(0.6)),
          const SizedBox(width: 10),
          Text(
            e['titulo'] ?? '-',
            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: AppTema.azulOscuro),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => _desvincularEtiqueta(e['id']),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
