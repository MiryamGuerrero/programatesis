import "package:flutter/material.dart";

class AppTema {
  // 🎨 COLORES CORPORATIVOS OFICIALES (FUERZA)
  static const Color azulPrincipal = Color(0xFF156082); 
  static const Color verdeSalud = Color(0xFF71A323);    
  static const Color cianLimpio = Color(0xFFCEEDF4);    
  static const Color grisLienzo = Color(0xFFF6F6F6);    
  static const Color verdeLima = Color(0xFFC8DF9F);     
  static const Color blanco = Colors.white;

  // 🌿 COLORES NUEVOS SOLICITADOS
  static const Color verdeMenta = Color(0xFFE0F2F1); // Un menta muy suave para fondos
  static const Color mentaFuerte = Color(0xFF4DB6AC); // Un menta más fuerte para acentos
  static const Color pastelCeleste = Color(0xFFE3F2FD); // Pastel para encabezados
  static const Color pastelRosado = Color(0xFFFCE4EC); // Pastel opcional
  static const Color pastelVerde = Color(0xFFF1F8E9); // Pastel opcional

  // 🔄 ALIASES PARA EL DISEÑO PREMIUM (COMPATIBILIDAD)
  static const Color pizarra = azulPrincipal;
  static const Color crema = grisLienzo;
  static const Color arena = cianLimpio;
  static const Color salvia = verdeLima;
  static const Color terracota = Color(0xFFD67D61); // Mantenemos un terracota suave para alertas/suspensiones
  static const Color rojoProhibido = Color(0xFFD32F2F);
  static const Color naranjaAlerta = Color(0xFFF57C00);

  // ALIASES ANTIGUOS
  static const Color azulEmpresa = azulPrincipal;
  static const Color azulClinico = azulPrincipal;
  static const Color verdeEmpresa = verdeSalud;
  static const Color verdeClaro = verdeLima;
  static const Color grisFondo = grisLienzo;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: grisLienzo,
      colorScheme: ColorScheme.fromSeed(
        seedColor: azulPrincipal,
        primary: azulPrincipal,
        secondary: verdeSalud,
        surface: blanco,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: arena),
        ),
        color: blanco,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: azulPrincipal, fontWeight: FontWeight.w900, fontSize: 26),
        titleMedium: TextStyle(color: Color(0xFF37474F), fontWeight: FontWeight.bold, fontSize: 16),
        bodyMedium: TextStyle(color: Color(0xFF546E7A), fontWeight: FontWeight.w400, fontSize: 14),
      ),
    );
  }
}
