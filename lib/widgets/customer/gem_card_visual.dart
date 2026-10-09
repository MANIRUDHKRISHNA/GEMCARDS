import 'package:flutter/material.dart' hide Card;

import '../../core/theme/app_theme.dart';
import '../../models/product_models.dart';

class GemCardVisual extends StatelessWidget {
  const GemCardVisual({
    required this.card,
    required this.frozen,
    this.compact = false,
    super.key,
  });
  final Card card;
  final bool frozen;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(compact ? 18 : 22),
    decoration: BoxDecoration(
      color: frozen ? AppTheme.muted : AppTheme.accentDark,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'GEMCARDS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Icon(
              frozen ? Icons.ac_unit_rounded : Icons.contactless_rounded,
              color: Colors.white70,
            ),
          ],
        ),
        SizedBox(height: compact ? 22 : 34),
        Text(
          '••••  ••••  ••••  ${card.lastFour}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                card.type.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              card.status.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
