import 'package:flutter_m_fsdk/core/storage/local_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('falls back when stored JSON is malformed', () async {
    SharedPreferences.setMockInitialValues({
      'teledrive_sort': 'not-json',
      'teledrive_recent_access_7': '[]',
    });
    final preferences = LocalPreferences();

    expect(await preferences.sortPreference(), {
      'field': 'name',
      'ascending': true,
    });
    expect(await preferences.recentAccess(userId: 7), isEmpty);
  });
}
