import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/state/app_providers.dart";
import "../../../shared/models/app_role.dart";

class RegistrarPacientePage extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  const RegistrarPacientePage({super.key, required this.onBack});

  @override
  ConsumerState<RegistrarPacientePage> createState() => _RegistrarPacientePageState();
}

class _RegistrarPacientePageState extends ConsumerState<RegistrarPacientePage> {
  final _formKey = GlobalKey<FormState>();
  bool _loadingCatalogos = true;
  bool _saving = false;

  // --- CATÁLOGOS ---
  List<dynamic> _sexos = [];
  List<dynamic> _provincias = [];
  List<dynamic> _parentescos = [];
  List<dynamic> _condicionesClinicas = [];
  List<dynamic> _allSubgrupos = [];
  List<dynamic> _allIngredientes = [];

  // --- DATOS PACIENTE ---
  final _nombreCtrl = TextEditingController();
  DateTime? _fnac;
  int? _idSexo;
  int _idProvincia = 5; // Chimborazo
  String? _enfermedadBase;

  // --- ALERGIAS ---
  final List<int> _selectedSubgrupos = [];
  final List<Map<String, dynamic>> _selectedIngredientes = [];
  final _searchIngredienteCtrl = TextEditingController();

  // --- DATOS CLÍNICOS INICIALES ---
  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();
  final _pcrCtrl = TextEditingController();
  final _rigidezCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  int _dolorEva = 0;
  int _inflamacion = 0;
  int _fatiga = 0;
  bool _brote = false;

  // --- DATOS TUTOR ---
  final _cedulaTutorCtrl = TextEditingController();
  final _nombreTutorCtrl = TextEditingController();
  final _emailTutorCtrl = TextEditingController();
  final _telTutorCtrl = TextEditingController();
  final _dirTutorCtrl = TextEditingController();
  
