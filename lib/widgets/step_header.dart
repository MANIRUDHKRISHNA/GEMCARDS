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
          '0$step / 06',
          style: const TextStyle(
            color: AppTheme.accentDark,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
        ),
      ],
    );
  }
}
