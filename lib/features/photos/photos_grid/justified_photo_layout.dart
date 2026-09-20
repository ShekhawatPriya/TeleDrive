import '../../../models/drive_models.dart';

class PhotoRow {
  const PhotoRow(this.files, this.widths, this.height);
  final List<DriveFile> files;
  final List<double> widths;
  final double height;
}

/// Chronological, aspect-aware rows. Geometry is cheap to compute; thumbnails
/// remain lazy SliverList children. Density changes target size, not image shape.
List<PhotoRow> justifyPhotos(
  List<DriveFile> files, {
  required double width,
  required double targetHeight,
  required double gap,
}) {
  double ratio(DriveFile file) {
    final w = file.widthPx ?? 0, h = file.heightPx ?? 0;
    return w > 0 && h > 0 ? w / h : 1;
  }

  final rows = <PhotoRow>[];
  var start = 0;
  while (start < files.length) {
    var end = start, sum = 0.0;
    while (end < files.length) {
      final next = ratio(files[end]);
      final before = sum == 0
          ? double.infinity
          : (width - gap * (end - start - 1)) / sum;
      final after = (width - gap * (end - start)) / (sum + next);
      if (end > start &&
          after < targetHeight &&
          (before - targetHeight).abs() < (after - targetHeight).abs())
        break;
      sum += next;
      end++;
      if (after <= targetHeight || end - start >= 12) break;
    }
    final fullHeight = (width - gap * (end - start - 1)) / sum;
    // An incomplete final row must not enlarge a lone portrait to page height.
    final height = fullHeight.clamp(1.0, targetHeight * 1.5);
    final items = files.sublist(start, end);
    rows.add(
      PhotoRow(
        items,
        items.map((file) => ratio(file) * height).toList(),
        height,
      ),
    );
    start = end;
  }
  return rows;
}
