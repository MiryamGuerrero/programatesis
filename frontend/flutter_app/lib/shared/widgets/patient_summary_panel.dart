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
    final restriccionesDetalle = (expediente['restricciones_alimentarias_detalle'] as List? ?? []);
    
    // Configuración de Restricciones Especiales
    final configRestricciones = [
      _ConfigRestriccion(
        codigo: 'INTOLERANCIA_LACTOSA',
        label: 'INTOLERANTE A LACTOSA',
        subtitulo: 'RESTRICCIÓN LÁCTEOS',
        icon: Icons.opacity_rounded,
        color: Colors.red,
        keywords: ['leche', 'lacteo', 'lácteo', 'queso', 'mantequilla', 'yogur', 'crema'],
        isActive: (expediente['es_intolerante_lactosa'] == true) || 
                  restriccionesDetalle.any((r) => r['codigo'] == 'INTOLERANCIA_LACTOSA'),
      ),
      _ConfigRestriccion(
        codigo: 'ALERGIA_GLUTEN',
        label: 'INTOLERANTE AL GLUTEN',
        subtitulo: 'RESTRICCIÓN TRIGO/CEBADA',
        icon: Icons.no_food_outlined,
        color: Colors.orange.shade800,
        keywords: ['gluten', 'trigo', 'cebada', 'centeno', 'avena', 'harina', 'pan', 'pasta', 'galleta', 'cuscus', 'cuscús'],
        isActive: restriccionesDetalle.any((r) => r['codigo'] == 'ALERGIA_GLUTEN' || r['codigo'] == 'CELIAQUIA'),
      ),
      _ConfigRestriccion(
        codigo: 'DIABETES',
        label: 'DIABETES DETECTADA',
        subtitulo: 'RESTRICCIÓN AZÚCAR',
        icon: Icons.monitor_heart_outlined,
        color: Colors.deepPurple,
        keywords: ['azucar', 'azúcar', 'dulce', 'miel', 'panela', 'caramelo', 'gaseosa', 'refresco', 'mermelada'],
        isActive: restriccionesDetalle.any((r) => r['codigo'] == 'DIABETES'),
      ),
      _ConfigRestriccion(
        codigo: 'INTOLERANCIA_FRUCTOSA',
        label: 'INTOLERANTE A FRUCTOSA',
        subtitulo: 'RESTRICCIÓN FRUTAS ALTAS',
        icon: Icons.apple_rounded,
        color: Colors.orange,
        keywords: ['fructosa', 'manzana', 'pera', 'mango', 'sandia', 'sandía', 'uva', 'higo', 'datil', 'dátil'],
        isActive: restriccionesDetalle.any((r) => r['codigo'] == 'INTOLERANCIA_FRUCTOSA'),
      ),
      _ConfigRestriccion(
        codigo: 'INTOLERANCIA_HISTAMINA',
        label: 'INTOLERANTE A HISTAMINA',
        subtitulo: 'RESTRICCIÓN FERMENTADOS',
        icon: Icons.science_outlined,
        color: Colors.brown,
        keywords: ['histamina', 'embutido', 'fermentado', 'queso curado', 'vinagre', 'atun', 'atún', 'vino'],
        isActive: restriccionesDetalle.any((r) => r['codigo'] == 'INTOLERANCIA_HISTAMINA'),
      ),
      _ConfigRestriccion(
        codigo: 'ALERGIA_HUEVO',
        label: 'ALERGIA AL HUEVO',
        subtitulo: 'RESTRICCIÓN HUEVO/DERIVADOS',
        icon: Icons.egg_outlined,
        color: Colors.amber.shade900,
        keywords: ['huevo', 'yema', 'clara', 'merengue', 'mayonesa'],
        isActive: restriccionesDetalle.any((r) => r['codigo'] == 'ALERGIA_HUEVO'),
      ),
      _ConfigRestriccion(
        codigo: 'ALERGIA_SOJA',
        label: 'ALERGIA A LA SOJA',
        subtitulo: 'RESTRICCIÓN SOYA/TOFU',
        icon: Icons.grass_outlined,
        color: Colors.green.shade900,
        keywords: ['soja', 'soya', 'tofu', 'tempeh', 'lecitina'],
        isActive: restriccionesDetalle.any((r) => r['codigo'] == 'ALERGIA_SOJA'),
      ),
      _ConfigRestriccion(
        codigo: 'ALERGIA_FRUTOS_SECOS',
        label: 'ALERGIA FRUTOS SECOS',
        subtitulo: 'RESTRICCIÓN MANÍ/NUECES',
        icon: Icons.park_outlined,
        color: Colors.brown.shade700,
        keywords: ['mani', 'maní', 'nuez', 'almendra', 'avellana', 'pistacho', 'anacardo', 'frutos secos'],
        isActive: restriccionesDetalle.any((r) => r['codigo'] == 'ALERGIA_FRUTOS_SECOS'),
      ),
      _ConfigRestriccion(
        codigo: 'ALERGIA_PESCADO_MARISCOS',
        label: 'ALERGIA PESCADO/MARISCO',
        subtitulo: 'RESTRICCIÓN MARINOS',
        icon: Icons.set_meal_outlined,
        color: Colors.blue.shade700,
        keywords: ['pescado', 'marisco', 'camaron', 'camarón', 'atun', 'atún', 'pulpo', 'calamar', 'crustaceo', 'crustáceo', 'molusco'],
        isActive: restriccionesDetalle.any((r) => r['codigo'] == 'ALERGIA_PESCADO_MARISCOS'),
      ),
    ];

    final restriccionesActivas = configRestricciones.where((c) => c.isActive).toList();
    final allKeywords = restriccionesActivas.expand((c) => c.keywords).toList();

    // Filtrar subgrupos e ingredientes que ya están cubiertos por las restricciones activas
    bool isRedundant(String name) {
      final n = name.toLowerCase();
      return allKeywords.any((k) => n.contains(k.toLowerCase()));
    }

    final subgrupos = (al['subgrupos'] as List? ?? [])
        .map((e) => e['nombre'].toString())
        .where((name) => !isRedundant(name))
        .toList();

    final ingredientes = (al['ingredientes'] as List? ?? [])
        .map((e) => e['nombre'].toString())
        .where((name) => !isRedundant(name))
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
                    "RESUMEN CLÍNICO",
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      color: AppTema.verdeSalud,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  NutriAvatar(
                    nombreCompleto: p['nombre_completo'] ?? "P",
                    radio: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    p['nombre_completo'] ?? "-",
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
                  
                  // Fila de Peso y Talla
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: "PESO ACTUAL",
                          value: "${c['peso_kg'] ?? '-'} kg",
                          icon: Icons.scale_outlined,
                          iconColor: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: "TALLA ACTUAL",
                          value: "${c['talla_cm'] ?? '-'} cm",
                          icon: Icons.straighten_rounded,
                          iconColor: AppTema.verdeSalud,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  _SummaryCard(
                    label: "ESTADO NUTRICIONAL",
                    value: c['estado_nutricional'] ?? "PENDIENTE",
                    icon: Icons.analytics_outlined,
                    iconColor: AppTema.verdeSalud,
                    isFullWidth: true,
                  ),
                  const SizedBox(height: 12),
                  
                  _SummaryCard(
                    label: "ENFERMEDAD PRINCIPAL",
                    value: d['condicion_nombre'] ?? d['nombre_condicion'] ?? "-",
                    icon: Icons.medical_services_outlined,
                    iconColor: AppTema.azulPrincipal,
                    isFullWidth: true,
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(),
                  ),

                  // INTOLERANCIAS Y CONDICIONES (Solo si existen)
                  ...restriccionesActivas.map((res) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SummaryCard(
                      label: res.label,
                      value: "SÍ (${res.subtitulo})",
                      icon: res.icon,
                      iconColor: res.color,
                      isFullWidth: true,
                    ),
                  )),

                  // Mostrar otras restricciones que no estén en el mapeo principal
                  ...restriccionesDetalle.where((r) {
                    final cod = r['codigo'].toString();
                    return !configRestricciones.any((c) => c.codigo == cod || (cod == 'CELIAQUIA' && c.codigo == 'ALERGIA_GLUTEN'));
                  }).map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SummaryCard(
                      label: "RESTRICCIÓN CLÍNICA",
                      value: r['nombre']?.toString().toUpperCase() ?? r['codigo']?.toString() ?? "-",
                      icon: Icons.health_and_safety_outlined,
                      iconColor: Colors.blueGrey,
                      isFullWidth: true,
                    ),
                  )),
                  
                  if (subgrupos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ListSummaryCard(
                      label: "ALERGIAS (SUBGRUPOS)",
                      items: subgrupos,
                      icon: Icons.warning_amber_rounded,
                      iconColor: Colors.orange,
                    ),
                  ],

                  if (ingredientes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ListSummaryCard(
                      label: "ALERGIAS (ESPECÍFICAS)",
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
                label: const Text("VER EXPEDIENTE MAESTRO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTema.verdeSalud,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigRestriccion {
  final String codigo;
  final String label;
  final String subtitulo;
  final IconData icon;
  final Color color;
  final List<String> keywords;
  final bool isActive;

  _ConfigRestriccion({
    required this.codigo,
    required this.label,
    required this.subtitulo,
    required this.icon,
    required this.color,
    required this.keywords,
    required this.isActive,
  });
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
                "NINGUNA",
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
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
            )),
          ],
        ],
      ),
    );
  }
}
