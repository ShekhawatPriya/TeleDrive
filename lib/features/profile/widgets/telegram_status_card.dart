import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class TelegramStatusCard extends StatelessWidget {
  const TelegramStatusCard({required this.connected, super.key});

  final bool? connected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isConnected = connected == true;
    final container = isConnected
        ? scheme.tertiaryContainer
        : scheme.errorContainer;
    final onContainer = isConnected
        ? scheme.onTertiaryContainer
        : scheme.onErrorContainer;
    final dotColor = isConnected ? scheme.tertiary : scheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(color: container, borderRadius: AppRadii.lgR),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: onContainer.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                isConnected
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: onContainer,
                size: 22,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isConnected
                          ? 'Telegram connected'
                          : 'Telegram not connected',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (isConnected)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? 'Storage is active.'
                      : 'Connect Telegram to upload and access files.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
