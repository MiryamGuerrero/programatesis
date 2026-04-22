import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../shared/models/app_role.dart';

// --- MODELOS ---
class MealSlot {
  final String mealType;
  final int momentId;
  List<dynamic> recipes;
  MealSlot({required this.mealType, required this.momentId, this.recipes = const []});
}

class PlanDay {
  final String day;
  final List<MealSlot> slots;
  PlanDay({required this.day, required this.slots});
}

class PlanManualPage extends ConsumerStatefulWidget {
  const PlanManualPage({super.key});

  @override
  ConsumerState<PlanManualPage> createState() => _PlanManualPageState();
}

class _PlanManualPageState extends ConsumerState<PlanManualPage> {
  Map<String, dynamic>? _selectedPatient;
  Map<String, dynamic>? _patientProfile;
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = false;
  
  List<PlanDay> _weeklyPlan = [];
  bool _planInitialized = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchPatients(""));
  }

  Future<void> _fetchPatients(String q) async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("buscar-pacientes", queryParameters: {"q": q});
      setState(() {
        _patients = List<Map<String, dynamic>>.from(res.data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onPatientSelected(Map<String, dynamic> patient) async {
    setState(() {
      _selectedPatient = patient;
      _isLoading = true;
    });
    
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("paciente-perfil/${patient["id"]}");
      setState(() => _patientProfile = res.data);
      _showConfigModal();
    } catch (e) {
      setState(() => _patientProfile = {
        "nombre": patient["nombre_completo"], 
        "sexo": "N/A", 
        "nutricional": "Sin evaluación",
        "clinico": "N/A",
        "temporal": "Ninguna",
        "alergias": "Ninguna", 
        "reglas_clinicas": [], 
        "reglas_nutricionales": []
      });
      _showConfigModal();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showConfigModal() {
    bool morningSnack = true;
    bool afternoonSnack = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Column(
            children: [
              Icon(Icons.settings_suggest, size: 40, color: Colors.blue),
              SizedBox(height: 12),
              Text("Configurar plan alimentario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModalSectionTitle("Tiempos obligatorios"),
                _buildConfigTile("Desayuno", "Principal", Icons.wb_twilight, true, null),
                _buildConfigTile("Almuerzo", "Principal", Icons.wb_sunny, true, null),
                _buildConfigTile("Merienda", "Principal", Icons.nightlight_round, true, null),
                const Divider(height: 32),
                _buildModalSectionTitle("Snacks opcionales"),
                _buildConfigTile("Snack media mañana", "Entre desayuno y almuerzo", Icons.coffee, morningSnack, (v) => setModalState(() => morningSnack = v!)),
                _buildConfigTile("Snack media tarde", "Entre almuerzo y cena", Icons.apple, afternoonSnack, (v) => setModalState(() => afternoonSnack = v!)),
              ],
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _initWeeklyTable(morningSnack, afternoonSnack);
                Navigator.pop(context);
              },
              child: const Text("Continuar y generar tabla"),
            )
          ],
        ),
      ),
    );
  }

  void _initWeeklyTable(bool morning, bool afternoon) {
    final days = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
    setState(() {
      _weeklyPlan = days.map((d) => PlanDay(
        day: d,
        slots: [
          MealSlot(mealType: "Desayuno", momentId: 1),
          if (morning) MealSlot(mealType: "Media mañana", momentId: 2),
          MealSlot(mealType: "Almuerzo", momentId: 3),
          if (afternoon) MealSlot(mealType: "Media tarde", momentId: 4),
          MealSlot(mealType: "Merienda", momentId: 5),
        ]
      )).toList();
      _planInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _selectedPatient != null) {
      return _buildBowlLoader();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _selectedPatient == null ? _buildPatientSelection() : _buildEditorLayout(),
    );
  }

  Widget _buildBowlLoader() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant, size: 80, color: Colors.orange), 
            const SizedBox(height: 24),
            Text("Calculando recetas seguras para ${_selectedPatient!["nombre_completo"]}...", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSelection() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Planificación Manual", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const Text("Selecciona un paciente de la lista para comenzar el diseño de su dieta.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Buscar paciente por nombre o cédula...",
                prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: _fetchPatients,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _patients.isEmpty 
                  ? const Center(child: Text("No se encontraron pacientes"))
                  : ListView.separated(
                      itemCount: _patients.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
                      itemBuilder: (context, index) {
                        final p = _patients[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.person, color: Colors.blue)),
                          title: Text(p["nombre_completo"] ?? "S/N", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("ID: ${p["id"]}"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _onPatientSelected(p),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorLayout() {
    return Column(
      children: [
        _buildEditorTopBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_patientProfile != null) 
                SizedBox(width: 300, child: _PatientProfileSidebar(profile: _patientProfile!))
              else
                const SizedBox(width: 300, child: Center(child: CircularProgressIndicator())),
              Expanded(child: _buildWeeklyBoard()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () => setState(() => _selectedPatient = null)),
          const SizedBox(width: 8),
          Expanded(child: Text("Diseñando Plan: ${_selectedPatient!["nombre_completo"]}", overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _showConfigModal, icon: const Icon(Icons.tune, size: 14), label: const Text("Ajustar")),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _savePlan(replicate: true), 
            icon: const Icon(Icons.auto_mode, size: 16), 
            label: const Text("Guardar Mes"),
            style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade700),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _savePlan(replicate: false), 
            icon: const Icon(Icons.check, size: 16), 
            label: const Text("Semana"),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBoard() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _weeklyPlan.length,
      itemBuilder: (context, idx) => _DayCard(
        day: _weeklyPlan[idx],
        onAdd: (slotIdx) => _openRecipePicker(idx, slotIdx),
        onRemove: (slotIdx, rIdx) => setState(() => _weeklyPlan[idx].slots[slotIdx].recipes.removeAt(rIdx)),
        onDuplicate: () => _duplicateDay(idx),
      ),
    );
  }

  void _openRecipePicker(int dIdx, int sIdx) {
    final slot = _weeklyPlan[dIdx].slots[sIdx];
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecipePicker(
        idPaciente: _selectedPatient!["id"],
        momentId: slot.momentId,
        mealType: slot.mealType,
        dayName: _weeklyPlan[dIdx].day,
        onSelected: (r) => setState(() => slot.recipes = [r]), // Solo una por slot para simplificar
      ),
    );
  }

  void _duplicateDay(int idx) {
    if (idx >= 6) return;
    setState(() {
      for (int i = 0; i < _weeklyPlan[idx].slots.length; i++) {
        _weeklyPlan[idx + 1].slots[i].recipes = List.from(_weeklyPlan[idx].slots[i].recipes);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Día duplicado exitosamente")));
  }

  void _savePlan({bool replicate = true}) async {
    // Validar que al menos haya una receta por slot
    for (var d in _weeklyPlan) {
      for (var s in d.slots) {
        if (s.recipes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.orange, content: Text("Falta receta en ${d.day} - ${s.mealType}")));
          return;
        }
      }
    }
    
    final data = {
      for (var d in _weeklyPlan)
        d.day: { for (var s in d.slots) s.mealType: s.recipes.first }
    };

    try {
      final dio = ref.read(dioProvider);
      await dio.post("plan-manual", data: {
        "id_paciente": _selectedPatient!["id"],
        "plan": data,
        "replicate": replicate
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("✅ Plan guardado y activado")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
    }
  }

  Widget _buildModalSectionTitle(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.blueGrey, letterSpacing: 1.1)));
  
  Widget _buildConfigTile(String title, String desc, IconData icon, bool value, ValueChanged<bool?>? onChanged) {
    return ListTile(
      leading: Icon(icon, color: value ? Colors.orange : Colors.grey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
      trailing: onChanged == null ? const Icon(Icons.check_circle, color: Colors.green) : Checkbox(value: value, onChanged: onChanged),
    );
  }
}

class _DayCard extends StatelessWidget {
  final PlanDay day;
  final Function(int) onAdd;
  final Function(int, int) onRemove;
  final VoidCallback onDuplicate;

  const _DayCard({required this.day, required this.onAdd, required this.onRemove, required this.onDuplicate});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 16), 
              const SizedBox(width: 12), 
              Text(day.day, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton.icon(onPressed: onDuplicate, icon: const Icon(Icons.copy, size: 14, color: Colors.white70), label: const Text("Duplicar al siguiente", style: TextStyle(color: Colors.white70, fontSize: 12))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12, runSpacing: 12,
              children: day.slots.asMap().entries.map((e) => _buildSlot(e.key, e.value)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(int idx, MealSlot s) {
    final has = s.recipes.isNotEmpty;
    return Container(
      width: 180,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: has ? Colors.blue.shade100 : Colors.orange.shade100)),
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(6), width: double.infinity, decoration: BoxDecoration(color: has ? Colors.blue.shade50 : Colors.orange.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))), child: Text(s.mealType, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: has ? Colors.blue : Colors.orange.shade900))),
          if (!has)
            InkWell(
              onTap: () => onAdd(idx),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const Icon(Icons.add_circle, color: Colors.orange, size: 28),
                    const SizedBox(height: 4),
                    const Text("Agregar receta", style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ...s.recipes.asMap().entries.map((re) => ListTile(
              dense: true, visualDensity: VisualDensity.compact,
              title: Text(re.value["nombre"], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.close, size: 14, color: Colors.red), onPressed: () => onRemove(idx, re.key)),
            )),
          if (has) IconButton(onPressed: () => onAdd(idx), icon: const Icon(Icons.refresh, size: 16, color: Colors.blueGrey), tooltip: "Cambiar receta"),
        ],
      ),
    );
  }
}

