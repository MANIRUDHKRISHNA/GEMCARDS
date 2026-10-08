import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accentDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.border,
          disabledForegroundColor: AppTheme.ink.withValues(alpha: .55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
