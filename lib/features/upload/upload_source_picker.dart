import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

Future<String?> chooseUploadSource(BuildContext context) async {
  try {
    return await const MethodChannel(
      'teledrive/appearance',
    ).invokeMethod<String>('chooseUploadSource');
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
