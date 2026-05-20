import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/google_drive_icon.dart';
import '../../../widgets/media_thumb.dart';
import '../drive_controller.dart';

/// Horizontal recents strip shown on the drive home screen.
class DriveRecentsStrip extends StatelessWidget {
  const DriveRecentsStrip({
    required this.files,
    required this.onFileTap,
    this.onMore,
    super.key,
  });

  final List<DriveFile> files;
  final void Function(DriveFile file) onFileTap;
  final void Function(DriveFile file)? onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 136,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => RecentFileCard(
          key: ValueKey(files[i].localId ?? files[i].id),
          file: files[i],
          onTap: () => onFileTap(files[i]),
          onMore: onMore != null ? () => onMore!(files[i]) : null,
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: files.length,
      ),
    );
  }
}

class RecentFileCard extends StatelessWidget {
  const RecentFileCard({
    required this.file,
    required this.onTap,
    this.onMore,
    super.key,
  });

  final DriveFile file;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final url = file.thumbnailUrl ?? file.previewUrl;
    final hasPreview = url != null;
    final fileColor = _getFileColor(file.kind, scheme);

    return Container(
      width: 156,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.mdR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.mdR,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview Area
                SizedBox(
                  height: 84,
                  width: double.infinity,
                  child: hasPreview
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadii.md),
                          ),
                          child: MediaThumb(
                            file: file,
                            fit: BoxFit.cover,
                            radius: 0,
                            showBackground: false,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                fileColor.withValues(alpha: isDark ? 0.08 : 0.06),
                                fileColor.withValues(alpha: isDark ? 0.15 : 0.12),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadii.md),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? scheme.surfaceContainerHigh
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: GoogleDriveIcon.file(
                                  file,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                // Details Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.2,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatLabel(file)} · ${formatFileSize(file.size)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onMore != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onMore,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.more_vert_rounded,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getFileColor(FileKind kind, ColorScheme scheme) {
    return switch (kind) {
      FileKind.pdf => const Color(0xFFEA4335),
      FileKind.doc => const Color(0xFF1A73E8),
      FileKind.sheet => const Color(0xFF1E8E3E),
      FileKind.slides => const Color(0xFFF9A825),
      FileKind.audio => const Color(0xFF5C6BC0),
      FileKind.video => const Color(0xFF00BCD4),
      FileKind.zip => const Color(0xFF8D6E63),
      FileKind.code => const Color(0xFF455A64),
      FileKind.text => const Color(0xFF757575),
      _ => scheme.primary,
    };
  }
}

/// Helper to push the file detail route and record recent access.
void openDriveFile(BuildContext context, WidgetRef ref, DriveFile file) {
  if (file.isOptimistic) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(formatUploadStatus(file))));
    return;
  }
  ref.read(driveControllerProvider).markAccessed(file.id);
  context.push('/file/${file.id}');
}
