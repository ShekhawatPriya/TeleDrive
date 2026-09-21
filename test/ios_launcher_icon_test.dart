import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'every iOS launcher size has opaque dark edges, without a white frame',
    () async {
      final directory = Directory(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      );
      final icons = directory.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.png'),
      );
      expect(icons, isNotEmpty);
      for (final file in icons) {
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        final image = (await codec.getNextFrame()).image;
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            if (x != 0 &&
                y != 0 &&
                x != image.width - 1 &&
                y != image.height - 1)
              continue;
            final offset = (y * image.width + x) * 4;
            expect(pixels.getUint8(offset + 3), 255, reason: file.path);
            for (var channel = 0; channel < 3; channel++) {
              expect(
                pixels.getUint8(offset + channel),
                lessThan(100),
                reason: file.path,
              );
            }
          }
        }
        image.dispose();
        codec.dispose();
      }
    },
  );
}
