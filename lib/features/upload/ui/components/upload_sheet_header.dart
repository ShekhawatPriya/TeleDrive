import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/file_type_detector.dart';
import '../../upload_models.dart';
import '../upload_summary_presentation.dart';
import 'upload_progress_bar.dart';
import 'upload_status_ring.dart';

class UploadSheetHeader extends StatelessWidget {
  const UploadSheetHeader({
    required this.summary,
    this.onMinimize,
    this.onRetry,
    this.onUseMobileData,
    super.key,
  });
  final UploadSummary summary;

  /// iOS only: the panel's own actions live in its summary card.
  final VoidCallback? onMinimize;
  final VoidCallback? onRetry;
  final VoidCallback? onUseMobileData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (theme.platform == TargetPlatform.iOS) {
      return _IosUploadSummary(
        summary: summary,
        onMinimize: onMinimize,
        onRetry: onRetry,
        onUseMobileData: onUseMobileData,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uploads', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            summary.statusTitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: summary.needsAttention ? scheme.error : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(summary.detailLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          UploadProgressBar(value: summary.overallProgress),
          const SizedBox(height: 8),
          Text(summary.countLabel, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// iOS panel header: a centered title with a minimize control, then one
/// inset summary card in the Live Activity's language — ring, title and
/// count, a large trailing figure, a tinted bar, and the single action the
/// session needs (retry or mobile data).
class _IosUploadSummary extends StatelessWidget {
  const _IosUploadSummary({
    required this.summary,
    this.onMinimize,
    this.onRetry,
    this.onUseMobileData,
  });

  final UploadSummary summary;
  final VoidCallback? onMinimize;
  final VoidCallback? onRetry;
  final VoidCallback? onUseMobileData;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = iosUploadPanelColors(scheme);
    final tint = uploadSummaryTint(context, summary);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final figure = _figure(summary);
    final figureText = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: figure.value,
            style: const TextStyle(fontSize: 28, letterSpacing: -0.6),
          ),
          if (figure.unit.isNotEmpty)
            TextSpan(
              text: ' ${figure.unit}',
              style: const TextStyle(fontSize: 15, letterSpacing: -0.2),
            ),
        ],
      ),
      maxLines: 1,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: tint,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          summary.capsuleTitle,
          style: TextStyle(
            fontSize: 20,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.45,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _detail(summary),
          style: TextStyle(
            fontSize: 15,
            height: 1.25,
            letterSpacing: -0.2,
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    final ring = UploadStatusRing(
      tint: tint,
      icon: uploadSummaryIcon(summary),
      progress: summary.progressing ? summary.overallProgress : null,
      size: 56,
      stroke: 4,
      iconSize: 23,
    );

    // Waiting and failed files can coexist; each gets its own action.
    final actions = [
      if (summary.waitingForWifi && onUseMobileData != null)
        (
          'Use Mobile Data',
          CupertinoIcons.antenna_radiowaves_left_right,
          onUseMobileData!,
          CupertinoDynamicColor.resolve(CupertinoColors.systemBlue, context),
        ),
      if (summary.failedCount > 0 && onRetry != null)
        (
          'Retry Failed',
          CupertinoIcons.arrow_clockwise,
          onRetry!,
          CupertinoDynamicColor.resolve(
            summary.uploadedCount > 0
                ? CupertinoColors.systemOrange
                : CupertinoColors.systemRed,
            context,
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  'Uploads',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
                if (onMinimize != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      // The drag handle carries "Minimize uploads".
                      label: 'Minimize',
                      button: true,
                      excludeSemantics: true,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(44),
                        onPressed: onMinimize,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.onSurface.withValues(alpha: .08),
                          ),
                          child: Icon(
                            CupertinoIcons.chevron_down,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            key: const ValueKey('upload-summary-card'),
            decoration: ShapeDecoration(
              color: colors.card,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (large) ...[
                    // Accessibility sizes stack, so words keep full width.
                    Row(children: [ring, const Spacer(), figureText]),
                    const SizedBox(height: 12),
                    title,
                  ] else
                    Row(
                      children: [
                        ring,
                        const SizedBox(width: 14),
                        Expanded(child: title),
                        const SizedBox(width: 10),
                        figureText,
                      ],
                    ),
                  const SizedBox(height: 16),
                  UploadTintBar(
                    value: summary.complete
                        ? 1
                        : summary.needsAttention && summary.itemCount > 0
                        ? summary.uploadedCount / summary.itemCount
                        : summary.overallProgress,
                    tint: tint,
                  ),
                  for (final action in actions) ...[
                    SizedBox(height: action == actions.first ? 16 : 10),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      minimumSize: const Size.fromHeight(48),
                      color: action.$4.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(24),
                      onPressed: action.$3,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(action.$2, size: 18, color: action.$4),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              action.$1,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                                color: action.$4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Running: percentage. Settled: size saved, or how many need attention.
  static ({String value, String unit}) _figure(UploadSummary summary) {
    if (summary.complete) {
      final text = formatFileSize(summary.totalBytes);
      final split = text.lastIndexOf(' ');
      return split < 0
          ? (value: text, unit: '')
          : (value: text.substring(0, split), unit: text.substring(split + 1));
    }
    if (summary.needsAttention) {
      return (value: '${summary.failedCount}', unit: 'failed');
    }
    if (summary.waitingForWifi) return (value: '', unit: '');
    final percent = (summary.overallProgress.clamp(0, 1) * 100).floor();
    return (value: '$percent%', unit: '');
  }

  static String _detail(UploadSummary summary) {
    if (summary.stillGeneratingThumbs) return 'Finishing previews…';
    if (summary.waitingForWifi) return 'Uploads resume on Wi-Fi';
    if (summary.progressing) {
      return '${summary.countLabel} · ${formatFileSize(summary.totalBytes)}';
    }
    return summary.countLabel;
  }
}
