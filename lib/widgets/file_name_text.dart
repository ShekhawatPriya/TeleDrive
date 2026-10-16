import 'package:flutter/widgets.dart';

/// A file name that, like the Files app, truncates in the middle so the end
/// of the name and its extension stay visible ("A weekend in…tains.jpg").
///
/// Text that fits renders unchanged; assistive technology always receives the
/// full name.
class FileNameText extends StatelessWidget {
  const FileNameText(
    this.name, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
  });

  final String name;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  /// Characters of the base name kept before the extension.
  static const _tailStem = 4;

  /// Returns [name] shortened in the middle to fit [maxWidth], or `null` when
  /// it already fits or cannot be shortened usefully.
  static String? fit(
    String name, {
    required TextStyle style,
    required double maxWidth,
    required TextScaler textScaler,
    required TextDirection textDirection,
    int maxLines = 1,
  }) {
    bool fits(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: maxLines,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      final ok = !painter.didExceedMaxLines;
      painter.dispose();
      return ok;
    }

    if (!maxWidth.isFinite || fits(name)) return null;
    final dot = name.lastIndexOf('.');
    final hasExtension = dot > 0 && name.length - dot <= 9;
    final tailStart = hasExtension
        ? (dot - _tailStem).clamp(0, dot)
        : (name.length - _tailStem - 2).clamp(0, name.length);
    final tail = name.substring(tailStart);
    var low = 0, high = tailStart, best = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (fits('${name.substring(0, mid).trimRight()}…$tail')) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    // Too narrow to keep any of the start: fall back to end truncation.
    if (best < 1) return null;
    return '${name.substring(0, best).trimRight()}…$tail';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortened = fit(
          name,
          style: resolved,
          maxWidth: constraints.maxWidth,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: maxLines,
        );
        return Text(
          shortened ?? name,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: maxLines > 1,
          textAlign: textAlign,
          style: style,
          semanticsLabel: name,
        );
      },
    );
  }
}
