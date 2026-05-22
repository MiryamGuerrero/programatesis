import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import 'tutor_home_page.dart';

class MisPacientesPage extends ConsumerStatefulWidget {
  const MisPacientesPage({super.key});

  @override
  ConsumerState<MisPacientesPage> createState() => _MisPacientesPageState();
}

class _MisPacientesPageState extends ConsumerState<MisPacientesPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final patientsAsync = ref.watch(misPacientesProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              Text(
                "Mis Pacientes",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              
              Text(
                "Gestiona el seguimiento y bienestar de tus pacientes asignados.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
              ),
              
              const SizedBox(height: 32),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SearchBar(
                  controller: _searchController,
                  hintText: "Buscar paciente...",
                  leading: const Icon(Icons.search_outlined),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchController.clear());
                        },
                      ),
                  ],
                  onChanged: (val) => setState(() {}),
                  elevation: WidgetStateProperty.all(0),
                  backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest.withOpacity(0.3)),
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Expanded(
                child: patientsAsync.when(
                  data: (patients) {
                    final filtered = patients.where((p) {
                      final name = p["nombre_completo"]?.toString().toLowerCase() ?? "";
                      return name.contains(_searchController.text.toLowerCase());
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_outlined, size: 64, color: colorScheme.outline.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text("No se encontraron pacientes", style: TextStyle(color: colorScheme.outline)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final String id = p["id"].toString();
                        final String nombre = p["nombre_completo"] ?? "Sin nombre";
                        final String parentesco = p["parentesco"] ?? "Asignado";
                        final String fechaNac = p["fecha_nacimiento"] ?? "";
                        
                        String edad = "Edad no disponible";
                        if (fechaNac.isNotEmpty) {
                          try {
                            final birth = DateTime.parse(fechaNac);
                            final now = DateTime.now();
                            int years = now.year - birth.year;
                            if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
                              years--;
                            }
                            edad = "$years años";
                          } catch (_) {}
                        }

                        return _PatientCard(
                          nombre: nombre,
                          diagnostico: "AIJ", // En una app real vendría de la BD
                          relacion: parentesco,
                          edad: edad,
                          onTap: () {
                            ref.read(selectedPatientIdProvider.notifier).state = id;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TutorHomePage()),
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final String nombre;
  final String diagnostico;
  final String relacion;
  final String edad;
  final VoidCallback onTap;

  const _PatientCard({
    required this.nombre,
    required this.diagnostico,
    required this.relacion,
    required this.edad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            Icon(
                              Icons.monitor_heart_outlined,
                              color: colorScheme.primary.withOpacity(0.6),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              diagnostico,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        Text(
                          "Relación: $relacion",
                          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTema.verdeSalud.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppTema.verdeSalud, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                "Seguimiento Activo",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTema.verdeSalud,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Text(
                  edad,
                  style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
