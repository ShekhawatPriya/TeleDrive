import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import '../../../core/media/item_preview_loader.dart';
import '../../../core/utils/safe_navigation.dart';
import '../../../models/share_models.dart';
import '../../../widgets/ios_more_menu.dart';
import '../../../widgets/native_item_context_menu.dart';
import '../../auth/auth_controller.dart';
import '../../drive/components/drive_dialogs.dart';
import '../../drive/drive_controller.dart';
import '../share_controller.dart';

/// Shared links retain their own access actions, using the same native hold
/// surface and fresh, account-scoped menu snapshots as private Drive items.
class ShareItemMenu extends ConsumerWidget {
  const ShareItemMenu({
    required this.share,
    required this.child,
    this.trailingClearance = 0,
    super.key,
  });
  final Share share;
  final Widget child;
  final double trailingClearance;

  static List<IosMenuSection> sections(
    BuildContext context,
    WidgetRef ref,
    Share source,
  ) {
    final account = _scope(ref);
    Share? current() {
      if (!context.mounted || account != _scope(ref)) return null;
      return ref
          .read(shareControllerProvider)
          .shares
          .where((s) => s.id == source.id)
          .firstOrNull;
    }

    final share = current();
    if (share == null) return [];
    return [
      IosMenuSection([
        IosMenuItem(
          label: 'Open',
          leadingIcon: CupertinoIcons.arrow_up_right,
          onTap: () {
            if (current() != null) context.safePush('/shared/${share.id}');
          },
        ),
      ]),
      if (share.isActive)
        IosMenuSection([
          IosMenuItem(
            label: 'Copy link',
            leadingIcon: CupertinoIcons.link,
            onTap: () async {
              final value = current();
              if (value == null || !value.isActive) return;
              await Clipboard.setData(ClipboardData(text: value.url));
              if (context.mounted && current() != null)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Link copied')));
            },
          ),
          IosMenuItem(
            label: 'Share link',
            leadingIcon: CupertinoIcons.square_arrow_up,
            onTap: () {
              final value = current();
              if (value == null || !value.isActive) return;
              final box = context.findRenderObject();
              share_plus.SharePlus.instance.share(
                share_plus.ShareParams(
                  text: value.url,
                  subject: value.displayName,
                  sharePositionOrigin: box is RenderBox
                      ? box.localToGlobal(Offset.zero) & box.size
                      : Rect.zero,
                ),
              );
            },
          ),
        ]),
      if (share.isActive)
        IosMenuSection([
          IosMenuItem(
            label: 'Revoke link',
            leadingIcon: Icons.link_off_outlined,
            destructive: true,
            onTap: () async {
              if (current() == null) return;
              final ok = await confirmAction(
                context,
                title: 'Revoke share?',
                message:
                    'The link will stop working immediately and cannot be restored.',
                confirmLabel: 'Revoke',
              );
              final value = current();
              if (!ok || value == null || !value.isActive) return;
              try {
                await ref
                    .read(shareControllerProvider)
                    .revokeShare(value.id, detail: value);
              } catch (_) {
                if (context.mounted && current() != null)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not revoke link. Try again.'),
                    ),
                  );
              }
            },
          ),
        ]),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).platform != TargetPlatform.iOS) return child;
    final account = ref.watch(
      authControllerProvider.select(
        (auth) => (auth.user?.userId, auth.user?.telegramId, auth.token),
      ),
    );
    final primary = share.items
        .where((item) => item.fileId != null)
        .firstOrNull;
    final file = primary == null
        ? null
        : ref.watch(driveControllerProvider).file(primary.fileId!);
    bool valid() =>
        context.mounted &&
        account == _scope(ref) &&
        ref.read(shareControllerProvider).shares.any((s) => s.id == share.id);
    return NativeItemContextMenu(
      identity: '${account.$1}:${account.$2}:share:${share.id}',
      title: share.displayName,
      subtitle: '${share.fileCount} files · ${share.permission.label}',
      previewSymbol: share.isFolder ? 'folder.fill' : 'link',
      hasVisualPreview: file != null,
      previewRevision:
          '${file?.modifiedAt}:${file?.thumbnailVersion}:${file?.previewVersion}',
      previewLoader: file == null
          ? null
          : (token) async {
              if (!valid()) return null;
              final result = await ref
                  .read(itemPreviewLoaderProvider)
                  .load(file, token);
              return valid() ? result : null;
            },
      trailingClearance: trailingClearance,
      onOpen: () {
        if (valid()) context.safePush('/shared/${share.id}');
      },
      sectionsBuilder: () => valid() ? sections(context, ref, share) : [],
      child: child,
    );
  }
}

Object _scope(WidgetRef ref) {
  final auth = ref.read(authControllerProvider);
  return (auth.user?.userId, auth.user?.telegramId, auth.token);
}
