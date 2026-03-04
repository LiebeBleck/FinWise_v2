import 'package:flutter/material.dart';

/// Утилиты для адаптивного дизайна.
/// Breakpoint: <600dp = телефон, ≥600dp = планшет.
class ResponsiveHelper {
  static const double _tabletBreakpoint = 600.0;
  static const double maxContentWidth = 720.0;

  /// True если ширина экрана ≥ 600dp (планшет) или landscape на телефоне.
  static bool useNavigationRail(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    return size.width >= _tabletBreakpoint || isLandscape;
  }

  /// Оборачивает [child] в Center + ConstrainedBox(maxWidth: 720).
  static Widget constrain(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
