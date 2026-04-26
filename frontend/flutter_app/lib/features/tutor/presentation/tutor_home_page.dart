import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/theme/app_theme.dart";
import "../data/seguimiento_provider.dart";
import "plan_diario_page.dart";
import "package:intl/intl.dart";

class TutorHomePage extends ConsumerWidget {
  final String idPaciente;
  final String nombrePaciente;

  const TutorHomePage({
    super.key,
    required this.idPaciente,
    required this.nombrePaciente,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adherenciaAsync = ref.watch(adherenciaProvider((idPaciente: idPaciente, dias: 7)));
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTema.grisFondo,
      appBar: AppBar(
        title: const Text("ReumaNutri • Tutor"),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBienvenida(),
            const SizedBox(height: 25),
            
            // Sección de Adherencia (Resumen con Gráfico)
            adherenciaAsync.when(
              data: (stats) => _buildAdherenciaCard(stats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Card(child: Text("Error al cargar estadísticas")),
            ),
            
            const SizedBox(height: 30),
            const Text(
              "Acciones de Hoy",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            
            _buildMenuButton(
              context,
              title: "Plan de Alimentación",
              subtitle: "Ver qué debe comer el paciente hoy",
              icon: Icons.restaurant_menu,
              color: AppTema.azulClinico,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlanDiarioPage(idPaciente: idPaciente, fecha: hoy)),
              ),
            ),
            
            const SizedBox(height: 15),
            
            _buildMenuButton(
              context,
              title: "Restricciones Médicas",
              subtitle: "Alimentos prohibidos por salud",
              icon: Icons.security,
              color: AppTema.rojoProhibido,
              onTap: () {},
            ),
            
            const SizedBox(height: 15),
            
            _buildMenuButton(
              context,
              title: "Evolución Clínica",
              subtitle: "Ver reportes y diagnósticos OMS",
              icon: Icons.show_chart,
              color: AppTema.verdeSalud,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBienvenida() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Bienvenido,", style: TextStyle(fontSize: 16, color: Colors.grey)),
        Text(
          nombrePaciente,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTema.azulClinico),
        ),
      ],
    );
  }

  Widget _buildAdherenciaCard(Map<String, dynamic> stats) {
    final porcentaje = (stats["porcentaje_cumplimiento"] as num).toDouble();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTema.azulClinico, AppTema.azulClinico.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppTema.azulClinico.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Cumplimiento", style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 5),
                const Text("Semana Actual", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  "${stats["total_consumido"]} de ${stats["total_planificado"]} comidas",
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: porcentaje / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text("${porcentaje.toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
