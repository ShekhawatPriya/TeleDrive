import 'package:flutter/material.dart';

/// Mixin for screens that support a multi-select mode.  Tracks
/// [selectMode] plus the file and folder id sets and exposes helpers for
/// entering, exiting, and toggling selections.  Hosting widget must call
/// [setState] indirectly via [updateSelection] so the screen rebuilds.
mixin SelectionModeMixin<T extends StatefulWidget> on State<T> {
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
}
