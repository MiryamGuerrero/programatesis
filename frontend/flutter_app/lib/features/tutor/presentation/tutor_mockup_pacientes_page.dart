import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class TutorMockupPacientesPage extends StatelessWidget {
  const TutorMockupPacientesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Colores basados en el sistema de diseño web identificado
    final Color colorFondo = AppTema.grisFondo; // #F8FAFC
    final Color colorTitulo = const Color(0xFF1E293B);
    final Color colorSubtitulo = const Color(0xFF64748B);
    final Color colorAcento = AppTema.azulPrincipal; // #0171BB
    final Color colorEstadoPositivo = AppTema.verdeSalud; // #70A81C

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Encabezado
              Text(
                "Mis Pacientes",
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorTitulo,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Gestiona el seguimiento y bienestar de tus pacientes asignados.",
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: colorSubtitulo,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Barra de Búsqueda
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF94A3B8), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Buscar paciente...",
                          hintStyle: GoogleFonts.lato(color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Lista de Pacientes
              _PatientCard(
                nombre: "Carlos Ruiz",
                diagnostico: "AIJ Oligoarticular",
                estado: "Plan activo",
                edad: "8 años",
                colorAcento: colorAcento,
                colorEstado: colorEstadoPositivo,
                colorTitulo: colorTitulo,
                colorSubtitulo: colorSubtitulo,
              ),
              const SizedBox(height: 16),
              _PatientCard(
                nombre: "Sofía Méndez",
                diagnostico: "AIJ Poliarticular",
                estado: "Plan activo",
                edad: "6 años",
                colorAcento: colorAcento,
                colorEstado: colorEstadoPositivo,
                colorTitulo: colorTitulo,
                colorSubtitulo: colorSubtitulo,
              ),
              const SizedBox(height: 16),
              _PatientCard(
                nombre: "Juan Pérez",
                diagnostico: "AIJ Sistémica",
                estado: "Plan activo",
                edad: "10 años",
                colorAcento: colorAcento,
                colorEstado: colorEstadoPositivo,
                colorTitulo: colorTitulo,
                colorSubtitulo: colorSubtitulo,
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
  final String estado;
  final String edad;
  final Color colorAcento;
  final Color colorEstado;
  final Color colorTitulo;
  final Color colorSubtitulo;

  const _PatientCard({
    required this.nombre,
    required this.diagnostico,
    required this.estado,
    required this.edad,
    required this.colorAcento,
    required this.colorEstado,
    required this.colorTitulo,
    required this.colorSubtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorAcento,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorTitulo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.monitor_heart_outlined,
                                color: colorAcento.withOpacity(0.6),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  diagnostico,
                                  style: GoogleFonts.lato(
                                    fontSize: 14,
                                    color: colorSubtitulo,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Estado: Estable",
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: colorSubtitulo,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Badge de Estado
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorEstado.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: colorEstado,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  estado,
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorEstado,
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
                
                // Texto de Edad (esquina superior derecha)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Text(
                    edad,
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