class _RecipePicker extends ConsumerStatefulWidget {
  final String idPaciente;
  final int momentId;
  final String mealType;
  final String dayName;
  final Function(Map<String, dynamic>) onSelected;
  const _RecipePicker({required this.idPaciente, required this.momentId, required this.mealType, required this.dayName, required this.onSelected});

  @override
  ConsumerState<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends ConsumerState<_RecipePicker> {
  List<dynamic> _recipes = [];
  List<dynamic> _filtered = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post("recetas-permitidas", data: {
        "id_paciente": widget.idPaciente,
        "id_momento": widget.momentId
      });
      if (mounted) {
        setState(() { 
          _recipes = res.data["recetas"] ?? []; 
          _filtered = _recipes;
          _loading = false; 
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Seleccionar Receta Segura", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  Text("${widget.dayName} • ${widget.mealType}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() {
                _filtered = _recipes.where((r) => r["nombre"].toString().toLowerCase().contains(v.toLowerCase())).toList();
              }),
              decoration: InputDecoration(hintText: "Filtrar por nombre...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) 
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _filtered.length,
                itemBuilder: (context, i) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.restaurant, color: Colors.orange),
                    title: Text(_filtered[i]["nombre"], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_filtered[i]["recomendacion"] ?? "Permitida", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.add_circle, color: Colors.blue),
                    onTap: () { widget.onSelected(_filtered[i]); Navigator.pop(context); },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PatientProfileSidebar extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _PatientProfileSidebar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: CircleAvatar(radius: 30, backgroundColor: Colors.blue.shade50, child: const Icon(Icons.person, color: Colors.blue))),
            const SizedBox(height: 12),
            Center(child: Text(profile["nombre"] ?? "N/A", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Center(child: Text("${profile["sexo"] ?? 'N/A'}", style: const TextStyle(color: Colors.grey, fontSize: 12))),
            const Divider(height: 32),
            _info("Estado Nutricional", profile["nutricional"] ?? "Sin evaluación", Colors.blue),
            _info("Condición Clínica", profile["clinico"] ?? "N/A", Colors.red),
            _info("Temporales", profile["temporal"] ?? "Ninguna", Colors.orange),
            _info("Alergias", profile["alergias"] ?? "Ninguna", Colors.orangeAccent),
            const SizedBox(height: 12),
            const Text("Restricciones Activas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _rule("Médicas", List<String>.from(profile["reglas_clinicas"] ?? []), Colors.purple),
            _rule("Nutricionales", List<String>.from(profile["reglas_nutricionales"] ?? []), Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _info(String l, String v, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.toUpperCase(), style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
  
  Widget _rule(String t, List<String> rs, Color c) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 10)),
      if (rs.isEmpty) const Text("• Ninguna", style: TextStyle(fontSize: 10, color: Colors.grey)),
      ...rs.map((r) => Text("• $r", style: const TextStyle(fontSize: 10))),
    ]),
  );
}
