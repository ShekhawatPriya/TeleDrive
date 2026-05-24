import 'package:flutter/material.dart';

import 'shelf_screen.dart';

class LockedScreen extends StatelessWidget {
  const LockedScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ShelfScreen(kind: ShelfKind.locked);
}
