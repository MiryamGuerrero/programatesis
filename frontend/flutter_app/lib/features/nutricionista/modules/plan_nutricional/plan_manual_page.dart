import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/nutri_avatar.dart';
import '../../../../shared/widgets/layout_components.dart';

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
  static const Color greenBrand = Color(0xFF2E7D32);
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
      final res = await dio.get("pacientes/${patient['id']}/expediente-completo");
      setState(() => _patientProfile = res.data);
      _showConfigModal();
    } catch (e) {
      setState(() => _patientProfile = {
        "paciente": {
          "nombre_completo": patient["nombre_completo"],
          "id": patient["id"]
        },
        "diagnostico": {},
        "ultimo_control": {},
        "alergias": {"subgrupos": [], "ingredientes": []},
        "es_intolerante_lactosa": false
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
            Text(
              "Calculando recetas seguras para ${_selectedPatient!["nombre_completo"]}...",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
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
                          title: Text(p["nombre_completo"]?.toString() ?? "S/N", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                SizedBox(
                  width: 350, 
                  child: _PatientProfileSidebar(
                    expediente: _patientProfile!,
                    greenBrand: greenBrand,
                    formatEdad: _formatEdad,
                    summaryItem: _summaryItem,
                    onVerExpediente: _mostrarExpedienteMaestroDialog,
                  )
                )
              else
                const SizedBox(width: 350, child: Center(child: CircularProgressIndicator())),
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

  String _formatEdad(String? fechaNac) {
    if (fechaNac == null) return "-";
    try {
      final birthDate = DateTime.parse(fechaNac);
      final now = DateTime.now();
      int years = now.year - birthDate.year;
      int months = now.month - birthDate.month;
      if (now.day < birthDate.day) months--;
      if (months < 0) { years--; months += 12; }
      return "$years años y $months meses";
    } catch (_) { return "-"; }
  }

  Widget _summaryItem(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.blueGrey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarExpedienteMaestroDialog() {
    if (_patientProfile == null) return;
    final p = _patientProfile!['paciente'] ?? {};
    final t = _patientProfile!['tutor'] ?? {};
    final d = _patientProfile!['diagnostico'] ?? {};
    final c = _patientProfile!['ultimo_control'] ?? {};
     
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: 900,
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.assignment_ind_outlined, color: greenBrand, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("EXPEDIENTE MAESTRO INTEGRAL", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 20)),
                  Text("Registro oficial del paciente en el sistema ReumaNutri", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
              const Spacer(),
              IconButton.filledTonal(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close))
            ]),
            const Divider(height: 48),
            Flexible(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildExpSection("1. IDENTIDAD DEL PACIENTE", [
                      _expItem("Nombres Completos", p['nombre_completo']),
                      _expItem("Cédula / ID", p['cedula']),
                      _expItem("Fecha de Nacimiento", p['fecha_nacimiento']),
                      _expItem("Sexo Biológico", p['sexo_nombre']),
                      const SizedBox(height: 16),
                      const Text("LOCALIZACIÓN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _expItem("Cantón de Residencia", p['canton_nombre']),
                      _expItem("Parroquia", p['parroquia_nombre']),
                    ])),
                    const SizedBox(width: 40),
                    Expanded(child: _buildExpSection("2. REPRESENTANTE LEGAL", [
                      _expItem("Nombre del Tutor", t['nombre_completo']),
                      _expItem("Cédula del Tutor", t['cedula']),
                      _expItem("Parentesco", t['parentesco_nombre']),
                      const SizedBox(height: 16),
                      const Text("CONTACTO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _expItem("Correo Electrónico", t['email']),
                      _expItem("Teléfono / Móvil", t['telefono']),
                      _expItem("Dirección de Domicilio", t['direccion']),
                    ])),
                    const SizedBox(width: 40),
                    Expanded(child: _buildExpSection("3. ESTADO CLÍNICO ACTUAL", [
                      _expItem("Diagnóstico Principal", d['condicion_nombre'] ?? "AIJ"),
                      _expItem("Estado Nutricional (OMS)", c['estado_nutricional'], isBold: true),
                      _expItem("Peso / Talla", "${c['peso_kg'] ?? '-'} kg / ${c['talla_cm'] ?? '-'} cm"),
                      _expItem("Inflamación Actual", "${c['escala_inflamacion'] ?? 0}/3"),
                      _expItem("Brote Activo", (c['en_brote'] == true) ? "SÍ (ACTIVO)" : "NO", isAlert: c['en_brote'] == true),
                      const SizedBox(height: 16),
                      const Text("SEGUIMIENTO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _expItem("Fecha de Último Control", c['fecha_control']),
                      _expItem("Próxima Cita Programada", c['fecha_proxima_cita']),
                    ])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.check_circle_outline), label: const Text("ENTENDIDO"), style: FilledButton.styleFrom(backgroundColor: greenBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 20)))),
            ])
          ]),
        ),
      ),
    );
  }

  Widget _buildExpSection(String title, List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: greenBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: greenBrand, letterSpacing: 0.5)),
    ),
    const SizedBox(height: 24), 
    ...items
  ]);

  Widget _expItem(String l, dynamic v, {bool isBold = false, bool isAlert = false, bool isHighlight = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 16), 
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(l, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.2)), 
        const SizedBox(height: 4),
        Text(
          v?.toString() ?? "NO REGISTRADO", 
          style: GoogleFonts.montserrat(
            fontSize: 13, 
            fontWeight: (isBold || isAlert) ? FontWeight.w900 : FontWeight.w600,
            color: isAlert ? Colors.red : (isHighlight ? greenBrand : const Color(0xFF1E293B)),
          )
        )
      ]
    )
  );
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
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.add_circle, color: Colors.orange, size: 28),
                    SizedBox(height: 4),
                    Text("Agregar receta", style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ...s.recipes.asMap().entries.map((re) => ListTile(
              dense: true, visualDensity: VisualDensity.compact,
              title: Text(re.value["nombre"]?.toString() ?? "Receta", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
                    title: Text(_filtered[i]["nombre"]?.toString() ?? "Receta", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_filtered[i]["recomendacion"]?.toString() ?? "Permitida", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
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
  final Map<String, dynamic> expediente;
  final Color greenBrand;
  final String Function(String?) formatEdad;
  final Widget Function(String, String, IconData, {Color? color}) summaryItem;
  final VoidCallback onVerExpediente;

  const _PatientProfileSidebar({
    required this.expediente,
    required this.greenBrand,
    required this.formatEdad,
    required this.summaryItem,
    required this.onVerExpediente,
  });

  @override
  Widget build(BuildContext context) {
    final p = expediente['paciente'] ?? {};
    final d = expediente['diagnostico'] ?? {};
    final c = expediente['ultimo_control'] ?? {};
    final al = expediente['alergias'] ?? {};
     
    final lactosa = expediente['es_intolerante_lactosa'] == true;
    final subgrupos = (al['subgrupos'] as List? ?? []).map((e) => e['nombre']).join(", ");
    final ingredientes = (al['ingredientes'] as List? ?? []).map((e) => e['nombre']).join(", ");

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  NutriAvatar(nombreCompleto: p['nombre_completo'] ?? "P", radio: 40),
                  const SizedBox(height: 16),
                  Text("RESUMEN CLÍNICO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 10, color: greenBrand, letterSpacing: 2)),
                ],
              ),
            ),
            const Divider(height: 48),
            summaryItem("ENFERMEDAD PRINCIPAL", d['condicion_nombre'] ?? d['nombre_condicion'] ?? "-", Icons.medical_services_outlined),
            summaryItem("EDAD", formatEdad(p['fecha_nacimiento']), Icons.cake_outlined),
            summaryItem("ESTADO NUTRICIONAL", c['estado_nutricional'] ?? "PENDIENTE", Icons.analytics_outlined, color: greenBrand),
            summaryItem("TALLA ACTUAL", "${c['talla_cm'] ?? '-'} cm", Icons.height_rounded),
            const Divider(height: 48),
            summaryItem("INTOLERANTE A LACTOSA", lactosa ? "SÍ" : "NO", Icons.opacity, color: lactosa ? Colors.red : greenBrand),
            summaryItem("ALERGIAS (SUBGRUPOS)", subgrupos.isEmpty ? "NINGUNA" : subgrupos, Icons.warning_amber_rounded, color: subgrupos.isEmpty ? Colors.grey : Colors.orange),
            summaryItem("ALERGIAS (ESPECÍFICAS)", ingredientes.isEmpty ? "NINGUNA" : ingredientes, Icons.security_rounded, color: ingredientes.isEmpty ? Colors.grey : Colors.orange),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onVerExpediente,
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text("VER EXPEDIENTE MAESTRO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenBrand,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
