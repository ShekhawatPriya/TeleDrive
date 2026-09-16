import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import 'upload_models.dart';

class UploadPickerResult {
  UploadPickerResult({this.items, this.error, this.sessionId});

  final List<UploadItem>? items;
  final String? error;
  final String? sessionId;
}

class UploadPickerHelper {
  static const _uuid = Uuid();

  static Future<UploadPickerResult> pickFiles({required int maxFiles}) async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return UploadPickerResult();
      if (files.length > maxFiles)
        return UploadPickerResult(
          error: 'Select at most $maxFiles files at once.',
        );
      final sessionId = _uuid.v4();
      final items = <UploadItem>[];
      for (final file in files) {
        final path = file.path;
        if (path == null || path.isEmpty) {
          return UploadPickerResult(
            error:
                'A selected file could not be accessed. Save it to device storage and try again.',
          );
        }
        final size = file.lengthSync() ?? await file.length();
        if (size == null)
          return UploadPickerResult(
            error:
                'Could not read the size of ${file.name}. Try selecting it again.',
          );
        items.add(
          UploadItem(
            localId: _uuid.v4(),
            uploadClientId: _uuid.v4(),
            name: file.name,
            size: size,
            mimeType: lookupMimeType(path) ?? 'application/octet-stream',
            path: path,
            status: UploadStatus.selected,
          ),
        );
      }
      return UploadPickerResult(items: items, sessionId: sessionId);
    } catch (err) {
      return UploadPickerResult(error: err.toString());
    }
  }

  static Future<UploadPickerResult> pickPhoto() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return UploadPickerResult();
      final mime = lookupMimeType(photo.path) ?? 'image/jpeg';
      final sessionId = _uuid.v4();
      final size = await photo.length();
      final items = [
        UploadItem(
          localId: _uuid.v4(),
          uploadClientId: _uuid.v4(),
          name: photo.name,
          size: size,
          mimeType: mime,
          path: photo.path,
          status: UploadStatus.selected,
        ),
      ];
      return UploadPickerResult(items: items, sessionId: sessionId);
    } catch (err) {
      return UploadPickerResult(error: err.toString());
    }
  }
}
