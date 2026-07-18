import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/widgets/layout_components.dart";
import "../data/supervision_provider.dart";

class PatientDetailModal extends ConsumerWidget {
  final String idPaciente;

  const PatientDetailModal({super.key, required this.idPaciente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expedienteAsync =
        ref.watch(medicoPatientExpedienteProvider(idPaciente));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: expedienteAsync.when(
                data: (data) => _buildContent(context, data),
                loading: () => const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: NutriLoading(mensaje: "Cargando expediente..."),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text("Error al cargar datos",
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(err.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        color: AppTema.azulPrincipal,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Text(
            "Información del paciente",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final paciente = data['paciente'] ?? {};
    final tutor = data['tutor'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
              Icons.person_outline_rounded, "Datos del paciente"),
          _buildInfoGrid([
            _InfoItem(
                label: "Nombre completo", value: paciente['nombre_completo']),
            _InfoItem(label: "Cédula", value: paciente['cedula']),
            _InfoItem(
                label: "Fecha de nacimiento", value: paciente['fecha_nacimiento']),
            _InfoItem(label: "Género", value: paciente['sexo_nombre']),
            _InfoItem(
                label: "Provincia/Cantón",
                value:
                    "${paciente['canton_nombre'] ?? '-'} / ${paciente['parroquia_nombre'] ?? '-'}"),
            _InfoItem(
                label: "Enfermedad",
                value: paciente['enfermedad_principal'],
                isHighlight: true),
          ]),
          const Divider(height: 40),
          _buildSectionTitle(
              Icons.supervised_user_circle_outlined, "Datos del tutor a cargo"),
          _buildInfoGrid([
            _InfoItem(
                label: "Nombre del tutor", value: tutor['nombre_completo']),
            _InfoItem(
                label: "Parentesco",
                value: tutor['parentesco_nombre'],
                isHighlight: true),
            _InfoItem(label: "Cédula del tutor", value: tutor['cedula']),
            _InfoItem(label: "Teléfono", value: tutor['telefono']),
            _InfoItem(label: "Correo electrónico", value: tutor['email']),
            _InfoItem(
                label: "Dirección domiciliaria", value: tutor['direccion']),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTema.azulOscuro),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTema.azulOscuro,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: items
            .map((item) => SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.value?.toString() ?? "No registrado",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: item.isHighlight
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: item.isHighlight
                              ? AppTema.verdeSalud
                              : Colors.blueGrey.shade800,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cerrar",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final dynamic value;
  final bool isHighlight;

  _InfoItem(
      {required this.label, required this.value, this.isHighlight = false});
}
