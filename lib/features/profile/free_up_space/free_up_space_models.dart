import 'package:flutter/foundation.dart';

@immutable
class FreeUpSpaceCandidate {
  const FreeUpSpaceCandidate({
    required this.fingerprint,
    required this.contentUri,
    required this.name,
    required this.sizeBytes,
    required this.mediaType,
    required this.mimeType,
    required this.modifiedAtMillis,
    required this.addedAtMillis,
    this.relativePath,
    this.thumbnailHintPath,
    required this.backendReason,
  });

  final String fingerprint;
  final String contentUri;
  final String name;
  final int sizeBytes;
  final String mediaType;
  final String mimeType;
  final int modifiedAtMillis;
  final int addedAtMillis;
  final String? relativePath;
  final String? thumbnailHintPath;
  final String backendReason;
}

@immutable
class FreeUpSpaceDeleteSummary {
  const FreeUpSpaceDeleteSummary({
    required this.requested,
    required this.deleted,
    required this.failed,
    required this.deletedBytes,
    required this.userCancelled,
  });

  final int requested;
  final int deleted;
  final int failed;
  final int deletedBytes;
  final bool userCancelled;
}

@immutable
class FreeUpSpaceState {
  const FreeUpSpaceState({
    this.scanning = false,
    this.deleting = false,
    this.permissionDenied = false,
    this.limitedAccess = false,
    this.userCancelledLastDelete = false,
    this.eligibleCount = 0,
    this.eligibleBytes = 0,
    this.photoCount = 0,
    this.videoCount = 0,
    this.photoBytes = 0,
    this.videoBytes = 0,
    this.scannedCount = 0,
    this.backendAllowedCount = 0,
    this.skippedNotBackedUp = 0,
    this.skippedManualUpload = 0,
    this.skippedRemoteMissing = 0,
    this.skippedAlreadyCleaned = 0,
    this.skippedCurrentlyUploading = 0,
    this.skippedUnsupportedUri = 0,
    this.skippedPathOnly = 0,
    this.lastScanAt,
    this.error,
    this.lastSuccessMessage,
    this.candidates = const [],
  });

  final bool scanning;
  final bool deleting;
  final bool permissionDenied;
  final bool limitedAccess;
  final bool userCancelledLastDelete;
  final int eligibleCount;
  final int eligibleBytes;
  final int photoCount;
  final int videoCount;
  final int photoBytes;
  final int videoBytes;
  final int scannedCount;
  final int backendAllowedCount;
  final int skippedNotBackedUp;
  final int skippedManualUpload;
  final int skippedRemoteMissing;
  final int skippedAlreadyCleaned;
  final int skippedCurrentlyUploading;
  final int skippedUnsupportedUri;
  final int skippedPathOnly;
  final DateTime? lastScanAt;
  final String? error;
  final String? lastSuccessMessage;
  final List<FreeUpSpaceCandidate> candidates;

  FreeUpSpaceState copyWith({
    bool? scanning,
    bool? deleting,
    bool? permissionDenied,
    bool? limitedAccess,
    bool? userCancelledLastDelete,
    int? eligibleCount,
    int? eligibleBytes,
    int? photoCount,
    int? videoCount,
    int? photoBytes,
    int? videoBytes,
    int? scannedCount,
    int? backendAllowedCount,
    int? skippedNotBackedUp,
    int? skippedManualUpload,
    int? skippedRemoteMissing,
    int? skippedAlreadyCleaned,
    int? skippedCurrentlyUploading,
    int? skippedUnsupportedUri,
    int? skippedPathOnly,
    DateTime? lastScanAt,
    String? error,
    bool clearError = false,
    String? lastSuccessMessage,
    bool clearLastSuccessMessage = false,
    List<FreeUpSpaceCandidate>? candidates,
  }) {
    return FreeUpSpaceState(
      scanning: scanning ?? this.scanning,
      deleting: deleting ?? this.deleting,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      limitedAccess: limitedAccess ?? this.limitedAccess,
      userCancelledLastDelete:
          userCancelledLastDelete ?? this.userCancelledLastDelete,
      eligibleCount: eligibleCount ?? this.eligibleCount,
      eligibleBytes: eligibleBytes ?? this.eligibleBytes,
      photoCount: photoCount ?? this.photoCount,
      videoCount: videoCount ?? this.videoCount,
      photoBytes: photoBytes ?? this.photoBytes,
      videoBytes: videoBytes ?? this.videoBytes,
      scannedCount: scannedCount ?? this.scannedCount,
      backendAllowedCount: backendAllowedCount ?? this.backendAllowedCount,
      skippedNotBackedUp: skippedNotBackedUp ?? this.skippedNotBackedUp,
      skippedManualUpload: skippedManualUpload ?? this.skippedManualUpload,
      skippedRemoteMissing: skippedRemoteMissing ?? this.skippedRemoteMissing,
      skippedAlreadyCleaned:
          skippedAlreadyCleaned ?? this.skippedAlreadyCleaned,
      skippedCurrentlyUploading:
          skippedCurrentlyUploading ?? this.skippedCurrentlyUploading,
      skippedUnsupportedUri:
          skippedUnsupportedUri ?? this.skippedUnsupportedUri,
      skippedPathOnly: skippedPathOnly ?? this.skippedPathOnly,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      error: clearError ? null : error ?? this.error,
      lastSuccessMessage: clearLastSuccessMessage
          ? null
          : lastSuccessMessage ?? this.lastSuccessMessage,
      candidates: candidates ?? this.candidates,
    );
  }
}
