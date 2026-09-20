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

  void submit() {
    _debounce?.cancel();
    _normalized = _raw.trim().toLowerCase();
    notifyListeners();
  }

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
