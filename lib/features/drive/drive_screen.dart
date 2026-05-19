import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios_more_menu.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/skeletons.dart';
import '../auth/auth_controller.dart';
import 'components/drive_fab.dart';
import 'components/drive_header_widgets.dart';
import 'components/drive_item_actions.dart';
import 'components/drive_list_slivers.dart';
import 'components/drive_menu_builder.dart';
import 'components/drive_selection_bar.dart';
import 'components/selection_mode_mixin.dart';
import 'drive_controller.dart';
import 'view_preferences_controller.dart';

class DriveScreen extends ConsumerStatefulWidget {
  const DriveScreen({super.key});

  @override
  ConsumerState<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends ConsumerState<DriveScreen>
    with SelectionModeMixin<DriveScreen> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final drive = ref.watch(driveControllerProvider);
    final prefs = ref.watch(viewPreferencesProvider);
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
    folders = sortDriveFolders(folders, ascending: prefs.ascending);
    files = sortDriveFiles(
      files,
      sort: prefs.sort,
      ascending: prefs.ascending,
    );
    final recent = drive.recentFiles();
    final grid = prefs.layout == LayoutMode.grid;
    final firstName = auth.user?.firstName ?? 'there';

    if (selectMode) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              DriveSelectionBar(
                selectedCount: selectedCount,
                onCancel: exitSelect,
                onShare: _bulkShare,
                onStar: _bulkStar,
                onMove: _bulkMove,
                onDelete: _bulkDelete,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: drive.refresh,
                  child: CustomScrollView(
                    slivers: [
                      if (folders.isNotEmpty)
                        const DriveSectionHeader('Folders'),
                      DriveFolderSliver(
                        folders: folders,
                        selectMode: true,
                        selectedFolderIds: selectedFolderIds,
                        onFolderTap: _onFolderTap,
                        onFolderLongPress: (id) =>
                            enterSelect(folderId: id),
                        onFolderMore: (folder) => DriveItemActions.openFolder(
                          context, ref, folder),
                      ),
                      if (files.isNotEmpty) const DriveSectionHeader('Files'),
                      DriveFilesSliver(
                        files: files,
                        grid: grid,
                        selectMode: true,
                        selectedFileIds: selectedFileIds,
                        onFileTap: _onFileTap,
                        onFileLongPress: (id) => enterSelect(fileId: id),
                        onFileMore: (file) =>
                            DriveItemActions.openFile(context, ref, file),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: drive.refresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.medium(
              pinned: true,
              floating: false,
              expandedHeight: 128,
              title: Text(
                'TeleDrive',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                title: Text(
                  'Hi, $firstName',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: grid ? 'List view' : 'Grid view',
                  onPressed: () => ref.read(viewPreferencesProvider).setLayout(
                      grid ? LayoutMode.list : LayoutMode.grid),
                  icon: Icon(grid
                      ? Icons.view_agenda_outlined
                      : Icons.grid_view_outlined),
                ),
                IosMoreButton(
                  sectionsBuilder: (ctx) => buildDriveMenuSections(
                    ctx,
                    ref,
                    folderId: null,
                    includeLayoutSection: false,
                    onSelect: () => setState(() => selectMode = true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      0, 0, AppSpacing.sm, 0),
                  child: GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: ProfileAvatar(user: auth.user, size: 36),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                child: SearchBar(
                  controller: search,
                  hintText: 'Search files and folders',
                  leading: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
                child: DriveStoragePill(used: state.usedStorage),
              ),
            ),
            if (state.loading && files.isEmpty && folders.isEmpty)
              const SliverFillRemaining(child: SkeletonList()),
            if (state.error != null) _ErrorBanner(state.error!),
            if (recent.isNotEmpty && query.isEmpty)
              SliverToBoxAdapter(
                child: DriveRecentsStrip(
                  files: recent,
                  onFileTap: (f) => openDriveFile(context, ref, f),
                ),
              ),
            if (!state.loading && folders.isEmpty && files.isEmpty)
              SliverFillRemaining(
                child: EmptyState(
                  icon: query.isEmpty ? Icons.folder_open : Icons.search_off,
                  title: query.isEmpty
                      ? 'Your Drive is empty'
                      : 'No results',
                  body: query.isEmpty
                      ? 'Upload files or create a folder to get started.'
                      : 'Try a different file or folder name.',
                ),
              ),
            if (folders.isNotEmpty) const DriveSectionHeader('Folders'),
            DriveFolderSliver(
              folders: folders,
              selectMode: false,
              selectedFolderIds: selectedFolderIds,
              onFolderTap: _onFolderTap,
              onFolderLongPress: (id) => enterSelect(folderId: id),
              onFolderMore: (folder) =>
                  DriveItemActions.openFolder(context, ref, folder),
            ),
            if (files.isNotEmpty) const DriveSectionHeader('Files'),
            DriveFilesSliver(
              files: files,
              grid: grid,
              selectMode: false,
              selectedFileIds: selectedFileIds,
              onFileTap: _onFileTap,
              onFileLongPress: (id) => enterSelect(fileId: id),
              onFileMore: (file) =>
                  DriveItemActions.openFile(context, ref, file),
            ),
          ],
        ),
      ),
      floatingActionButton: const DriveFab(),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: AppRadii.mdR,
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
