import 'package:intl/intl.dart';

import '../../models/drive_models.dart';

const _imageExt = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'heif',
  'avif',
  'gif',
  'bmp',
  'tiff',
};
const _videoExt = {
  'mp4',
  'mov',
  'avi',
  'mkv',
  'wmv',
  'flv',
  'webm',
  'm4v',
  '3gp',
  'ogv',
  'ts',
  'mts',
  'm2ts',
};
const _audioExt = {'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma', 'opus'};
const _docExt = {'doc', 'docx', 'odt'};
const _sheetExt = {'xls', 'xlsx', 'csv', 'ods', 'numbers'};
const _slideExt = {'ppt', 'pptx', 'key', 'odp'};
const _zipExt = {'zip', 'rar', 'tar', 'gz', '7z', 'bz2', 'xz'};
const _codeExt = {
  'js',
  'jsx',
  'ts',
  'tsx',
  'py',
  'java',
  'swift',
  'kt',
  'go',
  'rs',
  'cpp',
  'c',
  'h',
  'cs',
  'rb',
  'php',
  'sh',
  'yaml',
  'yml',
  'json',
  'xml',
  'html',
  'css',
};
const _textExt = {'txt', 'md', 'rtf', 'log'};

String extensionOf(String name) =>
    name.contains('.') ? name.split('.').last.toLowerCase() : '';

FileKind detectFileKind(String name, String? mimeType) {
  final mime = mimeType?.toLowerCase() ?? '';
  final ext = extensionOf(name);
  if (mime.startsWith('image/') || _imageExt.contains(ext))
    return FileKind.image;
  if (mime.startsWith('video/') || _videoExt.contains(ext))
    return FileKind.video;
  if (mime.startsWith('audio/') || _audioExt.contains(ext))
    return FileKind.audio;
  if (ext == 'pdf' || mime == 'application/pdf') return FileKind.pdf;
  if (_docExt.contains(ext)) return FileKind.doc;
  if (_sheetExt.contains(ext)) return FileKind.sheet;
  if (_slideExt.contains(ext)) return FileKind.slides;
  if (_zipExt.contains(ext)) return FileKind.zip;
  if (_codeExt.contains(ext)) return FileKind.code;
  if (_textExt.contains(ext) || mime.startsWith('text/')) return FileKind.text;
  return FileKind.other;
}

bool isImageFile(DriveFile file) => file.kind == FileKind.image;
bool isVideoFile(DriveFile file) => file.kind == FileKind.video;
bool isMediaFile(DriveFile file) => isImageFile(file) || isVideoFile(file);

String formatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

String formatDate(String iso) {
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return DateFormat(days > 365 ? 'MMM d, y' : 'MMM d').format(date);
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0)
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatLabel(DriveFile file) {
  final ext = extensionOf(file.name);
  if (ext.isNotEmpty) return ext.toUpperCase();
  return file.mimeType?.split('/').last.toUpperCase() ?? 'FILE';
}
