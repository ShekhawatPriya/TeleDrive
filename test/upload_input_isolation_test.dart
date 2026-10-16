import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/features/upload/upload_picker_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

UploadItem _item(String localId, String path, {String name = 'statement.pdf'}) {
  return UploadItem(
    localId: localId,
    uploadClientId: 'client-$localId',
    name: name,
    size: File(path).lengthSync(),
    mimeType: 'application/pdf',
    path: path,
    status: UploadStatus.selected,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('teledrive/appearance');
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('upload_input_isolation');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('the same document picked twice gets two independent inputs', () async {
    // file_picker_darwin copies each pick to tmp/<file name>, so both picks of
    // one PDF arrive with a single path.
    final shared = File(p.join(temp.path, 'statement.pdf'))
      ..writeAsBytesSync(List<int>.generate(4096, (i) => i % 251));
    final other = File(p.join(temp.path, 'photo.jpg'))
      ..writeAsBytesSync([1, 2, 3]);

    final items = await UploadPickerHelper.isolateSharedInputs([
      _item('a', shared.path),
      _item('b', other.path, name: 'photo.jpg'),
      _item('c', shared.path),
    ]);

    expect(items.map((i) => i.localId), ['a', 'b', 'c']);
    expect(items[1].path, other.path, reason: 'unique inputs are untouched');
    expect(items[0].path, isNot(items[2].path));
    expect(p.basename(items[0].path), 'statement.pdf');
    expect(p.basename(items[2].path), 'statement.pdf');
    expect(shared.existsSync(), isFalse, reason: 'shared original removed');

    // The first upload settles and deletes its input, as
    // deleteLocalOnComplete does; TDLib must still find the second input.
    await File(items[0].path).delete();
    final second = File(items[2].path);
    expect(second.existsSync(), isTrue);
    expect(second.readAsBytesSync(), List<int>.generate(4096, (i) => i % 251));
    expect(items[2].size, second.lengthSync());
  });

  test('distinct inputs are returned unchanged without copying', () async {
    final a = File(p.join(temp.path, 'a.pdf'))..writeAsBytesSync([1]);
    final b = File(p.join(temp.path, 'b.pdf'))..writeAsBytesSync([2]);
    final input = [_item('a', a.path), _item('b', b.path)];

    final items = await UploadPickerHelper.isolateSharedInputs(input);

    expect(identical(items, input), isTrue);
    expect(
      Directory(
        p.join(temp.path, UploadPickerHelper.stagingDirectoryName),
      ).existsSync(),
      isFalse,
    );
  });

  test('iOS document picks use the native bridge and stay distinct', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final shared = File(p.join(temp.path, 'statement.pdf'))
      ..writeAsBytesSync(List<int>.filled(863, 7));
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          // Even if the bridge ever returned one path twice, the helper still
          // separates the inputs.
          return [
            {'path': shared.path, 'name': 'statement.pdf', 'size': 863},
            {'path': shared.path, 'name': 'statement.pdf', 'size': 863},
          ];
        });

    final result = await UploadPickerHelper.pickFiles(maxFiles: 10);

    expect(calls, ['pickDocuments']);
    expect(result.error, isNull);
    final items = result.items!;
    expect(items, hasLength(2));
    expect(items[0].localId, isNot(items[1].localId));
    expect(items[0].path, isNot(items[1].path));
    for (final item in items) {
      expect(item.name, 'statement.pdf');
      expect(item.size, 863);
      expect(item.mimeType, 'application/pdf');
      expect(File(item.path).lengthSync(), 863);
    }
  });

  test('cancelling the iOS document picker yields no items', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    final result = await UploadPickerHelper.pickFiles(maxFiles: 10);

    expect(result.items, isNull);
    expect(result.error, isNull);
  });
}
