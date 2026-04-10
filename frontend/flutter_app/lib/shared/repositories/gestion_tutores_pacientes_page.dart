import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:reuma_nutri_app/core/state/app_providers.dart";

class GestionTutoresPacientesPage extends ConsumerStatefulWidget {
  const GestionTutoresPacientesPage({super.key});

  @override
  ConsumerState<GestionTutoresPacientesPage> createState() => _GestionTutoresPacientesPageState();
}

class _GestionTutoresPacientesPageState extends ConsumerState<GestionTutoresPacientesPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tutores y Pacientes",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person_add_alt_1), text: "Tutor"),
              Tab(icon: Icon(Icons.child_care), text: "Paciente"),
              Tab(icon: Icon(Icons.link), text: "Vincular"),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _FormRegistroTutor(),
                _FormRegistroPaciente(),
                _FormVincularTutorPaciente(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormRegistroTutor extends ConsumerStatefulWidget {
  const _FormRegistroTutor();

  @override
  ConsumerState<_FormRegistroTutor> createState() => _FormRegistroTutorState();
}

class _FormRegistroTutorState extends ConsumerState<_FormRegistroTutor> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _registrarTutor() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || name.isEmpty) {
      setState(() => _error = "El email y el nombre son obligatorios");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);

      await repo.registerTutorOnly(
        email: email,
        nombreCompleto: name,
      );

      if (!mounted) return;

      setState(() {
        _resultado = "Tutor registrado correctamente. Ahora puedes vincularlo con uno o varios pacientes.";
        _emailController.clear();
        _nameController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        _text(_emailController, "Correo electrónico del tutor", email: true),
        const SizedBox(height: 12),
        _text(_nameController, "Nombre completo"),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _registrarTutor,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text("Registrar Tutor"),
        ),
        if (_resultado != null) ...[
          const SizedBox(height: 12),
          Text(_resultado!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  Widget _text(TextEditingController controller, String label, {bool number = false, bool email = false}) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : (email ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _FormRegistroPaciente extends ConsumerStatefulWidget {
  const _FormRegistroPaciente();

  @override
  ConsumerState<_FormRegistroPaciente> createState() => _FormRegistroPacienteState();
}

class _FormRegistroPacienteState extends ConsumerState<_FormRegistroPaciente> {
  final _nameController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();
  final _pesoController = TextEditingController();
  final _tallaController = TextEditingController();
  final _edadMesesController = TextEditingController();
  final _pcrController = TextEditingController();
  final _diagnosticoOmsController = TextEditingController();
  final _notaEvolucionController = TextEditingController();
  final _rigidezMinController = TextEditingController();

  int? _selectedSexo;
  int? _selectedProvincia;
  int? _selectedCondicionNutricional;
  int? _selectedDolorEva;
  int? _selectedInflamacion;
  int? _selectedFatiga;
  bool? _hayBroteActivo;

  int _seccionActiva = 0;

  List<Map<String, dynamic>> _sexos = [];
  List<Map<String, dynamic>> _provincias = [];
  List<Map<String, dynamic>> _condiciones = [];
  List<int> _condicionesActivas = [];

  DateTime? _fechaNacimiento;

  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCatalogs);
  }

  Future<void> _loadCatalogs() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final sexos = await repo.fetchCatalog("usuarios", "catalogo_sexo");
      final provincias = await repo.fetchCatalog("usuarios", "provincia");
      final condiciones = await repo.fetchCatalog("heuristico", "condicion");
      if (mounted) {
        setState(() {
          _sexos = sexos;
          _provincias = provincias;
          _condiciones = condiciones;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = "No fue posible cargar catalogos clínicos: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fechaNacimientoController.dispose();
    _pesoController.dispose();
    _tallaController.dispose();
    _edadMesesController.dispose();
    _pcrController.dispose();
    _diagnosticoOmsController.dispose();
    _notaEvolucionController.dispose();
    _rigidezMinController.dispose();
    super.dispose();
  }

  int _calculateAgeInMonths(DateTime birthDate, DateTime referenceDate) {
    var months = (referenceDate.year - birthDate.year) * 12 + (referenceDate.month - birthDate.month);
    if (referenceDate.day < birthDate.day) {
      months -= 1;
    }
    return months < 0 ? 0 : months;
  }

  double? _parseDouble(String raw) {
    final value = raw.trim().replaceAll(",", ".");
    if (value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  int? _parseInt(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  double? _calculateImc(double pesoKg, double tallaCm) {
    final tallaM = tallaCm / 100;
    if (tallaM <= 0) {
      return null;
    }
    return pesoKg / (tallaM * tallaM);
  }

  String _condicionLabel(Map<String, dynamic> condicion) {
    final nombre = condicion["nombre"]?.toString().trim();
    if (nombre != null && nombre.isNotEmpty) {
      return nombre;
    }
    final descripcion = condicion["descripcion"]?.toString().trim();
    if (descripcion != null && descripcion.isNotEmpty) {
      return descripcion;
    }
    final codigo = condicion["codigo"]?.toString().trim();
    if (codigo != null && codigo.isNotEmpty) {
      return codigo;
    }
    return "Condición";
  }

  Map<String, dynamic> _buildControlClinicoPayload({
    required double pesoKg,
    required double tallaCm,
  }) {
    final edadIngresada = _parseInt(_edadMesesController.text);
    final edadMeses = edadIngresada ?? (_fechaNacimiento == null ? null : _calculateAgeInMonths(_fechaNacimiento!, DateTime.now()));

    return {
      "peso_kg": pesoKg,
      "talla_cm": tallaCm,
      "edad_meses": edadMeses,
      "nivel_dolor_eva": _selectedDolorEva,
      "nivel_inflamacion": _selectedInflamacion,
      "nivel_fatiga": _selectedFatiga,
      "minutos_rigidez_matutina": _parseInt(_rigidezMinController.text),
      "inflamacion_pcr": _parseDouble(_pcrController.text),
      "hay_brote_activo": _hayBroteActivo,
      "id_condicion_nutricional_resultado": _selectedCondicionNutricional,
      "diagnostico_oms_texto": _diagnosticoOmsController.text.trim().isEmpty
          ? null
          : _diagnosticoOmsController.text.trim(),
      "nota_evolucion": _notaEvolucionController.text.trim().isEmpty
          ? null
          : _notaEvolucionController.text.trim(),
      "imc_calculado": _calculateImc(pesoKg, tallaCm),
      "id_condiciones_activas": _condicionesActivas,
    };
  }

  void _resetForm() {
    _nameController.clear();
    _fechaNacimientoController.clear();
    _pesoController.clear();
    _tallaController.clear();
    _edadMesesController.clear();
    _pcrController.clear();
    _diagnosticoOmsController.clear();
    _notaEvolucionController.clear();
    _rigidezMinController.clear();

    _fechaNacimiento = null;
    _selectedSexo = null;
    _selectedProvincia = null;
    _selectedCondicionNutricional = null;
    _selectedDolorEva = null;
    _selectedInflamacion = null;
    _selectedFatiga = null;
    _hayBroteActivo = null;
    _condicionesActivas = [];
    _seccionActiva = 0;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _fechaNacimiento = date;
        _fechaNacimientoController.text = date.toIso8601String().split("T").first;
      });
    }
  }

  Future<void> _registrarPaciente() async {
    final name = _nameController.text.trim();
    final peso = _parseDouble(_pesoController.text);
    final talla = _parseDouble(_tallaController.text);

    if (name.isEmpty || _fechaNacimiento == null || _selectedSexo == null || peso == null || talla == null) {
      setState(() => _error = "Completa nombre, fecha de nacimiento, sexo, peso y talla para registrar al paciente.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final controlClinico = _buildControlClinicoPayload(
        pesoKg: peso,
        tallaCm: talla,
      );

      await repo.registerPatientOnly(
        nombreCompleto: name,
        fechaNacimiento: _fechaNacimiento!,
        idSexo: _selectedSexo!,
        idProvincia: _selectedProvincia,
        controlClinicoInicial: controlClinico,
      );

      if (!mounted) return;

      setState(() {
        _resultado = "Paciente registrado correctamente. Ahora debes vincularlo a un tutor en la pestaña Vincular.";
        _resetForm();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        Text(
          "Registro clínico inicial",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          "Completa los datos en secciones para registrar al paciente junto a su estado clínico base.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text("1. Datos personales"),
              selected: _seccionActiva == 0,
              onSelected: (_) => setState(() => _seccionActiva = 0),
            ),
            ChoiceChip(
              label: const Text("2. Antropometría"),
              selected: _seccionActiva == 1,
              onSelected: (_) => setState(() => _seccionActiva = 1),
            ),
            ChoiceChip(
              label: const Text("3. Estado clínico"),
              selected: _seccionActiva == 2,
              onSelected: (_) => setState(() => _seccionActiva = 2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildSectionCard(),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _registrarPaciente,
          icon: const Icon(Icons.child_care),
          label: const Text("Registrar Paciente con Datos Clínicos"),
        ),
        if (_resultado != null) ...[
          const SizedBox(height: 12),
          Text(_resultado!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  Widget _buildSectionCard() {
    if (_seccionActiva == 0) {
      return Card(
        key: const ValueKey("datos_personales"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Datos personales", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              _text(_nameController, "Nombre completo del paciente"),
              const SizedBox(height: 12),
              TextField(
                controller: _fechaNacimientoController,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: "Fecha de nacimiento",
                  prefixIcon: Icon(Icons.calendar_month),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedSexo,
                decoration: const InputDecoration(labelText: "Sexo"),
                items: _sexos
                    .map(
                      (s) => DropdownMenuItem<int>(
                        value: s["id"] as int,
                        child: Text(s["descripcion"]?.toString() ?? s["codigo"]?.toString() ?? ""),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedSexo = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedProvincia,
                decoration: const InputDecoration(labelText: "Provincia (Opcional)"),
                items: _provincias
                    .map(
                      (p) => DropdownMenuItem<int>(
                        value: p["id"] as int,
                        child: Text(p["nombre"]?.toString() ?? ""),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedProvincia = val),
              ),
            ],
          ),
        ),
      );
    }

    if (_seccionActiva == 1) {
      return Card(
        key: const ValueKey("antropometria"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Antropometría", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              _text(_pesoController, "Peso (kg)", number: true),
              const SizedBox(height: 12),
              _text(_tallaController, "Talla (cm)", number: true),
              const SizedBox(height: 12),
              _text(_edadMesesController, "Edad en meses (Opcional, se calcula automáticamente)", number: true),
            ],
          ),
        ),
      );
    }

    return Card(
      key: const ValueKey("estado_clinico"),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Estado clínico inicial", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedCondicionNutricional,
              decoration: const InputDecoration(labelText: "Condición nutricional resultante (Opcional)"),
              items: _condiciones
                  .map(
                    (c) => DropdownMenuItem<int>(
                      value: (c["id"] as num).toInt(),
                      child: Text(_condicionLabel(c)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCondicionNutricional = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedDolorEva,
              decoration: const InputDecoration(labelText: "Nivel de dolor EVA (0-10)"),
              items: List.generate(
                11,
                (idx) => DropdownMenuItem<int>(
                  value: idx,
                  child: Text(idx.toString()),
                ),
              ),
              onChanged: (value) => setState(() => _selectedDolorEva = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedInflamacion,
              decoration: const InputDecoration(labelText: "Nivel de inflamación (0-10)"),
              items: List.generate(
                11,
                (idx) => DropdownMenuItem<int>(
                  value: idx,
                  child: Text(idx.toString()),
                ),
              ),
              onChanged: (value) => setState(() => _selectedInflamacion = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedFatiga,
              decoration: const InputDecoration(labelText: "Nivel de fatiga (0-10)"),
              items: List.generate(
                11,
                (idx) => DropdownMenuItem<int>(
                  value: idx,
                  child: Text(idx.toString()),
                ),
              ),
              onChanged: (value) => setState(() => _selectedFatiga = value),
            ),
            const SizedBox(height: 12),
            _text(_rigidezMinController, "Minutos de rigidez matutina", number: true),
            const SizedBox(height: 12),
            _text(_pcrController, "Inflamación PCR", number: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool>(
              initialValue: _hayBroteActivo,
              decoration: const InputDecoration(labelText: "¿Hay brote activo?"),
              items: const [
                DropdownMenuItem<bool>(value: true, child: Text("Sí")),
                DropdownMenuItem<bool>(value: false, child: Text("No")),
              ],
              onChanged: (value) => setState(() => _hayBroteActivo = value),
            ),
            const SizedBox(height: 12),
            _text(_diagnosticoOmsController, "Diagnóstico OMS (texto, opcional)"),
            const SizedBox(height: 12),
            TextField(
              controller: _notaEvolucionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Nota de evolución",
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Condiciones activas asociadas al control",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _condiciones
                  .map(
                    (condicion) {
                      final idCondicion = (condicion["id"] as num).toInt();
                      return FilterChip(
                        selected: _condicionesActivas.contains(idCondicion),
                        label: Text(_condicionLabel(condicion)),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _condicionesActivas = [..._condicionesActivas, idCondicion];
                            } else {
                              _condicionesActivas = _condicionesActivas.where((id) => id != idCondicion).toList();
                            }
                          });
                        },
                      );
                    },
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(TextEditingController controller, String label, {bool number = false}) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class FormEditarControlClinicoPaciente extends ConsumerStatefulWidget {
  const FormEditarControlClinicoPaciente({super.key});

  @override
  ConsumerState<FormEditarControlClinicoPaciente> createState() => _FormEditarControlClinicoPacienteState();
}

class _FormEditarControlClinicoPacienteState extends ConsumerState<FormEditarControlClinicoPaciente> {
  final _pacienteSearchController = TextEditingController();
  final _pesoController = TextEditingController();
  final _tallaController = TextEditingController();
  final _edadMesesController = TextEditingController();
  final _pcrController = TextEditingController();
  final _diagnosticoOmsController = TextEditingController();
  final _notaEvolucionController = TextEditingController();
  final _rigidezMinController = TextEditingController();

  List<Map<String, dynamic>> _pacientesEncontrados = [];
  List<Map<String, dynamic>> _condiciones = [];
  List<int> _condicionesActivas = [];

  String? _selectedPacienteId;
  int? _selectedCondicionNutricional;
  int? _selectedDolorEva;
  int? _selectedInflamacion;
  int? _selectedFatiga;
  bool? _hayBroteActivo;

  int _seccionActiva = 0;
  bool _loading = false;
  bool _loadingControl = false;
  String? _resultado;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCatalogs);
  }

  @override
  void dispose() {
    _pacienteSearchController.dispose();
    _pesoController.dispose();
    _tallaController.dispose();
    _edadMesesController.dispose();
    _pcrController.dispose();
    _diagnosticoOmsController.dispose();
    _notaEvolucionController.dispose();
    _rigidezMinController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final condiciones = await repo.fetchCatalog("heuristico", "condicion");
      if (!mounted) {
        return;
      }
      setState(() => _condiciones = condiciones);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = "No fue posible cargar las condiciones clínicas: $error");
    }
  }

  Future<void> _buscarPacientes() async {
    final query = _pacienteSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _pacientesEncontrados = [];
        _selectedPacienteId = null;
      });
      return;
    }

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final rows = await repo.searchPatients(query: query, limit: 10);
      if (!mounted) {
        return;
      }
      setState(() {
        _pacientesEncontrados = rows;
        _selectedPacienteId = rows.isEmpty ? null : rows.first["id"]?.toString();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  double? _parseDouble(String raw) {
    final value = raw.trim().replaceAll(",", ".");
    if (value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  int? _parseInt(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  double? _calculateImc(double pesoKg, double tallaCm) {
    final tallaM = tallaCm / 100;
    if (tallaM <= 0) {
      return null;
    }
    return pesoKg / (tallaM * tallaM);
  }

  String _condicionLabel(Map<String, dynamic> condicion) {
    final nombre = condicion["nombre"]?.toString().trim();
    if (nombre != null && nombre.isNotEmpty) {
      return nombre;
    }
    final descripcion = condicion["descripcion"]?.toString().trim();
    if (descripcion != null && descripcion.isNotEmpty) {
      return descripcion;
    }
    final codigo = condicion["codigo"]?.toString().trim();
    if (codigo != null && codigo.isNotEmpty) {
      return codigo;
    }
    return "Condición";
  }

  void _populateControlForm(Map<String, dynamic> control) {
    _pesoController.text = (control["peso_kg"] ?? "").toString();
    _tallaController.text = (control["talla_cm"] ?? "").toString();
    _edadMesesController.text = (control["edad_meses"] ?? "").toString();
    _pcrController.text = control["inflamacion_pcr"] == null ? "" : control["inflamacion_pcr"].toString();
    _diagnosticoOmsController.text = control["diagnostico_oms_texto"]?.toString() ?? "";
    _notaEvolucionController.text = control["nota_evolucion"]?.toString() ?? "";
    _rigidezMinController.text = control["minutos_rigidez_matutina"] == null
        ? ""
        : control["minutos_rigidez_matutina"].toString();

    _selectedCondicionNutricional = control["id_condicion_nutricional_resultado"] == null
        ? null
        : (control["id_condicion_nutricional_resultado"] as num).toInt();
    _selectedDolorEva = control["nivel_dolor_eva"] == null ? null : (control["nivel_dolor_eva"] as num).toInt();
    _selectedInflamacion = control["nivel_inflamacion"] == null ? null : (control["nivel_inflamacion"] as num).toInt();
    _selectedFatiga = control["nivel_fatiga"] == null ? null : (control["nivel_fatiga"] as num).toInt();
    _hayBroteActivo = control["hay_brote_activo"] as bool?;

    final condiciones = control["id_condiciones_activas"];
    if (condiciones is List) {
      _condicionesActivas = condiciones.whereType<num>().map((it) => it.toInt()).toSet().toList();
    } else {
      _condicionesActivas = [];
    }
  }

  Future<void> _cargarControlActual() async {
    final idPaciente = _selectedPacienteId;
    if (idPaciente == null || idPaciente.isEmpty) {
      setState(() => _error = "Selecciona un paciente para cargar su ficha clínica.");
      return;
    }

    setState(() {
      _loadingControl = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final control = await repo.fetchCurrentClinicalControl(idPaciente: idPaciente);
      if (!mounted) {
        return;
      }
      setState(() {
        _populateControlForm(control);
        _resultado = "Ficha clínica cargada correctamente.";
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resultado = "El paciente no tiene control previo. Completa la ficha y guarda para crearlo.";
        _error = null;
        _pesoController.clear();
        _tallaController.clear();
        _edadMesesController.clear();
        _pcrController.clear();
        _diagnosticoOmsController.clear();
        _notaEvolucionController.clear();
        _rigidezMinController.clear();
        _selectedCondicionNutricional = null;
        _selectedDolorEva = null;
        _selectedInflamacion = null;
        _selectedFatiga = null;
        _hayBroteActivo = null;
        _condicionesActivas = [];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingControl = false);
      }
    }
  }

  Map<String, dynamic> _buildControlClinicoPayload({
    required double pesoKg,
    required double tallaCm,
  }) {
    return {
      "peso_kg": pesoKg,
      "talla_cm": tallaCm,
      "edad_meses": _parseInt(_edadMesesController.text),
      "nivel_dolor_eva": _selectedDolorEva,
      "nivel_inflamacion": _selectedInflamacion,
      "nivel_fatiga": _selectedFatiga,
      "minutos_rigidez_matutina": _parseInt(_rigidezMinController.text),
      "inflamacion_pcr": _parseDouble(_pcrController.text),
      "hay_brote_activo": _hayBroteActivo,
      "id_condicion_nutricional_resultado": _selectedCondicionNutricional,
      "diagnostico_oms_texto": _diagnosticoOmsController.text.trim().isEmpty
          ? null
          : _diagnosticoOmsController.text.trim(),
      "nota_evolucion": _notaEvolucionController.text.trim().isEmpty
          ? null
          : _notaEvolucionController.text.trim(),
      "imc_calculado": _calculateImc(pesoKg, tallaCm),
      "id_condiciones_activas": _condicionesActivas,
    };
  }

  Future<void> _guardarControlActual() async {
    final idPaciente = _selectedPacienteId;
    if (idPaciente == null || idPaciente.isEmpty) {
      setState(() => _error = "Selecciona un paciente antes de guardar la ficha clínica.");
      return;
    }

    final peso = _parseDouble(_pesoController.text);
    final talla = _parseDouble(_tallaController.text);
    if (peso == null || talla == null) {
      setState(() => _error = "Peso y talla son obligatorios para guardar el control clínico.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final payload = _buildControlClinicoPayload(
        pesoKg: peso,
        tallaCm: talla,
      );
      await repo.updateCurrentClinicalControl(
        idPaciente: idPaciente,
        controlClinico: payload,
      );
      if (!mounted) {
        return;
      }
      setState(() => _resultado = "Ficha clínica actualizada correctamente.");
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildSectionCard() {
    if (_seccionActiva == 0) {
      return Card(
        key: const ValueKey("editar_antropometria"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Antropometría", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              TextField(
                controller: _pesoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Peso (kg)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tallaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Talla (cm)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _edadMesesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Edad en meses (Opcional)"),
              ),
            ],
          ),
        ),
      );
    }

    if (_seccionActiva == 1) {
      return Card(
        key: const ValueKey("editar_estado_clinico"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Estado clínico", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedCondicionNutricional,
                decoration: const InputDecoration(labelText: "Condición nutricional resultante (Opcional)"),
                items: _condiciones
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: (c["id"] as num).toInt(),
                        child: Text(_condicionLabel(c)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedCondicionNutricional = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedDolorEva,
                decoration: const InputDecoration(labelText: "Nivel de dolor EVA (0-10)"),
                items: List.generate(
                  11,
                  (idx) => DropdownMenuItem<int>(value: idx, child: Text(idx.toString())),
                ),
                onChanged: (value) => setState(() => _selectedDolorEva = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedInflamacion,
                decoration: const InputDecoration(labelText: "Nivel de inflamación (0-10)"),
                items: List.generate(
                  11,
                  (idx) => DropdownMenuItem<int>(value: idx, child: Text(idx.toString())),
                ),
                onChanged: (value) => setState(() => _selectedInflamacion = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedFatiga,
                decoration: const InputDecoration(labelText: "Nivel de fatiga (0-10)"),
                items: List.generate(
                  11,
                  (idx) => DropdownMenuItem<int>(value: idx, child: Text(idx.toString())),
                ),
                onChanged: (value) => setState(() => _selectedFatiga = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rigidezMinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Minutos de rigidez matutina"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pcrController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Inflamación PCR"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<bool>(
                initialValue: _hayBroteActivo,
                decoration: const InputDecoration(labelText: "¿Hay brote activo?"),
                items: const [
                  DropdownMenuItem<bool>(value: true, child: Text("Sí")),
                  DropdownMenuItem<bool>(value: false, child: Text("No")),
                ],
                onChanged: (value) => setState(() => _hayBroteActivo = value),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      key: const ValueKey("editar_diagnostico"),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Diagnóstico y condiciones", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosticoOmsController,
              decoration: const InputDecoration(labelText: "Diagnóstico OMS (texto, opcional)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notaEvolucionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "Nota de evolución"),
            ),
            const SizedBox(height: 12),
            Text(
              "Condiciones activas asociadas",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _condiciones
                  .map(
                    (condicion) {
                      final idCondicion = (condicion["id"] as num).toInt();
                      return FilterChip(
                        selected: _condicionesActivas.contains(idCondicion),
                        label: Text(_condicionLabel(condicion)),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _condicionesActivas = [..._condicionesActivas, idCondicion];
                            } else {
                              _condicionesActivas = _condicionesActivas.where((id) => id != idCondicion).toList();
                            }
                          });
                        },
                      );
                    },
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        Text(
          "Editar ficha clínica del paciente",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pacienteSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscarPacientes(),
                decoration: const InputDecoration(
                  labelText: "Buscar paciente por nombre",
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _buscarPacientes,
              child: const Text("Buscar"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedPacienteId,
          decoration: const InputDecoration(labelText: "Seleccionar paciente"),
          items: _pacientesEncontrados
              .map(
                (p) => DropdownMenuItem<String>(
                  value: p["id"]?.toString(),
                  child: Text("${p["nombre_completo"] ?? ""} - ID: ${p["id"] ?? "N/A"}"),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedPacienteId = value),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _loadingControl ? null : _cargarControlActual,
          icon: const Icon(Icons.download),
          label: Text(_loadingControl ? "Cargando..." : "Cargar Ficha Clínica Actual"),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text("1. Antropometría"),
              selected: _seccionActiva == 0,
              onSelected: (_) => setState(() => _seccionActiva = 0),
            ),
            ChoiceChip(
              label: const Text("2. Estado clínico"),
              selected: _seccionActiva == 1,
              onSelected: (_) => setState(() => _seccionActiva = 1),
            ),
            ChoiceChip(
              label: const Text("3. Diagnóstico"),
              selected: _seccionActiva == 2,
              onSelected: (_) => setState(() => _seccionActiva = 2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildSectionCard(),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _guardarControlActual,
          icon: const Icon(Icons.save),
          label: const Text("Guardar Ficha Clínica"),
        ),
        if (_resultado != null) ...[
          const SizedBox(height: 12),
          Text(
            _resultado!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _FormVincularTutorPaciente extends ConsumerStatefulWidget {
  const _FormVincularTutorPaciente();

  @override
  ConsumerState<_FormVincularTutorPaciente> createState() => _FormVincularTutorPacienteState();
}

class _FormVincularTutorPacienteState extends ConsumerState<_FormVincularTutorPaciente> {
  final _tutorSearchController = TextEditingController();
  final _pacienteSearchController = TextEditingController();

  List<Map<String, dynamic>> _tutoresEncontrados = [];
  List<Map<String, dynamic>> _pacientesEncontrados = [];

  String? _selectedTutorId;
  String? _selectedPacienteId;
  int? _selectedParentesco;
  bool _esPrincipal = true;

  List<Map<String, dynamic>> _parentescos = [];
  List<Map<String, dynamic>> _vinculos = [];
  bool _loading = false;
  String? _resultado;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _tutorSearchController.dispose();
    _pacienteSearchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadCatalogs();
    await _loadVinculos();
  }

  Future<void> _loadCatalogs() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final parentescos = await repo.fetchCatalog("usuarios", "parentesco");
      if (!mounted) {
        return;
      }
      setState(() => _parentescos = parentescos);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  Future<void> _loadVinculos() async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final vinculos = await repo.fetchTutorPatientLinks();
      if (!mounted) {
        return;
      }
      setState(() => _vinculos = vinculos);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    }
  }

  Future<List<Map<String, dynamic>>> _searchTutors(String query) async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      return repo.searchTutors(query: query, limit: 10);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchPacientes(String query) async {
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      return repo.searchPatients(query: query, limit: 10);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _buscarTutores() async {
    final query = _tutorSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _tutoresEncontrados = [];
        _selectedTutorId = null;
      });
      return;
    }

    final rows = await _searchTutors(query);
    if (!mounted) {
      return;
    }

    setState(() {
      _tutoresEncontrados = rows;
      _selectedTutorId = rows.isEmpty ? null : rows.first["id"]?.toString();
    });
  }

  Future<void> _buscarPacientes() async {
    final query = _pacienteSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _pacientesEncontrados = [];
        _selectedPacienteId = null;
      });
      return;
    }

    final rows = await _searchPacientes(query);
    if (!mounted) {
      return;
    }

    setState(() {
      _pacientesEncontrados = rows;
      _selectedPacienteId = rows.isEmpty ? null : rows.first["id"]?.toString();
    });
  }

  Future<void> _vincular() async {
    final idTutor = _selectedTutorId;
    final idPaciente = _selectedPacienteId;

    if (idTutor == null || idTutor.isEmpty || idPaciente == null || idPaciente.isEmpty) {
      setState(() => _error = "Debes seleccionar tutor y paciente.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultado = null;
    });

    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      await repo.linkTutorToPatient(
        idUsuarioTutor: idTutor,
        idPaciente: idPaciente,
        idParentesco: _selectedParentesco,
        esPrincipal: _esPrincipal,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _resultado = "Tutor y paciente vinculados correctamente.";
        _tutorSearchController.clear();
        _pacienteSearchController.clear();
        _tutoresEncontrados = [];
        _pacientesEncontrados = [];
        _selectedTutorId = null;
        _selectedPacienteId = null;
        _selectedParentesco = null;
        _esPrincipal = true;
      });

      await _loadVinculos();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editarVinculo(Map<String, dynamic> vinculo) async {
    int? parentesco = vinculo["id_parentesco"] as int?;
    bool esPrincipal = vinculo["es_principal"] == true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Editar vínculo"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: parentesco,
                    decoration: const InputDecoration(labelText: "Parentesco"),
                    items: _parentescos
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p["id"] as int,
                            child: Text(p["nombre"]?.toString() ?? ""),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setDialogState(() => parentesco = val),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: esPrincipal,
                    onChanged: (val) => setDialogState(() => esPrincipal = val),
                    title: const Text("Tutor principal"),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                FilledButton(
                  onPressed: () async {
                    final idVinculo = vinculo["id"] as int;
                    final repo = ref.read(supabaseCrudRepositoryProvider);
                    await repo.updateTutorPatientLink(
                      idVinculo: idVinculo,
                      idParentesco: parentesco,
                      esPrincipal: esPrincipal,
                    );
                    if (!mounted) {
                      return;
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    setState(() => _resultado = "Vínculo actualizado correctamente.");
                    await _loadVinculos();
                  },
                  child: const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _desvincular(Map<String, dynamic> vinculo) async {
    final idVinculo = vinculo["id"] as int;
    final repo = ref.read(supabaseCrudRepositoryProvider);
    await repo.unlinkTutorPatient(idVinculo: idVinculo);
    if (mounted) {
      setState(() => _resultado = "Vínculo eliminado correctamente.");
    }
    await _loadVinculos();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        _buildTutorSelector(),
        const SizedBox(height: 12),
        _buildPacienteSelector(),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _selectedParentesco,
          decoration: const InputDecoration(labelText: "Parentesco (Opcional)"),
          items: _parentescos
              .map(
                (p) => DropdownMenuItem<int>(
                  value: p["id"] as int,
                  child: Text(p["nombre"]?.toString() ?? ""),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedParentesco = val),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text("Tutor principal para este paciente"),
          value: _esPrincipal,
          onChanged: (val) => setState(() => _esPrincipal = val),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _vincular,
          icon: const Icon(Icons.link),
          label: const Text("Vincular Tutor y Paciente"),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              "Vínculos registrados",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadVinculos,
              icon: const Icon(Icons.refresh),
              tooltip: "Recargar vínculos",
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._vinculos.map(_buildVinculoCard),
        if (_vinculos.isEmpty)
          const Text("No hay vínculos activos registrados."),
        if (_resultado != null) ...[
          const SizedBox(height: 12),
          Text(
            _resultado!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTutorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tutorSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscarTutores(),
                decoration: const InputDecoration(
                  labelText: "Buscar tutor por nombre o cédula",
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _buscarTutores,
              child: const Text("Buscar"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedTutorId,
          decoration: const InputDecoration(labelText: "Seleccionar tutor"),
          items: _tutoresEncontrados
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t["id"]?.toString(),
                  child: Text(
                    "${t["nombre_completo"] ?? ""} - Cédula: ${t["cedula"] ?? "N/A"}",
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedTutorId = value),
        ),
      ],
    );
  }

  Widget _buildPacienteSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pacienteSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscarPacientes(),
                decoration: const InputDecoration(
                  labelText: "Buscar paciente por nombre",
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _buscarPacientes,
              child: const Text("Buscar"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedPacienteId,
          decoration: const InputDecoration(labelText: "Seleccionar paciente"),
          items: _pacientesEncontrados
              .map(
                (p) => DropdownMenuItem<String>(
                  value: p["id"]?.toString(),
                  child: Text("${p["nombre_completo"] ?? ""} - ID: ${p["id"] ?? "N/A"}"),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedPacienteId = value),
        ),
      ],
    );
  }

  Widget _buildVinculoCard(Map<String, dynamic> vinculo) {
    final parentescoNombre = vinculo["parentesco_nombre"]?.toString() ?? "Sin parentesco";
    final tutorNombre = vinculo["tutor_nombre"]?.toString() ?? "Tutor";
    final tutorCedula = vinculo["tutor_cedula"]?.toString() ?? "N/A";
    final pacienteNombre = vinculo["paciente_nombre"]?.toString() ?? "Paciente";
    final esPrincipal = vinculo["es_principal"] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tutor: $tutorNombre", style: const TextStyle(fontWeight: FontWeight.w700)),
            Text("Cédula tutor: $tutorCedula"),
            Text("Paciente: $pacienteNombre"),
            Text("Parentesco: $parentescoNombre"),
            Text("Principal: ${esPrincipal ? "Sí" : "No"}"),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _editarVinculo(vinculo),
                  icon: const Icon(Icons.edit),
                  label: const Text("Editar"),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _desvincular(vinculo),
                  icon: const Icon(Icons.link_off),
                  label: const Text("Desvincular"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}