import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/file_type_detector.dart';
import '../copy_share_controller.dart';

class CopyShareProgressSheet extends StatefulWidget {
  const CopyShareProgressSheet({super.key, required this.controller});
  final CopyShareController controller;
  @override
  State<CopyShareProgressSheet> createState() => _CopyShareProgressSheetState();
}

class _CopyShareProgressSheetState extends State<CopyShareProgressSheet> {
  bool _closing = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  void _changed() {
    if (!mounted || _closing) return;
    final job = widget.controller;
    if (job.result != null || job.cancelled) {
      _closing = true;
      Navigator.of(context).pop(job.result != null && !job.cancelled);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.controller;
    final progress = job.progress;
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    Widget button(String label, VoidCallback onPressed) => ios
        ? CupertinoButton(onPressed: onPressed, child: Text(label))
        : TextButton(onPressed: onPressed, child: Text(label));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              job.error != null
                  ? 'Could not prepare files'
                  : 'Preparing to share',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            job.error ?? progress?.name ?? 'Preparing originals…',
            style: theme.textTheme.bodyLarge,
          ),
          if (job.error == null) ...[
            const SizedBox(height: 8),
            Text(
              progress == null
                  ? 'Checking availability'
                  : '${progress.preparingCopy ? 'Preparing original' : 'Downloading original'} · ${progress.index} of ${progress.count}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: progress?.fraction,
              minHeight: ios ? 4 : 6,
              borderRadius: BorderRadius.circular(4),
              semanticsLabel: 'Downloading original',
            ),
            const SizedBox(height: 8),
            Text(
              progress != null && !progress.preparingCopy && progress.total > 0
                  ? '${formatFileSize(progress.received)} of ${formatFileSize(progress.total)}'
                  : 'The share sheet will open when your files are ready.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              button('Cancel', job.cancel),
              if (job.error != null)
                button('Try again', () => unawaited(job.start())),
            ],
          ),
        ],
      ),
    );
  }
}
