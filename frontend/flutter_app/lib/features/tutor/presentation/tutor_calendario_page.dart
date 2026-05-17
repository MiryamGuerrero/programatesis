import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class TutorCalendarioPage extends StatefulWidget {
  const TutorCalendarioPage({super.key});

  @override
  State<TutorCalendarioPage> createState() => _TutorCalendarioPageState();
}

class _TutorCalendarioPageState extends State<TutorCalendarioPage> {
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final Color colorFondo = AppTema.grisFondo;
    final Color colorTitulo = const Color(0xFF1E293B);
    final Color colorSubtitulo = const Color(0xFF64748B);
    final Color colorAcento = AppTema.azulPrincipal;

    return Column(
      children: [
        // PANEL SUPERIOR: CUADRÍCULA DE CALENDARIO (Estilo MS Teams)
        _buildCalendarGrid(colorAcento, colorTitulo),
        
        // INDICADOR LINEAL (Drag Handle)
        Container(
          width: double.infinity,
          height: 24,
          decoration: BoxDecoration(
            color: colorFondo,
            border: const Border(
              top: BorderSide(color: Color(0xFFEEEEEE)),
              bottom: BorderSide(color: Color(0xFFEEEEEE)),
            ),
          ),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        
        // PANEL INFERIOR: LISTA DE AGENDA (Recetas)
        Expanded(
          child: Container(
            color: colorFondo,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 16),
                _buildAgendaHeader("16 may.", "Hoy"),
                _buildAgendaItem(
                  hora: "07:30",
                  duracion: "30 min",
                  titulo: "Huevos Revueltos con Espinaca",
                  subtitulo: "Desayuno · Plan Nutricionista",
                  colorBarra: AppTema.azulPrincipal,
                  colorTitulo: colorTitulo,
                  colorSubtitulo: colorSubtitulo,
                ),
                _buildAgendaItem(
                  hora: "10:00",
                  duracion: "15 min",
                  titulo: "Yogur con Nueces",
                  subtitulo: "Snack Mañana · Plan Sistema",
                  colorBarra: AppTema.verdeSalud,
                  colorTitulo: colorTitulo,
                  colorSubtitulo: colorSubtitulo,
                ),
                _buildAgendaItem(
                  hora: "13:30",
                  duracion: "45 min",
                  titulo: "Pechuga de Pollo a la Plancha",
                  subtitulo: "Almuerzo · Plan Nutricionista",
                  colorBarra: AppTema.azulPrincipal,
                  colorTitulo: colorTitulo,
                  colorSubtitulo: colorSubtitulo,
                ),
                const SizedBox(height: 16),
                _buildAgendaHeader("17 may.", "Mañana"),
                _buildAgendaItem(
                  hora: "08:00",
                  duracion: "30 min",
                  titulo: "Avena con Frutos Rojos",
                  subtitulo: "Desayuno · Plan Nutricionista",
                  colorBarra: AppTema.azulPrincipal,
                  colorTitulo: colorTitulo,
                  colorSubtitulo: colorSubtitulo,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(Color colorAcento, Color colorTitulo) {
    final diasSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: Column(
        children: [
          // Fila de Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: diasSemana.map((dia) => Container(
              width: 40,
              height: 30,
              alignment: Alignment.center,
              child: Text(
                dia,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Cuadrícula de Días (Ejemplo estático mes actual)
          _buildCalendarRow([27, 28, 29, 30, 1, 2, 3], colorAcento, colorTitulo, isCurrentMonth: [false, false, false, false, true, true, true]),
          _buildCalendarRow([4, 5, 6, 7, 8, 9, 10], colorAcento, colorTitulo),
          _buildCalendarRow([11, 12, 13, 14, 15, 16, 17], colorAcento, colorTitulo, selectedDay: 16),
          _buildCalendarRow([18, 19, 20, 21, 22, 23, 24], colorAcento, colorTitulo),
          _buildCalendarRow([25, 26, 27, 28, 29, 30, 31], colorAcento, colorTitulo),
        ],
      ),
    );
  }

  Widget _buildCalendarRow(List<int> dias, Color colorAcento, Color colorTitulo, {int? selectedDay, List<bool>? isCurrentMonth}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final dia = dias[index];
        final isSelected = dia == selectedDay;
        final currentMonth = isCurrentMonth == null || isCurrentMonth[index];
        
        return Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: isSelected ? BoxDecoration(
            color: colorAcento,
            shape: BoxShape.circle,
          ) : null,
          child: Text(
            dia.toString(),
            style: GoogleFonts.lato(
              fontSize: 14,
              color: isSelected ? Colors.white : (currentMonth ? colorTitulo : const Color(0xFFCBD5E1)),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAgendaHeader(String fecha, String diaSemana) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Text(
            fecha,
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            diaSemana,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaItem({
    required String hora,
    required String duracion,
    required String titulo,
    required String subtitulo,
    required Color colorBarra,
    required Color colorTitulo,
    required Color colorSubtitulo,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Columna de Tiempo
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hora,
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorTitulo,
                  ),
                ),
                Text(
                  duracion,
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    color: colorSubtitulo,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Separador Vertical
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: colorBarra,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Columna de Detalles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorTitulo,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: colorSubtitulo,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 18),
        ],
      ),
    );
  }
}
