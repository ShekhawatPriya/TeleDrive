import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'upload_models.dart';

class UploadPickerResult {
  UploadPickerResult({this.items, this.error, this.sessionId});

  final List<UploadItem>? items;
  final String? error;
  final String? sessionId;
}

/// One document returned by the iOS document picker bridge.
class _PickedDocument {
  const _PickedDocument({required this.path, required this.name, this.size});

  final String path;
  final String name;
  final int? size;
}

class UploadPickerHelper {
  static const _uuid = Uuid();
  static const _documentChannel = MethodChannel('teledrive/appearance');

  /// Directory under the temporary directory that holds per-item copies.
  static const stagingDirectoryName = 'teledrive-upload-inputs';

  static Future<UploadPickerResult> pickPhotos({required int maxFiles}) async {
    try {
      final media = await ImagePicker().pickMultipleMedia(
        limit: maxFiles,
        requestFullMetadata: false,
      );
      if (media.isEmpty) return UploadPickerResult();
      if (media.length > maxFiles)
        return UploadPickerResult(
          error: 'Select at most $maxFiles files at once.',
        );
      final items = <UploadItem>[];
      for (final file in media) {
        items.add(
          UploadItem(
            localId: _uuid.v4(),
            uploadClientId: _uuid.v4(),
            name: file.name,
            size: await file.length(),
            mimeType:
                file.mimeType ??
                lookupMimeType(file.path) ??
                'application/octet-stream',
            path: file.path,
            status: UploadStatus.selected,
          ),
        );
      }
      return UploadPickerResult(
        items: await isolateSharedInputs(items),
        sessionId: _uuid.v4(),
      );
    } catch (err) {
      return UploadPickerResult(error: err.toString());
    }
  }

  static Future<UploadPickerResult> pickFiles({required int maxFiles}) async {
    try {
      final files = await _pickDocuments();
      if (files.isEmpty) return UploadPickerResult();
      if (files.length > maxFiles)
        return UploadPickerResult(
          error: 'Select at most $maxFiles files at once.',
        );
      final sessionId = _uuid.v4();
      final items = <UploadItem>[];
      for (final file in files) {
        final path = file.path;
        if (path.isEmpty) {
          return UploadPickerResult(
            error:
                'A selected file could not be accessed. Save it to device storage and try again.',
          );
        }
        final size = file.size ?? await _lengthOrNull(path);
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
      return UploadPickerResult(
        items: await isolateSharedInputs(items),
        sessionId: sessionId,
      );
    } catch (err) {
      return UploadPickerResult(error: err.toString());
    }
  }

  /// On iOS the app's own document picker copies every pick into a unique
  /// folder. file_picker_darwin copies to `tmp/<file name>`, so two picks with
  /// one name would share (or overwrite) a single input. Other platforms and
  /// hosts without the bridge use file_picker.
  static Future<List<_PickedDocument>> _pickDocuments() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final raw = await _documentChannel.invokeListMethod<Object?>(
          'pickDocuments',
        );
        return [
          for (final entry in raw ?? const <Object?>[])
            if (entry is Map)
              _PickedDocument(
                path: '${entry['path'] ?? ''}',
                name: '${entry['name'] ?? ''}',
                size: (entry['size'] as num?)?.toInt(),
              ),
        ];
      } on MissingPluginException {
        // Widget tests and hosts without the bridge fall through.
      }
    }
    final files = await FilePicker.pickFiles();
    return [
      for (final file in files)
        _PickedDocument(
          path: file.path ?? '',
          name: file.name,
          size: file.lengthSync(),
        ),
    ];
  }

  static Future<int?> _lengthOrNull(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return null;
    }
  }

  /// Gives every item its own input file.
  ///
  /// Each upload deletes its temporary input when it settles. When a picker
  /// returns one path for several items (the same document picked twice), the
  /// first completion would delete the input the others still need, and TDLib
  /// then fails with "Can't find real file path". Shared inputs are copied into
  /// per-item folders and the shared original is removed; unique paths are
  /// left untouched.
  @visibleForTesting
  static Future<List<UploadItem>> isolateSharedInputs(
    List<UploadItem> items, {
    Directory? temporaryDirectory,
  }) async {
    final counts = <String, int>{};
    for (final item in items) {
      counts[item.path] = (counts[item.path] ?? 0) + 1;
    }
    if (counts.values.every((count) => count < 2)) return items;
    final root = Directory(
      p.join(
        (temporaryDirectory ?? await getTemporaryDirectory()).path,
        stagingDirectoryName,
      ),
    );
    final isolated = <UploadItem>[];
    final shared = <String>{};
    for (final item in items) {
      if ((counts[item.path] ?? 0) < 2) {
        isolated.add(item);
        continue;
      }
      shared.add(item.path);
      final directory = Directory(p.join(root.path, item.localId));
      await directory.create(recursive: true);
      final name = p.basename(item.path);
      final copy = await File(
        item.path,
      ).copy(p.join(directory.path, name.isEmpty ? item.name : name));
      isolated.add(item.copyWith(path: copy.path));
    }
    for (final path in shared) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    return isolated;
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
