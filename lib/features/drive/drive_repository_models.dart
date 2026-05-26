class FreeUpSpaceResolveDecision {
  const FreeUpSpaceResolveDecision({
    required this.fingerprint,
    required this.cleanupAllowed,
    required this.reason,
    this.clientSource,
    this.backupSource,
    required this.remoteAvailable,
    this.fileId,
    this.remoteSizeBytes,
  });

  final String fingerprint;
  final bool cleanupAllowed;
  final String reason;
  final String? clientSource;
  final String? backupSource;
  final bool remoteAvailable;
  final String? fileId;
  final int? remoteSizeBytes;

  factory FreeUpSpaceResolveDecision.fromJson(Map<String, dynamic> json) {
    return FreeUpSpaceResolveDecision(
      fingerprint: '${json['fingerprint'] ?? ''}',
      cleanupAllowed:
          json['cleanupAllowed'] == true || json['cleanup_allowed'] == true,
      reason: '${json['reason'] ?? 'invalid_request'}',
      clientSource:
          json['clientSource'] as String? ?? json['client_source'] as String?,
      backupSource:
          json['backupSource'] as String? ?? json['backup_source'] as String?,
      remoteAvailable:
          json['remoteAvailable'] == true || json['remote_available'] == true,
      fileId: json['fileId'] == null && json['file_id'] == null
          ? null
          : '${json['fileId'] ?? json['file_id']}',
      remoteSizeBytes:
          (json['remoteSizeBytes'] as num?)?.toInt() ??
          (json['remote_size_bytes'] as num?)?.toInt(),
    );
  }
}
