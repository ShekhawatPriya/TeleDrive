import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../upload_controller.dart';
import 'components/upload_card.dart';
import 'components/upload_sheet_header.dart';

/// Expanded modal upload sheet. Listens for drags below the snap threshold
/// and dismisses; otherwise lays one [UploadCard] per file.
class UploadSheet extends ConsumerWidget {
  const UploadSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(uploadControllerProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .62,
      minChildSize: .4,
      maxChildSize: .92,
      snap: true,
      snapSizes: const [0.62, 0.92],
      builder: (context, controller) {
        final scheme = Theme.of(context).colorScheme;
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) {
            if (n.extent < 0.32 && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            return false;
          },
          child: Material(
            color: scheme.surfaceContainerLow,
            surfaceTintColor: scheme.surfaceTint,
            elevation: AppElevation.level3,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadii.sheetTop,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.xs),
                UploadSheetHeader(upload: upload),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.xs,
                        AppSpacing.md, AppSpacing.lg),
                    itemCount: upload.items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final item = upload.items[i];
                      return UploadCard(key: ValueKey(item.localId), item: item);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
