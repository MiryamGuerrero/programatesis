import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/state/app_providers.dart";
import "../../../shared/models/app_role.dart";
import "expediente_paciente_page.dart";
import "registrar_paciente_page.dart";

class GestionPacientesPage extends ConsumerStatefulWidget {
  const GestionPacientesPage({super.key});

  @override
  ConsumerState<GestionPacientesPage> createState() => _GestionPacientesPageState();
}

class _GestionPacientesPageState extends ConsumerState<GestionPacientesPage> {
  bool _loading = false;
  List<dynamic> _pacientes = [];
  final TextEditingController _searchController = TextEditingController();

  // Estados de Navegación Interna para mantener el Menú visible
  Map<String, dynamic>? _pacienteSeleccionado;
  bool _mostrandoRegistro = false;

  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    _buscar("");
  }

  Future<void> _buscar(String q) async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseCrudRepositoryProvider);
      final results = await repo.searchPatients(query: q);
      setState(() {
        _pacientes = results;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _eliminar(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Paciente"),
        content: const Text("Esta acción borrará todo el historial y datos. Es irreversible. ¿Continuar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ELIMINAR")),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _loading = true);
      try {
        final repo = ref.read(supabaseCrudRepositoryProvider);
        await repo.deletePatient(id);
        _buscar("");
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // VISTA 1: REGISTRO MAESTRO (Dentro del shell)
    if (_mostrandoRegistro) {
      return RegistrarPacientePage(
        onBack: () {
          setState(() => _mostrandoRegistro = false);
          _buscar("");
        },
      );
    }

    // VISTA 2: EXPEDIENTE (Dentro del shell)
    if (_pacienteSeleccionado != null) {
      return ExpedientePacientePage(
        idPaciente: _pacienteSeleccionado!['id'],
        nombrePaciente: _pacienteSeleccionado!['nombre'],
        onBack: () => setState(() => _pacienteSeleccionado = null),
      );
    }

    // VISTA 3: LISTADO Y BÚSQUEDA
    final rol = ref.watch(appRoleProvider).valueOrNull ?? AppRole.nutricionista;
    final esMedicoOAdmin = rol == AppRole.medico || rol == AppRole.admin;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2F1), // Turquesa muy claro para el fondo
            border: Border(bottom: BorderSide(color: Colors.teal.shade100)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: "Buscar niño por nombre...", 
                    prefixIcon: Icon(Icons.search, color: Colors.teal),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: _buscar,
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => setState(() => _mostrandoRegistro = true), 
                icon: const Icon(Icons.person_add), 
                label: const Text("NUEVO REGISTRO MAESTRO"),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5), // Turquesa
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                ),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(color: Color(0xFF00BFA5)),
        Expanded(
          child: ListView.builder(
            itemCount: _pacientes.length,
            itemBuilder: (ctx, i) {
              final p = _pacientes[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  onTap: () => setState(() => _pacienteSeleccionado = p),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: const Icon(Icons.child_care, color: Colors.teal),
                  ),
                  title: Text(p['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Tutor: ${p['tutor'] ?? 'N/A'} - Tel: ${p['tutor_telefono'] ?? '-'}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (esMedicoOAdmin)
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _eliminar(p['id'])),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
