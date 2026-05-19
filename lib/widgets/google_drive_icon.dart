import 'package:flutter/material.dart';

import '../models/drive_models.dart';

/// A premium, highly-polished Google Drive-style file and folder icon widget.
///
/// It uses pure vector drawing via [CustomPainter] and responsive Flutter widgets
/// to replicate the exact Drive design language, including beautiful folded corners,
/// tactile depth shadows, branding color schemes, and spreadsheet grid structures.
class GoogleDriveIcon extends StatelessWidget {
  const GoogleDriveIcon({
    required this.kind,
    this.isShared = false,
    this.size = 40.0,
    this.color,
    super.key,
  });

  /// Convenient constructor directly using a [DriveFile].
  factory GoogleDriveIcon.file(
    DriveFile file, {
    double size = 40.0,
    Color? color,
    Key? key,
  }) {
    return GoogleDriveIcon(
      kind: file.kind,
      isShared: file.shared,
      size: size,
      color: color,
      key: key,
    );
  }

  /// Convenient constructor for folders.
  factory GoogleDriveIcon.folder({
    bool isShared = false,
    double size = 40.0,
    Color? color,
    Key? key,
  }) {
    return GoogleDriveIcon(
      kind: FileKind.folder,
      isShared: isShared,
      size: size,
      color: color,
      key: key,
    );
  }

  /// The category/type of file or folder.
  final FileKind kind;

  /// Whether this file/folder has been shared with others (renders a shared badge/visual).
  final bool isShared;

  /// The size of the icon (renders as a square bounding box of size x size).
  final double size;

  /// Optional color override. If not specified, Google Drive canonical brand colors will be used.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 1. PDF has a specific modern rounded badge with bold text (as per user reference image).
    if (kind == FileKind.pdf) {
      return _PdfBadge(size: size, color: color);
    }

    // 2. Folder has a premium custom-drawn folder shape with pockets and tab.
    if (kind == FileKind.folder) {
      return _FolderIcon(
        size: size,
        isShared: isShared,
        color: color ?? scheme.primary,
      );
    }

    // 3. Document files (Docs, Sheets, Slides, Archives, Audio, Video, Code, Text)
    // are drawn as custom pages with folded top-right corners and accurate inner graphics.
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DocumentPagePainter(
          kind: kind,
          color: color ?? _colorForKind(kind, scheme),
        ),
      ),
    );
  }

  static Color _colorForKind(FileKind kind, ColorScheme scheme) {
    return switch (kind) {
      FileKind.doc => const Color(0xFF1A73E8),    // Google Blue
      FileKind.sheet => const Color(0xFF1E8E3E),  // Google Green
      FileKind.slides => const Color(0xFFF9A825), // Google Yellow/Amber
      FileKind.audio => const Color(0xFF5C6BC0),  // Indigo / Purple
      FileKind.video => const Color(0xFF00BCD4),  // Cyan / Teal
      FileKind.zip => const Color(0xFF8D6E63),    // Brown / Gold
      FileKind.code => const Color(0xFF455A64),   // Slate Slate Grey
      FileKind.text => const Color(0xFF757575),   // Silver / Dark Grey
      _ => const Color(0xFF9E9E9E),               // Medium Grey fallback
    };
  }
}

/// A high-fidelity, centered bold PDF badge replicating the exact design in the user's reference image.
class _PdfBadge extends StatelessWidget {
  const _PdfBadge({required this.size, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? const Color(0xFFEA4335); // Warm Google Red
    final borderRadius = size * 0.18;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: size * 0.08),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'PDF',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.32,
            letterSpacing: -0.5,
            height: 1.0,
            fontFamily: 'Roboto', // Fallback to standard clean sans-serif
          ),
        ),
      ),
    );
  }
}

/// A high-fidelity painter for drawing a page with a folded top-right corner.
/// Includes dynamic vector drawing for multiple internal file structures.
class _DocumentPagePainter extends CustomPainter {
  _DocumentPagePainter({
    required this.kind,
    required this.color,
  });

  final FileKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Proportional sizing
    final w = size.width;
    final h = size.height;
    final r = w * 0.08; // smooth corner radius
    final fold = w * 0.28; // folded flap size

    // Main page clipping path (exclude top-right corner slant)
    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(w - fold, 0)
      ..lineTo(w, fold)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();

    // Fill page base color
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw the folded top-right corner flap shadow (tactile drop shadow effect)
    final shadowPath = Path()
      ..moveTo(w - fold, fold)
      ..lineTo(w - fold + (w * 0.05), fold + (w * 0.05))
      ..lineTo(w, fold)
      ..close();
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw the folded top-right corner flap itself (lighter shade to represent paper fold)
    final flapPath = Path()
      ..moveTo(w - fold, 0)
      ..lineTo(w - fold, fold)
      ..lineTo(w, fold)
      ..close();
    final flapPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawPath(flapPath, flapPaint);

