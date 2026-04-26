import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";
import "../../../shared/widgets/nutri_avatar.dart";
import "../../../core/state/app_providers.dart";
import "registro_paciente_page.dart";
import "control_mensual_page.dart";

class SupervisionPacientesPage extends ConsumerWidget {
  const SupervisionPacientesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(medicoNavProvider);
    final selectedPatient = ref.watch(selectedPatientProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildBody(currentView, selectedPatient),
    );
  }

  Widget _buildBody(MedicoView view, Map<String, dynamic>? patient) {
    switch (view) {
      case MedicoView.register:
        return const RegistroPacientePage();
      case MedicoView.control:
        if (patient == null) return const _ListaPacientesView();
        return ControlMensualPage(paciente: patient);
      case MedicoView.list:
      default:
        return const _ListaPacientesView();
    }
  }
}

class _ListaPacientesView extends ConsumerStatefulWidget {
  const _ListaPacientesView();
  @override
  ConsumerState<_ListaPacientesView> createState() => _ListaPacientesViewState();
}

class _ListaPacientesViewState extends ConsumerState<_ListaPacientesView> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildStatsRow(patientsAsync.valueOrNull ?? []),
          const SizedBox(height: 32),
          NutriTableToolbar(
            actionLabel: "Nuevo Paciente",
            onAction: () => ref.read(medicoNavProvider.notifier).state = MedicoView.register,
            onSearch: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 24),
          _buildPatientsTable(patientsAsync),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Gestión de Expedientes Pediátricos", 
          style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulPrincipal, letterSpacing: -0.5)),
        Text("Consistencia clínica estandarizada bajo parámetros OMS.", 
          style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatsRow(List<Map<String, dynamic>> patients) {
    return Row(
      children: [
        Expanded(child: NutriResumenCard(titulo: "TOTAL PACIENTES", valor: "${patients.length}", icon: Icons.child_care_rounded)),
        const SizedBox(width: 20),
        const Expanded(child: NutriResumenCard(titulo: "REGIÓN", valor: "CHIMBORAZO", colorValor: AppTema.verdeSalud, icon: Icons.location_on_rounded)),
        const SizedBox(width: 20),
        const Expanded(child: NutriResumenCard(titulo: "NORMATIVA", valor: "OMS 2024", colorValor: AppTema.cianLimpio, icon: Icons.verified_user_rounded)),
      ],
    );
  }

  Widget _buildPatientsTable(AsyncValue<List<Map<String, dynamic>>> patientsAsync) {
    return NutriTableContainer(
      child: patientsAsync.when(
        data: (patients) {
          final filtered = patients.where((p) {
            final term = _searchQuery.toLowerCase();
            return p["nombre_completo"].toString().toLowerCase().contains(term) ||
                   p["cedula"].toString().toLowerCase().contains(term);
          }).toList();

          if (filtered.isEmpty) return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No se encontraron registros pediátricos.")));

          return DataTable(
            headingRowColor: WidgetStateProperty.all(AppTema.pastelCeleste),
            columns: [
              _col("IDENTIDAD Y PACIENTE"),
              _col("CÉDULA"),
              _col("EDAD"),
              _col("ESTADO NUTRICIONAL (OMS)"),
              _col("ACCIONES"),
            ],
            rows: filtered.map((p) => DataRow(
              cells: [
                DataCell(Row(
                  children: [
                    NutriAvatar(nombreCompleto: p["nombre_completo"] ?? "P", radio: 16),
                    const SizedBox(width: 12),
                    Text(p["nombre_completo"]?.toString() ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTema.azulPrincipal)),
                  ],
                )),
                DataCell(Text(p["cedula"]?.toString() ?? "-", style: GoogleFonts.firaMono(fontSize: 12))),
                DataCell(Text("${p["edad_anios"] ?? 0} años", style: const TextStyle(fontSize: 13))),
                DataCell(NutriBadge(
                  label: (p["estado_nutricional"] ?? "PENDIENTE").toString().toUpperCase(), 
                  type: _getBadgeType(p["estado_nutricional"])
                )),
                DataCell(Row(
                  children: [
                    IconButton(tooltip: "Analítica y Control", icon: const Icon(Icons.analytics_rounded, color: AppTema.azulPrincipal, size: 20), onPressed: () {
                      ref.read(selectedPatientProvider.notifier).state = p;
                      ref.read(medicoNavProvider.notifier).state = MedicoView.control;
                    }),
                    IconButton(tooltip: "Editar Perfil Maestro", icon: const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 22), onPressed: () {
                      ref.read(selectedPatientProvider.notifier).state = p;
                      ref.read(medicoNavProvider.notifier).state = MedicoView.register; // Reutilizamos la vista de registro pero en modo edición
                    }),
                    IconButton(tooltip: "Eliminar Expediente", icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _confirmarEliminar(p)),
                  ],
                )),
              ],
            )).toList(),
          );
        },
        loading: () => const NutriLoading(mensaje: "Sincronizando expedientes..."),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  String _getBadgeType(dynamic estado) {
    if (estado == null) return "info";
    final e = estado.toString().toLowerCase();
    if (e.contains("eutrófico") || e.contains("normal")) return "success";
    if (e.contains("sobrepeso") || e.contains("desnutrición") || e.contains("riesgo")) return "warning";
    if (e.contains("obesidad") || e.contains("severa") || e.contains("delgadez")) return "danger";
    return "info";
  }

  DataColumn _col(String l) => DataColumn(label: Text(l, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppTema.azulPrincipal)));

  Future<void> _confirmarEliminar(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Eliminar Paciente", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("¿Deseas eliminar a ${p['nombre_completo']}? Esta acción limpiará todo el historial clínico y tutor si no tiene más hijos."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text("SÍ, ELIMINAR")),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(supabaseCrudRepositoryProvider).deletePatient(p["id"].toString());
        ref.invalidate(patientsListProvider);
        if (context.mounted) NutriSnack.show(context, "Paciente eliminado con éxito", ref: ref);
      } catch (e) {
        if (context.mounted) NutriSnack.show(context, "Error al eliminar", isError: true, ref: ref);
      }
    }
  }
}
