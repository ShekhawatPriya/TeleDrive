import 'package:flutter/widgets.dart';
import '../../../models/drive_models.dart';
import '../photos_filter.dart';

/// One browsing session, independent of refresh/reorder and widget lifetimes.
/// No credentials or media bytes are placed in route arguments.
class PhotoViewerSession {
  PhotoViewerSession({
    required this.filter,
    required this.query,
    required this.currentId,
    required this.generation,
    this.sourceRect,
    this.revealSource,
  });
  final PhotosFilter filter;
  final String query;
  final int generation;
  String currentId;
  final Rect? Function(String id)? sourceRect;
  final Future<Rect?> Function(String id)? revealSource;
  List<String> orderedIds = [];
  int _index = 0;

  List<DriveFile> reconcile(List<DriveFile> loaded) {
    final needle = query.trim().toLowerCase();
    final files = loaded
        .where(
          (f) =>
              filter.accepts(f) &&
              (needle.isEmpty || f.name.toLowerCase().contains(needle)),
        )
        .toList();
    final found = files.indexWhere((f) => f.id == currentId);
    _index = found >= 0
        ? found
        : _index.clamp(0, files.isEmpty ? 0 : files.length - 1);
    if (files.isNotEmpty) currentId = files[_index].id;
    orderedIds = files.map((f) => f.id).toList(growable: false);
    return files;
  }

  int get index => _index;
  void select(int index) {
    if (index < 0 || index >= orderedIds.length) return;
    _index = index;
    currentId = orderedIds[index];
  }
}
