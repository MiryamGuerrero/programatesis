import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'tutor_home_page.dart';

class MisPacientesPage extends StatefulWidget {
  const MisPacientesPage({super.key});

  @override
  State<MisPacientesPage> createState() => _MisPacientesPageState();
}

class _MisPacientesPageState extends State<MisPacientesPage> {
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                
                // SEARCH BAR M3
                SearchBar(
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
                
                const SizedBox(height: 32),
              
              const _PatientCard(
                nombre: "Carlos Ruiz",
                diagnostico: "AIJ Oligoarticular",
                estadoValor: "Estable",
                planEstado: "Plan activo",
                edad: "8 años",
              ),
              const SizedBox(height: 16),
              const _PatientCard(
                nombre: "Sofía Méndez",
                diagnostico: "AIJ Poliarticular",
                estadoValor: "En observación",
                planEstado: "Plan activo",
                edad: "6 años",
              ),
              const SizedBox(height: 16),
              const _PatientCard(
                nombre: "Juan Pérez",
                diagnostico: "AIJ Sistémica",
                estadoValor: "Estable",
                planEstado: "Plan activo",
                edad: "10 años",
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final String nombre;
  final String diagnostico;
  final String estadoValor;
  final String planEstado;
  final String edad;

  const _PatientCard({
    required this.nombre,
    required this.diagnostico,
    required this.estadoValor,
    required this.planEstado,
    required this.edad,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TutorHomePage(
                idPaciente: "1",
                nombrePaciente: nombre,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AVATAR M3 STYLE
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
                            Expanded(
                              child: Text(
                                diagnostico,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        Text(
                          "Estado: $estadoValor",
                          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        
                        // BADGE M3 STYLE
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTema.verdeSalud.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: AppTema.verdeSalud,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                planEstado,
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
