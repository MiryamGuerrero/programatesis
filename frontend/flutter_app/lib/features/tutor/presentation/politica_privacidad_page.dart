import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class PoliticaPrivacidadPage extends StatelessWidget {
  const PoliticaPrivacidadPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Política de Privacidad",
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTema.azulOscuro,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTema.azulOscuro),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded,
                      color: AppTema.verdeSalud, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Proyecto de Tesis e Investigación",
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF14532D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Esta aplicación NO comercializa datos ni los comparte con terceros.",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              number: "1",
              title: "Naturaleza del Proyecto",
              content:
                  "NutriReuma es una plataforma de soporte nutricional clínico para pacientes pediátricos en el área de reumatología. Su desarrollo forma parte de un proyecto de titulación universitaria e investigación académica.",
            ),
            _buildSection(
              number: "2",
              title: "Uso de la Información",
              content:
                  "Los datos ingresados (como edad, peso, talla y gustos alimentarios) son procesados exclusivamente para calcular índices antropométricos de la OMS y ofrecer recomendaciones nutricionales dentro de la app.",
            ),
            _buildSection(
              number: "3",
              title: "No Compartición con Terceros",
              content:
                  "Garantizamos que la información NO es vendida, cedida ni compartida con empresas externas, redes publicitarias ni entidades financieras.",
            ),
            _buildSection(
              number: "4",
              title: "Seguridad de Datos",
              content:
                  "Toda la comunicación con el servidor viaja encriptada vía HTTPS/TLS. El acceso a los datos de los pacientes está restringido por políticas de seguridad por rol (RLS).",
            ),
            _buildSection(
              number: "5",
              title: "Derechos del Usuario",
              content:
                  "Puede solicitar la actualización o eliminación de su cuenta y datos asociados en cualquier momento contactando al equipo de investigación.",
            ),
            _buildSection(
              number: "6",
              title: "Contacto",
              content:
                  "Para dudas o solicitudes sobre la privacidad de sus datos:\nCorreo de soporte: soporte.nutrireuma@gmail.com",
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                "© 2026 NutriReuma • Todos los derechos reservados",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTema.azulPrincipal,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTema.azulOscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
