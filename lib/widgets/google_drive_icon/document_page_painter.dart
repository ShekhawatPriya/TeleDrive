part of '../google_drive_icon.dart';

class _DocumentPagePainter extends CustomPainter {
  _DocumentPagePainter({required this.kind, required this.color});

  final FileKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.08; // smooth corner radius
    final fold = w * 0.28; // folded flap size

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

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final shadowPath = Path()
      ..moveTo(w - fold, fold)
      ..lineTo(w - fold + (w * 0.05), fold + (w * 0.05))
      ..lineTo(w, fold)
      ..close();
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shadowPath, shadowPaint);

    final flapPath = Path()
      ..moveTo(w - fold, 0)
      ..lineTo(w - fold, fold)
      ..lineTo(w, fold)
      ..close();
    final flapPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawPath(flapPath, flapPaint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    switch (kind) {
      case FileKind.doc:
      case FileKind.text:
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
        final left = w * 0.22;
        final top = h * 0.36;
        final right = w * 0.78;
        final bottom = h * 0.78;
        final gridW = right - left;
        final gridH = bottom - top;

        final rectPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.045
          ..strokeCap = StrokeCap.square;
        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), rectPaint);

        final thinPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035;

        final midX = left + (gridW * 0.40); // 40% column split
        canvas.drawLine(Offset(midX, top), Offset(midX, bottom), thinPaint);

        final row1y = top + (gridH / 3);
        final row2y = top + (2 * gridH / 3);
        canvas.drawLine(Offset(left, row1y), Offset(right, row1y), thinPaint);
        canvas.drawLine(Offset(left, row2y), Offset(right, row2y), thinPaint);
        break;

      case FileKind.slides:
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

        final miniTextPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              left + gridW * 0.15,
              top + gridH * 0.2,
              right - gridW * 0.15,
              top + gridH * 0.38,
            ),
            Radius.circular(w * 0.01),
          ),
          miniTextPaint,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              left + gridW * 0.25,
              top + gridH * 0.55,
              right - gridW * 0.25,
              top + gridH * 0.65,
            ),
            Radius.circular(w * 0.01),
          ),
          miniTextPaint,
        );
        break;

      case FileKind.audio:
        final noteHeadRadius = w * 0.09;
        final headX = w * 0.44;
        final headY = h * 0.65;

        canvas.drawCircle(Offset(headX, headY), noteHeadRadius, whitePaint);

        final stemPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.048
          ..strokeCap = StrokeCap.round;

        final stemTopY = h * 0.36;
        final stemX = headX + noteHeadRadius - (w * 0.02);

        canvas.drawLine(
          Offset(stemX, headY),
          Offset(stemX, stemTopY),
          stemPaint,
        );

        final flagPath = Path()
          ..moveTo(stemX, stemTopY)
          ..quadraticBezierTo(
            stemX + w * 0.12,
            stemTopY + h * 0.04,
            stemX + w * 0.22,
            stemTopY + h * 0.08,
          );
        canvas.drawPath(flagPath, stemPaint);
        break;

      case FileKind.video:
        final centerX = w * 0.50;
        final centerY = h * 0.58;
        final outerRadius = w * 0.17;

        final circlePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.042;
        canvas.drawCircle(Offset(centerX, centerY), outerRadius, circlePaint);

        final playPath = Path();
        final triSide = outerRadius * 0.85;
        playPath.moveTo(centerX - triSide * 0.3, centerY - triSide * 0.5);
        playPath.lineTo(centerX - triSide * 0.3, centerY + triSide * 0.5);
        playPath.lineTo(centerX + triSide * 0.58, centerY);
        playPath.close();
        canvas.drawPath(playPath, whitePaint);
        break;

      case FileKind.zip:
        final trackX = w * 0.50;
        final startY = h * 0.35;
        final endY = h * 0.78;
        final zipperW = w * 0.065;
        final gapY = h * 0.08;

        final linePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.04;

        canvas.drawLine(
          Offset(trackX, startY),
          Offset(trackX, endY),
          linePaint,
        );

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

        final leftPath = Path()
          ..moveTo(leftX + brW, midY - brH)
          ..lineTo(leftX, midY)
          ..lineTo(leftX + brW, midY + brH);
        canvas.drawPath(leftPath, codePaint);

        final rightPath = Path()
          ..moveTo(rightX - brW, midY - brH)
          ..lineTo(rightX, midY)
          ..lineTo(rightX - brW, midY + brH);
        canvas.drawPath(rightPath, codePaint);

        canvas.drawLine(
          Offset(w * 0.56, midY - brH * 1.3),
          Offset(w * 0.44, midY + brH * 1.3),
          codePaint,
        );
        break;

      default:
        canvas.drawCircle(Offset(w * 0.50, h * 0.58), w * 0.08, whitePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DocumentPagePainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}
