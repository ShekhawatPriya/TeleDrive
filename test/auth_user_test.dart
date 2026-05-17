import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads Telegram avatar from nested profile payloads', () {
    final user = AuthUser.fromMeJson({
      'user': {
        'id': 7,
        'telegram_id': 12345,
        'first_name': 'Sree',
        'last_name': 'Dev',
        'username': 'sree',
        'profile_photo': {'url': '/telegram/avatar/12345.jpg'},
      },
    });

    expect(user.displayName, 'Sree Dev');
    expect(user.username, 'sree');
    expect(user.photoUrl, '/telegram/avatar/12345.jpg');
  });

  test('preserves previous avatar when profile response omits it', () {
    const previous = AuthUser(
      userId: 7,
      telegramId: 12345,
      firstName: 'Sree',
      photoUrl: '/telegram/avatar/12345.jpg',
    );

    final user = AuthUser.fromMe({
      'profile': {'firstName': 'Sree', 'username': 'sree_dev'},
    }, previous);

    expect(user.username, 'sree_dev');
    expect(user.photoUrl, '/telegram/avatar/12345.jpg');
  });
}
