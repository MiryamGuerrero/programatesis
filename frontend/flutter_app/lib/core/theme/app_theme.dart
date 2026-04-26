import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTema {
  // COLORES CORPORATIVOS NUTRIREUMA (Estrictos)
  static const Color azulPrincipal = Color(0xFF0171BB);
  static const Color verdeSalud = Color(0xFF70A81C);
  static const Color azulOscuro = Color(0xFF005686);
  
  // ALIAS DE COMPATIBILIDAD (Alineados a la paleta)
  static const Color azulClinico = azulPrincipal;
  static const Color rojoProhibido = verdeSalud; // Cambiado a Verde Salud por identidad
  static const Color grisFondo = Color(0xFFF8FAFC);
  
  // COLORES DE APOYO
  static const Color grisLienzo = Color(0xFFF8FAFC);
  static const Color pastelCeleste = Color(0xFFE0F2FE);
  static const Color cianLimpio = Color(0xFFCFFAFE);
  static const Color verdeLima = Color(0xFFD9F99D);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: azulPrincipal,
        primary: azulPrincipal,
        secondary: verdeSalud,
        tertiary: azulOscuro,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: grisLienzo,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: azulPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: azulPrincipal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    );
  }
}
