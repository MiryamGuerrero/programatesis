import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";
import "../../../core/theme/app_theme.dart";
import "../data/seguimiento_provider.dart";
import "plan_diario_page.dart";

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
    final hoyStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAdherenciaSection(adherenciaAsync),
                  const SizedBox(height: 32),
                  _buildSectionHeader("Panel de Control"),
                  const SizedBox(height: 16),
                  _buildActionGrid(context, hoyStr),
                  const SizedBox(height: 32),
                  _buildSectionHeader("Resumen de Salud"),
                  const SizedBox(height: 16),
                  _buildHealthSummary(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTema.azulPrincipal,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Hola, Tutor",
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white70),
            ),
            Text(
              nombrePaciente,
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppTema.azulPrincipal, AppTema.azulOscuro],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1E293B),
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildAdherenciaSection(AsyncValue<Map<String, dynamic>> asyncStats) {
    return asyncStats.when(
      data: (stats) => _buildAdherenciaCard(stats),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAdherenciaCard(Map<String, dynamic> stats) {
    final porcentaje = (stats["porcentaje_cumplimiento"] as num).toDouble();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Adherencia Semanal", 
                  style: GoogleFonts.montserrat(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Text("${porcentaje.toInt()}%", 
                  style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w900, color: AppTema.azulPrincipal)),
                const SizedBox(height: 4),
                Text("${stats["total_consumido"]} de ${stats["total_planificado"]} comidas cumplidas",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          _buildProgressCircle(porcentaje),
        ],
      ),
    );
  }

  Widget _buildProgressCircle(double percentage) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percentage / 100,
            strokeWidth: 10,
            backgroundColor: AppTema.azulPrincipal.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTema.azulPrincipal),
            strokeCap: StrokeCap.round,
          ),
          Icon(Icons.auto_awesome_rounded, color: AppTema.azulPrincipal, size: 30),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, String fecha) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildActionCard(
          "Plan del Día",
          Icons.restaurant_menu_rounded,
          AppTema.azulPrincipal,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlanDiarioPage(idPaciente: idPaciente, fecha: fecha))),
        ),
        _buildActionCard(
          "Restricciones",
          Icons.no_food_rounded,
          Colors.orange,
          () {},
        ),
        _buildActionCard(
          "Evolución",
          Icons.insights_rounded,
          AppTema.verdeSalud,
          () {},
        ),
        _buildActionCard(
          "Reemplazos",
          Icons.swap_horiz_rounded,
          Colors.purple,
          () {},
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.03)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark slate
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Estado Actual", style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Estable y en Seguimiento", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
        ],
      ),
    );
  }
}
