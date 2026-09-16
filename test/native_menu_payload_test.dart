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
}
