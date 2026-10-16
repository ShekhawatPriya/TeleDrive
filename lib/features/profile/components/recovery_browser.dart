import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/file_list_tile.dart';
import '../../../widgets/ios/ios_browse.dart';
import '../../../widgets/ios/ios_page.dart';
import '../../../widgets/ios/ios_tab_header.dart';
import '../../../widgets/ios_more_menu.dart';
import '../../../widgets/selection_toolbar.dart';
import '../../drive/components/drive_item_context_menu.dart';
import '../../auth/auth_controller.dart';
import '../../drive/components/drive_list_slivers.dart';
import '../../../widgets/item_status.dart';

/// Recovery destinations use the same item rows, native hold previews and
/// selection controls as Drive, with destination-specific recovery actions.
class RecoveryBrowser extends ConsumerWidget {
  const RecoveryBrowser({
    required this.title,
    required this.icon,
    required this.description,
    required this.emptyTitle,
    required this.emptyBody,
    required this.files,
    required this.loading,
    required this.error,
    required this.selectMode,
    required this.selectedFiles,
    required this.selectedFolders,
    required this.onRefresh,
    required this.onSelect,
    required this.onDone,
    required this.onSelectAll,
    required this.onClear,
    required this.actions,
    required this.fileMenu,
    required this.folderMenu,
    required this.onFileSelect,
    required this.onFolderSelect,
    this.folders = const [],
    this.onDeleteAll,
    super.key,
  });
  final String title, description, emptyTitle, emptyBody;

  /// The space's symbol, matching its tile on the Drive home.
  final IconData icon;
  final List<DriveFile> files;
  final List<DriveFolder> folders;
  final bool loading, selectMode;
  final String? error;
  final Set<String> selectedFiles, selectedFolders;
  final Future<void> Function() onRefresh;
  final VoidCallback onSelect, onDone, onSelectAll, onClear;
  final VoidCallback? onDeleteAll;
  final void Function(String id) onFileSelect, onFolderSelect;
  final List<({String label, IconData icon, VoidCallback onPressed})> actions;
  final List<IosMenuSection> Function(DriveFile) fileMenu;
  final List<IosMenuSection> Function(DriveFolder) folderMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(
      authControllerProvider.select(
        (auth) => (auth.user?.userId, auth.user?.telegramId, auth.token),
      ),
    );
    bool valid() {
      final auth = ref.read(authControllerProvider);
      return context.mounted &&
          account == (auth.user?.userId, auth.user?.telegramId, auth.token);
    }

