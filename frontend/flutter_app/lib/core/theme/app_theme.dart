import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTema {
  // COLORES CORPORATIVOS NUTRIREUMA (Alineados a Material 3)
  static const Color azulPrincipal = Color(0xFF0171BB);
  static const Color verdeSalud = Color(0xFF70A81C);
  static const Color azulOscuro = Color(0xFF005686);
  static const Color grisFondo = Color(0xFFF8FAFC);

  // PALETA DE APOYO Y COMPATIBILIDAD
  static const Color grisLienzo = Color(0xFFF8FAFC);
  static const Color pastelCeleste = Color(0xFFE0F2FE);
  static const Color cianLimpio = Color(0xFFCFFAFE);
  static const Color verdeLima = Color(0xFFD9F99D);
  static const Color naranjaAlerta = Color(0xFFF59E0B);
  static const Color superficieElevada = Colors.white;

  static ThemeData get light {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: azulPrincipal,
      primary: azulPrincipal,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD1E4FF),
      onPrimaryContainer: const Color(0xFF001D36),
      secondary: verdeSalud,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE8FFD0),
      onSecondaryContainer: const Color(0xFF1B3700),
      surface: grisLienzo,
      onSurface: const Color(0xFF1E293B),
      outline: const Color(0xFFCBD5E1),
    );

    final baseTextTheme = GoogleFonts.latoTextTheme();
    final headlineTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: grisLienzo,

      // TIPOGRAFÍA ESTÁNDAR M3
      textTheme: baseTextTheme.copyWith(
        displayLarge: headlineTheme.displayLarge,
        displayMedium: headlineTheme.displayMedium,
        displaySmall: headlineTheme.displaySmall,
        headlineLarge:
            headlineTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        headlineMedium:
            headlineTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        headlineSmall:
            headlineTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        titleLarge:
            headlineTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium:
            headlineTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall:
            headlineTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),

      // BOTONES ESTILO M3 (Pill-shaped)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: headlineTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: headlineTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: headlineTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold, fontSize: 16, color: azulPrincipal),
        ),
      ),

      // APPBAR M3 (Flat/Clean)
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: headlineTheme.titleLarge?.copyWith(
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF64748B)),
      ),

      // TARJETAS M3
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),

      // INPUTS M3
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28), // Altamente redondeado
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: azulPrincipal, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),

      // NAVIGATION BAR (Sustituye a BottomNavigationBar en M3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: azulPrincipal.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return headlineTheme.labelMedium
                ?.copyWith(color: azulPrincipal, fontWeight: FontWeight.bold);
          }
          return headlineTheme.labelMedium
              ?.copyWith(color: const Color(0xFF64748B));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: azulPrincipal);
          }
          return const IconThemeData(color: Color(0xFF94A3B8));
        }),
      ),

      // CHIPS M3
      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: colorScheme.outline)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: headlineTheme.labelSmall,
      ),
    );
  }
}
