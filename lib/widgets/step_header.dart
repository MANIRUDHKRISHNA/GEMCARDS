import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class StepHeader extends StatelessWidget {
  const StepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP $step OF 6',
          style: const TextStyle(
            color: AppTheme.accentDark,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
