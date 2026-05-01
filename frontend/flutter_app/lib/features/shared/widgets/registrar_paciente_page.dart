import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/state/app_providers.dart";

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
  final int _idProvincia = 5; // Chimborazo
  String? _enfermedadBase;

  // --- ALERGIAS E INTOLERANCIAS ---
  bool? _esIntoleranteLactosa;
  bool? _tieneAlergiaGrupos;
  bool? _tieneAlergiaIngredientes;
  final List<int> _selectedSubgrupos = [];
  final List<Map<String, dynamic>> _selectedIngredientes = [];

  // --- DATOS CLÍNICOS ---
  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();
  final _pcrCtrl = TextEditingController();
  final _rigidezCtrl = TextEditingController();
  final _observacionesMedicoCtrl = TextEditingController();
  final int _dolorEva = 0;
  final int _inflamacion = 0;
  final int _fatiga = 0;
  bool _brote = false;

  // --- TUTOR ---
  final _cedulaTutorCtrl = TextEditingController();
  final _nombreTutorCtrl = TextEditingController();
  final _emailTutorCtrl = TextEditingController();
  final _telTutorCtrl = TextEditingController();
  final _dirTutorCtrl = TextEditingController();
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
          _nombreTutorCtrl.text = res.data['nombre'] ?? "";
          _emailTutorCtrl.text = res.data['email'] ?? "";
          _tutorVerificado = true; _esTutorNuevo = false;
        });
        _showMsg("✅ Tutor encontrado", Colors.blue);
      } else {
        setState(() {
          _nombreTutorCtrl.clear(); _emailTutorCtrl.clear();
          _tutorVerificado = true; _esTutorNuevo = true;
        });
        _showMsg("ℹ️ Tutor nuevo. Complete los datos.", Colors.orange);
      }
    } finally { setState(() => _buscandoTutor = false); }
  }

  void _showMsg(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  Future<void> _registrar() async {
    if (_nombreCtrl.text.isEmpty || _fnac == null || _idSexo == null || _enfermedadBase == null || !_tutorVerificado || _idParentesco == null) {
      return _showMsg("⚠️ Faltan campos obligatorios", Colors.red);
    }

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      
      final payload = {
        "paciente": {
          "nombre_completo": _nombreCtrl.text,
          "fecha_nacimiento": _fnac!.toIso8601String().split('T')[0],
          "id_sexo": _idSexo,
          "id_provincia": _idProvincia,
        },
        "tutor": {
          "cedula": _cedulaTutorCtrl.text,
          "nombre": _nombreTutorCtrl.text,
          "email": _emailTutorCtrl.text,
          "id_parentesco": _idParentesco,
        },
        "salud": {
          "id_patologia_base": _condicionesClinicas.firstWhere((c) => c['nombre'] == _enfermedadBase)['id'],
          "peso_kg": double.tryParse(_pesoCtrl.text) ?? 0,
          "talla_cm": double.tryParse(_tallaCtrl.text) ?? 0,
          "edad_meses": (DateTime.now().difference(_fnac!).inDays / 30).floor(),
          "dolor_eva": _dolorEva,
          "inflamacion": _inflamacion,
          "fatiga": _fatiga,
          "pcr": double.tryParse(_pcrCtrl.text) ?? 0,
          "rigidez_min": int.tryParse(_rigidezCtrl.text) ?? 0,
          "brote_activo": _brote,
          "alergias_ingredientes": _selectedIngredientes.map((e) => e['id']).toList(),
          "alergias_subgrupos": _selectedSubgrupos,
          "observaciones_medicas": _observacionesMedicoCtrl.text,
        }
      };

      await dio.post("gestion-pacientes/registrar", data: payload);
      _showMsg("✅ Expediente Maestro Creado", Colors.green);
      widget.onBack();
    } catch (e) { _showMsg("❌ Error en el registro integral", Colors.red); }
    finally { setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCatalogos) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("REGISTRO INTEGRAL DEL PACIENTE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF00BFA5),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSectionIdentidad()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildSectionClinica()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSectionAlergias()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildSectionTutor()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _card(
                    title: "OBSERVACIONES MÉDICAS GENERALES", icon: Icons.edit_note, color: Colors.blueGrey,
                    child: TextFormField(controller: _observacionesMedicoCtrl, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Notas adicionales del médico...")),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: FilledButton(
                      onPressed: _saving ? null : _registrar,
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(_saving ? "GUARDANDO..." : "FINALIZAR REGISTRO MAESTRO", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionIdentidad() {
    return _card(title: "1. DATOS DE IDENTIDAD", icon: Icons.person, color: Colors.blue, child: Column(
      children: [
        TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: "Nombre Completo *", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
            title: Text(_fnac == null ? "Fecha Nacimiento *" : _fnac!.toLocal().toString().split(' ')[0]),
            onTap: () async {
              final d = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now());
              if (d != null) setState(() => _fnac = d);
            },
          )),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<int>(
            initialValue: _idSexo, items: _sexos.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['nombre']))).toList(),
            onChanged: (v) => setState(() => _idSexo = v), decoration: const InputDecoration(labelText: "Sexo *", border: OutlineInputBorder()),
          )),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _enfermedadBase, items: _condicionesClinicas.map((c) => DropdownMenuItem<String>(value: c['nombre'], child: Text(c['nombre']))).toList(),
          onChanged: (v) => setState(() => _enfermedadBase = v), decoration: const InputDecoration(labelText: "Enfermedad Base *", border: OutlineInputBorder()),
        ),
      ],
    ));
  }

  Widget _buildSectionClinica() {
    return _card(title: "2. ESTADO CLÍNICO (BROTE Y PCR)", icon: Icons.health_and_safety, color: Colors.teal, child: Column(
      children: [
        Row(children: [
          Expanded(child: TextFormField(controller: _pesoCtrl, decoration: const InputDecoration(labelText: "Peso (kg) *", border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: _tallaCtrl, decoration: const InputDecoration(labelText: "Talla (cm) *", border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 12),
        TextFormField(controller: _pcrCtrl, decoration: const InputDecoration(labelText: "PCR (Proteína C Reactiva) *", border: OutlineInputBorder(), hintText: "Valor numérico")),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _brote ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _brote ? Colors.red : Colors.green)),
          child: SwitchListTile(
            title: Text(_brote ? "BROTE ACTIVO" : "SIN BROTE", style: TextStyle(fontWeight: FontWeight.bold, color: _brote ? Colors.red : Colors.green)),
            subtitle: const Text("Estado inflamatorio actual de la enfermedad"),
            value: _brote, onChanged: (v) => setState(() => _brote = v), activeThumbColor: Colors.red,
          ),
        ),
      ],
    ));
  }

  Widget _buildSectionAlergias() {
    return _card(title: "3. SEGURIDAD: ALERGIAS", icon: Icons.warning_amber_rounded, color: Colors.redAccent, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _preguntaSiNo(
          pregunta: "¿ES INTOLERANTE A LA LACTOSA?",
          valor: _esIntoleranteLactosa,
          onChanged: (v) => setState(() {
            _esIntoleranteLactosa = v;
            if (v == true) {
              _marcarLacteosAuto();
            } else {
              _quitarLacteosAuto();
            }
          }),
        ),
        const Divider(height: 32),
        _preguntaSiNo(
          pregunta: "¿TIENE ALERGIAS A GRUPOS (MARISCOS, ETC)?",
          valor: _tieneAlergiaGrupos,
          onChanged: (v) => setState(() {
            _tieneAlergiaGrupos = v;
            if (v == false) _selectedSubgrupos.clear();
            // Mantener lácteos si Step 1 fue SÍ
            if (_esIntoleranteLactosa == true) _marcarLacteosAuto();
          }),
        ),
        if (_tieneAlergiaGrupos == true) 
          Container(
            height: 140, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: ListView(children: _allSubgrupos.where((s) {
              final isLacteo = s['nombre'].toString().toLowerCase().contains("lácteo");
              // REDUNDANCIA: Si ya dijo que es intolerante, NO mostramos los grupos lácteos aquí
              if (_esIntoleranteLactosa == true && isLacteo) return false;
              return true;
            }).map((s) => CheckboxListTile(
              title: Text(s['nombre'], style: const TextStyle(fontSize: 13)), value: _selectedSubgrupos.contains(s['id']),
              onChanged: (v) => setState(() { if(v!) {
                _selectedSubgrupos.add(s['id']);
              } else {
                _selectedSubgrupos.remove(s['id']);
              } }),
            )).toList()),
          ),
        const Divider(height: 32),
        _preguntaSiNo(
          pregunta: "¿ALERGIA A INGREDIENTES PUNTUALES?",
          valor: _tieneAlergiaIngredientes,
          onChanged: (v) => setState(() => _tieneAlergiaIngredientes = v),
        ),
        if (_tieneAlergiaIngredientes == true) 
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (o) => o['nombre'],
              optionsBuilder: (v) => _allIngredientes.where((i) {
                final n = i['nombre'].toString().toLowerCase();
                final subgrupoId = i['id_subgrupo_alimentario'];

                // 1. FILTRO LACTOSA: Si es intolerante, bloqueamos derivados por nombre por seguridad
                if (_esIntoleranteLactosa == true && (n.contains("leche") || n.contains("queso") || n.contains("lactosa") || n.contains("yogurt"))) return false;
                
                // 2. FILTRO REDUNDANCIA GRUPO: Si el subgrupo ya está bloqueado (ej. Mariscos), no mostrar ingrediente
                if (subgrupoId != null && _selectedSubgrupos.contains(subgrupoId)) return false;

                return n.contains(v.text.toLowerCase());
              }).cast<Map<String, dynamic>>(),
              onSelected: (i) => setState(() {
                if (!_selectedIngredientes.any((x) => x['id'] == i['id'])) {
                  _selectedIngredientes.add(i);
                }
              }),
            ),
          ),
        if (_selectedIngredientes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, children: _selectedIngredientes.map((i) => Chip(
              label: Text(i['nombre'], style: const TextStyle(fontSize: 10)),
              onDeleted: () => setState(() => _selectedIngredientes.remove(i)),
            )).toList()),
          ),
      ],
    ));
  }

  Widget _preguntaSiNo({required String pregunta, bool? valor, required Function(bool) onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(pregunta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      Row(children: [
        _btnSiNo(label: "SÍ", isSelected: valor == true, color: Colors.redAccent, onTap: () => onChanged(true)),
        const SizedBox(width: 10),
        _btnSiNo(label: "NO", isSelected: valor == false, color: Colors.green, onTap: () => onChanged(false)),
      ]),
    ]);
  }

  Widget _btnSiNo({required String label, required bool isSelected, required Color color, required VoidCallback onTap}) {
    return Expanded(child: InkWell(onTap: onTap, child: Container(
      height: 45, alignment: Alignment.center,
      decoration: BoxDecoration(color: isSelected ? color : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
    )));
  }

  void _marcarLacteosAuto() {
    final ids = _allSubgrupos.where((s) => s['nombre'].toString().toLowerCase().contains("lácteo")).map((s) => s['id'] as int);
    setState(() => _selectedSubgrupos.addAll(ids));
  }

  void _quitarLacteosAuto() {
    final ids = _allSubgrupos.where((s) => s['nombre'].toString().toLowerCase().contains("lácteo")).map((s) => s['id'] as int).toSet();
    setState(() => _selectedSubgrupos.removeWhere((id) => ids.contains(id)));
  }

  Widget _buildSectionTutor() {
    return _card(title: "4. REPRESENTANTE", icon: Icons.family_restroom, color: Colors.orange, child: Column(
      children: [
        Row(children: [
          Expanded(child: TextFormField(controller: _cedulaTutorCtrl, decoration: const InputDecoration(labelText: "Cédula *", border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _verificarTutor, child: const Text("VERIFICAR")),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _idParentesco, items: _parentescos.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['nombre']))).toList(),
          onChanged: (v) => setState(() => _idParentesco = v), decoration: const InputDecoration(labelText: "Parentesco *", border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _nombreTutorCtrl, enabled: _esTutorNuevo, decoration: const InputDecoration(labelText: "Nombre Tutor *", border: OutlineInputBorder())),
      ],
    ));
  }

  Widget _card({required String title, required IconData icon, required Color color, required Widget child}) {
    return Card(
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
        const SizedBox(height: 20),
        child,
      ])),
    );
  }
}
