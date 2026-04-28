import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class NutriAvatar extends StatelessWidget {
  final String nombreCompleto;
  final double radio;
  final Color? colorFondo;
  final Color? colorTexto;

  const NutriAvatar({
    super.key,
    required this.nombreCompleto,
    this.radio = 20,
    this.colorFondo,
    this.colorTexto,
  });

  String _obtenerIniciales(String nombre) {
    if (nombre.isEmpty) return "?";
    List<String> partes = nombre.trim().split(RegExp(r'\s+'));
    
    // Regla: Primera letra del primer nombre + Primera letra del primer apellido
    if (partes.length >= 2) {
      return (partes[0][0] + partes[1][0]).toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: colorFondo ?? AppTema.azulPrincipal.withOpacity(0.1),
      child: Text(
        _obtenerIniciales(nombreCompleto),
        style: GoogleFonts.montserrat(
          fontSize: radio * 0.8,
          fontWeight: FontWeight.bold,
          color: colorTexto ?? AppTema.azulPrincipal,
        ),
      ),
    );
  }
}
