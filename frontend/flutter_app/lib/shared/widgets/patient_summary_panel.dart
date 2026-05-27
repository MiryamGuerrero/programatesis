import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'nutri_avatar.dart';

class PatientSummaryPanel extends StatelessWidget {
  final Map<String, dynamic> expediente;
  final String Function(String?) formatEdad;
  final VoidCallback onVerExpediente;
  final double width;

  const PatientSummaryPanel({
    super.key,
    required this.expediente,
    required this.formatEdad,
    required this.onVerExpediente,
    this.width = 380,
  });

  @override
  Widget build(BuildContext context) {
    final p = expediente['paciente'] ?? {};
    final d = expediente['diagnostico'] ?? {};
    final c = expediente['ultimo_control'] ?? {};
    final al = expediente['alergias'] ?? {};
    final restriccionesDetalle =
        (expediente['restricciones_alimentarias_detalle'] as List? ?? []);

    final restriccionesActivas = _buildRestriccionesActivas(
      restriccionesDetalle,
      esIntoleranteLactosa: expediente['es_intolerante_lactosa'] == true,
    );

    final subgrupos = (al['subgrupos'] as List? ?? [])
        .map((e) => e['nombre'].toString())
        .toList();

    final ingredientes = (al['ingredientes'] as List? ?? [])
        .map((e) => e['nombre'].toString())
        .toList();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Text(
                    'RESUMEN CLINICO',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      color: AppTema.verdeSalud,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  NutriAvatar(
                    nombreCompleto: p['nombre_completo'] ?? 'P',
                    radio: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    p['nombre_completo'] ?? '-',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatEdad(p['fecha_nacimiento']),
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'PESO ACTUAL',
                          value: "${c['peso_kg'] ?? '-'} kg",
                          icon: Icons.scale_outlined,
                          iconColor: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: 'TALLA ACTUAL',
                          value: "${c['talla_cm'] ?? '-'} cm",
                          icon: Icons.straighten_rounded,
                          iconColor: AppTema.verdeSalud,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    label: 'ESTADO NUTRICIONAL',
                    value: c['estado_nutricional'] ?? 'PENDIENTE',
                    icon: Icons.analytics_outlined,
                    iconColor: AppTema.verdeSalud,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    label: 'ENFERMEDAD PRINCIPAL',
                    value:
                        d['condicion_nombre'] ?? d['nombre_condicion'] ?? '-',
                    icon: Icons.medical_services_outlined,
                    iconColor: AppTema.azulPrincipal,
                    isFullWidth: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(),
                  ),
                  ...restriccionesActivas.map(
                    (res) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SummaryCard(
                        label: 'RESTRICCION CLINICA',
                        value: "SI (${res.nombre.toUpperCase()})",
                        icon: res.icon,
                        iconColor: res.color,
                        isFullWidth: true,
                      ),
                    ),
                  ),
                  if (subgrupos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ListSummaryCard(
                      label: 'ALERGIAS (SUBGRUPOS)',
                      items: subgrupos,
                      icon: Icons.warning_amber_rounded,
                      iconColor: Colors.orange,
                    ),
                  ],
                  if (ingredientes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ListSummaryCard(
                      label: 'ALERGIAS (ESPECIFICAS)',
                      items: ingredientes,
                      icon: Icons.security_rounded,
                      iconColor: Colors.orange,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onVerExpediente,
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text('VER EXPEDIENTE MAESTRO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<_RestriccionActiva> _buildRestriccionesActivas(
  List<dynamic> restriccionesDetalle, {
  required bool esIntoleranteLactosa,
}) {
  final out = <_RestriccionActiva>[];
  final seen = <String>{};

  for (final raw in restriccionesDetalle) {
    final row =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final codigo = (row['codigo'] ?? '').toString().trim();
    if (codigo.isEmpty || !seen.add(codigo)) continue;
    final nombre = (row['nombre'] ?? codigo).toString().trim();

    out.add(
      _RestriccionActiva(
        codigo: codigo,
        nombre: nombre.isEmpty ? codigo : nombre,
      ),
    );
  }

  if (esIntoleranteLactosa && !seen.contains('INTOLERANCIA_LACTOSA')) {
    out.add(
      const _RestriccionActiva(
        codigo: 'INTOLERANCIA_LACTOSA',
        nombre: 'Intolerancia a la lactosa',
      ),
    );
  }

  return out;
}

class _RestriccionActiva {
  final String codigo;
  final String nombre;

  const _RestriccionActiva({
    required this.codigo,
    required this.nombre,
  });

  IconData get icon {
    if (codigo.contains('GLUTEN')) return Icons.no_food_outlined;
    if (codigo.contains('LACTOSA')) return Icons.opacity_rounded;
    if (codigo.contains('DIABETES')) return Icons.monitor_heart_outlined;
    if (codigo.contains('FRUCTOSA')) return Icons.apple_rounded;
    if (codigo.contains('VEGETARIAN')) return Icons.eco_outlined;
    return Icons.health_and_safety_outlined;
  }

  Color get color {
    if (codigo.contains('GLUTEN')) return Colors.orange.shade800;
    if (codigo.contains('LACTOSA')) return Colors.red;
    if (codigo.contains('DIABETES')) return Colors.deepPurple;
    if (codigo.contains('FRUCTOSA')) return Colors.orange;
    if (codigo.contains('VEGETARIAN')) return Colors.green.shade700;
    return Colors.blueGrey;
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isFullWidth;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSummaryCard extends StatelessWidget {
  final String label;
  final List<String> items;
  final IconData icon;
  final Color iconColor;

  const _ListSummaryCard({
    required this.label,
    required this.items,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (items.isEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                'NINGUNA',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('- ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
