import 'package:db_explorer_app/core/constants/app_constants.dart';
import 'package:db_explorer_app/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Genel "Coming in Phase N" placeholder paneli.
///
/// Adaptive home shell'deki tüm panel slotlarında kullanılır.
/// İçeriği: başlık + açıklayıcı metin + phase numarası chip'i.
class PlaceholderPanel extends StatelessWidget {
  const PlaceholderPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.phaseNumber,
    this.icon,
  });

  final String title;
  final String subtitle;
  final int phaseNumber;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = context.radius;
    final spacing = context.spacing;

    return Container(
      margin: EdgeInsets.all(spacing.s8),
      padding: EdgeInsets.all(spacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius.r16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                icon ?? Icons.construction_outlined,
                color: theme.colorScheme.primary,
                size: AppConstants.iconSize24,
              ),
              SizedBox(width: spacing.s8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.s8,
                  vertical: spacing.s2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(radius.r8),
                ),
                child: Text(
                  'Phase $phaseNumber',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.s8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }
}
