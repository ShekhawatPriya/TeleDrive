import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'drive_recents_strip.dart';

import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/file_card_tile.dart';
import '../../../widgets/folder_collection_card.dart';
import '../../../widgets/file_list_tile.dart';
import '../../upload/upload_controller.dart';
import '../drive_controller.dart';
import 'drive_item_context_menu.dart';

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
    this.allowRename = true,
    super.key,
  });

  final bool allowRename;
  final List<DriveFolder> folders;
  final bool selectMode;
  final Set<String> selectedFolderIds;
  final FolderTapHandler onFolderTap;
  final FolderIdHandler onFolderLongPress;
  final FolderMoreHandler onFolderMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!selectMode && MediaQuery.textScalerOf(context).scale(14) <= 22) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            mainAxisExtent:
                (Theme.of(context).platform == TargetPlatform.iOS ? 148 : 176) +
                (MediaQuery.textScalerOf(context).scale(14) - 14) * 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: folders.length,
          itemBuilder: (_, i) {
            final folder = folders[i];
            return DriveItemContextMenu(
              folder: folder,
              allowRename: allowRename,
              enabled: !selectMode,
              trailingClearance: 48,
              onOpen: () => onFolderTap(folder),
              onSelect: () => onFolderLongPress(folder.id),
              child: FolderCollectionCard(
                folder: folder,
                onTap: () => onFolderTap(folder),
                onLongPress:
                    Theme.of(context).platform == TargetPlatform.iOS &&
                        !selectMode
                    ? null
                    : folder.isOptimistic
                    ? null
                    : () => onFolderLongPress(folder.id),
                onMore: folder.isOptimistic ? null : () => onFolderMore(folder),
              ),
            );
          },
        ),
      );
    }
    return SliverList.builder(
      itemCount: folders.length,
      itemBuilder: (_, i) {
        final folder = folders[i];
        return DriveItemContextMenu(
          folder: folder,
          allowRename: allowRename,
          enabled: !selectMode,
          trailingClearance: 48,
          onOpen: () => onFolderTap(folder),
          onSelect: () => onFolderLongPress(folder.id),
          child: FileListTile(
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
            onLongPress:
                Theme.of(context).platform == TargetPlatform.iOS && !selectMode
                ? null
                : folder.isOptimistic
                ? null
                : () => onFolderLongPress(folder.id),
            onStar: folder.isOptimistic
                ? null
                : () => ref
                      .read(driveControllerProvider)
                      .toggleStar(folder.id, folder: true),
            onMore: folder.isOptimistic ? null : () => onFolderMore(folder),
          ),
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
    if (grid && MediaQuery.textScalerOf(context).scale(14) <= 22) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            childAspectRatio: .72,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: files.length,
          itemBuilder: (_, i) {
            final file = files[i];
            final isFailed = _isFailed(file);
            return DriveItemContextMenu(
              file: file,
              enabled: !selectMode,
              trailingClearance: 48,
              onOpen: () => onFileTap(file),
              onSelect: () => onFileLongPress(file.id),
              child: FileCardTile(
                key: ValueKey(file.localId ?? file.id),
                file: file,
                selected: selectMode ? selectedFileIds.contains(file.id) : null,
                onTap: () => onFileTap(file),
                onLongPress:
                    Theme.of(context).platform == TargetPlatform.iOS &&
                        !selectMode
                    ? null
                    : () => onFileLongPress(file.id),
                onMore: () => onFileMore(file),
                onRetry: isFailed
                    ? () => ref.read(uploadControllerProvider).retryFailed()
                    : null,
                onRemove: isFailed ? () => _removeOptimistic(ref, file) : null,
              ),
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
          return DriveItemContextMenu(
            file: file,
            enabled: !selectMode,
            trailingClearance: 48,
            onOpen: () => onFileTap(file),
            onSelect: () => onFileLongPress(file.id),
            child: FileListTile(
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
              onLongPress:
                  Theme.of(context).platform == TargetPlatform.iOS &&
                      !selectMode
                  ? null
                  : () => onFileLongPress(file.id),
              onStar: file.isOptimistic
                  ? null
                  : () => ref.read(driveControllerProvider).toggleStar(file.id),
              onMore: file.isOptimistic ? null : () => onFileMore(file),
              onRetry: isFailed
                  ? () => ref.read(uploadControllerProvider).retryFailed()
                  : null,
              onRemove: isFailed ? () => _removeOptimistic(ref, file) : null,
            ),
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
