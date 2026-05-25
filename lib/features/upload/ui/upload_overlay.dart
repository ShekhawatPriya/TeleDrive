import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../upload_controller.dart';
import 'components/upload_collapsed_bar.dart';
import 'upload_sheet.dart';

/// Bottom-anchored entry point for the redesigned upload experience.
///
/// Shows the collapsed pill while uploads (or a preceding error) are in
/// flight; tapping the pill opens the full [UploadSheet] as a modal
/// bottom sheet.
class UploadOverlay extends ConsumerWidget {
  const UploadOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      uploadControllerProvider.select((c) => c.summary),
    );
    if (!summary.sheetVisible || summary.itemCount == 0) {
      return const SizedBox.shrink();
    }
    return UploadCollapsedBar(
      summary: summary,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
        barrierColor: Colors.black.withValues(alpha: .35),
        builder: (_) => const UploadSheet(),
      ),
    );
  }
}
