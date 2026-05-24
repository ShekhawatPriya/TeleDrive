import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'telegram_client_exceptions.dart';
import 'telegram_client_models.dart';

final telegramTransferServiceProvider = Provider<TelegramTransferService>((
  ref,
) {
  return MethodChannelTelegramTransferService(storage: SecureStorageService());
});

abstract class TelegramTransferService {
  Future<bool> get isAvailable;
  Future<bool> get isAuthorized;

  Future<void> configure({
    required String backendUserId,
    required int telegramUserId,
  });

  Future<Map<String, dynamic>> health();

  Future<Map<String, dynamic>> getMe();

  Future<int?> resolveUploadTarget(TelegramUploadTarget target);

  Future<TelegramUploadResult> uploadOriginal({
    required String filePath,
    required String filename,
    required String mimeType,
    required int sizeBytes,
    required TelegramUploadTarget target,
    String? transferId,
  });

  Future<TelegramUploadResult> uploadDerivative({
    required String filePath,
    required String filename,
    required String mimeType,
    required int sizeBytes,
    required TelegramUploadTarget target,
    required String variant,
    String? transferId,
  });

  Stream<TelegramTransferProgress> watchProgress(String transferId);

  Future<void> cancelTransfer(String transferId);

  Future<TelegramDownloadResult> downloadToCache(
    TelegramMediaRef ref, {
    required String filename,
    required String cacheKey,
  });

  Future<Stream<List<int>>> openRead(TelegramMediaRef ref);
}

class MethodChannelTelegramTransferService implements TelegramTransferService {
  MethodChannelTelegramTransferService({
    MethodChannel? channel,
    EventChannel? events,
    SecureStorageService? storage,
  }) : _channel = channel ?? const MethodChannel('teledrive/tdlib'),
       _events = events ?? const EventChannel('teledrive/tdlib/events'),
       _storage = storage ?? SecureStorageService() {
    _eventSubscription = _events.receiveBroadcastStream().listen(
      _onNativeEvent,
    );
  }

  final MethodChannel _channel;
  final EventChannel _events;
  final SecureStorageService _storage;
  final _uuid = const Uuid();
  final Map<String, StreamController<TelegramTransferProgress>> _progress = {};
  // Kept to keep the native EventChannel subscription alive for bridge events.
  // ignore: unused_field
  StreamSubscription<dynamic>? _eventSubscription;

  @override
  Future<bool> get isAvailable async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> get isAuthorized async {
    try {
      final state = await health();
      return state['authorized'] == true;
    } on TelegramClientException {
      return false;
    }
  }

  @override
  Future<void> configure({
    required String backendUserId,
    required int telegramUserId,
  }) async {
    final available = await isAvailable;
    if (!available) {
      throw const TelegramClientUnavailableException(
        'TDLib is not available on this device.',
        code: 'tdlib_unavailable',
      );
    }
    if (!AppConfig.telegramApiConfigured) {
      throw const TelegramClientUnavailableException(
        'Local TDLib requires TELEGRAM_API_ID and TELEGRAM_API_HASH.',
        code: 'tdlib_api_credentials_missing',
      );
    }
    final dir = await getApplicationSupportDirectory();
    final scope =
        '${_stableHash(AppConfig.apiBaseUrl)}_${backendUserId}_$telegramUserId';
    var encryptionKey = await _storage.readTdlibKey(scope);
    if (encryptionKey == null || encryptionKey.isEmpty) {
      encryptionKey = _newEncryptionKey();
      await _storage.saveTdlibKey(scope, encryptionKey);
    } else {
      final normalized = _normalizeEncryptionKey(encryptionKey);
      if (normalized != encryptionKey) {
        encryptionKey = normalized;
        await _storage.saveTdlibKey(scope, encryptionKey);
      }
    }
    final scopedPath =
        '${dir.path}${Platform.pathSeparator}tdlib${Platform.pathSeparator}${_stableHash(AppConfig.apiBaseUrl)}${Platform.pathSeparator}$backendUserId${Platform.pathSeparator}$telegramUserId';
    await _channel.invokeMethod<void>('configure', {
      'databaseDirectory': '$scopedPath/db',
      'filesDirectory': '$scopedPath/files',
      'apiId': AppConfig.telegramApiId,
      'apiHash': AppConfig.telegramApiHash,
      'encryptionKey': encryptionKey,
      'telegramUserId': telegramUserId,
      'applicationVersion': AppConfig.appVersion,
    });
  }

  @override
  Future<Map<String, dynamic>> health() => _invokeMap('health', {});

  @override
  Future<Map<String, dynamic>> getMe() => _invokeMap('getMe', {});

  @override
  Future<int?> resolveUploadTarget(TelegramUploadTarget target) async {
    final existing = target.tdlibChatId;
    if (existing != null) return existing;
    final result = await _invokeMap('resolveChat', {
      'tdlibChatId': target.tdlibChatId,
      'telethonPeerId': target.telethonPeerId,
      'telethonChannelId': target.telethonChannelId,
      'title': target.title,
      'type': target.type,
    });
    return _intish(result['tdlibChatId']);
  }

  @override
  Future<TelegramUploadResult> uploadOriginal({
    required String filePath,
    required String filename,
    required String mimeType,
    required int sizeBytes,
    required TelegramUploadTarget target,
    String? transferId,
  }) {
    return _upload(
      method: 'sendDocument',
      variant: 'original',
      filePath: filePath,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      target: target,
      transferId: transferId,
    );
  }

