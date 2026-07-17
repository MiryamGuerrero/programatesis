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

class _RecetaDetallePageState extends ConsumerState<RecetaDetallePage>
    with SingleTickerProviderStateMixin {
  static const Set<String> _codigosCriticosAmarillos = {
    'NO_APTO_DIABETICOS',
    'NO_APTO_INTOLERANCIA_FRUCTOSA',
    'NO_APTO_PARA_INTOLERANTES_A_LACTOSA',
    'NO_APTO_PARA_INTOLERANTES_AL_GLUTEN',
    'NO_APTO_PARA_INTOLERANTES_A_SULFITO',
    'NO_APTO_VEGETARIANOS',
  };

  static const Set<String> _codigosCriticosRojos = {
    'E9001_ALFALFA_L_CANAVANINA',
  };

  static const Map<String, String> _nombresCriticosAmigables = {
    'E9001_ALFALFA_L_CANAVANINA': 'LES: alfalfa / L-canavanina',
  };

  late TabController _tabController;
  late Map<String, dynamic> _recetaData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  String _textoLimpio(dynamic value) {
    final text = value?.toString() ?? '-';
    return text
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã­', 'í')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ãº', 'ú')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã', 'Á')
        .replaceAll('Ã‰', 'É')
        .replaceAll('Ã', 'Í')
        .replaceAll('Ã“', 'Ó')
        .replaceAll('Ãš', 'Ú')
        .replaceAll('Ã‘', 'Ñ')
        .replaceAll('Â°', '°')
        .replaceAll('Â¿', '¿')
        .replaceAll('Â¡', '¡');
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTema.azulPrincipal, size: 20),
          onPressed: widget.onBack,
        ),
        title: Text(
          _textoLimpio(r['nombre'] ?? 'Detalle de receta'),
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
            // Seccion de Cabecera: Imagen + Resumen de Datos
            _buildHeaderSection(r),
            const SizedBox(height: 32),
            _buildDescriptionBlock(r),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
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
                        _buildNutricion(r),
                        _buildIngredientes(r),
                        _buildPreparacion(r),
                        _buildEtiquetasLectura(r),
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
    // Calculo de tiempo total: Preparacion + Coccion
    final int tPrep =
        r['tiempo_preparacion_min'] ?? r['tiempo_preparacion'] ?? 0;
    final int tCoc = r['tiempo_coccion_min'] ?? r['tiempo_coccion'] ?? 0;
    final int tTotal = tPrep + tCoc;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lado Izquierdo: Imagen de la receta
        Expanded(
          flex: 4,
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: (r['imagen_url'] != null &&
                      r['imagen_url'].toString().isNotEmpty)
                  ? Image.network(
                      r['imagen_url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      key: ValueKey(
                          r['imagen_url']), // Forzar actualizacion visual
                      errorBuilder: (context, error, stackTrace) =>
                          _buildImagePlaceholder(),
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
            height: 320,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    _buildCompactStat(Icons.people_outline_rounded,
                        '${r['porciones'] ?? 0}', 'Porciones'),
                    _buildCompactStat(Icons.access_time_rounded, '$tTotal min',
                        'Tiempo total'),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    _buildCompactStat(Icons.bar_chart_rounded,
                        r['dificultad'] ?? 'Media', 'Dificultad'),
                    _buildCompactStat(
                        Icons.local_fire_department_rounded,
                        '${r['calorias_por_porcion'] ?? 0} kcal',
                        'Calorías por porción'),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    _buildCompactStat(
                        Icons.restaurant_menu_rounded,
                        r['momentos_nombres'] ??
                            r['categoria'] ??
                            'No definido',
                        'Momento'),
                    _buildCompactStat(Icons.info_outline_rounded,
                        r['activa'] == true ? 'Activa' : 'Inactiva', 'Estado'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStat(IconData icon, dynamic valor, String label) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTema.pastelCeleste.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTema.azulPrincipal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _textoLimpio(valor),
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTema.azulOscuro),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(_textoLimpio(label),
                    style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        color: Colors.blueGrey)),
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
            Icon(Icons.restaurant_menu_rounded,
                size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text('Sin imagen de referencia',
                style: GoogleFonts.inter(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionBlock(Map<String, dynamic> r) {
    final String desc = (r['descripcion_larga'] != null &&
            r['descripcion_larga'].toString().trim().isNotEmpty)
        ? r['descripcion_larga'].toString()
        : (r['descripcion'] != null &&
                r['descripcion'].toString().trim().isNotEmpty)
            ? r['descripcion'].toString()
            : 'No hay una descripción detallada disponible para esta receta.';

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
          Text('Descripción',
              style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTema.azulOscuro)),
          const SizedBox(height: 12),
          Text(
            _textoLimpio(desc),
            style: GoogleFonts.montserrat(
                fontSize: 14, color: Colors.blueGrey.shade700, height: 1.6),
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
      labelStyle:
          GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13),
      tabs: const [
        Tab(text: 'Información nutricional'),
        Tab(text: 'Ingredientes'),
        Tab(text: 'Preparación'),
        Tab(text: 'Etiquetas'),
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
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoItem(
                      'Momento de comida', r['categoria'] ?? 'No definido'),
                  const SizedBox(height: 24),
                  _buildInfoItem('Dificultad', r['dificultad']),
                  const SizedBox(height: 24),
                  _buildInfoItem('Tiempo preparación',
                      '${r['tiempo_preparacion_min'] ?? r['tiempo_preparacion'] ?? 0} min'),
                ],
              )),
              const VerticalDivider(width: 64, color: Color(0xFFF1F5F9)),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoItem('Porciones', r['porciones']),
                  const SizedBox(height: 24),
                  _buildInfoItem('Tiempo cocción',
                      '${r['tiempo_coccion_min'] ?? r['tiempo_coccion'] ?? 0} min'),
                  const SizedBox(height: 24),
                  _buildInfoItem(
                      'Estado', r['activa'] == true ? 'Activa' : 'Inactiva'),
                ],
              )),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          _buildInfoItem('Peso total estimado', '${r['peso_total'] ?? 0} g'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_textoLimpio(label),
            style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey)),
        const SizedBox(height: 4),
        Text(_textoLimpio(value),
            style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTema.azulOscuro)),
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
              child: Column(
                children: [
                  _buildTableHeader([
                    '#',
                    'Ingrediente',
                    'Cant.',
                    'Unidad',
                    'Gramos',
                    'Observaciones'
                  ]),
                  ...ing.asMap().entries.map((entry) {
                    final i = entry.value;
                    final index = entry.key;
                    return _buildTableRow([
                      (index + 1).toString(),
                      i['nombre']?.toString() ?? '-',
                      i['cantidad']?.toString() ?? '-',
                      i['unidad']?.toString() ?? '-',
                      '${i['gramos'] ?? 0}g',
                      i['observaciones']?.toString() ?? '-',
                    ], index);
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildTableHeader(List<String> cells) {
    return Container(
      color: AppTema.azulPrincipal,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Expanded(flex: 1, child: _headerCell(cells[0])),
          Expanded(flex: 4, child: _headerCell(cells[1])),
          Expanded(flex: 2, child: _headerCell(cells[2])),
          Expanded(flex: 2, child: _headerCell(cells[3])),
          Expanded(flex: 2, child: _headerCell(cells[4])),
          Expanded(flex: 4, child: _headerCell(cells[5])),
        ],
      ),
    );
  }

  Widget _headerCell(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(_textoLimpio(t),
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Colors.white)),
      );

  Widget _buildTableRow(List<String> cells, int index) {
    final bool isEven = index % 2 == 0;
    return Container(
      color: isEven ? Colors.white : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          Expanded(flex: 1, child: _rowCell(cells[0])),
          Expanded(flex: 4, child: _rowCell(cells[1])),
          Expanded(flex: 2, child: _rowCell(cells[2])),
          Expanded(flex: 2, child: _rowCell(cells[3])),
          Expanded(flex: 2, child: _rowCell(cells[4])),
          Expanded(flex: 4, child: _rowCell(cells[5])),
        ],
      ),
    );
  }

  Widget _rowCell(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(_textoLimpio(t),
            style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w600)),
      );

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
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: AppTema.azulPrincipal, shape: BoxShape.circle),
              child: Center(
                  child: Text('${p['paso']}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Paso ${p['paso']}',
                          style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTema.azulOscuro)),
                      if (p['tiempo'] != null &&
                          p['tiempo'].toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppTema.pastelCeleste,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(_textoLimpio(p['tiempo']),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTema.azulPrincipal)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_textoLimpio(p['descripcion']),
                      style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.blueGrey.shade700,
                          height: 1.5)),
                  if (p['nota'] != null && p['nota'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Nota: ${_textoLimpio(p['nota'])}',
                        style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTema.verdeSalud,
                            fontStyle: FontStyle.italic)),
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
          Text('Comparativa de macronutrientes',
              style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTema.azulOscuro)),
          const SizedBox(height: 24),
          _buildBarChart(r),
          const SizedBox(height: 48),
          Text('Desglose detallado',
              style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTema.azulOscuro)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildNutriTable('Macronutrientes', [
                {
                  'nombre': 'Calorías',
                  'valor': r['calorias_totales'],
                  'unidad': 'kcal'
                },
                {
                  'nombre': 'Proteínas',
                  'valor': r['proteinas_totales'],
                  'unidad': 'g'
                },
                {
                  'nombre': 'Carbohidratos',
                  'valor': r['carbohidratos_totales'],
                  'unidad': 'g'
                },
                {
                  'nombre': 'Grasas',
                  'valor': r['grasas_totales'] ?? 0,
                  'unidad': 'g'
                },
                {
                  'nombre': 'Fibra',
                  'valor': r['fibra_totales'] ?? 0,
                  'unidad': 'g'
                },
              ])),
              const SizedBox(width: 32),
              Expanded(
                  child: _buildNutriTable('Vitaminas',
                      r['nutricion_detallada']?['vitaminas'] ?? [])),
              const SizedBox(width: 32),
              Expanded(
                  child: _buildNutriTable('Minerales',
                      r['nutricion_detallada']?['minerales'] ?? [])),
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
        _buildProgressBar('Proteínas', prot / (total > 0 ? total : 1),
            AppTema.azulPrincipal, '${prot}g'),
        const SizedBox(height: 16),
        _buildProgressBar('Carbohidratos', carb / (total > 0 ? total : 1),
            Colors.orange, '${carb}g'),
        const SizedBox(height: 16),
        _buildProgressBar('Grasas', fat / (total > 0 ? total : 1),
            Colors.redAccent, '${fat}g'),
      ],
    );
  }

  Widget _buildProgressBar(
      String label, double percent, Color color, String value) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_textoLimpio(label),
                style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey)),
            Text(_textoLimpio(value),
                style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTema.azulOscuro)),
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
          Text(_textoLimpio(title),
<<<<<<< HEAD
              style: GoogleFonts.montserrat(
=======
              style: GoogleFonts.inter(
>>>>>>> ee478003e0250f56131e75a4a5b7f15cfe2ecbee
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.blueGrey,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final bool isEven = index % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: isEven ? Colors.white : const Color(0xFFF1F5F9),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_textoLimpio(row['nombre'] ?? 'Nutriente'),
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey.shade600)),
                  Text('${row['valor']} ${_textoLimpio(row['unidad'])}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTema.azulOscuro)),
                ],
              ),
            );
          }),
        ]
      ],
    );
  }

  Widget _buildEtiquetasLectura(Map<String, dynamic> r) {
    final List<dynamic> etiquetasActuales = r['etiquetas_salud'] ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmarks_rounded,
                  color: AppTema.azulPrincipal, size: 18),
              const SizedBox(width: 12),
              Text(
                'Etiquetas (${etiquetasActuales.length})',
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTema.azulOscuro),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (etiquetasActuales.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.grey.shade100, style: BorderStyle.solid),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.label_off_outlined,
                        color: Colors.grey.shade300, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'No hay etiquetas asignadas.',
                      style: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    etiquetasActuales.map((e) => _buildTagChip(e)).toList()),
        ],
      ),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> e) {
    final isRoja = _isEtiquetaCriticaRoja(e);
    final isAlerta = !isRoja && _isEtiquetaAlertaIntolerancia(e);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isRoja
            ? const Color(0xFFFFD6D6)
            : (isAlerta ? const Color(0xFFFFF8E1) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRoja
              ? const Color(0xFFD32F2F)
              : (isAlerta ? const Color(0xFFF6C453) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRoja
                ? Icons.dangerous_rounded
                : (isAlerta ? Icons.warning_amber_rounded : Icons.tag_rounded),
            size: 14,
            color: isRoja
                ? const Color(0xFFB71C1C)
                : (isAlerta
                    ? const Color(0xFF9A6700)
                    : AppTema.azulPrincipal.withOpacity(0.6)),
          ),
          const SizedBox(width: 10),
          Text(
            _textoEtiquetaVisible(e),
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isRoja
                  ? const Color(0xFFB71C1C)
                  : (isAlerta ? const Color(0xFF7A5200) : AppTema.azulOscuro),
            ),
          ),
        ],
      ),
    );
  }

  bool _isEtiquetaAlertaIntolerancia(Map<String, dynamic> etiqueta) {
    if (_isEtiquetaCriticaRoja(etiqueta)) return false;
    final valores = [
      etiqueta['codigo'],
      etiqueta['titulo'],
      etiqueta['nombre_visible'],
      etiqueta['nombre'],
    ].map(_normalizarCodigoEtiqueta).where((v) => v.isNotEmpty);

    return valores.any((valor) => _codigosCriticosAmarillos.any(
        (codigoCritico) =>
            valor == codigoCritico || valor.contains(codigoCritico)));
  }

  bool _isEtiquetaCriticaRoja(Map<String, dynamic> etiqueta) {
    final id = etiqueta['id'] is int
        ? etiqueta['id'] as int
        : int.tryParse(etiqueta['id']?.toString() ?? '');
    if (id == 9001) return true;
    final valores = [
      etiqueta['codigo'],
      etiqueta['titulo'],
      etiqueta['nombre_visible'],
      etiqueta['nombre'],
    ].map(_normalizarCodigoEtiqueta).where((v) => v.isNotEmpty);

    return valores.any((valor) =>
        _codigosCriticosRojos.any((codigoCritico) =>
            valor == codigoCritico || valor.contains(codigoCritico)) ||
        valor.contains('ALFALFA') ||
        valor.contains('L_CANAVANINA'));
  }

  String _textoEtiquetaVisible(Map<String, dynamic> etiqueta) {
    final codigo = _normalizarCodigoEtiqueta(etiqueta['codigo']);
    if (_nombresCriticosAmigables.containsKey(codigo)) {
      return _nombresCriticosAmigables[codigo]!;
    }
    return _textoLimpio(
      etiqueta['titulo'] ?? etiqueta['nombre_visible'] ?? etiqueta['nombre'],
    );
  }

  String _normalizarCodigoEtiqueta(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toUpperCase()
            .replaceAll('Á', 'A')
            .replaceAll('É', 'E')
            .replaceAll('Í', 'I')
            .replaceAll('Ó', 'O')
            .replaceAll('Ú', 'U')
            .replaceAll('Ñ', 'N')
            .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .replaceAll(RegExp(r'^_|_$'), '') ??
        '';
  }
}
