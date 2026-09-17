import 'package:flutter/foundation.dart';
import 'ios_menu_models.dart';

/// One snapshot per opening keeps callbacks and UIKit's checked state in sync.
class NativeMenuPayload {
  NativeMenuPayload(List<IosMenuSection> source) {
    var next = 0;
    for (final section in source) {
      final labels = section.items.map((item) => item.label).toSet();
      final layout = labels.containsAll({'Icons', 'List'});
      final sort = labels.containsAll({'Name', 'Kind', 'Size', 'Date'});
      sections.add({
        'title': layout
            ? 'View as'
            : sort
            ? 'Sort by'
            : '',
        'symbol': layout
            ? 'square.grid.2x2'
            : sort
            ? 'arrow.up.arrow.down'
            : '',
        'items': [for (final item in section.items) _item(item, '${next++}')],
      });
    }
  }
  final sections = <Map<String, Object?>>[];
  final actions = <String, VoidCallback>{};
  Map<String, Object?> _item(IosMenuItem item, String id) {
    actions[id] = item.onTap;
    return {
      'id': id,
      'label': item.label,
      'checked': item.checked,
      'destructive': item.destructive,
      'subtitle': item.subtitle,
      'symbol': switch (item.label) {
        'Open' => 'arrow.up.forward.app',
        'Share' => 'square.and.arrow.up',
        'Revoke share' => 'link',
        'Download' => 'square.and.arrow.down',
        'Move' => 'folder',
        'Rename' => 'pencil',
        'Star' => 'star',
        'Unstar' => 'star.slash',
        'Lock' => 'lock',
        'Archive' => 'archivebox',
        'Delete' => 'trash',
        'Select' => 'checkmark.circle',
        'New Folder' => 'folder.badge.plus',
        'Scan Documents' => 'doc.viewfinder',
        'Icons' => 'square.grid.2x2',
        'List' => 'list.bullet',
        'Name' => 'textformat.abc',
        'Kind' => 'square.on.circle',
        'Size' => 'internaldrive',
        'Date' => 'calendar',
        'Refresh' => 'arrow.clockwise',
        'Smaller tiles' => 'square.grid.3x3',
        'Larger tiles' => 'square.grid.2x2',
        _ => '',
      },
    };
  }
}
