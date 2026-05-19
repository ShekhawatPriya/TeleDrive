import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../upload_controller.dart';
import '../upload_status_label.dart';
import 'upload_progress_bar.dart';
import 'upload_thumb_slot.dart';

/// One persistent card per file for the entire duration of an upload.
///
/// Cards never overlap, never collapse into each other, never cycle.  The
/// active uploading file is distinguished by a breathing primary border.
/// Queued files are slightly muted but fully legible.
class UploadCard extends StatefulWidget {
  const UploadCard({required this.item, super.key});
  final UploadItem item;

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncBreathing();
  }

  @override
  void didUpdateWidget(covariant UploadCard old) {
    super.didUpdateWidget(old);
    _syncBreathing();
  }

  void _syncBreathing() {
    if (uploadIsActive(widget.item.status)) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;

    final isQueued =
        item.status == UploadStatus.selected ||
        item.status == UploadStatus.queued;
    final isUploaded = item.status == UploadStatus.uploaded;
    final isFailed = item.status == UploadStatus.failed;

    final baseBorder = scheme.outline;
    final accent = scheme.primary;

    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final tint = uploadIsActive(item.status)
            ? Color.lerp(
                baseBorder,
                accent.withValues(alpha: .55),
                _breath.value,
              )
            : baseBorder;
        return Opacity(
          opacity: isQueued ? 0.62 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: (tint ?? baseBorder).withValues(alpha: .86),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    UploadThumbSlot(item: item),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _StatusLine(item: item),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatFileSize(item.size),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withValues(alpha: .55),
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: isUploaded
                      ? _UploadedStrip(
                          key: const ValueKey('done'),
                          accent: accent,
                        )
                      : isFailed
                      ? const SizedBox(key: ValueKey('failed'), height: 4)
                      : UploadProgressBar(
                          key: const ValueKey('bar'),
                          value: item.progress,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.item});
  final UploadItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: .65);
    final label = uploadStatusLabel(item.status);
    final hasError = item.status == UploadStatus.failed && item.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: hasError ? scheme.error : muted,
            height: 1.2,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              item.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.error.withValues(alpha: .85),
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

class _UploadedStrip extends StatelessWidget {
  const _UploadedStrip({required this.accent, super.key});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_rounded, size: 14, color: accent),
        const SizedBox(width: 6),
        Text(
          'Done',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: accent,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
