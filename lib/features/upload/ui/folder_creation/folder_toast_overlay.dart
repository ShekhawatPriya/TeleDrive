import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'folder_toast.dart';
import 'folder_toast_controller.dart';

class FolderToastOverlay extends ConsumerWidget {
  const FolderToastOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(folderToastControllerProvider).value;
    return IgnorePointer(child: FolderToast(state: state));
  }
}
