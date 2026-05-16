import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/storage/local_preferences.dart';
import '../drive/drive_controller.dart';

final themeControllerProvider = ChangeNotifierProvider<ThemeController>((ref) {
  return ThemeController(ref.watch(localPreferencesProvider))..load();
});

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs);

  final LocalPreferences _prefs;
  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    mode = _parse(await _prefs.themeMode());
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    mode = value;
    notifyListeners();
    await _prefs.setThemeMode(value.name);
  }

  ThemeMode _parse(String value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
