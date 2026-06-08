import 'package:flutter/material.dart';
import 'app_breakpoints.dart';
import 'app_sizes.dart';

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isMobileSmall => screenWidth <= AppBreakpoints.mobileSmall;
  bool get isMobile => screenWidth <= AppBreakpoints.mobile;
  bool get isTablet =>
      screenWidth > AppBreakpoints.mobile &&
      screenWidth <= AppBreakpoints.desktop;
  bool get isDesktop => screenWidth > AppBreakpoints.desktop;

  /// Retorna un valor basado en el tipo de dispositivo
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Calcula un espaciado adaptable con límites
  double responsiveSpacing(double minSpacing, {double? maxSpacing}) {
    double factor = screenWidth / 375.0; // Base iPhone
    double calculated = minSpacing * factor;
    if (maxSpacing != null) {
      return calculated.clamp(minSpacing, maxSpacing);
    }
    return calculated.clamp(minSpacing, minSpacing * 2);
  }

  /// Estilo de texto adaptable simplificado
  double get bodySize => AppTextSizes.body(screenWidth);
  double get titleSize => AppTextSizes.title(screenWidth);
  double get headlineSize => AppTextSizes.headline(screenWidth);
}

/// Widget utilitario para limitar el ancho máximo en pantallas grandes
class ResponsiveMaxConstraints extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool center;

  const ResponsiveMaxConstraints({
    super.key,
    required this.child,
    this.maxWidth = AppSizes.maxContentWidth,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (center) {
      return Center(child: content);
    }
    return content;
  }
}
