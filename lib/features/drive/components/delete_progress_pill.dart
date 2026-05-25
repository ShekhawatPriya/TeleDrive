import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../drive_controller.dart';

/// Floating pill that surfaces deletion progress alongside the upload pill in
/// the [BottomActionSystem]. Watches `state.deleteProgress` and renders nothing
/// while no delete is in flight.
class DeleteProgressPill extends ConsumerWidget {
  const DeleteProgressPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(driveControllerProvider).state.deleteProgress;
    if (progress == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = progress.total;
    final completed = progress.completed;
    final failed = progress.failed;
    final done = completed >= total;
    final hasFailures = failed > 0;
    final value = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

    final iconColor = hasFailures
        ? scheme.onErrorContainer
        : done
        ? scheme.onPrimaryContainer
        : scheme.onErrorContainer;
    final iconBg = hasFailures
        ? scheme.errorContainer
        : done
        ? scheme.primaryContainer
        : scheme.errorContainer;
    final IconData iconData = hasFailures
        ? Icons.error_outline_rounded
        : done
        ? Icons.check_rounded
        : Icons.delete_outline_rounded;

    final remaining = total - completed;
    final String title;
    if (done && hasFailures) {
      title = 'Could not delete $failed of $total';
    } else if (done) {
      title = '$total ${total == 1 ? 'item' : 'items'} deleted';
    } else {
      title = 'Deleting $remaining ${remaining == 1 ? 'item' : 'items'}…';
    }
    final subtitle = '$completed of $total';

    final progressColor = hasFailures ? scheme.error : scheme.primary;

    return Material(
      color: scheme.surfaceContainer,
      surfaceTintColor: scheme.surfaceTint,
      shadowColor: scheme.shadow,
      elevation: AppElevation.level3,
      borderRadius: AppRadii.lgR,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(iconData, size: 20, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
