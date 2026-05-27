import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/nutri_avatar.dart';
import '../../../../shared/widgets/patient_summary_panel.dart';
import '../../../../shared/widgets/layout_components.dart';

// --- MODELOS ---
class MealSlot {
  final String mealType;
  final int momentId;
  List<dynamic> recipes;
  MealSlot(
      {required this.mealType,
      required this.momentId,
      this.recipes = const []});
}

class PlanDay {
  final DateTime date;
  final List<MealSlot> slots;
  PlanDay({required this.date, required this.slots});
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
  Map<String, dynamic>? _planVigente;
  List<Map<String, dynamic>> _patients = [];
  List<dynamic> _patientPlans = []; // Historial de planes
  bool _isLoading = false;
  bool _viewingHistory = true; // Nueva bandera de estado
  bool _recomendadorAbierto = false;

  List<PlanDay> _weeklyPlan = [];
  bool _planInitialized = false;

  String _durationType = "una semana";
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 6));
  DateTime _calendarViewDate = DateTime.now();

  bool _morningSnackEnabled = false;
  bool _afternoonSnackEnabled = false;
  List<int> _boostersSeleccionados = [];
  List<Map<String, dynamic>> _ingredientesSegurosCache = [];
  List<Map<String, dynamic>> _recomendacionesCache = [];

  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = "Todos";
  final List<String> _filters = [
    "Todos",
    "Plan activo",
    "No activo",
    "Validación nutricional confirmada",
    "Validación nutricional pendiente"
  ];

  int _calcularEdad(dynamic fechaNacimiento) {
    if (fechaNacimiento == null) return 0;
    try {
      final birthDate = DateTime.parse(fechaNacimiento.toString());
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

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

  void _calculateSmartDates(List planes, {Map<String, dynamic>? planVigente}) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    DateTime latestEnd = todayOnly;
    for (var p in planes) {
      final rawFin = p["fecha_fin"];
      if (rawFin == null) continue;
      try {
        final fFin = DateTime.parse(rawFin.toString());
        if (fFin.isAfter(latestEnd)) latestEnd = fFin;
      } catch (_) {}
    }
    final rawPlanVigenteFin = planVigente?["fecha_fin"];
    if (rawPlanVigenteFin != null) {
      try {
        final vigFin = DateTime.parse(rawPlanVigenteFin.toString());
        if (vigFin.isAfter(latestEnd)) latestEnd = vigFin;
      } catch (_) {}
    }
    _startDate = latestEnd.add(const Duration(days: 1));

    _endDate = _startDate.add(const Duration(days: 6));
    _calendarViewDate = _startDate;
  }

  List<Map<String, dynamic>> get _patientsFiltrados {
    final filtro = _selectedFilter;
    return _patients.where((p) {
      final planActivo = p["plan_activo"] == true;
      final validacionConfirmada = p["validacion_confirmada"] == true;

      switch (filtro) {
        case "Plan activo":
          return planActivo;
        case "No activo":
          return !planActivo;
        case "ValidaciÃ³n nutricional confirmada":
          return validacionConfirmada;
        case "ValidaciÃ³n nutricional pendiente":
          return !validacionConfirmada;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _onPatientSelected(Map<String, dynamic> patient) async {
    setState(() {
      _selectedPatient = patient;
      _viewingHistory = true;
      _isLoading = true;
    });

    try {
      final dio = ref.read(dioProvider);
      final prefetch = await dio.get(
        "pacientes/${patient['id']}/prefetch-planificacion",
        queryParameters: {"include_ingredientes": false},
      );
      final payload = (prefetch.data ?? {}) as Map<String, dynamic>;
      _patientProfile = (payload["expediente"] ?? {}) as Map<String, dynamic>;
      _planVigente = (payload["plan_vigente"] ?? {}) as Map<String, dynamic>?;
      _ingredientesSegurosCache = List<Map<String, dynamic>>.from(
          payload["ingredientes_seguros"] ?? []);
      _recomendacionesCache = List<Map<String, dynamic>>.from(
          payload["ingredientes_recomendados"] ?? []);
      if (_recomendacionesCache.isEmpty) {
        try {
          final recoRes =
              await dio.get("ingredientes/recomendados/${patient['id']}");
          _recomendacionesCache =
              List<Map<String, dynamic>>.from(recoRes.data ?? []);
        } catch (_) {}
      }
      _boostersSeleccionados = _recomendacionesCache
          .map((r) => (r["id_ingrediente"] as num?)?.toInt())
          .whereType<int>()
          .toList();

      final estadoValidacion =
          (payload["estado_validacion"] ?? {}) as Map<String, dynamic>;
      final mostrarModal = estadoValidacion["mostrar_modal"] == true;
      if (mostrarModal) {
        await _mostrarModalValidacionClinica(patient['id'].toString());
        final estadoRevalidado = await dio.get(
          "pacientes/${patient['id']}/control-mensual-actual/estado-validacion",
        );
        if (estadoRevalidado.data?["mostrar_modal"] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.redAccent,
                content: Text(
                    "Debes confirmar el estado nutricional antes de continuar."),
              ),
            );
          }
          setState(() {
            _selectedPatient = null;
            _patientProfile = null;
            _isLoading = false;
          });
          return;
        }
      }

      final resPlanes = await dio.get("pacientes/${patient['id']}/planes");
      final List planes = List.from(resPlanes.data);

      setState(() {
        _patientPlans = planes;
        _planInitialized = false;
        _calculateSmartDates(planes, planVigente: _planVigente);
      });
    } catch (e) {
      // Manejo fallback
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _modalRecomendacionesNutri(String idPaciente) async {
    final dio = ref.read(dioProvider);
    List<Map<String, dynamic>> seguros = _ingredientesSegurosCache;
    if (seguros.isEmpty) {
      try {
        final seg = await dio.get(
          "ingredientes/buscar-para-paciente/$idPaciente",
          queryParameters: {"q": "", "limit": 300},
        );
        seguros = List<Map<String, dynamic>>.from(seg.data ?? []);
      } catch (_) {}
    }

    final Set<int> seleccion = {..._boostersSeleccionados};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return AlertDialog(
            title: const Text("Seleccionar ingredientes recomendados"),
            content: SizedBox(
              width: 760,
              height: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Selecciona ingredientes seguros para potenciar este plan (Nutricionista):"),
                  const SizedBox(height: 8),
                  Expanded(
                    child: seguros.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Text(
                              "No hay ingredientes seguros disponibles para recomendar en este momento.\n\n"
                              "Posibles causas:\n"
                              "- Alergias/restricciones del paciente demasiado amplias.\n"
                              "- No existen ingredientes activos compatibles en el catalogo.\n"
                              "- Faltan datos clinicos actualizados para filtrar correctamente.",
                              style: TextStyle(fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            itemCount: seguros.length,
                            itemBuilder: (_, i) {
                              final ing = seguros[i];
                              final idIng = (ing["id"] as num?)?.toInt() ?? -1;
                              if (idIng <= 0) return const SizedBox.shrink();
                              final nombre = (ing["nombre"] ?? "-").toString();
                              return CheckboxListTile(
                                value: seleccion.contains(idIng),
                                onChanged: (v) {
                                  setModal(() {
                                    if (v == true) {
                                      seleccion.add(idIng);
                                    } else {
                                      seleccion.remove(idIng);
                                    }
                                  });
                                },
                                title: Text(nombre),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar")),
              FilledButton(
                onPressed: () async {
                  setState(() => _boostersSeleccionados = seleccion.toList());
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _aplicarPotenciadoresAutomaticos(idPaciente);
                },
                child: const Text("Aplicar al plan"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _abrirRecomendadorIngredientes() async {
    if (_selectedPatient == null || _isLoading || _recomendadorAbierto) return;
    setState(() => _recomendadorAbierto = true);
    try {
      await _modalRecomendacionesNutri(_selectedPatient!["id"].toString());
    } finally {
      if (mounted) {
        setState(() => _recomendadorAbierto = false);
      } else {
        _recomendadorAbierto = false;
      }
    }
  }

  Future<void> _aplicarPotenciadoresAutomaticos(String idPaciente) async {
    final dio = ref.read(dioProvider);
    int errores = 0;
    final idsValidos =
        _boostersSeleccionados.where((id) => id > 0).toSet().toList();
    for (final idIngrediente in idsValidos) {
      try {
        await dio.post(
          "ingredientes/recomendar",
          data: {
            "id_paciente": idPaciente,
            "id_ingrediente": idIngrediente,
            "motivo": "Potenciador de plan recomendado por nutricionista",
            "prioridad": 3,
          },
        );
      } catch (_) {
        errores += 1;
      }
    }
    try {
      final res = await dio.get("ingredientes/recomendados/$idPaciente");
      if (!mounted) return;
      setState(() {
        _recomendacionesCache = List<Map<String, dynamic>>.from(res.data ?? []);
        _boostersSeleccionados = _recomendacionesCache
            .map((r) => (r["id_ingrediente"] as num?)?.toInt())
            .whereType<int>()
            .toList();
      });
    } catch (_) {}
    if (!mounted) return;
    if (errores > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Se omitieron $errores recomendaciones no válidas para este paciente.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Recomendaciones guardadas correctamente.")),
      );
    }
  }

  Future<void> _mostrarModalValidacionClinica(String idPaciente) async {
    if (_patientProfile == null) return;
    final dio = ref.read(dioProvider);
    final ultimoControl =
        (_patientProfile!["ultimo_control"] ?? {}) as Map<String, dynamic>;
    final paciente =
        (_patientProfile!["paciente"] ?? {}) as Map<String, dynamic>;
    final condicionesResp = await dio.get("condiciones-nutricionales");
    final List<Map<String, dynamic>> condiciones =
        List<Map<String, dynamic>>.from(condicionesResp.data ?? []);
    final condicionesPeso = _filtrarCondicionesPeso(condiciones);
    final condicionesTalla = _filtrarCondicionesTalla(condiciones);

    final pesoCtrl = TextEditingController(
        text: (ultimoControl["peso_kg"] ?? "").toString());
    final tallaCtrl = TextEditingController(
        text: (ultimoControl["talla_cm"] ?? "").toString());
    int? condicionPesoId =
        (ultimoControl["id_condicion_nutricional_resultado"] as num?)?.toInt();
    int? condicionTallaId;
    final edadLabel = _formatEdad(paciente["fecha_nacimiento"]?.toString());

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: const Text("Validar datos clínicos del paciente"),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Diagnostico: ${_patientProfile?["diagnostico"]?["condicion_nombre"] ?? "No registrado"}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text("Edad actual: $edadLabel",
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pesoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: "Peso (kg)"),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tallaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: "Talla (cm)"),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: condicionPesoId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: "Condición nutricional - Peso"),
                        items: condicionesPeso
                            .map((c) => DropdownMenuItem<int>(
                                  value: (c["id"] as num).toInt(),
                                  child: Text(
                                      c["nombre"]?.toString() ?? "Condición"),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => condicionPesoId = v),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: condicionTallaId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: "Condición nutricional - Talla"),
                        items: condicionesTalla
                            .map((c) => DropdownMenuItem<int>(
                                  value: (c["id"] as num).toInt(),
                                  child: Text(
                                      c["nombre"]?.toString() ?? "Condición"),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => condicionTallaId = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await dio.post(
                        "pacientes/$idPaciente/control-mensual-actual/confirmar");
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text("Dejar como está"),
                ),
                FilledButton(
                  onPressed: () async {
                    final peso = double.tryParse(pesoCtrl.text.trim());
                    final talla = double.tryParse(tallaCtrl.text.trim());
                    if (peso == null ||
                        talla == null ||
                        condicionPesoId == null ||
                        condicionTallaId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Completa peso, talla y las 2 condiciones.")),
                      );
                      return;
                    }
                    await dio.put(
                      "pacientes/$idPaciente/control-mensual-actual",
                      data: {
                        "peso_kg": peso,
                        "talla_cm": talla,
                        "id_condicion_nutricional_peso": condicionPesoId,
                        "id_condicion_nutricional_talla": condicionTallaId,
                      },
                    );
                    final resExpNuevo = await dio
                        .get("pacientes/$idPaciente/expediente-completo");
                    if (mounted) {
                      setState(() => _patientProfile = resExpNuevo.data);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text("Actualizar datos"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePlan(int id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete("planes/$id");
      if (mounted) {
        setState(() => _patientPlans.removeWhere((p) => p["id"] == id));
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Plan eliminado correctamente")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
    }
  }

  Future<void> _startNewPlan() async {
    if (_selectedPatient == null) return;
    setState(() {
      _viewingHistory = false;
      _planInitialized = false;
      _weeklyPlan = []; // Limpiar plan previo
      _calculateSmartDates(_patientPlans,
          planVigente: _planVigente); // Recalcular fechas para el nuevo plan
    });
    _showConfigModal();
  }

  Future<void> _verDetallePlan(Map<String, dynamic> plan) async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("planes/${plan['id']}");
      final List items =
          res.data; // [{fecha, id_momento, id_receta, nombre_receta}]

      // 1. Agrupar por fecha
      final Map<String, List<Map<String, dynamic>>> group = {};
      for (var it in items) {
        final f = it["fecha"].toString();
        if (!group.containsKey(f)) group[f] = [];
        group[f]!.add(it);
      }

      final List<PlanDay> reconstructed = [];
      final sortedDates = group.keys.toList()..sort();

      for (var fStr in sortedDates) {
        final date = DateTime.parse(fStr);
        final dayItems = group[fStr]!;

        final List<MealSlot> slots = [];
        // Determinar snacks habilitados
        bool hasM = dayItems.any((i) => i["id_momento"] == 2);
        bool hasT = dayItems.any((i) => i["id_momento"] == 4);

        slots.add(MealSlot(
            mealType: "Desayuno",
            momentId: 1,
            recipes: _findRecipe(dayItems, 1)));
        if (hasM)
          slots.add(MealSlot(
              mealType: "Media mañana",
              momentId: 2,
              recipes: _findRecipe(dayItems, 2)));
        slots.add(MealSlot(
            mealType: "Almuerzo",
            momentId: 3,
            recipes: _findRecipe(dayItems, 3)));
        if (hasT)
          slots.add(MealSlot(
              mealType: "Media tarde",
              momentId: 4,
              recipes: _findRecipe(dayItems, 4)));
        slots.add(MealSlot(
            mealType: "Merienda",
            momentId: 5,
            recipes: _findRecipe(dayItems, 5)));

        reconstructed.add(PlanDay(date: date, slots: slots));
      }

      setState(() {
        _weeklyPlan = reconstructed;
        _viewingHistory = false;
        _planInitialized = true;
        _startDate = reconstructed.first.date;
        _endDate = reconstructed.last.date;
        _morningSnackEnabled =
            reconstructed.any((d) => d.slots.any((s) => s.momentId == 2));
        _afternoonSnackEnabled =
            reconstructed.any((d) => d.slots.any((s) => s.momentId == 4));
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al cargar plan: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _findRecipe(List<dynamic> items, int momentId) {
    final match = items.where((i) => i["id_momento"] == momentId).toList();
    if (match.isEmpty) return [];
    return match
        .map((item) => {
              "id": item["id_receta"],
              "nombre": item["nombre_receta"],
              "imagen_url": item["imagen_url"],
              "semaforo": item["semaforo"] ?? "neutral",
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _selectedPatient == null
          ? _buildPatientSelection()
          : (_viewingHistory ? _buildHistoryLayout() : _buildEditorLayout()),
    );

    if (_isLoading && _selectedPatient != null) {
      return Stack(
        children: [
          body,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.white.withOpacity(0.70),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return body;
  }

  Widget _buildPatientSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Planificación nutricional manual",
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Selecciona un paciente para crear, revisar o actualizar su plan nutricional personalizado.",
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          // Buscador
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _fetchPatients,
              decoration: InputDecoration(
                hintText: "Buscar paciente por nombre, cédula o teléfono...",
                hintStyle:
                    GoogleFonts.montserrat(color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Filtros
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final f = _filters[index];
                final isSelected = _selectedFilter == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilter = f);
                  },
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          // Listado de pacientes
          if (_isLoading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ))
          else if (_patientsFiltrados.isEmpty)
            const Center(child: Text("No se encontraron pacientes"))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _patientsFiltrados.length,
              itemBuilder: (context, index) {
                return _buildPatientCard(_patientsFiltrados[index], index);
              },
            ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String nombre) {
    final colors = [
      const Color(0xFFEFF6FF), // Blue
      const Color(0xFFF5F3FF), // Purple
      const Color(0xFFECFDF5), // Green
      const Color(0xFFFFF7ED), // Orange
    ];
    return colors[nombre.length % colors.length];
  }

  Color _getTextColor(String nombre) {
    final colors = [
      const Color(0xFF2563EB), // Blue
      const Color(0xFF7C3AED), // Purple
      const Color(0xFF059669), // Green
      const Color(0xFFD97706), // Orange
    ];
    return colors[nombre.length % colors.length];
  }

  Widget _buildPatientCard(Map<String, dynamic> p, int index) {
    final String nombre = p["nombre_completo"]?.toString() ?? "Sin nombre";
    final int edad = p["edad_anios"] != null
        ? (p["edad_anios"] as num).toInt()
        : _calcularEdad(p["fecha_nacimiento"]);
    final String genero =
        (p["id_sexo"] == 1 || p["id_sexo"] == "1") ? "Masculino" : "Femenino";

    final String diagnostico = p["enfermedad_principal"] ?? "No registrado";
    final String condicionNutri = p["condicion_nutricional"] ?? "Desconocida";

    // Asumimos inactivo o no validado hasta que se implementen flags reales en backend
    final bool planActivo = p["plan_activo"] == true;
    final bool validacionConfirmada = p["validacion_confirmada"] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _onPatientSelected(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                NutriAvatar(
                  nombreCompleto: nombre,
                  radio: 26,
                  colorFondo: _getAvatarColor(nombre),
                  colorTexto: _getTextColor(nombre),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        "$edad años  •  $genero",
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoItem(Icons.medical_services_outlined,
                              "Diagnóstico: $diagnostico"),
                          const SizedBox(width: 16),
                          _buildInfoItem(Icons.monitor_weight_outlined,
                              "Estado Nutricional: $condicionNutri"),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBadge(
                      planActivo ? "Plan activo" : "No activo",
                      planActivo
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBadge(
                      validacionConfirmada
                          ? "Validación nutricional confirmada"
                          : "Validación nutricional pendiente",
                      validacionConfirmada
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                OutlinedButton.icon(
                  onPressed: () => _onPatientSelected(p),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text("Crear plan"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF22C55E),
                    side:
                        const BorderSide(color: Color(0xFF22C55E), width: 1.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF94A3B8), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.montserrat(
            color: const Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    IconData icon;
    if (text == "Plan activo") {
      icon = Icons.check_circle_outline;
    } else if (text == "Validación nutricional confirmada") {
      icon = Icons.verified_user_outlined;
    } else if (text == "No activo") {
      icon = Icons.remove_circle_outline;
    } else {
      icon = Icons.access_time;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.montserrat(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryLayout() {
    return Row(
      children: [
        // Sidebar
        if (_patientProfile != null)
          PatientSummaryPanel(
            expediente: _patientProfile!,
            formatEdad: _formatEdad,
            onVerExpediente: _mostrarExpedienteMaestroDialog,
          )
        else
          const SizedBox(
              width: 320, child: Center(child: CircularProgressIndicator())),

        // Contenido Historial
        Expanded(
          child: Column(
            children: [
              _buildHistoryTopBar(),
              _buildWorkflowSections(),
              Expanded(
                child: Container(
                  color: const Color(0xFFF1F5F9),
                  child: _patientPlans.isEmpty
                      ? _buildEmptyHistoryState()
                      : _buildHistoryList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => setState(() => _selectedPatient = null),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Historial de Planes Nutricionales",
                    style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: const Color(0xFF0F172A))),
                Text("Paciente: ${_selectedPatient!["nombre_completo"]}",
                    style:
                        const TextStyle(color: Colors.blueGrey, fontSize: 13)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _startNewPlan,
            icon: const Icon(Icons.add_rounded),
            label: const Text("Seccion Plan Manual",
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: greenBrand,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _abrirRecomendadorIngredientes,
            icon: const Icon(Icons.eco_outlined),
            label: const Text("Seccion Recomendador"),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowSections() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: _buildWorkflowCard(
              title: "Seccion Plan Manual",
              description:
                  "Arma o ajusta el plan nutricional completo del paciente.",
              icon: Icons.calendar_month_rounded,
              primary: true,
              onTap: _startNewPlan,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildWorkflowCard(
              title: "Seccion Recomendador",
              description:
                  "Selecciona ingredientes seguros para potenciar el algoritmo.",
              icon: Icons.eco_outlined,
              primary: false,
              onTap: _abrirRecomendadorIngredientes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowCard({
    required String title,
    required String description,
    required IconData icon,
    required bool primary,
    required VoidCallback onTap,
  }) {
    final bg = primary ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9);
    final border =
        primary ? greenBrand.withOpacity(0.35) : const Color(0xFFCBD5E1);
    final iconBg = primary ? greenBrand : const Color(0xFF0F172A);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.blueGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_edu_rounded,
              size: 80, color: Colors.blueGrey.shade200),
          const SizedBox(height: 24),
          const Text("No hay planes previos registrados",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey)),
          const SizedBox(height: 8),
          const Text(
              "Comienza diseñando el primer plan alimentario para este paciente.",
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton.icon(
                  onPressed: _startNewPlan,
                  icon: const Icon(Icons.add),
                  label: const Text("Seccion Plan Manual")),
              OutlinedButton.icon(
                onPressed: _abrirRecomendadorIngredientes,
                icon: const Icon(Icons.eco_outlined),
                label: const Text("Seccion Recomendador"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(40),
      itemCount: _patientPlans.length,
      itemBuilder: (context, idx) {
        final p = _patientPlans[idx];
        final isVigente = p["vigente"] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: isVigente
                      ? greenBrand.withOpacity(0.3)
                      : Colors.transparent)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: isVigente
                          ? greenBrand.withOpacity(0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.description_outlined,
                      color: isVigente ? greenBrand : Colors.blueGrey),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("Plan ${p["tipo_plan"]}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFF1E293B))),
                          const SizedBox(width: 12),
                          if (isVigente) _buildBadge("VIGENTE", greenBrand),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          "Vigencia: ${p["fecha_inicio"]} hasta ${p["fecha_fin"]}",
                          style: const TextStyle(
                              color: Colors.blueGrey, fontSize: 13)),
                      Text("Configuración: ${p["comidas_por_dia"]} comidas",
                          style: const TextStyle(
                              color: Colors.blueGrey, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Origen: ${p["origen_plan"]}",
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent),
                          onPressed: () => _deletePlan(p["id"]),
                          tooltip: "Eliminar plan",
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () => _verDetallePlan(p),
                          child: const Text("Ver Detalle"),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Izquierdo
        if (_patientProfile != null)
          PatientSummaryPanel(
            expediente: _patientProfile!,
            formatEdad: _formatEdad,
            onVerExpediente: _mostrarExpedienteMaestroDialog,
          )
        else
          const SizedBox(
              width: 320, child: Center(child: CircularProgressIndicator())),

        // Área Central de Trabajo
        Expanded(
          child: Column(
            children: [
              _buildModernTopBar(),
              Expanded(
                child: Container(
                  color: const Color(0xFFF1F5F9),
                  child: _buildWeeklyTimeline(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => setState(() => _viewingHistory = true),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Diseño de Plan Nutricional",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF0F172A)),
                ),
                Text(
                  "Paciente: ${_selectedPatient!["nombre_completo"]}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            label: "Ajustar Configuración",
            icon: Icons.tune_rounded,
            onPressed: _showConfigModal,
            color: Colors.blueGrey.shade700,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            label: "Guardar Mes Completo",
            icon: Icons.auto_mode_rounded,
            onPressed: () => _savePlan(replicate: true),
            color: Colors.indigo.shade600,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            label: "Finalizar Plan",
            icon: Icons.check_circle_rounded,
            onPressed: () => _savePlan(replicate: false),
            color: greenBrand,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required String label,
      required IconData icon,
      required VoidCallback onPressed,
      required Color color,
      bool isPrimary = false}) {
    return isPrimary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18, color: color),
            label: Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: color.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
  }

  Widget _buildWeeklyTimeline() {
    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: _weeklyPlan.length,
      itemBuilder: (context, idx) {
        final day = _weeklyPlan[idx];
        final isLast = idx == _weeklyPlan.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.blue.withOpacity(0.05),
                              blurRadius: 4)
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                              DateFormat('EEE', 'es_EC')
                                  .format(day.date)
                                  .toUpperCase(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  color: Colors.blue)),
                          Text(DateFormat('d').format(day.date),
                              style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                  color: const Color(0xFF1E293B))),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.blue.withOpacity(0.1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                              DateFormat('EEEE, d ' 'MMMM', 'es_EC')
                                  .format(day.date),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF334155))),
                          const Spacer(),
                          if (idx < _weeklyPlan.length - 1)
                            TextButton.icon(
                              onPressed: () => _duplicateDay(idx),
                              icon:
                                  const Icon(Icons.copy_all_rounded, size: 16),
                              label: const Text("Copiar al siguiente día",
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.blueGrey),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: day.slots
                            .asMap()
                            .entries
                            .map((e) => _buildModernSlot(idx, e.key, e.value))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernSlot(int dayIdx, int slotIdx, MealSlot s) {
    final hasRecipe = s.recipes.isNotEmpty;
    String semaforoSlot = "neutral";
    if (hasRecipe) {
      final sems = s.recipes
          .map((e) => (e["semaforo"] ?? "neutral").toString())
          .toList();
      if (sems.contains("amarillo")) {
        semaforoSlot = "amarillo";
      } else if (sems.contains("verde")) {
        semaforoSlot = "verde";
      }
    }
    final Color colorSlot = semaforoSlot == "verde"
        ? Colors.green
        : (semaforoSlot == "amarillo"
            ? Colors.amber.shade700
            : Colors.blueGrey);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
        border: Border.all(
            color: hasRecipe
                ? colorSlot.withOpacity(0.45)
                : Colors.orange.withOpacity(0.1),
            width: hasRecipe ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: hasRecipe
                  ? colorSlot.withOpacity(0.1)
                  : const Color(0xFFFFF7ED),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(_getMomentIcon(s.momentId),
                    size: 14, color: hasRecipe ? colorSlot : Colors.orange),
                const SizedBox(width: 8),
                Text(s.mealType.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: hasRecipe ? colorSlot : Colors.orange.shade800,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: hasRecipe
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...s.recipes.map((rec) {
                        final sem = (rec["semaforo"] ?? "neutral").toString();
                        final Color color = sem == "verde"
                            ? Colors.green
                            : (sem == "amarillo"
                                ? Colors.amber.shade700
                                : Colors.blueGrey);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.22)),
                          ),
                          child: InkWell(
                            onTap: () => _mostrarDetalleReceta(
                                (rec["id"] as num?)?.toInt() ?? 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: (rec["imagen_url"] != null &&
                                            rec["imagen_url"]
                                                .toString()
                                                .isNotEmpty)
                                        ? Image.network(
                                            rec["imagen_url"].toString(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.image,
                                                  size: 16),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.image,
                                                size: 16),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(rec["nombre"]?.toString() ?? "-",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1E293B))),
                                      const SizedBox(height: 4),
                                      Text(
                                          rec["mensaje_regla"]?.toString() ??
                                              "Segura",
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: color,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.refresh_rounded,
                                size: 18, color: Colors.blueGrey),
                            onPressed: () => _openRecipePicker(dayIdx, slotIdx),
                            tooltip: "Cambiar recetas",
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.redAccent),
                            onPressed: () => setState(() => s.recipes = []),
                            tooltip: "Quitar",
                          ),
                        ],
                      )
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: OutlinedButton.icon(
                        onPressed: () => _openRecipePicker(dayIdx, slotIdx),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text("Añadir"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side:
                              BorderSide(color: Colors.orange.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showConfigModal() {
    bool morningSnack = _morningSnackEnabled;
    bool afternoonSnack = _afternoonSnackEnabled;
    final isAdjusting = _planInitialized;

    showDialog(
      context: context,
      barrierDismissible: false, // Forzar uso de botones
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              const Icon(Icons.settings_suggest, size: 40, color: Colors.blue),
              const SizedBox(height: 12),
              Text(
                  isAdjusting
                      ? "Ajustar plan nutricional"
                      : "Configurar plan alimentario",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModalSectionTitle("Periodo de Vigencia"),
                  DropdownButtonFormField<String>(
                    value: _durationType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: "un día", child: Text("Un día")),
                      DropdownMenuItem(
                          value: "una semana", child: Text("Una semana")),
                      DropdownMenuItem(value: "un mes", child: Text("Un mes")),
                    ],
                    onChanged: (v) {
                      setModalState(() {
                        _durationType = v!;
                        if (_durationType == "un día") {
                          _endDate = _startDate;
                        } else if (_durationType == "una semana") {
                          _endDate = _startDate.add(const Duration(days: 6));
                        } else if (_durationType == "un mes") {
                          _endDate = _startDate.add(const Duration(days: 30));
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildModalSectionTitle("Resumen de Fechas"),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.blue),
                        const SizedBox(height: 8),
                        Text(
                          "Rango: ${DateFormat('d MMM', 'es_EC').format(_startDate)} - ${DateFormat('d MMM', 'es_EC').format(_endDate)}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 14),
                        ),
                        Text(
                          "Total: ${_endDate.difference(_startDate).inDays + 1} días de vigencia",
                          style: TextStyle(
                              color: Colors.blue.shade700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  _buildModalSectionTitle("Tiempos obligatorios"),
                  const Text("Se establecerán 3 comidas base por día.",
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  _buildConfigTile(
                      "Desayuno", "Principal", Icons.wb_twilight, true, null),
                  _buildConfigTile(
                      "Almuerzo", "Principal", Icons.wb_sunny, true, null),
                  _buildConfigTile("Merienda", "Principal",
                      Icons.nightlight_round, true, null),
                  const Divider(height: 32),
                  _buildModalSectionTitle("Snacks opcionales"),
                  _buildConfigTile(
                      "Snack media mañana",
                      "Entre desayuno y almuerzo",
                      Icons.coffee,
                      morningSnack,
                      (v) => setModalState(() => morningSnack = v!)),
                  _buildConfigTile(
                      "Snack media tarde",
                      "Entre almuerzo y cena",
                      Icons.apple,
                      afternoonSnack,
                      (v) => setModalState(() => afternoonSnack = v!)),
                ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (isAdjusting) {
                        Navigator.pop(context);
                      } else {
                        // Si es creación, cancelar vuelve al historial
                        setState(() => _viewingHistory = true);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("Cancelar"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // VALIDACIÓN CRÍTICA: Fecha de Control
                      final proximaCitaStr = _patientProfile?['ultimo_control']
                          ?['fecha_proxima_cita'];
                      if (proximaCitaStr != null) {
                        final proximaCita = DateTime.parse(proximaCitaStr);
                        if (_endDate.isAfter(proximaCita)) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: Colors.redAccent,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                    "⚠️ RESTRICCIÓN DE SEGURIDAD CLÍNICA",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                    "El plan excede la fecha del próximo control ($proximaCitaStr)."),
                                const Text("Acciones sugeridas:"),
                                const Text(
                                    "• Edite un plan existente para ampliarlo."),
                                const Text(
                                    "• Cree un plan de menor duración (Día/Semana)."),
                                const Text(
                                    "• Elimine planes futuros para liberar el calendario."),
                              ],
                            ),
                            duration: const Duration(seconds: 8),
                          ));
                          return; // No cerrar el modal
                        }
                      }

                      _morningSnackEnabled = morningSnack;
                      _afternoonSnackEnabled = afternoonSnack;
                      _initPlan(morningSnack, afternoonSnack);
                      Navigator.pop(context);
                    },
                    child: Text(isAdjusting
                        ? "Actualizar Plan"
                        : "Continuar y generar tabla"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _initPlan(bool morning, bool afternoon) {
    final List<PlanDay> plan = [];
    DateTime current = _startDate;
    while (!current.isAfter(_endDate)) {
      plan.add(PlanDay(date: current, slots: [
        MealSlot(mealType: "Desayuno", momentId: 1),
        if (morning) MealSlot(mealType: "Media mañana", momentId: 2),
        MealSlot(mealType: "Almuerzo", momentId: 3),
        if (afternoon) MealSlot(mealType: "Media tarde", momentId: 4),
        MealSlot(mealType: "Merienda", momentId: 5),
      ]));
      current = current.add(const Duration(days: 1));
    }

    setState(() {
      _weeklyPlan = plan;
      _planInitialized = true;
    });
  }

  IconData _getMomentIcon(int momentId) {
    switch (momentId) {
      case 1:
        return Icons.wb_twilight_rounded;
      case 2:
        return Icons.coffee_rounded;
      case 3:
        return Icons.wb_sunny_rounded;
      case 4:
        return Icons.apple_rounded;
      case 5:
        return Icons.nightlight_round_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  void _openRecipePicker(int dIdx, int sIdx) {
    final slot = _weeklyPlan[dIdx].slots[sIdx];
    final dateStr =
        DateFormat('EEEE d MMMM', 'es_EC').format(_weeklyPlan[dIdx].date);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        child: SizedBox(
          width: 980,
          height: MediaQuery.of(context).size.height * 0.82,
          child: _RecipePicker(
            idPaciente: _selectedPatient!["id"],
            momentId: slot.momentId,
            mealType: slot.mealType,
            dayName: dateStr,
            initialSelected: List<Map<String, dynamic>>.from(slot.recipes),
            onSelected: (recipes) => setState(() => slot.recipes = recipes),
          ),
        ),
      ),
    );
  }

  void _duplicateDay(int idx) {
    if (idx >= _weeklyPlan.length - 1) return;
    setState(() {
      for (int i = 0; i < _weeklyPlan[idx].slots.length; i++) {
        _weeklyPlan[idx + 1].slots[i].recipes =
            List.from(_weeklyPlan[idx].slots[i].recipes);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Día duplicado exitosamente")));
  }

  Future<void> _mostrarDetalleReceta(int idReceta) async {
    if (idReceta <= 0) return;
    final dio = ref.read(dioProvider);
    try {
      final res = await dio.get("crud/recetas/$idReceta");
      final r = Map<String, dynamic>.from(res.data ?? {});
      final ingredientes =
          List<Map<String, dynamic>>.from(r["ingredientes"] ?? []);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text((r["nombre"] ?? "Receta").toString()),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Calorías: ${r["calorias_totales"] ?? 0} kcal"),
                  Text("Proteínas: ${r["proteinas_totales"] ?? 0} g"),
                  const SizedBox(height: 12),
                  const Text("Ingredientes",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...ingredientes
                      .map((i) => Text(
                          "- ${i["nombre"] ?? "-"} ${i["cantidad"] ?? ""} ${i["unidad"] ?? ""}"))
                      .toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cerrar"))
          ],
        ),
      );
    } catch (_) {}
  }

  void _savePlan({bool replicate = true}) async {
    // 1. Validar que al menos haya una receta por slot
    for (var d in _weeklyPlan) {
      for (var s in d.slots) {
        if (s.recipes.isEmpty) {
          final dateStr = DateFormat('yyyy-MM-dd').format(d.date);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.orange,
              content: Text("Falta receta en $dateStr - ${s.mealType}")));
          return;
        }
      }
    }

    // 2. Validar Fecha Límite (Próxima Cita)
    final proximaCitaStr =
        _patientProfile?['ultimo_control']?['fecha_proxima_cita'];
    if (proximaCitaStr != null) {
      final proximaCita = DateTime.parse(proximaCitaStr);
      if (_endDate.isAfter(proximaCita)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
              "El plan excede la fecha de la próxima cita ($proximaCitaStr). Por favor, ajusta la vigencia o elimina planes previos."),
          duration: const Duration(seconds: 5),
        ));
        return;
      }
    }

    final int totalComidas =
        3 + (_morningSnackEnabled ? 1 : 0) + (_afternoonSnackEnabled ? 1 : 0);

    final List<Map<String, dynamic>> planData = [];
    for (var d in _weeklyPlan) {
      for (var s in d.slots) {
        for (final recipe in s.recipes) {
          planData.add({
            "fecha": DateFormat('yyyy-MM-dd').format(d.date),
            "id_momento": s.momentId,
            "id_receta": recipe["id"],
            "semaforo": recipe["semaforo"],
            "comidas_por_dia": totalComidas,
          });
        }
      }
    }

    try {
      final dio = ref.read(dioProvider);
      await dio.post("plan-manual", data: {
        "id_paciente": _selectedPatient!["id"],
        "plan": planData,
        "replicate": replicate,
        "boosters": _boostersSeleccionados,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green,
            content: Text("✅ Plan guardado y activado")));
        _onPatientSelected(_selectedPatient!); // Recargar historial
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
    }
  }

  Widget _buildModalSectionTitle(String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(t,
          style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              color: Colors.blueGrey,
              letterSpacing: 1.1)));

  Widget _buildConfigTile(String title, String desc, IconData icon, bool value,
      ValueChanged<bool?>? onChanged) {
    return ListTile(
      leading: Icon(icon, color: value ? Colors.orange : Colors.grey),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
      trailing: onChanged == null
          ? const Icon(Icons.check_circle, color: Colors.green)
          : Checkbox(value: value, onChanged: onChanged),
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
      if (months < 0) {
        years--;
        months += 12;
      }
      return "$years años y $months meses";
    } catch (_) {
      return "-";
    }
  }

  List<Map<String, dynamic>> _filtrarCondicionesPeso(
      List<Map<String, dynamic>> condiciones) {
    final porTipo = condiciones.where((c) {
      final tipo = (c["tipo"] ?? c["tipo_condicion"] ?? c["id_tipo_condicion"])
              ?.toString()
              .toLowerCase() ??
          "";
      return tipo.contains("peso");
    }).toList();
    if (porTipo.isNotEmpty) return porTipo;
    return condiciones.where((c) {
      final nombre = (c["nombre"] ?? "").toString().toLowerCase();
      return nombre.contains("peso") ||
          nombre.contains("sobrepeso") ||
          nombre.contains("obes");
    }).toList();
  }

  List<Map<String, dynamic>> _filtrarCondicionesTalla(
      List<Map<String, dynamic>> condiciones) {
    final porTipo = condiciones.where((c) {
      final tipo = (c["tipo"] ?? c["tipo_condicion"] ?? c["id_tipo_condicion"])
              ?.toString()
              .toLowerCase() ??
          "";
      return tipo.contains("talla");
    }).toList();
    if (porTipo.isNotEmpty) return porTipo;
    return condiciones.where((c) {
      final nombre = (c["nombre"] ?? "").toString().toLowerCase();
      return nombre.contains("talla") || nombre.contains("estatura");
    }).toList();
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
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.assignment_ind_outlined,
                      color: greenBrand, size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("EXPEDIENTE MAESTRO INTEGRAL",
                          style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w900, fontSize: 20)),
                      Text(
                          "Registro oficial del paciente en el sistema ReumaNutri",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close))
                ]),
                const Divider(height: 48),
                Flexible(
                  child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child:
                                _buildExpSection("1. IDENTIDAD DEL PACIENTE", [
                          _expItem("Nombres Completos", p['nombre_completo']),
                          _expItem("Cédula / ID", p['cedula']),
                          _expItem(
                              "Fecha de Nacimiento", p['fecha_nacimiento']),
                          _expItem("Sexo Biológico", p['sexo_nombre']),
                          const SizedBox(height: 16),
                          const Text("LOCALIZACIÓN",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          _expItem("Cantón de Residencia", p['canton_nombre']),
                          _expItem("Parroquia", p['parroquia_nombre']),
                        ])),
                        const SizedBox(width: 40),
                        Expanded(
                            child: _buildExpSection("2. REPRESENTANTE LEGAL", [
                          _expItem("Nombre del Tutor", t['nombre_completo']),
                          _expItem("Cédula del Tutor", t['cedula']),
                          _expItem("Parentesco", t['parentesco_nombre']),
                          const SizedBox(height: 16),
                          const Text("CONTACTO",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          _expItem("Correo Electrónico", t['email']),
                          _expItem("Teléfono / Móvil", t['telefono']),
                          _expItem("Dirección de Domicilio", t['direccion']),
                        ])),
                        const SizedBox(width: 40),
                        Expanded(
                            child:
                                _buildExpSection("3. ESTADO CLÍNICO ACTUAL", [
                          _expItem("Diagnóstico Principal",
                              d['condicion_nombre'] ?? "AIJ"),
                          _expItem("Estado Nutricional (OMS)",
                              c['estado_nutricional'],
                              isBold: true),
                          _expItem("Peso / Talla",
                              "${c['peso_kg'] ?? '-'} kg / ${c['talla_cm'] ?? '-'} cm"),
                          _expItem("Inflamación Actual",
                              "${c['escala_inflamacion'] ?? 0}/3"),
                          _expItem("Brote Activo",
                              (c['en_brote'] == true) ? "SÍ (ACTIVO)" : "NO",
                              isAlert: c['en_brote'] == true),
                          const SizedBox(height: 16),
                          const Text("SEGUIMIENTO",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          _expItem(
                              "Fecha de Último Control", c['fecha_control']),
                          _expItem("Próxima Cita Programada",
                              c['fecha_proxima_cita']),
                        ])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Row(children: [
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("ENTENDIDO"),
                          style: FilledButton.styleFrom(
                              backgroundColor: greenBrand,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20)))),
                ])
              ]),
        ),
      ),
    );
  }

  Widget _buildExpSection(String title, List<Widget> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: greenBrand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  color: greenBrand,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(height: 24),
        ...items
      ]);

  Widget _expItem(String l, dynamic v,
          {bool isBold = false,
          bool isAlert = false,
          bool isHighlight = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2)),
            const SizedBox(height: 4),
            Text(v?.toString() ?? "NO REGISTRADO",
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight:
                      (isBold || isAlert) ? FontWeight.w900 : FontWeight.w600,
                  color: isAlert
                      ? Colors.red
                      : (isHighlight ? greenBrand : const Color(0xFF1E293B)),
                ))
          ]));
}

class _RecipePicker extends ConsumerStatefulWidget {
  final String idPaciente;
  final int momentId;
  final String mealType;
  final String dayName;
  final List<Map<String, dynamic>> initialSelected;
  final Function(List<Map<String, dynamic>>) onSelected;
  const _RecipePicker({
    required this.idPaciente,
    required this.momentId,
    required this.mealType,
    required this.dayName,
    required this.initialSelected,
    required this.onSelected,
  });

  @override
  ConsumerState<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends ConsumerState<_RecipePicker> {
  List<dynamic> _recipes = [];
  List<dynamic> _filtered = [];
  List<Map<String, dynamic>> _tipos = [];
  int? _tipoSeleccionado;
  final Map<int?, List<dynamic>> _cachePorTipo = {};
  Map<int, bool> _preferences = {};
  final Map<int, Map<String, dynamic>> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (final r in widget.initialSelected) {
      final rid = int.tryParse((r["id"] ?? "").toString());
      if (rid != null) _selected[rid] = r;
    }
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final responses = await Future.wait<dynamic>([
        dio.get("crud/tipos-plato"),
        dio.post("recetas-permitidas", data: {
          "id_paciente": widget.idPaciente,
          "id_momento": widget.momentId,
        }),
      ]);
      final tiposRes = responses[0];
      final recetasRes = responses[1];
      final catalogoTipos = List<Map<String, dynamic>>.from(tiposRes.data ?? []);
      final todasLasRecetas =
          List<dynamic>.from(recetasRes.data["recetas"] ?? []);
      final conteosPorTipo = <int, int>{};
      for (final receta in todasLasRecetas) {
        final ids = receta["tipos_plato_ids"];
        if (ids is! Iterable) continue;
        final idsUnicos = ids
            .map((id) => (id as num?)?.toInt())
            .whereType<int>()
            .toSet();
        for (final idTipo in idsUnicos) {
          conteosPorTipo[idTipo] = (conteosPorTipo[idTipo] ?? 0) + 1;
        }
      }
      final tipos = catalogoTipos
          .where((t) {
            final id = (t["id"] as num?)?.toInt();
            return id != null && conteosPorTipo.containsKey(id);
          })
          .map((t) => {
                "id_tipo_plato": (t["id"] as num?)?.toInt(),
                "tipo_plato_nombre": (t["nombre"] ?? "Tipo").toString(),
                "total_recetas":
                    conteosPorTipo[(t["id"] as num?)?.toInt()] ?? 0,
              })
          .toList();
      _cachePorTipo
        ..clear()
        ..[null] = todasLasRecetas;
      for (final tipo in tipos) {
        final idTipo = (tipo["id_tipo_plato"] as num?)?.toInt();
        if (idTipo == null) continue;
        _cachePorTipo[idTipo] = todasLasRecetas.where((receta) {
          final ids = receta["tipos_plato_ids"];
          if (ids is Iterable) {
            return ids.any((id) => (id as num?)?.toInt() == idTipo);
          }
          return false;
        }).toList();
      }
      final tipoInicial = tipos.isNotEmpty
          ? (tipos.first["id_tipo_plato"] as num?)?.toInt()
          : null;
      final recetasIniciales = _cachePorTipo[tipoInicial] ?? todasLasRecetas;
      if (mounted) {
        setState(() {
          _tipos = tipos;
          _tipoSeleccionado = tipoInicial;
          _recipes = recetasIniciales;
          _filtered = _recipes;
          _preferences = {};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<dynamic>> _obtenerRecetasPorTipo(int? idTipo) async {
    if (_cachePorTipo.containsKey(idTipo)) {
      return _cachePorTipo[idTipo] ?? <dynamic>[];
    }
    final dio = ref.read(dioProvider);
    final data = <String, dynamic>{
      "id_paciente": widget.idPaciente,
      "id_momento": widget.momentId,
    };
    if (idTipo != null) {
      data["id_tipo_plato"] = idTipo;
    }
    final res = await dio.post("recetas-permitidas", data: data);
    final recetas = List<dynamic>.from(res.data["recetas"] ?? []);
    _cachePorTipo[idTipo] = recetas;
    return recetas;
  }

  Future<void> _cargarPorTipo(int? idTipo) async {
    if (!mounted) {
      return;
    }
    final recetas = await _obtenerRecetasPorTipo(idTipo);
    setState(() {
      _tipoSeleccionado = idTipo;
      _recipes = recetas;
      _filtered = _recipes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(16))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Seleccionar Receta Segura",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                  Text("${widget.dayName} • ${widget.mealType}",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
                const Spacer(),
                Text("${_selected.length} seleccionadas",
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          if (_tipos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tipos.map((t) {
                    final id = (t["id_tipo_plato"] as num?)?.toInt();
                    final selected = id == _tipoSeleccionado;
                    return ChoiceChip(
                      label:
                          Text((t["tipo_plato_nombre"] ?? "Tipo").toString()),
                      selected: selected,
                      onSelected: (_) => _cargarPorTipo(id),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (!_loading && _tipos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "No hay tipos de comida aptos para este momento con las reglas actuales.",
                  style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() {
                final q = v.toLowerCase();
                _filtered = _recipes.where((r) {
                  final nombre = (r["nombre"] ?? "").toString().toLowerCase();
                  final ing = (r["ingredientes_nombres"] ?? [])
                      .toString()
                      .toLowerCase();
                  return nombre.contains(q) || ing.contains(q);
                }).toList();
              }),
              decoration: InputDecoration(
                  hintText: "Buscar por receta o ingrediente...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none)),
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
                itemBuilder: (context, i) {
                  final recipe = _filtered[i];
                  final recipeId = int.tryParse(recipe["id"].toString()) ?? 0;
                  final likes = _preferences[recipeId];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: (recipe["imagen_url"] != null &&
                                  recipe["imagen_url"].toString().isNotEmpty)
                              ? Image.network(
                                  recipe["imagen_url"].toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      color: Colors.orange.shade100,
                                      child: const Icon(Icons.restaurant,
                                          color: Colors.orange)),
                                )
                              : Container(
                                  color: Colors.orange.shade100,
                                  child: const Icon(Icons.restaurant,
                                      color: Colors.orange)),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                              child: Text(
                                  recipe["nombre"]?.toString() ?? "Receta",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                          if (likes == true)
                            const Icon(Icons.thumb_up,
                                color: Colors.green, size: 16),
                          if (likes == false)
                            const Icon(Icons.thumb_down,
                                color: Colors.red, size: 16),
                        ],
                      ),
                      subtitle: Text(
                          recipe["mensaje_regla"]?.toString() ??
                              recipe["recomendacion"]?.toString() ??
                              "Permitida",
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      trailing: Checkbox(
                        value: _selected.containsKey(recipeId),
                        onChanged: (_) {
                          setState(() {
                            if (_selected.containsKey(recipeId)) {
                              _selected.remove(recipeId);
                            } else {
                              _selected[recipeId] =
                                  Map<String, dynamic>.from(recipe);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (_selected.containsKey(recipeId)) {
                            _selected.remove(recipeId);
                          } else {
                            _selected[recipeId] =
                                Map<String, dynamic>.from(recipe);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              children: [
                OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar")),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    widget.onSelected(_selected.values.toList());
                    Navigator.pop(context);
                  },
                  child: const Text("Aplicar selección"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
