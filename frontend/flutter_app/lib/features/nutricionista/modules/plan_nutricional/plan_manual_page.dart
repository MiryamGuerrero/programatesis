import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/nutri_avatar.dart';
import '../../../../shared/widgets/patient_summary_panel.dart';
import '../../../../shared/widgets/shimmer_components.dart';
import '../../../../shared/widgets/layout_components.dart';
import 'asignacion_comida_manual_page.dart';
import 'widgets/receta_modal_verde.dart';

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

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Map<String, dynamic>? _selectedPatient;
  Map<String, dynamic>? _patientProfile;
  Map<String, dynamic>? _planVigente;
  List<Map<String, dynamic>> _patients = [];
  List<dynamic> _patientPlans = []; // Historial de planes
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  bool _viewingHistory = true; 
  bool _recomendadorAbierto = false;
  bool _isSaving = false;
  bool _saveSuccess = false;
  bool _isDeleting = false;
  bool _deleteSuccess = false;
  bool _isLoadingRecomendaciones = false;
  int? _loadingPlanId;
  int? _editingPlanId;
  bool _isDirty = false;
  Timer? _searchDebounce;

  List<PlanDay> _weeklyPlan = [];
  bool _planInitialized = false;
  bool _isAssigningSingleMeal = false;

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
  final ScrollController _historyScrollController = ScrollController();

  String _selectedFilter = "Todos";
  final List<String> _filters = [
    "Todos",
    "Plan activo",
    "No activo",
    "Validación nutricional confirmada",
    "Validación nutricional pendiente"
  ];

  RealtimeChannel? _realtimeChannel;

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
    Future.microtask(() {
      _fetchPatients("");
      _setupRealtimeSubscription();
    });
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchController.dispose();
    _historyScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    try {
      final supabase = ref.read(supabaseClientProvider);
      _realtimeChannel = supabase
          .channel('plan_manual_realtime_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'clinico',
            table: 'validacion_control_nutricional_mensual',
            callback: (payload) {
              debugPrint("[Realtime] validacion_control_nutricional_mensual: ${payload.eventType}");
              final newRec = payload.newRecord;
              final idPaciente = (newRec['id_paciente'] ?? payload.oldRecord['id_paciente'])?.toString();
              final bool confirmado = newRec['confirmado'] == true;
              if (idPaciente != null && mounted) {
                setState(() {
                  for (var p in _patients) {
                    if (p['id']?.toString() == idPaciente) {
                      p['validacion_confirmada'] = confirmado;
                    }
                  }
                  if (_selectedPatient != null && _selectedPatient!['id']?.toString() == idPaciente) {
                    _selectedPatient!['validacion_confirmada'] = confirmado;
                  }
                });
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'clinico',
            table: 'control_paciente',
            callback: (payload) {
              debugPrint("[Realtime] control_paciente: ${payload.eventType}");
              _fetchPatientsSilently();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'interaccion',
            table: 'plan_nutricional',
            callback: (payload) {
              debugPrint("[Realtime] plan_nutricional: ${payload.eventType}");
              final newRec = payload.newRecord;
              final oldRec = payload.oldRecord;
              final idPaciente = (newRec['id_paciente'] ?? oldRec['id_paciente'])?.toString();
              if (idPaciente != null && mounted) {
                final isInsert = payload.eventType == PostgresChangeEvent.insert;
                final isDelete = payload.eventType == PostgresChangeEvent.delete;
                setState(() {
                  for (var p in _patients) {
                    if (p['id']?.toString() == idPaciente) {
                      if (isInsert) p['plan_activo'] = true;
                      if (isDelete) p['plan_activo'] = false;
                    }
                  }
                  if (_selectedPatient != null && _selectedPatient!['id']?.toString() == idPaciente) {
                    if (isInsert) _selectedPatient!['plan_activo'] = true;
                    if (isDelete) _selectedPatient!['plan_activo'] = false;
                  }
                });
              }
              _fetchPatientsSilently();
              if (_selectedPatient != null) {
                _fetchPatientPlansSilently(_selectedPatient!['id']);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'interaccion',
            table: 'plan_item',
            callback: (payload) {
              debugPrint("[Realtime] plan_item: ${payload.eventType}");
              if (_selectedPatient != null) {
                _fetchPatientPlansSilently(_selectedPatient!['id']);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'interaccion',
            table: 'seguimiento_plan_item',
            callback: (payload) {
              debugPrint("[Realtime] seguimiento_plan_item: ${payload.eventType}");
              if (_selectedPatient != null) {
                _fetchPatientPlansSilently(_selectedPatient!['id']);
              }
            },
          )
          .subscribe((status, [error]) {
            debugPrint("[Realtime] Canal plan_manual status: $status, error: $error");
          });
    } catch (e) {
      debugPrint("Error setting up realtime subscription in PlanManual: $e");
    }
  }

  Future<void> _fetchPatientPlansSilently(dynamic patientId) async {
    if (patientId == null) return;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("pacientes/$patientId/planes");
      if (mounted && res.data != null) {
        final List planesRaw = res.data ?? [];
        setState(() {
          _patientPlans = planesRaw.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPatientsSilently() async {
    try {
      final dio = ref.read(dioProvider);
      final q = _searchController.text.trim();
      final res = await dio.get("buscar-pacientes", queryParameters: {"q": q});
      if (mounted && res.data != null) {
        setState(() {
          _patients = List<Map<String, dynamic>>.from(res.data);
        });
      }
    } catch (_) {}
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
    
    if (latestEnd.isAfter(todayOnly)) {
      _startDate = latestEnd.add(const Duration(days: 1));
    } else {
      _startDate = todayOnly;
    }

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
        case "Validación nutricional confirmada":
          return validacionConfirmada;
        case "Validación nutricional pendiente":
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
      _patientProfile = null;
      _planVigente = null;
      _patientPlans = [];
      _ingredientesSegurosCache = [];
      _recomendacionesCache = [];
      _boostersSeleccionados = [];
      _weeklyPlan = [];
      _planInitialized = false;
    });

    try {
      final dio = ref.read(dioProvider);
      final patientId = patient['id'];

      final results = await Future.wait([
        dio.get(
          "pacientes/$patientId/prefetch-planificacion",
          queryParameters: {"include_ingredientes": true},
        ),
        dio.get("pacientes/$patientId/planes"),
      ]);

      final payload = Map<String, dynamic>.from(results[0].data ?? {});
      final List planesRaw = results[1].data ?? [];

      _patientProfile = Map<String, dynamic>.from(payload["expediente"] ?? {});
      _planVigente = payload["plan_vigente"] != null
          ? Map<String, dynamic>.from(payload["plan_vigente"])
          : null;
      _ingredientesSegurosCache = (payload["ingredientes_seguros"] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      _recomendacionesCache = (payload["ingredientes_recomendados"] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];

      if (_recomendacionesCache.isEmpty) {
        dio.get("ingredientes/recomendados/$patientId").then((recoRes) {
          if (mounted) {
            setState(() {
              _recomendacionesCache = (recoRes.data as List?)
                      ?.map((e) => Map<String, dynamic>.from(e))
                      .toList() ??
                  [];
              _boostersSeleccionados = _recomendacionesCache
                  .map((r) => (r["id_ingrediente"] as num?)?.toInt())
                  .whereType<int>()
                  .toList();
            });
          }
        }).catchError((_) {});
      } else {
        _boostersSeleccionados = _recomendacionesCache
            .map((r) => (r["id_ingrediente"] as num?)?.toInt())
            .whereType<int>()
            .toList();
      }

      final estadoValidacion =
          Map<String, dynamic>.from(payload["estado_validacion"] ?? {});
      final mostrarModal = estadoValidacion["mostrar_modal"] == true;

      if (mostrarModal) {
        await _mostrarModalValidacionClinica(patientId.toString());
        final resRevalidado = await dio.get(
          "pacientes/$patientId/control-mensual-actual/estado-validacion",
        );
        if (resRevalidado.data != null) {
          final dataRevalidada = Map<String, dynamic>.from(resRevalidado.data);
          if (dataRevalidada["mostrar_modal"] == true) {
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
      }

      setState(() {
        _patientPlans =
            planesRaw.map((e) => Map<String, dynamic>.from(e)).toList();
        _planInitialized = false;
        _calculateSmartDates(_patientPlans, planVigente: _planVigente);
      });
    } catch (e) {
      debugPrint("Error en _onPatientSelected: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar datos del paciente: $e")),
        );
      }
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
    final searchCtrl = TextEditingController();
    String searchQuery = "";

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filteredSeguros = seguros.where((ing) {
            final nombre = (ing["nombre"] ?? "").toString().toLowerCase();
            return nombre.contains(searchQuery.toLowerCase());
          }).toList();

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 780, maxHeight: 680),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5EAF2)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTema.azulPrincipal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: AppTema.azulPrincipal,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "Seleccionar ingredientes recomendados",
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTema.azulOscuro,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF64748B),
                        iconSize: 22,
                        tooltip: "Cerrar",
                        splashRadius: 20,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Selecciona ingredientes seguros para potenciar este plan nutricional.",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Buscador igual al de plan de una sola comida
                  TextField(
                    controller: searchCtrl,
                    onChanged: (val) {
                      setModal(() {
                        searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre de ingrediente...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: const Icon(Icons.arrow_forward, color: Color(0xFF16A34A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lista
                  Expanded(
                    child: filteredSeguros.isEmpty
                        ? Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              searchQuery.isEmpty
                                  ? "No hay ingredientes seguros disponibles para recomendar en este momento.\n\n"
                                      "Posibles causas:\n"
                                      "- Alergias/restricciones del paciente demasiado amplias.\n"
                                      "- No existen ingredientes activos compatibles en el catálogo.\n"
                                      "- Faltan datos clínicos actualizados para filtrar."
                                  : "No se encontraron ingredientes con '$searchQuery'.",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredSeguros.length,
                            separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200, height: 1),
                            itemBuilder: (_, i) {
                              final ing = filteredSeguros[i];
                              final idIng = (ing["id"] as num?)?.toInt() ?? -1;
                              if (idIng <= 0) return const SizedBox.shrink();
                              final nombre = (ing["nombre"] ?? "-").toString();
                              final isSelected = seleccion.contains(idIng);

                              return ListTile(
                                onTap: () {
                                  setModal(() {
                                    if (isSelected) {
                                      seleccion.remove(idIng);
                                    } else {
                                      seleccion.add(idIng);
                                    }
                                  });
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.green.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.eco_rounded,
                                    color: isSelected ? Colors.green.shade600 : Colors.blueGrey.shade300,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  nombre,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF0F172A) : Colors.blueGrey.shade800,
                                  ),
                                ),
                                trailing: Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFF16A34A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (v) {
                                    setModal(() {
                                      if (v == true) {
                                        seleccion.add(idIng);
                                      } else {
                                        seleccion.remove(idIng);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Botones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blueGrey.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        child: const Text("Cancelar"),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          setState(() => _boostersSeleccionados = seleccion.toList());
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _aplicarPotenciadoresAutomaticos(idPaciente);
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: Text("Aplicar al plan", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A), // Verde
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _abrirRecomendadorIngredientes() async {
    if (_selectedPatient == null ||
        _isLoadingRecomendaciones ||
        _recomendadorAbierto) return;
    setState(() => _isLoadingRecomendaciones = true);
    try {
      await _modalRecomendacionesNutri(_selectedPatient!["id"].toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingRecomendaciones = false);
      } else {
        _isLoadingRecomendaciones = false;
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
    final condicionesResp = await dio.get(
      "condiciones-nutricionales",
      queryParameters: {"limit": 500},
    );
    final List rawData;
    if (condicionesResp.data is Map) {
      rawData = condicionesResp.data["items"] ?? [];
    } else {
      rawData = condicionesResp.data ?? [];
    }
    final List<Map<String, dynamic>> condiciones =
        List<Map<String, dynamic>>.from(rawData);
    final condicionesPeso = _filtrarCondicionesPeso(condiciones);
    final condicionesTalla = _filtrarCondicionesTalla(condiciones);

    final pesoCtrl = TextEditingController(
        text: (ultimoControl["peso_kg"] ?? "").toString());
    final tallaCtrl = TextEditingController(
        text: (ultimoControl["talla_cm"] ?? "").toString());
    final prediagnostico = (ultimoControl["estado_nutricional"] ?? "Desconocido").toString();
    final prediagnosticoLower = prediagnostico.toLowerCase().replaceAll('ó', 'o').replaceAll('í', 'i').replaceAll('á', 'a').replaceAll('é', 'e');

    int? condicionPesoId =
        (ultimoControl["id_condicion_nutricional_resultado"] as num?)?.toInt();
        
    if (condicionPesoId == null || !condicionesPeso.any((c) => (c["id"] as num).toInt() == condicionPesoId)) {
        // Keyword match for Peso
        final exactMatch = condicionesPeso.where((c) {
            final n = (c["nombre"] ?? "").toString().toLowerCase().replaceAll('ó', 'o').replaceAll('í', 'i').replaceAll('á', 'a').replaceAll('é', 'e');
            if (prediagnosticoLower.contains(n)) return true; // Prioritize exact substring match
            if (prediagnosticoLower.contains("sobrepeso") && n.contains("sobrepeso")) return true;
            if (prediagnosticoLower.contains("obesidad") && n.contains("obes")) return true;
            if (prediagnosticoLower.contains("emaciaci") && n.contains("emaciaci")) return true;
            if (prediagnosticoLower.contains("delgadez") && n.contains("delgadez")) return true;
            if (prediagnosticoLower.contains("bajo peso") && n.contains("bajo peso")) return true;
            return false;
        }).toList();
        
        if (exactMatch.isNotEmpty) {
            exactMatch.sort((a, b) => (b["nombre"] as String).length.compareTo((a["nombre"] as String).length));
            condicionPesoId = (exactMatch.first["id"] as num).toInt();
        } else if (condicionesPeso.isNotEmpty) {
            final normalPeso = condicionesPeso.where((c) => c["nombre"]?.toString().toLowerCase().contains("normal") ?? false).toList();
            condicionPesoId = (normalPeso.isNotEmpty ? normalPeso.first["id"] : condicionesPeso.first["id"]) as int?;
        }
    }

    int? condicionTallaId =
        (ultimoControl["id_condicion_nutricional_resultado"] as num?)?.toInt();
        
    if (condicionTallaId == null || !condicionesTalla.any((c) => (c["id"] as num).toInt() == condicionTallaId)) {
        // Keyword match for Talla
        final exactMatch = condicionesTalla.where((c) {
            final n = (c["nombre"] ?? "").toString().toLowerCase().replaceAll('ó', 'o').replaceAll('í', 'i').replaceAll('á', 'a').replaceAll('é', 'e');
            if (prediagnosticoLower.contains(n)) return true; // Prioritize exact substring match
            if (prediagnosticoLower.contains("talla baja") && n.contains("baja")) return true;
            if (prediagnosticoLower.contains("talla alta") && n.contains("alta")) return true;
            return false;
        }).toList();
        
        if (exactMatch.isNotEmpty) {
            exactMatch.sort((a, b) => (b["nombre"] as String).length.compareTo((a["nombre"] as String).length));
            condicionTallaId = (exactMatch.first["id"] as num).toInt();
        } else if (condicionesTalla.isNotEmpty) {
            final normalTalla = condicionesTalla.where((c) => 
                (c["nombre"]?.toString().toLowerCase().contains("normal") ?? false) || 
                (c["nombre"]?.toString().toLowerCase().contains("adecuada") ?? false)
            ).toList();
            condicionTallaId = (normalTalla.isNotEmpty ? normalTalla.first["id"] : condicionesTalla.first["id"]) as int?;
        }
    }
    final edadLabel = _formatEdad(paciente["fecha_nacimiento"]?.toString());
    final imcCalculado = (ultimoControl["imc_calculado"] ?? "No calculado").toString();

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final screenHeight = MediaQuery.of(context).size.height;
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 850,
                constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTema.pastelCeleste,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.verified_user_outlined,
                                    color: AppTema.azulPrincipal, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Validación: ${paciente['nombre_completo'] ?? 'Paciente'}",
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        color: AppTema.azulOscuro,
                                        fontSize: 16),
                                  ),
                                  Text(
                                    "Paciente de $edadLabel • Revisa el estado",
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blueGrey,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Read-only Data (Prediagnostic & Context)
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTema.verdeSalud.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTema.verdeSalud.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.auto_awesome, color: AppTema.verdeSalud, size: 18),
                                          const SizedBox(width: 6),
                                          Text("Prediagnóstico del Sistema", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTema.verdeSalud, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("IMC Calculado", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                                Text(imcCalculado, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("Estado Detectado", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                                Text(prediagnostico, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Diagnóstico Base", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                            Text(_patientProfile?["diagnostico"]?["condicion_nombre"] ?? "No registrado", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Edad actual", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                            Text(edadLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTema.azulOscuro)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right Column: Editable Values
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Ajustar Valores Clínicos", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppTema.azulOscuro)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: pesoCtrl,
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: "Peso (kg)",
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTema.azulPrincipal)),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: tallaCtrl,
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: "Talla (cm)",
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTema.azulPrincipal)),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  value: (condicionesPeso.any((c) => (c["id"] as num).toInt() == condicionPesoId)) ? condicionPesoId : null,
                                  isExpanded: true,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTema.azulOscuro),
                                  decoration: InputDecoration(
                                    labelText: "Condición nutricional - peso",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTema.azulPrincipal)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: condicionesPeso.map((c) => DropdownMenuItem<int>(
                                        value: (c["id"] as num).toInt(),
                                        child: Text(c["nombre"]?.toString() ?? "Condición"),
                                      )).toList(),
                                  onChanged: (v) => setModalState(() => condicionPesoId = v),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  value: (condicionesTalla.any((c) => (c["id"] as num).toInt() == condicionTallaId)) ? condicionTallaId : null,
                                  isExpanded: true,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTema.azulOscuro),
                                  decoration: InputDecoration(
                                    labelText: "Condición nutricional - talla",
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTema.azulPrincipal)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: condicionesTalla.map((c) => DropdownMenuItem<int>(
                                        value: (c["id"] as num).toInt(),
                                        child: Text(c["nombre"]?.toString() ?? "Condición"),
                                      )).toList(),
                                  onChanged: (v) => setModalState(() => condicionTallaId = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              try {
                                await dio.post("pacientes/$idPaciente/control-mensual-actual/confirmar");
                                if (mounted) {
                                  setState(() {
                                    for (var p in _patients) {
                                      if (p['id']?.toString() == idPaciente.toString()) {
                                        p['validacion_confirmada'] = true;
                                      }
                                    }
                                    if (_selectedPatient != null && _selectedPatient!['id']?.toString() == idPaciente.toString()) {
                                      _selectedPatient!['validacion_confirmada'] = true;
                                    }
                                  });
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                debugPrint("Error al confirmar: $e");
                              }
                            },
                            child: Text("Dejar como está", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTema.azulPrincipal,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final peso = double.tryParse(pesoCtrl.text.trim());
                              final talla = double.tryParse(tallaCtrl.text.trim());
                              if (peso == null || talla == null || condicionPesoId == null || condicionTallaId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Completa peso, talla y las 2 condiciones.", style: TextStyle(color: Colors.white))),
                                );
                                return;
                              }
                              try {
                                await dio.put(
                                  "pacientes/$idPaciente/control-mensual-actual",
                                  data: {
                                    "peso_kg": peso,
                                    "talla_cm": talla,
                                    "id_condicion_nutricional_peso": condicionPesoId,
                                    "id_condicion_nutricional_talla": condicionTallaId,
                                  },
                                );
                                final resExpNuevo = await dio.get("pacientes/$idPaciente/expediente-completo");
                                if (mounted) {
                                  setState(() {
                                    _patientProfile = resExpNuevo.data;
                                    for (var p in _patients) {
                                      if (p['id']?.toString() == idPaciente.toString()) {
                                        p['validacion_confirmada'] = true;
                                      }
                                    }
                                    if (_selectedPatient != null && _selectedPatient!['id']?.toString() == idPaciente.toString()) {
                                      _selectedPatient!['validacion_confirmada'] = true;
                                    }
                                  });
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                debugPrint("Error al actualizar: $e");
                              }
                            },
                            child: Text("Actualizar datos", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deletePlan(int id) async {
    setState(() {
      _isDeleting = true;
      _deleteSuccess = false;
    });
    
    try {
      final dio = ref.read(dioProvider);
      await dio.delete("planes/$id");
      if (mounted) {
        setState(() {
          _patientPlans.removeWhere((p) => p["id"] == id);
          _deleteSuccess = true;
          final hasVigente = _patientPlans.any((p) => p["vigente"] == true || p["plan_activo"] == true);
          final pId = _selectedPatient?["id"]?.toString();
          if (pId != null) {
            for (var p in _patients) {
              if (p['id']?.toString() == pId) {
                p['plan_activo'] = hasVigente;
              }
            }
            if (_selectedPatient != null) {
              _selectedPatient!['plan_activo'] = hasVigente;
            }
          }
        });
        _fetchPatientsSilently();
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _startNewPlan() async {
    if (_selectedPatient == null) return;
    setState(() {
      _viewingHistory = false;
      _planInitialized = false;
      _editingPlanId = null;
      _isDirty = false;
      _weeklyPlan = [];

      // Resetear configuraciones a valores por defecto
      _durationType = "una semana";
      _morningSnackEnabled = false;
      _afternoonSnackEnabled = false;
      _singleMealId = 3;

      _calculateSmartDates(_patientPlans, planVigente: _planVigente);
    });
    _showConfigModal();
  }

  Future<void> _verDetallePlan(Map<String, dynamic> plan) async {
    final planId = (plan['id'] as num?)?.toInt();
    if (planId == null) return;

    setState(() => _loadingPlanId = planId);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("planes/$planId");
      final List items = res.data; 

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
        
        for (int mId = 1; mId <= 5; mId++) {
          final recipes = _findRecipe(dayItems, mId);
          if (recipes.isNotEmpty) {
            String mealType = "";
            switch (mId) {
              case 1: mealType = "Desayuno"; break;
              case 2: mealType = "Media mañana"; break;
              case 3: mealType = "Almuerzo"; break;
              case 4: mealType = "Media tarde"; break;
              case 5: mealType = "Merienda"; break;
            }
            slots.add(MealSlot(mealType: mealType, momentId: mId, recipes: recipes));
          }
        }

        reconstructed.add(PlanDay(date: date, slots: slots));
      }

      setState(() {
        _weeklyPlan = reconstructed;
        _viewingHistory = false;
        _planInitialized = true;
        _editingPlanId = planId;
        _isDirty = false;
        _startDate = reconstructed.first.date;
        _endDate = reconstructed.last.date;
        _morningSnackEnabled =
            reconstructed.any((d) => d.slots.any((s) => s.momentId == 2));
        _afternoonSnackEnabled =
            reconstructed.any((d) => d.slots.any((s) => s.momentId == 4));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al cargar plan: $e")));
      }
    } finally {
      if (mounted) setState(() => _loadingPlanId = null);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          if (_isAssigningSingleMeal && _selectedPatient != null && _patientProfile != null)
            AsignacionComidaManualPage(
              idPaciente: _selectedPatient!['id'],
              nombrePaciente: _selectedPatient!['nombre_completo'] ?? 'Paciente',
              patientProfile: _patientProfile!,
              formatEdad: _formatEdad,
              onVerExpediente: _mostrarExpedienteMaestroDialog,
              onBack: () {
                setState(() => _isAssigningSingleMeal = false);
              },
              onSaved: () {
                setState(() => _isAssigningSingleMeal = false);
                _onPatientSelected(_selectedPatient!);
                _fetchPatientsSilently();
              },
            )
          else
            _selectedPatient == null
                ? _buildPatientSelection()
                : (_viewingHistory ? _buildHistoryLayout() : _buildEditorLayout()),
          if (!_isAssigningSingleMeal) _buildLoadingOverlay(),
          if (_isSaving || _isDeleting) _buildActionOverlay(),
        ],
      ),
    );
  }

  Widget _buildActionOverlay() {
    final bool isSuccess = _isSaving ? _saveSuccess : _deleteSuccess;
    final String loadingText = _isSaving ? "Guardando Plan..." : "Eliminando Plan...";
    final String successText = _isSaving ? "Plan guardado con éxito" : "Plan eliminado con éxito";
    
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSuccess)
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 5),
                )
              else
                const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF4ADE80), size: 86),
              const SizedBox(height: 24),
              Text(
                isSuccess ? successText : loadingText,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Planificación nutricional",
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTema.azulPrincipal,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Selecciona un paciente para crear, revisar o actualizar su plan nutricional personalizado.",
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.blueGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _fetchPatients,
              style:
                  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Buscar paciente por nombre, cédula o teléfono...",
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade400, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
                  onSelected: (val) async {
                    if (val) {
                      setState(() {
                        _selectedFilter = f;
                        _isLoading = true;
                      });
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (mounted) setState(() => _isLoading = false);
                    }
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
          if (_isLoading && _patients.isEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NutriShimmer(
                  width: double.infinity,
                  height: 100,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
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
      const Color(0xFFEFF6FF), 
      const Color(0xFFF5F3FF), 
      const Color(0xFFECFDF5), 
      const Color(0xFFFFF7ED), 
    ];
    return colors[nombre.length % colors.length];
  }

  Color _getTextColor(String nombre) {
    final colors = [
      const Color(0xFF2563EB), 
      const Color(0xFF7C3AED), 
      const Color(0xFF059669), 
      const Color(0xFFD97706), 
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

    final bool planActivo = p["plan_activo"] == true;
    final bool validacionConfirmada = p["validacion_confirmada"] == true;

    void handleTap() {
      _onPatientSelected(p);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: handleTap,
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
                              "Estado nutricional: $condicionNutri"),
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
                      planActivo ? "Plan activo" : "Sin plan",
                      planActivo
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBadge(
                      validacionConfirmada
                          ? "Valid. confirmada"
                          : "Valid. pendiente",
                      validacionConfirmada
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                OutlinedButton.icon(
                  onPressed: handleTap,
                  icon: Icon(
                    planActivo ? Icons.edit : Icons.add,
                    size: 14,
                    color: planActivo ? const Color(0xFF3B82F6) : const Color(0xFF22C55E),
                  ),
                  label: Text(
                    planActivo ? "Modificar plan" : "Crear plan",
                    style: TextStyle(
                      color: planActivo ? const Color(0xFF3B82F6) : const Color(0xFF22C55E),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: planActivo ? const Color(0xFF3B82F6) : const Color(0xFF22C55E),
                    side: BorderSide(
                      color: planActivo ? const Color(0xFF3B82F6) : const Color(0xFF22C55E),
                      width: 1.2,
                    ),
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
                Icon(Icons.chevron_right,
                    color: const Color(0xFF94A3B8), 
                    size: 22),
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
    if (text == "Plan activo" ||
        text == "Valid. confirmada" ||
        text == "Validación nutricional confirmada") {
      icon = Icons.verified_user_outlined;
    } else if (text == "No activo" || text == "Sin plan") {
      icon = Icons.remove_circle_outline;
    } else if (text == "Valid. pendiente" ||
        text == "Validación nutricional pendiente") {
      icon = Icons.pending_actions_outlined;
    } else {
      icon = Icons.access_time;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
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
        if (_patientProfile != null)
          PatientSummaryPanel(
            expediente: _patientProfile!,
            formatEdad: _formatEdad,
            onVerExpediente: _mostrarExpedienteMaestroDialog,
          )
        else
          Container(
            width: 320,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: const Column(
              children: [
                NutriShimmer(
                    width: 100,
                    height: 100,
                    borderRadius: BorderRadius.all(Radius.circular(50))),
                SizedBox(height: 24),
                NutriShimmer(width: 200, height: 20),
                SizedBox(height: 12),
                NutriShimmer(width: 120, height: 14),
                SizedBox(height: 48),
                NutriCardShimmer(height: 90),
                SizedBox(height: 20),
                NutriCardShimmer(height: 90),
                SizedBox(height: 20),
                NutriCardShimmer(height: 90),
              ],
            ),
          ),
        Expanded(
          child: Column(
            children: [
              _buildHistoryTopBar(),
              Expanded(
                child: Container(
                  color: const Color(0xFFF1F5F9),
                  child: _isLoading && _patientPlans.isEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.all(40),
                          itemCount: 3,
                          itemBuilder: (_, __) => const Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: NutriCardShimmer(height: 140),
                          ),
                        )
                      : _patientPlans.isEmpty
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
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade100.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1E293B)),
              onPressed: () => setState(() => _selectedPatient = null),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Historial de planes nutricionales",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(
                    "Paciente: ${_selectedPatient?["nombre_completo"] ?? 'N/A'}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: Colors.blueGrey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _startNewPlan,
            icon: const Icon(Icons.add_rounded),
            label: const Text("Crear plan",
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
            label: const Text("Recomendaciones"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.blue.shade50, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.05),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_toggle_off_rounded,
                  size: 56, color: Colors.blue.shade400),
            ),
            const SizedBox(height: 24),
            Text("Aún no hay planes registrados",
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(
                "Comienza diseñando el primer plan alimentario para este paciente. Puedes crear uno manual o recibir recomendaciones.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.blueGrey.shade400)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _startNewPlan,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text("Crear Plan", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    backgroundColor: const Color(0xFF0F172A), // Slate 900
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _abrirRecomendadorIngredientes,
                  icon: const Icon(Icons.eco_outlined, size: 20),
                  label: Text("Recomendaciones", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    foregroundColor: Colors.blueGrey.shade600,
                    side: BorderSide(color: Colors.grey.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      controller: _historyScrollController,
      padding: const EdgeInsets.all(40),
      itemCount: _patientPlans.length,
      itemBuilder: (context, idx) {
        final p = _patientPlans[idx];
        final pId = (p['id'] as num?)?.toInt();
        final bool isLoadingThis = _loadingPlanId == pId;

        return _PremiumPlanCard(
          key: ValueKey("plan_${pId}_${p['porcentaje_adherencia']}_${p['consumidos']}"),
          planData: p,
          isLoading: isLoadingThis,
          onDelete: () => _deletePlan(pId ?? 0),
          onVerDetalle: () => _verDetallePlan(p),
        );
      },
    );
  }

  Widget _buildEditorLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_patientProfile != null)
          PatientSummaryPanel(
            expediente: _patientProfile!,
            formatEdad: _formatEdad,
            onVerExpediente: _mostrarExpedienteMaestroDialog,
          )
        else
          Container(
            width: 320,
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: const Column(
              children: [
                NutriShimmer(width: 80, height: 80, borderRadius: BorderRadius.all(Radius.circular(40))),
                SizedBox(height: 24),
                NutriShimmer(width: 200, height: 20),
                SizedBox(height: 12),
                NutriShimmer(width: 150, height: 14),
                SizedBox(height: 40),
                NutriCardShimmer(height: 80),
                SizedBox(height: 16),
                NutriCardShimmer(height: 80),
              ],
            ),
          ),

        Expanded(
          child: Column(
            children: [
              _buildModernTopBar(),
              Expanded(
                child: Container(
                  color: const Color(0xFFF1F5F9),
                  child: _isLoading && _weeklyPlan.isEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.all(32),
                          itemCount: 3,
                          itemBuilder: (_, __) => Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const NutriShimmer(width: 100, height: 80),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const NutriShimmer(width: 200, height: 20),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: List.generate(3, (index) => const NutriShimmer(width: 220, height: 150)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildWeeklyTimeline(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTopBar() {
    final bool canFinalize =
        (_editingPlanId == null || _isDirty) && !_isSaving;
        
    final String titleText = _editingPlanId != null && !_isDirty
        ? "Detalles del Plan de ${DateFormat('dd/MM/yyyy').format(_startDate)} a ${DateFormat('dd/MM/yyyy').format(_endDate)}"
        : "Diseño de plan nutricional";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF0F172A)),
                ),
                Text(
                  "Paciente: ${_selectedPatient!["nombre_completo"]}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: Colors.blueGrey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildActionButton(
            label: "Ajustar configuración",
            icon: Icons.tune_rounded,
            onPressed: _showConfigModal,
            color: Colors.blueGrey.shade700,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            label: "Finalizar plan",
            icon: Icons.check_circle_rounded,
            onPressed: canFinalize ? () => _savePlan() : () {},
            color: canFinalize ? greenBrand : Colors.grey,
            isPrimary: true,
            isLoading: _isSaving,
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
      bool isPrimary = false,
      bool isLoading = false}) {
    if (isPrimary) {
      return FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            Opacity(
              opacity: isLoading ? 0.0 : 1.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            ),
          Opacity(
            opacity: isLoading ? 0.0 : 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(label,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
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
                      width: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                            ),
                            child: Text(
                              DateFormat('EEE', 'es_EC').format(day.date).toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              DateFormat('d').format(day.date),
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                color: const Color(0xFF1E293B),
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF22C55E).withValues(alpha: 0.5),
                                const Color(0xFF22C55E).withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
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

    final Color pastelColor = _getMomentColor(s.momentId);
    final Color darkColor = _getMomentColorDark(s.momentId);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: pastelColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
        border: Border.all(
            color: darkColor.withValues(alpha: 0.3),
            width: hasRecipe ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: darkColor.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(_getMomentIcon(s.momentId),
                    size: 14, color: darkColor),
                const SizedBox(width: 8),
                Text(_capitalize(s.mealType),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: darkColor,
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: InkWell(
                            onTap: () => mostrarDetalleRecetaVerde(
                                context, (rec["id"] as num?)?.toInt() ?? 0, ref),
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
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18, color: Colors.blueGrey),
                                  tooltip: "Eliminar esta receta",
                                  onPressed: () {
                                    setState(() {
                                      s.recipes.remove(rec);
                                      _isDirty = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSlotActionIcon(
                            icon: Icons.edit_note_rounded,
                            label: "Editar",
                            color: Colors.blueGrey.shade700,
                            tooltip: "Cambiar o añadir recetas",
                            onTap: () => _openRecipePicker(dayIdx, slotIdx),
                          ),
                          _buildSlotActionIcon(
                            icon: Icons.delete_outline_rounded,
                            label: "Borrar",
                            color: Colors.redAccent.shade400,
                            tooltip: "Limpiar esta comida",
                            onTap: () => setState(() {
                              s.recipes = [];
                              _isDirty = true;
                            }),
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
                              BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
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

  Map<int, bool> _momentosPasados = {};
  int _singleMealId = 3;

  void _showConfigModal() async {
    bool morningSnack = _morningSnackEnabled;
    bool afternoonSnack = _afternoonSnackEnabled;
    
    final isAdjusting = _planInitialized;
    bool isGenerating = false;

    final now = DateTime.now();
    if (!isAdjusting && _startDate.year == now.year && _startDate.month == now.month && _startDate.day == now.day) {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get("tutor/momentos-comida");
        final momentos = List<dynamic>.from(res.data);
        final Map<int, bool> pasados = {};

        for (var m in momentos) {
          final mId = m['id'];
          final horaFinStr = m['hora_fin'];
          if (horaFinStr == null) continue;
          final parts = horaFinStr.toString().split(':');
          final mHoraFin = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          final currentTodo = TimeOfDay.fromDateTime(now);
          bool yaPaso = currentTodo.hour > mHoraFin.hour || 
                       (currentTodo.hour == mHoraFin.hour && currentTodo.minute > mHoraFin.minute);
          
          if (yaPaso) {
            pasados[mId] = true;
            if (mId == 2) morningSnack = false;
            if (mId == 4) afternoonSnack = false;
          }
        }

        _momentosPasados = pasados;
        if (_momentosPasados[_singleMealId] == true) {
          final available = [1, 2, 3, 4, 5].where((id) => _momentosPasados[id] != true).toList();
          if (available.isNotEmpty) {
            _singleMealId = available.first;
          }
        }
      } catch (e) {
        debugPrint("Error pre-configurando momentos inteligentes: $e");
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final availableMoments = [1, 2, 3, 4, 5].where((id) => _momentosPasados[id] != true).toList();

          return AlertDialog(
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
                    _buildModalSectionTitle("Periodo de vigencia"),
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
                        DropdownMenuItem(value: "una comida", child: Text("Una sola comida")),
                        DropdownMenuItem(value: "un día", child: Text("Un día completo")),
                        DropdownMenuItem(
                            value: "una semana", child: Text("Una semana")),
                        DropdownMenuItem(value: "un mes", child: Text("Un mes")),
                      ],
                      onChanged: (v) {
                        if (v == "una comida") {
                          Navigator.pop(context);
                          setState(() => _isAssigningSingleMeal = true);
                          return;
                        }
                        setModalState(() {
                          _durationType = v!;
                          if (_durationType == "un día") {
                            _endDate = _startDate;
                          } else if (_durationType == "una semana") {
                            _endDate = _startDate.add(const Duration(days: 6));
                          } else if (_durationType == "un mes") {
                            DateTime? proximaCitaDate;
                            if (_patientProfile != null) {
                              final c = _patientProfile!['ultimo_control'] ?? {};
                              final str = c['fecha_proxima_cita']?.toString();
                              if (str != null && str.isNotEmpty) {
                                try { proximaCitaDate = DateTime.parse(str); } catch (_) {}
                              }
                            }
                            if (proximaCitaDate != null && proximaCitaDate.isAfter(_startDate)) {
                              _endDate = proximaCitaDate.subtract(const Duration(days: 1));
                            } else {
                              _endDate = _startDate.add(const Duration(days: 30));
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildModalSectionTitle("Resumen de fechas"),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
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
                      onPressed: isGenerating
                          ? null
                          : () {
                              if (isAdjusting) {
                                Navigator.pop(context);
                              } else {
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
                      onPressed: isGenerating
                          ? null
                          : () async {
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
                                            "⚠️ Restricción de seguridad clínica",
                                            style:
                                                TextStyle(fontWeight: FontWeight.bold)),
                                        Text(
                                            "El plan excede la fecha del próximo control ($proximaCitaStr)."),
                                        const Text("Acciones sugeridas:"),
                                        const Text(
                                            "• Edite un plan existente para ampliarlo."),
                                        const Text(
                                            "• Cree un plan de menor duración (día/semana)."),
                                        const Text(
                                            "• Elimine planes futuros para liberar el calendario."),
                                      ],
                                    ),
                                    duration: const Duration(seconds: 8),
                                  ));
                                  return;
                                }
                              }

                              setModalState(() => isGenerating = true);
                              _morningSnackEnabled = morningSnack;
                              _afternoonSnackEnabled = afternoonSnack;
                              
                              final List<int> selectedMomentos = [];
                              selectedMomentos.addAll([1, 3, 5]);
                              if (morningSnack) selectedMomentos.add(2);
                              if (afternoonSnack) selectedMomentos.add(4);
                              
                              if (context.mounted) Navigator.pop(context);

                              await _initPlanAutomaticWithCustomMoments(selectedMomentos);
                            },
                      child: isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Continuar y generar plan"),
                    ),
                  ),
                ],
              )
            ],
          );
        }
      ),
    );
  }


  String _getMomentName(int id) {
    switch (id) {
      case 1: return "Desayuno";
      case 2: return "Media mañana";
      case 3: return "Almuerzo";
      case 4: return "Media tarde";
      case 5: return "Merienda";
      default: return "Comida";
    }
  }

  void _initPlan(bool morning, bool afternoon) {
    final List<PlanDay> plan = [];
    DateTime current = _startDate;

    final Map<String, Map<int, List<dynamic>>> planPrevio = {};
    for (var d in _weeklyPlan) {
      final dateKey = DateFormat('yyyy-MM-dd').format(d.date);
      planPrevio[dateKey] = {};
      for (var s in d.slots) {
        planPrevio[dateKey]![s.momentId] = List.from(s.recipes);
      }
    }

    while (!current.isAfter(_endDate)) {
      final dateKey = DateFormat('yyyy-MM-dd').format(current);
      final prevDay = planPrevio[dateKey];
      final List<MealSlot> newSlots = [];
      List<dynamic> getPrevRecipes(int mId) => prevDay?[mId] ?? [];

      newSlots.add(MealSlot(
          mealType: "Desayuno", momentId: 1, recipes: getPrevRecipes(1)));
      if (morning) {
        newSlots.add(MealSlot(
            mealType: "Media mañana", momentId: 2, recipes: getPrevRecipes(2)));
      }
      newSlots.add(MealSlot(
          mealType: "Almuerzo", momentId: 3, recipes: getPrevRecipes(3)));
      if (afternoon) {
        newSlots.add(MealSlot(
            mealType: "Media tarde", momentId: 4, recipes: getPrevRecipes(4)));
      }
      newSlots.add(MealSlot(
          mealType: "Merienda", momentId: 5, recipes: getPrevRecipes(5)));

      plan.add(PlanDay(date: current, slots: newSlots));
      current = current.add(const Duration(days: 1));
    }

    setState(() {
      _weeklyPlan = plan;
      _planInitialized = true;
    });
  }

  Future<void> _initPlanAutomaticWithCustomMoments(List<int> momentosIds) async {
    final idPaciente = _selectedPatient?['id']?.toString();
    if (idPaciente == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = "Iniciando generación de plan inteligente...";
    });

    try {
      final repo = ref.read(inteligenciaRepositoryProvider);
      final totalDias = _endDate.difference(_startDate).inDays + 1;

      final progressMessages = [
        "Analizando perfil clínico y reglas de seguridad...",
        "Filtrando catálogo de recetas seguras para el paciente...",
        "Generando menús equilibrados para cada momento...",
        "Optimizando variedad y rotación de alimentos...",
        "Finalizando estructura del plan nutricional..."
      ];

      int msgIdx = 0;
      final timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (msgIdx < progressMessages.length && _isLoading) {
          if (mounted) {
            setState(() => _loadingMessage = progressMessages[msgIdx++]);
          }
        } else {
          t.cancel();
        }
      });

      final resp = await repo.planAutomatico(
        idPaciente: idPaciente,
        fechaInicio: _startDate,
        dias: totalDias,
        momentosIds: momentosIds,
      );

      timer.cancel();
      final List<dynamic> diasData = resp['dias'] ?? [];
      final List<PlanDay> plan = [];

      for (var diaData in diasData) {
        final DateTime fecha = DateTime.parse(diaData['fecha']);
        final List<dynamic> comidas = diaData['comidas'] ?? [];
        final Map<int, MealSlot> groupedSlots = {};

        for (var comida in comidas) {
          final int mId = comida['id_momento'];
          final recipe = {
            "id": comida['id_receta'],
            "nombre": comida['nombre_receta'],
            "semaforo": comida['semaforo'] ?? "neutral",
            "imagen_url": comida['imagen_url'],
          };
          if (groupedSlots.containsKey(mId)) {
            groupedSlots[mId]!.recipes.add(recipe);
          } else {
            groupedSlots[mId] = MealSlot(
              mealType: comida['nombre_momento'],
              momentId: mId,
              recipes: [recipe],
            );
          }
        }
        final sortedSlots = groupedSlots.keys.toList()..sort();
        plan.add(PlanDay(
            date: fecha,
            slots: sortedSlots.map((id) => groupedSlots[id]!).toList()));
      }

      if (mounted) {
        setState(() {
          _weeklyPlan = plan;
          _planInitialized = true;
          _isLoading = false;
          _loadingMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al generar plan automático: $e")),
        );
      }
    }
  }

  String? _loadingMessage;

  Widget _buildLoadingOverlay() {
    if (!_isLoading || _loadingMessage == null) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 4,
            ),
            const SizedBox(height: 24),
            Text(
              "Generando plan automático",
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _loadingMessage!,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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

  Color _getMomentColor(int momentId) {
    switch (momentId) {
      case 1:
        return Colors.orange.shade50;
      case 2:
        return Colors.yellow.shade50;
      case 3:
        return Colors.blue.shade50;
      case 4:
        return Colors.teal.shade50;
      case 5:
        return Colors.indigo.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getMomentColorDark(int momentId) {
    switch (momentId) {
      case 1:
        return Colors.orange.shade800;
      case 2:
        return Colors.amber.shade900;
      case 3:
        return Colors.blue.shade800;
      case 4:
        return Colors.teal.shade800;
      case 5:
        return Colors.indigo.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  Widget _buildSlotActionIcon({
    required IconData icon,
    required String label,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
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
            onSelected: (recipes) {
              setState(() {
                slot.recipes = recipes;
                _isDirty = true;
              });
            },
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
      _isDirty = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Día duplicado exitosamente")));
  }

  // El método _mostrarDetalleReceta fue reemplazado por mostrarDetalleRecetaVerde

  void _savePlan() async {
    // ELIMINADA la restricción de que cada slot debe tener una receta.
    // Esto permite guardar planes de una sola comida o con momentos omitidos por horario.

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

    setState(() {
      _isSaving = true;
      _saveSuccess = false;
    });

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
        "boosters": _boostersSeleccionados,
      });
      final savedPatientId = _selectedPatient!["id"]?.toString();
      if (mounted) {
        setState(() {
          _isDirty = false;
          _saveSuccess = true;
          if (savedPatientId != null) {
            for (var p in _patients) {
              if (p['id']?.toString() == savedPatientId) {
                p['plan_activo'] = true;
              }
            }
            if (_selectedPatient != null) {
              _selectedPatient!['plan_activo'] = true;
            }
          }
        });
        _fetchPatientsSilently();
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          _onPatientSelected(_selectedPatient!); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    final validNames = [
      "emaciación severa", "emaciación", "emaciacion severa", "emaciacion",
      "delgadez severa", "delgadez",
      "bajo peso severo", "bajo peso",
      "peso normal para la edad", "normal",
      "posible riesgo de sobrepeso", "sobrepeso", "obesidad",
      "peso elevado para la edad"
    ];
    
    final filtered = condiciones.where((c) {
      final nombre = (c["nombre"] ?? "").toString().toLowerCase();
      if (nombre.contains("talla") || nombre.contains("crecimiento")) return false; // STRICT EXCLUSION
      
      // Remove accents for comparison just in case
      final normalized = nombre.replaceAll('ó', 'o').replaceAll('í', 'i').replaceAll('á', 'a');
      return validNames.any((v) => normalized.contains(v) || normalized == v);
    }).toList();
    
    // Deduplicate by name
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in filtered) {
      final name = (c["nombre"] ?? "").toString().trim();
      if (!uniqueMap.containsKey(name)) {
        uniqueMap[name] = c;
      }
    }
    return uniqueMap.values.toList();
  }

  List<Map<String, dynamic>> _filtrarCondicionesTalla(
      List<Map<String, dynamic>> condiciones) {
    final validNames = [
      "talla baja severa", "talla baja",
      "talla normal", "talla alta"
    ];
    
    final filtered = condiciones.where((c) {
      final nombre = (c["nombre"] ?? "").toString().toLowerCase();
      return validNames.any((v) => nombre.contains(v));
    }).toList();
    
    // Deduplicate by name
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in filtered) {
      final name = (c["nombre"] ?? "").toString().trim();
      if (!uniqueMap.containsKey(name)) {
        uniqueMap[name] = c;
      }
    }
    return uniqueMap.values.toList();
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
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 1000,
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 850),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5EAF2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppTema.azulPrincipal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_ind_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Expediente Maestro Integral",
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                            "Registro oficial del paciente y soporte legal en el sistema ReumaNutri",
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF64748B),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      hoverColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1, color: Color(0xFFE5EAF2)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Expanded(
                            child:
                                _buildExpSection("1. Identidad del paciente", [
                          _expItem("Nombres completos", p['nombre_completo']),
                          _expItem("Cédula / ID", p['cedula']),
                          _expItem(
                              "Fecha de nacimiento", p['fecha_nacimiento']),
                          _expItem("Sexo biológico", p['sexo_nombre']),
                          const SizedBox(height: 16),
                          const Text("Localización",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          _expItem("Cantón de residencia", p['canton_nombre']),
                          _expItem("Parroquia", p['parroquia_nombre']),
                        ])),
                        const SizedBox(width: 40),
                        Expanded(
                            child: _buildExpSection("2. Representante legal", [
                          _expItem("Nombre del tutor", t['nombre_completo']),
                          _expItem("Cédula del tutor", t['cedula']),
                          _expItem("Parentesco", t['parentesco_nombre']),
                          const SizedBox(height: 16),
                          const Text("Contacto",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          _expItem("Correo electrónico", t['email']),
                          _expItem("Teléfono / Móvil", t['telefono']),
                          _expItem("Dirección de domicilio", t['direccion']),
                        ])),
                        const SizedBox(width: 40),
                        Expanded(
                            child:
                                _buildExpSection("3. Estado clínico actual", [
                          _expItem("Diagnóstico principal",
                              d['condicion_nombre'] ?? "AIJ"),
                          _expItem("Estado nutricional (OMS)",
                              c['estado_nutricional'],
                              isBold: true),
                          _expItem("Peso / Talla",
                              "${c['peso_kg'] ?? '-'} kg / ${c['talla_cm'] ?? '-'} cm"),
                          _expItem("Inflamación actual",
                              "${c['escala_inflamacion'] ?? 0}/3"),
                          _expItem("Brote activo",
                              (c['en_brote'] == true) ? "Sí (activo)" : "No",
                              isAlert: c['en_brote'] == true),
                          const SizedBox(height: 16),
                          const Text("Seguimiento",
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          _expItem(
                              "Fecha de último control", c['fecha_control']),
                          _expItem("Próxima cita programada",
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
                          label: const Text("Entendido"),
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
              color: greenBrand.withValues(alpha: 0.1),
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
            Text(v?.toString() ?? "No registrado",
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
      final catalogoTipos =
          List<Map<String, dynamic>>.from(tiposRes.data ?? []);
      final todasLasRecetas =
          List<dynamic>.from(recetasRes.data["recetas"] ?? []);
      final conteosPorTipo = <int, int>{};
      for (final receta in todasLasRecetas) {
        final ids = receta["tipos_plato_ids"];
        if (ids is! Iterable) continue;
        final idsUnicos =
            ids.map((id) => (id as num?)?.toInt()).whereType<int>().toSet();
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
                  const Text("Seleccionar receta segura",
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

class _PremiumPlanCard extends StatefulWidget {
  final Map<String, dynamic> planData;
  final bool isLoading;
  final VoidCallback onDelete;
  final VoidCallback onVerDetalle;

  const _PremiumPlanCard({
    super.key,
    required this.planData,
    required this.isLoading,
    required this.onDelete,
    required this.onVerDetalle,
  });

  @override
  State<_PremiumPlanCard> createState() => _PremiumPlanCardState();
}

class _PremiumPlanCardState extends State<_PremiumPlanCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.planData;
    final isVigente = p["vigente"] == true;
    final adherence = ((p["porcentaje_adherencia"] as num?) ?? 0.0).toDouble();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? Colors.green.shade200 : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.shade900.withValues(alpha: _isHovered ? 0.08 : 0.03),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              // Icono premium
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isVigente
                      ? Colors.green.shade50
                      : (_isHovered ? Colors.grey.shade100 : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isVigente ? Colors.green.shade200 : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Icon(Icons.assignment_rounded,
                    size: 28,
                    color: isVigente ? Colors.green.shade600 : Colors.blueGrey.shade400),
              ),
              const SizedBox(width: 24),
              
              // Información principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("Plan Nutricional",
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: -0.5,
                                color: const Color(0xFF0F172A))),
                        const SizedBox(width: 12),
                        if (isVigente)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 12, color: Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  "Vigente",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: Colors.blueGrey.shade400),
                        const SizedBox(width: 6),
                        Text(
                          "Vigencia: ${p["fecha_inicio"]} hasta ${p["fecha_fin"]}",
                          style: GoogleFonts.inter(
                              color: Colors.blueGrey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.restaurant_rounded, size: 14, color: Colors.blueGrey.shade400),
                        const SizedBox(width: 6),
                        Text("Configuración: ${p["comidas_por_dia"]} comidas por día",
                            style: GoogleFonts.inter(
                                color: Colors.blueGrey.shade500, fontSize: 13, fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Acciones y Adherencia
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("Origen: ${p["origen_plan"]}",
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.blueGrey.shade500)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _isHovered ? Colors.red.shade50 : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 20,
                              color: _isHovered ? Colors.red.shade400 : Colors.grey.shade400),
                          onPressed: widget.onDelete,
                          tooltip: "Eliminar plan",
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        height: 38,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _isHovered ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            foregroundColor: _isHovered ? Colors.white : const Color(0xFF334155),
                            elevation: _isHovered ? 4 : 0,
                            shadowColor: Colors.black.withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: widget.isLoading ? null : widget.onVerDetalle,
                          child: widget.isLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _isHovered ? Colors.white : const Color(0xFF334155)))
                              : Text("Ver detalle", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 160,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: (adherence / 100.0).clamp(0.0, 1.0),
                      ),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedVal, _) {
                        final displayPct = (animatedVal * 100).round();
                        final isGood = displayPct > 70;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Adherencia",
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey.shade500)),
                                Text("$displayPct%",
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isGood
                                            ? Colors.green.shade600
                                            : Colors.blue.shade600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: animatedVal,
                                backgroundColor: Colors.grey.shade100,
                                color: isGood
                                    ? Colors.green.shade500
                                    : Colors.blue.shade500,
                                minHeight: 6,
                              ),
                            ),
                          ],
                        );
                      },
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
}
