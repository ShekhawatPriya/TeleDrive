import 'package:flutter/material.dart';

class DriveActionSheet extends StatelessWidget {
  const DriveActionSheet({
    required this.title,
    required this.actions,
    super.key,
  });

  final String title;
  final Map<String, IconData> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final entry in actions.entries)
              ListTile(
                leading: Icon(entry.value),
                title: Text(
                  entry.key[0].toUpperCase() + entry.key.substring(1),
                ),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
  }
}
