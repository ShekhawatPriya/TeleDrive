import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_m_fsdk/core/media/client_derivative_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _MockPathProviderPlatform(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mediaChannel = MethodChannel('teledrive/media');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory(
      p.join(Directory.current.path, '.dart_tool', 'client_derivatives_test'),
    );
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);
    PathProviderPlatform.instance = _MockPathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('generates native HEIC derivatives even with a generic MIME', () async {
    final calls = <MethodCall>[];
    final sourceFile = File(p.join(tempDir.path, 'camera-upload.HEIC'))
      ..writeAsBytesSync([0, 1, 2, 3]);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, (call) async {
          calls.add(call);
          expect(call.method, 'createImageDerivative');
          final args = Map<String, Object?>.from(call.arguments as Map);
          expect(args['sourcePath'], sourceFile.path);
          final destinationPath = args['destinationPath'] as String;
          final output = File(destinationPath)
            ..writeAsBytesSync(List.filled(32, calls.length));
          return {
            'path': output.path,
            'width': args['maxEdge'],
            'height': args['maxEdge'],
            'sizeBytes': output.lengthSync(),
          };
        });

    final derivatives = await const ClientDerivativeGenerator().generate(
      localId: 'local-heic',
      originalPath: sourceFile.path,
      originalFilename: 'camera-upload.HEIC',
      mimeType: 'application/octet-stream',
      requiresThumbnail: true,
      requiresPreview: true,
    );

    expect(calls, hasLength(2));
    final thumbnailArgs = Map<String, Object?>.from(calls[0].arguments as Map);
    final previewArgs = Map<String, Object?>.from(calls[1].arguments as Map);
    expect(
      thumbnailArgs['maxEdge'],
      ClientDerivativeGenerator.thumbnailMaxEdge,
    );
    expect(previewArgs['maxEdge'], ClientDerivativeGenerator.previewMaxEdge);
    expect(thumbnailArgs['quality'], 76);
    expect(previewArgs['quality'], 86);
    expect(derivatives.thumbnail, isNotNull);
    expect(derivatives.preview, isNotNull);
    expect(File(derivatives.thumbnail!.path).existsSync(), isTrue);
    expect(File(derivatives.preview!.path).existsSync(), isTrue);
  });

  test('returns no HEIC derivatives when native generation fails', () async {
    var calls = 0;
    final sourceFile = File(p.join(tempDir.path, 'camera-upload.heic'))
      ..writeAsBytesSync([0, 1, 2, 3]);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, (call) async {
          calls++;
          throw PlatformException(
            code: 'media_derivative_failed',
            message: 'Failed to decode HEIC',
          );
        });

    final derivatives = await const ClientDerivativeGenerator().generate(
      localId: 'local-heic-failure',
      originalPath: sourceFile.path,
      originalFilename: 'camera-upload.heic',
      mimeType: 'image/heic',
      requiresThumbnail: true,
      requiresPreview: true,
    );

    expect(calls, 2);
    expect(derivatives.thumbnail, isNull);
    expect(derivatives.preview, isNull);
  });
}