    // ----------------------------------------------------
    // Draw Inner Graphic Details
    // ----------------------------------------------------
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    switch (kind) {
      case FileKind.doc:
      case FileKind.text:
        // Google Docs text lines
        final lineH = h * 0.045;
        final startY = h * 0.38;
        final gapY = h * 0.12;
        final leftX = w * 0.22;
        final rightX = w * 0.78;

        final lineRatios = kind == FileKind.doc
            ? [1.0, 0.85, 0.95, 0.55] // Docs lines
            : [1.0, 1.0, 0.80, 0.90]; // Text lines

        for (int i = 0; i < lineRatios.length; i++) {
          final curY = startY + (i * gapY);
          final curRightX = leftX + ((rightX - leftX) * lineRatios[i]);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(leftX, curY, curRightX, curY + lineH),
              Radius.circular(lineH / 2),
            ),
            whitePaint,
          );
        }
        break;

      case FileKind.sheet:
        // Google Sheets Grid layout (perfect spreadsheet representation)
        final left = w * 0.22;
        final top = h * 0.36;
        final right = w * 0.78;
        final bottom = h * 0.78;
        final gridW = right - left;
        final gridH = bottom - top;

        // Outer white border
        final rectPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.045
          ..strokeCap = StrokeCap.square;
        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), rectPaint);

        // Grid lines inside
        final thinPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035;

        // Vertical divider (2 columns)
        final midX = left + (gridW * 0.40); // 40% column split
        canvas.drawLine(Offset(midX, top), Offset(midX, bottom), thinPaint);

        // Horizontal dividers (3 rows)
        final row1y = top + (gridH / 3);
        final row2y = top + (2 * gridH / 3);
        canvas.drawLine(Offset(left, row1y), Offset(right, row1y), thinPaint);
        canvas.drawLine(Offset(left, row2y), Offset(right, row2y), thinPaint);
        break;

      case FileKind.slides:
        // Google Slides presentation canvas
        final left = w * 0.22;
        final top = h * 0.36;
        final right = w * 0.78;
        final bottom = h * 0.78;
        final gridW = right - left;
        final gridH = bottom - top;

        final slidePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.045;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left, top, right, bottom),
            Radius.circular(w * 0.03),
          ),
          slidePaint,
        );

        // Mini text/title layouts inside slide
        final miniTextPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill;

        // Title box
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left + gridW * 0.15, top + gridH * 0.2, right - gridW * 0.15, top + gridH * 0.38),
            Radius.circular(w * 0.01),
          ),
          miniTextPaint,
        );

        // Body lines
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left + gridW * 0.25, top + gridH * 0.55, right - gridW * 0.25, top + gridH * 0.65),
            Radius.circular(w * 0.01),
          ),
          miniTextPaint,
        );
        break;

      case FileKind.audio:
        // Audio Music Note icon
        final noteHeadRadius = w * 0.09;
        final headX = w * 0.44;
        final headY = h * 0.65;

        // Note head (filled circle)
        canvas.drawCircle(Offset(headX, headY), noteHeadRadius, whitePaint);

        // Stem & Flag
        final stemPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.048
          ..strokeCap = StrokeCap.round;

        final stemTopY = h * 0.36;
        final stemX = headX + noteHeadRadius - (w * 0.02);

        // Vertical stem line
        canvas.drawLine(Offset(stemX, headY), Offset(stemX, stemTopY), stemPaint);

        // Slanted music note flag
        final flagPath = Path()
          ..moveTo(stemX, stemTopY)
          ..quadraticBezierTo(stemX + w * 0.12, stemTopY + h * 0.04, stemX + w * 0.22, stemTopY + h * 0.08);
        canvas.drawPath(flagPath, stemPaint);
        break;

      case FileKind.video:
        // Video Play Button
        final centerX = w * 0.50;
        final centerY = h * 0.58;
        final outerRadius = w * 0.17;

        // Play outline circle
        final circlePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.042;
        canvas.drawCircle(Offset(centerX, centerY), outerRadius, circlePaint);

        // Inner solid play triangle
        final playPath = Path();
        final triSide = outerRadius * 0.85;
        playPath.moveTo(centerX - triSide * 0.3, centerY - triSide * 0.5);
        playPath.lineTo(centerX - triSide * 0.3, centerY + triSide * 0.5);
        playPath.lineTo(centerX + triSide * 0.58, centerY);
        playPath.close();
        canvas.drawPath(playPath, whitePaint);
        break;

      case FileKind.zip:
        // Compression zipper track
        final trackX = w * 0.50;
        final startY = h * 0.35;
        final endY = h * 0.78;
        final zipperW = w * 0.065;
        final gapY = h * 0.08;

        final linePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.04;

        // Vertical guide line
        canvas.drawLine(Offset(trackX, startY), Offset(trackX, endY), linePaint);

        // Horizontal teeth alternating
        int i = 0;
        for (double y = startY + 2; y < endY - 2; y += gapY) {
          final isRight = i % 2 == 0;
          final xStart = isRight ? trackX : trackX - zipperW;
          final xEnd = isRight ? trackX + zipperW : trackX;
          canvas.drawLine(Offset(xStart, y), Offset(xEnd, y), linePaint);
          i++;
        }
        break;

      case FileKind.code:
        // Code brackets < / >
        final leftX = w * 0.28;
        final rightX = w * 0.72;
        final midY = h * 0.56;
        final brH = h * 0.11;
        final brW = w * 0.12;

        final codePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.048
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        // Left bracket `<`
        final leftPath = Path()
          ..moveTo(leftX + brW, midY - brH)
          ..lineTo(leftX, midY)
          ..lineTo(leftX + brW, midY + brH);
        canvas.drawPath(leftPath, codePaint);

        // Right bracket `>`
        final rightPath = Path()
          ..moveTo(rightX - brW, midY - brH)
          ..lineTo(rightX, midY)
          ..lineTo(rightX - brW, midY + brH);
        canvas.drawPath(rightPath, codePaint);

        // Slash `/`
        canvas.drawLine(
          Offset(w * 0.56, midY - brH * 1.3),
          Offset(w * 0.44, midY + brH * 1.3),
          codePaint,
        );
        break;

      default:
        // Fallback: A single generic doc file visual (one clean question mark or dot)
        canvas.drawCircle(Offset(w * 0.50, h * 0.58), w * 0.08, whitePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DocumentPagePainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

/// A custom-designed widget representing a Google Drive folder.
/// Includes back flap, tab, front flap, and shared occupant icons.
class _FolderIcon extends StatelessWidget {
  const _FolderIcon({
    required this.size,
    required this.isShared,
    required this.color,
  });

  final double size;
  final bool isShared;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FolderPainter(
          isShared: isShared,
          color: color,
        ),
      ),
    );
  }
}

