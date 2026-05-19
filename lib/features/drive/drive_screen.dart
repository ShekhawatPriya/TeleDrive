import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios_more_menu.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/tab_header.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (selectMode)
              DriveSelectionBar(
                selectedCount: selectedCount,
                onCancel: exitSelect,
                onShare: _bulkShare,
                onStar: () => _bulkStar(),
                onMove: () => _bulkMove(),
                onDelete: () => _bulkDelete(),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: drive.refresh,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Header(
                        userName: auth.user?.firstName ?? 'there',
                        searchController: search,
                        used: state.usedStorage,
                        grid: grid,
                        onLayoutToggle: () => ref
                            .read(viewPreferencesProvider)
                            .setLayout(
                              grid ? LayoutMode.list : LayoutMode.grid,
                            ),
                        onSearchChanged: () => setState(() {}),
                        menuButton: IosMoreButton(
                          sectionsBuilder: (ctx) => buildDriveMenuSections(
                            ctx,
                            ref,
                            folderId: null,
                            includeLayoutSection: false,
                            onSelect: () =>
                                setState(() => selectMode = true),
                          ),
                        ),
                      ),
                    ),
                    if (state.loading && files.isEmpty && folders.isEmpty)
                      const SliverFillRemaining(child: SkeletonList()),
                    if (state.error != null) _ErrorBanner(state.error!),
                    if (recent.isNotEmpty && query.isEmpty && !selectMode)
                      SliverToBoxAdapter(
                        child: DriveRecentsStrip(
                          files: recent,
                          onFileTap: (f) => openDriveFile(context, ref, f),
                        ),
                      ),
                    if (!state.loading && folders.isEmpty && files.isEmpty)
                      SliverFillRemaining(
                        child: EmptyState(
                          icon: query.isEmpty
                              ? Icons.folder_open
                              : Icons.search,
                          title: query.isEmpty
                              ? 'Your Drive is empty'
                              : 'No results',
                          body: query.isEmpty
                              ? 'Upload files or create a folder to get started.'
                              : 'Try a different file or folder name.',
                        ),
                      ),
                    if (folders.isNotEmpty)
                      const DriveSectionHeader('Folders'),
                    DriveFolderSliver(
                      folders: folders,
                      selectMode: selectMode,
                      selectedFolderIds: selectedFolderIds,
                      onFolderTap: _onFolderTap,
                      onFolderLongPress: (id) =>
                          enterSelect(folderId: id),
                      onFolderMore: (folder) => DriveItemActions.openFolder(
                        context,
                        ref,
                        folder,
                      ),
                    ),
                    if (files.isNotEmpty) const DriveSectionHeader('Files'),
                    DriveFilesSliver(
                      files: files,
                      grid: grid,
                      selectMode: selectMode,
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
      floatingActionButton: selectMode ? null : const DriveFab(),
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
      context,
      ref,
      fileIds: selectedFileIds,
      folderIds: selectedFolderIds,
    );
  }

  Future<void> _bulkStar() async {
    await DriveBulkActions.star(
      ref,
      fileIds: selectedFileIds,
      folderIds: selectedFolderIds,
    );
    exitSelect();
  }

  Future<void> _bulkMove() async {
    await DriveBulkActions.move(
      context,
      ref,
      fileIds: selectedFileIds,
      folderIds: selectedFolderIds,
    );
    if (mounted) exitSelect();
  }

  Future<void> _bulkDelete() async {
    final ok = await DriveBulkActions.delete(
      context,
      ref,
      fileIds: selectedFileIds,
      folderIds: selectedFolderIds,
    );
    if (ok && mounted) exitSelect();
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.userName,
    required this.searchController,
    required this.used,
    required this.grid,
    required this.onLayoutToggle,
    required this.onSearchChanged,
    required this.menuButton,
  });

  final String userName;
  final TextEditingController searchController;
  final int used;
  final bool grid;
  final VoidCallback onLayoutToggle;
  final VoidCallback onSearchChanged;
  final Widget menuButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabHeader(
            title: 'TeleDrive',
            subtitle: 'Hi, $userName',
            trailing: menuButton,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search files and folders',
            ),
            onChanged: (_) => onSearchChanged(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              DriveStoragePill(used: used),
              const Spacer(),
              IconButton(
                onPressed: onLayoutToggle,
                icon: Icon(grid ? Icons.view_list : Icons.grid_view),
                tooltip: 'Toggle view',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message),
        ),
      ),
    ),
  );
}
