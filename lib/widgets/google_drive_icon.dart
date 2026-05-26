import 'package:flutter/material.dart';

import '../models/drive_models.dart';

part 'google_drive_icon/pdf_badge.dart';
part 'google_drive_icon/document_page_painter.dart';
part 'google_drive_icon/folder_icon.dart';

class GoogleDriveIcon extends StatelessWidget {
  const GoogleDriveIcon({
    required this.kind,
    this.isShared = false,
    this.size = 40.0,
    this.color,
    super.key,
  });

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

  final FileKind kind;

  final bool isShared;

  final double size;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (kind == FileKind.pdf) {
      return _PdfBadge(size: size, color: color);
    }

    if (kind == FileKind.folder) {
      return _FolderIcon(
        size: size,
        isShared: isShared,
        color: color ?? scheme.primary,
      );
    }

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
      FileKind.doc => const Color(0xFF1A73E8), // Google Blue
      FileKind.sheet => const Color(0xFF1E8E3E), // Google Green
      FileKind.slides => const Color(0xFFF9A825), // Google Yellow/Amber
      FileKind.audio => const Color(0xFF5C6BC0), // Indigo / Purple
      FileKind.video => const Color(0xFF00BCD4), // Cyan / Teal
      FileKind.zip => const Color(0xFF8D6E63), // Brown / Gold
      FileKind.code => const Color(0xFF455A64), // Slate Slate Grey
      FileKind.text => const Color(0xFF757575), // Silver / Dark Grey
      _ => const Color(0xFF9E9E9E), // Medium Grey fallback
    };
  }
}