  @override
  Future<TelegramUploadResult> uploadDerivative({
    required String filePath,
    required String filename,
    required String mimeType,
    required int sizeBytes,
    required TelegramUploadTarget target,
    required String variant,
    String? transferId,
  }) {
    return _upload(
      method: 'sendDocument',
      variant: variant,
      filePath: filePath,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      target: target,
      transferId: transferId,
    );
  }

  Future<TelegramUploadResult> _upload({
    required String method,
    required String variant,
    required String filePath,
    required String filename,
    required String mimeType,
    required int sizeBytes,
    required TelegramUploadTarget target,
    String? transferId,
  }) async {
    final effectiveTransferId = transferId ?? _uuid.v4();
    final tdlibChatId = await resolveUploadTarget(target);
    if (tdlibChatId == null) {
      throw const TelegramClientUnavailableException(
        'Could not resolve Telegram upload target.',
        code: 'tdlib_target_unresolved',
      );
    }
    _emit(
      TelegramTransferProgress(
        transferId: effectiveTransferId,
        state: TelegramTransferState.uploading,
        totalBytes: sizeBytes,
      ),
    );
    final result = await _invokeMap(method, {
      'transferId': effectiveTransferId,
      'chatId': tdlibChatId,
      'filePath': filePath,
      'filename': filename,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'variant': variant,
    });
    final ref = TelegramMediaRef.fromJson({
      ...result,
      'variant': variant,
      'clientProvider': 'tdlib',
      'storageBackend': 'telegram',
    });
    if (ref.tdlibMessageId == null || ref.tdlibMessageId! <= 0) {
      throw const TelegramClientException(
        'TDLib did not return a final message reference.',
        code: 'tdlib_final_message_missing',
      );
    }
    _emit(
      TelegramTransferProgress(
        transferId: effectiveTransferId,
        state: TelegramTransferState.completed,
        bytesDone: sizeBytes,
        totalBytes: sizeBytes,
      ),
    );
    return TelegramUploadResult(
      transferId: effectiveTransferId,
      ref: ref,
      sizeBytes: sizeBytes,
      mimeType: mimeType,
    );
  }

  @override
  Stream<TelegramTransferProgress> watchProgress(String transferId) {
    return _progress
        .putIfAbsent(transferId, () => StreamController.broadcast())
        .stream;
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    await _channel
        .invokeMethod<void>('cancelTransfer', {'transferId': transferId})
        .catchError((_) {});
  }

  @override
  Future<TelegramDownloadResult> downloadToCache(
    TelegramMediaRef ref, {
    required String filename,
    required String cacheKey,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path =
        '${dir.path}${Platform.pathSeparator}teledrive_${_stableHash(cacheKey)}_$safeName';
    final result = await _invokeMap('downloadToFile', {
      'transferId': _uuid.v4(),
      'tdlibChatId': ref.tdlibChatId,
      'tdlibMessageId': ref.tdlibMessageId,
      'tdlibFileId': ref.tdlibFileId,
      'destinationPath': path,
    });
    return TelegramDownloadResult(
      file: File((result['filePath'] as String?) ?? path),
      ref: ref,
    );
  }

  @override
  Future<Stream<List<int>>> openRead(TelegramMediaRef ref) async {
    throw const TelegramClientUnavailableException(
      'Streaming through TDLib is not exposed; download to cache first.',
      code: 'tdlib_stream_unavailable',
    );
  }

  Future<Map<String, dynamic>> _invokeMap(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      final result = await _channel.invokeMethod<Object?>(method, args);
      if (result is Map) return Map<String, dynamic>.from(result);
      return <String, dynamic>{};
    } on MissingPluginException {
      throw const TelegramClientUnavailableException(
        'TDLib bridge is not installed.',
        code: 'tdlib_bridge_missing',
      );
    } on PlatformException catch (err) {
      if (err.code == 'tdlib_unavailable' ||
          err.code == 'tdlib_bridge_not_implemented') {
        throw TelegramClientUnavailableException(
          err.message ?? 'TDLib is not available.',
          code: err.code,
        );
      }
      throw TelegramClientException(
        err.message ?? 'Telegram transfer failed.',
        code: err.code,
      );
    }
  }

  void _emit(TelegramTransferProgress event) {
    _progress
        .putIfAbsent(event.transferId, () => StreamController.broadcast())
        .add(event);
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;
    final data = Map<String, dynamic>.from(event);
    if (data['type'] != 'progress') return;
    final transferId = data['transferId'] as String?;
    if (transferId == null) return;
    _emit(
      TelegramTransferProgress(
        transferId: transferId,
        state: _stateFromNative('${data['state'] ?? ''}'),
        bytesDone: _intish(data['bytesDone']) ?? 0,
        totalBytes: _intish(data['totalBytes']),
        message: data['message'] as String?,
      ),
    );
  }

  TelegramTransferState _stateFromNative(String value) {
    return switch (value) {
      'resolvingTarget' => TelegramTransferState.resolvingTarget,
      'uploading' => TelegramTransferState.uploading,
      'downloading' => TelegramTransferState.downloading,
      'waitingForFinalMessage' => TelegramTransferState.waitingForFinalMessage,
      'completed' => TelegramTransferState.completed,
      'cancelled' => TelegramTransferState.cancelled,
      'failed' => TelegramTransferState.failed,
      _ => TelegramTransferState.queued,
    };
  }

  String _newEncryptionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  String _normalizeEncryptionKey(String value) {
    try {
      return base64Encode(base64Decode(value));
    } on FormatException {
      return base64Encode(base64Url.decode(base64Url.normalize(value)));
    }
  }

  String _stableHash(String value) {
    var hash = 0xcbf29ce484222325;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }

  int? _intish(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
