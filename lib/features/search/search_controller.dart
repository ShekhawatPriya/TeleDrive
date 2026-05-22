import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The four main-tab surfaces share the same navbar but each carries an
/// independent search query so switching tabs does not leak filter state
/// from one surface to another.
enum SearchScope { drive, photos, starred, shared }

/// Holds the active query string for one [SearchScope].
///
/// Writes are debounced (200ms) so per-keystroke rebuilds do not thrash
/// large lists; consumers `ref.watch(searchQueryProvider(scope))` and read
/// [query] (already lower-cased + trimmed) for filtering.
class SearchQueryController extends ChangeNotifier {
  String _raw = '';
  String _normalized = '';
  Timer? _debounce;

  static const _debounceDuration = Duration(milliseconds: 200);

  /// Raw text as the user typed it (preserves case + whitespace) — used to
  /// drive the `TextField`'s controller text.
  String get raw => _raw;

  /// Lower-cased, trimmed query used for `name.contains(...)` filtering.
  String get query => _normalized;

  bool get isActive => _normalized.isNotEmpty;

  void update(String value) {
    if (_raw == value) return;
    _raw = value;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      _normalized = value.trim().toLowerCase();
      notifyListeners();
    });
  }

  void clear() {
    _debounce?.cancel();
    if (_raw.isEmpty && _normalized.isEmpty) return;
    _raw = '';
    _normalized = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchQueryProvider =
    ChangeNotifierProvider.family<SearchQueryController, SearchScope>(
      (ref, scope) => SearchQueryController(),
    );

class RotatingPlaceholderController extends ChangeNotifier {
  RotatingPlaceholderController() {
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      _index = (_index + 1) % _phrases.length;
      notifyListeners();
    });
  }

  static const List<String> _phrases = [
    'Search files and folders',
    'Find a PDF',
    'Find a folder by name',
    'Search images & videos',
    'Search photos and videos',
    'Find by file name',
    'Find by date',
    'Search starred items',
    'Starred files',
    'Starred folders',
    'Search shared items',
    'Find a shared link',
    'Search by recipient name',
  ];

  Timer? _timer;
  int _index = 0;

  String get currentPhrase => _phrases[_index];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final rotatingPlaceholderProvider =
    ChangeNotifierProvider.autoDispose<RotatingPlaceholderController>((ref) {
      return RotatingPlaceholderController();
    });
