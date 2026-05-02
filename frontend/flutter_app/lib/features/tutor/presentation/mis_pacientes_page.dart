import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "../../../core/state/app_providers.dart";
import "../../../core/theme/app_theme.dart";
import "tutor_home_page.dart";

class MisPacientesPage extends ConsumerWidget {
  const MisPacientesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pacientesAsync = ref.watch(misPacientesProvider);

    return Scaffold(
      backgroundColor: AppTema.grisLienzo, // Revertido al color original
      appBar: AppBar(
        title: Text(
          "Mis Pacientes",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: pacientesAsync.when(
        data: (pacientes) {
          if (pacientes.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(misPacientesProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: pacientes.length,
              itemBuilder: (context, index) {
                final paciente = pacientes[index];
                return _PacienteCard(paciente: paciente);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text("Error al cargar pacientes", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.refresh(misPacientesProvider),
                child: const Text("Reintentar"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.child_care_rounded, size: 100, color: AppTema.azulPrincipal.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text(
            "Sin pacientes asignados",
            style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Aún no tienes pacientes bajo tu cuidado. Contacta al administrador para vincular una cuenta.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _PacienteCard extends StatelessWidget {
  final Map<String, dynamic> paciente;

  const _PacienteCard({required this.paciente});

  @override
  Widget build(BuildContext context) {
    final String nombre = paciente["nombre_completo"] ?? "Paciente";
    final String enfermedad = paciente["enfermedad_principal"] ?? "AIJ";
    final String condicionNutri = paciente["condicion_nutricional"] ?? "Evaluando...";
    final String parentesco = paciente["parentesco"] ?? "Tutor";
    final int edad = paciente["edad_anios"] ?? 0;
    final int idSexo = paciente["id_sexo"] ?? 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0, // Quitamos la elevación para un estilo más plano y moderno
      color: const Color(0xFFF0F9FF), // Un azul muy pálido para diferenciar la tarjeta del blanco/gris del fondo
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTema.azulPrincipal.withOpacity(0.2), width: 1.5), // Borde en azul principal suave
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TutorHomePage(
                idPaciente: paciente["id"].toString(),
                nombrePaciente: nombre,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _buildAvatar(idSexo),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTema.azulPrincipal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$parentesco • $edad años",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTag(enfermedad, AppTema.azulOscuro.withOpacity(0.1), AppTema.azulOscuro),
                        const SizedBox(width: 8),
                        _buildTag(condicionNutri, AppTema.verdeSalud.withOpacity(0.1), AppTema.verdeSalud),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(int idSexo) {
    final bool esMasculino = idSexo == 1;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: esMasculino ? Colors.blue.withOpacity(0.1) : Colors.pink.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        esMasculino ? Icons.boy_rounded : Icons.girl_rounded,
        size: 40,
        color: esMasculino ? Colors.blue : Colors.pink,
      ),
    );
  }

  Widget _buildTag(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
