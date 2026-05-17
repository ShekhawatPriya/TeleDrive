import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/file_type_detector.dart';
import 'upload_controller.dart';

class UploadMiniOverlay extends ConsumerWidget {
  const UploadMiniOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(uploadControllerProvider);
    if (!upload.sheetVisible || (upload.items.isEmpty && upload.error == null))
      return const SizedBox.shrink();
    final progress = upload.items.isEmpty
        ? 0.0
        : upload.items.fold<double>(0, (sum, i) => sum + i.progress) /
              upload.items.length;
    return Card(
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const UploadBatchSheet(),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.cloud_upload_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      upload.items.isEmpty
                          ? 'Upload needs attention'
                          : upload.uploading
                          ? 'Uploading ${upload.items.length} files'
                          : '${upload.items.length} files selected',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (upload.error != null && upload.items.isEmpty)
                      Text(
                        upload.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else
                      LinearProgressIndicator(
                        value: upload.uploading ? progress.clamp(0, 1) : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UploadBatchSheet extends ConsumerWidget {
  const UploadBatchSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(uploadControllerProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      minChildSize: .35,
      maxChildSize: .92,
      builder: (_, controller) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upload batch',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: upload.uploading
                        ? upload.cancelUpload
                        : upload.dismiss,
                    icon: Icon(
                      upload.uploading
                          ? Icons.stop_circle_outlined
                          : Icons.close,
                    ),
                  ),
                ],
              ),
            ),
            if (upload.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  upload.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: upload.items.length,
                itemBuilder: (_, i) {
                  final item = upload.items[i];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _canCancel(item)
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Cancel this upload',
                            onPressed: () => ref
                                .read(uploadControllerProvider)
                                .cancelItem(item.localId),
                          )
                        : null,
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatFileSize(item.size)} • ${item.status.name}',
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: item.progress.clamp(0, 1),
                        ),
                        if (item.error != null)
                          Text(
                            item.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (!upload.uploading && upload.items.isNotEmpty)
                    Expanded(
                      child: FilledButton(
                        onPressed: upload.confirmUpload,
                        child: const Text('Upload'),
                      ),
                    ),
                  if (upload.failedCount > 0) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: upload.retryFailed,
                        child: const Text('Retry failed'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _canCancel(UploadItem item) => {
  UploadStatus.queued,
  UploadStatus.stagingToBackend,
  UploadStatus.waitingForServer,
  UploadStatus.uploadingToTelegram,
  UploadStatus.processing,
}.contains(item.status);
