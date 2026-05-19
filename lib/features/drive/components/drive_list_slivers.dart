import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/file_tiles.dart';
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
          subtitle:
              '${folder.recursiveFileCount} files \u00b7 ${formatFileSize(folder.recursiveSize)}',
          isFolder: true,
          starred: folder.starred,
          shared: folder.shared,
          selected: selectMode ? selectedFolderIds.contains(folder.id) : null,
          onTap: () => onFolderTap(folder),
          onLongPress: () => onFolderLongPress(folder.id),
          onStar: () => ref
              .read(driveControllerProvider)
              .toggleStar(folder.id, folder: true),
          onMore: () => onFolderMore(folder),
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
            childAspectRatio: .82,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: files.length,
          itemBuilder: (_, i) {
            final file = files[i];
            return FileCardTile(
              key: ValueKey(file.id),
              file: file,
              selected: selectMode ? selectedFileIds.contains(file.id) : null,
              onTap: () => onFileTap(file),
              onLongPress: () => onFileLongPress(file.id),
              onMore: () => onFileMore(file),
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
          return FileListTile(
            key: ValueKey(file.id),
            name: file.name,
            subtitle: file.isOptimistic
                ? '${formatUploadStatus(file)} \u00b7 ${formatFileSize(file.size)}'
                : '${formatLabel(file)} \u00b7 ${formatFileSize(file.size)} \u00b7 ${formatDate(file.modifiedAt)}',
            file: file,
            starred: file.starred,
            selected: selectMode ? selectedFileIds.contains(file.id) : null,
            onTap: () => onFileTap(file),
            onLongPress: () => onFileLongPress(file.id),
            onStar: file.isOptimistic
                ? null
                : () => ref.read(driveControllerProvider).toggleStar(file.id),
            onMore: file.isOptimistic ? null : () => onFileMore(file),
          );
        },
      ),
    );
  }
}

/// Horizontal recents strip shown on the drive home screen.
class DriveRecentsStrip extends StatelessWidget {
  const DriveRecentsStrip({
    required this.files,
    required this.onFileTap,
    super.key,
  });

  final List<DriveFile> files;
  final FileTapHandler onFileTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => SizedBox(
          width: 160,
          child: FileCardTile(
            key: ValueKey(files[i].id),
            file: files[i],
            onTap: () => onFileTap(files[i]),
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: files.length,
      ),
    );
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
