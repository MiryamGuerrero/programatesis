import "package:flutter/material.dart";

/// Controlador de scroll que intercepta los eventos de la rueda del mouse
/// y los anima con desaceleracion fluida (Smooth Scrolling), evitando saltos bruscos.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return SmoothScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
    );
  }
}

class SmoothScrollPosition extends ScrollPositionWithSingleContext {
  SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  double? _targetPixels;

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      goBallistic(0.0);
      return;
    }

    final double current = pixels;
    double start = _targetPixels ?? current;

    // Si la dirección se invierte repentinamente mientras se anima, partir de los píxeles actuales
    if ((delta > 0 && start < current) || (delta < 0 && start > current)) {
      start = current;
    }

    final double target = (start + delta).clamp(minScrollExtent, maxScrollExtent);
    _targetPixels = target;

    animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (_targetPixels == target) {
        _targetPixels = null;
      }
    }).catchError((_) {
      _targetPixels = null;
    });
  }
}
