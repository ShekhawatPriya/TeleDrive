import '../../models/drive_models.dart';
import '../../core/utils/file_type_detector.dart';

enum UploadStatus {
  selected,
  queued,
  waitingForWifi,
  preparingMetadata,
  creatingThumbnail,
  creatingPreview,
  stagingToBackend,
  waitingForServer,
  uploadingToTelegram,
  uploadingOriginalToTelegram,
  uploadingThumbnailToTelegram,
  uploadingPreviewToTelegram,
  committingMetadata,
  processing,
  uploaded,
  cancelling,
  cancelled,
  failed;

  static UploadStatus fromBackendStatus(String status) {
    if (status == 'completed' || status == 'available')
      return UploadStatus.uploaded;
    if (status == 'cancelled') return UploadStatus.cancelled;
    if (status == 'failed') return UploadStatus.failed;
    if (status == 'client_uploading')
      return UploadStatus.uploadingOriginalToTelegram;
    if (status == 'pending_client_upload')
      return UploadStatus.preparingMetadata;
    if (status == 'uploading' || status == 'uploading_original')
      return UploadStatus.uploadingToTelegram;
    if (status.startsWith('processing') || status == 'derivatives')
      return UploadStatus.processing;
    return UploadStatus.waitingForServer;
  }
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
    this.localModifiedAt,
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
  }) : progress = _computeProgress(status, httpProgress, serverProgress);

  final String localId;
  final String uploadClientId;
  final String name;
  final int size;
  final String mimeType;
  final String path;
  final UploadStatus status;
  final String clientSource;
  final bool deleteLocalOnComplete;
  final DateTime? localModifiedAt;
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
      case UploadStatus.preparingMetadata:
        return 0.05;
      case UploadStatus.creatingThumbnail:
      case UploadStatus.creatingPreview:
        return 0.10;
      case UploadStatus.uploadingOriginalToTelegram:
        return (0.10 + server * 0.75).clamp(0.10, 0.85);
      case UploadStatus.uploadingThumbnailToTelegram:
      case UploadStatus.uploadingPreviewToTelegram:
        return (0.85 + server * 0.10).clamp(0.85, 0.95);
      case UploadStatus.committingMetadata:
        return 0.96;
      case UploadStatus.stagingToBackend:
        return (http * 0.4).clamp(0.0, 0.4);
      case UploadStatus.waitingForServer:
      case UploadStatus.uploadingToTelegram:
      case UploadStatus.processing:
        return (0.4 + server * 0.6).clamp(0.0, 1.0);
      case UploadStatus.cancelling:
      case UploadStatus.cancelled:
      case UploadStatus.failed:
        return ((http * 0.4) + (server * 0.6)).clamp(0.0, 1.0);
    }
  }

  UploadItem copyWith({
    String? name,
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
    DateTime? localModifiedAt,
    String? relativePath,
    int? durationMs,
    bool resetServerIds = false,
    bool? thumbnailReady,
    String? thumbnailUrl,
    bool clearThumbnail = false,
  }) {
    return UploadItem(
      localId: localId,
      uploadClientId: uploadClientId ?? this.uploadClientId,
      name: name ?? this.name,
      size: size,
      mimeType: mimeType,
      path: path,
      status: status ?? this.status,
      clientSource: clientSource ?? this.clientSource,
      deleteLocalOnComplete:
          deleteLocalOnComplete ?? this.deleteLocalOnComplete,
      localModifiedAt: localModifiedAt ?? this.localModifiedAt,
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
    );
  }
}

extension UploadItemMapping on UploadItem {
  DriveFile toDriveFile(String? activeFolderId) {
    final kind = detectFileKind(name, mimeType);
    return DriveFile(
      id: fileId != null ? '$fileId' : 'local:$localId',
      name: name,
      kind: kind,
      size: size,
      modifiedAt: DateTime.now().toIso8601String(),
      createdAt: DateTime.now().toIso8601String(),
      parentId: activeFolderId,
      starred: false,
      mimeType: mimeType,
      uploadStatus: status.name,
      uploadError: error,
      localUri: path,
      thumbnailUrl: kind == FileKind.image || kind == FileKind.video
          ? path
          : null,
      previewUrl: kind == FileKind.image ? path : null,
      isOptimistic: true,
      localId: localId,
    );
  }
}
