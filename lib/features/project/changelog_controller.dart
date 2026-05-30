import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'changelog_service.dart';
import 'github_release_models.dart';

class ChangelogState {
  const ChangelogState({
    this.releases = const [],
    this.isLoading = false,
    this.error,
    this.hasLoadedOnce = false,
  });

  final List<GithubRelease> releases;
  final bool isLoading;
  final String? error;
  final bool hasLoadedOnce;

  /// The most recent release tag (e.g. for showing the latest version on the
  /// Project hub), or null when nothing has loaded yet.
  GithubRelease? get latest => releases.isNotEmpty ? releases.first : null;

  ChangelogState copyWith({
    List<GithubRelease>? releases,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? hasLoadedOnce,
  }) {
    return ChangelogState(
      releases: releases ?? this.releases,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

final changelogServiceProvider = Provider<ChangelogService>(
  (ref) => ChangelogService(),
);

final changelogControllerProvider = ChangeNotifierProvider<ChangelogController>(
  (ref) => ChangelogController(ref.watch(changelogServiceProvider)),
);

class ChangelogController extends ChangeNotifier {
  ChangelogController(this._service);

  final ChangelogService _service;
  Future<void>? _inFlight;

  ChangelogState _state = const ChangelogState();
  ChangelogState get state => _state;

  void _set(ChangelogState next) {
    _state = next;
    notifyListeners();
  }

  /// Loads releases. Skips the network call if data is already present unless
  /// [force] is set (used by pull-to-refresh / retry).
  Future<void> load({bool force = false}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    if (!force && _state.hasLoadedOnce && _state.error == null) {
      return Future.value();
    }
    final future = _run();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    _set(_state.copyWith(isLoading: true, clearError: true));
    try {
      final releases = await _service.fetchReleases();
      _set(
        _state.copyWith(
          releases: releases,
          isLoading: false,
          clearError: true,
          hasLoadedOnce: true,
        ),
      );
    } on ChangelogFetchException catch (e) {
      _set(
        _state.copyWith(
          isLoading: false,
          error: e.message,
          hasLoadedOnce: true,
        ),
      );
    } catch (_) {
      _set(
        _state.copyWith(
          isLoading: false,
          error: 'Something went wrong',
          hasLoadedOnce: true,
        ),
      );
    }
  }
}
