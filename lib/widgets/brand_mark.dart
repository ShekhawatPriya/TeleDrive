import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 40, super.key});
  final double size;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: Icon(
          Icons.cloud_outlined,
          color: scheme.onPrimary,
          size: size * .64,
        ),
      ),
    );
  }
}
