import 'package:flutter/material.dart';

import '../../../models/share_models.dart';

class SharePermissionPicker extends StatelessWidget {
  const SharePermissionPicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final SharePermission value;
  final ValueChanged<SharePermission> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Permission', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<SharePermission>(
          segments: const [
            ButtonSegment(
              value: SharePermission.preview,
              label: Text('Preview only'),
              icon: Icon(Icons.visibility_outlined),
            ),
            ButtonSegment(
              value: SharePermission.download,
              label: Text('Allow download'),
              icon: Icon(Icons.download_outlined),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          value == SharePermission.preview
              ? 'Recipients can preview but cannot download.'
              : 'Recipients can download the original file.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