class _FolderPainter extends CustomPainter {
  _FolderPainter({
    required this.isShared,
    required this.color,
  });

  final bool isShared;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.08; // border radius
    final tabW = w * 0.45;
    final tabH = h * 0.16;
    final pocketTop = h * 0.28;

    // 1. Draw back flap (slanted tab + rectangle)
    final backPath = Path()
      ..moveTo(r, 0)
      ..lineTo(tabW - r, 0)
      ..quadraticBezierTo(tabW, 0, tabW + (w * 0.05), tabH) // smooth transition down
      ..lineTo(w - r, tabH)
      ..arcToPoint(Offset(w, tabH + r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();

    final backPaint = Paint()
      ..color = color.withValues(alpha: 0.72) // 3D background shading (darker tab background)
      ..style = PaintingStyle.fill;
    canvas.drawPath(backPath, backPaint);

    // 2. Draw front flap (pocket layer)
    final frontPath = Path()
      ..moveTo(0, pocketTop + r)
      ..arcToPoint(Offset(r, pocketTop), radius: Radius.circular(r))
      ..lineTo(w - r, pocketTop)
      ..arcToPoint(Offset(w, pocketTop + r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..close();

    final frontPaint = Paint()
      ..color = color // Crisp foreground layer
      ..style = PaintingStyle.fill;
    canvas.drawPath(frontPath, frontPaint);

    // 3. Draw premium border line/shadow on front flap top edge
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04;
    canvas.drawLine(Offset(r, pocketTop), Offset(w - r, pocketTop), borderPaint);

    // 4. Draw shared folder visual occupant (silhouetted person in center)
    if (isShared) {
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final pocketH = h - pocketTop;
      final headRadius = pocketH * 0.15;
      final headCX = w * 0.50;
      final headCY = pocketTop + (pocketH * 0.35);

      // Head
      canvas.drawCircle(Offset(headCX, headCY), headRadius, whitePaint);

      // Shoulders/Body (RRect clipped)
      final bodyW = pocketH * 0.50;
      final bodyH = pocketH * 0.28;
      final bodyRect = Rect.fromCenter(
        center: Offset(headCX, headCY + headRadius + bodyH / 2 + (pocketH * 0.03)),
        width: bodyW,
        height: bodyH,
      );

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          bodyRect,
          topLeft: Radius.circular(bodyW * 0.3),
          topRight: Radius.circular(bodyW * 0.3),
        ),
        whitePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FolderPainter oldDelegate) {
    return oldDelegate.isShared != isShared || oldDelegate.color != color;
  }
}
