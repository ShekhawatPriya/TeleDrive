import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the native media-download resolution contract described in
/// docs/media-loading.md ("Fresh TDLib database"). The bridges cannot run in
/// widget tests, so these checks pin the invariants in both sources: a
/// refactor that drops one must update the doc and this test deliberately.
void main() {
  final bridges = {
    'iOS': [
      File('ios/Runner/Tdlib/TdlibBridge.swift').readAsStringSync(),
      File('ios/Runner/Tdlib/TdlibBridge+Transfers.swift').readAsStringSync(),
      File('ios/Runner/Tdlib/TdlibBridgeModels.swift').readAsStringSync(),
    ].join('\n'),
    'Android': [
      File(
        'android/app/src/main/kotlin/com/example/flutter_m_fsdk/TdlibBridge.kt',
      ).readAsStringSync(),
      File(
        'android/app/src/main/kotlin/com/example/flutter_m_fsdk/TdlibBridgeModels.kt',
      ).readAsStringSync(),
    ].join('\n'),
  };

  for (final MapEntry(key: platform, value: source) in bridges.entries) {
    group('$platform TDLib download resolution', () {
      test('retries getMessage after making the chat known', () {
        expect(source, contains('fetchMessage('));
        expect(source, contains('ensureChatKnown(chatId)'));
        expect(source, contains('chatListArchive'));
        expect(source, contains('tdlib_chat_unavailable'));
      });

      test('chat discovery is single-flight and reset with the client', () {
        expect(source, contains('chatResolutions'));
        expect(
          RegExp(r'chatResolutions\.(removeAll|clear)\(\)').hasMatch(source),
          isTrue,
          reason: 'A reconfigured client must not reuse old chat discovery.',
        );
      });

      test('raw TDLib file ids are used only without other identifiers', () {
        expect(
          RegExp(
            r'hasMessageRef \|\| remoteFileId != nil \? nil : suppliedFileId|'
            r'if \(hasMessageRef \|\| remoteFileId != null\) null else suppliedFileId',
          ).hasMatch(source),
          isTrue,
        );
      });

      test('downloads accept the updating connection state', () {
        expect(source, contains('"connectionStateUpdating"'));
      });

      test('copied-out downloads release only TDLib-owned copies', () {
        expect(source, contains('releaseTdlibCopy('));
        expect(source, contains('"deleteFile"'));
        expect(source, contains('.partial'));
        expect(
          RegExp(r'hasPrefix\(root\)|startsWith\(root\)').hasMatch(source),
          isTrue,
          reason: 'Upload sources outside the TDLib files directory are kept.',
        );
      });

      test('TDLib storage is trimmed with optimizeStorage', () {
        expect(source, contains('"optimizeStorage"'));
        expect(source, contains('immunity_delay'));
      });

      test('stopped downloads fail fast instead of waiting for timeout', () {
        expect(source, contains('observedActive'));
        expect(source, contains('failStalledDownloads('));
        expect(source, contains('tdlib_download_stalled'));
      });
    });
  }
}
