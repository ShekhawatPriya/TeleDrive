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
    final upload = ref.watch(uploadControllerProvider);
    if (!upload.sheetVisible || upload.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return UploadCollapsedBar(
      upload: upload,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .35),
        builder: (_) => const UploadSheet(),
      ),
    );
  }
}
