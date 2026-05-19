import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../upload_controller.dart';
import 'components/upload_card.dart';
import 'components/upload_sheet_header.dart';

/// Expanded upload sheet.  No close/cancel buttons — dismissed only by
/// swiping down or tapping the dimmed barrier.
class UploadSheet extends ConsumerWidget {
  const UploadSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(uploadControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .62,
      minChildSize: .4,
      maxChildSize: .92,
      snap: true,
      snapSizes: const [0.62, 0.92],
      builder: (context, controller) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) {
            if (n.extent < 0.32 && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            return false;
          },
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.sheet),
              ),
              border: Border(top: BorderSide(color: scheme.outline)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: UploadSheetHeader(upload: upload),
                ),
                Container(height: 1, color: scheme.outline),
                Expanded(
                  child: _CardList(upload: upload, controller: controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.upload, required this.controller});
  final UploadController upload;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: upload.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = upload.items[i];
        return UploadCard(key: ValueKey(item.localId), item: item);
      },
    );
  }
}
