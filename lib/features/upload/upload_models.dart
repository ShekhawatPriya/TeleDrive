import '../../models/drive_models.dart';
import '../../core/utils/file_type_detector.dart';

enum UploadStatus {
  selected,
  queued,
  waitingForWifi,
  preparingMetadata,
  creatingThumbnail,
  creatingPreview,
  uploadingOriginalToTelegram,
  uploadingThumbnailToTelegram,
  uploadingPreviewToTelegram,
  committingMetadata,
  uploaded,
  cancelling,
  cancelled,
  failed,
}

class UploadItem {
  UploadItem({
    required this.localId,
    required this.uploadClientId,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.path,
    required this.status,
    this.clientSource = 'manual_picker',
    this.deleteLocalOnComplete = true,
    this.destinationFolderId,
    this.backupFingerprint,
    this.backupSourceKind,
    this.contentUri,
    this.localModifiedAt,
    this.addedAtMillis,
    this.mediaType,
    this.relativePath,
    this.durationMs,
    this.httpProgress = 0,
    this.serverProgress = 0,
    this.batchId,
    this.fileId,
    this.uploadJobId,
    this.error,
    this.cancelRequested = false,
    this.thumbnailReady = false,
    this.thumbnailUrl,
    this.bytesPerSecond,
    this.posterPath,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now(),
       progress = _computeProgress(status, httpProgress, serverProgress);

  final String localId;
  final String uploadClientId;
  final String name;
  final int size;
  final String mimeType;
  final String path;
  final UploadStatus status;
  final String clientSource;
  final bool deleteLocalOnComplete;
  final String? destinationFolderId;
  final String? backupFingerprint;
  final String? backupSourceKind;
  final String? contentUri;
  final DateTime? localModifiedAt;
  final int? addedAtMillis;
  final String? mediaType;
  final String? relativePath;
  final int? durationMs;
  final double httpProgress;
  final double serverProgress;
  final double progress;
  final int? batchId;
  final int? fileId;
  final int? uploadJobId;
  final String? error;
  final bool cancelRequested;
  final bool thumbnailReady;
  final String? thumbnailUrl;

  /// When the item joined the queue. Optimistic drive rows use it as their
  /// timestamp so rebuilding a row never changes its thumbnail cache key.
  final DateTime addedAt;

  /// On-device poster frame for a video, shown while it uploads.
  final String? posterPath;

  /// Smoothed upload speed of the original while it is transferring.
  final double? bytesPerSecond;

  /// Bytes of the original Telegram has accepted so far.
  int get transferredBytes =>
      (serverProgress.clamp(0.0, 1.0) * size).round().clamp(0, size);

  static double _computeProgress(
    UploadStatus status,
    double http,
    double server,
  ) {
    switch (status) {
      case UploadStatus.uploaded:
        return 1.0;
      case UploadStatus.selected:
      case UploadStatus.queued:
      case UploadStatus.waitingForWifi:
        return 0.0;
      // The original's bytes dominate; derivatives are made after it lands,
      // so their phases sit above it and the bar never moves backwards.
      case UploadStatus.preparingMetadata:
        return 0.02;
      case UploadStatus.uploadingOriginalToTelegram:
        return (0.03 + server * 0.89).clamp(0.03, 0.92);
      case UploadStatus.creatingThumbnail:
      case UploadStatus.creatingPreview:
        return 0.92;
      case UploadStatus.uploadingThumbnailToTelegram:
      case UploadStatus.uploadingPreviewToTelegram:
        return (0.92 + server * 0.05).clamp(0.92, 0.97);
      case UploadStatus.committingMetadata:
        return 0.98;
      case UploadStatus.cancelling:
      case UploadStatus.cancelled:
      case UploadStatus.failed:
        return ((http * 0.4) + (server * 0.6)).clamp(0.0, 1.0);
    }
  }

  UploadItem copyWith({
    String? name,
    String? path,
    String? uploadClientId,
    UploadStatus? status,
    double? httpProgress,
    double? serverProgress,
    int? batchId,
    int? fileId,
    int? uploadJobId,
    String? error,
    bool clearError = false,
    bool? cancelRequested,
    String? clientSource,
    bool? deleteLocalOnComplete,
    String? destinationFolderId,
    String? backupFingerprint,
    String? backupSourceKind,
    String? contentUri,
    DateTime? localModifiedAt,
    int? addedAtMillis,
    String? mediaType,
    String? relativePath,
    int? durationMs,
    bool resetServerIds = false,
    bool? thumbnailReady,
    String? thumbnailUrl,
    bool clearThumbnail = false,
    double? bytesPerSecond,
    bool clearSpeed = false,
    String? posterPath,
  }) {
    return UploadItem(
      localId: localId,
      uploadClientId: uploadClientId ?? this.uploadClientId,
      name: name ?? this.name,
      size: size,
      mimeType: mimeType,
      path: path ?? this.path,
      status: status ?? this.status,
      clientSource: clientSource ?? this.clientSource,
      deleteLocalOnComplete:
          deleteLocalOnComplete ?? this.deleteLocalOnComplete,
      destinationFolderId: destinationFolderId ?? this.destinationFolderId,
      backupFingerprint: backupFingerprint ?? this.backupFingerprint,
      backupSourceKind: backupSourceKind ?? this.backupSourceKind,
      contentUri: contentUri ?? this.contentUri,
      localModifiedAt: localModifiedAt ?? this.localModifiedAt,
      addedAtMillis: addedAtMillis ?? this.addedAtMillis,
      mediaType: mediaType ?? this.mediaType,
      relativePath: relativePath ?? this.relativePath,
      durationMs: durationMs ?? this.durationMs,
      httpProgress: httpProgress ?? this.httpProgress,
      serverProgress: serverProgress ?? this.serverProgress,
      batchId: resetServerIds ? null : batchId ?? this.batchId,
      fileId: resetServerIds ? null : fileId ?? this.fileId,
      uploadJobId: resetServerIds ? null : uploadJobId ?? this.uploadJobId,
      error: clearError ? null : error ?? this.error,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      thumbnailReady: clearThumbnail
          ? false
          : thumbnailReady ?? this.thumbnailReady,
      thumbnailUrl: clearThumbnail ? null : thumbnailUrl ?? this.thumbnailUrl,
      bytesPerSecond: clearSpeed ? null : bytesPerSecond ?? this.bytesPerSecond,
      posterPath: posterPath ?? this.posterPath,
      addedAt: addedAt,
    );
  }
}

/// Destination marker for "drive root" on an item, distinct from `null`
/// ("follow the controller's active folder").
const uploadRootFolderId = '';

String? uploadFolderIdOrNull(String? folderId) =>
    folderId == null || folderId == uploadRootFolderId ? null : folderId;

bool directDerivativePayloadsReady(
  UploadItem item,
  Map<String, Map<String, dynamic>> payloads,
) {
  final kind = detectFileKind(item.name, item.mimeType);
  if (kind != FileKind.image && kind != FileKind.video) return true;
  return payloads.containsKey('thumbnail') || payloads.containsKey('preview');
}

/// Overall progress weighted by size, as other cloud drives report it: a
/// 2 GB video dominates the bar instead of counting as much as a 1 MB photo.
/// Falls back to the per-item average when sizes are unknown.
double uploadOverallProgress(Iterable<UploadItem> items) {
  var count = 0;
  var sum = 0.0;
  var bytes = 0;
  var weighted = 0.0;
  for (final item in items) {
    count++;
    sum += item.progress;
    if (item.size > 0) {
      bytes += item.size;
      weighted += item.progress * item.size;
    }
  }
  if (count == 0) return 0;
  final value = bytes > 0 ? weighted / bytes : sum / count;
  return value.clamp(0.0, 1.0);
}

extension UploadItemMapping on UploadItem {
  DriveFile toDriveFile(String? activeFolderId) {
    final kind = detectFileKind(name, mimeType);
    // Only real images are drawn from disk: a video file is not an image, so
    // pointing the thumbnail at it failed and sent the row to the network
    // loader (spinner, then a "cloud off" retry mark, over and over).
    final localImage = kind == FileKind.image && path.startsWith('/')
        ? path
        : null;
    final localThumb = localImage ?? posterPath;
    // A stable timestamp keeps the row's thumbnail key fixed while progress
    // updates rebuild it several times a second.
    final stamp = addedAt.toIso8601String();
    return DriveFile(
      id: fileId != null ? '$fileId' : 'local:$localId',
      name: name,
      kind: kind,
      size: size,
      modifiedAt: stamp,
      createdAt: stamp,
      parentId: uploadFolderIdOrNull(destinationFolderId ?? activeFolderId),
      starred: false,
      mimeType: mimeType,
      uploadStatus: status.name,
      uploadError: error,
      localUri: path,
      thumbnailUrl: localThumb,
      previewUrl: localImage,
      isOptimistic: true,
      localId: localId,
      uploadProgress: status == UploadStatus.uploaded
          ? null
          : (progress * 100).round() / 100,
    );
  }
}

class UploadSummary {
  const UploadSummary({
    required this.sheetVisible,
    required this.itemCount,
    required this.uploadedCount,
    required this.failedCount,
    required this.activeCount,
    required this.waitingForWifi,
    required this.uploading,
    required this.stillGeneratingThumbs,
    required this.progressPermille,
    required this.totalBytes,
    required this.completedBytes,
  });

  final bool sheetVisible;
  final int itemCount;
  final int uploadedCount;
  final int failedCount;
  final int activeCount;
  final bool waitingForWifi;
  final bool uploading;
  final bool stillGeneratingThumbs;
  final int progressPermille;
  final int totalBytes;
  final int completedBytes;

  double get overallProgress => progressPermille / 1000.0;

  @override
  bool operator ==(Object other) =>
      other is UploadSummary &&
      other.sheetVisible == sheetVisible &&
      other.itemCount == itemCount &&
      other.uploadedCount == uploadedCount &&
      other.failedCount == failedCount &&
      other.activeCount == activeCount &&
      other.waitingForWifi == waitingForWifi &&
      other.uploading == uploading &&
      other.stillGeneratingThumbs == stillGeneratingThumbs &&
      other.progressPermille == progressPermille &&
      other.totalBytes == totalBytes &&
      other.completedBytes == completedBytes;

  @override
  int get hashCode => Object.hash(
    sheetVisible,
    itemCount,
    uploadedCount,
    failedCount,
    activeCount,
    waitingForWifi,
    uploading,
    stillGeneratingThumbs,
    progressPermille,
    totalBytes,
    completedBytes,
  );
}

class UploadItemIdsSnapshot {
  const UploadItemIdsSnapshot(this.ids, this.version);

  final List<String> ids;
  final int version;

  @override
  bool operator ==(Object other) =>
      other is UploadItemIdsSnapshot && other.version == version;

  @override
  int get hashCode => version;
}
