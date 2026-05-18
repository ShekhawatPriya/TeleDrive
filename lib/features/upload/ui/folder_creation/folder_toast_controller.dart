import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

class FolderToastState {
  const FolderToastState({
    required this.visible,
    required this.label,
    this.isError = false,
  });

  final bool visible;
  final String label;
  final bool isError;

  static const hidden = FolderToastState(visible: false, label: '');

  FolderToastState copyWith({bool? visible, String? label, bool? isError}) =>
      FolderToastState(
        visible: visible ?? this.visible,
        label: label ?? this.label,
        isError: isError ?? this.isError,
      );
}

class FolderToastController extends ValueNotifier<FolderToastState> {
  FolderToastController() : super(FolderToastState.hidden);

  Timer? _hideTimer;

  void show(String label) {
    _hideTimer?.cancel();
    value = FolderToastState(visible: true, label: label);
  }

  void hide() {
    _hideTimer?.cancel();
    value = FolderToastState.hidden;
  }

  void showError(String label, {Duration delay = const Duration(seconds: 2)}) {
    _hideTimer?.cancel();
    value = FolderToastState(visible: true, label: label, isError: true);
    _hideTimer = Timer(delay, hide);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}

final folderToastControllerProvider =
    ChangeNotifierProvider<FolderToastController>(
  (ref) => FolderToastController(),
);

/// Shows the toast, awaits [task], and hides on success.  On failure
/// briefly switches the toast to its error label, then hides — and
/// rethrows so callers keep their existing behavior.
Future<T> runWithFolderToast<T>(
  FolderToastController toast,
  Future<T> Function() task, {
  String label = 'Creating folder…',
  String errorLabel = "Couldn't create folder",
}) async {
  toast.show(label);
  try {
    final result = await task();
    toast.hide();
    return result;
  } catch (err) {
    toast.showError(errorLabel);
    rethrow;
  }
}
