import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ExpedienteMaestroModal extends StatefulWidget {
  final Map<String, dynamic> data;

  const ExpedienteMaestroModal({super.key, required this.data});

  @override
  State<ExpedienteMaestroModal> createState() => _ExpedienteMaestroModalState();
}

class _ExpedienteMaestroModalState extends State<ExpedienteMaestroModal> {
  int _activeTab = 0;

  Widget _buildTab(int index, String label) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTema.azulPrincipal.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isActive ? AppTema.azulPrincipal : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: GoogleFonts.inter(
                  color: isActive ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? AppTema.azulPrincipal : const Color(0xFF64748B),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(IconData icon, String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTema.azulOscuro,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthCard(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTema.azulOscuro,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentidad() {
    final p = widget.data['paciente'] ?? {};
    final t = widget.data['tutor'] ?? {};
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Identidad del Paciente", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTema.azulOscuro)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCard(Icons.person_outline, "Nombres Completos", p['nombre_completo'] ?? '-')),
              const SizedBox(width: 16),
              Expanded(child: _buildCard(Icons.badge_outlined, "Cédula / ID", p['cedula'] ?? '-')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCard(Icons.cake_outlined, "Fecha de Nacimiento", p['fecha_nacimiento'] ?? '-')),
              const SizedBox(width: 16),
              Expanded(child: _buildCard(Icons.wc_outlined, "Sexo Biológico", p['sexo_nombre'] ?? '-')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCard(Icons.map_outlined, "Cantón", p['canton_nombre'] ?? '-')),
              const SizedBox(width: 16),
              Expanded(child: _buildCard(Icons.location_on_outlined, "Parroquia", p['parroquia_nombre'] ?? '-')),
            ],
          ),
          const SizedBox(height: 32),
          Text("Representante Legal", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTema.azulOscuro)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCard(Icons.supervisor_account_outlined, "Nombre Tutor", t['nombre_completo'] ?? '-')),
              const SizedBox(width: 16),
              Expanded(child: _buildCard(Icons.family_restroom_outlined, "Parentesco", t['parentesco_nombre'] ?? '-')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCard(Icons.phone_outlined, "Teléfono", t['telefono'] ?? '-')),
              const SizedBox(width: 16),
              Expanded(child: _buildCard(Icons.email_outlined, "Correo", t['email'] ?? '-')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnostico() {
    final d = widget.data['diagnostico'] ?? {};
    final c = widget.data['ultimo_control'] ?? {};
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Diagnóstico Reumatológico", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTema.azulOscuro)),
          const SizedBox(height: 16),
          _buildFullWidthCard(Icons.medical_services_outlined, "Enfermedad Autoinmune", d['condicion_nombre'] ?? 'No registrada'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCard(Icons.event_outlined, "Fecha de Diagnóstico", d['fecha_diagnostico'] ?? '-')),
              const SizedBox(width: 16),
              Expanded(child: _buildCard(Icons.healing_outlined, "Severidad (Opcional)", d['severidad_inicial'] ?? 'No especificada')),
            ],
          ),
          const SizedBox(height: 32),
          Text("Último Estado Clínico", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTema.azulOscuro)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCard(Icons.favorite_border_rounded, "Estado Nutricional", c['estado_nutricional'] ?? '-', valueColor: Colors.teal)),
              const SizedBox(width: 16),
              Expanded(child: _buildCard(Icons.monitor_weight_outlined, "Relación Peso/IMC", "${c['peso_kg'] ?? '-'} kg / IMC: ${c['imc_calculado'] ?? '-'}")),
            ],
          ),
          const SizedBox(height: 16),
          _buildFullWidthCard(Icons.query_stats_rounded, "Actividad Clínica (Última medición)", 
              "Dolor ${c['puntos_dolor'] ?? '-'} | Inflamación ${c['escala_inflamacion'] ?? '-'} | Fatiga ${c['nivel_fatiga'] ?? '-'} | Rigidez ${c['minutos_rigidez'] ?? '-'} min"),
        ],
      ),
    );
  }

  Widget _buildAlergias() {
    final al = widget.data['alergias'] ?? {};
    final hasMeds = (al['medicamentos'] as List?)?.isNotEmpty ?? false;
    final hasAliments = (al['subgrupos'] as List?)?.isNotEmpty ?? false;
    final hasLacteos = (al['subgrupos'] as List? ?? []).any((a) => {98, 100, 101, 104, 105, 108, 111, 114, 117, 119}.contains(a['id']));
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Alergias e Intolerancias", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTema.azulOscuro)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCard(Icons.medication_outlined, "Alergias a Medicamentos", 
                  hasMeds ? "Sí, registrado" : "Ninguna registrada",
                  valueColor: hasMeds ? Colors.red.shade700 : Colors.teal
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCard(Icons.restaurant_outlined, "Intolerancias Alimentarias", 
                  hasAliments ? "Sí, registrado" : "Ninguna registrada",
                  valueColor: hasAliments ? Colors.red.shade700 : Colors.teal
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasLacteos)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "ALERTA: Paciente con intolerancia severa/sensibilidad a Lácteos reportada. Ajustar plan dietético.",
                      style: GoogleFonts.inter(color: Colors.red.shade900, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 850,
        height: 650,
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EAF2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTema.azulPrincipal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_ind_outlined,
                    color: AppTema.azulPrincipal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Expediente Maestro Integral",
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                          "Registro oficial del paciente y soporte legal en el sistema ReumaNutri",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF64748B),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    hoverColor: const Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab(0, "Identidad"),
                const SizedBox(width: 16),
                _buildTab(1, "Diagnóstico"),
                const SizedBox(width: 16),
                _buildTab(2, "Alergias"),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _buildIdentidad(),
                  _buildDiagnostico(),
                  _buildAlergias(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0275D8), // A beautiful primary blue like the image
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  "Cerrar Expediente Maestro",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
