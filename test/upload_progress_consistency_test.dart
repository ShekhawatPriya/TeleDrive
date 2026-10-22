import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/utils/file_type_detector.dart';
import 'package:flutter_m_fsdk/features/upload/ui/upload_status_label.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';

UploadItem _item(
  String id,
  int size,
  UploadStatus status, {
  double server = 0,
}) => UploadItem(
  localId: id,
  uploadClientId: 'u-$id',
  name: '$id.mov',
  size: size,
  mimeType: 'video/quicktime',
  path: '/fixture/$id.mov',
  status: status,
  serverProgress: server,
);

void main() {
  const mb = 1024 * 1024;

  test('a row, its ring and the upload sheet report the same bytes', () {
    // The reported case: 107 MB of a 160 MB video has landed.
    final video = _item(
      'video',
      160 * mb,
      UploadStatus.uploadingOriginalToTelegram,
      server: 107 / 160,
    );
    final file = video.toDriveFile(null);
    expect(formatUploadStatus(file), 'Uploading 66%');
    expect(uploadPercent(file.uploadProgress), 66);
    expect(video.percent, 66);
    expect(
      uploadRowDetail(video, uploadStatusLabel(video.status, video.progress)),
      '107 MB of 160 MB',
    );
  });

  test('nothing claims progress before Telegram accepts a byte', () {
    for (final status in [
      UploadStatus.queued,
      UploadStatus.waitingForWifi,
      UploadStatus.preparingMetadata,
      UploadStatus.uploadingOriginalToTelegram,
    ]) {
      final photo = _item('photo', 92 * 1024, status);
      expect(photo.progress, 0, reason: '$status');
      expect(photo.transferredBytes, 0, reason: '$status');
      expect(
        formatUploadStatus(photo.toDriveFile(null)),
        isNot(contains('%')),
        reason: '$status',
      );
    }
    final photo = _item(
      'photo',
      92 * 1024,
      UploadStatus.uploadingOriginalToTelegram,
    );
    expect(formatUploadStatus(photo.toDriveFile(null)), 'Uploading');
    expect(
      uploadRowDetail(photo, uploadStatusLabel(photo.status, photo.progress)),
      '0 B of 92 KB',
    );
  });

  test('after the original lands, every surface says Finishing', () {
    for (final status in [
      UploadStatus.creatingThumbnail,
      UploadStatus.creatingPreview,
      UploadStatus.uploadingThumbnailToTelegram,
      UploadStatus.uploadingPreviewToTelegram,
      UploadStatus.committingMetadata,
    ]) {
      final video = _item('video', 160 * mb, status, server: .3);
      expect(video.transferredBytes, video.size, reason: '$status');
      expect(formatUploadStatus(video.toDriveFile(null)), 'Finishing');
      expect(uploadStatusLabel(video.status, video.progress), 'Finishing');
    }
  });

  test('the overall percent is transferred bytes over total bytes', () {
    final items = [
      _item(
        'video',
        160 * mb,
        UploadStatus.uploadingOriginalToTelegram,
        server: 107 / 160,
      ),
      _item('photo', 92 * 1024, UploadStatus.uploadingOriginalToTelegram),
    ];
    final bytes = items.fold<int>(0, (sum, i) => sum + i.transferredBytes);
    final total = items.fold<int>(0, (sum, i) => sum + i.size);
    expect(
      uploadPercent(uploadOverallProgress(items)),
      uploadPercent(bytes / total),
    );
    expect(uploadPercent(uploadOverallProgress(items)), 66);
  });

  test('percent flooring is not thrown off by binary fractions', () {
    expect(uploadPercent(.29), 29);
    expect(uploadPercent(.57), 57);
    expect(uploadPercent(.999), 99);
    expect(uploadPercent(1), 100);
  });
}
