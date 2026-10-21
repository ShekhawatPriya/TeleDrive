import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../upload/ui/components/status_capsule.dart';
import '../drive_controller.dart';

/// Deletion status beside Add. It is the same [StatusCapsule] as the upload
/// status, so concurrent operations read as one family: red trash ring while
/// deleting, green check when done, orange/red when some items failed.
/// Renders nothing while no delete is in flight.
class DeleteProgressPill extends ConsumerWidget {
  const DeleteProgressPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(driveControllerProvider).state.deleteProgress;
    if (progress == null) return const SizedBox.shrink();

    final total = progress.total;
    final completed = progress.completed;
    final failed = progress.failed;
    final done = completed >= total;
    final hasFailures = failed > 0;
    final value = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final noun = total == 1 ? 'item' : 'items';

    final String title;
    final String detail;
    if (done && hasFailures) {
      title = 'Could not delete $failed of $total';
      detail = '${total - failed} deleted';
    } else if (done) {
      title = '$total $noun deleted';
      detail = 'Done';
    } else {
      final remaining = total - completed;
      title = 'Deleting $remaining ${remaining == 1 ? 'item' : 'items'}…';
      detail = '$completed of $total deleted';
    }

    final Color tint = CupertinoDynamicColor.resolve(
      done && hasFailures
          ? (failed < total
                ? CupertinoColors.systemOrange
                : CupertinoColors.systemRed)
          : done
          ? CupertinoColors.systemGreen
          : CupertinoColors.systemRed,
      context,
    );

    return StatusCapsule(
      title: title,
      detail: detail,
      trailing: done ? null : '${(value * 100).floor()}%',
      tint: tint,
      icon: done && hasFailures
          ? CupertinoIcons.exclamationmark
          : done
          ? CupertinoIcons.checkmark_alt
          : CupertinoIcons.trash,
      materialIcon: done && hasFailures
          ? Icons.error_outline
          : done
          ? Icons.check_rounded
          : Icons.delete_outline_rounded,
      progress: done ? null : value,
      attention: hasFailures,
      semanticLabel: '$title. $detail',
    );
  }
}
