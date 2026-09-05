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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTema.azulPrincipal.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
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
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? AppTema.azulPrincipal : const Color(0xFF64748B),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF0275D8), size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0275D8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 3,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1.5),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0275D8),
                Color(0xFF0275D8),
                Color(0xFF8DC63F),
                Color(0xFF8DC63F)
              ],
              stops: [0.0, 0.15, 0.15, 1.0],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildField(IconData icon, String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0275D8),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // Light greyish-blue filled background
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 14, color: const Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? const Color(0xFF1E293B),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdentidad() {
    final p = widget.data['paciente'] ?? {};
    final t = widget.data['tutor'] ?? {};
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(Icons.person, "Identidad del paciente"),
                _buildField(Icons.badge_outlined, "Cédula / ID*", p['cedula'] ?? '-'),
                const SizedBox(height: 16),
                _buildField(Icons.person_outline, "Nombres y apellidos*", p['nombre_completo'] ?? '-'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildField(Icons.cake_outlined, "F. Nacimiento", p['fecha_nacimiento'] ?? '-')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField(Icons.wc_outlined, "Sexo Biológico", p['sexo_nombre'] ?? '-')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildField(Icons.map_outlined, "Cantón*", p['canton_nombre'] ?? '-')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField(Icons.location_on_outlined, "Parroquia*", p['parroquia_nombre'] ?? '-')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(Icons.supervisor_account, "Representante legal"),
                _buildField(Icons.badge_outlined, "Cédula del tutor*", t['cedula'] ?? '-'),
                const SizedBox(height: 16),
                _buildField(Icons.person_outline, "Nombres y apellidos*", t['nombre_completo'] ?? '-'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildField(Icons.email_outlined, "Correo electrónico*", t['email'] ?? '-')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField(Icons.family_restroom_outlined, "Parentesco*", t['parentesco_nombre'] ?? '-')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildField(Icons.phone_outlined, "Teléfono móvil*", t['telefono'] ?? '-')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField(Icons.home_outlined, "Dirección del hogar*", t['direccion'] ?? p['direccion'] ?? '-')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnostico() {
    final d = widget.data['diagnostico'] ?? {};
    final c = widget.data['ultimo_control'] ?? {};
    
    Widget actChip(IconData icon, String label, String val, Color cBg, Color cText) {
      return Container(
         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
         decoration: BoxDecoration(color: cBg, borderRadius: BorderRadius.circular(6)),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Icon(icon, size: 12, color: cText),
             const SizedBox(width: 6),
             Text("$label: ", style: GoogleFonts.inter(fontSize: 10, color: cText.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
             Text(val, style: GoogleFonts.inter(fontSize: 11, color: cText, fontWeight: FontWeight.w800)),
           ]
         )
      );
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(Icons.medical_services, "Diagnóstico Reumatológico"),
                _buildField(Icons.coronavirus_outlined, "Enfermedad Autoinmune Principal*", d['condicion_nombre'] ?? 'No registrada'),
                const SizedBox(height: 16),
                _buildField(Icons.event_outlined, "Fecha de Diagnóstico*", d['fecha_diagnostico'] ?? '-'),
                const SizedBox(height: 16),
                _buildField(Icons.healing_outlined, "Severidad (Opcional)", d['severidad_inicial'] ?? 'No especificada'),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(Icons.monitor_heart, "Último Estado Clínico"),
                Row(
                  children: [
                    Expanded(child: _buildField(Icons.favorite_border_rounded, "Estado Nutricional", c['estado_nutricional'] ?? '-', valueColor: Colors.teal.shade700)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField(Icons.monitor_weight_outlined, "Peso / IMC", "${c['peso_kg'] ?? '-'} kg / ${c['imc_calculado'] ?? '-'}")),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Actividad Clínica (Última Medición)",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0275D8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                           actChip(Icons.sick_outlined, "Dolor", "${c['puntos_dolor'] ?? '-'}", Colors.red.shade50, Colors.red.shade700),
                           actChip(Icons.local_fire_department_outlined, "Inflamación", "${c['escala_inflamacion'] ?? '-'}", Colors.orange.shade50, Colors.orange.shade800),
                           actChip(Icons.bolt_outlined, "Fatiga", "${c['nivel_fatiga'] ?? '-'}", Colors.amber.shade50, Colors.amber.shade900),
                           actChip(Icons.timer_outlined, "Rigidez", "${c['minutos_rigidez'] ?? '-'}m", Colors.blue.shade50, Colors.blue.shade700),
                        ]
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlergias() {
    final al = widget.data['alergias'] ?? {};
    final hasMeds = (al['medicamentos'] as List?)?.isNotEmpty ?? false;
    final medsList = hasMeds ? (al['medicamentos'] as List).map((e) => e['nombre']).join(", ") : "Ninguna registrada";
    
    final hasAliments = (al['subgrupos'] as List?)?.isNotEmpty ?? false;
    final alimentsList = hasAliments ? (al['subgrupos'] as List).map((e) => e['nombre']).join(", ") : "Ninguna registrada";

    final hasLacteos = (al['subgrupos'] as List? ?? []).any((a) => {98, 100, 101, 104, 105, 108, 111, 114, 117, 119}.contains(a['id']));
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(Icons.warning_amber_rounded, "Alergias e Intolerancias"),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildField(Icons.medication_outlined, "Alergias a Medicamentos", 
                  medsList,
                  valueColor: hasMeds ? Colors.red.shade700 : const Color(0xFF1E293B)
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildField(Icons.restaurant_outlined, "Intolerancias Alimentarias", 
                  alimentsList,
                  valueColor: hasAliments ? Colors.red.shade700 : const Color(0xFF1E293B)
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (hasLacteos)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "ALERTA: Paciente con intolerancia severa/sensibilidad a Lácteos reportada. Ajustar plan dietético estrictamente.",
                      style: GoogleFonts.inter(color: Colors.red.shade900, fontWeight: FontWeight.w600, fontSize: 11),
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
        width: 900,
        height: 620,
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTema.azulPrincipal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_ind_outlined,
                    color: AppTema.azulPrincipal,
                    size: 18,
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                          "Registro oficial del paciente y soporte legal en el sistema",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
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
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildTab(0, "Identidad y Contacto"),
                const SizedBox(width: 8),
                _buildTab(1, "Diagnóstico y Estado Clínico"),
                const SizedBox(width: 8),
                _buildTab(2, "Alergias e Intolerancias"),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0275D8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  "Cerrar Expediente Maestro",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
