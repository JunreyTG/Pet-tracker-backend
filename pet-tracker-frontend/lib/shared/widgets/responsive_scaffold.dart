import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';

class ResponsiveScaffold extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveScaffold({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) return desktop;
    if (context.isTablet) return tablet ?? mobile;
    return mobile;
  }
}