  String? _idTutorExistente;
  int? _idParentesco;
  bool _tutorVerificado = false;
  bool _esTutorNuevo = false;
  bool _buscandoTutor = false;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get("gestion-pacientes/catalogos"),
        dio.get("ingredientes-lista", queryParameters: {"limit": 2000})
      ]);
      
      setState(() {
        _sexos = results[0].data['sexos'];
        _provincias = results[0].data['provincias'];
        _parentescos = results[0].data['parentescos'];
        _condicionesClinicas = results[0].data['condiciones_clinicas'];
        _allSubgrupos = results[0].data['subgrupos'];
        _allIngredientes = results[1].data['items'];
        _loadingCatalogos = false;
      });
    } catch (e) {
      setState(() => _loadingCatalogos = false);
    }
  }

  Future<void> _verificarTutor() async {
    if (_cedulaTutorCtrl.text.isEmpty) return _showMsg("Ingrese cédula del tutor", Colors.red);
    setState(() => _buscandoTutor = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("gestion-pacientes/buscar-tutor/${_cedulaTutorCtrl.text}");
      if (res.data['existe'] == true) {
        setState(() {
          _idTutorExistente = res.data['id'];
          _nombreTutorCtrl.text = res.data['nombre'] ?? "";
          _emailTutorCtrl.text = res.data['email'] ?? "";
          _telTutorCtrl.text = res.data['telefono'] ?? "";
          _dirTutorCtrl.text = res.data['direccion'] ?? "";
          _tutorVerificado = true; _esTutorNuevo = false;
        });
        _showMsg("✅ Tutor encontrado", Colors.blue);
      } else {
        setState(() {
          _idTutorExistente = null; _nombreTutorCtrl.clear(); _emailTutorCtrl.clear();
          _tutorVerificado = true; _esTutorNuevo = true;
        });
        _showMsg("ℹ️ Tutor nuevo. Complete los datos.", Colors.orange);
      }
    } finally { setState(() => _buscandoTutor = false); }
  }

  void _showMsg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  Future<void> _registrar() async {
    if (_nombreCtrl.text.isEmpty || _fnac == null || _idSexo == null || _enfermedadBase == null || !_tutorVerificado || _idParentesco == null) {
      return _showMsg("⚠️ Faltan campos obligatorios o verificar al tutor", Colors.red);
    }

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        "nombre": _nombreCtrl.text,
        "fecha_nacimiento": _fnac!.toIso8601String().split('T')[0],
        "id_sexo": _idSexo,
        "id_provincia": _idProvincia,
        "enfermedad_principal": _enfermedadBase,
        "id_parentesco": _idParentesco,
        "id_tutor": _idTutorExistente,
        "tutor_cedula": _cedulaTutorCtrl.text,
        "tutor_nombre": _nombreTutorCtrl.text,
        "tutor_email": _emailTutorCtrl.text,
        "tutor_telefono": _telTutorCtrl.text,
        "tutor_direccion": _dirTutorCtrl.text,
        "alergias_ingredientes": _selectedIngredientes.map((e) => e['id']).toList(),
        "alergias_subgrupos": _selectedSubgrupos
      };

      final resP = await dio.post("gestion-pacientes/registrar", data: payload);
      final String newId = resP.data['id'];

      await dio.post("gestion-pacientes/control", data: {
        "id_paciente": newId,
        "peso_kg": double.tryParse(_pesoCtrl.text) ?? 0,
        "talla_cm": double.tryParse(_tallaCtrl.text) ?? 0,
        "nivel_dolor_eva": _dolorEva,
        "nivel_inflamacion": _inflamacion,
        "nivel_fatiga": _fatiga,
        "inflamacion_pcr": double.tryParse(_pcrCtrl.text) ?? 0,
        "minutos_rigidez_matutina": int.tryParse(_rigidezCtrl.text) ?? 0,
        "hay_brote_activo": _brote,
        "nota_evolucion": "Registro Inicial Maestro. ${_notaCtrl.text}",
      });

      _showMsg("✅ Expediente Completo Creado", Colors.green);
      widget.onBack();
    } catch (e) { _showMsg("❌ Error en el registro", Colors.red); }
    finally { setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCatalogos) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)),
        title: const Text("REGISTRO MAESTRO DE PACIENTE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
        backgroundColor: const Color(0xFF00BFA5), // TURQUESA
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: _buildSectionIdentidad()),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildSectionClinica()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: _buildSectionAlergias()),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildSectionTutor()),
                    ],
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity, height: 65,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _registrar,
                      icon: const Icon(Icons.cloud_done_outlined),
                      label: Text(_saving ? "PROCESANDO..." : "FINALIZAR Y CREAR EXPEDIENTE COMPLETO", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionIdentidad() {
    return _card(title: "1. IDENTIDAD DEL NIÑO(A)", icon: Icons.child_care, color: Colors.blue, child: Column(
      children: [
        TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: "Nombre Completo *", border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
            title: Text(_fnac == null ? "Fecha Nacimiento *" : _fnac!.toLocal().toString().split(' ')[0]),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final d = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now());
              if (d != null) setState(() => _fnac = d);
            },
          )),
          const SizedBox(width: 16),
          Expanded(child: DropdownButtonFormField<int>(
            value: _idSexo, items: _sexos.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['nombre']))).toList(),
            onChanged: (v) => setState(() => _idSexo = v), decoration: const InputDecoration(labelText: "Sexo *", border: OutlineInputBorder()),
          )),
        ]),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _idProvincia, items: _provincias.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['nombre']))).toList(),
          onChanged: null, decoration: const InputDecoration(labelText: "Provincia (Fijo: Chimborazo)", border: OutlineInputBorder(), filled: true),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _enfermedadBase, items: _condicionesClinicas.map((c) => DropdownMenuItem<String>(value: c['nombre'], child: Text(c['nombre']))).toList(),
          onChanged: (v) => setState(() => _enfermedadBase = v), decoration: const InputDecoration(labelText: "Enfermedad Base *", border: OutlineInputBorder()),
        ),
      ],
    ));
  }

  Widget _buildSectionClinica() {
    return _card(title: "2. ESTADO CLÍNICO INICIAL", icon: Icons.monitor_heart, color: Colors.teal, child: Column(
      children: [
        Row(children: [
          Expanded(child: TextFormField(controller: _pesoCtrl, decoration: const InputDecoration(labelText: "Peso (kg)", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          const SizedBox(width: 16),
          Expanded(child: TextFormField(controller: _tallaCtrl, decoration: const InputDecoration(labelText: "Talla (cm)", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          const Text("Dolor (EVA): "),
          Expanded(child: Slider(value: _dolorEva.toDouble(), min: 0, max: 10, divisions: 10, label: _dolorEva.toString(), activeColor: Colors.orange, onChanged: (v) => setState(() => _dolorEva = v.toInt()))),
          Text(_dolorEva.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text("Inflamación: "),
          Expanded(child: Slider(value: _inflamacion.toDouble(), min: 0, max: 10, divisions: 10, label: _inflamacion.toString(), activeColor: Colors.redAccent, onChanged: (v) => setState(() => _inflamacion = v.toInt()))),
          Text(_inflamacion.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text("Fatiga:       "),
          Expanded(child: Slider(value: _fatiga.toDouble(), min: 0, max: 10, divisions: 10, label: _fatiga.toString(), activeColor: Colors.blueGrey, onChanged: (v) => setState(() => _fatiga = v.toInt()))),
          Text(_fatiga.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextFormField(controller: _pcrCtrl, decoration: const InputDecoration(labelText: "PCR Inicial", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          const SizedBox(width: 16),
          Expanded(child: TextFormField(controller: _rigidezCtrl, decoration: const InputDecoration(labelText: "Rigidez (min)", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
        ]),
        SwitchListTile(title: const Text("¿Brote activo?"), value: _brote, onChanged: (v) => setState(() => _brote = v), activeColor: Colors.red),
      ],
    ));
  }

  Widget _buildSectionAlergias() {
    return _card(title: "3. ALERGIAS E INTOLERANCIAS", icon: Icons.no_food, color: Colors.redAccent, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Paso 1: ¿Alergia a algún subgrupo completo?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 150, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
          child: ListView(children: _allSubgrupos.map((s) => CheckboxListTile(
            title: Text(s['nombre'], style: const TextStyle(fontSize: 12)), value: _selectedSubgrupos.contains(s['id']),
            onChanged: (v) => setState(() { if (v!) _selectedSubgrupos.add(s['id']); else _selectedSubgrupos.remove(s['id']); }), dense: true,
          )).toList()),
        ),
        const SizedBox(height: 20),
        const Text("Paso 2: Alergias a ingredientes específicos", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (o) => o['nombre'],
          optionsBuilder: (v) => _allIngredientes.where((i) => i['nombre'].toString().toLowerCase().contains(v.text.toLowerCase())).cast<Map<String, dynamic>>(),
          onSelected: (i) { if (!_selectedIngredientes.any((x) => x['id'] == i['id'])) setState(() => _selectedIngredientes.add(i)); },
          fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) => TextField(
            controller: ctrl, focusNode: focus, decoration: const InputDecoration(hintText: "Buscar ingrediente...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: _selectedIngredientes.map((i) => Chip(
          label: Text(i['nombre'], style: const TextStyle(fontSize: 10)), onDeleted: () => setState(() => _selectedIngredientes.remove(i)),
        )).toList()),
      ],
    ));
  }

  Widget _buildSectionTutor() {
    return _card(title: "4. REPRESENTANTE (TUTOR)", icon: Icons.person_search, color: Colors.orange, child: Column(
      children: [
        Row(children: [
          Expanded(child: TextFormField(controller: _cedulaTutorCtrl, decoration: const InputDecoration(labelText: "Cédula Tutor *", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _buscandoTutor ? null : _verificarTutor, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), child: const Text("VERIFICAR")),
        ]),
        if (_tutorVerificado) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _idParentesco, items: _parentescos.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['nombre']))).toList(),
            onChanged: (v) => setState(() => _idParentesco = v), decoration: const InputDecoration(labelText: "Parentesco *", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _nombreTutorCtrl, enabled: _esTutorNuevo, decoration: const InputDecoration(labelText: "Nombre Completo *", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: _emailTutorCtrl, enabled: _esTutorNuevo, decoration: const InputDecoration(labelText: "Email *", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: _telTutorCtrl, decoration: const InputDecoration(labelText: "Teléfono", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: _dirTutorCtrl, decoration: const InputDecoration(labelText: "Dirección", border: OutlineInputBorder())),
        ]
      ],
    ));
  }

  Widget _card({required String title, required IconData icon, required Color color, required Widget child}) {
    return Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 10), Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color))]),
        const SizedBox(height: 20),
        child,
      ])),
    );
  }
}
