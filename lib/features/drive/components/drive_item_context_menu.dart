import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/drive_models.dart';
import '../../../widgets/ios_more_menu.dart';
import '../../../widgets/native_item_context_menu.dart';
import '../../auth/auth_controller.dart';
import '../drive_controller.dart';
import 'drive_item_actions.dart';
import 'drive_sheet_action.dart';

/// The same item actions and confirmations serve menus and action sheets.
/// Resolve current model state on every opening and reject a stale account.
class DriveItemContextMenu extends ConsumerWidget {
  const DriveItemContextMenu({
    required this.child,
    required this.onOpen,
    required this.onSelect,
    this.file,
    this.folder,
    this.enabled = true,
    this.allowRename = true,
    this.trailingClearance = 0,
    super.key,
  });
  final Widget child;
  final DriveFile? file;
  final DriveFolder? folder;
  final VoidCallback onOpen, onSelect;
  final bool enabled, allowRename;
  final double trailingClearance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled ||
        Theme.of(context).platform != TargetPlatform.iOS ||
        (file?.isOptimistic ?? folder?.isOptimistic ?? true))
      return child;
    final account = ref.watch(
      authControllerProvider.select(
        (auth) => (auth.user?.userId, auth.user?.telegramId),
      ),
    );
    final id = file?.id ?? folder!.id;
    ref.watch(
      driveControllerProvider.select(
        (drive) => file != null ? drive.file(id) : drive.folder(id),
      ),
    );
    bool valid() =>
        context.mounted &&
        (
              ref.read(authControllerProvider).user?.userId,
              ref.read(authControllerProvider).user?.telegramId,
            ) ==
            account;
    return NativeItemContextMenu(
      identity: '$account:${file == null ? 'folder' : 'file'}:$id',
      title: file?.name ?? folder!.name,
      trailingClearance: trailingClearance,
      onOpen: () {
        if (valid()) onOpen();
      },
      sectionsBuilder: () {
        if (!valid()) return [];
        final drive = ref.read(driveControllerProvider);
        final currentFile = file == null ? null : drive.file(id) ?? file;
        final currentFolder = folder == null
            ? null
            : drive.folder(id) ?? folder;
        final actions = currentFile != null
            ? DriveItemActions.fileActions(currentFile)
            : DriveItemActions.folderActions(
                currentFolder!,
                allowRename: allowRename,
              );
        IosMenuItem item(SheetActionItem action) => IosMenuItem(
          label: action.label,
          leadingIcon: action.icon,
          destructive: action.destructive,
          onTap: () {
            if (!valid()) return;
            if (currentFile != null) {
              DriveItemActions.performFileAction(
                context,
                ref,
                currentFile,
                action.id,
              );
            } else {
              DriveItemActions.performFolderAction(
                context,
                ref,
                currentFolder!,
                action.id,
              );
            }
          },
        );
        return [
          IosMenuSection([
            IosMenuItem(
              label: 'Open',
              leadingIcon: CupertinoIcons.arrow_up_right,
              onTap: () {
                if (valid()) onOpen();
              },
            ),
            ...actions
                .where(
                  (a) => {
                    'share',
                    'revoke_share',
                    'download',
                    'star',
                  }.contains(a.id),
                )
                .map(item),
          ]),
          IosMenuSection([
            ...actions
                .where(
                  (a) => {'rename', 'move', 'lock', 'archive'}.contains(a.id),
                )
                .map(item),
            IosMenuItem(
              label: 'Select',
              leadingIcon: CupertinoIcons.check_mark_circled,
              onTap: () {
                if (valid()) onSelect();
              },
            ),
          ]),
          IosMenuSection(
            actions.where((a) => a.destructive).map(item).toList(),
          ),
        ];
      },
      child: child,
    );
  }
}
