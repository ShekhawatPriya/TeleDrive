import 'package:intl/intl.dart';

import '../../../models/drive_models.dart';

class PhotoDateSection {
  const PhotoDateSection({required this.label, required this.files});
  final String label;
  final List<DriveFile> files;
}

List<PhotoDateSection> groupByDate(List<DriveFile> files) {
  if (files.isEmpty) return const [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(const Duration(days: 6));

  final buckets = <String, List<DriveFile>>{};
  final order = <String>[];

  for (final file in files) {
    final date = DateTime.tryParse(file.createdAt)?.toLocal();
    final day = date == null
        ? today
        : DateTime(date.year, date.month, date.day);
    final String label;
    if (date == null) {
      label = 'Date unknown';
    } else if (day == today) {
      label = 'Today';
    } else if (day == yesterday) {
      label = 'Yesterday';
    } else if (day.isAfter(weekStart) || day == weekStart) {
      label = DateFormat('EEEE').format(date);
    } else if (day.year == today.year) {
      label = DateFormat('MMMM').format(date);
    } else {
      label = DateFormat('MMMM y').format(date);
    }
    if (!buckets.containsKey(label)) order.add(label);
    buckets.putIfAbsent(label, () => []).add(file);
  }

  return [
    for (final label in order)
      PhotoDateSection(label: label, files: buckets[label]!),
  ];
}
