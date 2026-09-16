import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/media_thumb.dart';

/// Uses the actual first item in the current library, never synthetic memories.
class PhotoLibraryCover extends StatelessWidget {
  const PhotoLibraryCover({required this.file, required this.onTap, super.key});
  final DriveFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(file.createdAt)?.toLocal();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Semantics(
        button: true,
        label: 'Open ${file.name}',
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height:
                  240 + (MediaQuery.textScalerOf(context).scale(24) - 24) * 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaThumb(
                    file: file,
                    fit: BoxFit.cover,
                    radius: 0,
                    decodeWidth: 960,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xD9000000)],
                        stops: [.25, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IN YOUR LIBRARY',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          date == null
                              ? 'A closer look'
                              : DateFormat('MMMM yyyy').format(date),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
