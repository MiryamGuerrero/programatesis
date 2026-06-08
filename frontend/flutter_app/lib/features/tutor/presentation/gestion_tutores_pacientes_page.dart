import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";

class GestionTutoresPacientesPage extends ConsumerStatefulWidget {
  const GestionTutoresPacientesPage({super.key});

  @override
  ConsumerState<GestionTutoresPacientesPage> createState() =>
      _GestionTutoresPacientesPageState();
}

class _GestionTutoresPacientesPageState
    extends ConsumerState<GestionTutoresPacientesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.grisLienzo,
      body: DefaultTabController(
        length: 3,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildTabBar(),
              const SizedBox(height: 24),
              const SizedBox(
                height:
                    800, // Altura fija para el contenido de las pestañas en el scroll
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
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión de Cuentas y Vínculos",
            style: GoogleFonts.montserrat(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTema.azulPrincipal,
                letterSpacing: -0.5)),
        Text(
            "Registro de tutores, pacientes pediátricos y administración de parentescos.",
            style: GoogleFonts.montserrat(
                color: Colors.blueGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: TabBar(
        labelColor: AppTema.azulPrincipal,
        unselectedLabelColor: Colors.blueGrey,
        indicatorColor: AppTema.azulPrincipal,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle:
            GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(
              icon: Icon(Icons.person_add_alt_1_rounded, size: 20),
              text: "REGISTRAR TUTOR"),
          Tab(
              icon: Icon(Icons.child_care_rounded, size: 20),
              text: "REGISTRAR PACIENTE"),
          Tab(
              icon: Icon(Icons.link_rounded, size: 20),
              text: "VINCULAR CUENTAS"),
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
  final _cedulaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _cedulaController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NutriTableContainer(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nuevo Tutor",
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTema.azulPrincipal)),
            const Text("Crea una cuenta de acceso para un representante legal.",
                style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
            const SizedBox(height: 32),
            _buildField("Correo Electrónico *", _emailController,
                Icons.alternate_email_rounded, "ejemplo@correo.com"),
            const SizedBox(height: 20),
            _buildField("Nombre Completo *", _nameController,
                Icons.person_outline_rounded, "Nombre y Apellidos"),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _buildField("Cédula", _cedulaController,
                        Icons.badge_outlined, "010... (opcional)")),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildField("Teléfono", _phoneController,
                        Icons.phone_android_rounded, "099...")),
              ],
            ),
            const SizedBox(height: 20),
            _buildField("Dirección", _addressController,
                Icons.home_work_outlined, "Calle principal y secundaria"),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _registrar,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text("REGISTRAR TUTOR",
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTema.azulPrincipal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController ctrl, IconData icon, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTema.azulPrincipal, size: 20),
            filled: true,
            fillColor: AppTema.grisLienzo.withOpacity(0.5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Future<void> _registrar() async {
    if (_emailController.text.isEmpty || _nameController.text.isEmpty) {
      NutriSnack.show(context, "Correo y Nombre son obligatorios",
          isError: true, ref: ref);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(supabaseCrudRepositoryProvider).registerTutorOnly(
            email: _emailController.text,
            nombreCompleto: _nameController.text,
            cedula:
                _cedulaController.text.isEmpty ? null : _cedulaController.text,
            fono: _phoneController.text.isEmpty ? null : _phoneController.text,
            direccion: _addressController.text.isEmpty
                ? null
                : _addressController.text,
          );
      if (mounted) {
        _emailController.clear();
        _nameController.clear();
        _cedulaController.clear();
        _phoneController.clear();
        _addressController.clear();
        NutriSnack.show(context, "Tutor registrado con éxito", ref: ref);
      }
    } catch (e) {
      if (mounted)
        NutriSnack.show(context, "Error: $e", isError: true, ref: ref);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _FormRegistroPaciente extends ConsumerStatefulWidget {
  const _FormRegistroPaciente();
  @override
  ConsumerState<_FormRegistroPaciente> createState() =>
      _FormRegistroPacienteState();
}

class _FormRegistroPacienteState extends ConsumerState<_FormRegistroPaciente> {
  final _nameController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _fechaNacController = TextEditingController();
  final _pesoController = TextEditingController();
  final _tallaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  int? _selectedSexo;
  DateTime? _fechaNac;
  bool _loading = false;
  List<Map<String, dynamic>> _sexos = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final s = await ref
          .read(supabaseCrudRepositoryProvider)
          .fetchCatalog("usuarios", "catalogo_sexo");
      if (mounted) setState(() => _sexos = s);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cedulaController.dispose();
    _fechaNacController.dispose();
    _pesoController.dispose();
    _tallaController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NutriTableContainer(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nuevo Paciente",
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTema.azulPrincipal)),
            const Text(
                "Registro base del paciente pediátrico para seguimiento clínico.",
                style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
            const SizedBox(height: 32),
            _buildField("Nombre del Paciente *", _nameController,
                Icons.child_care_rounded),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _buildField("Cédula (Opcional)", _cedulaController,
                        Icons.badge_outlined)),
                const SizedBox(width: 16),
                Expanded(child: _buildDateField()),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildSexoField()),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildField("Teléfono contacto", _phoneController,
                        Icons.phone_android_rounded)),
              ],
            ),
            const SizedBox(height: 20),
            _buildField(
                "Dirección", _addressController, Icons.home_work_outlined),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _buildField("Peso (kg)", _pesoController,
                        Icons.monitor_weight_outlined)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildField(
                        "Talla (cm)", _tallaController, Icons.height_rounded)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _registrar,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.app_registration_rounded),
                label: Text("REGISTRAR PACIENTE",
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTema.azulPrincipal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTema.azulPrincipal, size: 20),
            filled: true,
            fillColor: AppTema.grisLienzo.withOpacity(0.5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("FECHA DE NACIMIENTO *",
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        TextField(
          controller: _fechaNacController,
          readOnly: true,
          onTap: () async {
            final d = await showDatePicker(
                context: context,
                initialDate:
                    DateTime.now().subtract(const Duration(days: 3650)),
                firstDate: DateTime(1900),
                lastDate: DateTime.now());
            if (d != null) {
              setState(() {
                _fechaNac = d;
                _fechaNacController.text = d.toIso8601String().split("T").first;
              });
            }
          },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.calendar_today_rounded,
                color: AppTema.azulPrincipal, size: 20),
            filled: true,
            fillColor: AppTema.grisLienzo.withOpacity(0.5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSexoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("SEXO *",
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _selectedSexo,
          items: _sexos
              .map((s) => DropdownMenuItem(
                  value: s["id"] as int,
                  child: Text(s["descripcion"].toString())))
              .toList(),
          onChanged: (v) => setState(() => _selectedSexo = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_search_rounded,
                color: AppTema.azulPrincipal, size: 20),
            filled: true,
            fillColor: AppTema.grisLienzo.withOpacity(0.5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Future<void> _registrar() async {
    if (_nameController.text.isEmpty ||
        _fechaNac == null ||
        _selectedSexo == null) {
      NutriSnack.show(context, "Datos obligatorios faltantes (*)",
          isError: true, ref: ref);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(supabaseCrudRepositoryProvider).registerPatientOnly(
          nombreCompleto: _nameController.text,
          fechaNacimiento: _fechaNac!,
          idSexo: _selectedSexo!,
          cedula:
              _cedulaController.text.isEmpty ? null : _cedulaController.text,
          fono: _phoneController.text.isEmpty ? null : _phoneController.text,
          direccion:
              _addressController.text.isEmpty ? null : _addressController.text,
          controlClinicoInicial: {
            "peso_kg": double.tryParse(_pesoController.text) ?? 0,
            "talla_cm": double.tryParse(_tallaController.text) ?? 0,
          });
      if (mounted) {
        _nameController.clear();
        _cedulaController.clear();
        _fechaNacController.clear();
        _pesoController.clear();
        _tallaController.clear();
        _phoneController.clear();
        _addressController.clear();
        NutriSnack.show(context, "Paciente registrado con éxito", ref: ref);
      }
    } catch (e) {
      if (mounted)
        NutriSnack.show(context, "Error: $e", isError: true, ref: ref);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _FormVincularTutorPaciente extends ConsumerStatefulWidget {
  const _FormVincularTutorPaciente();
  @override
  ConsumerState<_FormVincularTutorPaciente> createState() =>
      _FormVincularTutorPacienteState();
}

class _FormVincularTutorPacienteState
    extends ConsumerState<_FormVincularTutorPaciente> {
  final _tutorSearch = TextEditingController();
  final _pacienteSearch = TextEditingController();

  List<Map<String, dynamic>> _tutores = [];
  List<Map<String, dynamic>> _pacientes = [];
  List<Map<String, dynamic>> _parentescos = [];

  String? _idTutor;
  String? _idPaciente;
  int? _idParentesco;
  bool _loading = false;
  bool _searchingTutor = false;
  bool _searchingPaciente = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final p = await ref
          .read(supabaseCrudRepositoryProvider)
          .fetchCatalog("usuarios", "parentesco");
      if (mounted) setState(() => _parentescos = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return NutriTableContainer(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Vinculación Familiar",
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTema.azulPrincipal)),
            const Text(
                "Conecta un tutor con un paciente para habilitar el seguimiento móvil.",
                style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
            const SizedBox(height: 32),
            _buildSearchField("Buscar Tutor", _tutorSearch, true),
            const SizedBox(height: 20),
            _buildSearchField("Buscar Paciente", _pacienteSearch, false),
            const SizedBox(height: 20),
            _buildParentescoField(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _vincular,
                icon: const Icon(Icons.link_rounded),
                label: Text("VINCULAR CUENTAS",
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTema.verdeSalud,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(
      String label, TextEditingController ctrl, bool isTutor) {
    final list = isTutor ? _tutores : _pacientes;
    final selected = isTutor ? _idTutor : _idPaciente;
    final isSearching = isTutor ? _searchingTutor : _searchingPaciente;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey)),
            if (isSearching)
              Text("Buscando...",
                  style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTema.naranjaAlerta))
            else if (list.isNotEmpty)
              Text(isTutor ? "Tutor encontrado" : "Paciente encontrado",
                  style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTema.verdeSalud)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: "Escriba nombre...",
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: AppTema.grisLienzo.withOpacity(0.5),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: isSearching
                  ? null
                  : () async {
                      setState(() {
                        if (isTutor) {
                          _searchingTutor = true;
                        } else {
                          _searchingPaciente = true;
                        }
                      });
                      try {
                        final repo = ref.read(supabaseCrudRepositoryProvider);
                        final res = isTutor
                            ? await repo.searchTutors(query: ctrl.text)
                            : await repo.searchPatients(query: ctrl.text);
                        if (mounted) {
                          setState(() {
                            if (isTutor) {
                              _tutores = res;
                            } else {
                              _pacientes = res;
                            }
                          });
                        }
                      } catch (_) {
                        // No mostramos alertas intrusivas en búsqueda
                      } finally {
                        if (mounted) {
                          setState(() {
                            if (isTutor) {
                              _searchingTutor = false;
                            } else {
                              _searchingPaciente = false;
                            }
                          });
                        }
                      }
                    },
              icon: isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search_rounded),
            ),
          ],
        ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selected,
            items: list
                .map((e) => DropdownMenuItem(
                    value: e["id"].toString(),
                    child: Text(e["nombre_completo"].toString())))
                .toList(),
            onChanged: (v) => setState(() {
              if (isTutor) {
                _idTutor = v;
              } else {
                _idPaciente = v;
              }
            }),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTema.pastelCeleste.withOpacity(0.3),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParentescoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PARENTESCO",
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _idParentesco,
          items: _parentescos
              .map((p) => DropdownMenuItem(
                  value: p["id"] as int,
                  child: Text(p["nombre"].toString().toUpperCase())))
              .toList(),
          onChanged: (v) => setState(() => _idParentesco = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.family_restroom_rounded,
                color: AppTema.azulPrincipal, size: 20),
            filled: true,
            fillColor: AppTema.grisLienzo.withOpacity(0.5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Future<void> _vincular() async {
    if (_idTutor == null || _idPaciente == null) {
      NutriSnack.show(context, "Debe seleccionar tutor y paciente",
          isError: true, ref: ref);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(supabaseCrudRepositoryProvider).linkTutorToPatient(
            idUsuarioTutor: _idTutor!,
            idPaciente: _idPaciente!,
            idParentesco: _idParentesco,
            esPrincipal: true,
          );
      if (mounted)
        NutriSnack.show(context, "Vínculo creado con éxito", ref: ref);
    } catch (e) {
      if (mounted)
        NutriSnack.show(context, "Error: $e", isError: true, ref: ref);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
