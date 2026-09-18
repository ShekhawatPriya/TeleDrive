import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/drive_models.dart';
import '../../models/share_models.dart';
import '../../widgets/sheet/adaptive_sheet.dart';
import '../auth/auth_controller.dart';
import 'components/copy_share_progress_sheet.dart';
import 'components/create_share_sheet.dart';
import 'components/share_choice_sheet.dart';
import 'copy_share_controller.dart';
import 'file_copy_share_service.dart';

typedef NativeFileShare = Future<void> Function(List<XFile> files, Rect origin);
final nativeFileShareProvider = Provider<NativeFileShare>(
  (ref) => (files, origin) async {
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        fileNameOverrides: files.map((file) => file.name).toList(),
        sharePositionOrigin: origin,
      ),
    );
  },
);

class ShareFlowState extends ChangeNotifier {
  bool _busy = false;
  bool _disposed = false;
  bool get busy => _busy;
  set busy(bool value) {
    if (_busy == value) return;
    _busy = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final shareFlowStateProvider = ChangeNotifierProvider(
  (ref) => ShareFlowState(),
);

Future<void> openItemShare(
  BuildContext context,
  WidgetRef ref, {
  required List<DriveFile> files,
  Set<String> folderIds = const {},
}) async {
  if (files.isEmpty && folderIds.isEmpty) return;
  final gate = ref.read(shareFlowStateProvider);
  if (gate.busy) return;
  final auth = ref.read(authControllerProvider);
  if (auth.user == null || auth.switchingAccount) return;
  Object identity() => (
    auth.user?.userId,
    auth.user?.telegramId,
    auth.token,
    auth.switchingAccount,
  );
  final owner = identity();
  var invalidated = false;
  CopyShareController? job;
  void accountChanged() {
    if (identity() != owner) {
      invalidated = true;
      job?.cancel();
    }
  }

  bool valid() => context.mounted && !invalidated && identity() == owner;
  gate.busy = true;
  auth.addListener(accountChanged);
  try {
    ModalRoute<dynamic>? choiceRoute;
    final choice = await showAdaptiveSheet<ShareChoice>(
      context: context,
      builder: (sheetContext) {
        choiceRoute = ModalRoute.of(sheetContext);
        return ShareChoiceSheet(
          count: files.length + folderIds.length,
          includesFolders: folderIds.isNotEmpty,
        );
      },
    );
    // Finish the Flutter sheet's dismissal before presenting another sheet.
    await choiceRoute?.completed;
    if (!context.mounted || !valid() || choice == null) return;
    if (choice == ShareChoice.link) {
      await showAdaptiveSheet<void>(
        context: context,
        builder: (_) => CreateShareSheet(
          isCurrent: valid,
          items: [
            for (final file in files)
              ShareItemRequest(type: ShareItemType.file, id: file.id),
            for (final id in folderIds)
              ShareItemRequest(
                type: ShareItemType.folder,
                id: id,
                mode: FolderShareMode.snapshot,
              ),
          ],
        ),
      );
      return;
    }
    if (folderIds.isNotEmpty)
      return; // Never silently omit folders from a copy.
    final preparation = job = CopyShareController(
      ref.read(fileCopyShareServiceProvider),
      files,
    );
    final done = preparation.start();
    // Cached originals should go straight to the OS sheet without a progress flash.
    final delay = Completer<void>();
    final timer = Timer(const Duration(milliseconds: 200), delay.complete);
    try {
      await Future.any([done, delay.future]);
    } finally {
      timer.cancel();
    }
    if (!context.mounted || !valid()) return;
    if (preparation.busy || preparation.error != null) {
      ModalRoute<dynamic>? progressRoute;
      final accepted = await showAdaptiveSheet<bool>(
        context: context,
        builder: (sheetContext) {
          progressRoute = ModalRoute.of(sheetContext);
          return CopyShareProgressSheet(controller: preparation);
        },
      );
      await progressRoute?.completed;
      if (accepted != true) {
        preparation.cancel();
        return;
      }
    }
    final copies = preparation.result;
    if (!context.mounted ||
        !valid() ||
        preparation.cancelled ||
        copies == null ||
        copies.isEmpty)
      return;
    final box = context.findRenderObject() as RenderBox?;
    final size = MediaQuery.sizeOf(context);
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
    await ref.read(nativeFileShareProvider)(copies, origin);
  } catch (_) {
    if (context.mounted && valid())
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open sharing. Please try again.'),
        ),
      );
  } finally {
    job?.dispose();
    auth.removeListener(accountChanged);
    gate.busy = false;
  }
}
