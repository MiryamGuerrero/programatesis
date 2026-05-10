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
  List<dynamic> _cantones = [];
  List<dynamic> _parroquiasCat = [];
  List<dynamic> _parroquiasFiltradas = [];
  List<dynamic> _parentescos = [];
  List<dynamic> _condicionesClinicas = [];
  List<dynamic> _allSubgrupos = [];
  List<dynamic> _allIngredientes = [];

  // --- DATOS PACIENTE ---
  final _nombreCtrl = TextEditingController();
  final _cedulaPacCtrl = TextEditingController();
  DateTime? _fnac;
  int? _idSexo;
  int? _idCanton;
  int? _idParroquia;
  final int _idProvincia = 5; // Chimborazo (Bloqueado)
  String? _enfermedadBase;

  // --- ALERGIAS E INTOLERANCIAS ---
  bool _esIntoleranteLactosa = false;
  static const Set<int> _subgruposLactosa = {98, 100, 101, 104, 105, 108, 111, 114, 117, 119};
  bool _tieneAlergiaGrupos = false;
  bool _tieneAlergiaIngredientes = false;
  final List<int> _selectedSubgrupos = [];
  final List<Map<String, dynamic>> _selectedIngredientes = [];

  String _emojiSubgrupo(int id) {
    return {
      8: "🍄", 9: "🍄", 10: "🥔", 11: "🥦", 12: "🥫", 13: "🥬", 14: "🥤", 15: "🍓",
      16: "🍇", 17: "🍎", 18: "🥜", 19: "🍊", 24: "🥚", 25: "🍗", 26: "🐖", 27: "🐑",
      29: "🥩", 30: "🐄", 31: "🫀", 32: "🦐", 33: "🐟", 34: "🐠", 35: "🐟", 36: "🥫",
      37: "🧂", 38: "🫒", 41: "🧄", 43: "🍬", 47: "🍭", 48: "🍿", 49: "🥤", 50: "💧",
      51: "☕", 53: "🧃", 88: "🌾", 89: "🌾", 90: "🍞", 91: "🍞", 92: "🍝", 93: "🫘",
      94: "🌱", 95: "🫘", 96: "🥫", 97: "🥜", 98: "🥛", 99: "🥛", 100: "🍶", 101: "🥛",
      102: "🥛", 103: "🥥", 104: "🥛", 105: "🧀", 106: "🧀", 107: "🧀", 108: "🧀",
      109: "🥓", 110: "🌭", 111: "🧈", 112: "🧈", 113: "🥓", 114: "🥣", 115: "🥣",
      116: "🥢", 117: "🍫", 118: "🍫", 119: "🍮", 120: "🍬", 121: "🍪", 122: "🥛",
      123: "🥛", 124: "🥛",
    }[id] ?? "🍽️";
  }

  // --- DATOS CLÍNICOS ---
  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();
  final _pcrCtrl = TextEditingController();
  final _rigidezCtrl = TextEditingController();
  final _observacionesMedicoCtrl = TextEditingController();
  int _dolorEva = 0;
  int _inflamacion = 0;
  final int _fatiga = 0;
  bool _brote = false;

  // --- TUTOR ---
  final _cedulaTutorCtrl = TextEditingController();
  final _nombreTutorCtrl = TextEditingController();
  final _emailTutorCtrl = TextEditingController();
  final _telTutorCtrl = TextEditingController();
  final _dirTutorCtrl = TextEditingController();
  int? _idParentesco;
  bool? _tutorEncontrado; // null: no verificado, true: encontrado, false: nuevo
  bool _buscandoTutor = false;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      
      final results = await Future.wait([
        repo.fetchCatalog("usuarios", "catalogo_sexo"),
        repo.fetchCatalog("usuarios", "catalogo_canton"),
        repo.fetchCatalog("usuarios", "catalogo_parroquia"),
        repo.fetchCatalog("usuarios", "parentesco"),
        repo.fetchCatalog("nutricion", "condiciones_clinicas"),
        repo.fetchCatalog("nutricion", "subgrupos_alimentarios"),
        repo.fetchCatalog("nutricion", "ingredientes"),
      ]);

      if (mounted) {
        setState(() {
          _sexos = results[0];
          _cantones = results[1];
          _parroquiasCat = results[2];
          _parentescos = results[3];
          _condicionesClinicas = results[4];
          _allSubgrupos = results[5];
          _allIngredientes = results[6];
          
          _idCanton = 1; // Riobamba por defecto
          _parroquiasFiltradas = _parroquiasCat.where((p) => p['id_canton'] == _idCanton).toList();
          
          _loadingCatalogos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cargando catálogos: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _verificarTutor() async {
    if (_cedulaTutorCtrl.text.length < 10) return;
    setState(() => _buscandoTutor = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final res = await repo.findTutorByCedula(_cedulaTutorCtrl.text);
      if (mounted) {
        setState(() {
          if (res != null) {
            _nombreTutorCtrl.text = res['nombre_completo'] ?? "";
            _emailTutorCtrl.text = res['email'] ?? "";
            _telTutorCtrl.text = res['telefono'] ?? "";
            _dirTutorCtrl.text = res['direccion'] ?? "";
            _tutorEncontrado = true;
          } else {
            _tutorEncontrado = false;
          }
          _buscandoTutor = false;
        });
      }
    } catch (_) {
      setState(() => _buscandoTutor = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fnac == null || _idSexo == null || _idParentesco == null || _enfermedadBase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor complete todos los campos obligatorios (*)"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final payload = {
        "paciente": {
          "nombre_completo": _nombreCtrl.text,
          "cedula": _cedulaPacCtrl.text,
          "fecha_nacimiento": _fnac!.toIso8601String(),
          "id_sexo": _idSexo,
          "id_canton": _idCanton,
          "id_parroquia": _idParroquia,
          "enfermedad_base": _enfermedadBase,
        },
        "clinico": {
          "peso_kg": double.tryParse(_pesoCtrl.text) ?? 0,
          "talla_cm": double.tryParse(_tallaCtrl.text) ?? 0,
          "pcr": double.tryParse(_pcrCtrl.text) ?? 0,
          "rigidez_matutina": int.tryParse(_rigidezCtrl.text) ?? 0,
          "dolor_eva": _dolorEva,
          "inflamacion": _inflamacion,
          "brote": _brote,
          "observaciones": _observacionesMedicoCtrl.text,
        },
        "alergias": {
          "es_intolerante_lactosa": _esIntoleranteLactosa,
          "subgrupos_ids": _selectedSubgrupos,
          "ingredientes_ids": _selectedIngredientes.map((i) => i['id']).toList(),
        },
        "tutor": {
          "cedula": _cedulaTutorCtrl.text,
          "nombre_completo": _nombreTutorCtrl.text,
          "email": _emailTutorCtrl.text,
          "telefono": _telTutorCtrl.text,
          "direccion": _dirTutorCtrl.text,
          "id_parentesco": _idParentesco,
          "es_nuevo": _tutorEncontrado == false,
        }
      };

      await repo.registerIntegral(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expediente creado con éxito"), backgroundColor: Colors.green));
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCatalogos) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text("REGISTRO INTEGRAL DE PACIENTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildSectionPaciente(),
              const SizedBox(height: 24),
              _buildSectionClinica(),
              const SizedBox(height: 24),
              _buildSectionAlergias(),
              const SizedBox(height: 24),
              _buildSectionTutor(),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _guardar,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text("FINALIZAR REGISTRO E INICIAR EXPEDIENTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionPaciente() {
    return _card(title: "1. IDENTIDAD DEL PACIENTE", icon: Icons.person_rounded, color: Colors.blue.shade800, child: Column(
      children: [
        TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: "Nombres y Apellidos Completos *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextFormField(controller: _cedulaPacCtrl, decoration: const InputDecoration(labelText: "Cédula / Pasaporte", border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge_outlined), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16)))),
          const SizedBox(width: 16),
          Expanded(child: _buildDateField()),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(
            initialValue: _idSexo, items: _sexos.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['descripcion']))).toList(),
            onChanged: (v) => setState(() => _idSexo = v), decoration: const InputDecoration(labelText: "Sexo Biológico *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.wc)),
          )),
          const SizedBox(width: 16),
          Expanded(child: _field(TextEditingController(text: "CHIMBORAZO"), "Provincia (Fijo)", Icons.location_on, enabled: false)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(
            initialValue: _idCanton, items: _cantones.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nombre']))).toList(),
            onChanged: (v) => setState(() {
              _idCanton = v;
              _idParroquia = null;
              _parroquiasFiltradas = _parroquiasCat.where((p) => p['id_canton'] == v).toList();
            }),
            decoration: const InputDecoration(labelText: "Cantón *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.map_outlined)),
          )),
          const SizedBox(width: 16),
          Expanded(child: DropdownButtonFormField<int>(
            initialValue: _idParroquia, items: _parroquiasFiltradas.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['nombre']))).toList(),
            onChanged: (v) => setState(() => _idParroquia = v),
            decoration: const InputDecoration(labelText: "Parroquia *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city)),
          )),
        ]),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _enfermedadBase, items: _condicionesClinicas.map((c) => DropdownMenuItem<String>(value: c['nombre'], child: Text(c['nombre']))).toList(),
          onChanged: (v) => setState(() => _enfermedadBase = v), decoration: const InputDecoration(labelText: "Diagnóstico Reumatológico Base *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.medication)),
        ),
      ],
    ));
  }

  Widget _buildSectionClinica() {
    return _card(title: "2. PARÁMETROS CLÍNICOS INICIALES", icon: Icons.analytics_rounded, color: Colors.teal.shade700, child: Column(
      children: [
        Row(children: [
          Expanded(child: TextFormField(controller: _pesoCtrl, decoration: const InputDecoration(labelText: "Peso (kg) *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.monitor_weight), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16)))),
          const SizedBox(width: 16),
          Expanded(child: TextFormField(controller: _tallaCtrl, decoration: const InputDecoration(labelText: "Talla (cm) *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.height), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16)))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextFormField(controller: _pcrCtrl, decoration: const InputDecoration(labelText: "PCR (mg/L) *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.biotech), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16)))),
          const SizedBox(width: 16),
          Expanded(child: TextFormField(controller: _rigidezCtrl, decoration: const InputDecoration(labelText: "Rigidez Matutina (min)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.timer), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16)))),
        ]),
        const SizedBox(height: 16),
        _buildMetricSlider("DOLOR (EVA)", _dolorEva, (v) => setState(() => _dolorEva = v.toInt()), Colors.orange),
        const SizedBox(height: 16),
        _buildMetricSlider("INFLAMACIÓN", _inflamacion, (v) => setState(() => _inflamacion = v.toInt()), Colors.red),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _brote ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: _brote ? Colors.red.shade200 : Colors.green.shade200, width: 2)),
          child: SwitchListTile(
            title: Text(_brote ? "EL PACIENTE SE ENCUENTRA EN BROTE ACTIVO" : "PACIENTE SIN BROTE DETECTADO", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _brote ? Colors.red.shade900 : Colors.green.shade900)),
            subtitle: const Text("Marque si presenta inflamación sistémica o crisis aguda"),
            value: _brote, onChanged: (v) => setState(() => _brote = v), activeThumbColor: Colors.red.shade700,
          ),
        ),
      ],
    ));
  }

  Widget _buildMetricSlider(String label, int val, Function(double) onC, Color col) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text("$val/10", style: TextStyle(fontWeight: FontWeight.bold, color: col))]),
      Slider(value: val.toDouble(), min: 0, max: 10, divisions: 10, onChanged: onC, activeColor: col, inactiveColor: col.withOpacity(0.1)),
    ]);
  }

  Widget _buildSectionAlergias() {
    return _card(title: "3. SEGURIDAD Y ALERGIAS", icon: Icons.security_rounded, color: Colors.red.shade700, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _preguntaSiNo(
          pregunta: "¿PRESENTA INTOLERANCIA A LA LACTOSA?",
          valor: _esIntoleranteLactosa,
          onChanged: (v) => setState(() {
            _esIntoleranteLactosa = v;
            if (v) {
              _marcarLacteosAuto();
            } else {
              _quitarLacteosAuto();
            }
          }),
        ),
        const SizedBox(height: 20),
        _preguntaSiNo(
          pregunta: "¿TIENE ALERGIAS A OTROS GRUPOS ALIMENTARIOS?",
          valor: _tieneAlergiaGrupos,
          onChanged: (v) => setState(() => _tieneAlergiaGrupos = v),
        ),
        if (_tieneAlergiaGrupos) 
          Container(
            height: 180, margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
            child: ListView(children: _allSubgrupos.where((s) {
              final id = s['id'] as int;
              if (_esIntoleranteLactosa && _subgruposLactosa.contains(id)) return false;
              return true;
            }).map((s) => CheckboxListTile(
              dense: true,
              title: Row(
                children: [
                  Text(_emojiSubgrupo(s['id']), style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s['nombre'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
              ),
              value: _selectedSubgrupos.contains(s['id']),
              onChanged: (v) => setState(() { if(v!) {
                _selectedSubgrupos.add(s['id']);
              } else {
                _selectedSubgrupos.remove(s['id']);
              } }),
            )).toList()),
          ),
        const SizedBox(height: 20),
        _preguntaSiNo(
          pregunta: "¿TIENE ALERGIAS A INGREDIENTES ESPECÍFICOS?",
          valor: _tieneAlergiaIngredientes,
          onChanged: (v) => setState(() => _tieneAlergiaIngredientes = v),
        ),
        if (_tieneAlergiaIngredientes) 
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (o) => o['nombre'],
              optionsBuilder: (v) {
                if (v.text.isEmpty) return const Iterable.empty();
                return _allIngredientes.where((i) {
                  final idSub = (i['id_subgrupo_alimentario'] as num?)?.toInt();
                  final subBloqueados = <int>{};
                  if (_esIntoleranteLactosa) subBloqueados.addAll(_subgruposLactosa);
                  subBloqueados.addAll(_selectedSubgrupos);
                  if (idSub != null && subBloqueados.contains(idSub)) return false;
                  return i['nombre'].toString().toLowerCase().contains(v.text.toLowerCase());
                }).cast<Map<String, dynamic>>();
              },
              onSelected: (i) => setState(() {
                if (!_selectedIngredientes.any((x) => x['id'] == i['id'])) {
                  _selectedIngredientes.add(i);
                  _autoBloquearDerivados(i['nombre']);
                }
              }),
              fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                String feedback = "Buscar ingrediente...";
                if (_esIntoleranteLactosa) feedback = "Lactosa activada: Lácteos bloqueados automáticamente.";
                if (_selectedSubgrupos.isNotEmpty) feedback = "Subgrupos seleccionados: Ingredientes bloqueados.";
                
                return TextField(
                  controller: ctrl, 
                  focusNode: focus, 
                  decoration: InputDecoration(
                    labelText: feedback, 
                    labelStyle: const TextStyle(fontSize: 12),
                    border: const OutlineInputBorder(), 
                    prefixIcon: const Icon(Icons.search)
                  )
                );
              },
            ),
          ),
        if (_selectedIngredientes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: _selectedIngredientes.map((i) => Chip(
              label: Text(i['nombre'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.red.shade50, deleteIconColor: Colors.red,
              onDeleted: () => setState(() => _selectedIngredientes.remove(i)),
            )).toList()),
          ),
      ],
    ));
  }

  void _autoBloquearDerivados(String nombre) {
    final n = nombre.toLowerCase().trim();
    final derivados = _allIngredientes.where((i) {
      final iname = i['nombre'].toString().toLowerCase();
      bool matches = (iname.contains(n) && iname != n);
      if (!matches) {
        if (n.contains("fresa") && (iname.contains("mermelada") || iname.contains("yogurt"))) {
          matches = iname.contains("fresa");
        }
        if (n.contains("coco") && (iname.contains("aceite") || iname.contains("leche") || iname.contains("rallado"))) {
          matches = iname.contains("coco");
        }
      }
      return matches;
    }).toList();
    
    for (var d in derivados) {
      if (!_selectedIngredientes.any((x) => x['id'] == d['id'])) {
        _selectedIngredientes.add(d);
      }
    }
  }

  Widget _preguntaSiNo({required String pregunta, required bool valor, required Function(bool) onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(pregunta, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF334155))),
      const SizedBox(height: 8),
      Row(children: [
        _btnSiNo(label: "SÍ", isSelected: valor, color: Colors.red.shade700, onTap: () => onChanged(true)),
        const SizedBox(width: 12),
        _btnSiNo(label: "NO", isSelected: !valor, color: Colors.green.shade700, onTap: () => onChanged(false)),
      ]),
    ]);
  }

  Widget _btnSiNo({required String label, required bool isSelected, required Color color, required VoidCallback onTap}) {
    return Expanded(child: InkWell(onTap: onTap, child: Container(
      height: 48, alignment: Alignment.center,
      decoration: BoxDecoration(color: isSelected ? color : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: isSelected ? Colors.white : Colors.grey.shade600, fontSize: 13)),
    )));
  }

  void _marcarLacteosAuto() {
    setState(() => _selectedSubgrupos.removeWhere((id) => _subgruposLactosa.contains(id)));
  }

  void _quitarLacteosAuto() {
  }

  Widget _buildSectionTutor() {
    return _card(title: "4. REPRESENTANTE (TUTOR)", icon: Icons.family_restroom_rounded, color: Colors.orange.shade800, child: Column(
      children: [
        Row(children: [
          Expanded(child: TextFormField(controller: _cedulaTutorCtrl, decoration: const InputDecoration(labelText: "Cédula del Tutor *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.fingerprint), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16)))),
          const SizedBox(width: 12),
          SizedBox(height: 56, child: ElevatedButton.icon(onPressed: _buscandoTutor ? null : _verificarTutor, icon: _buscandoTutor ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_search), label: const Text("VALIDAR"))),
        ]),
        if (_tutorEncontrado != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12), width: double.infinity,
            decoration: BoxDecoration(color: _tutorEncontrado! ? Colors.blue.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: _tutorEncontrado! ? Colors.blue.shade200 : Colors.orange.shade200)),
            child: Row(children: [Icon(_tutorEncontrado! ? Icons.check_circle : Icons.info, color: _tutorEncontrado! ? Colors.blue : Colors.orange), const SizedBox(width: 12), Expanded(child: Text(_tutorEncontrado! ? "TUTOR ENCONTRADO: Los datos se cargaron automáticamente." : "TUTOR NO ENCONTRADO: Por favor complete los datos manualmente.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _tutorEncontrado! ? Colors.blue.shade900 : Colors.orange.shade900)))]),
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(controller: _nombreTutorCtrl, decoration: const InputDecoration(labelText: "Nombre Completo del Tutor *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16))),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _idParentesco, items: _parentescos.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['nombre']))).toList(),
          onChanged: (v) => setState(() => _idParentesco = v), decoration: const InputDecoration(labelText: "Parentesco con el Paciente *", border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextFormField(controller: _emailTutorCtrl, decoration: const InputDecoration(labelText: "Correo Electrónico", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16)))),
          const SizedBox(width: 16),
          Expanded(child: TextFormField(controller: _telTutorCtrl, decoration: const InputDecoration(labelText: "Teléfono / Móvil", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16)))),
        ]),
        const SizedBox(height: 16),
        TextFormField(controller: _dirTutorCtrl, decoration: const InputDecoration(labelText: "Dirección de Domicilio del Representante", border: OutlineInputBorder(), prefixIcon: Icon(Icons.home_work), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: EdgeInsets.fromLTRB(16, 20, 16, 16))),
      ],
    ));
  }

  Widget _card({required String title, required IconData icon, required Color color, required Widget child}) {
    return Card(
      elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(padding: const EdgeInsets.all(32), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 16), Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14, letterSpacing: 0.5))]),
        const SizedBox(height: 32),
        child,
      ])),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool enabled = true}) {
    return TextFormField(
      controller: ctrl, enabled: enabled,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon), floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16)),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      readOnly: true,
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _fnac ?? DateTime.now().subtract(const Duration(days: 3650)), firstDate: DateTime(1900), lastDate: DateTime.now());
        if (d != null) {
          setState(() => _fnac = d);
        }
      },
      decoration: InputDecoration(
        labelText: "F. Nacimiento *", border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.cake),
        floatingLabelBehavior: FloatingLabelBehavior.always, contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        hintText: _fnac == null ? "Seleccione..." : _fnac!.toIso8601String().split("T").first,
      ),
    );
  }
}
