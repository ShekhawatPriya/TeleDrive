import '../../core/notifications/transfer_live_activity_service.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import 'upload_models.dart';

const _transferring = {
  UploadStatus.uploadingOriginalToTelegram,
  UploadStatus.uploadingThumbnailToTelegram,
  UploadStatus.uploadingPreviewToTelegram,
  UploadStatus.committingMetadata,
};

const _working = {
  UploadStatus.preparingMetadata,
  UploadStatus.creatingThumbnail,
  UploadStatus.creatingPreview,
  ..._transferring,
  UploadStatus.cancelling,
};

/// The Live Activity view of an upload session, or null while nothing has
/// been confirmed for upload (picked files awaiting confirmation stay off
/// the Lock Screen).
TransferActivitySnapshot? uploadActivitySnapshot(List<UploadItem> items) {
  if (items.isEmpty) return null;
  if (items.every((i) => i.status == UploadStatus.selected)) return null;

  var completed = 0;
  var failed = 0;
  var cancelled = 0;
  var waiting = 0;
  var queued = 0;
  var working = 0;
  var transferring = 0;
  var totalBytes = 0;
  var completedBytes = 0;
  for (final item in items) {
    final status = item.status;
    if (status == UploadStatus.uploaded) completed++;
    if (status == UploadStatus.failed) failed++;
    if (status == UploadStatus.cancelled) cancelled++;
    if (status == UploadStatus.waitingForWifi) waiting++;
    if (status == UploadStatus.queued || status == UploadStatus.selected) {
      queued++;
    }
    if (_working.contains(status)) working++;
    if (_transferring.contains(status)) transferring++;
    totalBytes += item.size;
    completedBytes += (item.progress * item.size).round();
  }
  final total = items.length;
  final unsuccessful = failed + cancelled;
  final settled = completed + unsuccessful == total;

  final TransferActivityPhase phase;
  if (settled) {
    phase = unsuccessful == 0
        ? TransferActivityPhase.completed
        : completed > 0
        ? TransferActivityPhase.partial
        : failed > 0
        ? TransferActivityPhase.failed
        : TransferActivityPhase.cancelled;
  } else if (working == 0 && queued == 0 && waiting > 0) {
    phase = TransferActivityPhase.waitingForWifi;
  } else if (completed == 0 && transferring == 0) {
    phase = TransferActivityPhase.preparing;
  } else {
    phase = TransferActivityPhase.uploading;
  }

  final current =
      items.where((i) => _transferring.contains(i.status)).firstOrNull ??
      items.where((i) => _working.contains(i.status)).firstOrNull ??
      items.where((i) => i.status == UploadStatus.queued).firstOrNull;

  return TransferActivitySnapshot(
    phase: phase,
    source: items.every((i) => i.clientSource == 'gallery_backup')
        ? TransferActivitySource.backup
        : TransferActivitySource.uploads,
    totalCount: total,
    completedCount: completed,
    failedCount: unsuccessful,
    progress: uploadOverallProgress(items),
    completedBytes: completedBytes,
    totalBytes: totalBytes,
    currentName: settled ? null : current?.name,
    currentKind: current == null
        ? TransferActivityFileKind.other
        : _activityKind(detectFileKind(current.name, current.mimeType)),
  );
}

TransferActivityFileKind _activityKind(FileKind kind) => switch (kind) {
  FileKind.image => TransferActivityFileKind.image,
  FileKind.video => TransferActivityFileKind.video,
  FileKind.audio => TransferActivityFileKind.audio,
  FileKind.zip => TransferActivityFileKind.archive,
  FileKind.pdf ||
  FileKind.doc ||
  FileKind.sheet ||
  FileKind.slides ||
  FileKind.text ||
  FileKind.code => TransferActivityFileKind.document,
  FileKind.folder || FileKind.other => TransferActivityFileKind.other,
};
