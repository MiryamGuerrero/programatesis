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
  static const Color naranjaAlerta = Color(0xFFF59E0B);

  static ThemeData get light {
    final baseTextTheme = GoogleFonts.latoTextTheme();
    final headlineTheme = GoogleFonts.montserratTextTheme();

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
      textTheme: baseTextTheme.copyWith(
        displayLarge: headlineTheme.displayLarge,
        displayMedium: headlineTheme.displayMedium,
        displaySmall: headlineTheme.displaySmall,
        headlineLarge: headlineTheme.headlineLarge,
        headlineMedium: headlineTheme.headlineMedium,
        headlineSmall: headlineTheme.headlineSmall,
        titleLarge: headlineTheme.titleLarge,
        titleMedium: headlineTheme.titleMedium,
        titleSmall: headlineTheme.titleSmall,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: azulPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: azulPrincipal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: azulPrincipal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        headingTextStyle: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: const Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
        dataTextStyle: GoogleFonts.lato(
          fontSize: 13,
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.w500,
        ),
        horizontalMargin: 20,
        columnSpacing: 20,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        headingRowHeight: 44,
        dividerThickness: 1,
      ),
    );
  }
}
