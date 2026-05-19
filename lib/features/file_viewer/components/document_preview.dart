import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';

class DocumentPreview extends StatefulWidget {
  const DocumentPreview({required this.file, required this.onOpen, super.key});
  final DriveFile file;
  final VoidCallback onOpen;

  @override
  State<DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<DocumentPreview> {
  bool _opening = false;

  Future<void> _handleOpen() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      widget.onOpen();
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = _kindLabel(widget.file.kind, widget.file.name);
    final accent = _kindAccent(widget.file.kind, scheme);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.78,
                child: CustomPaint(
                  painter: _DocumentPagePainter(
                    fillColor: scheme.surface,
                    borderColor: scheme.outlineVariant,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        const Spacer(),
                        _DocLine(
                          width: double.infinity,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 6),
                        _DocLine(
                          widthFraction: 0.85,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 6),
                        _DocLine(
                          widthFraction: 0.7,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 6),
                        _DocLine(
                          widthFraction: 0.92,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 6),
                        _DocLine(
                          widthFraction: 0.55,
                          color: scheme.outlineVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _opening ? null : _handleOpen,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadii.pill),
                  ),
                ),
              ),
              icon: _opening
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(_actionLabel(widget.file.kind)),
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(FileKind kind) {
    return switch (kind) {
      FileKind.pdf => 'Open PDF',
      FileKind.audio => 'Play audio',
      FileKind.zip => 'Open archive',
      FileKind.doc => 'Open document',
      FileKind.sheet => 'Open spreadsheet',
      FileKind.slides => 'Open slides',
      FileKind.code || FileKind.text => 'Open file',
      _ => 'Open file',
    };
  }

  String _kindLabel(FileKind kind, String name) {
    final ext = extensionOf(name).toUpperCase();
    return switch (kind) {
      FileKind.pdf => 'PDF',
      FileKind.audio => ext.isNotEmpty ? ext : 'AUDIO',
      FileKind.zip => ext.isNotEmpty ? ext : 'ARCHIVE',
      FileKind.doc => ext.isNotEmpty ? ext : 'DOC',
      FileKind.sheet => ext.isNotEmpty ? ext : 'SHEET',
      FileKind.slides => ext.isNotEmpty ? ext : 'SLIDES',
      FileKind.code => ext.isNotEmpty ? ext : 'CODE',
      FileKind.text => ext.isNotEmpty ? ext : 'TEXT',
      _ => ext.isNotEmpty ? ext : 'FILE',
    };
  }

  Color _kindAccent(FileKind kind, ColorScheme scheme) {
    return switch (kind) {
      FileKind.pdf => scheme.error,
      FileKind.doc => scheme.primary,
      FileKind.sheet => AppColors.success,
      FileKind.slides => scheme.tertiary,
      _ => scheme.primary,
    };
  }
}

class _DocLine extends StatelessWidget {
  const _DocLine({this.width, this.widthFraction = 1, required this.color});
  final double? width;
  final double widthFraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFraction,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _DocumentPagePainter extends CustomPainter {
  _DocumentPagePainter({required this.fillColor, required this.borderColor});

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 10.0;
    const fold = 14.0;
    final path = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height - radius)
      ..arcToPoint(
        Offset(size.width - radius, size.height),
        radius: const Radius.circular(radius),
      )
      ..lineTo(radius, size.height)
      ..arcToPoint(
        Offset(0, size.height - radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);

    final foldPath = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width - fold, fold)
      ..lineTo(size.width, fold);
    final foldFill = Paint()
      ..color = borderColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(foldPath, foldFill);

    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, stroke);
    canvas.drawLine(
      Offset(size.width - fold, 0),
      Offset(size.width - fold, fold),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width - fold, fold),
      Offset(size.width, fold),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _DocumentPagePainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor;
}
