import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/adaptive_surface.dart';
import '../../upload_models.dart';
import '../upload_summary_presentation.dart';

/// A single accessible target for reopening the transfer list.
class UploadCollapsedBar extends StatelessWidget {
  const UploadCollapsedBar({
    required this.summary,
    required this.onTap,
    super.key,
  });

  final UploadSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (summary.progressing)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: summary.overallProgress.clamp(0, 1),
                      strokeWidth: 2.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.outlineVariant,
                      color: scheme.primary,
                    ),
                  ),
                Icon(
                  summary.complete
                      ? (ios ? CupertinoIcons.check_mark : Icons.check_rounded)
                      : summary.waitingForWifi
                      ? (ios ? CupertinoIcons.wifi : Icons.wifi_rounded)
                      : summary.needsAttention
                      ? (ios
                            ? CupertinoIcons.exclamationmark_circle
                            : Icons.error_outline)
                      : (ios
                            ? CupertinoIcons.arrow_up
                            : Icons.arrow_upward_rounded),
                  size: summary.progressing ? 16 : 24,
                  color: summary.needsAttention ? scheme.error : scheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.statusTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  summary.stillGeneratingThumbs
                      ? 'Finishing previews…'
                      : summary.countLabel,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            ios ? CupertinoIcons.chevron_up : Icons.keyboard_arrow_up_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      onTap: onTap,
      label:
          '${summary.statusTitle}. ${summary.countLabel}. '
          '${summary.detailLabel}. Show upload details',
      excludeSemantics: true,
      child: ios
          ? AdaptiveSurface(
              radius: AppRadii.xl,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onTap,
                child: content,
              ),
            )
          : Material(
              color: scheme.surfaceContainer,
              surfaceTintColor: Colors.transparent,
              elevation: AppElevation.level2,
              borderRadius: AppRadii.xlR,
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}