    final scheme = Theme.of(context).colorScheme;
    final count = selectedFiles.length + selectedFolders.length;
    final initialLoading = loading && files.isEmpty && folders.isEmpty;
    Widget selection({bool actionsOnly = false}) => SelectionToolbar(
      count: count,
      onCancel: onDone,
      actions: actions,
      actionsOnly: actionsOnly,
      onSelectAll: onSelectAll,
      onClear: onClear,
    );
    final hasItems = files.isNotEmpty || folders.isNotEmpty;
    final total = files.length + folders.length;
    // The hero joins the loaded body, so the first result still reveals the
    // introduction, count and rows together.
    final showHero =
        !selectMode &&
        !(initialLoading && error == null) &&
        !(error != null && !hasItems);
    return PopScope(
      canPop: !selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectMode) onDone();
      },
      child: Scaffold(
        backgroundColor: IosBrowse.canvas(context),
        body: Column(
          children: [
            if (selectMode) selection(),
            Expanded(
              child: IosBrowseCanvas(
                child: IosHeroScope(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      if (!selectMode)
                        IosInlineTitleBar(
                          title: title,
                          // The hero names the page until it scrolls away.
                          hasHero: showHero,
                          backgroundColor: IosBrowse.canvas(context),
                          leading: IosNavigationBar.backButton(
                            context,
                            inScrollView: true,
                          ),
                          trailing: IosMoreButton(
                            claimsTouches: true,
                            size: 44,
                            tooltip: '$title options',
                            sectionsBuilder: (_) => [
                              IosMenuSection([
                                if (hasItems)
                                  IosMenuItem(
                                    label: 'Select',
                                    leadingIcon:
                                        CupertinoIcons.check_mark_circled,
                                    onTap: onSelect,
                                  ),
                                IosMenuItem(
                                  label: 'Refresh',
                                  leadingIcon: CupertinoIcons.arrow_clockwise,
                                  onTap: onRefresh,
                                ),
                              ]),
                              if (onDeleteAll != null &&
                                  !loading &&
                                  error == null &&
                                  hasItems)
                                IosMenuSection([
                                  IosMenuItem(
                                    label: 'Delete All',
                                    leadingIcon: CupertinoIcons.trash,
                                    destructive: true,
                                    onTap: onDeleteAll!,
                                  ),
                                ]),
                            ],
                          ),
                        ),
                      CupertinoSliverRefreshControl(onRefresh: onRefresh),
                      // Reveal the introduction, count and rows together on the
                      // first result. Refreshes keep the existing content visible.
                      if (initialLoading && error == null)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CupertinoActivityIndicator()),
                        )
                      else if (error != null && !hasItems)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: IosContentUnavailable(
                            icon: CupertinoIcons.exclamationmark_circle,
                            title: 'Unable to Load',
                            body: error,
                            actionLabel: 'Try Again',
                            onAction: onRefresh,
                          ),
                        )
                      else ...[
                        if (showHero)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                IosBrowse.gutter,
                                IosPageMetrics.contentTop,
                                IosBrowse.gutter,
                                0,
                              ),
                              child: IosSettingsIntro(
                                icon: _filled(icon),
                                color: CupertinoColors.systemBlue,
                                title: title,
                                description: description,
                                fill: IosBrowse.fill(context),
                              ),
                            ),
                          ),
                        if (!hasItems)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: IosContentUnavailable(
                              icon: icon,
                              title: emptyTitle,
                              body: emptyBody,
                            ),
                          ),
                        if (error != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      error!,
                                      style: IosBrowse.footnote(
                                        context,
                                        color: scheme.error,
                                      ),
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: const EdgeInsets.only(left: 12),
                                    minimumSize: const Size(44, 44),
                                    onPressed: onRefresh,
                                    child: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (hasItems)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                showHero ? 0 : 16,
                                20,
                                4,
                              ),
                              child: Text(
                                '$total ${total == 1 ? 'item' : 'items'}',
                                style: IosBrowse.footnote(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        SliverList.builder(
                          itemCount: folders.length + files.length,
                          itemBuilder: (_, index) {
                            final folder = index < folders.length
                                ? folders[index]
                                : null;
                            final file = folder == null
                                ? files[index - folders.length]
                                : null;
                            final id = file?.id ?? folder!.id;
                            List<IosMenuSection> menu() => !valid()
                                ? []
                                : [
                                    if (file != null)
                                      IosMenuSection([
                                        IosMenuItem(
                                          label: 'Open',
                                          leadingIcon:
                                              CupertinoIcons.arrow_up_right,
                                          onTap: () {
                                            if (valid())
                                              openDriveFile(context, ref, file);
                                          },
                                        ),
                                      ]),
                                    ...(file != null
                                        ? fileMenu(file)
                                        : folderMenu(folder!)),
                                  ];
                            void select() => file != null
                                ? onFileSelect(id)
                                : onFolderSelect(id);
                            BuildContext? rowContext;
                            void more() {
                              final box = rowContext?.findRenderObject();
                              if (box is! RenderBox) return;
                              showIosMoreMenu(
                                context: context,
                                anchor:
                                    box.localToGlobal(Offset.zero) & box.size,
                                sections: menu(),
                              );
                            }

                            void open() {
                              if (selectMode) {
                                select();
                                return;
                              }
                              if (file != null) {
                                openDriveFile(context, ref, file);
                              } else {
                                more();
                              }
                            }

                            return DriveItemContextMenu(
                              key: ValueKey(
                                '${file == null ? 'folder' : 'file'}-$id',
                              ),
                              file: file,
                              folder: folder,
                              enabled: !selectMode,
                              trailingClearance: 48,
                              sectionsBuilder: menu,
                              onOpen: open,
                              onSelect: select,
                              child: Builder(
                                builder: (tileContext) {
                                  rowContext = tileContext;
                                  return FileListTile(
                                    moreButton: IosMoreButton(
                                      plain: true,
                                      size: 48,
                                      menuTitle: itemStatusText(
                                        starred:
                                            file?.starred ?? folder!.starred,
                                        shared: file?.shared ?? folder!.shared,
                                      ),
                                      tooltip:
                                          'Actions for ${file?.name ?? folder!.name}',
                                      sectionsBuilder: (_) => menu(),
                                    ),
                                    name: file?.name ?? folder!.name,
                                    subtitle: folder == null
                                        ? formatFileSize(file!.size)
                                        : '${folder.recursiveFileCount} files · ${formatFileSize(folder.recursiveSize)}',
                                    file: file,
                                    isFolder: folder != null,
                                    starred: file?.starred ?? folder!.starred,
                                    shared: file?.shared ?? folder!.shared,
                                    selected: selectMode
                                        ? (file != null
                                              ? selectedFiles.contains(id)
                                              : selectedFolders.contains(id))
                                        : null,
                                    onTap: open,
                                    onMore: more,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                      SliverToBoxAdapter(
                        child: SizedBox(height: selectMode ? 24 : 48),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selectMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: selection(actionsOnly: true),
              ),
          ],
        ),
      ),
    );
  }
}

/// Filled variant of a space symbol for the tinted badge.
IconData _filled(IconData icon) => switch (icon) {
  CupertinoIcons.archivebox => CupertinoIcons.archivebox_fill,
  CupertinoIcons.lock => CupertinoIcons.lock_fill,
  CupertinoIcons.trash => CupertinoIcons.trash_fill,
  _ => icon,
};
