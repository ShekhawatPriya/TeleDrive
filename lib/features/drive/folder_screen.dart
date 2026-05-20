import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios_more_menu.dart';

import '../upload/ui/components/bottom_action_system.dart';
import 'components/drive_item_actions.dart';
import 'components/drive_list_slivers.dart';
import 'components/drive_menu_builder.dart';
import 'components/drive_selection_bar.dart';
import 'components/selection_mode_mixin.dart';
import 'drive_controller.dart';
import 'view_preferences_controller.dart';

class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({required this.folderId, super.key});
  final String folderId;

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen>
    with SelectionModeMixin<FolderScreen> {
  @override
  Widget build(BuildContext context) {
    final drive = ref.watch(driveControllerProvider);
    final prefs = ref.watch(viewPreferencesProvider);
    final folder = drive.folder(widget.folderId);
    var files = drive.filesInFolder(widget.folderId);
    var folders = drive.foldersInFolder(widget.folderId);
    folders = sortDriveFolders(folders, ascending: prefs.ascending);
    files = sortDriveFiles(
      files,
      sort: prefs.sort,
      ascending: prefs.ascending,
    );
    final path = drive.folderPath(widget.folderId);
    final grid = prefs.layout == LayoutMode.grid;

    return Scaffold(
      appBar: selectMode
          ? PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: DriveSelectionBar(
                selectedCount: selectedCount,
                onCancel: exitSelect,
                onShare: _bulkShare,
                onStar: _bulkStar,
                onMove: _bulkMove,
                onDelete: _bulkDelete,
              ),
            )
          : AppBar(
              title: Text(folder?.name ?? 'Folder'),
              actions: [
                IosMoreButton(
                  sectionsBuilder: (ctx) => buildDriveMenuSections(
                    ctx,
                    ref,
                    folderId: widget.folderId,
                    includeLayoutSection: true,
                    onSelect: () => setState(() => selectMode = true),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: ref.read(driveControllerProvider).refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Breadcrumbs(path: path)),
                if (folders.isEmpty && files.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.folder_open,
                      title: 'Nothing here yet',
                      body: 'Upload files or create a nested folder.',
                    ),
                  ),
                DriveFolderSliver(
                  folders: folders,
                  selectMode: selectMode,
                  selectedFolderIds: selectedFolderIds,
                  onFolderTap: _onFolderTap,
                  onFolderLongPress: (id) => enterSelect(folderId: id),
                  onFolderMore: (f) => DriveItemActions.openFolder(
                    context, ref, f, allowRename: false,
                  ),
                ),
                DriveFilesSliver(
                  files: files,
                  grid: grid,
                  selectMode: selectMode,
                  selectedFileIds: selectedFileIds,
                  onFileTap: _onFileTap,
                  onFileLongPress: (id) => enterSelect(fileId: id),
                  onFileMore: (f) => DriveItemActions.openFile(context, ref, f),
                  bottomPadding: 150,
                ),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: BottomActionSystem(
                showFab: !selectMode,
                parentId: widget.folderId,
              ),
            ),
          ),

        ],
      ),
    );
  }

  void _onFileTap(DriveFile file) {
    if (selectMode) {
      toggleFileSelection(file.id);
      return;
    }
    openDriveFile(context, ref, file);
  }

  void _onFolderTap(DriveFolder folder) {
    if (selectMode) {
      toggleFolderSelection(folder.id);
      return;
    }
    context.push('/folder/${folder.id}');
  }

  Future<void> _bulkShare() async {
    await DriveBulkActions.share(
      context, ref,
      fileIds: selectedFileIds, folderIds: selectedFolderIds,
    );
  }

  Future<void> _bulkStar() async {
    await DriveBulkActions.star(
      ref,
      fileIds: selectedFileIds, folderIds: selectedFolderIds,
    );
    exitSelect();
  }

  Future<void> _bulkMove() async {
    await DriveBulkActions.move(
      context, ref,
      fileIds: selectedFileIds, folderIds: selectedFolderIds,
      currentParentId: widget.folderId,
    );
    if (mounted) exitSelect();
  }

  Future<void> _bulkDelete() async {
    final ok = await DriveBulkActions.delete(
      context, ref,
      fileIds: selectedFileIds, folderIds: selectedFolderIds,
    );
    if (ok && mounted) exitSelect();
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.path});
  final List<dynamic> path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: path.length,
        separatorBuilder: (_, __) => Center(
          child: Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
        ),
        itemBuilder: (_, i) {
          final isLast = i == path.length - 1;
          return Center(
            child: TextButton(
              onPressed: isLast ? null : () => context.push('/folder/${path[i].id}'),
              style: TextButton.styleFrom(
                foregroundColor: isLast ? scheme.onSurface : scheme.primary,
              ),
              child: Text(path[i].name as String),
            ),
          );
        },
      ),
    );
  }
}
