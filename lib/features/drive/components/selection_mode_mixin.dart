import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drive_item_actions.dart';
import '../../auth/auth_controller.dart';

/// Mixin for screens that support a multi-select mode. Tracks
/// [selectMode] plus the file and folder id sets and exposes helpers for
/// entering, exiting, and toggling selections.
mixin SelectionModeMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authControllerProvider.select((auth) => auth.user?.userId),
      (previous, next) {
        if (previous == next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) exitSelect();
        });
      },
    );
  }

  bool selectMode = false;
  final Set<String> selectedFileIds = {};
  final Set<String> selectedFolderIds = {};

  int get selectedCount => selectedFileIds.length + selectedFolderIds.length;

  void enterSelect({String? fileId, String? folderId}) {
    setState(() {
      selectMode = true;
      if (fileId != null) selectedFileIds.add(fileId);
      if (folderId != null) selectedFolderIds.add(folderId);
    });
  }

  void exitSelect() {
    setState(() {
      selectMode = false;
      selectedFileIds.clear();
      selectedFolderIds.clear();
    });
  }

  void toggleFileSelection(String id) {
    setState(() {
      if (!selectedFileIds.add(id)) selectedFileIds.remove(id);
    });
  }

  void toggleFolderSelection(String id) {
    setState(() {
      if (!selectedFolderIds.add(id)) selectedFolderIds.remove(id);
    });
  }

  Future<void> bulkShare(BuildContext context) async {
    await DriveBulkActions.share(
      context,
      ref,
      fileIds: Set.of(selectedFileIds),
      folderIds: Set.of(selectedFolderIds),
    );
  }

  Future<void> bulkStar() async {
    await DriveBulkActions.star(
      ref,
      fileIds: Set.of(selectedFileIds),
      folderIds: Set.of(selectedFolderIds),
    );
    if (mounted) exitSelect();
  }

  Future<void> bulkMove(BuildContext context, {String? currentParentId}) async {
    await DriveBulkActions.move(
      context,
      ref,
      fileIds: Set.of(selectedFileIds),
      folderIds: Set.of(selectedFolderIds),
      currentParentId: currentParentId,
    );
    if (mounted) exitSelect();
  }

  Future<void> bulkDelete(BuildContext context) async {
    final ok = await DriveBulkActions.delete(
      context,
      ref,
      fileIds: Set.of(selectedFileIds),
      folderIds: Set.of(selectedFolderIds),
    );
    if (ok && mounted) exitSelect();
  }
}
