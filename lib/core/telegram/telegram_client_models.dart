import 'dart:io';

enum TelegramTransferState {
  queued,
  resolvingTarget,
  uploading,
  downloading,
  waitingForFinalMessage,
  completed,
  cancelled,
  failed,
}

class TelegramMediaRef {
  const TelegramMediaRef({
    required this.variant,
    this.storageBackend = 'telegram',
    this.clientProvider,
    this.serverProvider,
    this.tdlibChatId,
    this.tdlibMessageId,
    this.tdlibFileId,
    this.tdlibRemoteFileId,
    this.telethonPeerId,
    this.telethonMessageId,
    this.telethonAccessHash,
    this.telegramDcId,
  });

  final String variant;
  final String storageBackend;
  final String? clientProvider;
  final String? serverProvider;
  final int? tdlibChatId;
  final int? tdlibMessageId;
  final int? tdlibFileId;
  final String? tdlibRemoteFileId;
  final int? telethonPeerId;
  final int? telethonMessageId;
  final int? telethonAccessHash;
  final int? telegramDcId;

  factory TelegramMediaRef.fromJson(Map<String, dynamic> json) {
    return TelegramMediaRef(
      variant: '${json['variant'] ?? 'original'}',
      storageBackend: '${json['storageBackend'] ?? 'telegram'}',
      clientProvider: json['clientProvider'] as String?,
      serverProvider: json['serverProvider'] as String?,
      tdlibChatId: _intish(json['tdlibChatId']),
      tdlibMessageId: _intish(json['tdlibMessageId']),
      tdlibFileId: _intish(json['tdlibFileId']),
      tdlibRemoteFileId: json['tdlibRemoteFileId'] as String?,
      telethonPeerId: _intish(json['telethonPeerId']),
      telethonMessageId: _intish(json['telethonMessageId']),
      telethonAccessHash: _intish(json['telethonAccessHash']),
      telegramDcId: _intish(json['telegramDcId']),
    );
  }

  Map<String, dynamic> toCommitJson({
    String? filename,
    String? mimeType,
    int? sizeBytes,
    int? widthPx,
    int? heightPx,
    int? durationMs,
  }) {
    return {
      'tdlib_chat_id': tdlibChatId?.toString(),
      'tdlib_message_id': tdlibMessageId?.toString(),
      'tdlib_file_id': tdlibFileId?.toString(),
      'tdlib_remote_file_id': tdlibRemoteFileId,
      'telethon_peer_id': telethonPeerId?.toString(),
      'telethon_message_id': telethonMessageId?.toString(),
      'telethon_access_hash': telethonAccessHash?.toString(),
      'telegram_dc_id': telegramDcId?.toString(),
      'filename': filename,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'width_px': widthPx,
      'height_px': heightPx,
      'duration_ms': durationMs,
    };
  }
}

class TelegramUploadTarget {
  const TelegramUploadTarget({
    this.folderId,
    this.telethonPeerId,
    this.telethonAccessHash,
    this.telethonChannelId,
    this.tdlibChatId,
    this.title,
    this.type = 'private_channel',
    this.requiresClientResolution = true,
  });

  final int? folderId;
  final int? telethonPeerId;
  final int? telethonAccessHash;
  final int? telethonChannelId;
  final int? tdlibChatId;
  final String? title;
  final String type;
  final bool requiresClientResolution;

  factory TelegramUploadTarget.fromJson(Map<String, dynamic> json) {
    return TelegramUploadTarget(
      folderId: (json['folderId'] as num?)?.toInt(),
      telethonPeerId: _intish(json['telethonPeerId']),
      telethonAccessHash: _intish(json['telethonAccessHash']),
      telethonChannelId: _intish(json['telethonChannelId']),
      tdlibChatId: _intish(json['tdlibChatId']),
      title: json['title'] as String?,
      type: '${json['type'] ?? 'private_channel'}',
      requiresClientResolution: json['requiresClientResolution'] != false,
    );
  }
}

int? _intish(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class TelegramTransferProgress {
  const TelegramTransferProgress({
    required this.transferId,
    required this.state,
    this.bytesDone = 0,
    this.totalBytes,
    this.message,
  });

  final String transferId;
  final TelegramTransferState state;
  final int bytesDone;
  final int? totalBytes;
  final String? message;

  double get fraction =>
      totalBytes == null || totalBytes! <= 0 ? 0 : bytesDone / totalBytes!;
}

class TelegramUploadResult {
  const TelegramUploadResult({
    required this.transferId,
    required this.ref,
    required this.sizeBytes,
    this.mimeType,
  });

  final String transferId;
  final TelegramMediaRef ref;
  final int sizeBytes;
  final String? mimeType;
}

class TelegramDownloadResult {
  const TelegramDownloadResult({required this.file, required this.ref});

  final File file;
  final TelegramMediaRef ref;
}
