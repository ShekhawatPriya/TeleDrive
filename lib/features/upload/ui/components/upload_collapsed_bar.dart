import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../upload_controller.dart';
import 'upload_progress_bar.dart';

/// Premium collapsed pill that appears at the bottom of the screen while
/// uploads are in flight.  Tap target = whole card.
class UploadCollapsedBar extends StatefulWidget {
  const UploadCollapsedBar({
    required this.upload,
    required this.onTap,
    super.key,
  });

  final UploadController upload;
  final VoidCallback onTap;

  @override
  State<UploadCollapsedBar> createState() => _UploadCollapsedBarState();
}

class _UploadCollapsedBarState extends State<UploadCollapsedBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final upload = widget.upload;

    final total = upload.items.length;
    final done = upload.uploadedCount;
    final completed = total > 0 && done == total;
    final progress = total == 0
        ? 0.0
        : upload.items.fold<double>(0, (s, i) => s + i.progress) / total;

    final totalBytes = upload.items.fold<int>(0, (s, i) => s + i.size);
    final completedBytes = upload.items.fold<int>(
      0,
      (s, i) => s + (i.progress * i.size).round(),
    );

    final accent = dark ? AppColors.coral : AppColors.terracotta;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : AppColors.ivory,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: dark ? const Color(0xff3d3d3a) : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 10),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _breath,
                        builder: (context, _) {
                          final scale = completed
                              ? 1.0
                              : 1.0 + (_breath.value * 0.04);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xff3d3d3a)
                                    : AppColors.warmSand,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                completed
                                    ? Icons.check_rounded
                                    : Icons.cloud_upload_outlined,
                                size: 18,
                                color: accent,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              completed
                                  ? '$total ${total == 1 ? 'file' : 'files'} uploaded'
                                  : 'Uploading $total ${total == 1 ? 'file' : 'files'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$done of $total · '
                              '${formatFileSize(completedBytes)}/${formatFileSize(totalBytes)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: scheme.onSurface.withValues(alpha: .55),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 22,
                        color: scheme.onSurface.withValues(alpha: .45),
                      ),
                    ],
                  ),
                ),
                UploadProgressBar(
                  value: completed ? 1 : progress,
                  height: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
