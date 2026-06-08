import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import 'tutor_home_page.dart';

class MisPacientesPage extends ConsumerStatefulWidget {
  const MisPacientesPage({super.key});

  @override
  ConsumerState<MisPacientesPage> createState() => _MisPacientesPageState();
}

class _MisPacientesPageState extends ConsumerState<MisPacientesPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final patientsAsync = ref.watch(misPacientesProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Mis Pacientes",
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTema.azulOscuro,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Selecciona un perfil para gestionar su plan nutricional y seguimiento.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: patientsAsync.when(
                data: (patients) {
                  if (patients.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_off_rounded,
                              size: 80,
                              color: colorScheme.outline.withOpacity(0.1)),
                          const SizedBox(height: 20),
                          Text(
                            "No tienes pacientes asignados",
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 8),
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final p = patients[index];
                      return _PatientCard(
                        patientData: p,
                        onTap: () {
                          ref.read(selectedPatientIdProvider.notifier).state =
                              p["id"].toString();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const TutorHomePage()),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("Error: $err")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> patientData;
  final VoidCallback onTap;

  const _PatientCard({
    required this.patientData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String nombre =
        patientData["nombre_completo"] ?? "Paciente sin nombre";
    final String diagnostico =
        patientData["diagnostico"] ?? "Diagnóstico no especificado";
    final String id =
        patientData["id"]?.toString().substring(0, 8).toUpperCase() ??
            "ID-TEMP";
    final String fechaNac = patientData["fecha_nacimiento"] ?? "";

    String edad = "N/A";
    if (fechaNac.isNotEmpty) {
      try {
        final birth = DateTime.parse(fechaNac);
        final now = DateTime.now();
        int years = now.year - birth.year;
        if (now.month < birth.month ||
            (now.month == birth.month && now.day < birth.day)) {
          years--;
        }
        edad = "$years años";
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar Dinámico con Iniciales
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withOpacity(0.8)
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : "?",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Información Principal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cake_outlined,
                                  size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                edad,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nombre,
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTema.azulOscuro,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),
                // Sección Inferior: Diagnóstico y Estado
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.medical_services_outlined,
                              size: 18, color: AppTema.azulPrincipal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              diagnostico,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Badge de Acceso
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTema.verdeSalud.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_forward_rounded,
                              color: AppTema.verdeSalud, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
