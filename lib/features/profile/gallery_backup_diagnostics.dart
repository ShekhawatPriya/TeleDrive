import 'package:flutter/foundation.dart';

import 'app_settings_controller.dart';

@immutable
class GalleryBackupDiagnostics {
  const GalleryBackupDiagnostics({
    this.lastScanStartedAt,
    this.lastScanCompletedAt,
    this.scanDuration,
    this.indexingStrategy = GalleryBackupIndexingStrategy.mediaStoreOnly,
    this.mediaStoreItemsScanned = 0,
    this.pathItemsScanned = 0,
    this.mergedCandidates = 0,
    this.skippedAlreadyUploaded = 0,
    this.skippedAlreadyQueued = 0,
    this.skippedPermission = 0,
    this.skippedInvalid = 0,
    this.enqueued = 0,
    this.lastError,
    this.lastEnqueueError,
    this.lastUploadCompleteMarker,
    this.scanLimit = 80,
    this.queueLimit = 12,
    this.notes = const [],
  });

  final DateTime? lastScanStartedAt;
  final DateTime? lastScanCompletedAt;
  final Duration? scanDuration;
  final GalleryBackupIndexingStrategy indexingStrategy;
  final int mediaStoreItemsScanned;
  final int pathItemsScanned;
  final int mergedCandidates;
  final int skippedAlreadyUploaded;
  final int skippedAlreadyQueued;
  final int skippedPermission;
  final int skippedInvalid;
  final int enqueued;
  final String? lastError;
  final String? lastEnqueueError;
  final DateTime? lastUploadCompleteMarker;
  final int scanLimit;
  final int queueLimit;
  final List<String> notes;

  GalleryBackupDiagnostics copyWith({
    DateTime? lastScanStartedAt,
    DateTime? lastScanCompletedAt,
    Duration? scanDuration,
    GalleryBackupIndexingStrategy? indexingStrategy,
    int? mediaStoreItemsScanned,
    int? pathItemsScanned,
    int? mergedCandidates,
    int? skippedAlreadyUploaded,
    int? skippedAlreadyQueued,
    int? skippedPermission,
    int? skippedInvalid,
    int? enqueued,
    String? lastError,
    bool clearLastError = false,
    String? lastEnqueueError,
    bool clearLastEnqueueError = false,
    DateTime? lastUploadCompleteMarker,
    int? scanLimit,
    int? queueLimit,
    List<String>? notes,
  }) {
    return GalleryBackupDiagnostics(
      lastScanStartedAt: lastScanStartedAt ?? this.lastScanStartedAt,
      lastScanCompletedAt: lastScanCompletedAt ?? this.lastScanCompletedAt,
      scanDuration: scanDuration ?? this.scanDuration,
      indexingStrategy: indexingStrategy ?? this.indexingStrategy,
      mediaStoreItemsScanned:
          mediaStoreItemsScanned ?? this.mediaStoreItemsScanned,
      pathItemsScanned: pathItemsScanned ?? this.pathItemsScanned,
      mergedCandidates: mergedCandidates ?? this.mergedCandidates,
      skippedAlreadyUploaded:
          skippedAlreadyUploaded ?? this.skippedAlreadyUploaded,
      skippedAlreadyQueued: skippedAlreadyQueued ?? this.skippedAlreadyQueued,
      skippedPermission: skippedPermission ?? this.skippedPermission,
      skippedInvalid: skippedInvalid ?? this.skippedInvalid,
      enqueued: enqueued ?? this.enqueued,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      lastEnqueueError: clearLastEnqueueError
          ? null
          : lastEnqueueError ?? this.lastEnqueueError,
      lastUploadCompleteMarker:
          lastUploadCompleteMarker ?? this.lastUploadCompleteMarker,
      scanLimit: scanLimit ?? this.scanLimit,
      queueLimit: queueLimit ?? this.queueLimit,
      notes: notes ?? this.notes,
    );
  }
}
