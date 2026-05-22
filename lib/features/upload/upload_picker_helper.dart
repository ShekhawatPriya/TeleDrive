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
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        return UploadPickerResult();
      }
      if (result.files.length > maxFiles) {
        return UploadPickerResult(
          error: 'Select at most $maxFiles files at once.',
        );
      }
      final usableFiles = result.files.where((f) => f.path != null).toList();
      if (usableFiles.isEmpty) {
        return UploadPickerResult(
          error:
              'The selected file did not expose a local path. Try picking from device storage or Downloads.',
        );
      }
      final sessionId = _uuid.v4();
      final items = usableFiles.map((file) {
        final mime =
            lookupMimeType(file.path!, headerBytes: null) ??
            'application/octet-stream';
        return UploadItem(
          localId: _uuid.v4(),
          uploadClientId: _uuid.v4(),
          name: file.name,
          size: file.size,
          mimeType: mime,
          path: file.path!,
          status: UploadStatus.selected,
        );
      }).toList();
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
