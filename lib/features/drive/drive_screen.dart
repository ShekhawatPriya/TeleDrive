import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_tiles.dart';
import '../../widgets/skeletons.dart';
import '../auth/auth_controller.dart';
import '../upload/upload_controller.dart';
import 'drive_controller.dart';

enum SortField { name, kind, size, date }

class DriveScreen extends ConsumerStatefulWidget {
  const DriveScreen({super.key});

  @override
  ConsumerState<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends ConsumerState<DriveScreen> {
  final search = TextEditingController();
  bool grid = false;
  SortField sort = SortField.name;
  bool ascending = true;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final drive = ref.watch(driveControllerProvider);
    final state = drive.state;
    final query = search.text.trim().toLowerCase();
    var folders = drive.foldersInFolder(null);
    var files = drive.filesInFolder(null);
    if (query.isNotEmpty) {
      folders = drive.folders
          .where((f) => f.name.toLowerCase().contains(query))
          .toList();
      files = drive.files
          .where((f) => f.name.toLowerCase().contains(query))
          .toList();
    }
    folders = _sortFolders(folders);
    files = _sortFiles(files);
    final recent = drive.recentFiles();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: drive.refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TeleDrive',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                Text(
                                  'Hi ${auth.user?.firstName ?? 'there'}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => context.go('/profile'),
                            icon: const Icon(Icons.person_outline),
                            tooltip: 'Profile',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search files and folders',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StoragePill(
                            used: state.usedStorage,
                            total: state.totalStorage,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => setState(() => grid = !grid),
                            icon: Icon(
                              grid ? Icons.view_list : Icons.grid_view,
                            ),
                            tooltip: 'Toggle view',
                          ),
                          PopupMenuButton<SortField>(
                            icon: const Icon(Icons.sort),
                            onSelected: (value) => setState(() {
                              if (sort == value) {
                                ascending = !ascending;
                              } else {
                                sort = value;
                                ascending = true;
                              }
                            }),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: SortField.name,
                                child: Text('Name'),
                              ),
                              PopupMenuItem(
                                value: SortField.kind,
                                child: Text('Kind'),
                              ),
                              PopupMenuItem(
                                value: SortField.size,
                                child: Text('Size'),
                              ),
                              PopupMenuItem(
                                value: SortField.date,
                                child: Text('Date'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (state.loading && files.isEmpty && folders.isEmpty)
                const SliverFillRemaining(child: SkeletonList()),
              if (state.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(state.error!),
                      ),
                    ),
                  ),
                ),
              if (recent.isNotEmpty && query.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 156,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (_, i) => SizedBox(
                        width: 160,
                        child: FileCardTile(
                          file: recent[i],
                          onTap: () => _openFile(recent[i]),
                        ),
                      ),
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: recent.length,
                    ),
                  ),
                ),
              if (!state.loading && folders.isEmpty && files.isEmpty)
                SliverFillRemaining(
                  child: EmptyState(
                    icon: query.isEmpty ? Icons.folder_open : Icons.search,
                    title: query.isEmpty ? 'Your Drive is empty' : 'No results',
                    body: query.isEmpty
                        ? 'Upload files or create a folder to get started.'
                        : 'Try a different file or folder name.',
                  ),
                ),
              if (folders.isNotEmpty) _SectionHeader('Folders'),
              SliverList.builder(
                itemCount: folders.length,
                itemBuilder: (_, i) {
                  final folder = folders[i];
                  return FileListTile(
                    name: folder.name,
                    subtitle:
                        '${folder.recursiveFileCount} files • ${formatFileSize(folder.recursiveSize)}',
                    isFolder: true,
                    starred: folder.starred,
                    onTap: () => context.push('/folder/${folder.id}'),
                    onStar: () => ref
                        .read(driveControllerProvider)
                        .toggleStar(folder.id, folder: true),
                    onMore: () => _folderActions(folder),
                  );
                },
              ),
              if (files.isNotEmpty) _SectionHeader('Files'),
              if (grid)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: .82,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: files.length,
                    itemBuilder: (_, i) => FileCardTile(
                      file: files[i],
                      onTap: () => _openFile(files[i]),
                      onMore: () => _fileActions(files[i]),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 120),
                  sliver: SliverList.builder(
                    itemCount: files.length,
                    itemBuilder: (_, i) {
                      final file = files[i];
                      return FileListTile(
                        name: file.name,
                        subtitle:
                            '${formatLabel(file)} • ${formatFileSize(file.size)} • ${formatDate(file.modifiedAt)}',
                        file: file,
                        starred: file.starred,
                        onTap: () => _openFile(file),
                        onStar: () => ref
                            .read(driveControllerProvider)
                            .toggleStar(file.id),
                        onMore: () => _fileActions(file),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _DriveFab(parentId: null),
    );
  }

  List<DriveFile> _sortFiles(List<DriveFile> input) {
    final list = [...input];
    list.sort((a, b) {
      final cmp = switch (sort) {
        SortField.name => a.name.compareTo(b.name),
        SortField.kind => a.kind.name.compareTo(b.kind.name),
        SortField.size => a.size.compareTo(b.size),
        SortField.date => a.modifiedAt.compareTo(b.modifiedAt),
      };
      return ascending ? cmp : -cmp;
    });
    return list;
  }

  List<DriveFolder> _sortFolders(List<DriveFolder> input) {
    final list = [...input]..sort((a, b) => a.name.compareTo(b.name));
    return ascending ? list : list.reversed.toList();
  }

  void _openFile(DriveFile file) {
    ref.read(driveControllerProvider).markAccessed(file.id);
    context.push('/file/${file.id}');
  }

  Future<void> _fileActions(DriveFile file) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _ActionSheet(
        title: file.name,
        actions: const {
          'download': Icons.download,
          'star': Icons.star_border,
          'delete': Icons.delete_outline,
        },
      ),
    );
    if (action == 'delete')
      await ref.read(driveControllerProvider).deleteItems(fileIds: [file.id]);
    if (action == 'star') ref.read(driveControllerProvider).toggleStar(file.id);
  }

  Future<void> _folderActions(DriveFolder folder) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _ActionSheet(
        title: folder.name,
        actions: const {
          'rename': Icons.edit_outlined,
          'star': Icons.star_border,
          'delete': Icons.delete_outline,
        },
      ),
    );
    if (action == 'delete')
      await ref
          .read(driveControllerProvider)
          .deleteItems(folderIds: [folder.id]);
    if (action == 'star')
      ref.read(driveControllerProvider).toggleStar(folder.id, folder: true);
    if (action == 'rename' && mounted) await _renameFolder(folder);
  }

  Future<void> _renameFolder(DriveFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty)
      await ref.read(driveControllerProvider).renameFolder(folder.id, name);
  }
}

class _StoragePill extends StatelessWidget {
  const _StoragePill({required this.used, required this.total});
  final int used;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : used / total;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatFileSize(used)} used',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: pct.clamp(0, 1),
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

class _DriveFab extends ConsumerWidget {
  const _DriveFab({this.parentId});
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => _ActionSheet(
            title: 'Add to Drive',
            actions: const {
              'upload': Icons.upload_file,
              'folder': Icons.create_new_folder_outlined,
            },
          ),
        );
        if (action == 'upload')
          await ref
              .read(uploadControllerProvider)
              .pickFiles(folderId: parentId);
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
            await ref
                .read(driveControllerProvider)
                .createFolder(name, parentId);
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.title, required this.actions});
  final String title;
  final Map<String, IconData> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final entry in actions.entries)
              ListTile(
                leading: Icon(entry.value),
                title: Text(
                  entry.key[0].toUpperCase() + entry.key.substring(1),
                ),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
  }
}
