import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalPreferences {
  static const _themeKey = 'teledrive_theme_mode';
  static const _sortKey = 'teledrive_sort';
  static const _recentKey = 'teledrive_recent_access';

  String _recentKeyFor(int? userId) =>
      userId == null ? _recentKey : '${_recentKey}_$userId';

  Future<String> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<void> setThemeMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value);
  }

  Future<Map<String, dynamic>> sortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sortKey);
    if (raw == null) return {'field': 'name', 'ascending': true};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> setSortPreference(String field, bool ascending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sortKey,
      jsonEncode({'field': field, 'ascending': ascending}),
    );
  }

  Future<Map<String, String>> recentAccess({int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKeyFor(userId));
    if (raw == null) return {};
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    return parsed.map((key, value) => MapEntry(key, '$value'));
  }

  Future<void> setRecentAccess(Map<String, String> value, {int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentKeyFor(userId), jsonEncode(value));
  }
}
