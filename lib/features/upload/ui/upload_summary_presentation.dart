import '../../../core/utils/file_type_detector.dart';
import '../upload_models.dart';

/// Shared copy for the expanded and minimized transfer views.
extension UploadSummaryPresentation on UploadSummary {
  bool get complete => itemCount > 0 && uploadedCount == itemCount;
  bool get needsAttention => failedCount > 0 && activeCount == 0;
  bool get progressing => !complete && !waitingForWifi && !needsAttention;

  String get statusTitle {
    if (complete) return 'Uploads complete';
    if (waitingForWifi) return 'Waiting for Wi-Fi';
    if (needsAttention) return 'Uploads need attention';
    return 'Uploading $itemCount ${itemCount == 1 ? 'file' : 'files'}';
  }

  String get countLabel => '$uploadedCount of $itemCount uploaded';

  String get detailLabel {
    if (stillGeneratingThumbs) return 'Finishing previews…';
    if (complete) return '${formatFileSize(totalBytes)} saved to your drive';
    if (waitingForWifi) return 'Uploads resume when Wi-Fi is available.';
    if (needsAttention) return 'Review the remaining files below.';
    // completedBytes includes phase estimates, so it is not a byte counter.
    return '${formatFileSize(totalBytes)} total';
  }
}
