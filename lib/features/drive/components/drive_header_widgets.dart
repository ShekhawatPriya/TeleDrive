import 'package:flutter/material.dart';

import '../../../core/utils/file_type_detector.dart';

class DriveStoragePill extends StatelessWidget {
  const DriveStoragePill({required this.used, super.key});
  final int used;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatFileSize(used)} used',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: used > 0 ? 1 : 0,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriveSectionHeader extends StatelessWidget {
  const DriveSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}
