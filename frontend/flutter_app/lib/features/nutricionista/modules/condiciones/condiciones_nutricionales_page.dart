import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/state/app_providers.dart";
import "../../../../core/theme/app_theme.dart";
import "../../../../shared/widgets/layout_components.dart";

class CondicionesNutricionalesPage extends ConsumerStatefulWidget {
  const CondicionesNutricionalesPage({super.key});

  @override
  ConsumerState<CondicionesNutricionalesPage> createState() => _CondicionesNutricionalesPageState();
}

class _CondicionesNutricionalesPageState extends ConsumerState<CondicionesNutricionalesPage> with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<dynamic> _conditions = [];
  String _searchQuery = "";
  late TabController _tabController;

  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final response = await _dio.get("condiciones-nutricionales");
      if (mounted) {
        setState(() {
          _conditions = response.data as List;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        NutriSnack.show(context, "Error al cargar catálogo de condiciones", isError: true, ref: ref);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisFondo,
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSearchBarAndAddButton(),
              const SizedBox(height: 24),
              _buildTabs(),
              _buildConditionsTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Image.asset("assets/images/kp3.png", width: 40, height: 40, fit: BoxFit.contain),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Catálogo de Condiciones", 
                style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w800, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
              Text("Diccionario maestro de diagnósticos y eventos de salud para el sistema.", 
                style: GoogleFonts.montserrat(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.sync_rounded, color: AppTema.azulPrincipal),
          onPressed: _loadData,
          tooltip: "Sincronizar",
        ),
      ],
    );
  }

  Widget _buildSearchBarAndAddButton() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar condición por nombre o palabra clave...",
                hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTema.azulPrincipal),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white),
            label: Text("Nueva condición", 
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 3.0, color: AppTema.verdeSalud),
          insets: EdgeInsets.symmetric(horizontal: 0.0),
        ),
        labelColor: AppTema.verdeSalud,
        unselectedLabelColor: Colors.blueGrey,
        labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14),
        tabs: [
          Tab(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.add_box_outlined, size: 20, color: AppTema.verdeSalud),
                  SizedBox(width: 8),
                  Text("Diagnósticos clínicos"),
                ],
              ),
            ),
          ),
          Tab(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.access_time, size: 20),
                  SizedBox(width: 8),
                  Text("Síntomas temporales"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsTable() {
    final filtered = _conditions.where((c) {
      final term = _searchQuery.toLowerCase();
      return c["nombre"].toString().toLowerCase().contains(term) ||
             c["descripcion"].toString().toLowerCase().contains(term);
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: _loading 
        ? const Padding(padding: EdgeInsets.all(100), child: NutriLoading(mensaje: "Sincronizando catálogo..."))
        : Column(
            children: [
              _buildTableHead(),
              if (filtered.isEmpty)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No se encontraron condiciones.")))
              else
                ...filtered.map((c) => _buildTableRow(c)),
              _buildPagination(filtered.length),
            ],
          ),
    );
  }

  Widget _buildTableHead() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(flex: 6, child: _tableHeaderLabel("Identidad")),
          Expanded(flex: 2, child: Center(child: _tableHeaderLabel("Estado"))),
          Expanded(flex: 3, child: Center(child: _tableHeaderLabel("Acciones"))),
        ],
      ),
    );
  }

  Widget _tableHeaderLabel(String label) {
    return Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, color: AppTema.azulPrincipal));
  }

  Widget _buildTableRow(Map<String, dynamic> c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c["nombre"]?.toString() ?? "Condición", 
                  style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
                const SizedBox(height: 6),
                Text(c["descripcion"]?.toString() ?? "Sin descripción", 
                  style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _StatusBadge(isActive: c['activa'] == true),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                  icon: Icons.visibility_outlined, 
                  label: "Ver detalle", 
                  color: AppTema.azulPrincipal,
                  onTap: () {}
                ),
                const SizedBox(width: 20),
                _actionButton(
                  icon: Icons.edit_outlined, 
                  label: "Editar", 
                  color: Colors.orange,
                  onTap: () => _showForm(c)
                ),
                const SizedBox(width: 20),
                _actionButton(
                  icon: Icons.delete_outline_rounded, 
                  label: "Eliminar", 
                  color: Colors.red,
                  onTap: () => _deleteCondition(c["id"])
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Mostrando 1 a $count de $count condiciones", 
            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
          Row(
            children: [
              _pageButton(Icons.chevron_left, null),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTema.azulPrincipal,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text("1", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              _pageButton(Icons.chevron_right, null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageButton(IconData icon, VoidCallback? onTap) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Icon(icon, size: 20, color: Colors.grey.shade300),
    );
  }

  Future<void> _deleteCondition(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Eliminar Condición", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: const Text("¿Deseas eliminar esta condición del catálogo maestro?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text("SÍ, ELIMINAR")),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _dio.delete("condiciones-nutricionales/$id");
      _loadData();
      if (mounted) NutriSnack.show(context, "Condición eliminada", ref: ref);
    } catch (_) {
      if (mounted) NutriSnack.show(context, "Error en la operación", isError: true, ref: ref);
    }
  }

  void _showForm([Map<String, dynamic>? condition]) {
    showDialog(
      context: context,
      builder: (ctx) => _ConditionFormDialog(
        initialCondition: condition,
        onSaved: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTema.verdeSalud : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? Icons.check_circle_outline : Icons.highlight_off, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            isActive ? "Activa" : "Inactiva",
            style: GoogleFonts.montserrat(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ConditionFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialCondition;
  final VoidCallback onSaved;
  const _ConditionFormDialog({this.initialCondition, required this.onSaved});
  @override
  State<_ConditionFormDialog> createState() => _ConditionFormDialogState();
}

class _ConditionFormDialogState extends State<_ConditionFormDialog> {
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  late bool _activa;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.initialCondition?["nombre"]);
    _descripcionController = TextEditingController(text: widget.initialCondition?["descripcion"]);
    _activa = widget.initialCondition?["activa"] ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.initialCondition != null ? "Editar Diagnóstico" : "Nuevo Diagnóstico", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController, 
              decoration: const InputDecoration(labelText: "Nombre de la Condición", filled: true, border: OutlineInputBorder())
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descripcionController, 
              decoration: const InputDecoration(labelText: "Descripción Detallada", filled: true, border: OutlineInputBorder()), 
              maxLines: 4
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Condición Activa"), 
              value: _activa, 
              onChanged: (v) => setState(() => _activa = v),
              activeColor: AppTema.verdeSalud,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
        FilledButton(
          onPressed: () => _save(ref), 
          style: FilledButton.styleFrom(backgroundColor: AppTema.azulPrincipal), 
          child: const Text("GUARDAR")
        ),
      ],
    ));
  }

  Future<void> _save(WidgetRef ref) async {
    if (_nombreController.text.isEmpty) return;
    try {
      final payload = { "nombre": _nombreController.text, "descripcion": _descripcionController.text, "activa": _activa };
      if (widget.initialCondition != null) {
        await ref.read(dioProvider).put("condiciones-nutricionales/${widget.initialCondition!['id']}", data: payload);
      } else {
        await ref.read(dioProvider).post("condiciones-nutricionales", data: payload);
      }
      widget.onSaved();
    } catch (_) {}
  }
}
