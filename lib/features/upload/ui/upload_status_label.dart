import '../../../core/utils/file_type_detector.dart';
import '../upload_models.dart';

/// Status line for a row: real transferred bytes and speed while the original
/// uploads ("45 MB of 160 MB · 2.1 MB/s"), otherwise size and phase.
String uploadRowDetail(UploadItem item, String status) {
  if (item.status != UploadStatus.uploadingOriginalToTelegram) {
    return '${formatFileSize(item.size)} · $status';
  }
  final line =
      '${formatFileSize(item.transferredBytes)} of ${formatFileSize(item.size)}';
  final speed = item.bytesPerSecond;
  if (speed == null || speed < 1) return line;
  return '$line · ${formatFileSize(speed.round())}/s';
}

/// User-facing label for an upload phase.
String uploadStatusLabel(UploadStatus status) {
  switch (status) {
    case UploadStatus.selected:
    case UploadStatus.queued:
      return 'Waiting';
    case UploadStatus.waitingForWifi:
      return 'Waiting for Wi-Fi';
    case UploadStatus.preparingMetadata:
      return 'Preparing';
    case UploadStatus.creatingThumbnail:
    case UploadStatus.creatingPreview:
      return 'Preparing preview';
    case UploadStatus.uploadingOriginalToTelegram:
    case UploadStatus.uploadingThumbnailToTelegram:
    case UploadStatus.uploadingPreviewToTelegram:
    case UploadStatus.committingMetadata:
      return 'Uploading';
    case UploadStatus.uploaded:
      return 'Uploaded';
    case UploadStatus.cancelling:
      return 'Stopping…';
    case UploadStatus.cancelled:
      return 'Cancelled';
    case UploadStatus.failed:
      return 'Failed';
  }
}

bool uploadIsActive(UploadStatus status) {
  return status == UploadStatus.preparingMetadata ||
      status == UploadStatus.creatingThumbnail ||
      status == UploadStatus.creatingPreview ||
      status == UploadStatus.uploadingOriginalToTelegram ||
      status == UploadStatus.uploadingThumbnailToTelegram ||
      status == UploadStatus.uploadingPreviewToTelegram ||
      status == UploadStatus.committingMetadata;
}

bool uploadIsTerminal(UploadStatus status) {
  return status == UploadStatus.uploaded ||
      status == UploadStatus.cancelled ||
      status == UploadStatus.failed;
}
