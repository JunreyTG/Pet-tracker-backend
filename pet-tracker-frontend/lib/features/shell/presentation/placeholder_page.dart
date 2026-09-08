import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';

class PlaceholderRoutePage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Widget> actions;

  const PlaceholderRoutePage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.isLargeDesktop ? 1180 : 960,
          ),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (actions.isEmpty)
                    const StatusBadge(label: 'Phase B foundation')
                  else
                    ...actions,
                ],
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
