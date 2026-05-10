import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:dio/dio.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class CatalogoCondicionesPage extends ConsumerStatefulWidget {
  const CatalogoCondicionesPage({super.key});

  @override
  ConsumerState<CatalogoCondicionesPage> createState() => _CatalogoCondicionesPageState();
}

class _CatalogoCondicionesPageState extends ConsumerState<CatalogoCondicionesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<dynamic> _condiciones = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      // Filtramos tipos 1, 2 y 3 (clínicas, temporales y nutricionales)
      final res = await dio.get("catalogos/condiciones");
      if (mounted) {
        setState(() {
          _condiciones = res.data as List;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _clinicas => _condiciones
      .where((c) => (c["id_tipo"] ?? c["id_tipo_condicion"]) == 1 && c["nombre"].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
      .toList();

  List<dynamic> get _temporales => _condiciones
      .where((c) => (c["id_tipo"] ?? c["id_tipo_condicion"]) == 2 && c["nombre"].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
      .toList();

  List<dynamic> get _nutricionales => _condiciones
      .where((c) => (c["id_tipo"] ?? c["id_tipo_condicion"]) == 3 && c["nombre"].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: AppTema.azulPrincipal))
        : Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 24),
                    _buildTabBar(),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildClinicalList(_clinicas),
                      _buildTemporalGrid(_temporales),
                      _buildNutritionalGrid(_nutricionales),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTema.verdeSalud.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text("GESTIÓN CLÍNICA", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: AppTema.verdeSalud, letterSpacing: 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text("Catálogo de Condiciones", 
          style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text("Diccionario maestro de diagnósticos y eventos de salud para el sistema.", 
          style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 55,
                decoration: BoxDecoration(
                  color: AppTema.grisLienzo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: "Buscar condición por nombre o palabra clave...",
                    hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTema.azulPrincipal),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              height: 55,
              child: FilledButton.icon(
                onPressed: () => _abrirFormulario(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white),
                label: Text("NUEVA CONDICIÓN", 
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppTema.azulPrincipal,
      unselectedLabelColor: Colors.blueGrey,
      indicatorColor: AppTema.verdeSalud,
      indicatorWeight: 4,
      labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
      unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13),
      tabs: const [
        Tab(text: "DIAGNÓSTICOS CLÍNICOS"),
        Tab(text: "SÍNTOMAS TEMPORALES"),
        Tab(text: "ESTÁNDARES OMS"),
      ],
    );
  }

  Widget _buildNutritionalGrid(List<dynamic> items) {
    if (items.isEmpty) return _buildEmptyState();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.45,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bool active = item["activa"] == true;
        final String range = "${item['edad_min_meses'] ?? 0}-${item['edad_max_meses'] ?? 228}m";
        final String indicator = item['indicador_codigo'] ?? "OMS";

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? AppTema.azulPrincipal.withOpacity(0.2) : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTema.azulPrincipal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.analytics_outlined, color: AppTema.azulPrincipal, size: 20),
                  ),
                  _statusBadge(active),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                item["nombre"],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800, color: AppTema.azulOscuro),
              ),
              const SizedBox(height: 4),
              Text(
                "Indicador: $indicator | Rango: $range",
                style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blueGrey),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  item["descripcion"] ?? "Condición nutricional basada en percentiles OMS.",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(fontSize: 11, color: Colors.blueGrey, height: 1.4, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClinicalList(List<dynamic> items) {
    if (items.isEmpty) return _buildEmptyState();

    return NutriTableContainer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
            columnSpacing: 24,
            horizontalMargin: 24,
            dataRowMaxHeight: 75,
            columns: [
              DataColumn(label: _colLabel("IDENTIDAD")),
              DataColumn(label: _colLabel("ESTADO")),
              DataColumn(label: _colLabel("ACCIONES")),
            ],
            rows: items.map((item) {
              final active = item["activa"] == true;
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 400,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item["nombre"],
                            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: AppTema.azulOscuro),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item["descripcion"] ?? "Sin descripción clínica registrada.",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(_statusBadge(active)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tableActionBtn(
                          icon: Icons.visibility_outlined,
                          color: AppTema.azulPrincipal,
                          tooltip: "Ver Detalle",
                          onTap: () => _verDetalle(item),
                        ),
                        const SizedBox(width: 8),
                        _tableActionBtn(
                          icon: Icons.edit_note_rounded,
                          color: Colors.orange,
                          tooltip: "Editar",
                          onTap: () => _abrirFormulario(condicion: item),
                        ),
                        const SizedBox(width: 8),
                        _tableActionBtn(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          tooltip: "Eliminar",
                          onTap: () => _eliminar(item),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _colLabel(String l) => Text(
        l,
        style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: AppTema.azulOscuro, letterSpacing: 1),
      );

  Widget _tableActionBtn({required IconData icon, required Color color, required VoidCallback onTap, String? tooltip}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: color),
      style: IconButton.styleFrom(
        backgroundColor: color.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTemporalGrid(List<dynamic> items) {
    if (items.isEmpty) return _buildEmptyState();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.45,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildTemporalCard(items[index]),
    );
  }

  Widget _buildTemporalCard(dynamic item) {
    final int? duracion = item["duracion_dias_sugerida"];
    final bool active = item["activa"] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppTema.verdeSalud.withOpacity(0.2) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTema.verdeSalud.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.flash_on_rounded, color: AppTema.verdeSalud, size: 20),
              ),
              _statusBadge(active),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            item["nombre"],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(fontSize: 17, fontWeight: FontWeight.w800, color: AppTema.azulOscuro),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              item["descripcion"] ?? "Condición de duración limitada.",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.blueGrey, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("DURACIÓN", style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                  Text(duracion != null ? "$duracion DÍAS" : "S/D", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
                ],
              ),
              Row(
                children: [
                  _tableActionBtn(icon: Icons.visibility_outlined, color: AppTema.azulPrincipal, tooltip: "Ver", onTap: () => _verDetalle(item)),
                  const SizedBox(width: 6),
                  _tableActionBtn(icon: Icons.edit_note_rounded, color: Colors.orange, tooltip: "Editar", onTap: () => _abrirFormulario(condicion: item)),
                  const SizedBox(width: 6),
                  _tableActionBtn(icon: Icons.delete_outline_rounded, color: Colors.redAccent, tooltip: "Eliminar", onTap: () => _eliminar(item)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppTema.verdeSalud.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        active ? "ACTIVA" : "INACTIVA",
        style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w800, color: active ? AppTema.verdeSalud : Colors.grey.shade500),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No se encontraron condiciones", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  void _verDetalle(Map<String, dynamic> item) {
    showDialog(context: context, builder: (context) => _DetalleCondicionModal(condicion: item));
  }

  void _abrirFormulario({Map<String, dynamic>? condicion}) {
    showDialog(
      context: context,
      barrierColor: AppTema.azulOscuro.withOpacity(0.4),
      builder: (context) => _FormularioCondicion(condicion: condicion, onSuccess: _fetchData),
    );
  }

  Future<void> _eliminar(Map<String, dynamic> c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("¿Eliminar registro?", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
        content: Text("¿Deseas eliminar '${c["nombre"]}'? Esta acción es irreversible.", style: GoogleFonts.montserrat(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCELAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey))),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("ELIMINAR")),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(dioProvider).delete("catalogos/condiciones/${c["id"]}");
        _fetchData();
        if (mounted) NutriSnack.show(context, "Condición eliminada", ref: ref);
      } catch (e) {
        if (mounted) NutriSnack.show(context, "Error al eliminar: $e", isError: true, ref: ref);
      }
    }
  }
}

class _DetalleCondicionModal extends StatelessWidget {
  final Map<String, dynamic> condicion;
  const _DetalleCondicionModal({required this.condicion});

  @override
  Widget build(BuildContext context) {
    final int tipo = condicion["id_tipo"] ?? condicion["id_tipo_condicion"] ?? 1;
    final Color accentColor = tipo == 1 ? AppTema.azulPrincipal : AppTema.verdeSalud;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(tipo == 1 ? Icons.assignment_ind_rounded : Icons.flash_on_rounded, color: accentColor, size: 24),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 24),
            Text(condicion["nombre"].toString().toUpperCase(), style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: AppTema.azulOscuro, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(tipo == 1 ? "DIAGNÓSTICO CLÍNICO" : "SÍNTOMA TEMPORAL", accentColor),
                const SizedBox(width: 8),
                _chip(condicion["activa"] == true ? "ACTIVA" : "INACTIVA", condicion["activa"] == true ? AppTema.verdeSalud : Colors.grey),
              ],
            ),
            const SizedBox(height: 32),
            _infoBlock("DESCRIPCIÓN TÉCNICA", condicion["descripcion"] ?? "Sin información adicional."),
            if (tipo == 2) ...[
              const SizedBox(height: 24),
              _infoBlock("VENTANA DE TIEMPO SUGERIDA", "${condicion["duracion_dias_sugerida"] ?? 'Indefinida'} días de seguimiento recomendado."),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("CERRAR EXPEDIENTE", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: AppTema.azulOscuro, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
  );

  Widget _infoBlock(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
      const SizedBox(height: 10),
      Text(value, style: GoogleFonts.montserrat(fontSize: 14, color: AppTema.azulOscuro.withOpacity(0.8), height: 1.6, fontWeight: FontWeight.w500)),
    ],
  );
}

class _FormularioCondicion extends ConsumerStatefulWidget {
  final Map<String, dynamic>? condicion;
  final VoidCallback onSuccess;
  const _FormularioCondicion({this.condicion, required this.onSuccess});
  @override
  ConsumerState<_FormularioCondicion> createState() => _FormularioCondicionState();
}

class _FormularioCondicionState extends ConsumerState<_FormularioCondicion> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _duracionCtrl = TextEditingController();
  int _idTipo = 1;
  bool _activa = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.condicion != null) {
      _nombreCtrl.text = widget.condicion!["nombre"] ?? "";
      _descCtrl.text = widget.condicion!["descripcion"] ?? "";
      _duracionCtrl.text = widget.condicion!["duracion_dias_sugerida"]?.toString() ?? "";
      _idTipo = widget.condicion!["id_tipo"] ?? widget.condicion!["id_tipo_condicion"] ?? 1;
      _activa = widget.condicion!["activa"] ?? true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.condicion != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? "Modificar Registro" : "Alta de Nueva Condición", 
                style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w900, color: AppTema.azulOscuro, letterSpacing: -0.8)),
              const SizedBox(height: 8),
              Text("Complete la ficha técnica de la condición para el motor de reglas.", 
                style: GoogleFonts.montserrat(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 32),
              
              _sectionTitle("CLASIFICACIÓN"),
              Row(
                children: [
                  _typeOption(1, "CLÍNICA", Icons.health_and_safety_rounded, "Diagnóstico crónico/base"),
                  const SizedBox(width: 16),
                  _typeOption(2, "TEMPORAL", Icons.shutter_speed_rounded, "Evento de salud agudo"),
                ],
              ),
              
              const SizedBox(height: 32),
              _sectionTitle("INFORMACIÓN GENERAL"),
              _minimalInput(_nombreCtrl, "Nombre oficial de la condición", Icons.badge_outlined),
              if (_idTipo == 2) ...[
                const SizedBox(height: 16),
                _minimalInput(_duracionCtrl, "Duración estimada en días", Icons.av_timer_rounded, isNum: true),
              ],
              
              const SizedBox(height: 32),
              _sectionTitle("DETALLE CLÍNICO"),
              _minimalInput(_descCtrl, "Descripción, criterios médicos o síntomas...", Icons.text_snippet_outlined, lines: 4),
              
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTema.grisLienzo, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: _activa ? AppTema.verdeSalud : Colors.grey, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Estado de Disponibilidad", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
                          Text("Habilita esta condición para uso en pacientes.", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.blueGrey)),
                        ],
                      ),
                    ),
                    Switch.adaptive(value: _activa, activeColor: AppTema.verdeSalud, onChanged: (v) => setState(() => _activa = v)),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: Text("CANCELAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: Colors.grey, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTema.azulPrincipal,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(_saving ? "PROCESANDO..." : "GUARDAR REGISTRO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w900, color: AppTema.azulPrincipal.withOpacity(0.5), letterSpacing: 2)),
  );

  Widget _minimalInput(TextEditingController c, String h, IconData i, {int lines = 1, bool isNum = false}) => TextFormField(
    controller: c,
    maxLines: lines,
    keyboardType: isNum ? TextInputType.number : TextInputType.text,
    style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: AppTema.azulOscuro),
    decoration: InputDecoration(
      hintText: h,
      prefixIcon: Icon(i, color: AppTema.azulPrincipal, size: 20),
      filled: true,
      fillColor: AppTema.grisLienzo,
      contentPadding: const EdgeInsets.all(20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      hintStyle: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
    ),
  );

  Widget _typeOption(int val, String title, IconData icon, String sub) {
    final sel = _idTipo == val;
    final color = sel ? AppTema.verdeSalud : Colors.grey.shade300;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _idTipo = val),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sel ? AppTema.verdeSalud.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: sel ? 2 : 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w900, color: sel ? AppTema.verdeSalud : Colors.grey.shade500)),
              Text(sub, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nombreCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      if (widget.condicion != null) {
        await repo.updateCondition(
          idCondicion: widget.condicion!["id"],
          nombre: _nombreCtrl.text,
          descripcion: _descCtrl.text,
          idTipoCondicion: _idTipo,
          activa: _activa,
          codigo: widget.condicion!["codigo"],
          duracionDiasSugerida: (_idTipo == 2 && _duracionCtrl.text.isNotEmpty) ? int.tryParse(_duracionCtrl.text) : null,
        );
      } else {
        await repo.createCondition(
          nombre: _nombreCtrl.text,
          descripcion: _descCtrl.text,
          idTipoCondicion: _idTipo,
          activa: _activa,
          duracionDiasSugerida: (_idTipo == 2 && _duracionCtrl.text.isNotEmpty) ? int.tryParse(_duracionCtrl.text) : null,
        );
      }
      widget.onSuccess();
      if (mounted) {
        NutriSnack.show(context, "Registro guardado correctamente", ref: ref);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) NutriSnack.show(context, "Error al procesar solicitud", isError: true, ref: ref);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
