import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../models/drive_models.dart';

/// Stable chronological geometry; SliverGrid builds only visible tiles.
/// Density changes preserve tile identity and exact scroll extents instead of
/// moving widget state between rows or estimating variable-height lists.
class PhotoLayout {
  PhotoLayout(this.rects, this.extent) {
    var end = 0.0;
    trailing = [for (final rect in rects) end = math.max(end, rect.bottom)];
  }
  final List<Rect> rects;
  final double extent;
  late final List<double> trailing;
}

PhotoLayout layoutPhotos(
  List<DriveFile> files, {
  required double width,
  required int columns,
  required double gap,
}) {
  final rects = <Rect>[];
  if (files.isEmpty || width <= 0) return PhotoLayout(rects, 0);
  final baseHeight = (width - gap * (columns - 1)) / columns;
  var start = 0, rowIndex = 0;
  var y = 0.0;
  while (start < files.length) {
    // Identity-seeded emphasis is distributed throughout each date group.
    // Incomplete final rows never decide which photo deserves more space.
    final seed = files[start].id.codeUnits.fold(0, (a, b) => a * 31 + b);
    final featured = columns <= 3 && rowIndex % 4 == (seed.abs() % 3);
    final target = baseHeight * (featured ? 1.35 : 1.0);
    final ratios = <double>[];
    var sum = 0.0;
    while (start + ratios.length < files.length) {
      final file = files[start + ratios.length];
      final w = file.widthPx ?? 0, h = file.heightPx ?? 0;
      var ratio = w > 0 && h > 0
          ? (w / h).clamp(math.max(.65, 44 / baseHeight), 1.9).toDouble()
          : 1.0;
      if (featured && ratios.isEmpty) ratio = math.max(ratio, 1.65);
      final before = ratios.isEmpty
          ? double.infinity
          : (width - gap * (ratios.length - 1)) / sum;
      final after = (width - gap * ratios.length) / (sum + ratio);
      if (ratios.isNotEmpty &&
          after * math.min(ratio, ratios.reduce(math.min)) < 44)
        break;
      if (ratios.isNotEmpty &&
          after < target &&
          (before - target).abs() < (after - target).abs())
        break;
      ratios.add(ratio);
      sum += ratio;
      if (after <= target || ratios.length >= 12) break;
    }
    final justified = (width - gap * (ratios.length - 1)) / sum;
    final last = start + ratios.length == files.length;
    final height = last ? math.min(justified, baseHeight) : justified;
    var x = 0.0;
    for (final ratio in ratios) {
      final tileWidth = ratio * height;
      rects.add(Rect.fromLTWH(x, y, tileWidth, height));
      x += tileWidth + gap;
    }
    y += height + gap;
    start += ratios.length;
    rowIndex++;
  }
  return PhotoLayout(rects, y - gap);
}

class PhotoSliverGridDelegate extends SliverGridDelegate {
  const PhotoSliverGridDelegate(this.from, this.to, this.progress);
  final PhotoLayout from, to;
  final double progress;
  @override
  SliverGridLayout getLayout(SliverConstraints constraints) =>
      _PhotoSliverLayout(from, to, progress);
  @override
  bool shouldRelayout(PhotoSliverGridDelegate old) =>
      from != old.from || to != old.to || progress != old.progress;
}

class _PhotoSliverLayout extends SliverGridLayout {
  const _PhotoSliverLayout(this.from, this.to, this.t);
  final PhotoLayout from, to;
  final double t;
  double _lerp(double a, double b) => a + (b - a) * t;
  // Tops and cumulative trailing edges remain monotonic during reflow.
  // Binary searches make viewport discovery logarithmic in library size.
  int _lowerBound(double offset, {required bool trailing}) {
    var lo = 0, hi = from.rects.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      final value = trailing
          ? _lerp(from.trailing[mid], to.trailing[mid])
          : _lerp(from.rects[mid].top, to.rects[mid].top);
      if (value < offset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  @override
  int getMinChildIndexForScrollOffset(double offset) => _lowerBound(
    offset,
    trailing: true,
  ).clamp(0, math.max(0, from.rects.length - 1));
  @override
  int getMaxChildIndexForScrollOffset(double offset) =>
      (_lowerBound(offset, trailing: false) - 1).clamp(
        0,
        math.max(0, from.rects.length - 1),
      );
  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final rect = Rect.lerp(from.rects[index], to.rects[index], t)!;
    return SliverGridGeometry(
      scrollOffset: rect.top,
      crossAxisOffset: rect.left,
      mainAxisExtent: rect.height,
      crossAxisExtent: rect.width,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) =>
      childCount == 0 ? 0 : _lerp(from.extent, to.extent);
}
