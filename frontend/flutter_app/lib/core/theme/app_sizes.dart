import 'dart:math';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppTextSizes {
  /// 10 - 12
  static double caption(double width) => _clamp(width, 10, 12);
  
  /// 12 - 14
  static double bodySmall(double width) => _clamp(width, 12, 14);
  
  /// 14 - 16
  static double body(double width) => _clamp(width, 14, 16);
  
  /// 16 - 18
  static double bodyLarge(double width) => _clamp(width, 16, 18);
  
  /// 18 - 22
  static double title(double width) => _clamp(width, 18, 22);
  
  /// 22 - 32
  static double headline(double width) => _clamp(width, 22, 32);
  
  /// 32 - 48
  static double display(double width) => _clamp(width, 32, 48);

  static double _clamp(double width, double minSize, double maxSize) {
    // Escala base: 375px (iPhone estándar)
    double scale = width / 375.0;
    return max(minSize, min(maxSize, minSize * scale));
  }
}

class AppSizes {
  static const double buttonHeight = 48.0;
  static const double buttonHeightLarge = 56.0;
  static const double inputHeight = 52.0;
  static const double cardRadius = 16.0;
  static const double buttonRadius = 28.0;
  static const double inputRadius = 28.0;
  static const double iconSm = 18.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  
  /// Ancho máximo para el contenido en tablets/desktop para evitar que se vea muy estirado
  static const double maxContentWidth = 1200.0;
  static const double maxFormWidth = 500.0;
}
