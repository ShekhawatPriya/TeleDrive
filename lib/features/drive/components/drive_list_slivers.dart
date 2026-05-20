import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/file_card_tile.dart';
import '../../../widgets/file_list_tile.dart';
import '../../../widgets/google_drive_icon.dart';
import '../../../widgets/media_thumb.dart';
import '../../upload/upload_controller.dart';
import '../drive_controller.dart';

typedef FolderTapHandler = void Function(DriveFolder folder);
typedef FileTapHandler = void Function(DriveFile file);
typedef FolderIdHandler = void Function(String id);
typedef FileIdHandler = void Function(String id);
typedef FileMoreHandler = void Function(DriveFile file);
typedef FolderMoreHandler = void Function(DriveFolder folder);

/// Sliver list of folder tiles used by both the home and folder screens.
class DriveFolderSliver extends ConsumerWidget {
  const DriveFolderSliver({
    required this.folders,
    required this.selectMode,
    required this.selectedFolderIds,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onFolderMore,
    super.key,
  });

  final List<DriveFolder> folders;
  final bool selectMode;
  final Set<String> selectedFolderIds;
  final FolderTapHandler onFolderTap;
  final FolderIdHandler onFolderLongPress;
  final FolderMoreHandler onFolderMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverList.builder(
      itemCount: folders.length,
      itemBuilder: (_, i) {
        final folder = folders[i];
        return FileListTile(
          key: ValueKey('folder-${folder.id}'),
          name: folder.name,
          subtitle: folder.isOptimistic
              ? 'Creating folder…'
              : '${folder.recursiveFileCount} files · ${formatFileSize(folder.recursiveSize)}',
          isFolder: true,
          isOptimistic: folder.isOptimistic,
          starred: folder.starred,
          shared: folder.shared,
          selected: selectMode ? selectedFolderIds.contains(folder.id) : null,
          onTap: () => onFolderTap(folder),
          onLongPress: folder.isOptimistic
              ? null
              : () => onFolderLongPress(folder.id),
          onStar: folder.isOptimistic
              ? null
              : () => ref
                  .read(driveControllerProvider)
                  .toggleStar(folder.id, folder: true),
          onMore: folder.isOptimistic ? null : () => onFolderMore(folder),
        );
      },
    );
  }
}

/// Sliver of files rendered as either grid or list based on [grid].
class DriveFilesSliver extends ConsumerWidget {
  const DriveFilesSliver({
    required this.files,
    required this.grid,
    required this.selectMode,
    required this.selectedFileIds,
    required this.onFileTap,
    required this.onFileLongPress,
    required this.onFileMore,
    this.bottomPadding = 120,
    super.key,
  });

  final List<DriveFile> files;
  final bool grid;
  final bool selectMode;
  final Set<String> selectedFileIds;
  final FileTapHandler onFileTap;
  final FileIdHandler onFileLongPress;
  final FileMoreHandler onFileMore;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (grid) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: .72,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: files.length,
          itemBuilder: (_, i) {
            final file = files[i];
            final isFailed = _isFailed(file);
            return FileCardTile(
              key: ValueKey(file.localId ?? file.id),
              file: file,
              selected: selectMode ? selectedFileIds.contains(file.id) : null,
              onTap: () => onFileTap(file),
              onLongPress: () => onFileLongPress(file.id),
              onMore: () => onFileMore(file),
              onRetry: isFailed
                  ? () => ref.read(uploadControllerProvider).retryFailed()
                  : null,
              onRemove: isFailed ? () => _removeOptimistic(ref, file) : null,
            );
          },
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      sliver: SliverList.builder(
        itemCount: files.length,
        itemBuilder: (_, i) {
          final file = files[i];
          final isFailed = _isFailed(file);
          return FileListTile(
            key: ValueKey(file.localId ?? file.id),
            name: file.name,
            subtitle: file.isOptimistic
                ? '${formatUploadStatus(file)} · ${formatFileSize(file.size)}'
                : '${formatLabel(file)} · ${formatFileSize(file.size)} · ${formatDate(file.modifiedAt)}',
            file: file,
            isOptimistic: file.isOptimistic,
            starred: file.starred,
            selected: selectMode ? selectedFileIds.contains(file.id) : null,
            onTap: () => onFileTap(file),
            onLongPress: () => onFileLongPress(file.id),
            onStar: file.isOptimistic
                ? null
                : () => ref.read(driveControllerProvider).toggleStar(file.id),
            onMore: file.isOptimistic ? null : () => onFileMore(file),
            onRetry: isFailed
                ? () => ref.read(uploadControllerProvider).retryFailed()
                : null,
            onRemove: isFailed ? () => _removeOptimistic(ref, file) : null,
          );
        },
      ),
    );
  }
}

bool _isFailed(DriveFile file) =>
    file.isOptimistic &&
    (file.uploadStatus == 'failed' || file.uploadStatus == 'cancelled');

void _removeOptimistic(WidgetRef ref, DriveFile file) {
  // Optimistic file IDs are encoded as `local:<localId>` by
  // UploadController._syncOptimistic. Decode and dismiss the failed item.
  if (!file.id.startsWith('local:')) return;
  final localId = file.id.substring('local:'.length);
  ref.read(uploadControllerProvider).removeFailed(localId);
}

/// Horizontal recents strip shown on the drive home screen.
class DriveRecentsStrip extends StatelessWidget {
  const DriveRecentsStrip({
    required this.files,
    required this.onFileTap,
    this.onMore,
    super.key,
  });

  final List<DriveFile> files;
  final FileTapHandler onFileTap;
  final FileMoreHandler? onMore;

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
