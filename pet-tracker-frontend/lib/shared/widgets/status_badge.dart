import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum StatusBadgeTone { neutral, success, warning, danger }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeTone tone;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusBadgeTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      StatusBadgeTone.success => AppColors.success,
      StatusBadgeTone.warning => AppColors.warning,
      StatusBadgeTone.danger => AppColors.danger,
      StatusBadgeTone.neutral => AppColors.mutedText,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
