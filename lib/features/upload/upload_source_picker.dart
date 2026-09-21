import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

Future<String?> chooseUploadSource(BuildContext context) async {
  final box = context.findRenderObject();
  final rect = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  try {
    return await const MethodChannel(
      'teledrive/appearance',
    ).invokeMethod<String>(
      'chooseUploadSource',
      rect == null
          ? null
          : {
              'x': rect.left,
              'y': rect.top,
              'width': rect.width,
              'height': rect.height,
            },
    );
  } on MissingPluginException {
    // Portable tests and hosts without the bridge retain a Cupertino fallback.
  } on PlatformException {
    // The source chooser does not perform an upload, so fallback is safe.
  }
  if (!context.mounted) return null;
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'photos'),
          child: const Text('Upload from Photos'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 'files'),
          child: const Text('Upload from Files'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
}
