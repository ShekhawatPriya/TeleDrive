import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/widgets/ios_menu/native_menu_payload.dart';
import 'package:flutter_m_fsdk/widgets/ios_menu/ios_menu_models.dart';

void main() {
  test(
    'native menus group layout and sorting while preserving every action',
    () {
      final calls = <String>[];
      final payload = NativeMenuPayload([
        IosMenuSection([
          IosMenuItem(label: 'Select', onTap: () => calls.add('Select')),
        ]),
        IosMenuSection([
          for (final label in ['Icons', 'List'])
            IosMenuItem(
              label: label,
              checked: label == 'List',
              onTap: () => calls.add(label),
            ),
        ]),
        IosMenuSection([
          for (final label in ['Name', 'Kind', 'Date', 'Size'])
            IosMenuItem(
              label: label,
              subtitle: label == 'Name' ? 'A to Z' : null,
              onTap: () => calls.add(label),
            ),
        ]),
      ]);
      expect(payload.sections.map((s) => s['title']), [
        '',
        'View as',
        'Sort by',
      ]);
      expect((payload.sections[1]['items'] as List)[1]['checked'], isTrue);
      expect((payload.sections[2]['items'] as List)[0]['subtitle'], 'A to Z');
      for (final action in payload.actions.values) {
        action();
      }
      expect(calls, [
        'Select',
        'Icons',
        'List',
        'Name',
        'Kind',
        'Date',
        'Size',
      ]);
    },
  );
  test(
    'recovery and link menus include UIKit symbols and destructive roles',
    () {
      final payload = NativeMenuPayload([
        IosMenuSection([
          for (final label in [
            'Restore',
            'Unarchive',
            'Unlock',
            'Copy link',
            'Share link',
            'Revoke link',
            'Revoke share',
            'Delete forever',
            'Move to Trash',
            'Delete All',
          ])
            IosMenuItem(
              label: label,
              destructive: [
                'Revoke link',
                'Revoke share',
                'Delete forever',
                'Move to Trash',
                'Delete All',
              ].contains(label),
              onTap: () {},
            ),
        ]),
      ]);
      final items = payload.sections.single['items'] as List;
      expect(
        items.every((item) => (item['symbol'] as String).isNotEmpty),
        isTrue,
      );
      expect(items.where((item) => item['destructive'] == true), hasLength(5));
      for (final label in ['Revoke link', 'Revoke share']) {
        expect(
          items.firstWhere((item) => item['label'] == label)['symbol'],
          'teledrive.link-off',
        );
      }
    },
  );
}
