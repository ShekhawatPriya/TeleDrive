import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/file_type_detector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_tiles.dart';
import '../upload/upload_controller.dart';
import 'drive_controller.dart';

class FolderScreen extends ConsumerWidget {
  const FolderScreen({required this.folderId, super.key});
  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveControllerProvider);
    final folder = drive.folder(folderId);
    final files = drive.filesInFolder(folderId);
    final folders = drive.foldersInFolder(folderId);
    final path = drive.folderPath(folderId);

    return Scaffold(
      appBar: AppBar(
        title: Text(folder?.name ?? 'Folder'),
        actions: [
          IconButton(
            onPressed: () => ref.read(driveControllerProvider).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ref.read(driveControllerProvider).refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: path.length,
                separatorBuilder: (_, __) =>
                    const Icon(Icons.chevron_right, size: 18),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(path[i].name),
                  onPressed: i == path.length - 1
                      ? null
                      : () => context.push('/folder/${path[i].id}'),
                ),
              ),
            ),
            if (folders.isEmpty && files.isEmpty)
              const SizedBox(
                height: 520,
                child: EmptyState(
                  icon: Icons.folder_open,
                  title: 'Nothing here yet',
                  body: 'Upload files or create a nested folder.',
                ),
              ),
            for (final item in folders)
              FileListTile(
                name: item.name,
                subtitle:
                    '${item.recursiveFileCount} files • ${formatFileSize(item.recursiveSize)}',
                isFolder: true,
                starred: item.starred,
                onTap: () => context.push('/folder/${item.id}'),
                onStar: () => ref
                    .read(driveControllerProvider)
                    .toggleStar(item.id, folder: true),
                onMore: () => _folderActions(context, ref, item.id),
              ),
            for (final file in files)
              FileListTile(
                name: file.name,
                subtitle:
                    '${formatLabel(file)} • ${formatFileSize(file.size)} • ${formatDate(file.modifiedAt)}',
                file: file,
                starred: file.starred,
                onTap: () {
                  ref.read(driveControllerProvider).markAccessed(file.id);
                  context.push('/file/${file.id}');
                },
                onStar: () =>
                    ref.read(driveControllerProvider).toggleStar(file.id),
                onMore: () => _fileActions(context, ref, file.id),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Upload files'),
              onTap: () => Navigator.pop(context, 'upload'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Create folder'),
              onTap: () => Navigator.pop(context, 'folder'),
            ),
          ],
        ),
      ),
    );
    if (action == 'upload')
      await ref.read(uploadControllerProvider).pickFiles(folderId: folderId);
    if (action == 'folder' && context.mounted) {
      final c = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('New folder'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Folder name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (name != null && name.isNotEmpty)
        await ref.read(driveControllerProvider).createFolder(name, folderId);
    }
  }

  Future<void> _fileActions(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Move to trash'),
          onTap: () => Navigator.pop(context, 'delete'),
        ),
      ),
    );
    if (action == 'delete')
      await ref.read(driveControllerProvider).deleteItems(fileIds: [id]);
  }

  Future<void> _folderActions(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete folder'),
          onTap: () => Navigator.pop(context, 'delete'),
        ),
      ),
    );
    if (action == 'delete')
      await ref.read(driveControllerProvider).deleteItems(folderIds: [id]);
  }
}
