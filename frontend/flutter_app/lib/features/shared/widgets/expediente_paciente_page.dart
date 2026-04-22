import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/state/app_providers.dart";
import "../../../shared/models/app_role.dart";

class ExpedientePacientePage extends ConsumerStatefulWidget {
  final String idPaciente;
  final String nombrePaciente;
  final VoidCallback onBack;

  const ExpedientePacientePage({super.key, required this.idPaciente, required this.nombrePaciente, required this.onBack});

  @override
  ConsumerState<ExpedientePacientePage> createState() => _ExpedientePacientePageState();
}

class _ExpedientePacientePageState extends ConsumerState<ExpedientePacientePage> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  
  // Variables de Seguimiento
  final _pesoCtrl = TextEditingController();
  final _tallaCtrl = TextEditingController();
  final _pcrCtrl = TextEditingController();
  final _rigidezCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  int _dolorEva = 0;
  int _inflamacionArt = 0;
  int _fatiga = 0;
  bool _brote = false;
  
  // Bloqueo de campos si ya existen
  bool _pesoYaRegistrado = false;
  bool _tallaYaRegistrada = false;

  // Catálogos
  List<dynamic> _allIngredientes = [];
  List<dynamic> _allGrupos = [];
  List<dynamic> _allCondicionesMedicas = [];
  List<int> _selectedIngredientes = [];
  List<int> _selectedGrupos = [];
  List<int> _selectedClinicas = [];
  Map<int, DateTime> _selectedTemporales = {};

  @override
  void initState() {
    super.initState();
    _loadExpediente();
  }

  Future<void> _loadExpediente() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get("gestion-pacientes/${widget.idPaciente}/expediente");
      final resIng = await dio.get("ingredientes-lista", queryParameters: {"limit": 1000});
      final resGrp = await dio.get("gestion-pacientes/catalogo-grupos");
      final resCond = await dio.get("condiciones-medicas");

      setState(() {
        _data = res.data;
        _allIngredientes = resIng.data['items'] ?? [];
        _allGrupos = resGrp.data ?? [];
        _allCondicionesMedicas = resCond.data ?? [];
        
        _selectedIngredientes = ((_data?['alergias_ingredientes'] ?? []) as List).map((e) => (e['id'] ?? 0) as int).toList();
        _selectedGrupos = ((_data?['alergias_grupos'] ?? []) as List).map((e) => (e['id'] ?? 0) as int).toList();
        _selectedClinicas = ((_data?['condiciones_clinicas'] ?? []) as List).map((e) => (e['id'] ?? 0) as int).toList();
        
        _selectedTemporales = {};
        for (var t in ((_data?['condiciones_temporales'] ?? []) as List)) {
          if (t['id'] != null && t['fin'] != null) {
            _selectedTemporales[t['id']] = DateTime.parse(t['fin']);
          }
        }
        
        // Verificar registro de hoy
        if ((_data?['historial'] as List?)?.isNotEmpty == true) {
          final last = _data!['historial'][0];
          final String hoyStr = DateTime.now().toIso8601String().split('T')[0];
          if (last['fecha'] == hoyStr) {
            if ((last['peso'] ?? 0) > 0) {
              _pesoCtrl.text = last['peso'].toString();
              _pesoYaRegistrado = true;
            }
            if ((last['talla'] ?? 0) > 0) {
              _tallaCtrl.text = last['talla'].toString();
              _tallaYaRegistrada = true;
            }
          }
        }

        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guardar() async {
    final rol = ref.read(appRoleProvider).valueOrNull ?? AppRole.nutricionista;
    final bool isNutri = rol == AppRole.nutricionista;

    try {
      final dio = ref.read(dioProvider);
      
      Map<String, dynamic> payloadControl = {
        "id_paciente": widget.idPaciente,
        "peso_kg": double.tryParse(_pesoCtrl.text),
        "talla_cm": double.tryParse(_tallaCtrl.text),
      };

      if (!isNutri) {
        payloadControl.addAll({
          "nivel_dolor_eva": _dolorEva,
          "nivel_inflamacion": _inflamacionArt,
          "nivel_fatiga": _fatiga,
          "minutos_rigidez_matutina": int.tryParse(_rigidezCtrl.text),
          "inflamacion_pcr": double.tryParse(_pcrCtrl.text),
          "hay_brote_activo": _brote,
          "nota_evolucion": _notaCtrl.text,
          "id_condiciones_activas": [..._selectedClinicas, ..._selectedTemporales.keys]
        });
      }

      await dio.post("gestion-pacientes/control", data: payloadControl);

      if (!isNutri) {
        await dio.post("gestion-pacientes/${widget.idPaciente}/alergias", data: {
          "ingredientes": _selectedIngredientes,
          "grupos": _selectedGrupos,
          "temporales": _selectedTemporales.entries.map((e) => {
            "id": e.key, "fecha_fin": e.value.toIso8601String().split('T')[0]
          }).toList()
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Información sincronizada"), backgroundColor: Colors.green));
        _loadExpediente();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Error al guardar")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) return const Center(child: CircularProgressIndicator());

    final info = _data?['info'] ?? {};
    final rol = ref.watch(appRoleProvider).valueOrNull ?? AppRole.nutricionista;
    final bool isNutri = rol == AppRole.nutricionista;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
          child: Row(
            children: [
              IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, color: Colors.blueGrey)),
              const SizedBox(width: 8),
              Text("EXPEDIENTE: ${info['nombre'] ?? 'S/N'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _guardar, 
                icon: const Icon(Icons.save_rounded, size: 18), 
                label: Text(isNutri ? "GUARDAR PESO/TALLA" : "GUARDAR CONSULTA"),
                style: FilledButton.styleFrom(backgroundColor: isNutri ? Colors.blue : Colors.green.shade700),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 260,
                decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.grey.shade200))),
                child: SingleChildScrollView(child: _buildFichaEstatica(info)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildSeccionAntropometria(),
                      const SizedBox(height: 24),
                      if (!isNutri) _buildSeccionClinica(),
                      if (isNutri) _buildAvisoNutri(),
                      const SizedBox(height: 24),
                      _buildTimelineEvolucion(),
                    ],
                  ),
                ),
              ),
              Container(
                width: 300,
                decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: Colors.grey.shade200))),
                child: SingleChildScrollView(child: _buildSeccionRestricciones(isNutri)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFichaEstatica(Map<String, dynamic> info) {
    final String fnac = (info['fnac'] ?? "").toString();
    final String nombre = (info['nombre'] ?? "Sin nombre").toString();
    final String enfermedad = (info['enfermedad'] ?? "Sin diagnóstico").toString();
    final String sexo = (info['sexo'] ?? "N/A").toString();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40))),
          const SizedBox(height: 20),
          _datoFijo("Identidad", nombre),
          _datoFijo("Diagnóstico Base", enfermedad, isHighlight: true),
          _datoFijo("Edad", fnac.isEmpty ? "-" : "${_calcularEdad(fnac)} años"),
          _datoFijo("Sexo", sexo),
          const Divider(height: 40),
          const Text("ESTADO NUTRICIONAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text((info['estado_oms'] ?? "Pendiente").toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildSeccionAntropometria() {
    return Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("MEDICIONES ANTROPOMÉTRICAS", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(
                  controller: _pesoCtrl, 
                  enabled: !_pesoYaRegistrado,
                  decoration: InputDecoration(labelText: "Peso (kg)", border: const OutlineInputBorder(), filled: _pesoYaRegistrado), 
                  keyboardType: TextInputType.number
                )),
                const SizedBox(width: 16),
                Expanded(child: TextField(
                  controller: _tallaCtrl, 
                  enabled: !_tallaYaRegistrada,
                  decoration: InputDecoration(labelText: "Talla (cm)", border: const OutlineInputBorder(), filled: _tallaYaRegistrada), 
                  keyboardType: TextInputType.number
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionClinica() {
    return Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("DIAGNÓSTICO MÉDICO DEL DÍA", style: TextStyle(fontWeight: FontWeight.bold)),
            _sliderControl("Dolor (EVA)", _dolorEva, (v) => setState(() => _dolorEva = v.toInt()), Colors.orange),
            _sliderControl("Inflamación", _inflamacionArt, (v) => setState(() => _inflamacionArt = v.toInt()), Colors.redAccent),
            _sliderControl("Fatiga", _fatiga, (v) => setState(() => _fatiga = v.toInt()), Colors.blueGrey),
            Row(
              children: [
                Expanded(child: TextField(controller: _pcrCtrl, decoration: const InputDecoration(labelText: "PCR"), keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _rigidezCtrl, decoration: const InputDecoration(labelText: "Rigidez (min)"), keyboardType: TextInputType.number)),
              ],
            ),
            SwitchListTile(title: const Text("¿Brote Activo?"), value: _brote, onChanged: (v) => setState(() => _brote = v)),
            const Divider(),
            _buildListaCondiciones("Clínicas Permanentes", 1, Colors.blue),
            const SizedBox(height: 8),
            _buildListaTemporales(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvisoNutri() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(child: Text("Como Nutricionista, puede visualizar el historial y restricciones, pero solo actualizar medidas de peso/talla.", style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildSeccionRestricciones(bool isReadOnly) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("RESTRICCIONES", style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          const SizedBox(height: 8),
          const Text("Ingredientes", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          Container(
            height: 250,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
            child: ListView.builder(
              itemCount: _allIngredientes.length,
              itemBuilder: (ctx, i) {
                final ing = _allIngredientes[i];
                final int id = (ing['id'] ?? 0) as int;
                return CheckboxListTile(
                  title: Text((ing['nombre'] ?? 'Item').toString(), style: const TextStyle(fontSize: 10)),
                  value: _selectedIngredientes.contains(id),
                  onChanged: isReadOnly ? null : (v) => setState(() { if (v!) _selectedIngredientes.add(id); else _selectedIngredientes.remove(id); }),
                  dense: true,
                );
              },
            ),
          ),
          const Text("Grupos Prohibidos", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          ..._allGrupos.map((g) {
            final int id = (g['id'] ?? 0) as int;
            return CheckboxListTile(
              title: Text((g['nombre'] ?? 'Grupo').toString(), style: const TextStyle(fontSize: 10)),
              value: _selectedGrupos.contains(id),
              onChanged: isReadOnly ? null : (v) => setState(() { if (v!) _selectedGrupos.add(id); else _selectedGrupos.remove(id); }),
              dense: true,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineEvolucion() {
    final hist = (_data?['historial'] ?? []) as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("HISTORIAL", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (hist.isEmpty) const Text("Sin registros previos", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ...hist.map((h) {
          final String fecha = (h['fecha'] ?? "N/A").toString();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.history, size: 20),
              title: Text("$fecha | ${h['peso'] ?? 0}kg - ${h['talla'] ?? 0}cm", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text("Estado: ${h['estado'] ?? 'N/A'} | Dolor: ${h['dolor'] ?? 0} | Inflamación: ${h['inflamacion'] ?? 0} | Fatiga: ${h['fatiga'] ?? 0}", style: const TextStyle(fontSize: 11)),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildListaCondiciones(String title, int typeId, Color color) {
    final list = _allCondicionesMedicas.where((c) => c['id_tipo_condicion'] == typeId).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ...list.map((c) {
          final int id = (c['id'] ?? 0) as int;
          return CheckboxListTile(
            title: Text((c['nombre'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
            value: _selectedClinicas.contains(id),
            onChanged: (v) => setState(() { if (v!) _selectedClinicas.add(id); else _selectedClinicas.remove(id); }),
            dense: true,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildListaTemporales() {
    final list = _allCondicionesMedicas.where((c) => c['id_tipo_condicion'] == 2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Temporales", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
        ...list.map((c) {
          final int id = (c['id'] ?? 0) as int;
          bool isSelected = _selectedTemporales.containsKey(id);
          return CheckboxListTile(
            title: Text((c['nombre'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
            subtitle: isSelected ? Text("Vence: ${_selectedTemporales[id]!.toLocal().toString().split(' ')[0]}", style: const TextStyle(fontSize: 9, color: Colors.orange)) : null,
            value: isSelected,
            onChanged: (v) async {
              if (v!) {
                final date = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
                if (date != null) setState(() => _selectedTemporales[id] = date);
              } else { setState(() => _selectedTemporales.remove(id)); }
            },
            dense: true,
          );
        }).toList(),
      ],
    );
  }

  Widget _sliderControl(String label, int value, Function(double) onChanged, Color color) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 11))),
        Expanded(child: Slider(value: value.toDouble(), min: 0, max: 10, divisions: 10, activeColor: color, onChanged: onChanged)),
        Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _datoFijo(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  int _calcularEdad(String fnac) {
    if (fnac.isEmpty) return 0;
    try {
      final birth = DateTime.parse(fnac);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
      return age;
    } catch (_) { return 0; }
  }
}
