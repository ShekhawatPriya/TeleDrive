import '../upload_models.dart';

/// User-facing label for an upload phase.  Internal backend terminology
/// (`waitingForServer`, `uploadingToTelegram`, `processing`) is collapsed
/// into the three plain-language states the user actually cares about:
/// "Waiting", "Uploading", "Uploaded".
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
    case UploadStatus.stagingToBackend:
    case UploadStatus.waitingForServer:
    case UploadStatus.uploadingToTelegram:
    case UploadStatus.uploadingOriginalToTelegram:
    case UploadStatus.uploadingThumbnailToTelegram:
    case UploadStatus.uploadingPreviewToTelegram:
    case UploadStatus.committingMetadata:
    case UploadStatus.processing:
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
      status == UploadStatus.stagingToBackend ||
      status == UploadStatus.waitingForServer ||
      status == UploadStatus.uploadingToTelegram ||
      status == UploadStatus.uploadingOriginalToTelegram ||
      status == UploadStatus.uploadingThumbnailToTelegram ||
      status == UploadStatus.uploadingPreviewToTelegram ||
      status == UploadStatus.committingMetadata ||
      status == UploadStatus.processing;
}

bool uploadIsTerminal(UploadStatus status) {
  return status == UploadStatus.uploaded ||
      status == UploadStatus.cancelled ||
      status == UploadStatus.failed;
}
