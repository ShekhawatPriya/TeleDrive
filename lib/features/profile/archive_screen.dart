import 'package:flutter/material.dart';

import 'shelf_screen.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ShelfScreen(kind: ShelfKind.archive);
}
