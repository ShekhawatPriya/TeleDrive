import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/drive_models.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import '../drive/drive_repository.dart';
import 'search_controller.dart';

final driveSearchProvider =
    ChangeNotifierProvider.autoDispose<DriveSearchController>((ref) {
      // A fresh controller per query/account prevents late responses crossing either boundary.
      ref.watch(authControllerProvider.select((auth) => auth.user?.userId));
      final query = ref.watch(
        searchQueryProvider(SearchScope.drive).select((search) => search.query),
      );
      final controller = DriveSearchController(
        ref.watch(driveRepositoryProvider),
        query,
        drive: ref.read(driveControllerProvider),
      );
      if (query.isNotEmpty) unawaited(controller.loadMore());
      return controller;
    });

class DriveSearchController extends ChangeNotifier {
  DriveSearchController(this._repository, this.query, {this.drive}) {
    drive?.addListener(_itemsChanged);
  }
  final DriveController? drive;
  void _itemsChanged() {
    if (_disposed) return;
    files = files.map((file) => drive?.anyFile(file.id) ?? file).toList();
    notifyListeners();
  }

  final DriveRepository _repository;
  final String query;
  List<DriveFile> files = const [];
  String? cursor;
  String? error;
  bool loading = false;
  bool loaded = false;
  bool _disposed = false;
  int _generation = 0;
  bool get hasMore => !loaded || cursor != null;

  Future<void> refresh() async {
    _generation++;
    loading = false;
    loaded = false;
    cursor = null;
    files = const [];
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_disposed || loading || !hasMore || query.isEmpty) return;
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _repository.listFiles(
        allFolders: true,
        query: query,
        cursor: cursor,
        limit: 60,
      );
      if (_disposed || generation != _generation) return;
      drive?.cacheSearchFiles(page.files);
      final seen = files.map((file) => file.id).toSet();
      files = [...files, ...page.files.where((file) => seen.add(file.id))];
      cursor = page.nextCursor;
      loaded = true;
    } catch (err) {
      if (_disposed || generation != _generation) return;
      error = _repository.api.errorMessage(err, 'Could not search your drive.');
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    drive?.removeListener(_itemsChanged);
    _generation++;
    super.dispose();
  }
}
