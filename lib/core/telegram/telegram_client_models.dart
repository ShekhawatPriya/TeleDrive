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
      variant: _stringish(json, const ['variant']) ?? 'original',
      storageBackend:
          _stringish(json, const ['storageBackend', 'storage_backend']) ??
          'telegram',
      clientProvider: _stringish(json, const [
        'clientProvider',
        'client_provider',
      ]),
      serverProvider: _stringish(json, const [
        'serverProvider',
        'server_provider',
      ]),
      tdlibChatId: _intishAny(json, const ['tdlibChatId', 'tdlib_chat_id']),
      tdlibMessageId: _intishAny(json, const [
        'tdlibMessageId',
        'tdlib_message_id',
      ]),
      tdlibFileId: _intishAny(json, const ['tdlibFileId', 'tdlib_file_id']),
      tdlibRemoteFileId: _stringish(json, const [
        'tdlibRemoteFileId',
        'tdlib_remote_file_id',
      ]),
      telethonPeerId: _intishAny(json, const [
        'telethonPeerId',
        'telethon_peer_id',
      ]),
      telethonMessageId: _intishAny(json, const [
        'telethonMessageId',
        'telethon_message_id',
      ]),
      telethonAccessHash: _intishAny(json, const [
        'telethonAccessHash',
        'telethon_access_hash',
      ]),
      telegramDcId: _intishAny(json, const ['telegramDcId', 'telegram_dc_id']),
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
      folderId: _intishAny(json, const ['folderId', 'folder_id']),
      telethonPeerId: _intishAny(json, const [
        'telethonPeerId',
        'telethon_peer_id',
      ]),
      telethonAccessHash: _intishAny(json, const [
        'telethonAccessHash',
        'telethon_access_hash',
      ]),
      telethonChannelId: _intishAny(json, const [
        'telethonChannelId',
        'telethon_channel_id',
      ]),
      tdlibChatId: _intishAny(json, const ['tdlibChatId', 'tdlib_chat_id']),
      title: _stringish(json, const ['title']),
      type: _stringish(json, const ['type']) ?? 'private_channel',
      requiresClientResolution:
          _boolishAny(json, const [
            'requiresClientResolution',
            'requires_client_resolution',
          ]) ??
          true,
    );
  }
}

String? _stringish(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final string = value is String ? value : '$value';
    final trimmed = string.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

int? _intishAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final parsed = _intish(json[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

bool? _boolishAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
  }
  return null;
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
