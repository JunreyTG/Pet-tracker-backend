import 'package:flutter/widgets.dart';

class Breakpoints {
  static const mobile = 0.0;
  static const tablet = 600.0;
  static const desktop = 1024.0;
  static const largeDesktop = 1440.0;

  const Breakpoints._();
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isMobile => screenWidth < Breakpoints.tablet;
  bool get isTablet =>
      screenWidth >= Breakpoints.tablet && screenWidth < Breakpoints.desktop;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;
  bool get isLargeDesktop => screenWidth >= Breakpoints.largeDesktop;
}
