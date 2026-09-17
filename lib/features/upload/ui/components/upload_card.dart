import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../../../core/utils/iterable_ext.dart';
import '../../../../models/drive_models.dart';
import '../../upload_controller.dart';
import '../../upload_models.dart';
import '../upload_status_label.dart';
import 'upload_progress_bar.dart';
import 'upload_thumb_slot.dart';

/// Compact transfer row; item subscriptions keep progress updates local.
class UploadCard extends ConsumerWidget {
  const UploadCard({required this.localId, super.key});
  final String localId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
      uploadControllerProvider.select(
        (c) => c.items.firstWhereOrNull((i) => i.localId == localId),
      ),
    );
    if (item == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final largeText = MediaQuery.textScalerOf(context).scale(17) > 24;
    final active = uploadIsActive(item.status);
    final uploaded = item.status == UploadStatus.uploaded;
    final failed = item.status == UploadStatus.failed;
    final cancelled = item.status == UploadStatus.cancelled;
    final preparing =
        item.status == UploadStatus.preparingMetadata ||
        item.status == UploadStatus.creatingThumbnail ||
        item.status == UploadStatus.creatingPreview;
    final status =
        uploaded &&
            !item.thumbnailReady &&
            {
              FileKind.image,
              FileKind.video,
            }.contains(detectFileKind(item.name, item.mimeType))
        ? 'Uploaded · Finishing preview'
        : uploadStatusLabel(item.status);

    Widget action({
      required String label,
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      final glyph = Icon(icon, size: 20, color: scheme.onSurfaceVariant);
      if (ios) {
        return Semantics(
          label: '$label ${item.name}',
          button: true,
          child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: CupertinoButton(
              padding: const EdgeInsets.all(12),
              minimumSize: const Size.square(48),
              onPressed: onPressed,
              child: glyph,
            ),
          ),
        );
      }
      return IconButton(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        tooltip: '$label ${item.name}',
        onPressed: onPressed,
        icon: glyph,
      );
    }

    return Container(
      decoration: ios
          ? null
          : BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: AppRadii.lgR,
            ),
      padding: EdgeInsets.fromLTRB(ios ? 20 : 16, 12, ios ? 12 : 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: UploadThumbSlot(item: item, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: largeText ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${formatFileSize(item.size)} · $status',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: failed
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (uploaded)
                      SizedBox.square(
                        dimension: 48,
                        child: Icon(
                          ios ? CupertinoIcons.check_mark : Icons.check_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else if (failed || cancelled)
                      action(
                        label: 'Dismiss',
                        icon: ios ? CupertinoIcons.xmark : Icons.close_rounded,
                        onPressed: () => ref
                            .read(uploadControllerProvider)
                            .removeFailed(item.localId),
                      )
                    else if (item.status == UploadStatus.cancelling)
                      SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: MediaQuery.disableAnimationsOf(context)
                              ? Icon(
                                  ios
                                      ? CupertinoIcons.ellipsis
                                      : Icons.more_horiz,
                                  size: 20,
                                )
                              : ios
                              ? const CupertinoActivityIndicator(radius: 8)
                              : const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                        ),
                      )
                    else
                      action(
                        label: 'Cancel',
                        icon: ios ? CupertinoIcons.xmark : Icons.close_rounded,
                        onPressed: () => ref
                            .read(uploadControllerProvider)
                            .cancelItem(item.localId),
                      ),
                  ],
                ),
                if (active)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 12,
                      right: 8,
                      bottom: 4,
                    ),
                    child: UploadProgressBar(
                      value: item.progress,
                      height: 3,
                      indeterminate: preparing,
                    ),
                  ),
                if (failed) ...[
                  if (item.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: Text(
                        item.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ),
                  // The existing controller retries the batch's failed items.
                  if (ios)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(48, 48),
                      alignment: Alignment.centerLeft,
                      onPressed: () =>
                          ref.read(uploadControllerProvider).confirmUpload(),
                      child: Text(
                        'Retry uploads',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () =>
                          ref.read(uploadControllerProvider).confirmUpload(),
                      child: const Text('Retry uploads'),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
