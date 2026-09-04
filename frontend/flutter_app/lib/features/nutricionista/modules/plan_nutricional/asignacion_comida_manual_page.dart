import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../shared/widgets/patient_summary_panel.dart';
import 'widgets/receta_modal_verde.dart';

class AsignacionComidaManualPage extends ConsumerStatefulWidget {
  final String idPaciente;
  final String nombrePaciente;
  final Map<String, dynamic> patientProfile;
  final String Function(String?) formatEdad;
  final VoidCallback onVerExpediente;
  final VoidCallback onBack;
  final VoidCallback? onSaved;

  const AsignacionComidaManualPage({
    super.key,
    required this.idPaciente,
    required this.nombrePaciente,
    required this.patientProfile,
    required this.formatEdad,
    required this.onVerExpediente,
    required this.onBack,
    this.onSaved,
  });

  @override
  ConsumerState<AsignacionComidaManualPage> createState() =>
      _AsignacionComidaManualPageState();
}

class _AsignacionComidaManualPageState
    extends ConsumerState<AsignacionComidaManualPage> {
  bool _isLoading = false;
  bool _saveSuccess = false;
  List<dynamic> _recetasResultados = [];
  int? _idRecetaSeleccionada;
  
  List<dynamic> _momentos = [];
  int _idMomentoSeleccionado = 3; // Por defecto Almuerzo
  
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _diasAutoCtrl = TextEditingController(text: "1");
  final TextEditingController _saltoAutoCtrl = TextEditingController(text: "2");
  String _patronAuto = "Seguidos";

  final Set<DateTime> _fechasSeleccionadas = {};
  
  late DateTime _fechaMin;
  
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaMin = DateTime(now.year, now.month, now.day);
    _cargarMomentos();
    _buscarRecetas("");
  }
  
  Future<void> _cargarMomentos() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get("tutor/momentos-comida");
      if (mounted) {
        setState(() {
          _momentos = List<dynamic>.from(response.data);
        });
      }
    } catch (e) {
      debugPrint("Error cargando momentos: $e");
    }
  }
  
  Future<void> _buscarRecetas(String query) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("tutor/recetas-seguras/${widget.idPaciente}", queryParameters: {
        "consulta": query,
        "limite": 50
      });
      if (mounted) {
        setState(() {
          _recetasResultados = List<dynamic>.from(res.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error buscando recetas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarAsignacion() async {
    if (_idRecetaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debes seleccionar una receta.")));
      return;
    }
    if (_fechasSeleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debes seleccionar al menos una fecha.")));
      return;
    }
    
    setState(() {
      _isLoading = true;
      _saveSuccess = false;
    });
    
    try {
      final dio = ref.read(dioProvider);
      await dio.post("nutricionista/asignar-comida-manual-fechas", data: {
        "id_paciente": widget.idPaciente,
        "id_receta": _idRecetaSeleccionada!,
        "id_momento": _idMomentoSeleccionado,
        "fechas": _fechasSeleccionadas.map((f) => f.toIso8601String()).toList(),
      });
      if (mounted) {
        setState(() => _saveSuccess = true);
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          setState(() => _isLoading = false);
          if (widget.onSaved != null) {
            widget.onSaved!();
          } else {
            widget.onBack();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget _buildSavingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_saveSuccess)
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
                _saveSuccess
                    ? "Plan guardado con éxito"
                    : "Guardando Plan...",
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

  Widget _buildCalendarioGrid() {
    final List<DateTime> dias = [];
    for (int i = 0; i <= 30; i++) {
      dias.add(_fechaMin.add(Duration(days: i)));
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4
      ),
      itemCount: dias.length,
      itemBuilder: (context, index) {
        final dia = dias[index];
        final isSelected = _fechasSeleccionadas.any((d) => d.year == dia.year && d.month == dia.month && d.day == dia.day);
        
        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _fechasSeleccionadas.removeWhere((d) => d.year == dia.year && d.month == dia.month && d.day == dia.day);
              } else {
                _fechasSeleccionadas.add(dia);
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF22C55E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.green.shade700 : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected 
                ? [BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('E', 'es_EC').format(dia).toUpperCase(), 
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade500,
                  )
                ),
                const SizedBox(height: 2),
                Text(
                  "${dia.day}", 
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 16,
                    color: isSelected ? Colors.white : Colors.blueGrey.shade800,
                  )
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _aplicarAutocompletado() {
    int cantidad = int.tryParse(_diasAutoCtrl.text) ?? 1;
    if (cantidad <= 0) cantidad = 1;
    if (cantidad > 30) cantidad = 30;
    
    setState(() {
      _fechasSeleccionadas.clear();
      int agregados = 0;
      int desplazamiento = 0;
      
      while (agregados < cantidad && desplazamiento <= 60) {
        final dia = _fechaMin.add(Duration(days: desplazamiento));
        
        if (_patronAuto == "Seguidos") {
          _fechasSeleccionadas.add(dia);
          agregados++;
        } else if (_patronAuto == "Interdiario") {
          if (desplazamiento % 2 == 0) {
            _fechasSeleccionadas.add(dia);
            agregados++;
          }
        } else if (_patronAuto == "Personalizado") {
          int salto = int.tryParse(_saltoAutoCtrl.text) ?? 2;
          if (salto < 0) salto = 0;
          if (desplazamiento % (salto + 1) == 0) {
            _fechasSeleccionadas.add(dia);
            agregados++;
          }
        }
        desplazamiento++;
      }
    });
  }

  IconData _getIconForMomento(String nombre) {
    final lower = nombre.toLowerCase();
    if (lower.contains("desayuno")) return Icons.wb_twilight;
    if (lower.contains("almuerzo")) return Icons.wb_sunny;
    if (lower.contains("cena")) return Icons.nights_stay;
    if (lower.contains("colación") || lower.contains("snack")) return Icons.apple;
    return Icons.restaurant;
  }

  Widget _buildDropdownItem(int id, String nombre) {
    bool isSelected = _idMomentoSeleccionado == id;
    Color color = isSelected ? Colors.green.shade800 : Colors.blueGrey.shade800;
    Color bgColor = isSelected ? Colors.green.shade50 : Colors.transparent;
    Color iconBgColor = isSelected ? Colors.green.shade200.withValues(alpha: 0.5) : Colors.blueGrey.shade50;
    Color iconColor = isSelected ? Colors.green.shade700 : Colors.blueGrey.shade500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(_getIconForMomento(nombre), color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              nombre,
              style: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          if (isSelected)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String number, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: Colors.green.shade500, width: 4))
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(number, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.green.shade900)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Left Sidebar: Patient Profile
          PatientSummaryPanel(
            expediente: widget.patientProfile,
            formatEdad: widget.formatEdad,
            onVerExpediente: widget.onVerExpediente,
          ),
          
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Header Estilo Web
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1E293B)),
                          onPressed: widget.onBack,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Plan Nutricional de una Sola Comida",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
                                    color: const Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            Text(
                              "Paciente: ${widget.nombrePaciente}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: Colors.blueGrey.shade500,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade300),
          // Content Layout
          Expanded(
            child: Container(
              color: Colors.white,
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // Panel Izquierdo: Buscador de Recetas
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("1", "Selecciona la receta"),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre de alimento...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Color(0xFF16A34A)),
                        onPressed: () => _buscarRecetas(_searchCtrl.text),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Color(0xFF16A34A)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: _buscarRecetas,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading && _recetasResultados.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            itemCount: _recetasResultados.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final r = _recetasResultados[index];
                              final isSelected = _idRecetaSeleccionada == r["id"];
                              
                              final String? imgUrl = r["imagen_url"];
                              String categorias = "";
                              if (r["tipos_plato_nombres"] is List) {
                                categorias = (r["tipos_plato_nombres"] as List).join(", ");
                              } else if (r["tipos_plato_nombres"] is String) {
                                categorias = r["tipos_plato_nombres"];
                              }

                              return InkWell(
                                onTap: () => mostrarDetalleRecetaVerde(
                                  context, 
                                  r["id"], 
                                  ref, 
                                  onSelect: () => setState(() => _idRecetaSeleccionada = r["id"])
                                ),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blue.shade50 : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? Colors.blue.shade400 : Colors.grey.shade200,
                                      width: isSelected ? 2 : 1
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4)
                                      )
                                    ]
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Imagen de la receta
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          image: imgUrl != null && imgUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(imgUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: imgUrl == null || imgUrl.isEmpty
                                            ? const Icon(Icons.restaurant, color: Colors.grey, size: 30)
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      // Textos
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r["nombre"] ?? "Sin nombre", 
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700, 
                                                fontSize: 16,
                                                color: Colors.blueGrey.shade900
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              (r["descripcion"] != null && r["descripcion"].toString().isNotEmpty)
                                                  ? r["descripcion"]
                                                  : (categorias.isEmpty ? "Receta general" : categorias),
                                              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Icono de selección
                                      if (isSelected)
                                        Container(
                                          margin: const EdgeInsets.only(left: 12),
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle
                                          ),
                                          child: const Icon(Icons.check, color: Colors.white, size: 20),
                                        )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  )
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.black12),
          // Panel Derecho: Opciones de Asignación
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)
                    ),
                    child: Text(
                      "Busca y selecciona una receta segura del catálogo. Luego elige el momento del día y estampa las fechas en el calendario para agendarla.",
                      style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 14, height: 1.4),
                    ),
                  ),
                  _buildSectionHeader("2", "Selecciona el momento"),
                  DropdownButtonFormField<int>(
                    value: _momentos.isNotEmpty ? _idMomentoSeleccionado : null,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    icon: const Icon(Icons.expand_more, color: Colors.green),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.green.shade500)),
                      filled: true,
                      fillColor: Colors.white
                    ),
                    selectedItemBuilder: (context) {
                      return _momentos.map((m) => Row(
                        children: [
                          Icon(_getIconForMomento(m["nombre"]), color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            m["nombre"],
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 15),
                          )
                        ]
                      )).toList();
                    },
                    items: _momentos.map((m) => DropdownMenuItem<int>(
                      value: m["id"],
                      child: _buildDropdownItem(m["id"], m["nombre"])
                    )).toList(),
                    onChanged: (v) => setState(() => _idMomentoSeleccionado = v!),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader("3", "Días a asignar en el calendario"),
                  const Text("Seleccione las fechas manualmente en la cuadrícula inferior, o utilice el asistente automático.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4)
                        )
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.blueGrey.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text("Asistente de Autocompletado", style: TextStyle(color: Colors.blueGrey.shade800, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Pregunta 1
                        const Text("1. ¿Cuántas veces en total comerá el paciente esta receta?", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            controller: _diasAutoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              suffixText: "veces",
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Pregunta 2
                        const Text("2. ¿Con qué frecuencia desea asignarla en el calendario?", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ["Seguidos", "Interdiario", "Personalizado"].map((patron) {
                            final isSelected = _patronAuto == patron;
                            return ChoiceChip(
                              label: Text(patron == "Interdiario" ? "Interdiario (1 sí, 1 no)" : patron),
                              selected: isSelected,
                              showCheckmark: false,
                              onSelected: (v) {
                                if (v) setState(() => _patronAuto = patron);
                              },
                              selectedColor: const Color(0xFF16A34A),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: isSelected ? const Color(0xFF16A34A) : Colors.black12),
                              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            );
                          }).toList(),
                        ),
                        
                        // Pregunta 3 (Solo si es personalizado)
                        if (_patronAuto == "Personalizado") ...[
                          const SizedBox(height: 20),
                          const Text("3. ¿Cuántos días de descanso habrá entre comidas?", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 140,
                            child: TextFormField(
                              controller: _saltoAutoCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: "días",
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _aplicarAutocompletado,
                            icon: const Icon(Icons.calendar_month, size: 18),
                            label: const Text("Generar fechas en el calendario"),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D), // Green shade 700
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCalendarioGrid(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: _isLoading || _fechasSeleccionadas.isEmpty || _idRecetaSeleccionada == null ? null : _guardarAsignacion,
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                      label: Text(_isLoading ? "Guardando..." : "Guardar plan nutricional (${_fechasSeleccionadas.length} días)", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
          ],
              ),
            ),
          ),
        ],
      ),
      ),
      ],
      ),
      if (_isLoading) _buildSavingOverlay(),
      ],
      ),
    );
  }
}
