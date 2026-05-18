import 'package:flutter/material.dart';

enum ShareExpiryOption { hour1, day1, week1, month1, never }

extension ShareExpiryOptionX on ShareExpiryOption {
  String get label => switch (this) {
    ShareExpiryOption.hour1 => '1 hour',
    ShareExpiryOption.day1 => '24 hours',
    ShareExpiryOption.week1 => '7 days',
    ShareExpiryOption.month1 => '30 days',
    ShareExpiryOption.never => 'Never',
  };

  DateTime? toExpiry() {
    final now = DateTime.now().toUtc();
    return switch (this) {
      ShareExpiryOption.hour1 => now.add(const Duration(hours: 1)),
      ShareExpiryOption.day1 => now.add(const Duration(days: 1)),
      ShareExpiryOption.week1 => now.add(const Duration(days: 7)),
      ShareExpiryOption.month1 => now.add(const Duration(days: 30)),
      ShareExpiryOption.never => null,
    };
  }
}

class ShareExpiryPicker extends StatelessWidget {
  const ShareExpiryPicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ShareExpiryOption value;
  final ValueChanged<ShareExpiryOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Expires', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in ShareExpiryOption.values)
              ChoiceChip(
                label: Text(option.label),
                selected: value == option,
                onSelected: (_) => onChanged(option),
              ),
          ],
        ),
      ],
    );
  }
}
